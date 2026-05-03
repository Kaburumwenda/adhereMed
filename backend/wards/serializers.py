from rest_framework import serializers

from .models import Ward, Bed, Admission


class BedSerializer(serializers.ModelSerializer):
    ward_name = serializers.CharField(source='ward.name', read_only=True)

    class Meta:
        model = Bed
        fields = ['id', 'ward', 'ward_name', 'bed_number', 'status']
        read_only_fields = ['id']


class WardSerializer(serializers.ModelSerializer):
    available_beds = serializers.IntegerField(read_only=True)
    beds = BedSerializer(many=True, read_only=True)

    class Meta:
        model = Ward
        fields = [
            'id', 'name', 'type', 'floor', 'capacity',
            'daily_rate', 'is_active', 'available_beds', 'beds',
        ]
        read_only_fields = ['id']


class AdmissionSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    bed_label = serializers.CharField(source='bed.__str__', read_only=True)
    admitting_doctor_name = serializers.CharField(
        source='admitting_doctor.full_name', read_only=True,
    )

    class Meta:
        model = Admission
        fields = [
            'id', 'patient', 'patient_name',
            'bed', 'bed_label',
            'admitting_doctor', 'admitting_doctor_name',
            'admission_date', 'discharge_date',
            'reason', 'discharge_summary', 'status',
            'created_at',
        ]
        read_only_fields = ['id', 'created_at']
