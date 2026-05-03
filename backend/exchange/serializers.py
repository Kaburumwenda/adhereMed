from rest_framework import serializers
from .models import PrescriptionExchange, PharmacyQuote, PatientOrder, LabOrderExchange


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
