from django.db import migrations, models
import django.db.models.deletion
from django.conf import settings


class Migration(migrations.Migration):

    dependencies = [
        ('dispensing', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='dispensingrecord',
            name='receipt_number',
            field=models.CharField(blank=True, max_length=30, unique=True),
        ),
        migrations.AddField(
            model_name='dispensingrecord',
            name='patient_phone',
            field=models.CharField(blank=True, max_length=30),
        ),
        migrations.AddField(
            model_name='dispensingrecord',
            name='subtotal',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=12),
        ),
        migrations.AddField(
            model_name='dispensingrecord',
            name='discount',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=12),
        ),
        migrations.AddField(
            model_name='dispensingrecord',
            name='payment_method',
            field=models.CharField(
                choices=[('cash', 'Cash'), ('mpesa', 'M-Pesa'), ('card', 'Card'),
                         ('insurance', 'Insurance'), ('credit', 'Credit / On Account')],
                default='cash', max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='dispensingrecord',
            name='paid_amount',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=12),
        ),
        migrations.AddField(
            model_name='dispensingrecord',
            name='status',
            field=models.CharField(
                choices=[('completed', 'Completed'), ('cancelled', 'Cancelled')],
                default='completed', max_length=20,
            ),
        ),
        migrations.AlterField(
            model_name='dispensingrecord',
            name='patient_user_id',
            field=models.IntegerField(blank=True, null=True, help_text='FK to User (public schema)'),
        ),
    ]
