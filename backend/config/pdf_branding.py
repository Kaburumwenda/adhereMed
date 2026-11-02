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
    """Return (logo_path, business_name) for the current tenant.

    The **tenant** logo wins: it is the org-wide mark edited at
    ``/ims/organization/profile`` (``POST /tenants/me/upload-logo/``) and is the
    same one the app shell renders, so a PDF header is never out of sync with
    what the operator sees on screen. ``PharmacyDetail.logo`` is only a
    fallback for legacy pharmacy tenants that never set the tenant logo.
    """
    tenant = getattr(request, 'tenant', None)
    profile = None
    try:
        from pharmacy_profile.models import PharmacyDetail
        profile = PharmacyDetail.objects.order_by('-created_at').first()
    except Exception:
        profile = None

    logo_path = None
    for logo_source in (
        getattr(tenant, 'logo', None) if tenant else None,
        getattr(profile, 'logo', None) if profile else None,
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

    # Same precedence for the display name.
    business_name = ((getattr(tenant, 'name', '') if tenant else '') or
                     getattr(profile, 'name', '') or '')
    return logo_path, business_name


# ─────────────────────────────────────────────────────────────────────────
# Brand palette (set at /ims/organization/branding)
# ─────────────────────────────────────────────────────────────────────────
#: Kept in sync with ``BRAND_DEFAULTS`` in ``nuxtfrontend/utils/branding.js``
#: and ``DEFAULTS`` in ``pages/organization/branding.vue`` — if these drift, a
#: tenant that never saved a palette gets a PDF in a different colour from the
#: app it is printed out of.
BRAND_DEFAULTS = {
    'primary': '#2f6dff',
    'secondary': '#143ce1',
    'accent': '#37d6ff',
}

_HEX_RE = None


def normalize_hex(value):
    """``#abc`` / ``abc`` / ``#AABBCC`` → ``#aabbcc``; ``''`` when unusable."""
    global _HEX_RE
    if _HEX_RE is None:
        import re
        _HEX_RE = re.compile(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$')

    raw = str(value or '').strip()
    if not raw:
        return ''
    match = _HEX_RE.match(raw)
    if not match:
        return ''
    digits = match.group(1).lower()
    if len(digits) == 3:
        digits = ''.join(ch * 2 for ch in digits)
    return '#' + digits


def resolve_palette(request=None, *, tenant=None):
    """Return the tenant's brand palette as reportlab ``HexColor`` objects.

    ``{'primary', 'secondary', 'accent'}`` — each read from the ``Tenant`` row
    that ``/ims/organization/branding`` writes (``brand_primary`` /
    ``brand_secondary`` / ``brand_accent``), falling back per-colour to
    :data:`BRAND_DEFAULTS` so a partially-filled palette never crashes a PDF.
    """
    from reportlab.lib.colors import HexColor

    if tenant is None:
        tenant = getattr(request, 'tenant', None)

    palette = {}
    for key, default in BRAND_DEFAULTS.items():
        raw = getattr(tenant, f'brand_{key}', '') if tenant else ''
        palette[key] = HexColor(normalize_hex(raw) or default)
    return palette


def tint(color, amount, towards='#ffffff'):
    """Blend ``color`` toward ``towards`` by ``amount`` (0–1).

    Used for the soft washes behind table headers and the letterhead's accent
    rule, so they follow the brand instead of a hard-coded slate. Returns a
    :class:`reportlab.lib.colors.Color` — ``HexColor`` only accepts integers.
    """
    from reportlab.lib.colors import Color, HexColor

    amount = max(0.0, min(1.0, float(amount)))
    other = HexColor(normalize_hex(towards) or '#ffffff')
    return Color(
        color.red + (other.red - color.red) * amount,
        color.green + (other.green - color.green) * amount,
        color.blue + (other.blue - color.blue) * amount,
    )
