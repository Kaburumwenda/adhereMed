from rest_framework import serializers

from .models import Department


class DepartmentSerializer(serializers.ModelSerializer):
    head_name = serializers.CharField(source='head.full_name', read_only=True)

    class Meta:
        model = Department
        fields = [
            'id', 'name', 'description', 'head', 'head_name',
            'is_active', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']
