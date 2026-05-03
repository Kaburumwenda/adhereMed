from rest_framework import serializers

from .models import RadiologyOrder, RadiologyResult


class RadiologyResultSerializer(serializers.ModelSerializer):
    radiologist_name = serializers.CharField(source='radiologist.full_name', read_only=True)

    class Meta:
        model = RadiologyResult
        fields = [
            'id', 'order', 'findings', 'impression',
            'radiologist', 'radiologist_name',
            'image_url', 'result_date',
        ]
        read_only_fields = ['id', 'result_date']


class RadiologyOrderSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    ordered_by_name = serializers.CharField(source='ordered_by.full_name', read_only=True)
    result = RadiologyResultSerializer(read_only=True)

    class Meta:
        model = RadiologyOrder
        fields = [
            'id', 'consultation', 'patient', 'patient_name',
            'ordered_by', 'ordered_by_name',
            'imaging_type', 'body_part', 'clinical_indication',
            'status', 'priority', 'result', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']
