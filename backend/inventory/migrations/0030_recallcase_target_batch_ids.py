from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('inventory', '0029_transfer_line_lots_and_shortage'),
    ]

    operations = [
        migrations.AddField(
            model_name='recallcase',
            name='target_batch_ids',
            field=models.JSONField(
                blank=True,
                default=list,
                help_text=('Specific StockBatch rows picked in the recall '
                           'dialog. Empty means "every batch that matches the '
                           'lot number / medication name" — the whole-lot '
                           'behaviour.'),
            ),
        ),
    ]
