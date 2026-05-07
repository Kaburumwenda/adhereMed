"""Scan for low-stock and expiring stock and create notifications for pharmacy admins.

Run inside a tenant context:
    python manage.py tenant_command scan_alerts --schema=yusra_pharmacy
or directly while in a tenant shell.
"""
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils import timezone

User = get_user_model()


class Command(BaseCommand):
    help = 'Scan inventory and create notifications for low-stock and expiring batches.'

    def add_arguments(self, parser):
        parser.add_argument('--days', type=int, default=30,
                            help='Days-ahead horizon for expiry alerts (default 30)')
        parser.add_argument('--quiet', action='store_true')

    def handle(self, *args, **options):
        from inventory.models import MedicationStock, StockBatch
        from notifications.models import Notification

        days = options['days']
        quiet = options['quiet']
        today = timezone.now().date()
        cutoff = today + timedelta(days=days)

        recipients = list(User.objects.filter(
            role__in=['tenant_admin', 'pharmacy_admin', 'pharmacist', 'admin'],
            is_active=True,
        ))
        if not recipients:
            self.stdout.write(self.style.WARNING('No recipient users found.'))
            return

        # Low stock
        low_count = 0
        for stock in MedicationStock.objects.filter(is_active=True):
            if stock.total_quantity <= (stock.reorder_level or 0):
                key = f'low-stock-{stock.id}-{today.isoformat()}'
                for u in recipients:
                    if Notification.objects.filter(recipient=u, data__key=key).exists():
                        continue
                    Notification.objects.create(
                        recipient=u,
                        type=Notification.NotificationType.SYSTEM,
                        title=f'Low stock: {stock.medication_name}',
                        message=(f'{stock.medication_name} is at {stock.total_quantity} '
                                 f'(reorder level {stock.reorder_level}).'),
                        data={'key': key, 'stock_id': stock.id, 'kind': 'low_stock',
                              'quantity': stock.total_quantity,
                              'reorder_level': stock.reorder_level},
                    )
                low_count += 1

        # Expiring batches
        exp_count = 0
        batches = StockBatch.objects.filter(
            quantity_remaining__gt=0, expiry_date__isnull=False,
            expiry_date__lte=cutoff,
        ).select_related('stock')
        for b in batches:
            days_left = (b.expiry_date - today).days
            kind = 'expired' if days_left < 0 else 'expiring_soon'
            key = f'{kind}-batch-{b.id}-{today.isoformat()}'
            for u in recipients:
                if Notification.objects.filter(recipient=u, data__key=key).exists():
                    continue
                title = ('EXPIRED' if days_left < 0 else f'Expires in {days_left}d')
                Notification.objects.create(
                    recipient=u,
                    type=Notification.NotificationType.SYSTEM,
                    title=f'{title}: {b.stock.medication_name if b.stock else "?"} batch {b.batch_number}',
                    message=(f'Batch {b.batch_number}: {b.quantity_remaining} units '
                             f'expire on {b.expiry_date}.'),
                    data={'key': key, 'batch_id': b.id, 'stock_id': b.stock_id,
                          'kind': kind, 'days_left': days_left},
                )
            exp_count += 1

        if not quiet:
            self.stdout.write(self.style.SUCCESS(
                f'Scan complete. Low-stock items: {low_count}; expiring/expired batches: {exp_count}.'
            ))
