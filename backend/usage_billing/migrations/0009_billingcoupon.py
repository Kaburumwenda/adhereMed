# Reconciliation migration: the usage_billing_billingcoupon table already
# exists in the database (created out-of-band by prior work). This migration
# defines the model in Django's state and is applied with --fake so the
# existing table + data are preserved.
import django.db.models.deletion
import django.utils.timezone
from decimal import Decimal
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('tenants', '0006_tenant_billing_grace_until_tenant_billing_suspended_and_more'),
        ('usage_billing', '0008_monthlybill_discount_amount_alter_monthlybill_status_and_more'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='BillingCoupon',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('code', models.CharField(max_length=50, unique=True)),
                ('description', models.TextField(blank=True)),
                ('discount_type', models.CharField(choices=[('percent', 'Percentage'), ('fixed', 'Fixed amount')], default='percent', max_length=12)),
                ('discount_value', models.DecimalField(decimal_places=2, help_text='Percentage (0-100) or fixed amount, per discount_type.', max_digits=12)),
                ('currency', models.CharField(default='KSH', max_length=8)),
                ('max_uses', models.PositiveIntegerField(default=1)),
                ('times_used', models.PositiveIntegerField(default=0)),
                ('min_bill_amount', models.DecimalField(decimal_places=2, default=Decimal('0'), help_text='Minimum bill balance required to use this coupon.', max_digits=12)),
                ('valid_from', models.DateTimeField(default=django.utils.timezone.now)),
                ('valid_until', models.DateTimeField(blank=True, null=True)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('created_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='billing_coupons_created', to=settings.AUTH_USER_MODEL)),
                ('tenant', models.ForeignKey(blank=True, help_text='Restrict to a single tenant. Leave empty for any tenant.', null=True, on_delete=django.db.models.deletion.CASCADE, related_name='billing_coupons', to='tenants.tenant')),
            ],
            options={
                'ordering': ['-created_at', '-id'],
            },
        ),
    ]
