"""Tenant-scoped caching helpers for expensive read-only API payloads.

The default backend (:class:`config.cache_backends.TenantRedisCache`) already
prefixes every key with the tenant schema, so schemas can never read each
other's entries. These helpers add:

* a namespace + generation suffix so a write can drop a whole family of cached
  payloads with a single ``INCR`` (no ``SCAN`` / key deletes);
* a decorator for DRF handlers that keys on path, query string and an optional
  scope fragment (branch / clinic site), so per-user scoping is preserved.

Usage::

    from config.cache import branch_scope, tenant_cache

    class InventoryOverviewView(APIView):
        @tenant_cache('ims.dashboard', timeout=60, scope=branch_scope)
        def get(self, request):
            ...
"""
from __future__ import annotations

import hashlib
import json
import logging
from functools import wraps

from django.conf import settings
from django.core.cache import cache
from rest_framework.response import Response

logger = logging.getLogger(__name__)

VERSION_KEY_TEMPLATE = 'tenant-cache:version:{namespace}'
#: Query parameters that request a non-JSON rendering (never cached).
UNCACHEABLE_FORMATS = {'csv', 'pdf', 'xlsx'}


def is_enabled() -> bool:
    """False when caching is switched off via ``TENANT_CACHE_ENABLED``."""
    return bool(getattr(settings, 'TENANT_CACHE_ENABLED', True))


def _version_key(namespace: str) -> str:
    return VERSION_KEY_TEMPLATE.format(namespace=namespace)


def namespace_version(namespace: str) -> int:
    """Current generation of ``namespace``; part of every key it caches."""
    try:
        return int(cache.get(_version_key(namespace), 0) or 0)
    except Exception:  # noqa: BLE001 - caching must never break a request
        logger.debug('Could not read cache generation for %s', namespace, exc_info=True)
        return 0


def invalidate(namespace: str) -> None:
    """Drop every cached payload of ``namespace`` for the active tenant."""
    key = _version_key(namespace)
    try:
        if cache.add(key, 1, None):
            return
        cache.incr(key)
    except ValueError:
        # Redis came back between the add and the incr; retry once.
        try:
            cache.add(key, 1, None)
        except Exception:  # noqa: BLE001
            logger.debug('Could not invalidate cache namespace %s', namespace, exc_info=True)
    except Exception:  # noqa: BLE001 - caching must never break a write
        logger.debug('Could not invalidate cache namespace %s', namespace, exc_info=True)


def build_key(namespace: str, parts) -> str:
    """Deterministic key for ``parts`` in the current generation of ``namespace``."""
    payload = json.dumps(parts, sort_keys=True, default=str).encode()
    digest = hashlib.sha256(payload).hexdigest()[:32]
    return f'tenant-cache:{namespace}:{namespace_version(namespace)}:{digest}'


def branch_scope(request) -> str:
    """Key fragment for endpoints that are branch-scoped per user.

    Admins see every branch (optionally narrowed by ``?branch_id=``), other
    roles are locked to the branch on their staff profile.
    """
    from config.branch_scope import BRANCH_ADMIN_BYPASS_ROLES, get_user_branch

    user = getattr(request, 'user', None)
    role = getattr(user, 'role', '')
    if getattr(user, 'is_superuser', False) or role in BRANCH_ADMIN_BYPASS_ROLES:
        params = request.query_params
        return params.get('branch_id') or params.get('branch') or 'all'
    return str(get_user_branch(user) or 'none')


def _request_from(args):
    """Find the request in a DRF view / viewset-action call signature."""
    for candidate in args[:2]:
        if hasattr(candidate, 'query_params') and hasattr(candidate, 'method'):
            return candidate
        request = getattr(candidate, 'request', None)
        if request is not None and hasattr(request, 'method'):
            return request
    return None


def _plain(value):
    """Strip serializer wrappers (``ReturnDict``/``ReturnList``) so payloads pickle.

    Serializer output carries a back-reference to the serializer instance and
    its context (which may hold the request), which is neither picklable nor
    worth caching; the leaves (datetimes, decimals, UUIDs) are kept as-is so a
    cache hit serializes exactly like a cache miss.
    """
    if isinstance(value, dict):
        return {key: _plain(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_plain(item) for item in value]
    return value


def _is_cacheable(request) -> bool:
    if request is None or not is_enabled():
        return False
    if request.method not in ('GET', 'HEAD'):
        return False
    return request.query_params.get('format') not in UNCACHEABLE_FORMATS


def tenant_cache(namespace: str, timeout: int = 60, scope=None):
    """Cache a read-only DRF handler's payload per tenant.

    ``namespace`` groups payloads for invalidation, ``timeout`` is the entry's
    TTL in seconds and ``scope`` (optional) is a ``request -> str`` callable
    that captures user-dependent scoping such as branch or clinic site.
    """
    def decorator(view):
        @wraps(view)
        def wrapper(*args, **kwargs):
            request = _request_from(args)
            if not _is_cacheable(request):
                return view(*args, **kwargs)

            key = build_key(namespace, {
                'path': request.path,
                'query': sorted(request.query_params.lists()),
                'scope': scope(request) if scope else '',
            })
            cached = cache.get(key)
            if cached is not None:
                return Response(cached, headers={'X-Tenant-Cache': 'HIT'})

            response = view(*args, **kwargs)
            if isinstance(response, Response) and response.status_code == 200:
                payload = _plain(response.data)
                cache.set(key, payload, timeout)
                response.data = payload
                response['X-Tenant-Cache'] = 'MISS'
            return response

        return wrapper

    return decorator


def register_invalidation(namespaces, *models) -> None:
    """Bump ``namespaces`` whenever one of ``models`` is saved or deleted.

    Bulk ``QuerySet.update()`` / ``.delete()`` calls skip signals; those
    payloads still expire on their TTL.
    """
    from django.db.models.signals import post_delete, post_save

    namespaces = tuple(namespaces)

    def _drop(sender, **kwargs):
        for namespace in namespaces:
            invalidate(namespace)

    for model in models:
        tag = model._meta.label_lower
        post_save.connect(
            _drop, sender=model, dispatch_uid=f'tenant-cache:{tag}:save', weak=False)
        post_delete.connect(
            _drop, sender=model, dispatch_uid=f'tenant-cache:{tag}:delete', weak=False)
