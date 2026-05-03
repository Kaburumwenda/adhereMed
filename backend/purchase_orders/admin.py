from django.contrib import admin
from .models import PurchaseOrder, GoodsReceivedNote


@admin.register(PurchaseOrder)
class PurchaseOrderAdmin(admin.ModelAdmin):
    list_display = ('po_number', 'supplier', 'total_cost', 'status', 'order_date')
    list_filter = ('status',)


@admin.register(GoodsReceivedNote)
class GoodsReceivedNoteAdmin(admin.ModelAdmin):
    list_display = ('grn_number', 'purchase_order', 'received_by', 'received_date')
