"""Audit trail helpers and middleware for homecare PHI operations.

The middleware writes an :class:`AuditEvent` for every mutating request
(POST/PUT/PATCH/DELETE) on /api/homecare/* endpoints. Read access is not
logged here to avoid noise; specific sensitive endpoints can call
:func:`log_event` directly to record a ``view`` action.
"""
from __future__ import annotations

import json
import logging
from typing import Any, Optional

from django.utils.deprecation import MiddlewareMixin

logger = logging.getLogger(__name__)


_AUDITED_PREFIXES = ('/api/homecare/',)
_MUTATING_METHODS = {'POST', 'PUT', 'PATCH', 'DELETE'}


def _client_ip(request) -> Optional[str]:
    xf = request.META.get('HTTP_X_FORWARDED_FOR')
    if xf:
        return xf.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR')


def _safe_body(request) -> dict:
    """Return a JSON-safe snapshot of the request body, redacting secrets."""
    if request.method not in _MUTATING_METHODS:
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
    if not isinstance(data, dict):
        return {'_value': data}
    redacted = {}
    for k, v in data.items():
        if any(s in k.lower() for s in ('password', 'secret', 'token', 'otp', 'pin')):
            redacted[k] = '***'
        else:
            redacted[k] = v
    return redacted


def _object_type_from_path(path: str) -> str:
    # /api/homecare/devices/12/assign/ -> devices
    parts = [p for p in path.split('/') if p]
    try:
        i = parts.index('homecare')
        return parts[i + 1] if i + 1 < len(parts) else ''
    except ValueError:
        return ''


def _object_id_from_path(path: str) -> str:
    parts = [p for p in path.split('/') if p]
    for p in reversed(parts):
        if p.isdigit():
            return p
    return ''


def log_event(*, request=None, action: str, object_type: str,
              object_id: Any = '', object_repr: str = '',
              payload_diff: Optional[dict] = None,
              extra: Optional[dict] = None,
              status_code: Optional[int] = None) -> None:
    """Write a single audit event. Never raises."""
    try:
        from .models import AuditEvent  # local import: tenant model

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
        AuditEvent.objects.create(
            actor_user_id=actor_id,
            actor_email=actor_email[:255],
            actor_role=actor_role[:64],
            action=action,
            object_type=str(object_type)[:120],
            object_id=str(object_id)[:64],
            object_repr=str(object_repr)[:255],
            method=method[:10],
            path=path[:512],
            ip=ip,
            user_agent=ua,
            payload_diff=payload_diff or {},
            extra=extra or {},
            status_code=status_code,
        )
    except Exception:
        logger.exception('audit.log_event failed')


class HomecareAuditMiddleware(MiddlewareMixin):
    """Log every mutating request against /api/homecare/* to AuditEvent."""

    def process_request(self, request):
        if request.method in _MUTATING_METHODS and \
                any(request.path.startswith(p) for p in _AUDITED_PREFIXES):
            # Cache the body once, before DRF consumes it.
            request._audit_payload = _safe_body(request)
        return None

    def process_response(self, request, response):
        try:
            if request.method not in _MUTATING_METHODS:
                return response
            if not any(request.path.startswith(p) for p in _AUDITED_PREFIXES):
                return response
            method_to_action = {
                'POST': 'create', 'PUT': 'update',
                'PATCH': 'update', 'DELETE': 'delete',
            }
            action = method_to_action.get(request.method, 'action')
            log_event(
                request=request,
                action=action,
                object_type=_object_type_from_path(request.path),
                object_id=_object_id_from_path(request.path),
                payload_diff=getattr(request, '_audit_payload', {}) or {},
                status_code=getattr(response, 'status_code', None),
            )
        except Exception:
            logger.exception('HomecareAuditMiddleware failed')
        return response
