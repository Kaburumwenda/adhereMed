from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('pos', '0003_add_branch_to_postransaction'),
    ]

    operations = [
        migrations.AlterField(
            model_name='postransaction',
            name='payment_method',
            field=models.CharField(
                choices=[
                    ('cash', 'Cash'),
                    ('card', 'Card'),
                    ('mpesa', 'M-Pesa'),
                    ('insurance', 'Insurance'),
                    ('credit', 'Credit'),
                ],
                default='cash',
                max_length=20,
            ),
        ),
    ]
