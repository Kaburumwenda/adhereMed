from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('patients', '0010_patient_paediatric'),
    ]

    operations = [
        migrations.AddField(
            model_name='patient',
            name='latitude',
            field=models.DecimalField(
                blank=True, decimal_places=6, max_digits=9, null=True,
                help_text='Latitude of the patient home address (Google Places).',
            ),
        ),
        migrations.AddField(
            model_name='patient',
            name='longitude',
            field=models.DecimalField(
                blank=True, decimal_places=6, max_digits=9, null=True,
                help_text='Longitude of the patient home address (Google Places).',
            ),
        ),
        migrations.AddField(
            model_name='patient',
            name='address_place_id',
            field=models.CharField(blank=True, default='', max_length=255,
                                   help_text='Google Places place_id for the saved address (re-resolution).'),
        ),
    ]
