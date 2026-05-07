from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('inventory', '0004_add_barcode_prescription_required'),
    ]

    operations = [
        migrations.AddField(
            model_name='medicationstock',
            name='discount_percent',
            field=models.DecimalField(
                max_digits=5, decimal_places=2, default=0,
                help_text='Default discount applied at POS, as a percentage (0\u2013100)',
            ),
        ),
    ]
