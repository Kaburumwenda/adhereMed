# Generated for BillingSettings singleton model

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('homecare', '0032_drainline'),
    ]

    operations = [
        migrations.CreateModel(
            name='BillingSettings',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('billing_type', models.CharField(
                    choices=[('daily', 'Daily'), ('weekly', 'Weekly'),
                             ('monthly', 'Monthly'), ('quarterly', 'Quarterly'),
                             ('yearly', 'Yearly'),
                             ('manually', 'Manually (no auto-generation)')],
                    db_index=True, default='daily', max_length=16,
                    help_text='How often patient bills are auto-generated.')),
                ('auto_generate', models.BooleanField(
                    db_index=True, default=True,
                    help_text='Master switch for automatic bill generation.')),
                ('last_run_at', models.DateTimeField(
                    blank=True, null=True,
                    help_text='When the auto-generate tick last ran for this tenant.')),
                ('updated_by_user_id', models.IntegerField(blank=True, null=True)),
                ('updated_by_name', models.CharField(blank=True, max_length=255)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'verbose_name': 'Billing settings',
                'verbose_name_plural': 'Billing settings',
            },
        ),
    ]
