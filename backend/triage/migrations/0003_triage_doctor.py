# Generated for adding doctor assignment to Triage
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('triage', '0002_triage_alcohol_use_triage_allergies_confirmed_and_more'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name='triage',
            name='doctor',
            field=models.ForeignKey(
                blank=True,
                help_text='Doctor assigned to receive this patient after triage',
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='triages_assigned',
                to=settings.AUTH_USER_MODEL,
            ),
        ),
    ]
