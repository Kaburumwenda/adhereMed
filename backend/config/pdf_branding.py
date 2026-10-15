"""Shared branding resolution for PDF documents/reports.

The pharmacy/hospital logo is uploaded via /pharmacy/settings and stored on
PharmacyDetail. The Tenant model also has a logo field, so check both
before falling back to the bundled default.

Storage-agnostic: reportlab needs a real filesystem path, but S3-backed
storages raise NotImplementedError for ``FileField.path``. Non-local files are
downloaded once into a per-process temp directory and reused.
"""
import atexit
import hashlib
import os
import shutil
import tempfile

#: Downloaded non-local logos are cached here for the life of the process.
_BRANDING_CACHE_DIR = os.path.join(tempfile.gettempdir(), 'adheremed-branding')
_atexit_registered = False


def _cleanup_cache():
    shutil.rmtree(_BRANDING_CACHE_DIR, ignore_errors=True)


def _materialize(logo_source):
    """Return a local filesystem path for a stored logo, or None.

    Local-disk storage resolves via ``.path``. Remote storage (S3) does not, so
    the object is streamed to a temp file keyed by its storage name.
    """
    # 1. Local storage: use the path directly.
    try:
        path = logo_source.path
        if path and os.path.exists(path):
            return path
        return None
    except (NotImplementedError, ValueError, AttributeError, OSError):
        pass

    # 2. Remote storage: download once into the cache directory.
    name = getattr(logo_source, 'name', '') or ''
    if not name:
        return None

    global _atexit_registered
    try:
        os.makedirs(_BRANDING_CACHE_DIR, exist_ok=True)
        if not _atexit_registered:
            atexit.register(_cleanup_cache)
            _atexit_registered = True

        # Key on the full storage name — names are unique (UUID-suffixed), and
        # hashing avoids path separator issues.
        digest = hashlib.sha1(name.encode('utf-8')).hexdigest()[:16]
        suffix = os.path.splitext(name)[1]
        destination = os.path.join(_BRANDING_CACHE_DIR, digest + suffix)

        if not os.path.exists(destination):
            with logo_source.open('rb') as source, open(destination, 'wb') as out:
                shutil.copyfileobj(source, out)
        return destination if os.path.exists(destination) else None
    except Exception:
        return None


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
        logo_path = _materialize(logo_source)
        if logo_path:
            break
    if not logo_path:
        logo_path = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            '..', 'purchase_orders', 'assets', 'hos_default.png',
        )
        logo_path = os.path.normpath(logo_path)

    business_name = (getattr(profile, 'name', '') or
                     (getattr(tenant, 'name', '') if tenant else '') or '')
    return logo_path, business_name
