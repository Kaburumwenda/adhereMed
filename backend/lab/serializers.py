from rest_framework import serializers

from .models import LabTestCatalog, LabOrder, LabResult, HomeSampleVisit


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
            'patient_address', 'status', 'notes',
            'completed_at', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']
