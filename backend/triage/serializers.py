from rest_framework import serializers

from .models import Triage


class TriageSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    nurse_name = serializers.CharField(source='nurse.full_name', read_only=True)
    doctor_name = serializers.CharField(source='doctor.full_name', read_only=True, default='')

    class Meta:
        model = Triage
        fields = [
            'id', 'patient', 'patient_name',
            'nurse', 'nurse_name',
            'doctor', 'doctor_name',
            'esi_level', 'suggested_esi', 'esi_override_reason',
            'chief_complaint', 'vital_signs',
            'arrival_mode', 'pain_scale', 'avpu',
            'news2_score', 'bmi',
            'allergies_confirmed', 'allergies_updated',
            'medication_history',
            'pregnancy_status', 'mental_health_screen',
            'smoking_status', 'alcohol_use', 'substance_use',
            'nutrition_screen', 'fall_risk', 'infection_risk',
            'nursing_assessment', 'interventions', 'patient_education',
            'notes', 'status', 'triage_time', 'completed_at',
        ]
        read_only_fields = ['id', 'triage_time']
        extra_kwargs = {
            'nurse': {'required': False, 'allow_null': True},
            'doctor': {'required': False, 'allow_null': True},
        }
