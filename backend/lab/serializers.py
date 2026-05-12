from rest_framework import serializers

from .models import (
    LabTestCatalog, LabOrder, LabResult, HomeSampleVisit,
    LabPanel, ReferringFacility, ReferringDoctor, Instrument,
    Specimen, QualityControlRun,
    LabInvoice, LabInvoiceItem, LabInvoicePayment,
    ReportTemplate, LabOrderExtra, LabResultAudit,
    LabReagent, ReagentLot, ReagentTransaction,
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


class LabResultSerializer(serializers.ModelSerializer):
    test_name = serializers.CharField(source='test.name', read_only=True)
    performed_by_name = serializers.CharField(source='performed_by.full_name', read_only=True)
    verified_by_name = serializers.CharField(source='verified_by.full_name', read_only=True)

    class Meta:
        model = LabResult
        fields = [
            'id', 'order', 'test', 'test_name',
            'result_value', 'unit', 'is_abnormal', 'comments',
            'performed_by', 'performed_by_name',
            'verified_by', 'verified_by_name',
            'result_date',
        ]
        read_only_fields = ['id', 'result_date']


class LabOrderSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    ordered_by_name = serializers.CharField(source='ordered_by.full_name', read_only=True)
    results = LabResultSerializer(many=True, read_only=True)
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
            'tests', 'test_ids', 'test_names',
            'status', 'priority', 'clinical_notes',
            'is_home_collection',
            'recurrence_frequency_days', 'recurrence_end_date',
            'next_collection_date',
            'results', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'ordered_by', 'tests', 'created_at', 'updated_at']

    def get_test_names(self, obj):
        return list(obj.tests.values_list('name', flat=True))


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
