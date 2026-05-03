from rest_framework import serializers

from .models import Prescription, PrescriptionItem, PharmacyPrescription, PharmacyPrescriptionItem


class PrescriptionItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = PrescriptionItem
        fields = [
            'id', 'prescription', 'medication_id', 'medication_name',
            'custom_medication_name', 'is_custom',
            'dosage', 'frequency', 'duration', 'quantity', 'instructions',
        ]
        read_only_fields = ['id']


class PrescriptionSerializer(serializers.ModelSerializer):
    items = PrescriptionItemSerializer(many=True, read_only=True)
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    doctor_name = serializers.CharField(source='doctor.full_name', read_only=True)

    class Meta:
        model = Prescription
        fields = [
            'id', 'consultation', 'patient', 'patient_name',
            'doctor', 'doctor_name',
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
        ]


class PrescriptionCreateSerializer(serializers.ModelSerializer):
    items = PrescriptionItemCreateSerializer(many=True)
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    doctor_name = serializers.CharField(source='doctor.full_name', read_only=True)

    class Meta:
        model = Prescription
        fields = [
            'id', 'consultation', 'patient', 'patient_name',
            'doctor', 'doctor_name',
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
