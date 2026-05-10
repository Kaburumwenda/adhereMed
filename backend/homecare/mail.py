"""Homecare tenant mailbox: IMAP fetch + SMTP send.

Wraps stdlib `imaplib`, `smtplib`, `email` to expose a small JSON-friendly
helper API that the views layer can call.
"""
from __future__ import annotations

import base64
import email
import email.policy
import imaplib
import re
import smtplib
import ssl
from contextlib import contextmanager
from email.message import EmailMessage
from email.utils import getaddresses, parseaddr, parsedate_to_datetime
from typing import Iterable

from django.conf import settings


# ─────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────
def _cfg() -> dict:
    """Return effective mail config for the current tenant.

    Resolution order:
      1. Active `MailAccount` row in the current tenant schema.
      2. Global `settings.HOMECARE_MAIL` defaults.
    The tenant `name` (when available) is used as the From display name
    unless a `MailAccount.display_name` is provided.
    """
    base = dict(getattr(settings, 'HOMECARE_MAIL', {}) or {})

    # Default From name = tenant name (falls back to settings)
    try:
        from django.db import connection
        tenant = getattr(connection, 'tenant', None)
        if tenant and getattr(tenant, 'name', None):
            base.setdefault('FROM_NAME', tenant.name)
    except Exception:
        pass

    # Tenant-level override row (singleton)
    try:
        from .models import MailAccount  # local import to avoid cycles
        acc = MailAccount.objects.filter(is_active=True).first()
        if acc:
            return {
                'IMAP_HOST': acc.imap_host or base.get('IMAP_HOST'),
                'IMAP_PORT': acc.imap_port or base.get('IMAP_PORT', 993),
                'IMAP_SSL':  bool(acc.imap_use_ssl),
                'SMTP_HOST': acc.smtp_host or base.get('SMTP_HOST'),
                'SMTP_PORT': acc.smtp_port or base.get('SMTP_PORT', 465),
                'SMTP_SSL':  bool(acc.smtp_use_ssl),
                'USERNAME':  acc.username or acc.email or base.get('USERNAME'),
                'PASSWORD':  acc.password or base.get('PASSWORD'),
                'FROM_NAME': acc.display_name or base.get('FROM_NAME')
                             or 'Homecare',
                'FROM_EMAIL': acc.email or acc.username or base.get('USERNAME'),
            }
    except Exception:
        # Migrations not applied yet, etc.
        pass

    base.setdefault('FROM_NAME', 'Homecare')
    base['FROM_EMAIL'] = base.get('USERNAME')
    return base


def is_configured() -> bool:
    c = _cfg()
    return bool(c.get('USERNAME') and c.get('PASSWORD')
                and c.get('IMAP_HOST') and c.get('SMTP_HOST'))


# ─────────────────────────────────────────────────────────
# IMAP
# ─────────────────────────────────────────────────────────
@contextmanager
def imap_connection():
    c = _cfg()
    ctx = ssl.create_default_context()
    if c.get('IMAP_SSL', True):
        m = imaplib.IMAP4_SSL(c['IMAP_HOST'], c.get('IMAP_PORT', 993),
                              ssl_context=ctx)
    else:
        m = imaplib.IMAP4(c['IMAP_HOST'], c.get('IMAP_PORT', 143))
    try:
        m.login(c['USERNAME'], c['PASSWORD'])
        yield m
    finally:
        try:
            m.logout()
        except Exception:
            pass


SAFE_FOLDER_RE = re.compile(r'^[A-Za-z0-9_./\- ]+$')


def _safe_folder(name: str | None) -> str:
    name = (name or 'INBOX').strip()
    if not SAFE_FOLDER_RE.match(name):
        return 'INBOX'
    return name


def list_folders() -> list[dict]:
    out = []
    with imap_connection() as m:
        typ, data = m.list()
        if typ != 'OK':
            return out
        for raw in data or []:
            if not raw:
                continue
            line = raw.decode(errors='ignore')
            # ex: '(\\HasNoChildren) "/" "INBOX"'
            try:
                name = line.rsplit(' ', 1)[-1].strip().strip('"')
            except Exception:
                continue
            try:
                m.select(f'"{name}"', readonly=True)
                typ2, num = m.search(None, 'ALL')
                count = len(num[0].split()) if typ2 == 'OK' and num and num[0] else 0
                typ3, unum = m.search(None, 'UNSEEN')
                unread = len(unum[0].split()) if typ3 == 'OK' and unum and unum[0] else 0
            except Exception:
                count, unread = 0, 0
            out.append({'name': name, 'count': count, 'unread': unread})
    return out


def _parse_addrs(value: str | None) -> list[dict]:
    if not value:
        return []
    return [{'name': name or '', 'email': addr or ''}
            for (name, addr) in getaddresses([value]) if addr]


def _decode_header(value: str | None) -> str:
    if not value:
        return ''
    try:
        from email.header import decode_header, make_header
        return str(make_header(decode_header(value)))
    except Exception:
        return value


def _msg_summary(uid: str, msg) -> dict:
    return {
        'uid': uid,
        'subject': _decode_header(msg.get('Subject')),
        'from': _parse_addrs(msg.get('From'))[:1] or [{'name': '', 'email': ''}],
        'to': _parse_addrs(msg.get('To')),
        'cc': _parse_addrs(msg.get('Cc')),
        'date': _format_date(msg.get('Date')),
        'message_id': msg.get('Message-ID') or '',
    }


def _format_date(value: str | None) -> str | None:
    if not value:
        return None
    try:
        return parsedate_to_datetime(value).isoformat()
    except Exception:
        return value


def list_messages(folder: str = 'INBOX', limit: int = 50,
                  search: str | None = None) -> dict:
    folder = _safe_folder(folder)
    limit = max(1, min(int(limit or 50), 200))
    items: list[dict] = []
    total = 0
    unread = 0
    with imap_connection() as m:
        typ, _ = m.select(f'"{folder}"', readonly=True)
        if typ != 'OK':
            return {'folder': folder, 'total': 0, 'unread': 0, 'items': []}
        # Search
        criteria = 'ALL'
        charset = None
        if search:
            # Avoid CR/LF injection in search term
            term = re.sub(r'[\r\n"]', ' ', search)[:200]
            charset = 'UTF-8'
            criteria = f'(OR OR SUBJECT "{term}" FROM "{term}" TEXT "{term}")'
        typ, data = m.uid('SEARCH', charset, criteria) if charset \
            else m.uid('SEARCH', None, criteria)
        if typ != 'OK' or not data or not data[0]:
            return {'folder': folder, 'total': 0, 'unread': 0, 'items': []}
        uids = data[0].split()
        total = len(uids)
        # Most recent first
        uids = uids[-limit:][::-1]
        # Unread count
        typ2, udata = m.uid('SEARCH', None, 'UNSEEN')
        if typ2 == 'OK' and udata and udata[0]:
            unread = len(udata[0].split())
        unseen_set = set(udata[0].split()) if (typ2 == 'OK' and udata and udata[0]) else set()
        if not uids:
            return {'folder': folder, 'total': total, 'unread': unread, 'items': []}
        # Bulk fetch headers
        uid_list = b','.join(uids).decode()
        typ, fetched = m.uid('FETCH', uid_list,
                             '(BODY.PEEK[HEADER.FIELDS (SUBJECT FROM TO CC DATE MESSAGE-ID)] FLAGS RFC822.SIZE)')
        if typ != 'OK' or not fetched:
            return {'folder': folder, 'total': total, 'unread': unread, 'items': []}
        # Parse fetch response: alternating tuples + bytes
        cur_uid = None
        cur_flags = ''
        cur_size = 0
        for part in fetched:
            if isinstance(part, tuple) and len(part) >= 2:
                meta = part[0].decode(errors='ignore') if isinstance(part[0], bytes) else str(part[0])
                head = part[1] if isinstance(part[1], (bytes, bytearray)) else b''
                # Extract UID, FLAGS, SIZE
                muid = re.search(r'UID (\d+)', meta)
                mflags = re.search(r'FLAGS \(([^)]*)\)', meta)
                msize = re.search(r'RFC822\.SIZE (\d+)', meta)
                cur_uid = muid.group(1) if muid else None
                cur_flags = mflags.group(1) if mflags else ''
                cur_size = int(msize.group(1)) if msize else 0
                if not cur_uid:
                    continue
                msg = email.message_from_bytes(bytes(head), policy=email.policy.default)
                summary = _msg_summary(cur_uid, msg)
                summary['flags'] = cur_flags.split() if cur_flags else []
                summary['unread'] = cur_uid.encode() in unseen_set
                summary['size'] = cur_size
                items.append(summary)
        # Restore newest-first ordering by uid desc
        items.sort(key=lambda x: int(x['uid']), reverse=True)
        return {'folder': folder, 'total': total, 'unread': unread, 'items': items}


def fetch_message(uid: str, folder: str = 'INBOX') -> dict | None:
    folder = _safe_folder(folder)
    if not str(uid).isdigit():
        return None
    with imap_connection() as m:
        typ, _ = m.select(f'"{folder}"')
        if typ != 'OK':
            return None
        typ, data = m.uid('FETCH', str(uid), '(RFC822 FLAGS)')
        if typ != 'OK' or not data:
            return None
        raw = None
        flags = ''
        for part in data:
            if isinstance(part, tuple) and len(part) >= 2:
                raw = part[1]
                meta = part[0].decode(errors='ignore') if isinstance(part[0], bytes) else ''
                mflags = re.search(r'FLAGS \(([^)]*)\)', meta)
                flags = mflags.group(1) if mflags else ''
        if not raw:
            return None
        msg = email.message_from_bytes(bytes(raw), policy=email.policy.default)
        body_text, body_html = '', ''
        attachments: list[dict] = []
        for part in msg.walk():
            if part.is_multipart():
                continue
            cdisp = (part.get_content_disposition() or '').lower()
            ctype = part.get_content_type()
            filename = part.get_filename()
            if cdisp == 'attachment' or filename:
                payload = part.get_payload(decode=True) or b''
                attachments.append({
                    'name': _decode_header(filename) or 'attachment',
                    'type': ctype,
                    'size': len(payload),
                    'data': base64.b64encode(payload).decode('ascii'),
                })
                continue
            if ctype == 'text/plain' and not body_text:
                try:
                    body_text = part.get_content()
                except Exception:
                    body_text = (part.get_payload(decode=True) or b'').decode(
                        part.get_content_charset() or 'utf-8', errors='replace')
            elif ctype == 'text/html' and not body_html:
                try:
                    body_html = part.get_content()
                except Exception:
                    body_html = (part.get_payload(decode=True) or b'').decode(
                        part.get_content_charset() or 'utf-8', errors='replace')
        result = _msg_summary(str(uid), msg)
        result.update({
            'flags': flags.split() if flags else [],
            'body_text': body_text,
            'body_html': body_html,
            'attachments': attachments,
            'reply_to': _parse_addrs(msg.get('Reply-To')),
        })
        return result


def mark_seen(uid: str, folder: str = 'INBOX', seen: bool = True) -> bool:
    folder = _safe_folder(folder)
    if not str(uid).isdigit():
        return False
    with imap_connection() as m:
        typ, _ = m.select(f'"{folder}"')
        if typ != 'OK':
            return False
        cmd = '+FLAGS' if seen else '-FLAGS'
        typ, _ = m.uid('STORE', str(uid), cmd, '\\Seen')
        return typ == 'OK'


def delete_message(uid: str, folder: str = 'INBOX') -> bool:
    folder = _safe_folder(folder)
    if not str(uid).isdigit():
        return False
    with imap_connection() as m:
        typ, _ = m.select(f'"{folder}"')
        if typ != 'OK':
            return False
        m.uid('STORE', str(uid), '+FLAGS', '\\Deleted')
        m.expunge()
        return True


# ─────────────────────────────────────────────────────────
# SMTP
# ─────────────────────────────────────────────────────────
def _split_addrs(value) -> list[str]:
    if not value:
        return []
    if isinstance(value, str):
        # comma / semicolon separated
        parts = re.split(r'[,;]', value)
    else:
        parts = list(value)
    out = []
    for p in parts:
        p = (p or '').strip()
        if not p:
            continue
        _, addr = parseaddr(p)
        if addr:
            out.append(p if '<' in p else addr)
    return out


def send_message(*, to, subject: str, body_text: str = '', body_html: str = '',
                 cc=None, bcc=None, attachments: Iterable[dict] | None = None,
                 reply_to: str | None = None, in_reply_to: str | None = None) -> dict:
    """Send an email via SMTP. attachments = [{name, type, data: base64}]."""
    c = _cfg()
    if not is_configured():
        raise RuntimeError('Homecare mailbox is not configured.')

    to_list = _split_addrs(to)
    cc_list = _split_addrs(cc)
    bcc_list = _split_addrs(bcc)
    if not to_list:
        raise ValueError('At least one recipient is required.')

    msg = EmailMessage()
    from_name = c.get('FROM_NAME') or 'Homecare'
    from_addr = c.get('FROM_EMAIL') or c['USERNAME']
    msg['From'] = f'{from_name} <{from_addr}>'
    msg['To'] = ', '.join(to_list)
    if cc_list:
        msg['Cc'] = ', '.join(cc_list)
    msg['Subject'] = subject or '(no subject)'
    if reply_to:
        msg['Reply-To'] = reply_to
    if in_reply_to:
        msg['In-Reply-To'] = in_reply_to
        msg['References'] = in_reply_to

    text = body_text or _strip_html(body_html) or ''
    msg.set_content(text or ' ')
    if body_html:
        msg.add_alternative(body_html, subtype='html')

    for att in (attachments or []):
        name = att.get('name') or 'attachment'
        ctype = att.get('type') or 'application/octet-stream'
        data = att.get('data') or ''
        # Allow data URLs
        if ',' in data and data.startswith('data:'):
            data = data.split(',', 1)[1]
        try:
            payload = base64.b64decode(data)
        except Exception:
            continue
        maintype, _, subtype = ctype.partition('/')
        if not subtype:
            maintype, subtype = 'application', 'octet-stream'
        msg.add_attachment(payload, maintype=maintype, subtype=subtype, filename=name)

    ctx = ssl.create_default_context()
    rcpts = to_list + cc_list + bcc_list
    if c.get('SMTP_SSL', True):
        with smtplib.SMTP_SSL(c['SMTP_HOST'], c.get('SMTP_PORT', 465), context=ctx) as s:
            s.login(c['USERNAME'], c['PASSWORD'])
            s.send_message(msg, from_addr=from_addr, to_addrs=rcpts)
    else:
        with smtplib.SMTP(c['SMTP_HOST'], c.get('SMTP_PORT', 587)) as s:
            s.starttls(context=ctx)
            s.login(c['USERNAME'], c['PASSWORD'])
            s.send_message(msg, from_addr=from_addr, to_addrs=rcpts)

    # Try to append to "Sent" folder so it shows in webmail
    try:
        with imap_connection() as m:
            for folder in ('Sent', 'INBOX.Sent', 'Sent Items', 'Sent Messages'):
                typ, _ = m.select(f'"{folder}"')
                if typ == 'OK':
                    m.append(f'"{folder}"', '\\Seen', None, msg.as_bytes())
                    break
    except Exception:
        pass

    return {'ok': True, 'recipients': rcpts, 'message_id': msg.get('Message-ID', '')}


def _strip_html(html: str | None) -> str:
    if not html:
        return ''
    text = re.sub(r'<\s*(br|/p|/div|/li|/tr)\s*/?>', '\n', html, flags=re.I)
    text = re.sub(r'<[^>]+>', '', text)
    return re.sub(r'\n{3,}', '\n\n', text).strip()


# ─────────────────────────────────────────────────────────
# Credential verification (used by the settings UI)
# ─────────────────────────────────────────────────────────
def verify_credentials(cfg: dict) -> dict:
    """Try IMAP login + SMTP login using the supplied config.

    Returns {ok: bool, imap_ok, smtp_ok, error}. Does not send any mail.
    """
    out = {'ok': False, 'imap_ok': False, 'smtp_ok': False, 'error': ''}
    ctx = ssl.create_default_context()
    # IMAP
    try:
        if cfg.get('imap_use_ssl', True):
            m = imaplib.IMAP4_SSL(cfg['imap_host'], int(cfg.get('imap_port') or 993),
                                  ssl_context=ctx)
        else:
            m = imaplib.IMAP4(cfg['imap_host'], int(cfg.get('imap_port') or 143))
        try:
            m.login(cfg['username'], cfg['password'])
            out['imap_ok'] = True
        finally:
            try:
                m.logout()
            except Exception:
                pass
    except Exception as exc:
        out['error'] = f'IMAP: {exc}'
        return out
    # SMTP
    try:
        if cfg.get('smtp_use_ssl', True):
            s = smtplib.SMTP_SSL(cfg['smtp_host'], int(cfg.get('smtp_port') or 465),
                                 context=ctx, timeout=15)
        else:
            s = smtplib.SMTP(cfg['smtp_host'], int(cfg.get('smtp_port') or 587),
                             timeout=15)
            s.starttls(context=ctx)
        try:
            s.login(cfg['username'], cfg['password'])
            out['smtp_ok'] = True
        finally:
            try:
                s.quit()
            except Exception:
                pass
    except Exception as exc:
        out['error'] = f'SMTP: {exc}'
        return out
    out['ok'] = True
    return out
