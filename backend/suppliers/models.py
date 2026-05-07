from django.db import models


class Supplier(models.Model):
    name = models.CharField(max_length=255)
    contact_person = models.CharField(max_length=255, blank=True)
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True)
    address = models.TextField(blank=True)
    payment_terms = models.CharField(max_length=100, blank=True, help_text='e.g., Net 30')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class SupplierItem(models.Model):
    """An item that a supplier provides. May reference an existing stock item
    or be entered manually (for items not yet in stock)."""
    supplier = models.ForeignKey(
        Supplier, on_delete=models.CASCADE, related_name='items',
    )
    stock = models.ForeignKey(
        'inventory.MedicationStock', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='supplier_items',
        help_text='Linked stock item; null for manually-entered items.',
    )
    item_name = models.CharField(
        max_length=255,
        help_text='Cached display name (auto-filled from stock or entered manually).',
    )
    unit_cost = models.DecimalField(
        max_digits=12, decimal_places=2, default=0,
        help_text='Supplier purchase price per unit.',
    )
    unit_price = models.DecimalField(
        max_digits=12, decimal_places=2, default=0,
        help_text='Recommended selling price per unit.',
    )
    quantity = models.DecimalField(
        max_digits=12, decimal_places=2, default=0,
        help_text='Typical supply quantity per order.',
    )
    notes = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['item_name']

    def __str__(self):
        return f'{self.supplier.name} – {self.item_name}'
