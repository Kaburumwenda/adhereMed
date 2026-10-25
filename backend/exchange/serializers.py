from rest_framework import serializers
from .models import (
    PrescriptionExchange, PharmacyQuote, PatientOrder, LabOrderExchange,
    PatientLabRecord,
)


class PharmacyQuoteSerializer(serializers.ModelSerializer):
    class Meta:
        model = PharmacyQuote
        fields = '__all__'


class PrescriptionExchangeSerializer(serializers.ModelSerializer):
    quotes = PharmacyQuoteSerializer(many=True, read_only=True)
    lowest_quote = serializers.SerializerMethodField()

    class Meta:
        model = PrescriptionExchange
        fields = '__all__'

    def get_lowest_quote(self, obj):
        quote = obj.quotes.filter(status='quoted').order_by('total_cost').first()
        if quote:
            return PharmacyQuoteSerializer(quote).data
        return None


class PatientOrderSerializer(serializers.ModelSerializer):
    class Meta:
        model = PatientOrder
        fields = '__all__'
        read_only_fields = ['order_number', 'patient_user_id', 'patient_name',
                            'pharmacy_name', 'subtotal', 'total', 'status']


class LabOrderExchangeSerializer(serializers.ModelSerializer):
    class Meta:
        model = LabOrderExchange
        fields = '__all__'
        read_only_fields = ['id', 'created_at', 'updated_at']


class PatientLabRecordSerializer(serializers.ModelSerializer):
    """One shared lab order as the patient sees it.

    Results are withheld until a verifier has signed the report — an unverified
    report is a working draft and must not reach the patient.
    """

    stage_label = serializers.CharField(source='get_stage_display', read_only=True)
    status_tone = serializers.SerializerMethodField()
    progress_pct = serializers.SerializerMethodField()
    has_report = serializers.SerializerMethodField()

    class Meta:
        model = PatientLabRecord
        fields = [
            'id', 'source_tenant_id', 'source_tenant_name',
            'source_order_id', 'order_ref',
            'patient_name', 'patient_number',
            'tests', 'priority', 'clinical_notes',
            'ordered_by_name', 'clinic_site_name', 'is_home_collection',
            'requested_on',
            'stage', 'stage_label', 'status_tone', 'progress_pct',
            'raw_status', 'stage_updated_at',
            'results', 'result_summary', 'abnormal_count',
            'performed_by_name', 'performed_at',
            'verified_by_name', 'verified_at', 'is_verified',
            'turnaround_seconds', 'has_report',
            'synced_at', 'created_at',
        ]
        read_only_fields = fields

    # Ordered pipeline used by the progress meter.
    _PIPELINE = ['requested', 'sample_collected', 'processing', 'ready', 'released']

    def get_status_tone(self, obj):
        """Colour hint for the pill."""
        return {
            'requested': 'info',
            'sample_collected': 'info',
            'processing': 'warning',
            'ready': 'success',
            'released': 'success',
            'cancelled': 'error',
        }.get(obj.stage, 'info')

    def get_progress_pct(self, obj):
        if obj.stage == 'cancelled':
            return 0
        try:
            index = self._PIPELINE.index(obj.stage)
        except ValueError:
            return 0
        return int(round((index + 1) / len(self._PIPELINE) * 100))

    def get_has_report(self, obj):
        """The report is downloadable only once it is verified."""
        return bool(obj.is_verified and obj.results)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        # Never leak a draft report — hide values until verification.
        if not instance.is_verified:
            data['results'] = []
            data['abnormal_count'] = 0
        return data
