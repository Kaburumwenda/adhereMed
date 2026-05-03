from rest_framework import serializers
from .models import Medication


class MedicationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Medication
        fields = '__all__'


class MedicationSearchSerializer(serializers.ModelSerializer):
    label = serializers.SerializerMethodField()

    class Meta:
        model = Medication
        fields = ['id', 'generic_name', 'brand_names', 'strength', 'dosage_form', 'category', 'label']

    def get_label(self, obj):
        strength = f' {obj.strength}' if obj.strength else ''
        return f'{obj.generic_name}{strength} ({obj.get_dosage_form_display()})'
