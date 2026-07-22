"""Seed a catalog of common homecare medical equipment (with hire rates)
into every homecare-enabled tenant.

Usage:
    python manage.py seed_homecare_equipment
    python manage.py seed_homecare_equipment --schema=<schema>
    python manage.py seed_homecare_equipment --reset

Each item is seeded with hourly / daily / weekly / monthly hire rates (KES),
a refundable deposit and a default billing period, so the equipment module has
realistic rental pricing out of the box.
"""
from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone
from django_tenants.utils import schema_context, get_tenant_model

from homecare.models import Device


# name, device_type, manufacturer, model, hourly, daily, weekly, monthly,
# deposit, default_period, quantity, low_stock_threshold
EQUIPMENT = [
    ('Pulse Oximeter (Fingertip)', Device.DeviceType.OXIMETER, 'Contec', 'CMS50D',
     None, 150, 800, 2500, 2000, Device.RatePeriod.DAILY, 12, 3),
    ('Digital Blood Pressure Monitor', Device.DeviceType.BP_MONITOR, 'Omron', 'HEM-7120',
     None, 200, 1100, 3500, 3000, Device.RatePeriod.DAILY, 10, 3),
    ('Blood Glucose Monitor', Device.DeviceType.GLUCOMETER, 'Accu-Chek', 'Active',
     None, 120, 650, 2000, 1500, Device.RatePeriod.DAILY, 10, 3),
    ('Infrared Thermometer', Device.DeviceType.THERMOMETER, 'Beurer', 'FT90',
     None, 100, 500, 1500, 1000, Device.RatePeriod.DAILY, 15, 4),
    ('Oxygen Concentrator 5L', Device.DeviceType.OXYGEN_CONCENTRATOR, 'Philips', 'EverFlo',
     None, 1500, 9000, 30000, 25000, Device.RatePeriod.DAILY, 6, 2),
    ('Oxygen Concentrator 10L', Device.DeviceType.OXYGEN_CONCENTRATOR, 'Yuwell', '8F-10',
     None, 2200, 13000, 45000, 35000, Device.RatePeriod.DAILY, 4, 1),
    ('Nebulizer Machine', Device.DeviceType.NEBULIZER, 'Omron', 'NE-C101',
     None, 300, 1600, 5000, 3000, Device.RatePeriod.DAILY, 8, 2),
    ('Electric Hospital Bed (3-function)', Device.DeviceType.BED, 'Hill-Rom', '900',
     None, 2500, 15000, 45000, 40000, Device.RatePeriod.MONTHLY, 5, 1),
    ('Manual Hospital Bed (2-crank)', Device.DeviceType.BED, 'Generic', 'MB-200',
     None, 1200, 7000, 22000, 20000, Device.RatePeriod.MONTHLY, 6, 2),
    ('Standard Wheelchair', Device.DeviceType.WHEELCHAIR, 'Karma', 'S-Ergo',
     None, 500, 2800, 9000, 8000, Device.RatePeriod.WEEKLY, 8, 2),
    ('Reclining Wheelchair', Device.DeviceType.WHEELCHAIR, 'Drive', 'Sentra',
     None, 900, 5000, 16000, 15000, Device.RatePeriod.WEEKLY, 4, 1),
    ('Rollator Walker', Device.DeviceType.WALKER, 'Drive', 'Nitro',
     None, 300, 1600, 5000, 4000, Device.RatePeriod.WEEKLY, 10, 3),
    ('Suction Machine', Device.DeviceType.SUCTION, 'Yuwell', '7E-A',
     None, 800, 4500, 14000, 12000, Device.RatePeriod.DAILY, 5, 1),
    ('Portable Ventilator', Device.DeviceType.VENTILATOR, 'ResMed', 'Astral 150',
     150, 6000, 38000, 130000, 100000, Device.RatePeriod.DAILY, 3, 1),
    ('Infusion Pump', Device.DeviceType.INFUSION_PUMP, 'B. Braun', 'Infusomat',
     None, 1200, 7000, 22000, 18000, Device.RatePeriod.DAILY, 7, 2),
    ('12-Lead ECG Monitor', Device.DeviceType.ECG, 'Contec', 'ECG1200G',
     100, 3500, 20000, 65000, 50000, Device.RatePeriod.DAILY, 4, 1),
    ('Syringe Driver', Device.DeviceType.INFUSION_PUMP, 'BD', 'Alaris CC',
     None, 900, 5200, 16000, 14000, Device.RatePeriod.DAILY, 6, 2),
    ('Air Mattress (Anti-bedsore)', Device.DeviceType.OTHER, 'Apex', 'Domus 2',
     None, 400, 2200, 7000, 6000, Device.RatePeriod.MONTHLY, 6, 2),
]


class Command(BaseCommand):
    help = 'Seed a starter medical equipment catalog (with hire rates) into every homecare tenant.'

    def add_arguments(self, parser):
        parser.add_argument('--schema', help='Only seed the given tenant schema.')
        parser.add_argument('--reset', action='store_true',
                            help='Delete seeded catalog devices (by name) before re-seeding.')

    def handle(self, *args, **opts):
        Tenant = get_tenant_model()
        tenants = Tenant.objects.exclude(schema_name='public')
        if opts.get('schema'):
            tenants = tenants.filter(schema_name=opts['schema'])

        names = [row[0] for row in EQUIPMENT]
        today = timezone.localdate()

        for t in tenants:
            with schema_context(t.schema_name):
                if opts.get('reset'):
                    Device.objects.filter(name__in=names, serial_number='').delete()
                created = updated = 0
                for (name, dtype, maker, model, hourly, daily, weekly,
                     monthly, deposit, period, qty, low) in EQUIPMENT:
                    obj, was_created = Device.objects.update_or_create(
                        name=name,
                        serial_number='',
                        defaults=dict(
                            device_type=dtype,
                            manufacturer=maker,
                            model_number=model,
                            status=Device.Status.AVAILABLE,
                            quantity=qty,
                            quantity_available=qty,
                            low_stock_threshold=low,
                            is_rentable=True,
                            currency='KES',
                            hourly_rate=hourly,
                            daily_rate=daily,
                            weekly_rate=weekly,
                            monthly_rate=monthly,
                            deposit=deposit,
                            default_hire_period=period,
                            next_maintenance_due=today + timedelta(days=90),
                        ),
                    )
                    if was_created:
                        created += 1
                    else:
                        updated += 1
                self.stdout.write(self.style.SUCCESS(
                    f'  [{t.schema_name}] {created} new / {updated} updated'
                ))
        self.stdout.write(self.style.SUCCESS('Equipment catalog seeded.'))
