from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('audit', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='auditevent',
            name='latitude',
            field=models.DecimalField(blank=True, decimal_places=12, help_text='GPS latitude of the actor at the time of the event.', max_digits=30, null=True),
        ),
        migrations.AddField(
            model_name='auditevent',
            name='longitude',
            field=models.DecimalField(blank=True, decimal_places=12, help_text='GPS longitude of the actor at the time of the event.', max_digits=30, null=True),
        ),
    ]
