"""Add free-text vehicle note to StockTransfer (manual vehicle entry)."""
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('inventory', '0020_transfer_cargo_assignment_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='stocktransfer',
            name='assigned_vehicle_note',
            field=models.CharField(
                blank=True, default='', max_length=255,
                help_text='Free-text vehicle description when no fleet vehicle is linked.',
            ),
        ),
    ]
