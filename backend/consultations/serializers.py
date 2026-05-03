from rest_framework import serializers

from .models import Consultation


class ConsultationSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    doctor_name = serializers.CharField(source='doctor.full_name', read_only=True)

    class Meta:
        model = Consultation
        fields = [
            'id', 'appointment', 'patient', 'patient_name',
            'doctor', 'doctor_name',
            'chief_complaint', 'history_present_illness',
            'examination_findings', 'diagnosis', 'treatment_plan',
            'notes', 'vital_signs',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class ConsultationDetailSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    doctor_name = serializers.CharField(source='doctor.full_name', read_only=True)
    prescriptions = serializers.SerializerMethodField()
    lab_orders = serializers.SerializerMethodField()
    radiology_orders = serializers.SerializerMethodField()

    class Meta:
        model = Consultation
        fields = [
            'id', 'appointment', 'patient', 'patient_name',
            'doctor', 'doctor_name',
            'chief_complaint', 'history_present_illness',
            'examination_findings', 'diagnosis', 'treatment_plan',
            'notes', 'vital_signs',
            'prescriptions', 'lab_orders', 'radiology_orders',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_prescriptions(self, obj):
        from prescriptions.serializers import PrescriptionSerializer
        return PrescriptionSerializer(obj.prescriptions.all(), many=True).data

    def get_lab_orders(self, obj):
        from lab.serializers import LabOrderSerializer
        return LabOrderSerializer(obj.lab_orders.all(), many=True).data

    def get_radiology_orders(self, obj):
        from radiology.serializers import RadiologyOrderSerializer
        return RadiologyOrderSerializer(obj.radiology_orders.all(), many=True).data
