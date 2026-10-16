from django.db import migrations, models
import django.db.models.deletion
import django.conf


class Migration(migrations.Migration):

    dependencies = [
        ('purchase_orders', '0006_rfq_evaluation_reorder'),
    ]

    operations = [
        migrations.AddField(
            model_name='purchaseorder',
            name='approved_by',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='approved_purchase_orders',
                to=django.conf.settings.AUTH_USER_MODEL,
            ),
        ),
        migrations.AddField(
            model_name='purchaseorder',
            name='approved_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='purchaseorder',
            name='rejected_by',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='rejected_purchase_orders',
                to=django.conf.settings.AUTH_USER_MODEL,
            ),
        ),
        migrations.AddField(
            model_name='purchaseorder',
            name='rejected_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='purchaseorder',
            name='rejection_reason',
            field=models.TextField(blank=True, default=''),
        ),
    ]
