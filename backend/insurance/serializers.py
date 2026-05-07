from rest_framework import serializers
from django.utils import timezone
from .models import InsuranceProvider, InsuranceClaim


class InsuranceProviderSerializer(serializers.ModelSerializer):
    open_claims = serializers.SerializerMethodField(read_only=True)
    total_outstanding = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = InsuranceProvider
        fields = '__all__'

    def get_open_claims(self, obj):
        return obj.claims.exclude(status__in=['paid', 'rejected']).count()

    def get_total_outstanding(self, obj):
        return float(sum(c.outstanding for c in obj.claims.exclude(status__in=['rejected'])))


class InsuranceClaimSerializer(serializers.ModelSerializer):
    provider_name = serializers.CharField(source='provider.name', read_only=True)
    provider_code = serializers.CharField(source='provider.code', read_only=True)
    created_by_name = serializers.SerializerMethodField(read_only=True)
    outstanding = serializers.FloatField(read_only=True)

    class Meta:
        model = InsuranceClaim
        fields = '__all__'
        read_only_fields = ('reference', 'created_by', 'created_at', 'updated_at',
                            'submitted_at', 'settled_at')

    def get_created_by_name(self, obj):
        if not obj.created_by:
            return ''
        return f'{obj.created_by.first_name} {obj.created_by.last_name}'.strip() or obj.created_by.email

    def create(self, validated_data):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            validated_data['created_by'] = request.user
        return super().create(validated_data)
