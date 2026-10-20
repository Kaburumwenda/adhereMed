"""Store digital signatures on stock transfers.

The approve ("Confirm approval & shipment") and receive dialogs capture a
hand-drawn signature and post it as a base64 PNG data-URL. Both columns are
``TextField`` to mirror ``homecare.Consent.signature_data_url``.
"""
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('inventory', '0022_transfer_line_batch'),
    ]

    operations = [
        migrations.AddField(
            model_name='stocktransfer',
            name='approved_signature',
            field=models.TextField(
                blank=True,
                default='',
                help_text="Base64 data-URL of the approver's captured signature (PNG).",
            ),
        ),
        migrations.AddField(
            model_name='stocktransfer',
            name='received_signature',
            field=models.TextField(
                blank=True,
                default='',
                help_text="Base64 data-URL of the receiver's captured signature (PNG).",
            ),
        ),
    ]
