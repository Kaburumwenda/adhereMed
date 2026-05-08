"""
Management command to create test hospital and pharmacy tenants
with domains pointing to localhost subdomains for development.
"""
from django.core.management.base import BaseCommand
from tenants.models import Tenant, Domain


class Command(BaseCommand):
    help = 'Create test hospital and pharmacy tenants for local development'

    def handle(self, *args, **options):
        # --- Hospital Tenant ---
        hospital, created = Tenant.objects.get_or_create(
            schema_name='hospital_demo',
            defaults={
                'name': 'Demo Hospital',
                'type': 'hospital',
                'slug': 'demo-hospital',
                'city': 'Nairobi',
                'country': 'Kenya',
                'phone': '+254700000001',
                'email': 'admin@demohospital.local',
            },
        )
        if created:
            self.stdout.write(self.style.SUCCESS(f'Created hospital tenant: {hospital.name}'))
        else:
            self.stdout.write(f'Hospital tenant already exists: {hospital.name}')

        Domain.objects.get_or_create(
            domain='hospital.localhost',
            defaults={'tenant': hospital, 'is_primary': True},
        )

        # --- Pharmacy Tenant ---
        pharmacy, created = Tenant.objects.get_or_create(
            schema_name='pharmacy_demo',
            defaults={
                'name': 'Demo Pharmacy',
                'type': 'pharmacy',
                'slug': 'demo-pharmacy',
                'city': 'Nairobi',
                'country': 'Kenya',
                'phone': '+254700000002',
                'email': 'admin@demopharmacy.local',
            },
        )
        if created:
            self.stdout.write(self.style.SUCCESS(f'Created pharmacy tenant: {pharmacy.name}'))
        else:
            self.stdout.write(f'Pharmacy tenant already exists: {pharmacy.name}')

        Domain.objects.get_or_create(
            domain='pharmacy.localhost',
            defaults={'tenant': pharmacy, 'is_primary': True},
        )

        # --- Homecare Tenant ---
        homecare, created = Tenant.objects.get_or_create(
            schema_name='homecare_demo',
            defaults={
                'name': 'Demo Homecare',
                'type': 'homecare',
                'slug': 'demo-homecare',
                'city': 'Nairobi',
                'country': 'Kenya',
                'phone': '+254700000003',
                'email': 'admin@demohomecare.local',
            },
        )
        if created:
            self.stdout.write(self.style.SUCCESS(f'Created homecare tenant: {homecare.name}'))
        else:
            self.stdout.write(f'Homecare tenant already exists: {homecare.name}')

        Domain.objects.get_or_create(
            domain='homecare.localhost',
            defaults={'tenant': homecare, 'is_primary': True},
        )

        self.stdout.write(self.style.SUCCESS(
            '\nDone! Use these domains:\n'
            '  Hospital: http://hospital.localhost:8000\n'
            '  Pharmacy: http://pharmacy.localhost:8000\n'
            '  Homecare: http://homecare.localhost:8000\n'
            '  Public:   http://localhost:8000\n'
        ))
