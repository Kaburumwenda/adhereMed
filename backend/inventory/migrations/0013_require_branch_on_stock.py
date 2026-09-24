from django.db import migrations, models
import django.db.models.deletion


def backfill_branch(apps, schema_editor):
    """Assign the tenant's main warehouse to stock items that have no
    warehouse set, before the branch column becomes NOT NULL."""
    MedicationStock = apps.get_model('inventory', 'MedicationStock')
    Branch = apps.get_model('pharmacy_profile', 'Branch')

    if not MedicationStock.objects.filter(branch__isnull=True).exists():
        return

    main = (Branch.objects.filter(is_main=True).first()
            or Branch.objects.order_by('id').first())
    if main is None:
        # Tenant has stock but no warehouse at all — create a default main one.
        main = Branch.objects.create(
            name='Main Warehouse', is_main=True, is_active=True)

    MedicationStock.objects.filter(branch__isnull=True).update(branch=main)


class Migration(migrations.Migration):

    dependencies = [
        ('inventory', '0012_alter_stockadjustment_reason'),
        ('pharmacy_profile', '0011_alter_delivery_status'),
    ]

    operations = [
        migrations.RunPython(backfill_branch, migrations.RunPython.noop),
        migrations.AlterField(
            model_name='medicationstock',
            name='branch',
            field=models.ForeignKey(
                help_text='Warehouse this stock item belongs to (required)',
                on_delete=django.db.models.deletion.PROTECT,
                related_name='stocks',
                to='pharmacy_profile.branch',
            ),
        ),
    ]
