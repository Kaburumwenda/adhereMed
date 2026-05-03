from rest_framework import serializers

from .models import Triage


class TriageSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    nurse_name = serializers.CharField(source='nurse.full_name', read_only=True)

    class Meta:
        model = Triage
        fields = [
            'id', 'patient', 'patient_name',
            'nurse', 'nurse_name',
            'esi_level', 'chief_complaint', 'vital_signs',
            'arrival_mode', 'pain_scale', 'notes', 'triage_time',
        ]
        read_only_fields = ['id', 'triage_time']
