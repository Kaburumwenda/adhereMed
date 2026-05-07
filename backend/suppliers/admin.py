from django.contrib import admin
from .models import Supplier, SupplierItem


class SupplierItemInline(admin.TabularInline):
    model = SupplierItem
    extra = 0


@admin.register(Supplier)
class SupplierAdmin(admin.ModelAdmin):
    list_display = ('name', 'contact_person', 'phone', 'email', 'is_active')
    search_fields = ('name',)
    inlines = [SupplierItemInline]


@admin.register(SupplierItem)
class SupplierItemAdmin(admin.ModelAdmin):
    list_display = ('item_name', 'supplier', 'unit_cost', 'unit_price', 'quantity')
    search_fields = ('item_name', 'supplier__name')
