"""Resolution helpers shared by the API and the aggregation endpoints."""

from __future__ import annotations

from .models import ClinicSite


def get_hq_site() -> ClinicSite | None:
    """Return the tenant's HQ site, if one exists."""
    return ClinicSite.objects.filter(is_hq=True).first()


def get_default_site() -> ClinicSite | None:
    """HQ when present, otherwise the oldest active site."""
    hq = get_hq_site()
    if hq:
        return hq
    return ClinicSite.objects.filter(is_active=True).order_by('created_at').first()


def ensure_hq_site(profile=None) -> ClinicSite:
    """Guarantee the tenant has an HQ site, bootstrapping it if necessary.

    The HQ inherits the legacy ``PharmacyDetail`` facility profile so existing
    single-clinic deployments keep their name, address, hours and licence.
    """
    hq = get_hq_site()
    if hq:
        if profile is not None and hq.profile_id is None:
            hq.profile = profile
            hq.save(update_fields=['profile', 'updated_at'])
        return hq

    if profile is None:
        try:
            from pharmacy_profile.models import PharmacyDetail
            profile = PharmacyDetail.objects.order_by('created_at').first()
        except Exception:  # noqa: BLE001 - profile app is optional in tests
            profile = None

    name = 'HQ Clinic'
    payload = {
        'name': name,
        'code': 'HQ',
        'kind': ClinicSite.Kind.HQ,
        'is_hq': True,
        'is_active': True,
        'profile': profile,
    }
    if profile is not None:
        payload.update({
            'name': profile.name or name,
            'address': getattr(profile, 'address', '') or '',
            'phone': getattr(profile, 'phone', '') or '',
            'email': getattr(profile, 'email', '') or '',
            'license_number': profile.license_number or '',
            'opening_hours': profile.operating_hours or {},
            'services': profile.services or [],
        })
        # PharmacyDetail carries no address/phone/email fields in every
        # deployment; fall back to the linked branch when present.
        try:
            from pharmacy_profile.models import Branch
            branch = Branch.objects.filter(is_main=True).first() or Branch.objects.first()
            if branch:
                payload.setdefault('address', branch.address or '')
                payload['place_name'] = payload.get('place_name') or branch.place_name or ''
                payload['phone'] = payload.get('phone') or branch.phone or ''
                payload['email'] = payload.get('email') or branch.email or ''
                payload['latitude'] = branch.latitude
                payload['longitude'] = branch.longitude
        except Exception:  # noqa: BLE001
            pass

    # Fall back to the tenant record — a brand-new clinic has no profile row yet.
    try:
        from django.db import connection
        tenant = getattr(connection, 'tenant', None)
        if tenant is not None and getattr(tenant, 'schema_name', '') != 'public':
            payload['name'] = payload.get('name') if payload.get('name') != name \
                else (tenant.name or name)
            payload['address'] = payload.get('address') or (tenant.address or '')
            payload['place_name'] = payload.get('place_name') or (tenant.place_name or '')
            payload['city'] = tenant.city or ''
            payload['phone'] = payload.get('phone') or (tenant.phone or '')
            payload['email'] = payload.get('email') or (tenant.email or '')
            payload['latitude'] = tenant.latitude or payload.get('latitude')
            payload['longitude'] = tenant.longitude or payload.get('longitude')
    except Exception:  # noqa: BLE001
        pass

    # Drop keys the model does not have (defensive across profile revisions).
    valid = {f.name for f in ClinicSite._meta.get_fields() if getattr(f, 'concrete', False)}
    payload = {k: v for k, v in payload.items() if k in valid or k == 'profile'}

    if not payload['name']:
        payload['name'] = name
    return ClinicSite.objects.create(**payload)


def resolve_site(value) -> ClinicSite | None:
    """Resolve an ``?site=`` value (id, code, ``hq`` or ``all``)."""
    if value in (None, '', 'all', 'any'):
        return None
    text = str(value).strip()
    if text.lower() in ('hq', 'default'):
        return get_default_site()
    if text.isdigit():
        return ClinicSite.objects.filter(pk=int(text)).first()
    return (
        ClinicSite.objects.filter(code__iexact=text).first()
        or ClinicSite.objects.filter(name__iexact=text).first()
    )


def site_from_request(request) -> ClinicSite | None:
    """Resolve the active site from the request.

    Precedence: ``?site=`` → ``X-Clinic-Site`` header → none (tenant-wide).
    """
    if request is None:
        return None
    value = None
    try:
        value = request.query_params.get('site') or request.query_params.get('clinic_site')
    except AttributeError:
        value = None
    if not value:
        value = request.headers.get('X-Clinic-Site')
    return resolve_site(value)


def scope_to_site(queryset, site, field='clinic_site'):
    """Filter a queryset to ``site``; rows with no site count as HQ.

    Records created before multi-clinic support (``clinic_site IS NULL``) are
    attributed to the HQ, so filtering by HQ must include them.
    """
    if site is None:
        return queryset
    root = field.split('__')[0]
    if name_has_field(queryset.model, root):
        from django.db.models import Q
        if site.is_hq:
            return queryset.filter(Q(**{field: site}) | Q(**{f'{field}__isnull': True}))
        return queryset.filter(**{field: site})
    return queryset


def name_has_field(model, field: str) -> bool:
    return any(f.name == field for f in model._meta.get_fields())

def sites_snapshot() -> list[dict]:
    """Lightweight site list embedded in dashboard/analytics payloads."""
    rows = ClinicSite.objects.order_by('-is_hq', 'name')
    return [
        {
            'id': site.id,
            'name': site.name,
            'code': site.code,
            'kind': site.kind,
            'is_hq': site.is_hq,
            'is_active': site.is_active,
            'place_name': site.place_name,
        }
        for site in rows
    ]