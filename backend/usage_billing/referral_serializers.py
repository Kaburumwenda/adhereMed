from rest_framework import serializers
from .referral_models import ReferralProfile, Referral, CoinTransaction


class CoinTransactionSerializer(serializers.ModelSerializer):
    related_tenant_name = serializers.SerializerMethodField()

    class Meta:
        model = CoinTransaction
        fields = ['id', 'type', 'amount', 'reason', 'related_tenant', 'related_tenant_name', 'created_at']

    def get_related_tenant_name(self, obj):
        return obj.related_tenant.name if obj.related_tenant else None


class ReferralSerializer(serializers.ModelSerializer):
    referred_name = serializers.CharField(source='referred.name', read_only=True)
    referred_type = serializers.CharField(source='referred.type', read_only=True)
    referred_created = serializers.DateTimeField(source='referred.created_at', read_only=True)

    class Meta:
        model = Referral
        fields = [
            'id', 'referred', 'referred_name', 'referred_type', 'referred_created',
            'status', 'bonus_awarded', 'tracked_requests', 'coins_from_usage', 'created_at',
        ]


class ReferralProfileSerializer(serializers.ModelSerializer):
    tenant_name = serializers.CharField(source='tenant.name', read_only=True)

    class Meta:
        model = ReferralProfile
        fields = [
            'id', 'tenant', 'tenant_name', 'referral_code',
            'coin_balance', 'total_earned', 'total_redeemed',
            'referral_count', 'created_at',
        ]
        read_only_fields = ['tenant', 'referral_code', 'coin_balance', 'total_earned', 'total_redeemed', 'referral_count']
