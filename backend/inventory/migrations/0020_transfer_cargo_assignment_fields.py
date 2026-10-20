"""Add cargo, scheduling and assignment fields to StockTransfer."""
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('inventory', '0019_rename_brand_names_to_brand_name'),
        ('logistics', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='stocktransfer',
            name='priority',
            field=models.CharField(
                choices=[('low', 'Low'), ('normal', 'Normal'), ('high', 'High'), ('urgent', 'Urgent')],
                default='normal', max_length=10,
            ),
        ),
        migrations.AddField(
            model_name='stocktransfer',
            name='parcel_count',
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='stocktransfer',
            name='weight_kg',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True),
        ),
        migrations.AddField(
            model_name='stocktransfer',
            name='scheduled_pickup',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='stocktransfer',
            name='scheduled_delivery',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='stocktransfer',
            name='assigned_driver',
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='stock_transfers',
                to='logistics.driver',
            ),
        ),
        migrations.AddField(
            model_name='stocktransfer',
            name='assigned_carrier',
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='stock_transfers',
                to='logistics.carrier',
            ),
        ),
        migrations.AddField(
            model_name='stocktransfer',
            name='assigned_vehicle',
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='stock_transfers',
                to='logistics.vehicle',
            ),
        ),
    ]
