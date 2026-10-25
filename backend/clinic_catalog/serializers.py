from rest_framework import serializers

from .models import ClinicAllergy, ClinicChronicCondition


class ClinicAllergySerializer(serializers.ModelSerializer):
    class Meta:
        model = ClinicAllergy
        fields = ('id', 'name', 'category', 'description', 'common_symptoms',
                  'source', 'is_active', 'created_at', 'updated_at')
        read_only_fields = ('source', 'created_at', 'updated_at')


class ClinicChronicConditionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ClinicChronicCondition
        fields = ('id', 'name', 'category', 'icd_code', 'description',
                  'source', 'is_active', 'created_at', 'updated_at')
        read_only_fields = ('source', 'created_at', 'updated_at')
