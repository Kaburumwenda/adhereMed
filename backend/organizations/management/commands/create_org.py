"""Create an organization and link existing tenants + designate an org admin.

Usage:
    python manage.py create_org \
        --name "Demo Health Group" \
        --slug demo-health \
        --tenants inventory_demo,clinic_demo \
        --admin-email admin@demoims.local
"""
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from tenants.models import Tenant
from organizations.models import Organization, OrganizationMembership

User = get_user_model()


class Command(BaseCommand):
    help = 'Create an organization, link tenants, and designate an org admin.'

    def add_arguments(self, parser):
        parser.add_argument('--name', required=True, help='Organization name')
        parser.add_argument('--slug', required=True, help='URL slug (unique)')
        parser.add_argument('--tenants', required=True,
                            help='Comma-separated tenant schema_names to link')
        parser.add_argument('--admin-email', required=True,
                            help='Email of existing user to designate as org admin')
        parser.add_argument('--address', default='', help='Address (optional)')

    def handle(self, *args, **options):
        name = options['name']
        slug = options['slug']
        schema_names = [s.strip() for s in options['tenants'].split(',') if s.strip()]
        admin_email = options['admin_email']

        # Create or get org
        org, created = Organization.objects.get_or_create(
            slug=slug,
            defaults={'name': name, 'address': options.get('address', '')},
        )
        if created:
            self.stdout.write(self.style.SUCCESS(
                f'Created organization "{name}" (slug={slug})'))
        else:
            self.stdout.write(self.style.WARNING(
                f'Organization "{name}" already exists (slug={slug})'))

        # Link tenants
        linked = []
        for schema_name in schema_names:
            try:
                tenant = Tenant.objects.get(schema_name=schema_name)
            except Tenant.DoesNotExist:
                self.stdout.write(self.style.ERROR(
                    f'  Tenant "{schema_name}" not found — skipping.'))
                continue
            membership, mk = OrganizationMembership.objects.get_or_create(
                organization=org, tenant=tenant,
                defaults={'is_active': True},
            )
            if mk:
                self.stdout.write(self.style.SUCCESS(
                    f'  Linked tenant: {tenant.name} ({schema_name})'))
            else:
                self.stdout.write(self.style.WARNING(
                    f'  Already linked: {tenant.name} ({schema_name})'))
            linked.append(tenant.name)

        # Designate org admin
        try:
            admin_user = User.objects.get(email=admin_email)
        except User.DoesNotExist:
            raise CommandError(f'User "{admin_email}" not found.')

        admin_user.organization = org
        admin_user.is_org_admin = True
        admin_user.save(update_fields=['organization', 'is_org_admin'])
        self.stdout.write(self.style.SUCCESS(
            f'  Designated "{admin_email}" as org admin.'))

        self.stdout.write(self.style.SUCCESS(
            f'\nDone. Org "{name}" has {len(linked)} tenant(s): '
            f'{", ".join(linked)}'))
