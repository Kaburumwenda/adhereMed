"""
Management command that creates a default demo login for the independent
Inventory / Warehouse (IMS) tenant:

  * Tenant      : "Demo IMS Warehouse" (type=inventory, schema inventory_demo)
  * Login       : admin@demoims.local / Demo@1234   (tenant admin - full access)
  * Manager     : manager@demoims.local / Demo@1234  (inventory_admin)
  * Storekeeper : storekeeper@demoims.local / Demo@1234 (read-only stock ops)

Also seeds rich demo data so the dashboard is alive on first login:
warehouses, suppliers, categories/units, ~30 stock items with batches
(healthy / low / out-of-stock / expiring / expired), adjustments, purchase
orders, warehouse transfers and stock takes.

Usage:
    python manage.py create_ims_demo
    python manage.py create_ims_demo --reset     # wipe & reseed stock data
"""
import random
from datetime import date, timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.db import connection, transaction

from tenants.models import Tenant, Domain

random.seed(42)

DEMO_SCHEMA = 'inventory_demo'
DEMO_PASSWORD = 'Demo@1234'

DEMO_USERS = [
    ('admin@demoims.local', 'Amina', 'Njeri', 'tenant_admin'),
    ('manager@demoims.local', 'David', 'Kiptoo', 'inventory_admin'),
    ('storekeeper@demoims.local', 'Grace', 'Wambui', 'storekeeper'),
]

WAREHOUSES = [
    ('Main Warehouse', 'Mombasa Road, Nairobi', '-1.316', '36.816', True),
    ('Coast Depot', 'Kilindini Road, Mombasa', '-4.043', '39.668', False),
]

SUPPLIERS = [
    ('KEMSA (Kenya Medical Supplies Authority)', 'James Otieno', 'Net 30'),
    ('Cosmos Ltd', 'Priya Shah', 'Net 15'),
    ('Dawa Ltd', 'Hassan Ali', 'Net 30'),
    ('Laborex Kenya', 'Mary Wanjiru', 'Net 45'),
]

CATEGORY_DEFS = [
    'Analgesic / Pain Reliever', 'Antibiotic', 'Antimalarial', 'Antihypertensive',
    'Antidiabetic', 'Respiratory', 'Antacid / GI', 'Antifungal',
    'Vitamin / Supplement', 'First Aid / Wound Care',
    'Medical Device / Consumable', 'Emergency / IV Fluids',
]

UNIT_DEFS = [
    ('Tablets', 'tab'), ('Capsules', 'cap'), ('Syrup', 'btl'),
    ('Injection', 'inj'), ('Vial', 'vial'), ('Ampoule', 'amp'),
    ('Bottle', 'btl'), ('Box', 'box'), ('Sachet', 'sachet'), ('IV Bag', 'bag'),
]

# (name, category, unit, cost, selling, reorder_level, reorder_qty, location, barcode,
#  batches: [(batch_no, qty, expiry_offset_days_or_None, warehouse_idx_or_None, supplier_idx)])
STOCK_DEFS = [
    ('Paracetamol 500mg Tablet', 'Analgesic / Pain Reliever', 'Tablets', 0.80, 1.50, 200, 2000, 'A1-01', 'PC500TAB',
     [('PCM-2401', 8000, 540, 0, 0), ('PCM-2402', 5000, 300, 0, 0)]),
    ('Paracetamol 1g Tablet', 'Analgesic / Pain Reliever', 'Tablets', 1.10, 2.00, 150, 1000, 'A1-02', 'PC1G-TAB',
     [('PCM1G-2401', 4200, 360, 0, 0)]),
    ('Ibuprofen 400mg Tablet', 'Analgesic / Pain Reliever', 'Tablets', 1.00, 2.00, 200, 1500, 'A1-03', 'IBU400-TAB',
     [('IBU-2403', 3000, 240, 0, 1)]),
    ('Diclofenac 50mg Tablet', 'Analgesic / Pain Reliever', 'Tablets', 0.90, 1.80, 150, 1000, 'A1-04', 'DIC50-TAB',
     [('DIC-2402', 900, 120, 0, 1)]),
    ('Tramadol 50mg Capsule', 'Analgesic / Pain Reliever', 'Capsules', 3.50, 6.00, 400, 1500, 'A1-05', 'TRA50-CAP',
     [('TRA-2401', 350, 20, 0, 2)]),  # low stock
    ('Amoxicillin 500mg Capsule', 'Antibiotic', 'Capsules', 2.20, 4.00, 300, 2000, 'B1-01', 'AMX500-CAP',
     [('AMX-2401', 9000, 420, 0, 0), ('AMX-2402', 3000, 75, 0, 1)]),  # second batch expiring in 75d
    ('Amoxicillin + Clavulanate 625mg Tablet', 'Antibiotic', 'Tablets', 5.50, 9.50, 200, 1200, 'B1-02', 'AUG625-TAB',
     [('AUG-2401', 3500, 330, 0, 2)]),
    ('Ceftriaxone 1g Injection', 'Antibiotic', 'Vial', 6.00, 11.00, 150, 800, 'B1-03', 'CTX1G-VIAL',
     [('CTX-2402', 1600, 180, 0, 0)]),
    ('Azithromycin 500mg Tablet', 'Antibiotic', 'Tablets', 4.50, 8.00, 150, 600, 'B1-04', 'AZI500-TAB',
     [('AZI-2401', 120, 25, 0, 2)]),  # low stock
    ('Gentamicin 80mg/2ml Injection', 'Antibiotic', 'Ampoule', 1.80, 3.50, 100, 500, 'B1-05', 'GEN80-AMP',
     []),  # out of stock
    ('Artemether + Lumefantrine 20/120mg Tablet', 'Antimalarial', 'Tablets', 3.20, 6.00, 300, 2400, 'C1-01', 'AL20-TAB',
     [('AL-2401', 7000, 500, 0, 0)]),
    ('Artesunate 60mg Injection', 'Antimalarial', 'Vial', 4.00, 7.50, 150, 900, 'C1-02', 'ART60-VIAL',
     [('ART-2402', 1800, 210, 0, 3)]),
    ('Sulfadoxine + Pyrimethamine (Fansidar) Tablet', 'Antimalarial', 'Tablets', 1.50, 3.00, 120, 800, 'C1-03', 'SP-TAB',
     [('SP-2401', 1500, 60, 0, 0)]),  # expiring in 60d
    ('Amlodipine 5mg Tablet', 'Antihypertensive', 'Tablets', 0.70, 1.50, 300, 3000, 'D1-01', 'AMLO5-TAB',
     [('AMLO-2401', 12000, 600, 0, 1)]),
    ('Losartan 50mg Tablet', 'Antihypertensive', 'Tablets', 1.90, 3.50, 250, 1500, 'D1-02', 'LOSA50-TAB',
     [('LOSA-2401', 5200, 400, 0, 1)]),
    ('Atenolol 50mg Tablet', 'Antihypertensive', 'Tablets', 0.85, 1.60, 200, 1200, 'D1-03', 'ATEN50-TAB',
     [('ATEN-2401', 2600, 270, 1, 1)]),
    ('Metformin 500mg Tablet', 'Antidiabetic', 'Tablets', 0.95, 1.90, 400, 4000, 'E1-01', 'MET500-TAB',
     [('MET-2401', 18000, 540, 0, 2)]),
    ('Insulin Mixtard 30/70 100IU/ml Vial', 'Antidiabetic', 'Vial', 42.00, 65.00, 300, 800, 'E1-02', 'MIX-VIAL',
     [('INS-2403', 260, 25, 0, 3)]),  # low stock, expiring in 25d
    ('Glucagon 1mg Injection', 'Antidiabetic', 'Vial', 95.00, 150.00, 10, 40, 'E1-03', 'GLU1-VIAL',
     []),  # out of stock
    ('Salbutamol 100mcg Inhaler', 'Respiratory', 'Bottle', 22.00, 38.00, 60, 300, 'F1-01', 'SALB-INH',
     [('SAL-2401', 420, 300, 0, 3)]),
    ('Salbutamol 2.5mg/2.5ml Nebule', 'Respiratory', 'Bottle', 2.80, 5.00, 150, 1000, 'F1-02', 'SALB-NEB',
     [('NEB-2402', 2000, 150, 1, 3)]),
    ('Budesonide 0.5mg Nebule', 'Respiratory', 'Bottle', 6.50, 11.00, 80, 400, 'F1-03', 'BUD-NEB',
     [('BUD-2401', 300, 85, 0, 3)]),  # expiring in 85d
    ('Omeprazole 20mg Capsule', 'Antacid / GI', 'Capsules', 1.30, 2.50, 300, 2000, 'G1-01', 'OMP20-CAP',
     [('OMP-2401', 6500, 420, 0, 2)]),
    ('ORS Sachet (Low Osmolarity)', 'Antacid / GI', 'Sachet', 0.35, 0.80, 500, 5000, 'G1-02', 'ORS-SACH',
     [('ORS-2402', 14000, 360, 0, 0)]),
    ('Fluconazole 150mg Capsule', 'Antifungal', 'Capsules', 2.50, 5.00, 100, 600, 'H1-01', 'FLZ150-CAP',
     [('FLZ-2401', 1400, 330, 0, 1)]),
    ('Clotrimazole 1% Cream', 'Antifungal', 'Bottle', 3.20, 6.50, 80, 400, 'H1-02', 'CLO-CRM',
     [('CLO-2401', 620, 450, 0, 1)]),
    ('Multivitamin Tablet', 'Vitamin / Supplement', 'Tablets', 0.50, 1.20, 400, 5000, 'I1-01', 'MVT-TAB',
     [('MV-2401', 9500, 480, 0, 2)]),
    ('Surgical Face Mask (Box of 50)', 'First Aid / Wound Care', 'Box', 45.00, 90.00, 40, 200, 'I1-02', 'MASK-BOX',
     [('MSK-2401', 480, 700, 0, 0)]),
    ('Disposable Syringe 5ml', 'Medical Device / Consumable', 'Box', 12.00, 25.00, 100, 800, 'I1-03', 'SYR5-BOX',
     [('SYR-2402', 2100, 540, 1, 0)]),
    ('Adrenaline (Epinephrine) 1mg/ml Injection', 'Emergency / IV Fluids', 'Ampoule', 5.50, 10.00, 60, 300, 'J1-01', 'ADR-AMP',
     [('ADR-2301', 210, -30, 0, 0)]),  # expired 30 days ago (quantity remaining > 0)
    ('Normal Saline 0.9% 500ml IV Bag', 'Emergency / IV Fluids', 'IV Bag', 3.80, 7.00, 200, 1500, 'J1-02', 'NS500-BAG',
     [('NS-2401', 3600, 400, 0, 0)]),
]


class Command(BaseCommand):
    help = 'Create a demo inventory (IMS) tenant with a default login and rich demo data.'

    def add_arguments(self, parser):
        parser.add_argument('--reset', action='store_true',
                            help='Wipe existing inventory demo data and reseed from scratch.')

    def handle(self, *args, **options):
        # -- 1. Tenant + domain ------------------------------------------
        tenant, t_created = Tenant.objects.get_or_create(
            schema_name=DEMO_SCHEMA,
            defaults={
                'name': 'Demo IMS Warehouse',
                'type': 'inventory',
                'slug': 'demo-ims',
                'city': 'Nairobi',
                'country': 'Kenya',
                'phone': '+254700000004',
                'email': 'admin@demoims.local',
            },
        )
        if t_created:
            self.stdout.write(self.style.SUCCESS(f'Created inventory tenant: {tenant.name}'))
        else:
            self.stdout.write(f'Inventory tenant already exists: {tenant.name}')

        Domain.objects.get_or_create(
            domain='ims.localhost',
            defaults={'tenant': tenant, 'is_primary': True},
        )

        # -- 2. Demo users (public schema, like tenant registration) -----
        from accounts.models import User
        connection.set_schema_to_public()
        for email, first, last, role in DEMO_USERS:
            user, created = User.objects.get_or_create(
                email=email,
                defaults={
                    'first_name': first,
                    'last_name': last,
                    'role': role,
                    'tenant': tenant,
                    'is_active': True,
                },
            )
            if created:
                user.set_password(DEMO_PASSWORD)
                user.save()
                self.stdout.write(self.style.SUCCESS(f'  + {role}: {email}'))

        # -- 3. Demo data inside the tenant schema -----------------------
        from django_tenants.utils import tenant_context
        with tenant_context(tenant):
            self._seed_data(reset=options.get('reset', False))

        self.stdout.write(self.style.SUCCESS(
            '\nIMS demo ready!\n'
            f'  Tenant domain : http://ims.localhost:8000\n'
            f'  Admin login   : admin@demoims.local / {DEMO_PASSWORD}\n'
            f'  Manager login : manager@demoims.local / {DEMO_PASSWORD}\n'
            f'  Storekeeper   : storekeeper@demoims.local / {DEMO_PASSWORD}\n'
            f'  Dashboard     : /ims\n'
        ))

    @transaction.atomic
    def _seed_data(self, reset):
        from pharmacy_profile.models import Branch, Delivery
        from suppliers.models import Supplier
        from inventory.models import (
            Category, Unit, MedicationStock, StockBatch, StockAdjustment,
            InventoryCount, InventoryCountLine, StockTransfer, StockTransferLine,
        )
        from purchase_orders.models import PurchaseOrder
        from pos.models import (
            Customer, POSTransaction, TransactionItem, CreditSale,
            CreditPayment, ParkedSale, CashierShift,
        )
        from sales_orders.models import SalesOrder

        if reset:
            Delivery.objects.all().delete()
            SalesOrder.objects.all().delete()
            CashierShift.objects.all().delete()
            ParkedSale.objects.all().delete()
            CreditPayment.objects.all().delete()
            CreditSale.objects.all().delete()
            TransactionItem.objects.all().delete()
            POSTransaction.objects.all().delete()
            Customer.objects.all().delete()
            StockTransferLine.objects.all().delete()
            StockTransfer.objects.all().delete()
            InventoryCountLine.objects.all().delete()
            InventoryCount.objects.all().delete()
            StockAdjustment.objects.all().delete()
            StockBatch.objects.all().delete()
            MedicationStock.objects.all().delete()
            PurchaseOrder.objects.all().delete()
            Supplier.objects.all().delete()
            Branch.objects.all().delete()
            self.stdout.write('  Cleared existing demo data')

        # -- Warehouses (always ensure, even when stock data is present) ----
        warehouses = []
        for name, address, lat, lon, is_main in WAREHOUSES:
            b, _ = Branch.objects.get_or_create(
                name=name,
                defaults={
                    'address': address,
                    'latitude': Decimal(lat), 'longitude': Decimal(lon),
                    'is_main': is_main, 'is_active': True,
                },
            )
            warehouses.append(b)
        self.stdout.write(f'  + {len(warehouses)} warehouses')

        # -- Staff profiles (always ensure, so /ims/staff lists the demo users)
        from accounts.models import User
        from staff_profiles.models import StaffProfile
        staff_assignments = [
            ('admin@demoims.local', 0, 'BSc Supply Chain Management',
             'Oversees all warehouse operations and procurement.'),
            ('manager@demoims.local', 0, 'BCom Logistics & Inventory Management',
             'Manages stock control, cycle counts and warehouse transfers.'),
            ('storekeeper@demoims.local', 1, 'Diploma in Storekeeping',
             'Receives, issues and keeps records at the Coast Depot.'),
        ]
        n_new = 0
        for email, wh_idx, qualification, bio in staff_assignments:
            user = User.objects.filter(email=email).first()
            if not user:
                continue
            _, created = StaffProfile.objects.get_or_create(
                user=user,
                defaults={
                    'branch': warehouses[wh_idx],
                    'qualification': qualification,
                    'bio': bio,
                    'is_available': True,
                },
            )
            n_new += int(created)
        self.stdout.write(f'  + {len(staff_assignments)} staff profiles ({n_new} new)')

        if MedicationStock.objects.exists() and not reset:
            self.stdout.write('  Stock items already present - skipping catalog seed (use --reset to reseed).')
            self._seed_sales(warehouses, reset)
            return

        today = date.today()

        # -- Suppliers ------------------------------------------------------
        suppliers = []
        for name, contact, terms in SUPPLIERS:
            s, _ = Supplier.objects.get_or_create(
                name=name,
                defaults={'contact_person': contact, 'payment_terms': terms,
                          'phone': f'+2547{random.randint(10000000, 99999999)}'},
            )
            suppliers.append(s)
        self.stdout.write(f'  + {len(suppliers)} suppliers')

        # -- Categories & units -------------------------------------------
        categories = {}
        for name in CATEGORY_DEFS:
            c, _ = Category.objects.get_or_create(name=name)
            categories[name] = c
        units = {}
        for name, abbr in UNIT_DEFS:
            u, _ = Unit.objects.get_or_create(name=name, defaults={'abbreviation': abbr})
            units[name] = u

        # -- Stock items + batches ----------------------------------------
        stocks = []
        n_batches = 0
        for (name, cat, unit, cost, selling, reorder, reorder_qty, location, barcode,
             batch_defs) in STOCK_DEFS:
            # Branch is compulsory — default to the item's first batch's
            # warehouse (or the main warehouse).
            first_wh = batch_defs[0][3] if batch_defs and batch_defs[0][3] is not None else 0
            stock = MedicationStock.objects.create(
                medication_name=name,
                category=categories[cat],
                unit=units[unit],
                branch=warehouses[first_wh],
                selling_price=Decimal(str(selling)),
                cost_price=Decimal(str(cost)),
                reorder_level=reorder,
                reorder_quantity=reorder_qty,
                location_in_store=location,
                barcode=barcode,
                is_active=True,
            )
            stocks.append(stock)
            for (batch_no, qty, expiry_days, wh_idx, sup_idx) in batch_defs:
                branch = warehouses[wh_idx] if wh_idx is not None else None
                StockBatch.objects.create(
                    stock=stock,
                    batch_number=batch_no,
                    quantity_received=qty,
                    quantity_remaining=qty,
                    cost_price_per_unit=Decimal(str(cost)),
                    expiry_date=(today + timedelta(days=expiry_days)) if expiry_days is not None else None,
                    supplier=suppliers[sup_idx],
                    branch=branch,
                )
                n_batches += 1
        self.stdout.write(f'  + {len(stocks)} stock items / {n_batches} batches '
                          f'(incl. low, out-of-stock, expiring & expired)')

        def batch_for(stock):
            return stock.batches.order_by('expiry_date').first()

        # -- Stock adjustments (damage / expiry / correction) -------------
        damaged = stocks[2]   # Ibuprofen 400mg
        b = batch_for(damaged)
        if b:
            StockAdjustment.objects.create(
                stock=damaged, batch=b, quantity_change=-5,
                reason=StockAdjustment.Reason.DAMAGE,
                notes='Crushed during handling at Main Warehouse',
            )
            b.quantity_remaining = max(0, b.quantity_remaining - 5)
            b.save(update_fields=['quantity_remaining'])

        corrected = stocks[0]  # Paracetamol 500mg
        b = batch_for(corrected)
        if b:
            StockAdjustment.objects.create(
                stock=corrected, batch=b, quantity_change=3,
                reason=StockAdjustment.Reason.COUNT_CORRECTION,
                notes='Found 3 strips during shelf sweep',
            )
            b.quantity_remaining += 3
            b.save(update_fields=['quantity_remaining'])

        expired = stocks[-2]  # Adrenaline - expired batch
        b = batch_for(expired)
        if b:
            StockAdjustment.objects.create(
                stock=expired, batch=b, quantity_change=-20,
                reason=StockAdjustment.Reason.EXPIRY,
                notes=f'Batch {b.batch_number} expired - quarantined for destruction',
            )
            b.quantity_remaining = max(0, b.quantity_remaining - 20)
            b.save(update_fields=['quantity_remaining'])
        self.stdout.write('  + 3 stock adjustments')

        # -- Purchase orders ----------------------------------------------
        po_items = [
            (stocks[6].id, stocks[6].medication_name, 800, float(stocks[6].cost_price)),
            (stocks[1].id, stocks[1].medication_name, 2000, float(stocks[1].cost_price)),
        ]
        total = sum(q * c for _, _, q, c in po_items)
        PurchaseOrder.objects.create(
            po_number='PO-DEMO-0001',
            supplier=suppliers[0],
            items=[{'medication_stock_id': sid, 'name': nm, 'qty': q,
                    'unit_cost': c, 'total': round(q * c, 2)}
                   for sid, nm, q, c in po_items],
            total_cost=Decimal(str(round(total, 2))),
            status='sent',
            expected_delivery=today + timedelta(days=10),
            notes='KEMSA quarterly replenishment order',
            branch=warehouses[0],
        )
        po_items2 = [
            (stocks[19].id, stocks[19].medication_name, 300, float(stocks[19].cost_price)),
            (stocks[20].id, stocks[20].medication_name, 600, float(stocks[20].cost_price)),
        ]
        total2 = sum(q * c for _, _, q, c in po_items2)
        PurchaseOrder.objects.create(
            po_number='PO-DEMO-0002',
            supplier=suppliers[1],
            items=[{'medication_stock_id': sid, 'name': nm, 'qty': q,
                    'unit_cost': c, 'total': round(q * c, 2)}
                   for sid, nm, q, c in po_items2],
            total_cost=Decimal(str(round(total2, 2))),
            status='draft',
            expected_delivery=today + timedelta(days=21),
            notes='Respiratory stock-up for flu season',
            branch=warehouses[1],
        )
        self.stdout.write('  + 2 purchase orders (1 sent, 1 draft)')

        # -- Warehouse transfers ------------------------------------------
        tr = StockTransfer.objects.create(
            source_branch=warehouses[0], dest_branch=warehouses[1],
            status='in_transit',
            notes='Weekly coastal depot replenishment',
        )
        for stock, qty in [(stocks[0], 500), (stocks[15], 300)]:
            StockTransferLine.objects.create(
                transfer=tr, stock=stock, quantity=qty,
            )

        tr2 = StockTransfer.objects.create(
            source_branch=warehouses[1], dest_branch=warehouses[0],
            status='completed',
            notes='Emergency shortage top-up',
        )
        for stock, qty, received in [(stocks[9], 150, 150), (stocks[21], 80, 75)]:
            StockTransferLine.objects.create(
                transfer=tr2, stock=stock, quantity=qty, quantity_received=received,
            )
        self.stdout.write('  + 2 warehouse transfers (1 in transit, 1 completed)')

        # -- Stock takes ---------------------------------------------------
        count = InventoryCount.objects.create(
            name='Monthly count - Main Warehouse',
            branch=warehouses[0],
            status='completed',
            notes='Full physical count of racks A-J',
        )
        for stock, expected, counted in [(stocks[0], 13003, 13003), (stocks[3], 900, 897), (stocks[13], 12000, 11988)]:
            InventoryCountLine.objects.create(
                count=count, stock=stock,
                expected_quantity=expected, counted_quantity=counted,
                notes='Minor shrinkage' if counted < expected else '',
            )
        count.completed_at = count.created_at + timedelta(hours=3)
        count.save(update_fields=['completed_at'])

        count2 = InventoryCount.objects.create(
            name='Quarterly count - Coast Depot',
            branch=warehouses[1],
            status='in_progress',
        )
        for stock in [stocks[4], stocks[8], stocks[16]]:
            InventoryCountLine.objects.create(
                count=count2, stock=stock, expected_quantity=stock.total_quantity,
            )
        self.stdout.write('  + 2 stock takes (1 completed with variance, 1 in progress)')

        # -- Sales demo data (POS, customers, credit, orders, deliveries) ---
        self._seed_sales(warehouses, reset)

    def _seed_sales(self, warehouses, reset):
        """Seeds demo sales data so the Sales menu is alive: customers, POS
        transactions, a credit sale with a partial payment, a parked (on-hold)
        sale, cashier shifts, sales orders and one delivery in transit."""
        from pos.models import (
            Customer, POSTransaction, TransactionItem, CreditSale,
            CreditPayment, ParkedSale, CashierShift,
        )
        from sales_orders.models import SalesOrder
        from pharmacy_profile.models import Delivery
        from accounts.models import User
        from inventory.models import MedicationStock, StockBatch
        from django.db.models import F
        from django.utils import timezone

        if POSTransaction.objects.exists() and not reset:
            self.stdout.write('  Sales demo already present - skipping sales seed.')
            return

        admin = User.objects.filter(email='admin@demoims.local').first()
        warehouse = warehouses[0]
        today = date.today()

        # -- Customers -------------------------------------------------------
        customer_defs = [
            ('Uzima Medical Centre', '+254711000001', 'orders@uzimamedical.co', 'Hospital'),
            ('Baraka Health Clinic', '+254711000002', 'supply@barakaclinic.co', 'Clinic'),
            ('Mwangi Wholesalers', '+254711000003', 'sales@mwangiwholesale.co', 'Retailer'),
        ]
        customers = []
        for name, phone, email, notes in customer_defs:
            c, _ = Customer.objects.get_or_create(
                phone=phone,
                defaults={'name': name, 'email': email, 'notes': f'Account type: {notes}'},
            )
            customers.append(c)
        self.stdout.write(f'  + {len(customers)} customers')

        def fefo_batch(stock):
            return (StockBatch.objects
                    .filter(stock=stock, quantity_remaining__gt=0)
                    .order_by('expiry_date', 'id').first())

        def make_sale(txn_no, day_offset, payment, customer, lines):
            subtotal = sum(q * p for _, q, p in lines)
            txn = POSTransaction.objects.create(
                transaction_number=txn_no,
                customer=customer,
                customer_name=customer.name if customer else 'Walk-in customer',
                customer_phone=customer.phone if customer else '',
                subtotal=Decimal(str(round(subtotal, 2))),
                total=Decimal(str(round(subtotal, 2))),
                payment_method=payment,
                cashier=admin,
                branch=warehouse,
                status=POSTransaction.SaleStatus.COMPLETED,
            )
            for (stock, qty, price) in lines:
                batch = fefo_batch(stock)
                if batch:
                    batch.quantity_remaining = max(0, batch.quantity_remaining - qty)
                    batch.save(update_fields=['quantity_remaining'])
                TransactionItem.objects.create(
                    transaction=txn, stock=stock, batch=batch,
                    medication_name=stock.medication_name,
                    quantity=qty, unit_price=Decimal(str(price)),
                    total_price=Decimal(str(round(qty * price, 2))),
                )
            # backdate the transaction (created_at is auto_now_add)
            stamp = timezone.now() - timedelta(days=day_offset, hours=random.randint(1, 8))
            POSTransaction.objects.filter(pk=txn.pk).update(created_at=stamp)
            if customer:
                Customer.objects.filter(pk=customer.pk).update(
                    total_purchases=F('total_purchases') + txn.total,
                    visit_count=F('visit_count') + 1,
                )
                customer.refresh_from_db()
            return txn

        stock_by_name = {s.medication_name: s for s in
                         MedicationStock.objects.filter(is_active=True)}

        def st(name):
            return stock_by_name[name]

        # -- POS sales (last few days) ---------------------------------------
        txn1 = make_sale('TXN-DEMO-0001', 3, 'cash', None, [
            (st('Paracetamol 500mg Tablet'), 100, 1.50),
            (st('Amoxicillin 500mg Capsule'), 200, 4.00),
            (st('ORS Sachet (Low Osmolarity)'), 500, 0.80),
        ])
        txn2 = make_sale('TXN-DEMO-0002', 2, 'mpesa', customers[0], [
            (st('Surgical Face Mask (Box of 50)'), 20, 90.00),
            (st('Disposable Syringe 5ml'), 30, 25.00),
        ])
        make_sale('TXN-DEMO-0003', 1, 'cash', None, [
            (st('Amlodipine 5mg Tablet'), 300, 1.50),
            (st('Metformin 500mg Tablet'), 500, 1.90),
        ])
        txn4 = make_sale('TXN-DEMO-0004', 0, 'mpesa', customers[2], [
            (st('Salbutamol 2.5mg/2.5ml Nebule'), 100, 5.00),
            (st('Budesonide 0.5mg Nebule'), 50, 11.00),
        ])
        txn5 = make_sale('TXN-DEMO-0005', 0, 'credit', customers[1], [
            (st('Insulin Mixtard 30/70 100IU/ml Vial'), 10, 65.00),
            (st('Fluconazole 150mg Capsule'), 100, 5.00),
        ])
        self.stdout.write('  + 5 POS sales (cash, M-Pesa & credit)')

        # -- Credit sale with partial payment --------------------------------
        CreditSale.objects.create(
            transaction=txn5, customer_name=customers[1].name,
            customer_phone=customers[1].phone,
            due_date=today + timedelta(days=14),
            notes='Net-14 account order',
            total_amount=txn5.total,
            partial_paid_amount=Decimal('500.00'),
            balance_amount=txn5.total - Decimal('500.00'),
            partial_payment_method='mpesa',
            status=CreditSale.Status.PARTIAL,
        )
        CreditPayment.objects.create(
            credit_sale=txn5.credit_record, amount=Decimal('500.00'),
            payment_method='mpesa', reference='MPESA-DEMO-1',
            notes='Part payment on account', recorded_by=admin,
        )
        self.stdout.write('  + 1 credit sale (partially paid)')

        # -- Parked (on-hold) sale --------------------------------------------
        ParkedSale.objects.create(
            park_number='PARK-DEMO-0001',
            customer_name='Aisha Mohammed',
            customer_phone='+254722111222',
            payment_method='cash',
            items=[
                {'stock_id': st('Artemether + Lumefantrine 20/120mg Tablet').id,
                 'name': 'Artemether + Lumefantrine 20/120mg Tablet', 'sku': 'AL20-TAB',
                 'category': 'Antimalarial', 'selling_price': 6.00, 'quantity': 200, 'max_qty': 7000},
                {'stock_id': st('Ceftriaxone 1g Injection').id,
                 'name': 'Ceftriaxone 1g Injection', 'sku': 'CTX1G-VIAL',
                 'category': 'Antibiotic', 'selling_price': 11.00, 'quantity': 50, 'max_qty': 1600},
            ],
            notes='Held while awaiting customer M-Pesa confirmation',
            cashier=admin, branch=warehouse,
        )
        self.stdout.write('  + 1 parked (on-hold) sale')

        # -- Cashier shifts ----------------------------------------------------
        shift_open = CashierShift.objects.create(
            cashier=admin, branch=warehouse, opening_float=Decimal('5000.00'),
        )
        self.stdout.write(f'  + 1 open cashier shift ({shift_open.reference})')

        # -- Sales orders -------------------------------------------------------
        so_items = [
            {'stock_id': st('Normal Saline 0.9% 500ml IV Bag').id,
             'name': 'Normal Saline 0.9% 500ml IV Bag', 'qty': 300, 'unit_price': 7.00,
             'discount_percent': 0, 'total': 2100.00},
            {'stock_id': st('Omeprazole 20mg Capsule').id,
             'name': 'Omeprazole 20mg Capsule', 'qty': 400, 'unit_price': 2.50,
             'discount_percent': 0, 'total': 1000.00},
        ]
        SalesOrder.objects.create(
            so_number='SO-DEMO-0001',
            customer=customers[0], customer_name=customers[0].name,
            customer_phone=customers[0].phone,
            items=so_items, total_amount=Decimal('3100.00'),
            status=SalesOrder.Status.CONFIRMED,
            payment_status=SalesOrder.PaymentStatus.UNPAID,
            payment_method='credit',
            expected_delivery=today + timedelta(days=5),
            delivery_address='Uzima Medical Centre, Pipeline Road, Nairobi',
            notes='Monthly facility replenishment order',
            branch=warehouse,
        )
        so_items2 = [
            {'stock_id': st('Multivitamin Tablet').id,
             'name': 'Multivitamin Tablet', 'qty': 1000, 'unit_price': 1.20,
             'discount_percent': 0, 'total': 1200.00},
        ]
        SalesOrder.objects.create(
            so_number='SO-DEMO-0002',
            customer=customers[2], customer_name=customers[2].name,
            customer_phone=customers[2].phone,
            items=so_items2, total_amount=Decimal('1200.00'),
            amount_paid=Decimal('1200.00'),
            status=SalesOrder.Status.FULFILLED,
            payment_status=SalesOrder.PaymentStatus.PAID,
            payment_method='mpesa',
            delivery_address='Mwangi Wholesalers, Kirinyaga Road, Nairobi',
            notes='Paid on delivery',
            branch=warehouse,
        )
        self.stdout.write('  + 2 sales orders (confirmed + fulfilled)')

        # -- Delivery in transit -----------------------------------------------
        Delivery.objects.create(
            transaction=txn4,
            delivery_address='Mwangi Wholesalers, Kirinyaga Road, Nairobi',
            recipient_name='Mwangi Wholesalers',
            recipient_phone='+254711000003',
            delivery_fee=Decimal('350.00'),
            status=Delivery.Status.IN_TRANSIT,
            assigned_driver_name='Joseph Kariuki',
            notes='Respiratory stock - handle with care',
        )
        self.stdout.write('  + 1 delivery (in transit)')
