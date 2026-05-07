from django.contrib import admin

from .models import Expense, ExpenseCategory


@admin.register(ExpenseCategory)
class ExpenseCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'is_active', 'created_at')
    search_fields = ('name',)


@admin.register(Expense)
class ExpenseAdmin(admin.ModelAdmin):
    list_display = ('reference', 'title', 'category', 'amount', 'status', 'expense_date')
    list_filter = ('status', 'payment_method', 'is_recurring', 'category')
    search_fields = ('reference', 'title', 'vendor', 'payment_reference')
    date_hierarchy = 'expense_date'
