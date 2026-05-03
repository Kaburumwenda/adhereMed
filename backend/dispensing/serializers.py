from rest_framework import serializers

from .models import DispensingRecord


class DispensingRecordSerializer(serializers.ModelSerializer):
    dispensed_by_name = serializers.CharField(source='dispensed_by.full_name', read_only=True)

    class Meta:
        model = DispensingRecord
        fields = [
            'id', 'prescription_exchange_id', 'patient_user_id',
            'patient_name', 'items_dispensed', 'total',
            'dispensed_by', 'dispensed_by_name',
            'notes', 'dispensed_at',
        ]
        read_only_fields = ['id', 'dispensed_at']
