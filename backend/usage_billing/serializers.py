from rest_framework import serializers

from .models import BillingRate, DailyUsage, DoctorCommissionRate, MonthlyBill, BillingCoupon


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
    period_label = serializers.CharField(read_only=True)
    is_overdue = serializers.BooleanField(read_only=True)
    effective_status = serializers.CharField(read_only=True)
    balance = serializers.DecimalField(max_digits=14, decimal_places=4, read_only=True)

    class Meta:
        model = MonthlyBill
        fields = [
            "id",
            "tenant",
            "tenant_name",
            "tenant_schema",
            "year",
            "month",
            "period_label",
            "total_requests",
            "requests_per_unit",
            "unit_cost",
            "amount",
            "discount_amount",
            "paid_amount",
            "balance",
            "currency",
            "status",
            "effective_status",
            "is_overdue",
            "due_date",
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


class BillingCouponSerializer(serializers.ModelSerializer):
    created_by_email = serializers.CharField(source="created_by.email", read_only=True)
    tenant_name = serializers.CharField(source="tenant.name", read_only=True, default=None)
    discount_type_display = serializers.CharField(source="get_discount_type_display", read_only=True)
    uses_remaining = serializers.IntegerField(read_only=True)

    class Meta:
        model = BillingCoupon
        fields = [
            "id", "code", "description", "tenant", "tenant_name", "discount_type",
            "discount_type_display", "discount_value", "currency", "max_uses",
            "times_used", "uses_remaining", "min_bill_amount", "valid_from",
            "valid_until", "is_active", "created_by", "created_by_email", "created_at",
        ]
        read_only_fields = [
            "id", "times_used", "uses_remaining", "created_by",
            "created_by_email", "tenant_name", "discount_type_display", "created_at",
        ]
