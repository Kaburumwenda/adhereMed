from django.contrib import admin

from .models import SalesOrder


@admin.register(SalesOrder)
class SalesOrderAdmin(admin.ModelAdmin):
    list_display = ('so_number', 'customer_name', 'status', 'payment_status',
                    'total_amount', 'amount_paid', 'branch', 'created_at')
    list_filter = ('status', 'payment_status', 'branch')
    search_fields = ('so_number', 'customer_name', 'customer_phone')
