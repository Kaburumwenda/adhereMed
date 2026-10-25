from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('patients', '0009_patient_clinic_site'),
    ]

    operations = [
        migrations.AddField(
            model_name='patient',
            name='patient_category',
            field=models.CharField(
                choices=[('general', 'General'), ('paediatric', 'Paediatrics')],
                db_index=True,
                default='general',
                help_text='Clinical stream: general or paediatrics. Chosen at registration.',
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='patient',
            name='guardian_name',
            field=models.CharField(
                blank=True,
                help_text='Parent / guardian responsible for a paediatric patient.',
                max_length=255,
            ),
        ),
        migrations.AddField(
            model_name='patient',
            name='guardian_phone',
            field=models.CharField(blank=True, max_length=20),
        ),
        migrations.AddField(
            model_name='patient',
            name='guardian_relationship',
            field=models.CharField(
                blank=True,
                help_text='e.g. Mother, Father, Grandparent, Legal guardian.',
                max_length=50,
            ),
        ),
        migrations.AddField(
            model_name='patient',
            name='immunisation_status',
            field=models.CharField(
                blank=True,
                choices=[
                    ('', 'Not recorded'),
                    ('up_to_date', 'Up to date'),
                    ('due', 'Due / partial'),
                    ('overdue', 'Overdue'),
                ],
                default='',
                help_text='Immunisation state captured at paediatric registration.',
                max_length=20,
            ),
        ),
    ]
