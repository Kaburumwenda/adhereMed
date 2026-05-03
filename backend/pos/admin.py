from django.contrib import admin
from .models import POSTransaction, TransactionItem


class TransactionItemInline(admin.TabularInline):
    model = TransactionItem
    extra = 0


@admin.register(POSTransaction)
class POSTransactionAdmin(admin.ModelAdmin):
    list_display = ('transaction_number', 'customer_name', 'total', 'payment_method', 'cashier', 'created_at')
    list_filter = ('payment_method',)
    inlines = [TransactionItemInline]
