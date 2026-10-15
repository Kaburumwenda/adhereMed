"""
Custom tenant middleware that supports header-based tenant resolution.
In development, the Flutter app sends X-Tenant-Schema header to specify
which tenant schema to use, avoiding the need for DNS subdomains.
Falls back to standard domain-based resolution.

It also guards tenants whose schema is not ready yet. Tenant creation commits
its public rows immediately and builds the schema in the background, so there
is a window (seconds to minutes) where the tenant exists but its tables do not.
Before this guard those requests blew up with::

    ProgrammingError: relation "inventory_classification" does not exist

Now they get an explicit, actionable 503 instead.
"""
from django.db import connection
from django.http import JsonResponse
from django_tenants.middleware.main import TenantMainMiddleware
from django_tenants.utils import get_tenant_model, get_tenant_domain_model


class HeaderTenantMiddleware(TenantMainMiddleware):
    """
    Extends django-tenants middleware to allow specifying tenant via
    X-Tenant-Schema HTTP header (for development/API use).
    """

    #: Paths that stay reachable while a tenant is not ready — otherwise an
    #: administrator could not sign in or retry provisioning.
    READY_GUARD_ALLOWLIST = (
        '/api/auth/',
        '/api/tenants/',
        '/api/superadmin/',
        '/admin/',
        '/static/',
        '/media/',
    )

    #: Statuses that mean "the tenant schema is not usable yet".
    UNREADY_STATUSES = ('pending', 'provisioning', 'failed')

    def process_request(self, request):
        schema = request.META.get('HTTP_X_TENANT_SCHEMA')
        if schema:
            TenantModel = get_tenant_model()
            try:
                tenant = TenantModel.objects.get(schema_name=schema)
                request.tenant = tenant
                connection.set_tenant(tenant)
                return self._guard_provisioning(request)
            except TenantModel.DoesNotExist:
                pass

        # Fall back to standard domain-based resolution
        super().process_request(request)
        return self._guard_provisioning(request)

    def _guard_provisioning(self, request):
        """Return a 503 while the tenant's schema is still being built."""
        tenant = getattr(request, 'tenant', None)
        if tenant is None:
            return None

        # getattr keeps this safe even if the column/attribute is absent.
        status = getattr(tenant, 'provisioning_status', None)
        if status not in self.UNREADY_STATUSES:
            return None

        path = request.path or ''
        if any(path.startswith(prefix) for prefix in self.READY_GUARD_ALLOWLIST):
            return None

        # Later middleware (audit) still runs process_response, so point the
        # connection somewhere valid before we short-circuit.
        connection.set_schema_to_public()

        error = getattr(tenant, 'provisioning_error', '') or ''
        if status == 'failed':
            detail = (
                f'The workspace for "{tenant.name}" could not be prepared. '
                'Please contact support.'
            )
        else:
            detail = (
                f'The workspace for "{tenant.name}" is still being prepared. '
                'Please try again in a moment.'
            )

        return JsonResponse(
            {
                'detail': detail,
                'code': 'tenant_not_ready',
                'provisioning_status': status,
                'provisioning_error': error[:500],
                'tenant': tenant.name,
            },
            status=503,
        )
