"""Bench authorisation: identify the signer, verify their password, sign.

Most clinics run the laboratory from a single shared workstation, so the
logged-in session is often *not* the person who ran the test. Releasing a
result therefore takes three things from the bench technologist:

1. their name, picked from the roster of lab staff for this tenant,
2. their own account password (proof it is really them), and
3. a handwritten signature (drawn on the pad, uploaded, or reused from file).

Every sign-off is snapshotted onto the order and appended to an immutable
event log so a report always shows exactly what was signed and by whom.
"""
import base64
import binascii
import re
import uuid

from django.contrib.auth import authenticate
from django.core.files.base import ContentFile
from django.db import transaction
from django.utils import timezone

from .models import (
    LabAuthorizationEvent, LabOrderAuthorization, LabStaffProfile,
    MAX_SIGNATURE_BYTES, PERFORM_ROLES, SIGNATURE_IMAGE_TYPES, VERIFY_ROLES,
)

DATA_URL_RE = re.compile(r'^data:(?P<mime>[\w/+.-]+);base64,(?P<payload>.+)$', re.S)


class AuthorisationError(Exception):
    """Raised for a recoverable sign-off problem (surfaced as HTTP 400)."""

    def __init__(self, message, *, code='invalid', field=None):
        super().__init__(message)
        self.message = message
        self.code = code
        self.field = field


def decode_signature(value):
    """Turn a ``data:image/png;base64,…`` payload into an uploadable file.

    Returns ``None`` when the caller did not supply a new signature (they may
    be reusing the one already on file).
    """
    if not value:
        return None
    if not isinstance(value, str):
        raise AuthorisationError('The signature could not be read.', field='signature')

    match = DATA_URL_RE.match(value.strip())
    if not match:
        raise AuthorisationError(
            'Draw or upload a signature before signing.', field='signature',
        )
    mime = match.group('mime').lower()
    if mime not in SIGNATURE_IMAGE_TYPES:
        raise AuthorisationError(
            'Signatures must be PNG, JPEG or WEBP images.', field='signature',
        )
    try:
        raw = base64.b64decode(match.group('payload'), validate=True)
    except (binascii.Error, ValueError):
        raise AuthorisationError('The signature image is corrupt.', field='signature')

    if len(raw) > MAX_SIGNATURE_BYTES:
        raise AuthorisationError(
            f'The signature image is larger than {MAX_SIGNATURE_BYTES // (1024 * 1024)} MB.',
            field='signature',
        )
    if len(raw) < 64:
        raise AuthorisationError('The signature looks empty — please sign again.', field='signature')

    extension = {'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp'}[mime]
    return ContentFile(raw, name=f'signature-{uuid.uuid4().hex[:12]}.{extension}')


def resolve_signer(request, *, role, user_id, password):
    """Validate the selected staff member's credentials for this role.

    Two ways to prove identity:

    * **The signed-in user signing as themselves** — the JWT session is already
      proof, so only the signature is required. This is the common case and
      keeps a single technologist on one workstation fast.
    * **Anyone else at the shared bench** — the session belongs to somebody
      else, so the signer must confirm with their own account password.
    """
    if role not in {'performed', 'verified'}:
        raise AuthorisationError('Unknown sign-off role.', field='role')
    if not user_id:
        raise AuthorisationError('Select your name from the laboratory roster.', field='user_id')

    from accounts.models import User

    try:
        candidate = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        raise AuthorisationError('That staff account no longer exists.', field='user_id')

    tenant = getattr(request, 'tenant', None)
    if tenant is not None and candidate.tenant_id not in (None, tenant.id):
        raise AuthorisationError('That staff member belongs to another workspace.', field='user_id')
    if not candidate.is_active:
        raise AuthorisationError('That account is deactivated.', field='user_id')

    profile = LabStaffProfile.objects.filter(user=candidate).first()
    if profile and not profile.is_active:
        raise AuthorisationError('That staff member is not active on the lab bench.', field='user_id')

    allowed_roles = PERFORM_ROLES if role == 'performed' else VERIFY_ROLES
    can = (
        (profile.can_perform if role == 'performed' else profile.can_verify)
        if profile else True
    )
    if candidate.role not in allowed_roles and not (profile and can):
        raise AuthorisationError(
            'That staff member is not authorised to sign in this capacity.',
            field='user_id',
        )

    signed_in = getattr(request, 'user', None)
    is_self = bool(
        signed_in is not None
        and getattr(signed_in, 'is_authenticated', False)
        and signed_in.pk == candidate.pk
    )

    if not password:
        if is_self:
            return candidate, profile, LabOrderAuthorization.Identity.SESSION
        raise AuthorisationError(
            'Enter your password to sign as someone other than the signed-in user.',
            field='password',
        )

    authenticated = authenticate(request=request, email=candidate.email, password=password)
    if authenticated is None or authenticated.pk != candidate.pk:
        raise AuthorisationError('Incorrect password.', code='bad_password', field='password')

    return candidate, profile, LabOrderAuthorization.Identity.PASSWORD


def _client_ip(request):
    forwarded = request.META.get('HTTP_X_FORWARDED_FOR', '')
    if forwarded:
        return forwarded.split(',')[0].strip() or None
    return request.META.get('REMOTE_ADDR') or None


def apply_signoff(
    request, order, *, role, user, profile, signature_upload,
    title='', notes='', save_signature=False, identity='',
):
    """Write a performer/verifier sign-off onto the order and log the event."""
    now = timezone.now()
    identity = identity or LabOrderAuthorization.Identity.PASSWORD
    title = (title or '').strip()
    effective_title = title or (profile.title if profile else '') or user.get_role_display()

    # Remember the signature for next time when the staff member opted in.
    if signature_upload is not None and save_signature:
        if profile is None:
            profile = LabStaffProfile.objects.create(user=user)
        signature_upload.seek(0)
        profile.signature = signature_upload
        profile.signature_updated_at = now
        profile.title = effective_title
        profile.save(update_fields=['signature', 'signature_updated_at', 'title', 'updated_at'])

    with transaction.atomic():
        authorization, _ = LabOrderAuthorization.objects.get_or_create(order=order)
        # The turnaround clock always starts when the order entered the queue.
        if authorization.pending_at is None:
            authorization.pending_at = order.created_at or now
        if signature_upload is not None:
            # A FileField drains its input stream, so rewind before reuse.
            signature_upload.seek(0)

        if role == 'performed':
            authorization.performed_by = user
            authorization.performed_by_name = user.full_name
            authorization.performed_by_title = effective_title
            if signature_upload is not None:
                authorization.performed_signature = signature_upload
            authorization.performed_at = now
            authorization.performed_identity = identity
            authorization.performed_notes = notes or ''
            authorization.save(update_fields=[
                'performed_by', 'performed_by_name', 'performed_by_title',
                'performed_signature', 'performed_at', 'performed_identity',
                'performed_notes', 'pending_at', 'updated_at',
            ])
            order.results.update(performed_by=user)
        else:
            authorization.verified_by = user
            authorization.verified_by_name = user.full_name
            authorization.verified_by_title = effective_title
            if signature_upload is not None:
                authorization.verified_signature = signature_upload
            authorization.verified_at = now
            authorization.verified_identity = identity
            authorization.verified_notes = notes or ''
            # Freeze the turnaround so later edits can never rewrite history.
            authorization.turnaround_seconds = max(
                0, int((now - authorization.pending_at).total_seconds()),
            )
            authorization.turnaround_target_seconds = authorization.target_seconds()
            authorization.save(update_fields=[
                'verified_by', 'verified_by_name', 'verified_by_title',
                'verified_signature', 'verified_at', 'verified_identity',
                'verified_notes', 'pending_at', 'turnaround_seconds',
                'turnaround_target_seconds', 'updated_at',
            ])
            order.results.update(verified_by=user)

        LabAuthorizationEvent.objects.create(
            order=order,
            role=role,
            action=LabAuthorizationEvent.Action.SIGN,
            user=user,
            user_name=user.full_name,
            user_title=effective_title,
            notes=(notes or '')[:255],
            ip_address=_client_ip(request),
            user_agent=(request.META.get('HTTP_USER_AGENT', '') or '')[:255],
        )

    return authorization


def revoke_signoff(request, order, *, role, actor, notes=''):
    """Clear one half of the authorisation (e.g. a mis-signed report)."""
    authorization = LabOrderAuthorization.objects.filter(order=order).first()
    if authorization is None:
        raise AuthorisationError('This order has no authorisation to revoke.', code='nothing')

    with transaction.atomic():
        if role == 'performed':
            authorization.performed_by = None
            authorization.performed_by_name = ''
            authorization.performed_by_title = ''
            authorization.performed_signature = None
            authorization.performed_at = None
            authorization.performed_identity = ''
            authorization.performed_notes = ''
            authorization.save(update_fields=[
                'performed_by', 'performed_by_name', 'performed_by_title',
                'performed_signature', 'performed_at', 'performed_identity',
                'performed_notes', 'updated_at',
            ])
            order.results.update(performed_by=None)
        else:
            authorization.verified_by = None
            authorization.verified_by_name = ''
            authorization.verified_by_title = ''
            authorization.verified_signature = None
            authorization.verified_at = None
            authorization.verified_identity = ''
            authorization.verified_notes = ''
            # The clock restarts from the original queue entry time.
            authorization.turnaround_seconds = None
            authorization.turnaround_target_seconds = None
            authorization.save(update_fields=[
                'verified_by', 'verified_by_name', 'verified_by_title',
                'verified_signature', 'verified_at', 'verified_identity',
                'verified_notes', 'turnaround_seconds',
                'turnaround_target_seconds', 'updated_at',
            ])
            order.results.update(verified_by=None)

        LabAuthorizationEvent.objects.create(
            order=order,
            role=role,
            action=LabAuthorizationEvent.Action.REVOKE,
            user=actor,
            user_name=getattr(actor, 'full_name', '') or '',
            user_title=getattr(actor, 'get_role_display', lambda: '')(),
            notes=(notes or '')[:255],
            ip_address=_client_ip(request),
            user_agent=(request.META.get('HTTP_USER_AGENT', '') or '')[:255],
        )

    return authorization


def signer_roster(request, role):
    """Staff who may sign in the given capacity, ready for the picker."""
    from accounts.models import User

    allowed_roles = PERFORM_ROLES if role == 'performed' else VERIFY_ROLES
    tenant = getattr(request, 'tenant', None)

    users = User.objects.filter(is_active=True, role__in=allowed_roles)
    if tenant is not None:
        users = users.filter(tenant=tenant)
    users = users.order_by('first_name', 'last_name')

    existing = {p.user_id: p for p in LabStaffProfile.objects.filter(user__in=users)}

    roster = []
    for user in users:
        profile = existing.get(user.id)
        if profile is None:
            profile = LabStaffProfile(user=user)
        # Respect an explicit opt-out on the profile.
        if profile.pk and not (profile.can_perform if role == 'performed' else profile.can_verify):
            continue
        if profile.pk and not profile.is_active:
            continue
        roster.append(profile)
    return roster
