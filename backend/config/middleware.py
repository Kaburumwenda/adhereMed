"""
Custom tenant middleware that supports header-based tenant resolution.
In development, the Flutter app sends X-Tenant-Schema header to specify
which tenant schema to use, avoiding the need for DNS subdomains.
Falls back to standard domain-based resolution.
"""
from django.db import connection
from django_tenants.middleware.main import TenantMainMiddleware
from django_tenants.utils import get_tenant_model, get_tenant_domain_model


class HeaderTenantMiddleware(TenantMainMiddleware):
    """
    Extends django-tenants middleware to allow specifying tenant via
    X-Tenant-Schema HTTP header (for development/API use).
    """

    def process_request(self, request):
        schema = request.META.get('HTTP_X_TENANT_SCHEMA')
        if schema:
            TenantModel = get_tenant_model()
            try:
                tenant = TenantModel.objects.get(schema_name=schema)
                request.tenant = tenant
                connection.set_tenant(tenant)
                return
            except TenantModel.DoesNotExist:
                pass

        # Fall back to standard domain-based resolution
        super().process_request(request)
