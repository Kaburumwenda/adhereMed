"""Signed token helpers for short-lived resource access (teleconsult rooms).

Uses HS256 keyed off Django ``SECRET_KEY`` with a per-feature salt. Tokens
are intentionally narrow-scoped: ``aud=teleconsult-room``, ``sub=<user_id>``,
``room_id``, ``room_token``, with a short ``exp`` (default 60 minutes).
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
from datetime import datetime, timedelta, timezone as dt_tz
from typing import Tuple

from django.conf import settings


_AUD = 'homecare-teleconsult-room'
_DEFAULT_TTL = timedelta(minutes=60)


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode('ascii')


def _b64url_decode(data: str) -> bytes:
    pad = '=' * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + pad)


def _sign(msg: bytes) -> bytes:
    key = (settings.SECRET_KEY + ':homecare-teleconsult').encode('utf-8')
    return hmac.new(key, msg, hashlib.sha256).digest()


def issue_room_token(*, room, user, ttl: timedelta = _DEFAULT_TTL) -> Tuple[str, datetime]:
    """Issue a signed JWT-like token for joining a teleconsult room."""
    now = datetime.now(dt_tz.utc)
    exp = now + ttl
    header = {'alg': 'HS256', 'typ': 'JWT'}
    payload = {
        'aud': _AUD,
        'sub': str(getattr(user, 'id', '')),
        'email': getattr(user, 'email', ''),
        'role': getattr(user, 'role', ''),
        'room_id': room.id,
        'room_token': str(room.room_token),
        'provider': room.provider,
        'iat': int(now.timestamp()),
        'exp': int(exp.timestamp()),
    }
    h = _b64url(json.dumps(header, separators=(',', ':')).encode('utf-8'))
    p = _b64url(json.dumps(payload, separators=(',', ':')).encode('utf-8'))
    signing_input = f'{h}.{p}'.encode('ascii')
    sig = _b64url(_sign(signing_input))
    return f'{h}.{p}.{sig}', exp


def verify_room_token(token: str) -> dict:
    """Verify signature, audience and expiry. Returns the payload dict."""
    if not token or token.count('.') != 2:
        raise ValueError('malformed token')
    h, p, s = token.split('.')
    expected_sig = _b64url(_sign(f'{h}.{p}'.encode('ascii')))
    if not hmac.compare_digest(expected_sig, s):
        raise ValueError('invalid signature')
    payload = json.loads(_b64url_decode(p).decode('utf-8'))
    if payload.get('aud') != _AUD:
        raise ValueError('invalid audience')
    exp = payload.get('exp', 0)
    if datetime.now(dt_tz.utc).timestamp() > float(exp):
        raise ValueError('token expired')
    return payload
