"""Add optional ``batch`` FK to ``StockTransferLine``.

Lets the create wizard pin a transfer line to a specific ``StockBatch`` so
the approver deducts from that exact batch (instead of draining FEFO).
Old transfers keep ``batch IS NULL`` and continue to work unchanged.
"""
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('inventory', '0021_transfer_vehicle_note'),
    ]

    operations = [
        migrations.AddField(
            model_name='stocktransferline',
            name='batch',
            field=models.ForeignKey(
                blank=True,
                help_text=(
                    'Optional: specific source batch to deduct from. '
                    'When null, the approver drains batches FEFO.'
                ),
                null=True,
                on_delete=models.SET_NULL,
                related_name='transfer_lines',
                to='inventory.stockbatch',
            ),
        ),
    ]
