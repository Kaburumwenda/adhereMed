"""Add tenant schema provisioning bookkeeping.

New tenants are created with the public rows committed immediately and the
schema built in the background, so the tenant row needs to record where that
background work got to. Existing rows default to "ready" because their schema
was created synchronously.
"""
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('tenants', '0008_tenant_branding_colors'),
    ]

    operations = [
        migrations.AddField(
            model_name='tenant',
            name='provisioning_status',
            field=models.CharField(
                choices=[
                    ('pending', 'Pending'),
                    ('provisioning', 'Provisioning'),
                    ('ready', 'Ready'),
                    ('failed', 'Failed'),
                ],
                db_index=True,
                default='ready',
                help_text='Lifecycle of the tenant schema. Not "ready" means the '
                          'schema is still being built in the background.',
                max_length=16,
            ),
        ),
        migrations.AddField(
            model_name='tenant',
            name='provisioning_error',
            field=models.TextField(
                blank=True,
                default='',
                help_text='Last provisioning failure, if any.',
            ),
        ),
        migrations.AddField(
            model_name='tenant',
            name='provisioning_started_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='tenant',
            name='provisioning_completed_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
