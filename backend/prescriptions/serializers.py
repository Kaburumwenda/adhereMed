from rest_framework import serializers

from .models import Prescription, PrescriptionItem, PharmacyPrescription, PharmacyPrescriptionItem


def _doctor_profile(doctor):
    """Return the DoctorProfile for a User, or None if it doesn't exist."""
    try:
        from doctors.models import DoctorProfile
        return DoctorProfile.objects.filter(user=doctor).first()
    except Exception:
        return None


class PrescriptionItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = PrescriptionItem
        fields = [
            'id', 'prescription', 'medication_id', 'medication_name',
            'custom_medication_name', 'is_custom',
            'dosage', 'frequency', 'duration', 'quantity', 'instructions',
            'schedule', 'refills',
        ]
        read_only_fields = ['id']


class PrescriptionSerializer(serializers.ModelSerializer):
    items = PrescriptionItemSerializer(many=True, read_only=True)
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    patient_phone = serializers.CharField(source='patient.user.phone', read_only=True, default='')
    patient_email = serializers.CharField(source='patient.user.email', read_only=True, default='')
    patient_national_id = serializers.CharField(source='patient.national_id', read_only=True, default='')
    patient_allergies = serializers.JSONField(source='patient.allergies', read_only=True, default=list)
    patient_chronic_conditions = serializers.JSONField(source='patient.chronic_conditions', read_only=True, default=list)
    patient_insurance_provider = serializers.CharField(source='patient.insurance_provider', read_only=True, default='')
    patient_insurance_number = serializers.CharField(source='patient.insurance_number', read_only=True, default='')
    doctor_name = serializers.CharField(source='doctor.full_name', read_only=True)
    doctor_license_number = serializers.SerializerMethodField()
    doctor_practice_type = serializers.SerializerMethodField()
    doctor_signature_url = serializers.SerializerMethodField()

    def get_doctor_license_number(self, obj):
        profile = _doctor_profile(obj.doctor)
        return profile.license_number if profile else None

    def get_doctor_practice_type(self, obj):
        profile = _doctor_profile(obj.doctor)
        return profile.practice_type if profile else None

    def get_doctor_signature_url(self, obj):
        profile = _doctor_profile(obj.doctor)
        if not profile or not profile.signature:
            return None
        request = self.context.get('request')
        if request:
            return request.build_absolute_uri(profile.signature.url)
        return profile.signature.url

    class Meta:
        model = Prescription
        fields = [
            'id', 'consultation', 'patient', 'patient_name',
            'patient_phone', 'patient_email', 'patient_national_id',
            'patient_allergies', 'patient_chronic_conditions',
            'patient_insurance_provider', 'patient_insurance_number',
            'doctor', 'doctor_name',
            'doctor_license_number', 'doctor_practice_type', 'doctor_signature_url',
            'status', 'notes', 'items', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class PrescriptionItemCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PrescriptionItem
        fields = [
            'medication_id', 'medication_name',
            'custom_medication_name', 'is_custom',
            'dosage', 'frequency', 'duration', 'quantity', 'instructions',
            'schedule', 'refills',
        ]


class PrescriptionCreateSerializer(serializers.ModelSerializer):
    items = PrescriptionItemCreateSerializer(many=True)
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    patient_phone = serializers.CharField(source='patient.user.phone', read_only=True, default='')
    patient_email = serializers.CharField(source='patient.user.email', read_only=True, default='')
    patient_national_id = serializers.CharField(source='patient.national_id', read_only=True, default='')
    patient_allergies = serializers.JSONField(source='patient.allergies', read_only=True, default=list)
    patient_chronic_conditions = serializers.JSONField(source='patient.chronic_conditions', read_only=True, default=list)
    patient_insurance_provider = serializers.CharField(source='patient.insurance_provider', read_only=True, default='')
    patient_insurance_number = serializers.CharField(source='patient.insurance_number', read_only=True, default='')
    doctor_name = serializers.CharField(source='doctor.full_name', read_only=True)
    doctor_license_number = serializers.SerializerMethodField()
    doctor_practice_type = serializers.SerializerMethodField()
    doctor_signature_url = serializers.SerializerMethodField()

    def get_doctor_license_number(self, obj):
        profile = _doctor_profile(obj.doctor)
        return profile.license_number if profile else None

    def get_doctor_practice_type(self, obj):
        profile = _doctor_profile(obj.doctor)
        return profile.practice_type if profile else None

    def get_doctor_signature_url(self, obj):
        profile = _doctor_profile(obj.doctor)
        if not profile or not profile.signature:
            return None
        request = self.context.get('request')
        if request:
            return request.build_absolute_uri(profile.signature.url)
        return profile.signature.url

    class Meta:
        model = Prescription
        fields = [
            'id', 'consultation', 'patient', 'patient_name',
            'patient_phone', 'patient_email', 'patient_national_id',
            'patient_allergies', 'patient_chronic_conditions',
            'patient_insurance_provider', 'patient_insurance_number',
            'doctor', 'doctor_name',
            'doctor_license_number', 'doctor_practice_type', 'doctor_signature_url',
            'status', 'notes', 'items', 'created_at',
        ]
        read_only_fields = ['id', 'doctor', 'created_at']
        extra_kwargs = {
            'consultation': {'required': False, 'allow_null': True},
        }

    def create(self, validated_data):
        items_data = validated_data.pop('items')
        prescription = Prescription.objects.create(**validated_data)
        for item_data in items_data:
            PrescriptionItem.objects.create(prescription=prescription, **item_data)
        return prescription


# ─── Pharmacy Prescription Serializers ────────────────────────────────────────

class PharmacyPrescriptionItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = PharmacyPrescriptionItem
        fields = [
            'id', 'medication_name', 'stock_id',
            'dosage', 'frequency', 'duration', 'quantity', 'instructions',
        ]
        read_only_fields = ['id']


class PharmacyPrescriptionSerializer(serializers.ModelSerializer):
    items = PharmacyPrescriptionItemSerializer(many=True)
    pharmacist_name = serializers.CharField(source='pharmacist.full_name', read_only=True)

    class Meta:
        model = PharmacyPrescription
        fields = [
            'id', 'patient_name', 'patient_phone',
            'pharmacist', 'pharmacist_name',
            'notes', 'status', 'items', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'pharmacist', 'created_at', 'updated_at']

    def create(self, validated_data):
        items_data = validated_data.pop('items')
        rx = PharmacyPrescription.objects.create(**validated_data)
        for item_data in items_data:
            PharmacyPrescriptionItem.objects.create(prescription=rx, **item_data)
        return rx

    def update(self, instance, validated_data):
        items_data = validated_data.pop('items', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if items_data is not None:
            instance.items.all().delete()
            for item_data in items_data:
                PharmacyPrescriptionItem.objects.create(prescription=instance, **item_data)
        return instance
