from django.contrib import admin
from .models import Category, Unit, MedicationStock, StockBatch


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'description', 'created_at')
    search_fields = ('name',)


@admin.register(Unit)
class UnitAdmin(admin.ModelAdmin):
    list_display = ('name', 'abbreviation', 'created_at')
    search_fields = ('name', 'abbreviation')


class StockBatchInline(admin.TabularInline):
    model = StockBatch
    extra = 0


@admin.register(MedicationStock)
class MedicationStockAdmin(admin.ModelAdmin):
    list_display = ('medication_name', 'category', 'unit', 'selling_price', 'cost_price', 'total_quantity', 'reorder_level', 'is_low_stock', 'is_active')
    list_filter = ('is_active', 'category', 'unit')
    search_fields = ('medication_name',)
    inlines = [StockBatchInline]


@admin.register(StockBatch)
class StockBatchAdmin(admin.ModelAdmin):
    list_display = ('stock', 'batch_number', 'quantity_remaining', 'expiry_date', 'received_date')
    list_filter = ('expiry_date',)
