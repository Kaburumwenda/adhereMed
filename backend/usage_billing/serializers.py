from rest_framework import serializers

from .models import BillingRate, DailyUsage, DoctorCommissionRate, MonthlyBill


class BillingRateSerializer(serializers.ModelSerializer):
    created_by_email = serializers.CharField(source="created_by.email", read_only=True)

    class Meta:
        model = BillingRate
        fields = [
            "id",
            "requests_per_unit",
            "unit_cost",
            "currency",
            "effective_from",
            "is_active",
            "notes",
            "created_by",
            "created_by_email",
            "created_at",
        ]
        read_only_fields = ["id", "created_by", "created_by_email", "created_at"]


class DailyUsageSerializer(serializers.ModelSerializer):
    tenant_name = serializers.CharField(source="tenant.name", read_only=True)
    tenant_schema = serializers.CharField(source="tenant.schema_name", read_only=True)

    class Meta:
        model = DailyUsage
        fields = ["id", "tenant", "tenant_name", "tenant_schema", "date", "request_count", "last_updated"]


class MonthlyBillSerializer(serializers.ModelSerializer):
    tenant_name = serializers.CharField(source="tenant.name", read_only=True)
    tenant_schema = serializers.CharField(source="tenant.schema_name", read_only=True)

    class Meta:
        model = MonthlyBill
        fields = [
            "id",
            "tenant",
            "tenant_name",
            "tenant_schema",
            "year",
            "month",
            "total_requests",
            "requests_per_unit",
            "unit_cost",
            "amount",
            "currency",
            "status",
            "generated_at",
            "paid_at",
            "notes",
        ]
        read_only_fields = fields


class DoctorCommissionRateSerializer(serializers.ModelSerializer):
    created_by_email = serializers.CharField(source="created_by.email", read_only=True)

    class Meta:
        model = DoctorCommissionRate
        fields = [
            "id",
            "percentage",
            "currency",
            "effective_from",
            "is_active",
            "notes",
            "created_by",
            "created_by_email",
            "created_at",
        ]
        read_only_fields = ["id", "created_by", "created_by_email", "created_at"]
