from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('usage_billing', '0004_referralprofile_cointransaction_referral'),
    ]

    operations = [
        migrations.AddField(
            model_name='monthlybill',
            name='due_date',
            field=models.DateField(
                blank=True,
                null=True,
                help_text='Date payment is due. Issued bills past this date are overdue.',
            ),
        ),
    ]
