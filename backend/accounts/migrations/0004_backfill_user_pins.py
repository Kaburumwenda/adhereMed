from django.db import migrations
import secrets


def _gen(User, length=6):
    for _ in range(50):
        candidate = ''.join(str(secrets.randbelow(10)) for _ in range(length))
        if not User.objects.filter(pin=candidate).exists():
            return candidate
    return ''.join(str(secrets.randbelow(10)) for _ in range(length + 2))


def backfill_pins(apps, schema_editor):
    User = apps.get_model('accounts', 'User')
    for user in User.objects.filter(pin__isnull=True):
        user.pin = _gen(User)
        user.save(update_fields=['pin'])


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0003_user_pin'),
    ]

    operations = [
        migrations.RunPython(backfill_pins, noop),
    ]
