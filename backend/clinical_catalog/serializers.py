from rest_framework import serializers
from .models import Allergy, ChronicCondition


class AllergySerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(source='get_category_display', read_only=True)

    class Meta:
        model = Allergy
        fields = [
            'id', 'name', 'category', 'category_display',
            'description', 'common_symptoms', 'is_active',
        ]


class ChronicConditionSerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(source='get_category_display', read_only=True)

    class Meta:
        model = ChronicCondition
        fields = [
            'id', 'name', 'category', 'category_display',
            'icd_code', 'description', 'is_active',
        ]
