from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('organizations', '0001_initial'),
        ('accounts', '0008_alter_user_role'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='organization',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='org_users',
                to='organizations.organization',
            ),
        ),
        migrations.AddField(
            model_name='user',
            name='is_org_admin',
            field=models.BooleanField(
                default=False,
                help_text='Can access the Organization Command Center and switch '
                          'between linked tenants.',
            ),
        ),
    ]
