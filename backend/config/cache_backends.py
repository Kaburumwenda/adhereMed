"""Cache backends used by the project.

``TenantRedisCache`` is the default backend. Two properties matter for this
multi-tenant deployment:

* every key is prefixed with the active tenant schema (django-tenants keeps it
  on ``connection.schema_name``), so a cached payload can never leak from one
  tenant's schema into another's;
* losing Redis must never take the API down — the client degrades to "cache
  miss" for a short window instead of raising.
"""
from __future__ import annotations

import logging
import time

from django.core.cache.backends.redis import RedisCache, RedisCacheClient

logger = logging.getLogger(__name__)

#: Seconds to serve uncached after a Redis failure before trying again.
RETRY_AFTER = 30


def current_schema() -> str:
    """Schema name of the active tenant (``public`` outside a tenant request)."""
    try:
        from django.db import connection
    except Exception:  # pragma: no cover - settings not configured yet
        return 'public'

    schema = getattr(connection, 'schema_name', None)
    if not schema:
        tenant = getattr(connection, 'tenant', None)
        schema = getattr(tenant, 'schema_name', None)
    return schema or 'public'


class TenantRedisCacheClient(RedisCacheClient):
    """Redis client that turns connection failures into cache misses."""

    _down_until = 0.0
    _last_error_log = 0.0

    def _guard(self, default, operation, *args):
        cls = type(self)
        if time.monotonic() < cls._down_until:
            return default
        try:
            return operation(*args)
        except (self._lib.RedisError, OSError) as exc:
            cls._down_until = time.monotonic() + RETRY_AFTER
            if time.monotonic() - cls._last_error_log > RETRY_AFTER:
                cls._last_error_log = time.monotonic()
                logger.warning(
                    'Redis cache unavailable, serving uncached responses: %s', exc)
            return default

    def add(self, key, value, timeout):
        return self._guard(False, super().add, key, value, timeout)

    def get(self, key, default):
        return self._guard(default, super().get, key, default)

    def set(self, key, value, timeout):
        return self._guard(None, super().set, key, value, timeout)

    def touch(self, key, timeout):
        return self._guard(False, super().touch, key, timeout)

    def delete(self, key):
        return self._guard(False, super().delete, key)

    def get_many(self, keys):
        return self._guard({}, super().get_many, keys)

    def has_key(self, key):
        return self._guard(False, super().has_key, key)

    def incr(self, key, delta):
        return self._guard(0, super().incr, key, delta)

    def set_many(self, data, timeout):
        return self._guard(None, super().set_many, data, timeout)

    def delete_many(self, keys):
        return self._guard(None, super().delete_many, keys)

    def clear(self):
        return self._guard(False, super().clear)


class TenantRedisCache(RedisCache):
    """Redis cache whose keys are namespaced per tenant schema."""

    def __init__(self, server, params):
        super().__init__(server, params)
        # ``RedisCache.__init__`` hardcodes the stock client class.
        self._class = TenantRedisCacheClient

    def make_key(self, key, version=None):
        return super().make_key(f'{current_schema()}:{key}', version=version)
