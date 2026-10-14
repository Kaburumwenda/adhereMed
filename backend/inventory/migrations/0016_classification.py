# Generated manually for the classification lookup + default "Routine"

from django.db import migrations, models
import django.db.models.deletion
import inventory.models


def seed_routine_and_backfill(apps, schema_editor):
    """Create the seeded "Routine" classification for this tenant and
    backfill every existing stock item so the new column is not blank."""
    Classification = apps.get_model('inventory', 'Classification')
    MedicationStock = apps.get_model('inventory', 'MedicationStock')

    routine, _ = Classification.objects.get_or_create(
        name='Routine',
        defaults={'description': 'Default classification for routine stock items.'},
    )
    MedicationStock.objects.filter(classification__isnull=True).update(classification=routine)


class Migration(migrations.Migration):

    dependencies = [
        ('inventory', '0015_roledefinition_is_system'),
    ]

    operations = [
        migrations.CreateModel(
            name='Classification',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100, unique=True)),
                ('description', models.TextField(blank=True)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
            ],
            options={
                'verbose_name_plural': 'Classifications',
                'ordering': ['name'],
            },
        ),
        migrations.AddField(
            model_name='medicationstock',
            name='classification',
            field=models.ForeignKey(
                blank=True,
                default=inventory.models._default_classification_id,
                help_text='Operational classification (Routine, Emergency, Cold Chain, …). Defaults to "Routine" when left blank.',
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='stocks',
                to='inventory.classification',
            ),
        ),
        migrations.RunPython(seed_routine_and_backfill, migrations.RunPython.noop),
    ]
