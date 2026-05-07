from rest_framework import serializers
from .models import Medication, DrugInteraction


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


class DrugInteractionSerializer(serializers.ModelSerializer):
    drug_a_name = serializers.CharField(source='drug_a.generic_name', read_only=True)
    drug_b_name = serializers.CharField(source='drug_b.generic_name', read_only=True)

    class Meta:
        model = DrugInteraction
        fields = '__all__'

    def validate(self, data):
        a = data.get('drug_a')
        b = data.get('drug_b')
        if a and b and a.id == b.id:
            raise serializers.ValidationError('drug_a and drug_b must be different.')
        # canonicalize: smaller id first to keep pair unique regardless of input order
        if a and b and a.id > b.id:
            data['drug_a'], data['drug_b'] = b, a
        return data

