from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('pos', '0004_add_credit_payment_method'),
    ]

    operations = [
        migrations.AddField(
            model_name='postransaction',
            name='status',
            field=models.CharField(
                choices=[
                    ('completed', 'Completed'),
                    ('cancelled', 'Cancelled'),
                    ('suspended', 'Suspended'),
                    ('pending', 'Pending'),
                ],
                default='completed',
                max_length=20,
            ),
        ),
    ]
