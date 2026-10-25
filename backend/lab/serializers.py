from rest_framework import serializers
from django.utils import timezone

from .models import (
    LabTestCatalog, LabOrder, LabResult, HomeSampleVisit,
    LabPanel, ReferringFacility, ReferringDoctor, Instrument,
    Specimen, QualityControlRun,
    LabInvoice, LabInvoiceItem, LabInvoicePayment,
    ReportTemplate, LabOrderExtra, LabResultAudit,
    LabReagent, ReagentLot, ReagentTransaction,
    LabStaffProfile, LabOrderAuthorization, LabAuthorizationEvent,
    ALLOWED_RESULT_ATTACHMENT_TYPES, MAX_RESULT_ATTACHMENT_BYTES,
    attachment_kind,
)


class LabTestCatalogSerializer(serializers.ModelSerializer):
    class Meta:
        model = LabTestCatalog
        fields = [
            'id', 'name', 'code', 'department', 'specimen_type',
            'reference_ranges', 'price', 'turnaround_time',
            'instructions', 'is_active',
        ]
        read_only_fields = ['id']


# ===================== Demo seed (review + selective apply) =====================


class SeedEntrySerializer(serializers.Serializer):
    """One template entry, merged with this clinic's own overrides."""

    kind = serializers.CharField()
    code = serializers.CharField()
    name = serializers.CharField(allow_blank=True)
    department = serializers.CharField(allow_blank=True, required=False)
    specimen_type = serializers.CharField(allow_blank=True, required=False)
    turnaround_time = serializers.CharField(allow_blank=True, required=False)
    instructions = serializers.CharField(allow_blank=True, required=False)
    description = serializers.CharField(allow_blank=True, required=False)
    reference_ranges = serializers.DictField(required=False)
    price = serializers.FloatField(required=False)
    test_codes = serializers.ListField(
        child=serializers.CharField(), required=False,
    )

    is_selected = serializers.BooleanField(default=True)
    is_customized = serializers.BooleanField(default=False)
    is_dismissed = serializers.BooleanField(default=False)
    is_applied = serializers.BooleanField(default=False)
    is_locked = serializers.BooleanField(default=False)
    existing_id = serializers.IntegerField(allow_null=True, required=False)
    existing_name = serializers.CharField(allow_null=True, required=False, allow_blank=True)
    defaults = serializers.DictField(required=False)


class SeedApplySerializer(serializers.Serializer):
    """Payload for writing the chosen entries into the clinic catalogue."""

    tests = SeedEntrySerializer(many=True, required=False, default=list)
    panels = SeedEntrySerializer(many=True, required=False, default=list)

    def validate(self, attrs):
        if not attrs.get('tests') and not attrs.get('panels'):
            raise serializers.ValidationError(
                'Select at least one test or panel to add.'
            )
        return attrs


class LabResultSerializer(serializers.ModelSerializer):
    test_name = serializers.CharField(source='test.name', read_only=True)
    performed_by_name = serializers.CharField(source='performed_by.full_name', read_only=True)
    verified_by_name = serializers.CharField(source='verified_by.full_name', read_only=True)
    attachment_kind = serializers.SerializerMethodField()
    attachment_name = serializers.CharField(read_only=True)
    attachment_type = serializers.CharField(read_only=True)
    attachment_size = serializers.IntegerField(read_only=True)

    class Meta:
        model = LabResult
        fields = [
            'id', 'order', 'test', 'test_name',
            'result_value', 'unit', 'is_abnormal', 'comments',
            'attachment', 'attachment_name', 'attachment_type',
            'attachment_size', 'attachment_kind',
            'performed_by', 'performed_by_name',
            'verified_by', 'verified_by_name',
            'result_date',
        ]
        read_only_fields = ['id', 'result_date']
        extra_kwargs = {'attachment': {'required': False, 'allow_null': True}}

    def get_attachment_kind(self, obj):
        return attachment_kind(obj.attachment_type, obj.attachment_name)

    def validate_attachment(self, upload):
        """Optional PDF/image scan — cap the size and reject executables."""
        if upload in (None, ''):
            return upload
        mime = (getattr(upload, 'content_type', '') or '').split(';')[0].strip().lower()
        if mime not in ALLOWED_RESULT_ATTACHMENT_TYPES:
            raise serializers.ValidationError(
                'Upload a PDF or an image (JPG, PNG, WEBP, TIFF, HEIC).'
            )
        if (getattr(upload, 'size', 0) or 0) > MAX_RESULT_ATTACHMENT_BYTES:
            limit_mb = MAX_RESULT_ATTACHMENT_BYTES // (1024 * 1024)
            raise serializers.ValidationError(f'File is larger than {limit_mb} MB.')
        return upload

    def create(self, validated_data):
        upload = validated_data.get('attachment')
        instance = super().create(validated_data)
        if upload:
            instance.stow_attachment(upload)
            instance.save(update_fields=['attachment_name', 'attachment_type', 'attachment_size'])
        return instance

    def update(self, instance, validated_data):
        upload = validated_data.get('attachment', serializers.empty)
        instance = super().update(instance, validated_data)
        if upload is not serializers.empty:
            instance.stow_attachment(upload)
            instance.save(update_fields=['attachment_name', 'attachment_type', 'attachment_size'])
        return instance


class LabOrderSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    ordered_by_name = serializers.CharField(source='ordered_by.full_name', read_only=True)
    clinic_site_name = serializers.CharField(source='clinic_site.name', read_only=True, default=None)
    results = LabResultSerializer(many=True, read_only=True)
    authorization = serializers.SerializerMethodField()
    is_verified = serializers.SerializerMethodField()
    verified_at = serializers.SerializerMethodField()
    performed_at = serializers.SerializerMethodField()
    turnaround = serializers.SerializerMethodField()
    test_ids = serializers.PrimaryKeyRelatedField(
        queryset=LabTestCatalog.objects.all(),
        many=True, write_only=True, source='tests',
    )
    test_names = serializers.SerializerMethodField()

    class Meta:
        model = LabOrder
        fields = [
            'id', 'consultation', 'patient', 'patient_name',
            'ordered_by', 'ordered_by_name',
            'clinic_site', 'clinic_site_name',
            'tests', 'test_ids', 'test_names',
            'status', 'priority', 'clinical_notes',
            'is_home_collection',
            'recurrence_frequency_days', 'recurrence_end_date',
            'next_collection_date',
            'results', 'authorization',
            'is_verified', 'verified_at', 'performed_at', 'turnaround',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'ordered_by', 'tests', 'created_at', 'updated_at']

    def get_test_names(self, obj):
        return list(obj.tests.values_list('name', flat=True))

    def _authorization(self, obj):
        try:
            return obj.authorization
        except LabOrderAuthorization.DoesNotExist:
            return None

    def get_authorization(self, obj):
        """Current bench sign-offs, or null when nobody has signed yet."""
        authorization = self._authorization(obj)
        if authorization is None:
            return None
        return LabOrderAuthorizationSerializer(authorization, context=self.context).data

    def get_is_verified(self, obj):
        """True only when a verifier has signed the report."""
        authorization = self._authorization(obj)
        return bool(authorization and authorization.verified_at)

    def get_verified_at(self, obj):
        authorization = self._authorization(obj)
        return authorization.verified_at if authorization else None

    def get_performed_at(self, obj):
        authorization = self._authorization(obj)
        return authorization.performed_at if authorization else None

    def get_turnaround(self, obj):
        """Flat turnaround block so the list table needs no nested lookup.

        Orders nobody has signed yet still have a running clock — it starts at
        ``created_at`` — so the list can show how long they have been waiting.
        """
        authorization = self._authorization(obj)
        if authorization is not None:
            return LabOrderAuthorizationSerializer(
                authorization, context=self.context,
            ).data.get('turnaround')

        started = obj.created_at
        if not started:
            return None
        target = LabOrderAuthorization.TURNAROUND_TARGETS.get(
            obj.priority, LabOrderAuthorization.TURNAROUND_TARGETS['routine'],
        )
        seconds = max(0, int((timezone.now() - started).total_seconds()))
        return {
            'started_at': started,
            'verified_at': None,
            'seconds': seconds,
            'target_seconds': target,
            'pct': min(999, round(seconds / target * 100)) if target else 0,
            'state': 'overdue' if seconds > target else 'running',
            'is_verified': False,
        }


# ===================== Bench authorisation serializers =====================


def _signature_url(field):
    """URL for a signature file, or None when nothing is on file."""
    if not field:
        return None
    try:
        return field.url
    except (ValueError, AttributeError):
        return None


class LabOrderAuthorizationSerializer(serializers.ModelSerializer):
    performed = serializers.SerializerMethodField()
    verified = serializers.SerializerMethodField()
    is_complete = serializers.BooleanField(read_only=True)
    turnaround = serializers.SerializerMethodField()

    class Meta:
        model = LabOrderAuthorization
        fields = [
            'id', 'order', 'performed', 'verified', 'is_complete', 'turnaround',
            'created_at', 'updated_at',
        ]
        read_only_fields = fields

    def get_turnaround(self, obj):
        """Pending → verified timing, for the turnaround column and bar.

        ``seconds`` is frozen at verification time (or computed live for orders
        still awaiting a signature), and ``pct`` expresses it against the
        priority target so the UI can colour the bar.
        """
        seconds = obj.elapsed_seconds
        target = obj.turnaround_target_seconds or obj.target_seconds()
        pct = min(999, round(seconds / target * 100)) if target else 0
        if obj.is_verified:
            state = 'overdue' if seconds > target else 'verified'
        else:
            state = 'overdue' if seconds > target else 'running'
        return {
            'started_at': obj.started_at,
            'verified_at': obj.verified_at,
            'seconds': seconds,
            'target_seconds': target,
            'pct': pct,
            'state': state,
            'is_verified': obj.is_verified,
        }

    def get_performed(self, obj):
        if not obj.performed_at:
            return None
        return {
            'name': obj.performed_by_name,
            'title': obj.performed_by_title,
            'user_id': obj.performed_by_id,
            'signed_at': obj.performed_at,
            'signature': _signature_url(obj.performed_signature),
            'identity': obj.performed_identity or 'password',
            'notes': obj.performed_notes,
        }

    def get_verified(self, obj):
        if not obj.verified_at:
            return None
        return {
            'name': obj.verified_by_name,
            'title': obj.verified_by_title,
            'user_id': obj.verified_by_id,
            'signed_at': obj.verified_at,
            'signature': _signature_url(obj.verified_signature),
            'identity': obj.verified_identity or 'password',
            'notes': obj.verified_notes,
        }


class LabAuthorizationEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = LabAuthorizationEvent
        fields = [
            'id', 'order', 'role', 'action', 'user', 'user_name',
            'user_title', 'notes', 'ip_address', 'created_at',
        ]
        read_only_fields = fields


class LabStaffProfileSerializer(serializers.ModelSerializer):
    """Bench roster entry — enough to render the picker in the dialog."""

    full_name = serializers.CharField(source='user.full_name', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)
    role = serializers.CharField(source='user.role', read_only=True)
    role_label = serializers.CharField(source='user.get_role_display', read_only=True)
    avatar_initials = serializers.SerializerMethodField()
    signature_url = serializers.SerializerMethodField()
    has_signature = serializers.BooleanField(read_only=True)
    is_me = serializers.SerializerMethodField()
    performed_count = serializers.SerializerMethodField()
    verified_count = serializers.SerializerMethodField()

    class Meta:
        model = LabStaffProfile
        fields = [
            'id', 'user', 'full_name', 'email', 'role', 'role_label',
            'avatar_initials', 'title', 'signature_url', 'has_signature',
            'is_me', 'signature_updated_at', 'can_perform', 'can_verify', 'is_active',
            'performed_count', 'verified_count',
        ]
        read_only_fields = fields

    def get_is_me(self, obj):
        """True when this roster entry is the signed-in user.

        Those staff can sign with just their signature — the session is the
        proof of identity. Everyone else must also re-enter their password.
        """
        request = self.context.get('request')
        user = getattr(request, 'user', None)
        return bool(user and getattr(user, 'is_authenticated', False) and user.pk == obj.user_id)

    def get_avatar_initials(self, obj):
        parts = [p for p in [
            getattr(obj.user, 'first_name', ''),
            getattr(obj.user, 'last_name', ''),
        ] if p]
        return ''.join(p[0].upper() for p in parts[:2]) or '?'

    def get_signature_url(self, obj):
        return _signature_url(obj.signature)

    def get_performed_count(self, obj):
        return LabOrderAuthorization.objects.filter(
            performed_by=obj.user, performed_at__isnull=False,
        ).count()

    def get_verified_count(self, obj):
        return LabOrderAuthorization.objects.filter(
            verified_by=obj.user, verified_at__isnull=False,
        ).count()


class HomeSampleVisitSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    assigned_lab_tech_name = serializers.CharField(
        source='assigned_lab_tech.full_name', read_only=True,
    )
    scheduled_by_name = serializers.CharField(source='scheduled_by.full_name', read_only=True)

    class Meta:
        model = HomeSampleVisit
        fields = [
            'id', 'lab_order', 'patient', 'patient_name',
            'assigned_lab_tech', 'assigned_lab_tech_name',
            'scheduled_by', 'scheduled_by_name',
            'scheduled_date', 'scheduled_time',
            'patient_address', 'address_place_name',
            'address_latitude', 'address_longitude',
            'status', 'notes',
            'completed_at', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']


# ===================== Lab Tenant serializers =====================


class LabPanelSerializer(serializers.ModelSerializer):
    test_ids = serializers.PrimaryKeyRelatedField(
        queryset=LabTestCatalog.objects.all(), many=True,
        write_only=True, source='tests', required=False,
    )
    test_names = serializers.SerializerMethodField()

    class Meta:
        model = LabPanel
        fields = [
            'id', 'name', 'code', 'department', 'description',
            'tests', 'test_ids', 'test_names', 'price',
            'is_active', 'created_at',
        ]
        read_only_fields = ['id', 'tests', 'created_at']

    def get_test_names(self, obj):
        return list(obj.tests.values_list('name', flat=True))


class ReferringFacilitySerializer(serializers.ModelSerializer):
    class Meta:
        model = ReferringFacility
        fields = [
            'id', 'name', 'contact_person', 'phone', 'email',
            'address', 'discount_percent', 'is_active', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class ReferringDoctorSerializer(serializers.ModelSerializer):
    facility_name = serializers.CharField(source='facility.name', read_only=True)

    class Meta:
        model = ReferringDoctor
        fields = [
            'id', 'full_name', 'facility', 'facility_name',
            'license_no', 'specialty', 'phone', 'email',
            'commission_percent', 'is_active', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class InstrumentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Instrument
        fields = [
            'id', 'name', 'serial_no', 'manufacturer', 'model',
            'department', 'status', 'location',
            'last_service_date', 'next_service_date',
            'notes', 'is_active', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class SpecimenSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(
        source='lab_order.patient.user.full_name', read_only=True,
    )
    collected_by_name = serializers.CharField(
        source='collected_by.full_name', read_only=True,
    )
    received_by_name = serializers.CharField(
        source='received_by.full_name', read_only=True,
    )

    class Meta:
        model = Specimen
        fields = [
            'id', 'accession_number', 'barcode', 'lab_order',
            'patient_name', 'specimen_type', 'container_type',
            'volume_ml', 'collected_at', 'collected_by', 'collected_by_name',
            'received_at', 'received_by', 'received_by_name',
            'status', 'rejection_reason', 'storage_location',
            'notes', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class QualityControlRunSerializer(serializers.ModelSerializer):
    instrument_name = serializers.CharField(source='instrument.name', read_only=True)
    test_name = serializers.CharField(source='test.name', read_only=True)
    performed_by_name = serializers.CharField(
        source='performed_by.full_name', read_only=True,
    )

    class Meta:
        model = QualityControlRun
        fields = [
            'id', 'instrument', 'instrument_name',
            'test', 'test_name',
            'qc_level', 'lot_number',
            'expected_value', 'measured_value', 'sd', 'result',
            'performed_by', 'performed_by_name',
            'comments', 'run_at',
        ]
        read_only_fields = ['id', 'run_at']


class LabInvoiceItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = LabInvoiceItem
        fields = [
            'id', 'invoice', 'test', 'panel', 'description',
            'qty', 'unit_price', 'discount', 'amount',
        ]
        read_only_fields = ['id', 'amount']


class LabInvoicePaymentSerializer(serializers.ModelSerializer):
    received_by_name = serializers.CharField(
        source='received_by.full_name', read_only=True,
    )

    class Meta:
        model = LabInvoicePayment
        fields = [
            'id', 'invoice', 'method', 'amount', 'reference',
            'received_by', 'received_by_name', 'received_at', 'notes',
        ]
        read_only_fields = ['id', 'received_at']


class LabInvoiceSerializer(serializers.ModelSerializer):
    items = LabInvoiceItemSerializer(many=True, read_only=True)
    payments = LabInvoicePaymentSerializer(many=True, read_only=True)
    patient_name = serializers.CharField(
        source='patient.user.full_name', read_only=True,
    )
    referring_facility_name = serializers.CharField(
        source='referring_facility.name', read_only=True,
    )
    balance = serializers.DecimalField(
        max_digits=12, decimal_places=2, read_only=True,
    )

    class Meta:
        model = LabInvoice
        fields = [
            'id', 'invoice_number', 'lab_order',
            'patient', 'patient_name',
            'payer_type', 'insurance_scheme',
            'referring_facility', 'referring_facility_name',
            'subtotal', 'discount', 'tax', 'total',
            'amount_paid', 'balance', 'status', 'notes',
            'items', 'payments',
            'created_by', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_by', 'balance', 'created_at', 'updated_at']


class ReportTemplateSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReportTemplate
        fields = [
            'id', 'name', 'department',
            'header_html', 'footer_html',
            'signatory_name', 'signatory_title', 'signatory_signature',
            'is_default', 'is_active', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class LabOrderExtraSerializer(serializers.ModelSerializer):
    panel_ids = serializers.PrimaryKeyRelatedField(
        queryset=LabPanel.objects.all(), many=True,
        write_only=True, source='panels', required=False,
    )

    class Meta:
        model = LabOrderExtra
        fields = [
            'id', 'lab_order', 'accession_number',
            'referring_doctor', 'referring_facility',
            'panels', 'panel_ids', 'payer_type', 'notes_for_lab',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'panels', 'created_at', 'updated_at']


class LabResultAuditSerializer(serializers.ModelSerializer):
    changed_by_name = serializers.CharField(
        source='changed_by.full_name', read_only=True,
    )

    class Meta:
        model = LabResultAudit
        fields = [
            'id', 'result', 'changed_by', 'changed_by_name',
            'previous_value', 'new_value', 'reason', 'changed_at',
        ]
        read_only_fields = ['id', 'changed_at']


class ReagentLotSerializer(serializers.ModelSerializer):
    reagent_name = serializers.CharField(source='reagent.name', read_only=True)
    received_by_name = serializers.CharField(
        source='received_by.full_name', read_only=True,
    )
    effective_expiry = serializers.SerializerMethodField()
    days_to_expiry = serializers.SerializerMethodField()

    class Meta:
        model = ReagentLot
        fields = [
            'id', 'reagent', 'reagent_name', 'lot_number',
            'received_date', 'opened_date', 'expiry_date',
            'open_stability_days', 'effective_expiry', 'days_to_expiry',
            'initial_quantity', 'quantity_on_hand',
            'location', 'status',
            'received_by', 'received_by_name',
            'notes', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_effective_expiry(self, obj):
        from datetime import timedelta
        candidates = []
        if obj.expiry_date:
            candidates.append(obj.expiry_date)
        if obj.opened_date and obj.open_stability_days:
            candidates.append(obj.opened_date + timedelta(days=obj.open_stability_days))
        return min(candidates).isoformat() if candidates else None

    def get_days_to_expiry(self, obj):
        from datetime import date, timedelta
        eff = self.get_effective_expiry(obj)
        if not eff:
            return None
        d = date.fromisoformat(eff)
        return (d - date.today()).days


class ReagentTransactionSerializer(serializers.ModelSerializer):
    performed_by_name = serializers.CharField(
        source='performed_by.full_name', read_only=True,
    )
    lot_number = serializers.CharField(source='lot.lot_number', read_only=True)
    reagent_name = serializers.CharField(source='lot.reagent.name', read_only=True)

    class Meta:
        model = ReagentTransaction
        fields = [
            'id', 'lot', 'lot_number', 'reagent_name',
            'txn_type', 'quantity', 'reason', 'reference',
            'performed_by', 'performed_by_name', 'performed_at',
        ]
        read_only_fields = ['id', 'performed_at']


class LabReagentSerializer(serializers.ModelSerializer):
    instrument_name = serializers.CharField(source='instrument.name', read_only=True)
    quantity_on_hand = serializers.SerializerMethodField()
    active_lot_count = serializers.SerializerMethodField()
    nearest_expiry = serializers.SerializerMethodField()
    stock_status = serializers.SerializerMethodField()
    lots = ReagentLotSerializer(many=True, read_only=True)

    class Meta:
        model = LabReagent
        fields = [
            'id', 'name', 'code', 'catalog_no', 'manufacturer', 'supplier',
            'category', 'storage', 'department',
            'instrument', 'instrument_name',
            'unit', 'pack_size', 'unit_cost',
            'reorder_level', 'reorder_qty',
            'msds_url', 'hazard_class', 'is_controlled',
            'notes', 'is_active',
            'quantity_on_hand', 'active_lot_count', 'nearest_expiry', 'stock_status',
            'lots',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_quantity_on_hand(self, obj):
        from decimal import Decimal
        total = Decimal('0')
        for lot in obj.lots.all():
            if lot.status in ('active', 'quarantine'):
                total += lot.quantity_on_hand or Decimal('0')
        return str(total)

    def get_active_lot_count(self, obj):
        return sum(1 for l in obj.lots.all() if l.status == 'active')

    def get_nearest_expiry(self, obj):
        dates = [l.expiry_date for l in obj.lots.all()
                 if l.expiry_date and l.status in ('active', 'quarantine')]
        return min(dates).isoformat() if dates else None

    def get_stock_status(self, obj):
        from decimal import Decimal
        total = Decimal(self.get_quantity_on_hand(obj))
        if total <= 0:
            return 'out'
        if obj.reorder_level and total <= obj.reorder_level:
            return 'low'
        return 'ok'
