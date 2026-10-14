from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('inventory', '0016_classification'),
    ]

    operations = [
        migrations.AddField(
            model_name='medicationstock',
            name='items_per_unit',
            field=models.PositiveIntegerField(
                default=0,
                help_text='How many individual items are inside one box/pack/strip of this stock item. '
                          'Only meaningful when the unit is a container type (e.g. box, pack, strip).',
            ),
        ),
    ]
