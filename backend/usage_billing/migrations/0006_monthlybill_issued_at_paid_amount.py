from decimal import Decimal

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('usage_billing', '0005_monthlybill_due_date'),
    ]

    operations = [
        migrations.AddField(
            model_name='monthlybill',
            name='issued_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='monthlybill',
            name='paid_amount',
            field=models.DecimalField(decimal_places=4, default=Decimal('0'), max_digits=14),
        ),
    ]
