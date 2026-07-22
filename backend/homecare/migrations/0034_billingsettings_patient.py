"""Make BillingSettings per-patient (add required patient OneToOneField)."""

from django.db import migrations, models
import django.db.models.deletion


def _clear_singleton_rows(apps, schema_editor):
    """The legacy BillingSettings table held a single tenant-wide row with no
    patient link. Drop those rows so we can add a NOT NULL patient column."""
    apps.get_model('homecare', 'BillingSettings').objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ('homecare', '0033_billingsettings'),
    ]

    operations = [
        migrations.RunPython(
            _clear_singleton_rows,
            reverse_code=migrations.RunPython.noop,
        ),
        migrations.AddField(
            model_name='billingsettings',
            name='patient',
            field=models.OneToOneField(
                on_delete=django.db.models.deletion.CASCADE,
                related_name='billing_settings',
                to='homecare.homecarepatient',
            ),
        ),
    ]
