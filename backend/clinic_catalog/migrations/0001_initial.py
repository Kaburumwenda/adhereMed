from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name='ClinicAllergy',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(db_index=True, max_length=255)),
                ('category', models.CharField(blank=True, db_index=True, max_length=40)),
                ('description', models.TextField(blank=True)),
                ('common_symptoms', models.TextField(blank=True)),
                ('source', models.CharField(choices=[('seed', 'Seeded'), ('custom', 'Custom')], db_index=True, default='custom', max_length=10)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'verbose_name': 'Clinic allergy',
                'verbose_name_plural': 'Clinic allergies',
                'ordering': ['category', 'name'],
            },
        ),
        migrations.CreateModel(
            name='ClinicChronicCondition',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(db_index=True, max_length=255)),
                ('category', models.CharField(blank=True, db_index=True, max_length=40)),
                ('icd_code', models.CharField(blank=True, db_index=True, max_length=20)),
                ('description', models.TextField(blank=True)),
                ('source', models.CharField(choices=[('seed', 'Seeded'), ('custom', 'Custom')], db_index=True, default='custom', max_length=10)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'verbose_name': 'Clinic chronic condition',
                'verbose_name_plural': 'Clinic chronic conditions',
                'ordering': ['category', 'name'],
            },
        ),
        migrations.AddConstraint(
            model_name='clinicallergy',
            constraint=models.UniqueConstraint(fields=('name',), name='uniq_clinic_allergy_name'),
        ),
        migrations.AddConstraint(
            model_name='clinicchroniccondition',
            constraint=models.UniqueConstraint(fields=('name',), name='uniq_clinic_condition_name'),
        ),
    ]
