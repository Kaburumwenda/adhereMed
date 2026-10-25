from django.utils import timezone
from rest_framework import serializers

from .models import CorporateClient, CorporateDocument, CorporateStaff


class CorporateStaffSerializer(serializers.ModelSerializer):
    corporate_name = serializers.CharField(source='corporate.name', read_only=True)
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True, default='')
    patient_number = serializers.CharField(source='patient.patient_number', read_only=True, default='')
    is_eligible = serializers.BooleanField(read_only=True)
    ineligibility_reason = serializers.CharField(read_only=True)
    status_label = serializers.CharField(source='get_status_display', read_only=True)
    verification_label = serializers.CharField(source='get_verification_display', read_only=True)
    document_count = serializers.SerializerMethodField()

    class Meta:
        model = CorporateStaff
        fields = [
            'id', 'corporate', 'corporate_name',
            'patient', 'patient_name', 'patient_number',
            'staff_number', 'full_name', 'relationship',
            'job_title', 'department', 'phone', 'email',
            'national_id', 'date_of_birth', 'gender',
            'annual_limit', 'valid_from', 'valid_to',
            'status', 'status_label', 'verification_status', 'verification_label',
            'is_eligible', 'ineligibility_reason',
            'verified_at', 'verified_by', 'rejection_reason',
            'document_count', 'notes', 'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'verified_at', 'verified_by', 'created_at', 'updated_at',
        ]

    def get_document_count(self, obj):
        return obj.documents.count()


class CorporateDocumentSerializer(serializers.ModelSerializer):
    corporate_name = serializers.CharField(source='corporate.name', read_only=True)
    staff_name = serializers.CharField(source='staff.full_name', read_only=True, default='')
    status_label = serializers.CharField(source='get_status_display', read_only=True)
    doc_type_label = serializers.CharField(source='get_doc_type_display', read_only=True)
    file_url = serializers.SerializerMethodField()
    is_expired = serializers.BooleanField(read_only=True)
    uploaded_by_name = serializers.CharField(source='uploaded_by.full_name', read_only=True, default='')

    class Meta:
        model = CorporateDocument
        fields = [
            'id', 'corporate', 'corporate_name', 'staff', 'staff_name',
            'doc_type', 'doc_type_label', 'title', 'file', 'file_url', 'reference',
            'issued_at', 'expires_at', 'is_expired',
            'status', 'status_label', 'verified_at', 'verified_by',
            'rejection_reason', 'notes', 'uploaded_by', 'uploaded_by_name',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'status', 'verified_at', 'verified_by', 'uploaded_by',
            'created_at', 'updated_at',
        ]

    def get_file_url(self, obj):
        if not obj.file:
            return ''
        request = self.context.get('request')
        try:
            url = obj.file.url
        except Exception:
            return ''
        return request.build_absolute_uri(url) if request else url


class CorporateClientSerializer(serializers.ModelSerializer):
    status_label = serializers.CharField(source='get_status_display', read_only=True)
    contract_valid = serializers.BooleanField(read_only=True)
    is_verified = serializers.BooleanField(read_only=True)
    can_cover_treatment = serializers.BooleanField(read_only=True)
    active_staff_count = serializers.IntegerField(read_only=True)
    staff_total = serializers.SerializerMethodField()
    pending_document_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = CorporateClient
        fields = [
            'id', 'name', 'code', 'registration_number', 'industry',
            'contact_person', 'contact_phone', 'contact_email', 'address',
            'discount_rate', 'payment_terms_days', 'credit_limit',
            'annual_limit_per_staff',
            'contract_start', 'contract_end', 'contract_valid',
            'status', 'status_label', 'is_active', 'is_verified',
            'can_cover_treatment', 'verified_at', 'verified_by',
            'active_staff_count', 'staff_total', 'pending_document_count',
            'notes', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'verified_at', 'verified_by', 'created_at', 'updated_at']

    def get_staff_total(self, obj):
        return obj.staff.count()


class CorporateVerificationSerializer(serializers.Serializer):
    """Input for matching a visiting patient against the corporate roster."""

    staff_number = serializers.CharField(required=False, allow_blank=True, default='')
    first_name = serializers.CharField(required=False, allow_blank=True, default='')
    last_name = serializers.CharField(required=False, allow_blank=True, default='')
    full_name = serializers.CharField(required=False, allow_blank=True, default='')
    date_of_birth = serializers.DateField(required=False, allow_null=True)
    national_id = serializers.CharField(required=False, allow_blank=True, default='')
    phone = serializers.CharField(required=False, allow_blank=True, default='')
    patient = serializers.IntegerField(required=False, allow_null=True)


def _norm(value):
    return str(value or '').strip().lower()


def verify_corporate_patient(corporate, data):
    """Match patient details against the corporate roster.

    Returns a dict with the outcome plus a per-check breakdown so reception can
    see exactly which detail did not line up.
    """
    checks = []

    contract_ok = corporate.can_cover_treatment
    checks.append({
        'key': 'corporate',
        'label': 'Corporate active & contract valid',
        'passed': contract_ok,
        'detail': (
            f'{corporate.name} is active and in contract.'
            if contract_ok else
            f'{corporate.name} cannot cover treatment: '
            f'{corporate.get_status_display().lower()}'
            + ('' if corporate.contract_valid else ', contract out of window')
            + ('.' if corporate.is_active else ' and inactive.')
        ),
    })

    staff_number = _norm(data.get('staff_number'))
    national_id = _norm(data.get('national_id'))
    phone = _norm(data.get('phone'))
    dob = data.get('date_of_birth')
    first = _norm(data.get('first_name'))
    last = _norm(data.get('last_name'))
    full = _norm(data.get('full_name')) or ' '.join(p for p in [first, last] if p)

    roster = corporate.staff.select_related('patient__user').all()

    match = None
    matched_by = ''
    if staff_number:
        match = roster.filter(staff_number__iexact=staff_number).first()
        matched_by = 'staff number' if match else ''
    if not match and national_id:
        match = roster.filter(national_id__iexact=national_id).first()
        matched_by = 'national ID' if match else ''
    if not match and full:
        match = roster.filter(full_name__iexact=data.get('full_name') or '').first()
        if not match:
            # Fall back to a contains match on the composed name.
            for row in roster:
                if full in _norm(row.full_name) or _norm(row.full_name) in full:
                    match = row
                    break
        matched_by = 'name' if match else ''
    if not match and phone:
        match = roster.filter(phone__iexact=data.get('phone') or '').first()
        matched_by = 'phone' if match else ''

    checks.append({
        'key': 'roster',
        'label': 'Employee found on the staff roster',
        'passed': bool(match),
        'detail': (
            f'Matched on {matched_by}: {match.full_name} ({match.staff_number}).'
            if match else
            'No matching employee on this corporate roster. Ask the company to '
            'upload the staff record, or check the job card number.'
        ),
    })

    if match:
        eligible = match.is_eligible
        checks.append({
            'key': 'eligibility',
            'label': 'Employee cover is valid today',
            'passed': eligible,
            'detail': 'Cover is active for treatment.' if eligible else match.ineligibility_reason,
        })

        if dob and match.date_of_birth:
            passed = match.date_of_birth == dob
            checks.append({
                'key': 'dob',
                'label': 'Date of birth matches the roster',
                'passed': passed,
                'detail': (
                    'Date of birth confirmed.'
                    if passed else
                    f'Roster shows {match.date_of_birth:%d %b %Y} — confirm the identity '
                    'before billing the company.'
                ),
            })

        if national_id and match.national_id:
            passed = _norm(match.national_id) == national_id
            checks.append({
                'key': 'national_id',
                'label': 'National ID matches the roster',
                'passed': passed,
                'detail': 'ID confirmed.' if passed else 'ID on the roster is different.',
            })

        verified_docs = match.documents.filter(status=CorporateDocument.Status.VERIFIED).count()
        corporate_docs = corporate.documents.filter(
            doc_type__in=[
                CorporateDocument.DocType.CONTRACT,
                CorporateDocument.DocType.AUTH_LETTER,
            ],
            status=CorporateDocument.Status.VERIFIED,
        ).count()
        doc_ok = bool(verified_docs or corporate_docs)
        checks.append({
            'key': 'documents',
            'label': 'Verification document on file',
            'passed': doc_ok,
            'detail': (
                'A verified job card or corporate authorisation is on file.'
                if doc_ok else
                'Upload the job card or the company authorisation letter to complete '
                'verification.'
            ),
        })

    verified = all(c['passed'] for c in checks)

    if verified:
        if not corporate.verified_at:
            corporate.status = CorporateClient.Status.ACTIVE
            corporate.verified_at = timezone.now()
            corporate.save(update_fields=['status', 'verified_at'])
        if match and match.verification_status != CorporateStaff.Verification.VERIFIED:
            match.verification_status = CorporateStaff.Verification.VERIFIED
            match.verified_at = match.verified_at or timezone.now()
            match.save(update_fields=['verification_status', 'verified_at'])

    return {
        'verified': verified,
        'corporate': CorporateClientSerializer(corporate).data,
        'staff': CorporateStaffSerializer(match).data if match else None,
        'staff_id': match.id if match else None,
        'matched_by': matched_by,
        'checks': checks,
        'message': (
            'Corporate and patient details verified — treatment can be billed to the company.'
            if verified else
            'Verification incomplete. Review the checks below with the patient.'
        ),
    }
