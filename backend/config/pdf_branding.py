"""Shared branding resolution for PDF documents/reports.

The pharmacy/hospital logo is uploaded via /pharmacy/settings and stored on
PharmacyDetail. The Tenant model also has a logo field, so check both
before falling back to the bundled default.
"""
import os


def resolve_branding(request):
    """Return (logo_path, business_name) for the current tenant."""
    tenant = getattr(request, 'tenant', None)
    profile = None
    try:
        from pharmacy_profile.models import PharmacyDetail
        profile = PharmacyDetail.objects.order_by('-created_at').first()
    except Exception:
        profile = None

    logo_path = None
    for logo_source in (
        getattr(profile, 'logo', None) if profile else None,
        getattr(tenant, 'logo', None) if tenant else None,
    ):
        if not logo_source:
            continue
        try:
            path = logo_source.path
            if path and os.path.exists(path):
                logo_path = path
                break
        except Exception:
            continue
    if not logo_path:
        logo_path = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            '..', 'purchase_orders', 'assets', 'hos_default.png',
        )
        logo_path = os.path.normpath(logo_path)

    business_name = (getattr(profile, 'name', '') or
                     (getattr(tenant, 'name', '') if tenant else '') or '')
    return logo_path, business_name
