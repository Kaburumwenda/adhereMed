"""Generic audit middleware — logs every mutating request to AuditEvent.

Mounted in ``config.settings.MIDDLEWARE`` so it runs for every tenant.
The audit is *append-only*: the middleware only inserts rows, never
updates them, so the trail stays intact even if the underlying transaction
rolls back (we wrap the insert in a nested atomic block).

For non-API requests (admin, static, /api/auth/login etc.) it logs login
and logout events plus any failed authentication.
"""
from __future__ import annotations

import logging

from django.utils.deprecation import MiddlewareMixin

from .utils import safe_body, _client_ip, redact_payload

logger = logging.getLogger(__name__)


_MUTATING_METHODS = {'POST', 'PUT', 'PATCH', 'DELETE'}


def _object_type_from_path(path: str) -> str:
    """Return the API module name from a path like /api/patients/12/."""
    parts = [p for p in path.split('/') if p]
    if len(parts) < 2 or parts[0] != 'api':
        return ''
    # parts: ['api','patients','12','admit']
    return parts[1]


def _object_id_from_path(path: str) -> str:
    parts = [p for p in path.split('/') if p]
    for p in reversed(parts):
        if p.isdigit():
            return p
    return ''


def _action_for(method: str, status: int) -> str:
    if method == 'POST':
        return 'create' if 200 <= status < 400 else 'action'
    if method in ('PUT', 'PATCH'):
        return 'update'
    if method == 'DELETE':
        return 'delete'
    return 'view'


class AuditMiddleware(MiddlewareMixin):
    """Record one AuditEvent per mutating API request."""

    # Skip noisy paths that aren't worth auditing.
    _SKIP_PREFIXES = (
        '/api/auth/token',     # JWT refresh
        '/api/usage-billing',  # usage heartbeat
        '/static/',
        '/media/',
    )

    def process_request(self, request):
        # Stash the request body snapshot before the view consumes it.
        # We only need it for mutating API calls.
        if request.method in _MUTATING_METHODS and request.path.startswith('/api/'):
            request._audit_payload = safe_body(request)
        return None

    def process_response(self, request, response):
        try:
            self._maybe_log(request, response)
        except Exception:
            logger.exception('AuditMiddleware.process_response failed')
        return response

    def _maybe_log(self, request, response):
        path = request.path or ''
        if not path.startswith('/api/'):
            return
        if any(path.startswith(p) for p in self._SKIP_PREFIXES):
            return

        # Login / logout + failed auth are audited even for GET.
        if path.endswith('/login/'):
            self._record(request, response, action='login', object_type='auth',
                         description='Sign-in attempt')
            return
        if path.endswith('/logout/'):
            self._record(request, response, action='logout', object_type='auth',
                         description='Sign-out')
            return

        # Only audit mutating requests beyond this point.
        if request.method not in _MUTATING_METHODS:
            return

        action = _action_for(request.method, response.status_code)
        severity = 'info'
        if response.status_code >= 500:
            severity = 'critical'
        elif response.status_code >= 400:
            severity = 'warning'

        self._record(
            request, response,
            action=action,
            object_type=_object_type_from_path(path),
            object_id=_object_id_from_path(path),
            payload_diff=getattr(request, '_audit_payload', {}) or {},
            severity=severity,
        )

    def _record(self, request, response, *, action, object_type='',
                object_id='', payload_diff=None, description='', severity='info'):
        from .models import AuditEvent
        from .utils import log_event
        log_event(
            request=request,
            action=action,
            object_type=object_type,
            object_id=object_id,
            description=description,
            payload_diff=payload_diff or {},
            status_code=getattr(response, 'status_code', None),
            severity=severity,
        )
