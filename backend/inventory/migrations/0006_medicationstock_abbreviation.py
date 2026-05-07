from django.db import migrations, models


def backfill_abbreviation(apps, schema_editor):
    """Copy abbreviation from the Medication catalog to existing stock rows
    by matching on `medication_name` <-> `generic_name` (case-insensitive)."""
    MedicationStock = apps.get_model('inventory', 'MedicationStock')
    try:
        Medication = apps.get_model('medications', 'Medication')
    except LookupError:
        return

    # Build a lookup: lowercased generic_name -> abbreviation
    catalog = {
        m.generic_name.strip().lower(): m.abbreviation
        for m in Medication.objects.exclude(abbreviation='')
        if m.generic_name
    }
    if not catalog:
        return

    to_update = []
    for s in MedicationStock.objects.filter(abbreviation='').only('id', 'medication_name'):
        key = (s.medication_name or '').strip().lower()
        abbr = catalog.get(key)
        if not abbr:
            # try the first word (e.g. "Paracetamol 500mg" -> "paracetamol")
            head = key.split()[0] if key else ''
            abbr = catalog.get(head)
        if abbr:
            s.abbreviation = abbr
            to_update.append(s)
    if to_update:
        MedicationStock.objects.bulk_update(to_update, ['abbreviation'], batch_size=500)


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('inventory', '0005_medicationstock_discount_percent'),
        ('medications', '0003_medication_abbreviation'),
    ]

    operations = [
        migrations.AddField(
            model_name='medicationstock',
            name='abbreviation',
            field=models.CharField(
                blank=True,
                db_index=True,
                help_text='Short code (e.g. PCM, AMOX) for quick POS search.',
                max_length=20,
            ),
        ),
        migrations.RunPython(backfill_abbreviation, noop),
    ]
