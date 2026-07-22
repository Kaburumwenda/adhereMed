from django.db import migrations, models


def backfill_patient_ids(apps, schema_editor):
    Patient = apps.get_model('patients', 'Patient')
    # Determine the current highest AD number (in case some already exist).
    max_n = 0
    for pid in Patient.objects.exclude(patient_id__isnull=True).values_list('patient_id', flat=True):
        if pid and pid.startswith('AD'):
            try:
                n = int(pid[2:])
            except (TypeError, ValueError):
                continue
            if n > max_n:
                max_n = n
    # Assign AD ids to patients missing one, ordered by creation.
    for patient in Patient.objects.filter(
        models.Q(patient_id__isnull=True) | models.Q(patient_id='')
    ).order_by('id'):
        max_n += 1
        patient.patient_id = f'AD{max_n:02d}'
        patient.save(update_fields=['patient_id'])


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('patients', '0002_national_id_unique_required'),
    ]

    operations = [
        migrations.AddField(
            model_name='patient',
            name='patient_id',
            field=models.CharField(
                blank=True, null=True, max_length=20,
                help_text='Auto-generated AdhereMed patient identifier (AD01, AD02, ...).',
            ),
        ),
        migrations.RunPython(backfill_patient_ids, noop),
        migrations.AlterField(
            model_name='patient',
            name='patient_id',
            field=models.CharField(
                blank=True, db_index=True, max_length=20, unique=True,
                help_text='Auto-generated AdhereMed patient identifier (AD01, AD02, ...).',
            ),
        ),
    ]
