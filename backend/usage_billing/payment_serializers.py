from rest_framework import serializers

from .payment_models import (
    MpesaTransaction,
    PaymentGatewayConfig,
    TenantWallet,
    WalletTransaction,
)


class PaymentGatewayConfigSerializer(serializers.ModelSerializer):
    updated_by_email = serializers.CharField(source="updated_by.email", read_only=True)

    class Meta:
        model = PaymentGatewayConfig
        fields = [
            "id",
            "name",
            "stk_push_url",
            "confirm_url",
            "source",
            "is_active",
            "request_timeout_seconds",
            "poll_interval_seconds",
            "updated_by",
            "updated_by_email",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "updated_by", "updated_by_email", "created_at", "updated_at"]


class PaymentMethodSerializer(serializers.Serializer):
    key = serializers.CharField()
    label = serializers.CharField()
    description = serializers.CharField()
    icon = serializers.CharField()
    available = serializers.BooleanField()


class TenantWalletSerializer(serializers.ModelSerializer):
    class Meta:
        model = TenantWallet
        fields = ["id", "balance", "currency", "updated_at"]
        read_only_fields = fields


class WalletTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = WalletTransaction
        fields = [
            "id",
            "type",
            "amount",
            "balance_after",
            "reason",
            "related_bill",
            "created_at",
        ]
        read_only_fields = fields


class MpesaTransactionSerializer(serializers.ModelSerializer):
    tenant_name = serializers.CharField(source="tenant.name", read_only=True)
    tenant_schema = serializers.CharField(source="tenant.schema_name", read_only=True)
    purpose_display = serializers.CharField(source="get_purpose_display", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    bill_period = serializers.CharField(source="bill.period_label", read_only=True, default=None)

    class Meta:
        model = MpesaTransaction
        fields = [
            "id",
            "tenant",
            "tenant_name",
            "tenant_schema",
            "purpose",
            "purpose_display",
            "bill",
            "bill_period",
            "phone",
            "amount",
            "currency",
            "checkout_request_id",
            "status",
            "status_display",
            "result_code",
            "result_desc",
            "applied",
            "created_at",
            "completed_at",
        ]
        read_only_fields = fields
