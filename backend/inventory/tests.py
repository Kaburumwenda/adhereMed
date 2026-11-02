"""Tests for the inventory (IMS) tenant: stock quantities, adjustments,
transfers, stock takes and RBAC.

Run with::

    python manage.py test inventory --keepdb

``TenantTestCase`` builds a throw-away tenant schema, so the first run pays
the migration cost once (``--keepdb`` makes later runs fast).
"""
from datetime import date, timedelta

from django_tenants.test.cases import TenantTestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import User
from pharmacy_profile.models import Branch
from pos.models import POSTransaction, TransactionItem
from staff_profiles.models import StaffProfile

from inventory.models import (
    InventoryCount,
    InventoryCountLine,
    MedicationStock,
    StockAdjustment,
    StockBatch,
    StockTransfer,
    StockTransferLine,
)
from inventory.services.stock import (
    InsufficientStock,
    apply_quantity_change,
    consume_stock,
    receipt_stock,
    reconcile_quantity,
)


class InventoryApiTestCase(TenantTestCase):
    """One tenant schema for the whole module (schema creation is expensive)."""

    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = 'Test Warehouse Co'
        tenant.type = 'inventory'
        tenant.slug = 'test-warehouse'

    @classmethod
    def get_test_tenant_domain(cls):
        return 'test-warehouse.test.localhost'

    # ── Fixtures ────────────────────────────────────────────────────────
    def setUp(self):
        self.branch = Branch.objects.create(name='Main Warehouse', is_main=True)
        self.branch2 = Branch.objects.create(name='North Depot')

        self.admin = User.objects.create_user(
            email='admin@test.local', password='x', first_name='Ada', last_name='Admin',
            role='tenant_admin',
        )
        self.manager = User.objects.create_user(
            email='manager@test.local', password='x', first_name='Ben', last_name='Boss',
            role='branch_admin',
        )
        StaffProfile.objects.create(user=self.manager, branch=self.branch2)

        self.cashier = User.objects.create_user(
            email='cashier@test.local', password='x', first_name='Cam', last_name='Till',
            role='cashier',
        )

        self.client = APIClient(HTTP_X_TENANT_SCHEMA=self.tenant.schema_name)

    def _login(self, user):
        self.client.force_authenticate(user=user)

    def _stock(self, name, branch=None, cost='10.00', selling='20.00'):
        return MedicationStock.objects.create(
            medication_name=name,
            branch=branch or self.branch,
            cost_price=cost,
            selling_price=selling,
            reorder_level=10,
        )

    def _batch(self, stock, qty, expiry_days=None, cost='10.00'):
        return StockBatch.objects.create(
            stock=stock,
            batch_number=f'B-{stock.pk}-{qty}-{expiry_days}',
            quantity_received=qty,
            quantity_remaining=qty,
            cost_price_per_unit=cost,
            expiry_date=(None if expiry_days is None
                         else timezone.localdate() + timedelta(days=expiry_days)),
        )

    # ── Model quantities ────────────────────────────────────────────────
    def test_expired_stock_excluded_from_sellable_quantity(self):
        stock = self._stock('Paracetamol 500mg')
        self._batch(stock, 100)          # no expiry → sellable
        self._batch(stock, 50, expiry_days=10)   # sellable
        self._batch(stock, 30, expiry_days=-5)   # expired

        stock.refresh_from_db()
        self.assertEqual(stock.total_quantity, 180)
        self.assertEqual(stock.expired_quantity, 30)
        self.assertEqual(stock.sellable_quantity, 150)
        self.assertEqual(stock.available_quantity, 150)

    def test_low_stock_uses_sellable_not_physical_quantity(self):
        stock = self._stock('Amoxicillin 250mg')   # reorder_level = 10
        self._batch(stock, 500, expiry_days=-2)    # all expired
        stock.refresh_from_db()
        self.assertEqual(stock.total_quantity, 500)
        self.assertEqual(stock.sellable_quantity, 0)
        self.assertTrue(stock.is_low_stock)

    def test_committed_quantity_reduces_availability(self):
        stock = self._stock('Ibuprofen 400mg')
        self._batch(stock, 40)
        stock.committed_qty = 15
        stock.save(update_fields=['committed_qty'])
        stock.refresh_from_db()
        self.assertEqual(stock.available_quantity, 25)

    # ── Stock service ───────────────────────────────────────────────────
    def test_decrease_drains_batches_fefo_and_reports_ledger(self):
        stock = self._stock('Ceftriaxone 1g')
        early = self._batch(stock, 20, expiry_days=30)
        late = self._batch(stock, 100, expiry_days=400)

        rows = apply_quantity_change(
            stock, -50, reason=StockAdjustment.Reason.DAMAGE,
            notes='Damaged carton', user=self.admin,
        )

        early.refresh_from_db()
        late.refresh_from_db()
        self.assertEqual(early.quantity_remaining, 0)
        self.assertEqual(late.quantity_remaining, 70)
        self.assertEqual(sum(r.quantity_change for r in rows), -50)
        self.assertEqual(len(rows), 2)   # one ledger row per batch touched
        self.assertEqual(stock.total_quantity, 70)

    def test_decrease_beyond_stock_raises(self):
        stock = self._stock('Metformin 500mg')
        self._batch(stock, 10)
        with self.assertRaises(InsufficientStock):
            apply_quantity_change(
                stock, -11, reason=StockAdjustment.Reason.THEFT, user=self.admin)
        self.assertEqual(stock.total_quantity, 10)

    def test_reconcile_sets_exact_total(self):
        stock = self._stock('Omeprazole 20mg')
        self._batch(stock, 30)
        reconcile_quantity(stock, 12, user=self.admin)
        self.assertEqual(stock.total_quantity, 12)

    # ── Sales-channel service (consume_stock / receipt_stock) ───────────
    def test_consume_stock_skips_expired_batches(self):
        """POS / dispensing / sales orders must never sell expired stock."""
        stock = self._stock('Tramadol 50mg')
        expired = self._batch(stock, 100, expiry_days=-3)
        live = self._batch(stock, 40, expiry_days=200)

        consume_stock(stock, 10, reason=StockAdjustment.Reason.POS_SALE,
                      user=self.admin)

        expired.refresh_from_db()
        live.refresh_from_db()
        self.assertEqual(expired.quantity_remaining, 100, 'expired lot must be untouched')
        self.assertEqual(live.quantity_remaining, 30)

    def test_consume_stock_skips_quarantined_batches(self):
        stock = self._stock('Adrenaline 1mg')
        blocked = self._batch(stock, 50, expiry_days=200)
        blocked.is_blocked = True
        blocked.save(update_fields=['is_blocked'])
        self._batch(stock, 10, expiry_days=200)

        consume_stock(stock, 10, reason=StockAdjustment.Reason.DISPENSING,
                      user=self.admin)

        blocked.refresh_from_db()
        self.assertEqual(blocked.quantity_remaining, 50)

    def test_consume_stock_refuses_to_oversell(self):
        """A sale the shelf cannot back must be rejected, not completed."""
        stock = self._stock('Insulin Mixtard')
        self._batch(stock, 5, expiry_days=200)
        with self.assertRaises(InsufficientStock):
            consume_stock(stock, 6, reason=StockAdjustment.Reason.POS_SALE,
                          user=self.admin)
        self.assertEqual(stock.total_quantity, 5)

    def test_consume_stock_writes_one_ledger_row_per_batch(self):
        stock = self._stock('Azithromycin 500mg')
        self._batch(stock, 5, expiry_days=30)
        self._batch(stock, 5, expiry_days=100)

        rows = consume_stock(stock, 8, reason=StockAdjustment.Reason.POS_SALE,
                             user=self.admin)

        self.assertEqual(len(rows), 2)
        self.assertEqual(sum(r.quantity_change for r in rows), -8)
        self.assertTrue(all(r.reason == 'pos_sale' for r in rows))

    def test_receipt_stock_never_tops_up_an_expired_lot(self):
        """Adding units to an expired batch leaves them permanently unsellable."""
        stock = self._stock('Ceftriaxone 2g')
        expired = self._batch(stock, 20, expiry_days=-10)

        receipt_stock(stock, 15, reason=StockAdjustment.Reason.OTHER,
                      user=self.admin)

        expired.refresh_from_db()
        self.assertEqual(expired.quantity_remaining, 20,
                         'expired batch must not receive new units')
        stock.refresh_from_db()
        self.assertEqual(stock.total_quantity, 35)
        self.assertEqual(stock.sellable_quantity, 15)

    def test_apply_quantity_change_still_moves_expired_stock(self):
        """Write-offs legitimately need to touch expired units."""
        stock = self._stock('Expired Only')
        batch = self._batch(stock, 30, expiry_days=-4)
        apply_quantity_change(
            stock, -30, reason=StockAdjustment.Reason.EXPIRY,
            user=self.admin, batch=batch,
        )
        batch.refresh_from_db()
        self.assertEqual(batch.quantity_remaining, 0)

    # ── Adjustments API ─────────────────────────────────────────────────
    def test_adjustment_without_batch_still_changes_stock(self):
        """A batch-less adjustment used to write a ledger row but move no
        stock, because on-hand is derived from batches."""
        stock = self._stock('Diclofenac 50mg')
        self._batch(stock, 60)
        self._login(self.admin)

        response = self.client.post('/api/inventory/adjustments/', {
            'stock': stock.pk,
            'quantity_change': -15,
            'reason': 'damage',
            'notes': 'Crushed in transit',
        }, format='json')

        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(stock.total_quantity, 45)

    def test_adjustment_over_deduction_is_rejected(self):
        stock = self._stock('Losartan 50mg')
        self._batch(stock, 5)
        self._login(self.admin)

        response = self.client.post('/api/inventory/adjustments/', {
            'stock': stock.pk,
            'quantity_change': -9,
            'reason': 'theft',
        }, format='json')

        self.assertEqual(response.status_code, 400, response.data)
        self.assertEqual(stock.total_quantity, 5)

    def test_adjustment_outside_own_warehouse_is_rejected(self):
        stock = self._stock('Salbutamol Inhaler', branch=self.branch)
        self._batch(stock, 10)
        self._login(self.manager)   # branch_admin scoped to branch2

        response = self.client.post('/api/inventory/adjustments/', {
            'stock': stock.pk,
            'quantity_change': 5,
            'reason': 'other',
        }, format='json')

        self.assertEqual(response.status_code, 403, response.data)

    # ── Bulk delete / RBAC ──────────────────────────────────────────────
    def test_bulk_delete_requires_delete_capability(self):
        stock = self._stock('Temp Item')
        self._login(self.manager)   # branch_admin: manage but not delete

        response = self.client.post('/api/inventory/stocks/bulk-delete/',
                                    {'ids': [stock.pk]}, format='json')
        self.assertEqual(response.status_code, 403, response.data)
        self.assertTrue(MedicationStock.objects.filter(pk=stock.pk).exists())

        self._login(self.admin)
        response = self.client.post('/api/inventory/stocks/bulk-delete/',
                                    {'ids': [stock.pk]}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertFalse(MedicationStock.objects.filter(pk=stock.pk).exists())

    def test_analytics_hides_cost_from_roles_without_capability(self):
        stock = self._stock('Vitamin C 100mg')
        self._batch(stock, 10, cost='10.00')

        self._login(self.admin)
        admin_data = self.client.get('/api/inventory/analytics/').data
        self.assertGreater(admin_data['total_cost_value'], 0)

        self._login(self.cashier)
        cashier_data = self.client.get('/api/inventory/analytics/').data
        self.assertEqual(cashier_data['total_cost_value'], 0)
        self.assertIsNone(cashier_data['potential_profit'])

    # ── Transfers ───────────────────────────────────────────────────────
    def _transfer(self, stock, qty, status=StockTransfer.Status.REQUESTED):
        transfer = StockTransfer.objects.create(
            source_branch=self.branch, dest_branch=self.branch2, status=status,
            requested_by=self.admin,
        )
        StockTransferLine.objects.create(transfer=transfer, stock=stock, quantity=qty)
        return transfer

    def test_approve_rejects_shortage_and_leaves_stock_untouched(self):
        stock = self._stock('Azithromycin 250mg')
        self._batch(stock, 5)
        transfer = self._transfer(stock, 9)
        self._login(self.admin)

        response = self.client.post(
            f'/api/inventory/transfers/{transfer.pk}/approve/', {}, format='json')

        self.assertEqual(response.status_code, 400, response.data)
        self.assertIn('shortages', response.data)
        self.assertEqual(stock.total_quantity, 5)
        transfer.refresh_from_db()
        self.assertEqual(transfer.status, StockTransfer.Status.REQUESTED)

    def test_approve_is_cumulative_across_lines_of_the_same_item(self):
        """Two lines that each fit individually must not jointly oversell."""
        stock = self._stock('Ranitidine 150mg')
        self._batch(stock, 10)
        transfer = StockTransfer.objects.create(
            source_branch=self.branch, dest_branch=self.branch2,
            status=StockTransfer.Status.REQUESTED, requested_by=self.admin,
        )
        StockTransferLine.objects.create(transfer=transfer, stock=stock, quantity=6)
        StockTransferLine.objects.create(transfer=transfer, stock=stock, quantity=6)
        self._login(self.admin)

        response = self.client.post(
            f'/api/inventory/transfers/{transfer.pk}/approve/', {}, format='json')

        self.assertEqual(response.status_code, 400, response.data)
        self.assertEqual(stock.total_quantity, 10)

    def test_approve_deducts_stock_and_cannot_run_twice(self):
        stock = self._stock('Ciprofloxacin 500mg')
        self._batch(stock, 40)
        transfer = self._transfer(stock, 15)
        self._login(self.admin)

        first = self.client.post(
            f'/api/inventory/transfers/{transfer.pk}/approve/', {}, format='json')
        self.assertEqual(first.status_code, 200, first.data)
        self.assertEqual(stock.total_quantity, 25)

        second = self.client.post(
            f'/api/inventory/transfers/{transfer.pk}/approve/', {}, format='json')
        self.assertEqual(second.status_code, 409, second.data)
        self.assertEqual(stock.total_quantity, 25)

    def test_receive_creates_dest_item_and_preserves_batch_traceability(self):
        stock = self._stock('Ferrous Sulphate 200mg')
        expiry = timezone.localdate() + timedelta(days=45)
        StockBatch.objects.create(
            stock=stock, batch_number='LOT-77', quantity_received=20,
            quantity_remaining=20, cost_price_per_unit='12.50', expiry_date=expiry,
        )
        transfer = self._transfer(stock, 20)
        self._login(self.admin)

        self.client.post(f'/api/inventory/transfers/{transfer.pk}/approve/', {}, format='json')
        response = self.client.post(
            f'/api/inventory/transfers/{transfer.pk}/receive/',
            {'lines': [{'id': transfer.lines.first().pk, 'quantity_received': 20}]},
            format='json',
        )

        self.assertEqual(response.status_code, 200, response.data)
        dest_stock = MedicationStock.objects.get(
            branch=self.branch2, medication_name__iexact='Ferrous Sulphate 200mg')
        dest_batch = dest_stock.batches.first()
        self.assertIsNotNone(dest_batch)
        self.assertEqual(dest_batch.expiry_date, expiry)       # not today + 365
        self.assertEqual(dest_batch.batch_number, 'LOT-77')     # traceable
        self.assertEqual(str(dest_batch.cost_price_per_unit), '12.50')
        transfer.refresh_from_db()
        self.assertEqual(transfer.status, StockTransfer.Status.COMPLETED)

    def test_receive_twice_is_rejected(self):
        stock = self._stock('Amlodipine 5mg')
        self._batch(stock, 10)
        transfer = self._transfer(stock, 10)
        self._login(self.admin)
        self.client.post(f'/api/inventory/transfers/{transfer.pk}/approve/', {}, format='json')
        self.client.post(f'/api/inventory/transfers/{transfer.pk}/receive/',
                         {'lines': []}, format='json')

        second = self.client.post(
            f'/api/inventory/transfers/{transfer.pk}/receive/', {'lines': []}, format='json')
        self.assertEqual(second.status_code, 409, second.data)
        # Only one batch should have been created at the destination.
        self.assertEqual(StockBatch.objects.filter(
            stock__branch=self.branch2,
            stock__medication_name__iexact='Amlodipine 5mg').count(), 1)

    # ── Stock take ──────────────────────────────────────────────────────
    def test_stock_take_completion_posts_variance(self):
        stock = self._stock('Hydrocortisone Cream')
        self._batch(stock, 100)
        count = InventoryCount.objects.create(name='Cycle count', branch=self.branch)
        InventoryCountLine.objects.create(
            count=count, stock=stock, expected_quantity=100, counted_quantity=92)

        self._login(self.admin)
        response = self.client.post(
            f'/api/inventory/counts/{count.pk}/complete/', {}, format='json')

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(stock.total_quantity, 92)
        count.refresh_from_db()
        self.assertEqual(count.status, InventoryCount.Status.COMPLETED)
        self.assertEqual(
            StockAdjustment.objects.filter(
                stock=stock, reason=StockAdjustment.Reason.COUNT_CORRECTION).count(), 1)

    def test_stock_take_sheet_respects_its_branch(self):
        mine = self._stock('Branch One Item', branch=self.branch)
        self._batch(mine, 5)
        other = self._stock('Branch Two Item', branch=self.branch2)
        self._batch(other, 5)

        count = InventoryCount.objects.create(name='Branch 1 count', branch=self.branch)
        self._login(self.admin)

        response = self.client.post(
            f'/api/inventory/counts/{count.pk}/generate-sheet/', {}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(
            set(count.lines.values_list('stock__medication_name', flat=True)),
            {'Branch One Item'})

    # ── Movement report ─────────────────────────────────────────────────
    def test_movement_report_counts_sales_order_outflow_once(self):
        stock = self._stock('Sold Via Order')
        self._batch(stock, 100)
        StockAdjustment.objects.create(
            stock=stock, quantity_change=-7,
            reason=StockAdjustment.Reason.SALES_ORDER, notes='SO-1',
        )
        self._login(self.admin)

        data = self.client.get('/api/inventory/stock-movements/').data
        self.assertEqual(data['kpis']['total_out'], 7)
        so_rows = [m for m in data['movements'] if m['reason'] == 'sales_order']
        self.assertEqual(len(so_rows), 1)

    # ── Item traceability ───────────────────────────────────────────────
    def test_trace_walks_receipt_to_sale_and_reconciles(self):
        """A lot received then part-sold must reconcile and carry a digest."""
        stock = self._stock('Traced Item')
        batch = self._batch(stock, 100)                     # 100 in
        StockAdjustment.objects.create(
            stock=stock, batch=batch, quantity_change=-25,
            reason=StockAdjustment.Reason.DAMAGE, notes='Dropped',
        )
        batch.refresh_from_db()
        batch.quantity_remaining = 75
        batch.save(update_fields=['quantity_remaining'])
        self._login(self.admin)

        res = self.client.get(f'/api/inventory/trace/items/{stock.pk}/')
        self.assertEqual(res.status_code, 200)
        data = res.data

        self.assertEqual(data['summary']['received'], 100)
        self.assertEqual(data['summary']['on_hand'], 75)
        self.assertEqual(data['summary']['adjusted'], -25)
        # 100 received, 25 adjusted out -> 75 explained, which is what is there.
        self.assertTrue(data['reconciliation']['tied'],
                        data['reconciliation']['verdict'])
        self.assertEqual(data['reconciliation']['residual'], 0)
        self.assertTrue(data['summary']['custody_digest'])
        self.assertGreaterEqual(len(data['events']), 2)

    def test_trace_flags_a_shortfall_it_cannot_explain(self):
        """Physical stock below the ledger must surface as a finding, not silence."""
        stock = self._stock('Unreconciled Item')
        batch = self._batch(stock, 100)
        batch.quantity_remaining = 60        # 40 units vanished, no ledger row
        batch.save(update_fields=['quantity_remaining'])
        self._login(self.admin)

        res = self.client.get(f'/api/inventory/trace/items/{stock.pk}/')
        data = res.data
        self.assertFalse(data['reconciliation']['tied'])
        self.assertEqual(data['reconciliation']['residual'], -40)
        labels = [a['label'] for a in data['anomalies']]
        self.assertIn('Trace does not reconcile', labels)

    def test_trace_export_returns_csv_with_the_custody_digest(self):
        stock = self._stock('Exported Item')
        self._batch(stock, 12)
        self._login(self.admin)

        res = self.client.get(f'/api/inventory/trace/items/{stock.pk}/export/')
        self.assertEqual(res.status_code, 200)
        self.assertIn('text/csv', res['Content-Type'])
        self.assertIn('attachment', res['Content-Disposition'])
        body = res.content.decode('utf-8')
        self.assertIn('Custody digest', body)
        self.assertIn('Goods received', body)

    def test_trace_window_is_not_compared_against_all_time_stock(self):
        """A date-bounded trace must not claim the ledger is broken.

        ``on_hand`` is the all-time physical balance while a windowed trace only
        sees the movements inside the range, so a pre-window receipt would show
        up as an unexplained surplus. The verdict has to say "not comparable"
        rather than reporting a failure that does not exist.
        """
        stock = self._stock('Windowed Item')
        self._batch(stock, 50)
        StockBatch.objects.create(
            stock=stock, batch_number='W-LATE', quantity_received=10,
            quantity_remaining=10,
        )
        self._login(self.admin)

        full = self.client.get(f'/api/inventory/trace/items/{stock.pk}/').data
        self.assertTrue(full['reconciliation']['comparable'])
        self.assertFalse(full['window']['windowed'])

        # A window that starts after the receipts leaves events behind, so the
        # comparison against stock on hand is meaningless.
        res = self.client.get(f'/api/inventory/trace/items/{stock.pk}/',
                              {'date_to': '2000-01-01'})
        windowed = res.data
        self.assertTrue(windowed['window']['windowed'])
        self.assertFalse(windowed['reconciliation']['comparable'])
        self.assertIn('Not comparable', windowed['reconciliation']['verdict'])
        self.assertNotIn('Trace does not reconcile',
                         [a['label'] for a in windowed['anomalies']])

    def test_trace_search_matches_a_lot_number(self):
        stock = self._stock('Lot Searchable')
        StockBatch.objects.create(
            stock=stock, batch_number='LOT-XYZ-999',
            quantity_received=5, quantity_remaining=5,
        )
        self._stock('Different Item')
        self._login(self.admin)

        res = self.client.get('/api/inventory/trace/', {'q': 'XYZ-999'})
        self.assertEqual(res.status_code, 200)
        names = [r['name'] for r in res.data['results']]
        self.assertEqual(names, ['Lot Searchable'])

    def test_trace_search_quantities_are_not_multiplied_by_lots(self):
        """Guards a real bug: joining ``batches`` to count or to match a lot
        number back-multiplied every ``Sum`` in ``with_quantities()``, so a
        30-unit item with 3 lots was advertised as 90 on the picker."""
        stock = self._stock('Multi Lot')
        for index in range(3):
            StockBatch.objects.create(
                stock=stock, batch_number=f'MULTI-{index}',
                quantity_received=10, quantity_remaining=10,
            )
        self._login(self.admin)

        truth = MedicationStock.objects.with_quantities().get(pk=stock.pk).total_quantity
        self.assertEqual(truth, 30)

        for term in ('Multi Lot', 'MULTI-1'):
            with self.subTest(search=term):
                res = self.client.get('/api/inventory/trace/', {'q': term})
                row = next(r for r in res.data['results'] if r['id'] == stock.pk)
                self.assertEqual(row['on_hand'], 30)
                self.assertEqual(row['lots'], 3)

    def test_trace_pdf_is_a_branded_custody_record(self):
        stock = self._stock('Documented Item')
        self._batch(stock, 40)
        self._login(self.admin)

        res = self.client.get(f'/api/inventory/trace/items/{stock.pk}/pdf/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res['Content-Type'], 'application/pdf')
        self.assertIn('attachment', res['Content-Disposition'])
        self.assertIn('.pdf', res['Content-Disposition'])
        self.assertGreater(len(res.content), 4000)
        self.assertEqual(res.content[:5], b'%PDF-')

        payload = self.client.get(f'/api/inventory/trace/items/{stock.pk}/').data
        digest = payload['summary']['custody_digest']
        self.assertTrue(digest)

        # The document must state the digest it is attesting to, on every page
        # run, so a printed copy can be checked against a regenerated one.
        import pymupdf
        doc = pymupdf.open(stream=res.content, filetype='pdf')
        try:
            pages = [doc[i].get_text() for i in range(len(doc))]
        finally:
            doc.close()
        text = '\n'.join(pages)
        self.assertIn('Chain of Custody Record', text)
        self.assertIn('Item under trace', text)
        self.assertIn('Reconciliation', text)
        self.assertIn('Movement ledger', text)
        self.assertIn('Attestation and verification', text)
        self.assertIn(digest[:16], text)
        self.assertIn('Documented Item', text)
        # Footer credit is on *every* page, not just the first.
        for index, page in enumerate(pages):
            with self.subTest(page=index + 1):
                self.assertIn('Powered by AdhereMed', page)
                self.assertIn(f'Page {index + 1} of {len(pages)}', page)

    def test_trace_pdf_is_never_watermarked(self):
        """The custody record prints clean, even if a watermark is requested.

        Diagonal text over an attestation reduces the legibility of the figures
        being signed for, so the document has no watermark at any opacity.
        """
        stock = self._stock('Clean Record Item')
        self._batch(stock, 5)
        self._login(self.admin)

        import pymupdf

        def page_text(query):
            res = self.client.get(f'/api/inventory/trace/items/{stock.pk}/pdf/',
                                  query)
            self.assertEqual(res.status_code, 200)
            doc = pymupdf.open(stream=res.content, filetype='pdf')
            try:
                return '\n'.join(doc[i].get_text() for i in range(len(doc)))
            finally:
                doc.close()

        for query in ({}, {'watermark': 'Stamped'},
                      {'watermark': 'CONFIDENTIAL', 'watermark_opacity': '0.6'}):
            with self.subTest(query=query):
                text = page_text(query)
                self.assertNotIn('STAMPED', text.upper())
                self.assertNotIn('CONFIDENTIAL', text.upper())

    def test_trace_pdf_404s_for_an_unknown_item(self):
        self._login(self.admin)
        res = self.client.get('/api/inventory/trace/items/999999/pdf/')
        self.assertEqual(res.status_code, 404)

    # ── Branch awareness ────────────────────────────────────────────────
    def test_trace_refuses_another_branchs_item_on_every_endpoint(self):
        """A branch-scoped user must not walk ids into another warehouse.

        404 rather than 403 on purpose: a distinct code would confirm that the
        id exists somewhere the reader cannot see.
        """
        foreign = self._stock('Foreign Item', branch=self.branch)
        self._batch(foreign, 20)
        self._login(self.manager)          # branch_admin locked to branch2

        for suffix in ('', 'export/', 'pdf/'):
            with self.subTest(endpoint=suffix or 'trace'):
                res = self.client.get(
                    f'/api/inventory/trace/items/{foreign.pk}/{suffix}')
                self.assertEqual(res.status_code, 404)

    def test_trace_serves_a_scoped_users_own_branch(self):
        own = self._stock('Own Shelf Item', branch=self.branch2)
        self._batch(own, 15)
        self._login(self.manager)

        res = self.client.get(f'/api/inventory/trace/items/{own.pk}/')
        self.assertEqual(res.status_code, 200)
        scope = res.data['branch_scope']
        self.assertTrue(scope['locked'])
        self.assertEqual(scope['branch_id'], self.branch2.id)
        self.assertIn(self.branch2.name, scope['label'])

    def test_trace_scope_is_open_for_an_admin(self):
        anywhere = self._stock('Admin Visible', branch=self.branch2)
        self._batch(anywhere, 8)
        self._login(self.admin)

        res = self.client.get(f'/api/inventory/trace/items/{anywhere.pk}/')
        self.assertEqual(res.status_code, 200)
        scope = res.data['branch_scope']
        self.assertFalse(scope['locked'])
        self.assertIn('All warehouses', scope['label'])

    def test_trace_search_cannot_be_steered_to_another_branch(self):
        self._stock('Mine', branch=self.branch2)
        self._stock('Theirs', branch=self.branch)
        self._login(self.manager)

        # The explicit filter must lose to the user's own branch lock.
        res = self.client.get('/api/inventory/trace/',
                              {'branch': self.branch.id})
        self.assertEqual(res.status_code, 200)
        names = [r['name'] for r in res.data['results']]
        self.assertEqual(names, ['Mine'])
        self.assertTrue(res.data['branch_scope']['locked'])

    def test_trace_search_filters_by_branch_for_an_admin(self):
        self._stock('Main Only', branch=self.branch)
        self._stock('North Only', branch=self.branch2)
        self._login(self.admin)

        res = self.client.get('/api/inventory/trace/',
                              {'branch': self.branch2.id})
        self.assertEqual([r['name'] for r in res.data['results']], ['North Only'])

        everything = self.client.get('/api/inventory/trace/')
        self.assertCountEqual([r['name'] for r in everything.data['results']],
                              ['Main Only', 'North Only'])

    def test_trace_branches_endpoint_respects_the_branch_lock(self):
        self._stock('Counted', branch=self.branch2)
        self._stock('Also Counted', branch=self.branch2)

        self._login(self.manager)
        scoped = self.client.get('/api/inventory/trace/branches/')
        self.assertEqual(scoped.status_code, 200)
        self.assertTrue(scoped.data['locked'])
        self.assertEqual(scoped.data['branch_id'], self.branch2.id)
        self.assertEqual([b['id'] for b in scoped.data['branches']],
                         [self.branch2.id])
        self.assertEqual(scoped.data['branches'][0]['items'], 2)

        self._login(self.admin)
        wide = self.client.get('/api/inventory/trace/branches/')
        self.assertFalse(wide.data['locked'])
        self.assertIsNone(wide.data['branch_id'])
        self.assertCountEqual([b['id'] for b in wide.data['branches']],
                              [self.branch.id, self.branch2.id])

    def test_trace_exports_state_the_branch_scope(self):
        """Both the CSV and the PDF must say which warehouses they cover.

        Two exports of the same item can reconcile differently depending on
        whether the reader was locked to one warehouse, so the record has to
        carry the scope rather than leave it implicit.
        """
        stock = self._stock('Scoped Item', branch=self.branch2)
        self._batch(stock, 30)
        self._login(self.manager)

        csv_res = self.client.get(
            f'/api/inventory/trace/items/{stock.pk}/export/')
        self.assertEqual(csv_res.status_code, 200)
        body = csv_res.content.decode('utf-8')
        self.assertIn('Branch scope', body)
        self.assertIn('locked to the reader', body)

        pdf_res = self.client.get(f'/api/inventory/trace/items/{stock.pk}/pdf/')
        self.assertEqual(pdf_res.status_code, 200)
        import pymupdf
        doc = pymupdf.open(stream=pdf_res.content, filetype='pdf')
        try:
            text = '\n'.join(doc[i].get_text() for i in range(len(doc)))
        finally:
            doc.close()
        self.assertIn('BRANCH SCOPE', text.upper())
        self.assertIn(self.branch2.name, text)
        self.assertIn('Single warehouse', text)

    # ── Batch (lot) trace ───────────────────────────────────────────────
    def _lot_stock(self, name, lot, qty, *, branch=None, expiry_days=None):
        """A stock item with one identifiable lot."""
        stock = self._stock(name, branch=branch)
        StockBatch.objects.create(
            stock=stock,
            branch=branch or self.branch,
            batch_number=lot,
            quantity_received=qty,
            quantity_remaining=qty,
            cost_price_per_unit='10.00',
            expiry_date=(None if expiry_days is None
                         else timezone.localdate() + timedelta(days=expiry_days)),
        )
        return stock

    def test_batch_trace_walks_a_lot_to_the_customer(self):
        """The recall question: where did these specific units go?"""
        stock = self._lot_stock('Lot Traced Item', 'LOT-TRACE-1', 500)
        batch = stock.batches.first()

        sale = POSTransaction.objects.create(
            transaction_number='TXN-LOT-1', branch=self.branch,
            status='completed', payment_method='cash',
            customer_name='Mary Wanjiku',
        )
        TransactionItem.objects.create(
            transaction=sale, stock=stock, batch=batch,
            medication_name='Lot Traced Item',
            quantity=40, unit_price='20.00', total_price='800.00',
        )

        self._login(self.admin)
        res = self.client.get('/api/inventory/trace/batch/',
                              {'lot': 'LOT-TRACE-1'})
        self.assertEqual(res.status_code, 200)
        data = res.data

        self.assertEqual(data['summary']['batch_number'], 'LOT-TRACE-1')
        self.assertEqual(data['summary']['received'], 500)
        self.assertEqual(data['summary']['sold'], 40)
        self.assertEqual(data['summary']['on_hand'], 500)  # fixture, not decremented
        self.assertTrue(data['summary']['custody_digest'])

        kinds = [e['kind'] for e in data['events']]
        self.assertIn('receipt', kinds)
        self.assertIn('sale', kinds)

        # The call-list is the point of the document.
        self.assertEqual(len(data['exposure']), 1)
        self.assertEqual(data['exposure'][0]['party'], 'Mary Wanjiku')
        self.assertEqual(data['exposure'][0]['quantity'], 40)
        self.assertEqual(data['summary']['units_downstream'], 40)

    def test_batch_trace_aggregates_a_lot_across_items_and_warehouses(self):
        """A lot number is not unique per item or per warehouse.

        Treating it as unique would report two half-truths instead of one
        complete answer — the exact failure that makes a recall miss stock.
        """
        a = self._lot_stock('Shared Lot A', 'SHARED-1', 100, branch=self.branch)
        b = self._lot_stock('Shared Lot B', 'SHARED-1', 250, branch=self.branch2)

        self._login(self.admin)
        res = self.client.get('/api/inventory/trace/batch/', {'lot': 'SHARED-1'})
        self.assertEqual(res.status_code, 200)
        data = res.data

        self.assertEqual(data['summary']['items'], 2)
        self.assertEqual(data['summary']['branches'], 2)
        self.assertCountEqual(data['summary']['item_names'],
                              ['Shared Lot A', 'Shared Lot B'])
        self.assertEqual(data['summary']['received'], 350)
        self.assertEqual(data['summary']['on_hand'], 350)
        self.assertEqual(len(data['positions']), 2)
        # Two receipts, one per lot row - not one merged receipt.
        receipts = [e for e in data['events'] if e['kind'] == 'receipt']
        self.assertEqual(len(receipts), 2)

    def test_batch_trace_search_lists_each_lot_once(self):
        """The picker must aggregate by lot, not list one row per batch row."""
        self._lot_stock('Picker A', 'AGGR-1', 10, branch=self.branch)
        self._lot_stock('Picker B', 'AGGR-1', 20, branch=self.branch2)
        self._login(self.admin)

        res = self.client.get('/api/inventory/trace/batches/', {'q': 'AGGR-1'})
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['count'], 1)
        row = res.data['results'][0]
        self.assertEqual(row['batch_number'], 'AGGR-1')
        self.assertEqual(row['items'], 2)
        self.assertEqual(row['received'], 30)
        self.assertEqual(row['on_hand'], 30)
        self.assertEqual(row['label'], 'Picker A +1 more')

    def test_batch_trace_is_branch_scoped(self):
        """A scoped user sees only their own lot rows, and cannot probe others."""
        self._lot_stock('Mine Lot', 'SCOPE-LOT-1', 60, branch=self.branch2)
        self._lot_stock('Theirs Lot', 'SCOPE-LOT-2', 90, branch=self.branch)
        self._login(self.manager)          # branch_admin locked to branch2

        own = self.client.get('/api/inventory/trace/batch/',
                              {'lot': 'SCOPE-LOT-1'})
        self.assertEqual(own.status_code, 200)
        self.assertEqual(own.data['summary']['received'], 60)
        self.assertTrue(own.data['branch_scope']['locked'])
        self.assertEqual(own.data['summary']['branches'], 1)

        foreign = self.client.get('/api/inventory/trace/batch/',
                                  {'lot': 'SCOPE-LOT-2'})
        self.assertEqual(foreign.status_code, 404)

        # The picker must not leak the other warehouse either.
        listing = self.client.get('/api/inventory/trace/batches/', {'limit': 200})
        codes = [r['batch_number'] for r in listing.data['results']]
        self.assertIn('SCOPE-LOT-1', codes)
        self.assertNotIn('SCOPE-LOT-2', codes)

    def test_batch_trace_validates_its_parameters(self):
        self._login(self.admin)
        self.assertEqual(
            self.client.get('/api/inventory/trace/batch/').status_code, 400)
        self.assertEqual(
            self.client.get('/api/inventory/trace/batch/',
                            {'lot': 'NOPE-9999'}).status_code, 404)
        # Lot matching is case-insensitive so a typed barcode still resolves.
        self._lot_stock('Case Item', 'Case-Lot-9', 5)
        self.assertEqual(
            self.client.get('/api/inventory/trace/batch/',
                            {'lot': 'case-lot-9'}).status_code, 200)

    def test_batch_trace_flags_units_leaving_before_receipt(self):
        """Backdated receipts or off-book issues must be reported, not smoothed."""
        stock = self._lot_stock('Backdated Item', 'BACK-1', 50)
        batch = stock.batches.first()
        sale = POSTransaction.objects.create(
            transaction_number='TXN-BACK-1', branch=self.branch,
            status='completed', payment_method='cash',
        )
        TransactionItem.objects.create(
            transaction=sale, stock=stock, batch=batch,
            medication_name='Backdated Item',
            quantity=10, unit_price='5.00', total_price='50.00',
        )
        # received_date is auto_now_add, so force the sale into the past and
        # the receipt into the future to create the inversion deliberately.
        POSTransaction.objects.filter(pk=sale.pk).update(
            created_at=timezone.now() - timedelta(days=30))
        StockBatch.objects.filter(pk=batch.pk).update(
            received_date=timezone.localdate() + timedelta(days=2))

        self._login(self.admin)
        res = self.client.get('/api/inventory/trace/batch/', {'lot': 'BACK-1'})
        self.assertEqual(res.status_code, 200)
        labels = [a['label'] for a in res.data['anomalies']]
        self.assertIn('Units left before the lot was received', labels)

    def test_batch_trace_exports_csv_and_pdf(self):
        stock = self._lot_stock('Dossier Item', 'DOSS-1', 200, expiry_days=-3)
        batch = stock.batches.first()
        sale = POSTransaction.objects.create(
            transaction_number='TXN-DOSS-1', branch=self.branch,
            status='completed', payment_method='mpesa',
            customer_name='Joseph Otieno',
        )
        TransactionItem.objects.create(
            transaction=sale, stock=stock, batch=batch,
            medication_name='Dossier Item',
            quantity=25, unit_price='9.00', total_price='225.00',
        )
        self._login(self.admin)
        digest = self.client.get('/api/inventory/trace/batch/',
                                 {'lot': 'DOSS-1'}).data['summary']['custody_digest']

        csv_res = self.client.get('/api/inventory/trace/batch/export/',
                                  {'lot': 'DOSS-1'})
        self.assertEqual(csv_res.status_code, 200)
        self.assertIn('text/csv', csv_res['Content-Type'])
        self.assertIn('.csv', csv_res['Content-Disposition'])
        body = csv_res.content.decode('utf-8')
        self.assertIn('AdhereMed batch traceability record', body)
        self.assertIn(digest, body)
        self.assertIn('Recipients', body)
        self.assertIn('Joseph Otieno', body)

        pdf_res = self.client.get('/api/inventory/trace/batch/pdf/',
                                  {'lot': 'DOSS-1'})
        self.assertEqual(pdf_res.status_code, 200)
        self.assertEqual(pdf_res['Content-Type'], 'application/pdf')
        self.assertEqual(pdf_res.content[:5], b'%PDF-')

        import pymupdf
        doc = pymupdf.open(stream=pdf_res.content, filetype='pdf')
        try:
            pages = [doc[i].get_text() for i in range(len(doc))]
        finally:
            doc.close()
        text = '\n'.join(pages)
        for heading in ('Lot under trace', 'Reconciliation', 'Recall exposure',
                        'Positions by item and warehouse', 'Movement ledger',
                        'Recipients and exit points', 'Attestation'):
            with self.subTest(heading=heading):
                self.assertIn(heading, text)
        self.assertIn('DOSS-1', text)
        self.assertIn(digest[:16], text)
        self.assertIn('Joseph Otieno', text)
        # Footer credit and page numbers on every page, as with the item record.
        for index, page in enumerate(pages):
            with self.subTest(page=index + 1):
                self.assertIn('Powered by AdhereMed', page)
                self.assertIn(f'Page {index + 1} of {len(pages)}', page)

    # ── Scan verify ─────────────────────────────────────────────────────
    def test_scan_reports_which_rule_resolved_it(self):
        """A scan must say *how* it resolved, not just that it did.

        When a read goes wrong the first question is "what did it think I
        scanned?", and that is unanswerable without the winning rule.
        """
        stock = self._stock('Scan Target')
        stock.barcode = 'SCAN-TGT-1'
        stock.save(update_fields=['barcode'])
        batch = self._batch(stock, 20)
        self._login(self.admin)

        for code, expected_type in (
            ('SCAN-TGT-1', 'barcode'),
            (stock.medication_id, 'sku'),
            ('Scan Target', 'name'),
            (batch.batch_number, 'lot'),
            (f'{stock.medication_id}|{batch.batch_number}', 'payload'),
        ):
            with self.subTest(code=code):
                res = self.client.post('/api/inventory/scan/',
                                       {'code': code, 'context': 'pick'},
                                       format='json')
                self.assertEqual(res.status_code, 200)
                self.assertEqual(res.data['match_type'], expected_type)
                self.assertEqual(res.data['stock_id'], stock.id)

    def test_scan_of_an_expired_lot_warns_before_the_units_move(self):
        """A scan that resolves correctly against a lot nobody may sell is
        still a problem, and the scanner is the last place to catch it."""
        stock = self._stock('Expired Lot Item')
        StockBatch.objects.create(
            stock=stock, branch=self.branch, batch_number='EXP-LOT-1',
            quantity_received=40, quantity_remaining=40,
            cost_price_per_unit='5.00',
            expiry_date=timezone.localdate() - timedelta(days=12),
        )
        self._login(self.admin)

        res = self.client.post('/api/inventory/scan/',
                               {'code': 'EXP-LOT-1', 'context': 'pick'},
                               format='json')
        self.assertEqual(res.status_code, 200)
        messages = [w['message'] for w in res.data['warnings']]
        self.assertTrue(any('expired' in m.lower() for m in messages), messages)
        self.assertTrue(any(w['severity'] == 'critical'
                            for w in res.data['warnings']))
        # And it points at the full lot history rather than dead-ending.
        self.assertEqual(res.data['links'][0]['path'],
                         '/ims/inventory/batch-trace?lot=EXP-LOT-1')

    def test_scan_miss_offers_ranked_suggestions(self):
        stock = self._stock('Amoxicillin 500mg Capsule')
        stock.barcode = 'AMX500-CAP'
        stock.save(update_fields=['barcode'])
        self._login(self.admin)

        res = self.client.post('/api/inventory/scan/',
                               {'code': 'AMX500', 'context': 'receive'},
                               format='json')
        self.assertEqual(res.status_code, 409)
        self.assertFalse(res.data['found'])
        self.assertEqual(res.data['match_type'], 'none')
        self.assertEqual(res.data['suggestions'][0]['stock_id'], stock.id)
        self.assertIn('barcode', res.data['suggestions'][0]['why'])

        # Garbage in gets nothing invented back.
        empty = self.client.post('/api/inventory/scan/',
                                 {'code': 'ZZZZZZZZ', 'context': 'receive'},
                                 format='json')
        self.assertEqual(empty.data['suggestions'], [])

    def test_scan_against_an_expected_line_shows_both_sides(self):
        wanted = self._stock('Wanted Item')
        scanned = self._stock('Scanned Item')
        scanned.barcode = 'WRONG-ONE'
        scanned.save(update_fields=['barcode'])
        self._login(self.admin)

        res = self.client.post('/api/inventory/scan/', {
            'code': 'WRONG-ONE', 'context': 'pick',
            'expected_stock': wanted.id,
        }, format='json')
        self.assertEqual(res.status_code, 409)
        self.assertFalse(res.data['is_match'])
        self.assertEqual(res.data['expected_item']['stock_id'], wanted.id)
        self.assertEqual(res.data['expected_item']['medication_name'],
                         'Wanted Item')
        self.assertEqual(res.data['stock_id'], scanned.id)

    def test_scan_analytics_agree_with_the_trail_it_summarises(self):
        """The tiles and the list come from the same rows, so they can never
        disagree — a match rate that does not match the list is worse than none."""
        for index in range(4):
            self.client.post('/api/inventory/scan/', {
                'code': f'GOOD-{index}', 'context': 'pick',
            }, format='json')
        self._login(self.admin)
        # One deliberate miss.
        self.client.post('/api/inventory/scan/',
                         {'code': 'NOTHING-HERE', 'context': 'pick'},
                         format='json')

        data = self.client.get('/api/inventory/scan/', {'days': 30}).data
        analytics = data['analytics']
        rows = data['results']

        self.assertEqual(analytics['total'], len(rows))
        self.assertEqual(analytics['matches'], sum(1 for r in rows if r['is_match']))
        self.assertEqual(analytics['misses'], sum(1 for r in rows if not r['is_match']))
        self.assertAlmostEqual(
            analytics['match_rate'],
            round(analytics['matches'] / analytics['total'] * 100, 1),
            places=1)
        self.assertEqual(sum(c['total'] for c in analytics['by_context']),
                         analytics['total'])

    def test_scan_trail_filters_do_not_drop_unresolved_rows(self):
        """A failed read has no warehouse. Scoping must keep it visible or the
        audit silently loses exactly the rows it exists to hold."""
        mine = self._stock('Scoped Item', branch=self.branch2)
        mine.barcode = 'SCOPED-CODE'
        mine.save(update_fields=['barcode'])
        self._login(self.manager)          # branch_admin locked to branch2

        self.client.post('/api/inventory/scan/',
                         {'code': 'SCOPED-CODE', 'context': 'pick'},
                         format='json')
        self.client.post('/api/inventory/scan/',
                         {'code': 'GHOST-CODE', 'context': 'pick'},
                         format='json')

        data = self.client.get('/api/inventory/scan/', {'days': 30}).data
        codes = [r['code'] for r in data['results']]
        self.assertIn('SCOPED-CODE', codes)
        self.assertIn('GHOST-CODE', codes)
        self.assertTrue(data['branch_scope']['locked'])

    def test_scan_trail_search_and_mismatch_filter(self):
        good = self._stock('Searchable Good')
        good.barcode = 'SRCH-OK'
        good.save(update_fields=['barcode'])
        self._login(self.admin)

        self.client.post('/api/inventory/scan/',
                         {'code': 'SRCH-OK', 'context': 'pick',
                          'reference': 'GRN-778'}, format='json')
        self.client.post('/api/inventory/scan/',
                         {'code': 'SRCH-BAD', 'context': 'count'},
                         format='json')

        by_ref = self.client.get('/api/inventory/scan/',
                                 {'search': 'GRN-778', 'days': 30}).data
        self.assertEqual([r['code'] for r in by_ref['results']], ['SRCH-OK'])

        misses = self.client.get('/api/inventory/scan/',
                                 {'mismatches': 1, 'days': 30}).data
        self.assertTrue(misses['results'])
        self.assertTrue(all(not r['is_match'] for r in misses['results']))

        by_context = self.client.get('/api/inventory/scan/',
                                     {'context': 'count', 'days': 30}).data
        self.assertTrue(all(r['context'] == 'count'
                            for r in by_context['results']))
