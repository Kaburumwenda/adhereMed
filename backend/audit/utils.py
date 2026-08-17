"""Audit logging utilities — call from any view to record a manual event."""
from __future__ import annotations

import json
import logging
from typing import Any, Optional

from django.db import transaction

logger = logging.getLogger(__name__)


def _client_ip(request) -> Optional[str]:
    if request is None:
        return None
    xf = request.META.get('HTTP_X_FORWARDED_FOR')
    if xf:
        return xf.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR')


_SENSITIVE_KEYS = ('password', 'secret', 'token', 'otp', 'pin', 'auth',
                   'cvv', 'card_number', 'ssn', 'national_id')


def redact_payload(payload: Any) -> Any:
    """Return a JSON-safe snapshot of a payload, redacting secret keys."""
    if isinstance(payload, dict):
        redacted = {}
        for k, v in payload.items():
            if isinstance(k, str) and any(s in k.lower() for s in _SENSITIVE_KEYS):
                redacted[k] = '***'
            else:
                redacted[k] = redact_payload(v)
        return redacted
    if isinstance(payload, list):
        return [redact_payload(v) for v in payload]
    return payload


def safe_body(request) -> dict:
    """Read the JSON body of a mutating request, redacting sensitive keys.

    Returns ``{}`` for non-mutating methods or unparseable bodies.
    """
    if request.method not in ('POST', 'PUT', 'PATCH', 'DELETE'):
        return {}
    try:
        raw = request.body
    except Exception:
        return {}
    if not raw:
        return {}
    try:
        data = json.loads(raw.decode('utf-8'))
    except Exception:
        return {'_raw_size': len(raw)}
    return redact_payload(data)


def log_event(*, request=None, action: str, object_type: str = '',
              object_id: Any = '', object_repr: str = '',
              description: str = '', payload_diff: Optional[dict] = None,
              extra: Optional[dict] = None, status_code: Optional[int] = None,
              severity: Optional[str] = None, session_id: str = '') -> None:
    """Write a single audit event. Never raises.

    Designed to be called from any view (or signal) to record custom or
    READ events. Mutating writes are normally auto-logged by the
    :mod:`audit.middleware`.
    """
    try:
        from .models import AuditEvent

        actor_id = None
        actor_email = ''
        actor_role = ''
        ip = None
        ua = ''
        method = ''
        path = ''
        if request is not None:
            user = getattr(request, 'user', None)
            if user is not None and getattr(user, 'is_authenticated', False):
                actor_id = getattr(user, 'id', None)
                actor_email = getattr(user, 'email', '') or ''
                actor_role = getattr(user, 'role', '') or ''
            ip = _client_ip(request)
            ua = (request.META.get('HTTP_USER_AGENT') or '')[:512]
            method = request.method or ''
            path = request.path or ''
        # Defer insert so log calls inside a request don't fail on rollback.
        with transaction.atomic():
            AuditEvent.objects.create(
                actor_user_id=actor_id,
                actor_email=actor_email,
                actor_role=actor_role,
                action=action,
                severity=severity or AuditEvent.Severity.INFO,
                object_type=object_type or '',
                object_id=str(object_id) if object_id is not None else '',
                object_repr=(object_repr or '')[:255],
                description=(description or '')[:255],
                method=method,
                path=path[:512],
                ip=ip,
                user_agent=ua,
                payload_diff=payload_diff or {},
                extra=extra or {},
                status_code=status_code,
                session_id=session_id or '',
            )
    except Exception:
        logger.exception('audit.log_event failed')
