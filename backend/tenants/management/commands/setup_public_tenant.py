from django.core.management.base import BaseCommand
from tenants.models import Tenant, Domain
from accounts.models import User


class Command(BaseCommand):
    help = 'Create the public tenant and super admin user'

    def add_arguments(self, parser):
        parser.add_argument('--email', type=str, default='admin@afyaone.com')
        parser.add_argument('--password', type=str, default='admin123456')

    def handle(self, *args, **options):
        if Tenant.objects.filter(schema_name='public').exists():
            self.stdout.write(self.style.WARNING('Public tenant already exists.'))
            return

        tenant = Tenant.objects.create(
            name='AfyaOne Platform',
            type=Tenant.TenantType.HOSPITAL,
            slug='public',
            schema_name='public',
        )
        Domain.objects.create(
            domain='localhost',
            tenant=tenant,
            is_primary=True,
        )
        self.stdout.write(self.style.SUCCESS(f'Public tenant created: {tenant}'))

        email = options['email']
        password = options['password']

        if not User.objects.filter(email=email).exists():
            user = User.objects.create_superuser(
                email=email,
                password=password,
                first_name='Super',
                last_name='Admin',
            )
            self.stdout.write(self.style.SUCCESS(f'Super admin created: {user.email}'))
        else:
            self.stdout.write(self.style.WARNING(f'User {email} already exists.'))
