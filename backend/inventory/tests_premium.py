"""Tests for the premium inventory layer (Tiers 1-7).

Covers the pure maths, the services and the API contracts that the new
screens depend on. Run with::

    python manage.py test inventory --keepdb
"""
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path
import tempfile

from django.test import SimpleTestCase
from django.utils import timezone
from django_tenants.test.cases import TenantTestCase
from rest_framework.test import APIClient

from accounts.models import User
from inventory.models import (
    CycleCountSchedule,
    DemandForecast,
    InventoryCount,
    InventoryCountLine,
    InventorySettings,
    InventorySnapshot,
    MedicationStock,
    RecallCase,
    StockAdjustment,
    StockAnomaly,
    StockBatch,
    StockPolicy,
    StorageZone,
    SupplierCertificate,
    TemperatureExcursion,
    WarehouseBin,
)
from inventory.services import (
    anomaly,
    bins as bin_service,
    cycle_count,
    expiry,
    forecasting,
    kpis,
    labels as label_service,
    planning,
    quality,
    recall as recall_service,
    replenishment,
    scanning,
    scorecard,
    stock_take,
    valuation,
)
from pharmacy_profile.models import Branch
from staff_profiles.models import StaffProfile


class BaseTenantCase(TenantTestCase):
    """Tenant-backed base.

    Every subclass must expose a unique ``schema_slug`` / ``domain`` — the
    default ``django_tenants`` implementation reuses the schema name ``test``
    for all classes, so one failed setup leaves a Tenant row behind and every
    later class dies on ``Key (schema_name)=(test) already exists``.
    """

    schema_slug = 'premium'
    domain = 'premium.test.localhost'

    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = f'Premium Warehouse {cls.schema_slug}'
        tenant.type = 'inventory'
        tenant.slug = cls.schema_slug

    @classmethod
    def get_test_schema_name(cls):
        return cls.schema_slug

    @classmethod
    def get_test_tenant_domain(cls):
        return cls.domain

    def setUp(self):
        self.branch = Branch.objects.create(name='Main WH', is_main=True)
        self.admin = User.objects.create_user(
            email='premium@test.local', password='x', first_name='Pat',
            last_name='Planner', role='tenant_admin')
        StaffProfile.objects.create(user=self.admin, branch=self.branch)
        self.client = APIClient(HTTP_X_TENANT_SCHEMA=self.tenant.schema_name)

    def _stock(self, name='Paracetamol 500mg', cost='10.00', selling='20.00',
               reorder=10):
        return MedicationStock.objects.create(
            medication_name=name, branch=self.branch,
            cost_price=cost, selling_price=selling, reorder_level=reorder)

    def _batch(self, stock, qty, expiry_days=None, cost=None):
        return StockBatch.objects.create(
            stock=stock,
            batch_number=f'LOT-{stock.pk}-{qty}',
            quantity_received=qty,
            quantity_remaining=qty,
            cost_price_per_unit=cost or stock.cost_price,
            expiry_date=(None if expiry_days is None
                         else timezone.localdate() + timedelta(days=expiry_days)),
        )


# ══════════════════════════════════════════════════════════════════════
#  Forecasting maths (Tier 2) — pure functions
# ══════════════════════════════════════════════════════════════════════
class ForecastingMathsTest(SimpleTestCase):
    """Pure maths — no tenant data needed."""

    def test_z_score_monotonic(self):
        self.assertLess(forecasting.z_for_service_level(90),
                        forecasting.z_for_service_level(99))
        self.assertEqual(forecasting.z_for_service_level(95), 1.645)

    def test_safety_stock_increases_with_variability_and_service(self):
        base = forecasting.safety_stock(10, 2, 5, 0, 90)
        higher_sd = forecasting.safety_stock(10, 5, 5, 0, 90)
        higher_sl = forecasting.safety_stock(10, 2, 5, 0, 99)
        self.assertGreater(higher_sd, base)
        self.assertGreater(higher_sl, base)

    def test_safety_stock_formula_matches_definition(self):
        # SS = z·sqrt(LT·σ² + d̄²·σ_LT²)
        value = forecasting.safety_stock(
            avg_demand=20, demand_stddev=4, lead_time_days=9,
            lead_time_stddev=0, service_level=95)
        expected = 1.645 * (9 * 16) ** 0.5
        self.assertAlmostEqual(value, round(expected, 2), places=2)

    def test_reorder_point(self):
        self.assertEqual(forecasting.reorder_point(10, 5, 20), 70.0)

    def test_eoq_is_minimised_at_sqrt(self):
        eoq = forecasting.economic_order_quantity(3650, 500, 2)
        self.assertAlmostEqual(eoq, (2 * 3650 * 500 / 2) ** 0.5, places=1)
        # Degenerate inputs return 0 rather than raising.
        self.assertEqual(forecasting.economic_order_quantity(0, 500, 2), 0)

    def test_round_to_multiple(self):
        self.assertEqual(forecasting.round_to_multiple(23, 10), 30)
        self.assertEqual(forecasting.round_to_multiple(0, 10), 0)

    def test_abc_classes_pareto(self):
        # One value dominates → it must be class A.
        letters = forecasting.abc_classes([1000, 10, 10, 10])
        self.assertEqual(letters[0], 'A')
        self.assertEqual(letters[-1], 'C')

    def test_xyz_from_coefficient_of_variation(self):
        self.assertEqual(forecasting.classify_xyz(0.1), 'X')
        self.assertEqual(forecasting.classify_xyz(0.4), 'Y')
        self.assertEqual(forecasting.classify_xyz(0.9), 'Z')

    def test_mape(self):
        self.assertEqual(forecasting.mape([10, 10], [10, 10]), 0.0)
        self.assertAlmostEqual(forecasting.mape([10], [20]), 100.0, places=1)


# ══════════════════════════════════════════════════════════════════════
#  ABC / XYZ study (report platform)
# ══════════════════════════════════════════════════════════════════════
def _pdf_text(blob):
    """Decompressed text of every stream, for asserting on what got printed.

    ReportLab writes page content as ``/ASCII85Decode /FlateDecode``, so a raw
    ``zlib.decompress`` finds nothing and every assertion silently compares
    against an empty string. Try plain Flate first, then the a85 wrapper.
    """
    import base64
    import re
    import zlib

    chunks = []
    for match in re.finditer(rb'stream', blob):
        start = match.end()
        while start < len(blob) and blob[start] in (13, 10):
            start += 1
        end = blob.find(b'endstream', start)
        if end < 0:
            continue
        raw = blob[start:end].strip()
        for decode in (lambda data: zlib.decompress(data),
                       lambda data: zlib.decompress(base64.a85decode(
                           b'<~' + data.rstrip(b'~>') + b'~>', adobe=True))):
            try:
                chunks.append(decode(raw).decode('latin-1'))
                break
            except Exception:
                continue
    return '\n'.join(chunks)


class AbcStudyTest(BaseTenantCase):
    """The classification study must be internally consistent.

    The PDF reads everything from ``build_abc_analysis``'s ``meta``, so a
    share that does not add up (or a matrix that disagrees with the class
    counts) would print a confident, wrong document.
    """

    schema_slug = 'prem_abc'
    domain = 'abc.test.localhost'

    def _policy(self, name, on_hand, cost, abc='C', xyz='X'):
        stock = self._stock(name=name, cost=str(cost))
        StockBatch.objects.create(
            stock=stock, batch_number=f'L-{name[:4]}',
            quantity_received=on_hand, quantity_remaining=on_hand,
            cost_price_per_unit=cost)
        return StockPolicy.objects.create(
            stock=stock, abc_class=abc, xyz_class=xyz,
            avg_daily_demand=1.0, reorder_point=5, eoq=20,
            lead_time_days=14, value_share=0)

    def setUp(self):
        super().setUp()
        self._policy('Cheap line', 10, 1, abc='C', xyz='Z')
        self._policy('Mid line', 100, 10, abc='B', xyz='Y')
        self._policy('Vital line', 1000, 100, abc='A', xyz='X')

    def test_snapshot_uses_on_hand_capital(self):
        from inventory.reports.datasets import build_abc_analysis

        result = build_abc_analysis(None)
        meta = result['meta']
        self.assertEqual(meta['value_basis'], 'on_hand')
        self.assertFalse(meta['windowed'])
        # 10x1 + 100x10 + 1000x100 = 101,010
        self.assertEqual(meta['total_value'], 101010.0)

    def test_class_shares_sum_to_one_hundred(self):
        from inventory.reports.datasets import build_abc_analysis

        meta = build_abc_analysis(None)['meta']
        value_pct = sum(c['value_pct'] for c in meta['class_summary'])
        items_pct = sum(c['items_pct'] for c in meta['class_summary'])
        self.assertAlmostEqual(value_pct, 100.0, delta=0.4)
        self.assertAlmostEqual(items_pct, 100.0, delta=0.4)

    def test_matrix_agrees_with_class_counts(self):
        from inventory.reports.datasets import build_abc_analysis

        meta = build_abc_analysis(None)['meta']
        matrix_total = sum(c['count'] for c in meta['matrix'])
        self.assertEqual(matrix_total, meta['concentration']['items'])
        # One cell for each axis pairing.
        self.assertEqual(len(meta['matrix']), 9)

    def test_pareto_curve_is_monotonic_and_ends_at_one_hundred(self):
        from inventory.reports.datasets import build_abc_analysis

        meta = build_abc_analysis(None)['meta']
        curve = meta['pareto']
        self.assertEqual(len(curve), 3)
        shares = [p['cumulative_pct'] for p in curve]
        self.assertEqual(shares, sorted(shares))
        self.assertAlmostEqual(shares[-1], 100.0, delta=0.2)
        # The most valuable item is ranked first.
        self.assertEqual(curve[0]['label'], 'Vital line')

    def test_concentration_counts_the_items_that_make_80_percent(self):
        from inventory.reports.datasets import build_abc_analysis

        meta = build_abc_analysis(None)['meta']
        # The vital line alone is 99% of the value.
        self.assertEqual(meta['concentration']['items_for_80'], 1)

    def test_premium_pdf_renders(self):
        from inventory.reports import abc_render
        from inventory.reports.datasets import build_abc_analysis

        result = build_abc_analysis(None)
        body = abc_render.render_abc_pdf(
            rows=result['rows'], meta=result['meta'],
            business_name='Test Warehouse',
            scope_lines=['All warehouses'],
            prepared_by='Pat Planner')
        self.assertTrue(body.startswith(b'%PDF'))
        self.assertGreater(len(body), 5000)
        text = _pdf_text(body)
        # A classification study, not a custody record.
        self.assertIn('CLASSIFICATION STUDY', text)
        self.assertIn('ABC / XYZ classification study', text)
        self.assertIn('ABC / XYZ matrix', text)
        self.assertNotIn('CUSTODY RECORD', text)

    def test_pdf_without_cost_permission_omits_value_blocks(self):
        from inventory.reports import abc_render
        from inventory.reports.datasets import build_abc_analysis

        result = build_abc_analysis(None)
        body = abc_render.render_abc_pdf(
            rows=result['rows'], meta=result['meta'],
            business_name='Test Warehouse', can_view_cost=False)
        self.assertTrue(body.startswith(b'%PDF'))
        text = _pdf_text(body)
        self.assertIn('Purchase cost is withheld', text)
        # The value curve and money tiles must be gone, not zeroed.
        self.assertNotIn('Value concentration', text)
        self.assertNotIn('Classified value', text)

    def test_generate_endpoint_returns_a_pdf(self):
        self.client.force_authenticate(user=self.admin)
        result = self.client.post(
            '/api/inventory/reports/generate/',
            {'report': 'abc_analysis', 'format': 'pdf'}, format='json')
        self.assertEqual(result.status_code, 200, result.content[:300])
        self.assertEqual(result['Content-Type'], 'application/pdf')
        self.assertTrue(result.content.startswith(b'%PDF'))
        self.assertIsNone(forecasting.mape([0], [5]))

    def test_holt_winters_needs_two_seasons(self):
        short = forecasting.holt_winters([1, 2, 3], days_ahead=2)
        self.assertEqual(len(short), 2)
        long = forecasting.holt_winters(list(range(28)), days_ahead=7)
        self.assertEqual(len(long), 7)
        self.assertTrue(all(v >= 0 for v in long))

    def test_daily_series_fills_gaps_with_zero(self):
        start = date(2026, 1, 1)
        series = forecasting.daily_series([(start, 5)], start, start + timedelta(days=2))
        self.assertEqual(series, [5.0, 0.0, 0.0])


# ══════════════════════════════════════════════════════════════════════
#  Tier 1 — automation
# ══════════════════════════════════════════════════════════════════════
class AutomationTest(BaseTenantCase):
    schema_slug = 'prem_automation'
    domain = 'automation.test.localhost'
    def test_auto_quarantine_blocks_expired_and_removes_from_sellable(self):
        stock = self._stock()
        self._batch(stock, 100)
        expired = self._batch(stock, 40, expiry_days=-3)
        stock.refresh_from_db()
        self.assertEqual(stock.sellable_quantity, 100)

        result = expiry.auto_quarantine_expired()
        self.assertEqual(result['quarantined'], 1)

        expired.refresh_from_db()
        self.assertTrue(expired.is_blocked)
        self.assertIn('Expired', expired.blocked_reason)
        stock.refresh_from_db()
        self.assertEqual(stock.sellable_quantity, 100)
        self.assertEqual(stock.blocked_quantity, 40)

    def test_release_expiry_block_when_date_corrected(self):
        stock = self._stock()
        batch = self._batch(stock, 10, expiry_days=-1)
        expiry.auto_quarantine_expired()
        batch.expiry_date = timezone.localdate() + timedelta(days=90)
        batch.save(update_fields=['expiry_date'])

        result = expiry.release_expired_block()
        self.assertEqual(result['released'], 1)
        batch.refresh_from_db()
        self.assertFalse(batch.is_blocked)

    def test_expiry_alert_ladder_is_deduplicated(self):
        stock = self._stock()
        self._batch(stock, 20, expiry_days=12)

        first = expiry.run_expiry_alerts()
        second = expiry.run_expiry_alerts()
        self.assertGreaterEqual(first['alerts_sent'], 1)
        self.assertEqual(second['alerts_sent'], 0, 'daily tick must not spam')

    def test_write_off_expired_posts_adjustments(self):
        stock = self._stock()
        self._batch(stock, 30, expiry_days=-5)
        expiry.auto_quarantine_expired()
        result = expiry.write_off_expired(user=self.admin)
        self.assertEqual(result['batches_written_off'], 1)
        stock.refresh_from_db()
        self.assertEqual(stock.total_quantity, 0)
        self.assertTrue(StockAdjustment.objects.filter(
            stock=stock, reason=StockAdjustment.Reason.EXPIRY).exists())

    def test_replenishment_uses_sellable_not_physical(self):
        """The old generator read total_quantity, so expired stock hid a
        genuine shortage. It must now suggest a real order."""
        stock = self._stock(reorder=50)
        self._batch(stock, 200, expiry_days=-10)   # all expired
        policy = planning.refresh_policies()['policies_updated']
        self.assertGreaterEqual(policy, 1)

        payload = replenishment.build_suggestions(write=False)
        row = next(r for r in payload['rows'] if r['stock_id'] == stock.id)
        self.assertEqual(row['on_hand'], 0)
        self.assertGreater(row['suggested_quantity'], 0)
        self.assertIn(row['severity'], ('out', 'critical'))

    def test_respects_units_already_on_order(self):
        from purchase_orders.models import PurchaseOrder
        from suppliers.models import Supplier

        stock = self._stock(reorder=100)
        planning.refresh_policies()
        # Give the item a real target so the on-order quantity is a genuine
        # offset rather than the whole (zero) shortfall.
        policy = StockPolicy.objects.get(stock=stock)
        policy.reorder_point = 100
        policy.max_qty = 1000
        policy.order_multiple = 1
        policy.avg_daily_demand = 10
        policy.save()

        supplier = Supplier.objects.create(name='Acme Supplies')
        PurchaseOrder.objects.create(
            po_number='PO-TEST-1', supplier=supplier,
            items=[{'medication_stock_id': stock.id, 'name': stock.medication_name,
                    'qty': 500, 'unit_cost': 10, 'total': 5000}],
            status=PurchaseOrder.Status.SENT, branch=self.branch,
        )
        payload = replenishment.build_suggestions(write=False)
        row = next(r for r in payload['rows'] if r['stock_id'] == stock.id)
        self.assertEqual(row['on_order'], 500)
        # 1000 target − 500 already inbound = 500 to order, not a fresh 1000.
        self.assertEqual(row['suggested_quantity'], 500)

    def test_no_suggestion_when_open_order_covers_the_target(self):
        from purchase_orders.models import PurchaseOrder
        from suppliers.models import Supplier

        stock = self._stock(reorder=100)
        planning.refresh_policies()
        policy = StockPolicy.objects.get(stock=stock)
        policy.reorder_point = 100
        policy.max_qty = 200
        policy.order_multiple = 1
        policy.avg_daily_demand = 10
        policy.save()

        supplier = Supplier.objects.create(name='Acme Supplies')
        PurchaseOrder.objects.create(
            po_number='PO-TEST-2', supplier=supplier,
            items=[{'medication_stock_id': stock.id, 'name': stock.medication_name,
                    'qty': 500, 'unit_cost': 10, 'total': 5000}],
            status=PurchaseOrder.Status.SENT, branch=self.branch,
        )
        payload = replenishment.build_suggestions(write=False)
        self.assertFalse([r for r in payload['rows'] if r['stock_id'] == stock.id],
                         'a fully covered item must not appear on the buy list')

    def test_draft_purchase_orders_creates_drafts(self):
        from purchase_orders.models import PurchaseOrder
        from suppliers.models import Supplier, SupplierItem

        stock = self._stock(reorder=100)
        supplier = Supplier.objects.create(name='Acme Supplies')
        SupplierItem.objects.create(
            supplier=supplier, stock=stock, item_name=stock.medication_name,
            unit_cost=Decimal('9.50'))
        planning.refresh_policies()
        replenishment.build_suggestions(write=True)

        result = replenishment.draft_purchase_orders(user=self.admin)
        self.assertEqual(len(result['purchase_orders']), 1)
        po = PurchaseOrder.objects.get(id=result['purchase_orders'][0]['id'])
        self.assertEqual(po.status, PurchaseOrder.Status.DRAFT)
        self.assertTrue(po.po_number.startswith('AUTO-'))

    def test_draft_reports_lines_without_a_supplier(self):
        """`skipped_no_supplier` used to be hard-coded to 0, so the planner was
        told "nothing to order" when the real problem was a missing supplier."""
        stock = self._stock(reorder=100)
        planning.refresh_policies()

        result = replenishment.draft_purchase_orders(user=self.admin)
        self.assertEqual(result['purchase_orders'], [])
        self.assertGreaterEqual(result['skipped_no_supplier'], 1)
        self.assertIn(stock.medication_name,
                      [o['name'] for o in result['unsupplied']])

    def test_cycle_count_plan_creates_sheet_and_reschedules(self):
        """Creating a sheet must NOT advance the schedule; counting it must.

        ``create_count_from_schedule`` deliberately leaves ``next_due`` alone:
        creating a sheet is not the same as doing the count, and advancing on
        creation let a cancelled or abandoned sheet drop the item out of the
        backlog for a whole cycle. Only ``advance_from_count`` moves it — and
        only for lines that actually carry a counted quantity, so an untouched
        sheet must not move anything either.
        """
        stock = self._stock(reorder=10)
        self._batch(stock, 100)
        planning.refresh_policies()

        cycle_count.replan()
        result = cycle_count.create_count_from_schedule(user=self.admin)
        self.assertEqual(result['counts_created'], 1)

        schedule = CycleCountSchedule.objects.get(stock=stock)
        self.assertGreaterEqual(schedule.next_due, timezone.localdate())
        # A sheet exists but nobody has counted anything yet.
        self.assertIsNone(schedule.last_counted_at)

        count = InventoryCount.objects.get(pk=result['counts'][0]['count_id'])
        # An empty sheet advances nothing.
        cycle_count.advance_from_count(count)
        schedule.refresh_from_db()
        self.assertIsNone(schedule.last_counted_at)

        # Once the line is counted, the item moves to its next cadence.
        count.lines.update(counted_quantity=100)
        cycle_count.advance_from_count(count)

        schedule.refresh_from_db()
        self.assertIsNotNone(schedule.last_counted_at)
        self.assertGreater(schedule.next_due, timezone.localdate())

    def test_abc_cadence_drives_interval(self):
        stock = self._stock()
        self._batch(stock, 100)
        planning.refresh_policies()

        cycle_count.replan()
        # A row exists for every item, and its interval follows the ABC class.
        self.assertTrue(CycleCountSchedule.objects.exists())
        schedule = CycleCountSchedule.objects.get(stock=stock)
        _, expected = cycle_count.cadence_for(schedule.cadence)
        self.assertEqual(schedule.interval_days, expected)
        self.assertIsNotNone(schedule.next_due)

    def test_cycle_plan_endpoint_bootstraps_and_summarises(self):
        """A brand-new tenant has no schedules; reading the plan must create
        them, otherwise the screen is permanently empty and the button dead."""
        stock = self._stock()
        self._batch(stock, 30)
        self.client.force_authenticate(user=self.admin)

        self.assertFalse(CycleCountSchedule.objects.exists())
        response = self.client.get('/api/inventory/cycle-count-plan/')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(CycleCountSchedule.objects.exists())
        self.assertGreaterEqual(response.data['summary']['scheduled'], 1)
        self.assertIn('A', response.data['summary']['by_cadence'])

    def test_daily_digest_notifies_once(self):
        stock = self._stock(reorder=100)
        self._batch(stock, 0)
        first = expiry.__name__ and None  # keep import-used
        from inventory.tasks import daily_digest
        sent = daily_digest()
        self.assertGreaterEqual(sent['digest_sent'], 1)
        again = daily_digest()
        self.assertEqual(again['digest_sent'], 0)


class CyclePlanCoverageTest(BaseTenantCase):
    """The plan must cover every active item, not just the ones seeded first.

    Regression: the endpoint used to bootstrap the schedule only when *zero*
    rows existed. A tenant with three pre-seeded schedules and 31 stock rows
    therefore kept 28 items permanently invisible to the plan — they were
    never scheduled and never counted, and nothing on the screen said so.
    """

    schema_slug = 'prem_cycle'
    domain = 'cycle.test.localhost'

    def _plan(self, **params):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get('/api/inventory/cycle-count-plan/', params)
        self.assertEqual(response.status_code, 200, response.data)
        return response.data

    def test_partial_schedule_is_topped_up(self):
        stocks = [self._stock(name=f'Item {i}') for i in range(5)]
        for stock in stocks:
            self._batch(stock, 10)
            StockPolicy.objects.update_or_create(stock=stock)

        # Simulate the seeded/partial state: only one item has a schedule.
        CycleCountSchedule.objects.create(
            stock=stocks[0], branch=self.branch,
            cadence=CycleCountSchedule.Cadence.C,
            interval_days=365, next_due=timezone.localdate())

        data = self._plan()
        self.assertEqual(data['summary']['items'], 5)
        self.assertEqual(data['summary']['scheduled'], 5)
        self.assertEqual(data['summary']['coverage_pct'], 100.0)
        self.assertEqual(data['summary']['uncovered'], 0)
        self.assertEqual(CycleCountSchedule.objects.count(), 5)

    def test_ensure_coverage_is_a_no_op_when_complete(self):
        stock = self._stock()
        self._batch(stock, 10)
        StockPolicy.objects.update_or_create(stock=stock)
        cycle_count.replan()

        first = cycle_count.ensure_coverage()
        self.assertFalse(first['replanned'])
        second = cycle_count.ensure_coverage()
        self.assertFalse(second['replanned'])

    def test_uncovered_items_are_reported_with_their_value(self):
        stock = self._stock(name='Orphan', cost='25.00')
        self._batch(stock, 4)  # 100 at cost
        data = self._plan()
        # The plan heals itself, so nothing may remain uncovered afterwards.
        self.assertEqual(data['summary']['uncovered'], 0)
        self.assertEqual(len(data['due']), 1)
        self.assertAlmostEqual(data['due'][0]['value'], 100.0, places=2)

    def test_due_rows_carry_classification_and_value(self):
        stock = self._stock(cost='10.00')
        self._batch(stock, 12)
        StockPolicy.objects.update_or_create(
            stock=stock, defaults={'abc_class': 'A'})

        data = self._plan()
        row = data['due'][0]
        self.assertEqual(row['abc_class'], 'A')
        self.assertEqual(row['cadence'], 'A')
        self.assertAlmostEqual(row['on_hand'], 12.0, places=1)
        self.assertAlmostEqual(row['value'], 120.0, places=2)
        self.assertEqual(row['unit'], '')
        self.assertIsNone(row['last_counted_at'])

    def test_cadence_economics_and_branch_coverage(self):
        a = self._stock(name='Fast mover', cost='5.00')
        c = self._stock(name='Slow mover', cost='5.00')
        self._batch(a, 10)
        self._batch(c, 10)
        # Set the classes explicitly — the test is about cadence derivation,
        # not about how the classifier scores two identical items.
        StockPolicy.objects.update_or_create(
            stock=a, defaults={'abc_class': 'A'})
        StockPolicy.objects.update_or_create(
            stock=c, defaults={'abc_class': 'C'})

        data = self._plan()
        self.assertEqual(data['summary']['by_cadence'], {'A': 1, 'B': 0, 'C': 1})
        self.assertEqual(data['summary']['cadence_days']['A'], 30)
        self.assertEqual(len(data['by_branch']), 1)
        branch = data['by_branch'][0]
        self.assertEqual(branch['total'], 2)
        self.assertEqual(branch['planned'], 2)
        self.assertEqual(branch['coverage_pct'], 100.0)
        self.assertAlmostEqual(branch['value'], 100.0, places=2)

    def test_calendar_buckets_work_by_week(self):
        stock = self._stock()
        self._batch(stock, 10)
        StockPolicy.objects.update_or_create(stock=stock)
        cycle_count.replan()
        # Push the single schedule three weeks out.
        future = timezone.localdate() + timedelta(days=21)
        CycleCountSchedule.objects.update(next_due=future)

        data = self._plan(horizon=90)
        calendar = data['calendar']
        self.assertTrue(calendar)
        starts = [week['week_start'] for week in calendar]
        self.assertEqual(starts, sorted(starts))
        self.assertEqual(sum(w['overdue'] + w['due'] + w['upcoming']
                             for w in calendar), 1)
        # A future date lands in an upcoming bucket, never overdue.
        self.assertEqual(sum(w['overdue'] for w in calendar), 0)
        self.assertEqual(len(data['upcoming']), 1)

    def test_accuracy_reflects_completed_counts(self):
        stock = self._stock(cost='2.00')
        self._batch(stock, 100)
        StockPolicy.objects.update_or_create(stock=stock)

        count = InventoryCount.objects.create(
            name='Test count', branch=self.branch,
            status=InventoryCount.Status.COMPLETED)
        InventoryCountLine.objects.create(
            count=count, stock=stock, expected_quantity=100, counted_quantity=100)
        other = self._stock(name='Second')
        self._batch(other, 50)
        InventoryCountLine.objects.create(
            count=count, stock=other, expected_quantity=50, counted_quantity=45)

        data = self._plan()
        accuracy = data['accuracy']
        self.assertEqual(accuracy['scored_lines'], 2)
        self.assertEqual(accuracy['exact'], 1)
        self.assertEqual(accuracy['exact_pct'], 50.0)
        # 5 units absolute variance against 150 expected.
        self.assertAlmostEqual(accuracy['accuracy_pct'], 96.7, places=1)

        statuses = {sheet['status'] for sheet in data['sheets']}
        self.assertIn('completed', statuses)

    # ── Completion integrity ───────────────────────────────────────────
    def test_create_sheet_is_idempotent_per_warehouse(self):
        """A second click must not mint a duplicate sheet.

        Creating a sheet deliberately does not advance the schedule, so the
        button used to be repeatable and every click produced an identical
        copy. Two warehouses quickly became four indistinguishable sheets.
        """
        stock = self._stock()
        self._batch(stock, 40)
        StockPolicy.objects.update_or_create(stock=stock)
        cycle_count.replan()

        first = cycle_count.create_count_from_schedule(user=self.admin)
        self.assertEqual(first['counts_created'], 1)

        second = cycle_count.create_count_from_schedule(user=self.admin)
        self.assertEqual(second['counts_created'], 0)
        self.assertEqual(second['skipped_open'], 1)
        self.assertEqual(InventoryCount.objects.count(), 1)

    def test_completing_a_partial_sheet_is_refused(self):
        stock = self._stock()
        self._batch(stock, 40)
        other = self._stock(name='Second item')
        self._batch(other, 10)
        StockPolicy.objects.update_or_create(stock=stock)

        count = InventoryCount.objects.create(
            name='Partial', branch=self.branch,
            status=InventoryCount.Status.IN_PROGRESS)
        InventoryCountLine.objects.create(
            count=count, stock=stock, expected_quantity=40, counted_quantity=40)
        InventoryCountLine.objects.create(
            count=count, stock=other, expected_quantity=10)  # never counted

        self.client.force_authenticate(user=self.admin)
        response = self.client.post(f'/api/inventory/counts/{count.id}/complete/',
                                    {}, format='json')
        self.assertEqual(response.status_code, 400, response.data)
        self.assertEqual(response.data['outstanding'], 1)
        self.assertEqual(response.data['counted_lines'], 1)
        self.assertIn('allow_partial', response.data['detail'])

        count.refresh_from_db()
        self.assertEqual(count.status, InventoryCount.Status.IN_PROGRESS)

    def test_allow_partial_completes_but_only_advances_counted_items(self):
        """Un-counted items must stay in the backlog, not skip a whole cycle."""
        counted = self._stock(name='Counted')
        self._batch(counted, 40)
        skipped = self._stock(name='Never counted')
        self._batch(skipped, 10)
        StockPolicy.objects.update_or_create(stock=counted)
        StockPolicy.objects.update_or_create(stock=skipped)
        cycle_count.replan()

        count = InventoryCount.objects.create(
            name='Half done', branch=self.branch,
            status=InventoryCount.Status.IN_PROGRESS)
        InventoryCountLine.objects.create(
            count=count, stock=counted, expected_quantity=40, counted_quantity=40)
        InventoryCountLine.objects.create(
            count=count, stock=skipped, expected_quantity=10)

        self.client.force_authenticate(user=self.admin)
        response = self.client.post(f'/api/inventory/counts/{count.id}/complete/',
                                    {'allow_partial': True}, format='json')
        self.assertEqual(response.status_code, 200, response.data)

        count.refresh_from_db()
        self.assertEqual(count.status, InventoryCount.Status.COMPLETED)

        advanced = CycleCountSchedule.objects.get(stock=counted)
        untouched = CycleCountSchedule.objects.get(stock=skipped)
        self.assertIsNotNone(advanced.last_counted_at)
        self.assertGreater(advanced.next_due, timezone.localdate())
        # The item nobody counted keeps its original due date.
        self.assertIsNone(untouched.last_counted_at)
        self.assertLessEqual(untouched.next_due, timezone.localdate())


# ══════════════════════════════════════════════════════════════════════
#  Stock-take board (premium /ims/inventory/stock-take)
# ══════════════════════════════════════════════════════════════════════
class StockTakeBoardTest(BaseTenantCase):
    schema_slug = 'prem_stocktake'
    domain = 'stocktake.test.localhost'

    def _board(self, **params):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get('/api/inventory/stock-take/', params)
        self.assertEqual(response.status_code, 200, response.data)
        return response.data

    def test_open_queue_and_accuracy_are_aggregated(self):
        counted = self._stock(name='Counted item', cost='10.00')
        self._batch(counted, 100)
        blank = self._stock(name='Blank item', cost='5.00')
        self._batch(blank, 40)

        completed = InventoryCount.objects.create(
            name='Done', branch=self.branch,
            status=InventoryCount.Status.COMPLETED,
            completed_at=timezone.now())
        InventoryCountLine.objects.create(
            count=completed, stock=counted,
            expected_quantity=100, counted_quantity=95)
        open_sheet = InventoryCount.objects.create(
            name='Open', branch=self.branch,
            status=InventoryCount.Status.IN_PROGRESS)
        InventoryCountLine.objects.create(
            count=open_sheet, stock=blank, expected_quantity=40)

        data = self._board()
        summary = data['summary']
        self.assertEqual(summary['open_sheets'], 1)
        self.assertEqual(summary['open_lines'], 1)
        self.assertEqual(summary['open_outstanding'], 1)
        self.assertEqual(summary['scored_lines'], 1)
        self.assertEqual(summary['exact_lines'], 0)
        self.assertAlmostEqual(summary['accuracy_pct'], 95.0, places=1)
        self.assertEqual(data['open_sheets'][0]['outstanding'], 1)

        # The actionable queue sorts above closed paperwork.
        self.assertTrue(data['sheets'][0]['is_open'])

        leaders = data['variance_leaders']
        self.assertEqual(len(leaders), 1)
        self.assertEqual(leaders[0]['variance'], -5)
        self.assertAlmostEqual(leaders[0]['variance_value'], -50.0, places=2)

    def test_cost_is_scrubbed_when_the_role_cannot_see_costs(self):
        stock = self._stock(cost='10.00')
        self._batch(stock, 50)
        count = InventoryCount.objects.create(
            name='Done', branch=self.branch,
            status=InventoryCount.Status.COMPLETED,
            completed_at=timezone.now())
        InventoryCountLine.objects.create(
            count=count, stock=stock,
            expected_quantity=50, counted_quantity=45)

        data = stock_take.board(show_cost=False)
        self.assertTrue(data['summary']['cost_hidden'])
        self.assertEqual(data['summary']['variance_value'], 0.0)
        # Unit variance stays visible — only money is scrubbed.
        self.assertEqual(data['variance_leaders'][0]['variance'], -5)
        self.assertEqual(data['variance_leaders'][0]['variance_value'], 0.0)

    # ── Printable documents ────────────────────────────────────────────
    def test_register_pdf_renders_a_letterheaded_document(self):
        stock = self._stock(cost='4.00')
        self._batch(stock, 30)
        count = InventoryCount.objects.create(
            name='PDF check', branch=self.branch,
            status=InventoryCount.Status.COMPLETED,
            completed_at=timezone.now())
        InventoryCountLine.objects.create(
            count=count, stock=stock,
            expected_quantity=30, counted_quantity=28)

        self.client.force_authenticate(user=self.admin)
        response = self.client.get('/api/inventory/stock-take/pdf/')
        self.assertEqual(response.status_code, 200, response.content[:300])
        self.assertEqual(response['Content-Type'], 'application/pdf')
        self.assertIn('attachment;', response['Content-Disposition'])
        self.assertTrue(response.content.startswith(b'%PDF'))
        # The document is built, not an error page streamed as a PDF.
        self.assertGreater(len(response.content), 4000)

    def test_count_sheet_pdf_renders_for_one_sheet(self):
        stock = self._stock(cost='9.00')
        self._batch(stock, 12)
        count = InventoryCount.objects.create(
            name='Walk the aisle', branch=self.branch,
            status=InventoryCount.Status.IN_PROGRESS)
        InventoryCountLine.objects.create(
            count=count, stock=stock, expected_quantity=12)

        self.client.force_authenticate(user=self.admin)
        response = self.client.get(f'/api/inventory/counts/{count.id}/pdf/')
        self.assertEqual(response.status_code, 200, response.content[:300])
        self.assertEqual(response['Content-Type'], 'application/pdf')
        self.assertIn(count.reference, response['Content-Disposition'])
        self.assertTrue(response.content.startswith(b'%PDF'))


# ══════════════════════════════════════════════════════════════════════
#  Tier 2 — planning
# ══════════════════════════════════════════════════════════════════════
class PlanningTest(BaseTenantCase):
    schema_slug = 'prem_planning'
    domain = 'planning.test.localhost'
    def test_refresh_policies_populates_policy(self):
        stock = self._stock()
        self._batch(stock, 500)
        result = planning.refresh_policies()
        self.assertGreaterEqual(result['policies_updated'], 1)

        policy = StockPolicy.objects.get(stock=stock)
        self.assertGreaterEqual(policy.lead_time_days, 1)
        self.assertGreaterEqual(policy.safety_stock, 0)
        self.assertIn(policy.abc_class, {'A', 'B', 'C'})
        self.assertIn(policy.xyz_class, {'X', 'Y', 'Z'})

    def test_manual_lead_time_is_preserved(self):
        stock = self._stock()
        self._batch(stock, 10)
        planning.refresh_policies()
        policy = StockPolicy.objects.get(stock=stock)
        policy.lead_time_days = 42
        policy.is_manual_lead_time = True
        policy.save()

        planning.refresh_policies()
        policy.refresh_from_db()
        self.assertEqual(policy.lead_time_days, 42)

    def test_refresh_forecasts_writes_horizon(self):
        stock = self._stock()
        self._batch(stock, 50)
        result = planning.refresh_forecasts(horizon_days=7)
        self.assertEqual(result['horizon_days'], 7)
        self.assertEqual(
            DemandForecast.objects.filter(stock=stock).count(), 7)
        self.assertTrue(DemandForecast.objects.filter(
            stock=stock, forecast_date__gt=timezone.localdate()).exists())

    def test_forecast_is_idempotent_per_day(self):
        stock = self._stock()
        self._batch(stock, 50)
        planning.refresh_forecasts(horizon_days=5)
        planning.refresh_forecasts(horizon_days=5)
        self.assertEqual(DemandForecast.objects.filter(stock=stock).count(), 5)

    def test_inventory_settings_singleton_and_defaults(self):
        obj = InventorySettings.get()
        self.assertEqual(obj.pk, 1)
        self.assertEqual(obj.service_level, 95)
        self.assertEqual(obj.expiry_alert_days, [90, 60, 30, 14, 7, 1])
        # Saving again must not create a second row.
        obj.service_level = 98
        obj.save()
        self.assertEqual(InventorySettings.objects.count(), 1)
        self.assertEqual(InventorySettings.get().service_level, 98)

    def test_sop_endpoint(self):
        planning.refresh_forecasts(horizon_days=3)
        self.client.force_authenticate(user=self.admin)
        response = self.client.get('/api/inventory/sop/')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertIn('scenarios', response.data)
        self.assertIn('bias_pct', response.data)

    def test_settings_patch_is_authorised(self):
        self.client.force_authenticate(user=self.admin)
        response = self.client.patch('/api/inventory/settings/',
                                     {'service_level': 98}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['service_level'], 98)


class SopPayloadTest(BaseTenantCase):
    """The S&OP screen explains itself — assert the story blocks are there."""

    schema_slug = 'prem_sop'
    domain = 'sop.test.localhost'

    def _sop(self, **params):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get('/api/inventory/sop/', params)
        self.assertEqual(response.status_code, 200, response.data)
        return response.data

    def test_cold_start_reports_blockers_instead_of_blank_charts(self):
        """A tenant with policies but no history still gets a usable answer."""
        stock = self._stock(cost='10.00')
        self._batch(stock, 400)
        planning.refresh_policies()

        data = self._sop()
        self.assertEqual(data['series'], [])
        self.assertEqual(data['horizon_weeks'], [])
        self.assertGreater(data['blockers'], 0)
        self.assertFalse(data['ready'])

        # Every readiness row must explain itself, not just fail silently.
        keys = {row['key'] for row in data['readiness']}
        self.assertEqual(keys, {'history', 'forecasts', 'demand', 'lead_time',
                                'policy', 'accuracy'})
        for row in data['readiness']:
            self.assertTrue(row['detail'], row)
            if not row['done']:
                self.assertTrue(row['action'], row)

    def test_capital_is_split_by_abc_class(self):
        a = self._stock(name='Budget A', cost='100.00')
        b = self._stock(name='Budget B', cost='10.00')
        self._batch(a, 10)      # 1,000
        self._batch(b, 5)       # 50
        planning.refresh_policies()

        StockPolicy.objects.filter(stock=a).update(abc_class='A')
        StockPolicy.objects.filter(stock=b).update(abc_class='C')

        data = self._sop()
        capital = {row['abc']: row for row in data['planning']['capital']}
        self.assertAlmostEqual(data['planning']['capital_total'], 1050.0, places=2)
        self.assertAlmostEqual(capital['A']['value'], 1000.0, places=2)
        self.assertAlmostEqual(capital['C']['value'], 50.0, places=2)
        self.assertAlmostEqual(capital['A']['share'], 95.2, places=1)

    def test_ladder_carries_z_and_marginal_cost(self):
        stock = self._stock(cost='5.00')
        self._batch(stock, 500)
        planning.refresh_policies()
        # Give the item a demand profile so safety stock reacts to the level.
        StockPolicy.objects.filter(stock=stock).update(
            avg_daily_demand=20.0, demand_stddev=6.0, lead_time_days=14,
            lead_time_stddev=2.0, safety_stock=0.0)

        data = self._sop()
        ladder = data['ladder']
        self.assertEqual([r['service_level_pct'] for r in ladder], [90, 95, 98, 99])
        self.assertEqual([r['z'] for r in ladder], [1.28, 1.645, 2.05, 2.33])
        self.assertEqual(sum(1 for r in ladder if r['is_current']), 1)

        # Extra capital must be non-decreasing in the service level.
        capitals = [r['extra_capital'] for r in ladder]
        self.assertEqual(capitals, sorted(capitals))
        self.assertGreater(capitals[-1], 0)
        # Marginal cost is only defined for a step up from the previous rung.
        self.assertIsNone(ladder[0]['marginal_per_point'])
        for rung in ladder[1:]:
            self.assertIsNotNone(rung['marginal_per_point'])

    def test_horizon_is_bucketed_by_week(self):
        stock = self._stock()
        self._batch(stock, 500)
        planning.refresh_policies()
        planning.refresh_forecasts(horizon_days=21)

        data = self._sop()
        self.assertGreater(data['horizon']['points'], 0)
        self.assertGreaterEqual(len(data['horizon_weeks']), 3)
        total_week = sum(week['units'] for week in data['horizon_weeks'])
        self.assertAlmostEqual(total_week, data['horizon']['units'], places=2)
        # Buckets come back oldest-first so the chart reads left to right.
        starts = [week['start'] for week in data['horizon_weeks']]
        self.assertEqual(starts, sorted(starts))

    def test_accuracy_bands_cover_every_scored_item(self):
        stock = self._stock()
        self._batch(stock, 500)
        planning.refresh_policies()
        # Two scored days: one near-perfect, one badly wrong.
        DemandForecast.objects.create(
            stock=stock, branch=self.branch,
            forecast_date=timezone.localdate() - timedelta(days=2),
            predicted_qty=100, actual_qty=100, mape=0)
        DemandForecast.objects.create(
            stock=stock, branch=self.branch,
            forecast_date=timezone.localdate() - timedelta(days=1),
            predicted_qty=100, actual_qty=40, mape=60)

        self.client.force_authenticate(user=self.admin)
        response = self.client.get('/api/inventory/forecasts/accuracy/')
        self.assertEqual(response.status_code, 200, response.data)
        data = response.data
        self.assertIn('bands', data)
        self.assertEqual([b['label'] for b in data['bands']],
                         ['0–5%', '5–10%', '10–20%', '20–30%', '30%+'])
        self.assertEqual(sum(b['count'] for b in data['bands']),
                         data['items_scored'])
        self.assertIn(data['rating'], {'excellent', 'good', 'fair', 'poor',
                                       'unscored'})



# ══════════════════════════════════════════════════════════════════════
#  Tier 3 — traceability
# ══════════════════════════════════════════════════════════════════════
class RecallTest(BaseTenantCase):
    schema_slug = 'prem_recall'
    domain = 'recall.test.localhost'
    def test_trace_finds_on_hand_units(self):
        stock = self._stock()
        batch = self._batch(stock, 60)
        case = RecallCase.objects.create(
            title='Defective lot', batch_number=batch.batch_number,
            medication_name=stock.medication_name,
            reason=RecallCase.Reason.QUALITY, severity='critical')

        totals = recall_service.trace_case(case)
        self.assertEqual(totals['batches'], 1)
        self.assertEqual(totals['on_hand'], 60)
        self.assertTrue(case.lines.filter(touch='on_hand').exists())
        case.refresh_from_db()
        self.assertEqual(case.status, RecallCase.Status.TRACING)

    def test_trace_is_idempotent(self):
        stock = self._stock()
        batch = self._batch(stock, 20)
        case = RecallCase.objects.create(
            title='Lot', batch_number=batch.batch_number,
            medication_name=stock.medication_name)
        recall_service.trace_case(case)
        recall_service.trace_case(case)
        self.assertEqual(case.lines.count(), 1)

    def test_quarantine_blocks_batches_and_items(self):
        stock = self._stock()
        batch = self._batch(stock, 30)
        case = RecallCase.objects.create(
            title='Recall', batch_number=batch.batch_number,
            medication_name=stock.medication_name)
        recall_service.trace_case(case)
        result = recall_service.quarantine_case(case, user=self.admin)

        self.assertEqual(result['batches_blocked'], 1)
        batch.refresh_from_db()
        self.assertTrue(batch.is_blocked)
        policy = StockPolicy.objects.get(stock=stock)
        self.assertTrue(policy.is_quarantined)
        case.refresh_from_db()
        self.assertEqual(case.status, RecallCase.Status.QUARANTINED)

    def test_quarantined_stock_is_not_sellable(self):
        stock = self._stock()
        batch = self._batch(stock, 25)
        case = RecallCase.objects.create(
            title='Recall', batch_number=batch.batch_number,
            medication_name=stock.medication_name)
        recall_service.trace_case(case)
        recall_service.quarantine_case(case)
        stock.refresh_from_db()
        self.assertEqual(stock.sellable_quantity, 0)

    def test_quarantine_locks_the_lot_without_a_trace(self):
        """A recall must contain the stock even if the trace never ran.

        Quarantine used to derive its batch list from the traced lines, so a
        case created while the trace failed left every unit on sale.
        """
        stock = self._stock()
        batch = self._batch(stock, 40)
        case = RecallCase.objects.create(
            title='Recall before trace', batch_number=batch.batch_number,
            medication_name=stock.medication_name)
        self.assertFalse(case.lines.exists())

        result = recall_service.quarantine_case(case)

        batch.refresh_from_db()
        self.assertTrue(batch.is_blocked)
        self.assertEqual(result['units_blocked'], 40)
        stock.refresh_from_db()
        self.assertEqual(stock.sellable_quantity, 0)
        self.assertTrue(StockPolicy.objects.get(stock=stock).is_quarantined)

    def test_quarantine_locks_every_row_carrying_the_lot(self):
        """One lot number can sit on several items — all of them are locked.

        The case below also names one of the two items, which used to narrow
        the match to that item alone and leave the sibling half of the lot on
        sale. A recall follows the lot number, not the product label.
        """
        first = self._stock(name='Amoxicillin 500mg')
        second = self._stock(name='Amoxicillin 250mg')
        lot = 'LOT-SHARED-01'
        rows = [
            StockBatch.objects.create(
                stock=first, batch_number=lot, quantity_received=30,
                quantity_remaining=30, cost_price_per_unit=first.cost_price),
            StockBatch.objects.create(
                stock=second, batch_number=lot, quantity_received=20,
                quantity_remaining=20, cost_price_per_unit=second.cost_price),
        ]
        case = RecallCase.objects.create(
            title='Shared lot', batch_number=lot,
            medication_name=first.medication_name)
        recall_service.trace_case(case)
        result = recall_service.quarantine_case(case)

        self.assertEqual(result['batches_in_scope'], 2)
        self.assertEqual(result['units_blocked'], 50)
        for row in rows:
            row.refresh_from_db()
            self.assertTrue(row.is_blocked)
        first.refresh_from_db()
        second.refresh_from_db()
        self.assertEqual(first.sellable_quantity, 0)
        self.assertEqual(second.sellable_quantity, 0)

    def test_quarantine_only_locks_the_picked_rows(self):
        """Selecting individual shelf rows must not spread to sibling lots."""
        stock = self._stock()
        picked = self._batch(stock, 10)
        other = StockBatch.objects.create(
            stock=stock, batch_number='LOT-OTHER', quantity_received=15,
            quantity_remaining=15, cost_price_per_unit=stock.cost_price)
        case = RecallCase.objects.create(
            title='Picked rows', batch_number=picked.batch_number,
            medication_name=stock.medication_name,
            target_batch_ids=[picked.id])
        recall_service.quarantine_case(case)

        picked.refresh_from_db()
        other.refresh_from_db()
        self.assertTrue(picked.is_blocked)
        self.assertFalse(other.is_blocked)
        stock.refresh_from_db()
        self.assertEqual(stock.sellable_quantity, 15)

    def test_close_releases_everything(self):
        stock = self._stock()
        batch = self._batch(stock, 15)
        case = RecallCase.objects.create(
            title='Recall', batch_number=batch.batch_number,
            medication_name=stock.medication_name)
        recall_service.trace_case(case)
        recall_service.quarantine_case(case)
        result = recall_service.release_case(case, user=self.admin)

        self.assertEqual(result['batches_released'], 1)
        batch.refresh_from_db()
        self.assertFalse(batch.is_blocked)
        stock.refresh_from_db()
        self.assertEqual(stock.sellable_quantity, 15)
        case.refresh_from_db()
        self.assertEqual(case.status, RecallCase.Status.COMPLETED)

    def test_recall_api_lifecycle(self):
        stock = self._stock()
        self._batch(stock, 10)
        self.client.force_authenticate(user=self.admin)

        created = self.client.post('/api/inventory/recalls/', {
            'title': 'API recall',
            'batch_number': f'LOT-{stock.pk}-10',
            'medication_name': stock.medication_name,
            'reason': 'quality',
            'severity': 'high',
        }, format='json')
        self.assertEqual(created.status_code, 201, created.data)
        case_id = created.data['id']
        self.assertTrue(created.data['reference'].startswith('RCL-'))

        traced = self.client.post(f'/api/inventory/recalls/{case_id}/trace/', {},
                                  format='json')
        self.assertEqual(traced.status_code, 200, traced.data)
        self.assertEqual(traced.data['trace']['batches'], 1)

        quarantined = self.client.post(
            f'/api/inventory/recalls/{case_id}/quarantine/', {}, format='json')
        self.assertEqual(quarantined.status_code, 200, quarantined.data)

        closed = self.client.post(f'/api/inventory/recalls/{case_id}/close/',
                                  {'note': 'done'}, format='json')
        self.assertEqual(closed.status_code, 200, closed.data)


class ColdChainTest(BaseTenantCase):
    schema_slug = 'prem_coldchain'
    domain = 'coldchain.test.localhost'
    def test_critical_excursion_auto_quarantines(self):
        zone = StorageZone.objects.create(
            name='Cold Room', min_temp_c=Decimal('2'), max_temp_c=Decimal('8'),
            requires_cold_chain=True)
        stock = self._stock()
        batch = self._batch(stock, 40)

        excursion = quality.log_excursion(
            recorded_temp_c=Decimal('18'), zone=zone, batch=batch,
            user=self.admin)

        self.assertEqual(excursion.severity, TemperatureExcursion.Severity.CRITICAL)
        self.assertTrue(excursion.auto_quarantined)
        batch.refresh_from_db()
        self.assertTrue(batch.is_blocked)

    def test_minor_excursion_does_not_quarantine(self):
        zone = StorageZone.objects.create(
            name='Cold Room', min_temp_c=Decimal('2'), max_temp_c=Decimal('8'))
        stock = self._stock()
        batch = self._batch(stock, 10)
        excursion = quality.log_excursion(
            recorded_temp_c=Decimal('8.5'), zone=zone, batch=batch)
        self.assertEqual(excursion.severity, TemperatureExcursion.Severity.MINOR)
        batch.refresh_from_db()
        self.assertFalse(batch.is_blocked)

    def test_certificate_covering_receipt_is_accepted(self):
        from suppliers.models import Supplier
        supplier = Supplier.objects.create(name='Cert Supplier')
        stock = self._stock()
        batch = self._batch(stock, 10)
        batch.supplier = supplier
        batch.save(update_fields=['supplier'])

        SupplierCertificate.objects.create(
            supplier=supplier, stock=stock, reference='COA-1',
            issued_on=timezone.localdate() - timedelta(days=10),
            expires_on=timezone.localdate() + timedelta(days=300))

        result = quality.batch_certified(batch)
        self.assertTrue(result['certified'], result)
        self.assertEqual(result['certificate_id'],
                         SupplierCertificate.objects.first().id)

    def test_expired_certificate_is_rejected(self):
        from suppliers.models import Supplier
        supplier = Supplier.objects.create(name='Cert Supplier')
        stock = self._stock()
        batch = self._batch(stock, 10)
        batch.supplier = supplier
        batch.save(update_fields=['supplier'])
        SupplierCertificate.objects.create(
            supplier=supplier, reference='COA-1',
            expires_on=timezone.localdate() - timedelta(days=1))
        self.assertFalse(quality.batch_certified(batch)['certified'])

    def test_quality_dashboard_endpoint(self):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get('/api/inventory/quality/')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertIn('excursions', response.data)
        self.assertIn('certificates', response.data)


# ══════════════════════════════════════════════════════════════════════
#  Tier 4 — warehouse execution
# ══════════════════════════════════════════════════════════════════════
class ExecutionTest(BaseTenantCase):
    schema_slug = 'prem_execution'
    domain = 'execution.test.localhost'
    def test_putaway_prefers_emptiest_compatible_bin(self):
        WarehouseBin.objects.create(branch=self.branch, name='A1',
                                    zone='Z', aisle='1', bin_code='A1',
                                    capacity_units=100)
        big = WarehouseBin.objects.create(branch=self.branch, name='B1',
                                          zone='Z', aisle='1', bin_code='B1',
                                          capacity_units=1000)
        stock = self._stock()
        suggestion = bin_service.suggest_putaway(stock, 10)
        self.assertIsNotNone(suggestion)
        self.assertEqual(suggestion['bin'].id, big.id)

    def test_placement_tracks_bin_utilisation(self):
        bin_obj = WarehouseBin.objects.create(
            branch=self.branch, name='A1', capacity_units=100)
        stock = self._stock()
        bin_service.place_stock(stock, bin_obj, 40)
        self.assertEqual(bin_obj.used_units, 40)
        self.assertEqual(bin_obj.free_units, 60)
        self.assertEqual(bin_obj.fill_pct, 40)

    def test_move_placement_merges(self):
        a = WarehouseBin.objects.create(branch=self.branch, name='A', capacity_units=100)
        b = WarehouseBin.objects.create(branch=self.branch, name='B', capacity_units=100)
        stock = self._stock()
        placement = bin_service.place_stock(stock, a, 20)
        moved = bin_service.move_placement(placement, b)
        self.assertEqual(moved.bin_id, b.id)
        self.assertEqual(moved.quantity, 20)
        self.assertEqual(a.placements.count(), 0)

    def test_pick_list_is_fefo(self):
        stock = self._stock()
        self._batch(stock, 100)
        soon = StockBatch.objects.create(
            stock=stock, batch_number='SOON', quantity_received=10,
            quantity_remaining=10, cost_price_per_unit='10',
            expiry_date=timezone.localdate() + timedelta(days=5))
        rows = bin_service.pick_list()
        self.assertGreaterEqual(len(rows), 1)
        self.assertEqual(rows[0]['batch_number'], soon.batch_number)
        self.assertTrue(rows[0]['unplaced'])

    def test_scan_resolves_batch_barcode_and_name(self):
        stock = self._stock()
        stock.barcode = 'BAR-001'
        stock.save(update_fields=['barcode'])
        batch = self._batch(stock, 5)

        by_barcode = scanning.resolve_code('BAR-001')
        self.assertTrue(by_barcode['found'])
        self.assertEqual(by_barcode['stock_id'], stock.id)

        by_batch = scanning.resolve_code(batch.batch_number)
        self.assertTrue(by_batch['found'])
        self.assertEqual(by_batch['batch']['id'], batch.id)

        payload = label_service.encode_payload(stock, batch)
        by_payload = scanning.resolve_code(payload)
        self.assertTrue(by_payload['found'])
        self.assertEqual(by_payload['stock_id'], stock.id)

        self.assertFalse(scanning.resolve_code('NOPE-123')['found'])

    def test_scan_verify_records_mismatch(self):
        a = self._stock('Item A')
        b = self._stock('Item B', cost='5.00')
        b.barcode = 'BBB'
        b.save(update_fields=['barcode'])

        result = scanning.verify_scan(
            code='BBB', context='pick', expected_stock=a, user=self.admin)
        self.assertFalse(result['is_match'])
        self.assertIn('does not match', result['warning'].lower())
        self.assertEqual(scanning.scan_history(only_mismatches=True)[0]['code'], 'BBB')

    def test_label_pdf_is_generated(self):
        stock = self._stock()
        self._batch(stock, 12, expiry_days=90)
        rows = label_service.stock_label_rows([stock])
        self.assertEqual(len(rows), 1)
        pdf = label_service.build_label_pdf(rows, business_name='Test WH')
        self.assertTrue(pdf.startswith(b'%PDF'))

    def test_label_payload_uses_medication_id_and_still_resolves(self):
        """The printed label carries ``medication_id``, not the pk — a scan of
        the printed code must still resolve."""
        stock = self._stock()
        batch = self._batch(stock, 4)
        payload = label_service.encode_payload(stock, batch)
        self.assertTrue(payload.startswith(stock.medication_id or str(stock.pk)))

        resolved = scanning.resolve_code(payload)
        self.assertTrue(resolved['found'], payload)
        self.assertEqual(resolved['stock_id'], stock.id)
        self.assertEqual(resolved['batch']['id'], batch.id)

    def test_barcode_is_scaled_to_fit_the_label(self):
        """reportlab sizes Code128 from a fixed X-dimension, so a full
        ``sku|lot|expiry`` payload used to overflow the label box."""
        from reportlab.lib.units import mm

        inner = label_service.LABEL_W - 3.6 * mm - 2.6 * mm
        payloads = [
            'MED-00001|PCM-2402|2027-03-31',
            'MED-00012|ADR-2301|2026-08-21',
            'A-VERY-LONG-BATCH-NUMBER-1234567890|2029-12-31',
            'PC500TAB',
        ]
        for payload in payloads:
            bar, width = label_service._fit_barcode(payload, inner)
            self.assertIsNotNone(bar, payload)
            self.assertLessEqual(width, inner + 1e-6,
                                 f'{payload!r} does not fit the label')
            self.assertGreaterEqual(bar.barWidth, label_service.X_MIN - 1e-9)

    def test_label_lines_omit_branch_and_quantity(self):
        """Warehouse and qty change between print and scan time, so they are
        deliberately not printed — only the lot and the expiry are."""
        stock = self._stock()
        self._batch(stock, 37)
        rows = label_service.stock_label_rows([stock])
        self.assertEqual(len(rows), 1)

        lines = rows[0]['lines']
        self.assertEqual(len(lines), 2, lines)
        self.assertTrue(lines[0].startswith('Lot'), lines)
        self.assertTrue(lines[1].startswith('Exp'), lines)
        for line in lines:
            self.assertNotIn('qty', line.lower())
            self.assertNotIn(self.branch.name.lower(), line.lower())

    def test_putaway_reports_over_capacity(self):
        small = WarehouseBin.objects.create(
            branch=self.branch, name='TINY', capacity_units=10)
        stock = self._stock()
        self.client.force_authenticate(user=self.admin)
        response = self.client.post('/api/inventory/bins/putaway/', {
            'stock': stock.id, 'quantity': 50, 'apply': True}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(response.data['suggestion']['over_capacity'])
        self.assertEqual(response.data['suggestion']['bin_id'], small.id)

    def test_label_endpoint_returns_pdf(self):
        stock = self._stock()
        self._batch(stock, 3, expiry_days=30)
        self.client.force_authenticate(user=self.admin)
        response = self.client.get(f'/api/inventory/labels/?stocks={stock.pk}')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response['Content-Type'], 'application/pdf')

    # ── Letterhead (org profile → first page header) ────────────────────
    def test_org_detail_lines_dedupe_repeated_tokens(self):
        """A tenant that types the whole location into ``address`` *and* sets
        city/country must not print "Kenya, Nairobi, Kenya"."""
        lines = label_service._org_detail_lines({
            'address': '3Q62+5WH, Mtwapa, Kenya',
            'city': 'Nairobi',
            'country': 'Kenya',
            'phone': '+254700000004',
            'email': 'admin@demoims.local',
        })
        self.assertEqual(lines[0].count('Kenya'), 1, lines[0])
        self.assertIn('Mtwapa', lines[0])
        self.assertIn('Nairobi', lines[0])
        self.assertIn('Tel +254700000004', lines[1])
        self.assertIn('admin@demoims.local', lines[1])

    def test_org_detail_lines_skips_missing_fields(self):
        lines = label_service._org_detail_lines(
            {'address': '', 'city': '', 'country': '', 'phone': '', 'email': ''})
        self.assertEqual(lines, [])

    def test_letterhead_carries_org_details_on_first_page_only(self):
        """Page 1 shows the logo + profile details; pages 2+ use a compact
        running header so the label grid keeps its density."""
        import pymupdf

        stock = self._stock()
        for i in range(14):                       # forces a second page
            self._batch(stock, 5, expiry_days=90 + i)

        org = {'name': 'Acme Distribution Ltd',
               'address': '12 Depot Road, Mtwapa, Kenya',
               'city': 'Mombasa', 'country': 'Kenya',
               'phone': '+254711000111', 'email': 'ops@acme.test',
               'website': 'https://acme.test/'}
        rows = label_service.stock_label_rows([stock])
        self.assertGreater(len(rows), 12)

        pdf = label_service.build_label_pdf(
            rows, business_name=org['name'], org=org,
            meta_extra=['Warehouse: Main WH'])
        doc = pymupdf.open(stream=pdf, filetype='pdf')
        self.assertGreaterEqual(doc.page_count, 2)

        page1 = doc[0].get_text()
        page2 = doc[1].get_text()

        self.assertIn('Acme Distribution Ltd', page1)
        self.assertIn('Mtwapa', page1)
        self.assertIn('Tel +254711000111', page1)
        self.assertIn('ops@acme.test', page1)
        self.assertIn('acme.test', page1)          # scheme + slash stripped
        self.assertIn('Warehouse: Main WH', page1)
        self.assertEqual(page1.count('Kenya'), 1, 'country printed twice')

        # Running header only — no org contact block repeated.
        self.assertIn('Acme Distribution Ltd', page2)
        self.assertNotIn('ops@acme.test', page2)
        self.assertNotIn('Tel +254711000111', page2)

    def test_letterhead_embeds_the_tenant_logo_only_on_page_one(self):
        """The logo comes from /ims/organization/profile (``tenant.logo``)."""
        import pymupdf
        from PIL import Image

        logo = Path(tempfile.gettempdir()) / 'test_tenant_logo.png'
        Image.new('RGB', (180, 90), (14, 116, 144)).save(logo)

        stock = self._stock()
        for i in range(14):
            self._batch(stock, 5, expiry_days=90 + i)
        rows = label_service.stock_label_rows([stock])

        pdf = label_service.build_label_pdf(
            rows, business_name='Logo Co', org={'name': 'Logo Co'},
            logo_path=str(logo))

        doc = pymupdf.open(stream=pdf, filetype='pdf')
        self.assertEqual(len(doc[0].get_images(full=True)), 1,
                         'logo missing from the first page')
        self.assertEqual(len(doc[1].get_images(full=True)), 0,
                         'logo should not repeat on page 2')

    def test_label_endpoint_uses_the_tenant_profile(self):
        """The header must show the same name/contact the org profile edits."""
        tenant = type(self).tenant
        tenant.name = 'Profile Name Ltd'
        tenant.address = '12 Depot Road, Mtwapa, Kenya'
        tenant.city = 'Mombasa'
        tenant.country = 'Kenya'
        tenant.phone = '+254733111222'
        tenant.email = 'hello@profile.test'
        tenant.save()

        stock = self._stock()
        self._batch(stock, 3, expiry_days=30)
        self.client.force_authenticate(user=self.admin)
        response = self.client.get(f'/api/inventory/labels/?stocks={stock.pk}')
        self.assertEqual(response.status_code, 200)

        import pymupdf
        doc = pymupdf.open(stream=response.content, filetype='pdf')
        text = doc[0].get_text()

        self.assertIn('Profile Name Ltd', text)
        self.assertIn('Mtwapa', text)
        self.assertIn('Tel +254733111222', text)
        self.assertIn('hello@profile.test', text)
        self.assertEqual(text.count('Kenya'), 1, 'country printed twice')

    # ── Brand palette (/ims/organization/branding) ───────────────────────
    def test_resolve_palette_reads_brand_columns(self):
        from config.pdf_branding import resolve_palette

        tenant = type(self).tenant
        tenant.brand_primary = '#0D9488'
        tenant.brand_secondary = '#0F766E'
        tenant.brand_accent = '#5EEAD4'
        tenant.save()

        palette = resolve_palette(None, tenant=tenant)
        # ``hexval()`` returns '0xrrggbb' in this reportlab version.
        for key, expected in (('primary', '0x0d9488'),
                              ('secondary', '0x0f766e'),
                              ('accent', '0x5eead4')):
            self.assertEqual(str(palette[key].hexval()).lower(), expected)

    def test_resolve_palette_falls_back_per_colour(self):
        """An unset or malformed colour must not lose the whole palette."""
        from config.pdf_branding import BRAND_DEFAULTS, resolve_palette

        tenant = type(self).tenant
        tenant.brand_primary = '#zzzzzz'      # malformed but column-length
        tenant.brand_secondary = ''
        tenant.brand_accent = '#abc'          # shorthand must expand
        tenant.save()

        palette = resolve_palette(None, tenant=tenant)
        self.assertEqual(str(palette['primary'].hexval()).lower(),
                         BRAND_DEFAULTS['primary'].replace('#', '0x'))
        self.assertEqual(str(palette['secondary'].hexval()).lower(),
                         BRAND_DEFAULTS['secondary'].replace('#', '0x'))
        self.assertEqual(str(palette['accent'].hexval()).lower(), '0xaabbcc')

    def test_letterhead_uses_the_brand_band_colour(self):
        """The band must paint in ``brand_secondary``, not a hard-coded navy."""
        import pymupdf

        from config.pdf_branding import resolve_palette

        tenant = type(self).tenant
        tenant.brand_primary = '#DC2626'
        tenant.brand_secondary = '#991B1B'   # crimson band
        tenant.brand_accent = '#FCA5A5'
        tenant.save()

        stock = self._stock()
        self._batch(stock, 4)
        rows = label_service.stock_label_rows([stock])
        pdf = label_service.build_label_pdf(
            rows, business_name='Brand Co', org={'name': 'Brand Co'},
            palette=resolve_palette(None, tenant=tenant))

        doc = pymupdf.open(stream=pdf, filetype='pdf')
        page = doc[0]

        fills = set()
        for drawing in page.get_drawings():
            fill = drawing.get('fill')
            if fill:
                fills.add(tuple(round(c, 3) for c in fill))
            for item in drawing['items']:
                if item[0] == 're' and item[1].height < 30:
                    continue

        expected = (0x99 / 255, 0x1B / 255, 0x1B / 255)
        self.assertTrue(
            any(abs(f[0] - expected[0]) < 0.02
                and abs(f[1] - expected[1]) < 0.02
                and abs(f[2] - expected[2]) < 0.02 for f in fills),
            f'brand_secondary #991B1B not painted in the letterhead: {fills}')

    def test_letterhead_text_stays_legible_on_a_pale_band(self):
        """A pale palette must flip the band text to dark, not invisible white."""
        from reportlab.lib import colors as rl_colors

        pale = rl_colors.HexColor('#FDE68A')
        self.assertNotEqual(label_service._readable_on(pale), rl_colors.white)

        dark = rl_colors.HexColor('#0F172A')
        self.assertEqual(label_service._readable_on(dark), rl_colors.white)

    def test_tint_returns_a_reportlab_colour(self):
        from reportlab.lib import colors as rl_colors

        from config.pdf_branding import tint

        mixed = tint(rl_colors.HexColor('#0D9488'), 0.5)
        self.assertIsInstance(mixed, rl_colors.Color)
        # Halfway to white is lighter than the source on every channel.
        self.assertGreater(mixed.red, rl_colors.HexColor('#0D9488').red)
        self.assertAlmostEqual(mixed.blue, (0x88 / 255 + 1.0) / 2, places=2)

    # ── Branch / category filters ────────────────────────────────────────
    def test_label_endpoint_filters_by_category(self):
        from inventory.models import Category

        cat_a = Category.objects.create(name='Analgesics')
        cat_b = Category.objects.create(name='Antibiotics')
        keep = self._stock('Filter Keep')
        keep.category = cat_a
        keep.save(update_fields=['category'])
        drop = self._stock('Filter Drop', cost='4.00')
        drop.category = cat_b
        drop.save(update_fields=['category'])

        self.client.force_authenticate(user=self.admin)
        response = self.client.get(
            f'/api/inventory/labels/?category={cat_a.id}')
        self.assertEqual(response.status_code, 200)

        import pymupdf
        text = pymupdf.open(stream=response.content, filetype='pdf')[0].get_text()
        self.assertIn('Filter Keep', text)
        self.assertNotIn('Filter Drop', text)
        self.assertIn('Category: Analgesics', text)

    def test_label_endpoint_filters_by_branch(self):
        from pharmacy_profile.models import Branch

        other = Branch.objects.create(name='Second WH')
        here = self._stock('Here Item')
        there = self._stock('There Item', cost='3.00')
        there.branch = other
        there.save(update_fields=['branch'])

        self.client.force_authenticate(user=self.admin)
        response = self.client.get(
            f'/api/inventory/labels/?branch={other.id}')
        self.assertEqual(response.status_code, 200)

        import pymupdf
        text = pymupdf.open(stream=response.content, filetype='pdf')[0].get_text()
        self.assertIn('There Item', text)
        self.assertNotIn('Here Item', text)
        self.assertIn('Warehouse: Second WH', text)

    def test_label_endpoint_explicit_selection_beats_filters(self):
        """A ticked row must print even when it sits outside the filters."""
        from inventory.models import Category

        cat = Category.objects.create(name='Filters Bypassed')
        picked = self._stock('Picked Item')
        picked.category = cat
        picked.save(update_fields=['category'])

        self.client.force_authenticate(user=self.admin)
        # Filter on a category the item is NOT in, but pass its id explicitly.
        response = self.client.get(
            f'/api/inventory/labels/?stocks={picked.pk}&category=999999')
        self.assertEqual(response.status_code, 200)

        import pymupdf
        text = pymupdf.open(stream=response.content, filetype='pdf')[0].get_text()
        self.assertIn('Picked Item', text)

    def test_label_endpoint_empty_filter_result_returns_400(self):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get('/api/inventory/labels/?category=999999')
        self.assertEqual(response.status_code, 400)
        self.assertIn('No stock items', str(response.data['detail']))


# ══════════════════════════════════════════════════════════════════════
#  Tier 5 — costing & valuation
# ══════════════════════════════════════════════════════════════════════
class ValuationTest(BaseTenantCase):
    schema_slug = 'prem_valuation'
    domain = 'valuation.test.localhost'
    def test_weighted_average_cost(self):
        stock = self._stock(cost='10.00')
        StockBatch.objects.create(stock=stock, batch_number='A',
                                  quantity_received=100, quantity_remaining=100,
                                  cost_price_per_unit='10.00')
        StockBatch.objects.create(stock=stock, batch_number='B',
                                  quantity_received=100, quantity_remaining=100,
                                  cost_price_per_unit='20.00')
        cost = valuation.stock_unit_cost(stock, 'weighted_average')
        self.assertEqual(cost, Decimal('15.00'))

    def test_fifo_cost_uses_earliest_expiry(self):
        stock = self._stock()
        StockBatch.objects.create(
            stock=stock, batch_number='EARLY', quantity_received=10,
            quantity_remaining=10, cost_price_per_unit='7.00',
            expiry_date=timezone.localdate() + timedelta(days=10))
        StockBatch.objects.create(
            stock=stock, batch_number='LATE', quantity_received=10,
            quantity_remaining=10, cost_price_per_unit='9.00',
            expiry_date=timezone.localdate() + timedelta(days=300))
        self.assertEqual(valuation.stock_unit_cost(stock, 'fifo'), Decimal('7.00'))

    def test_snapshot_is_idempotent_per_period(self):
        stock = self._stock()
        self._batch(stock, 50)
        first = valuation.create_snapshot()
        second = valuation.create_snapshot()
        self.assertEqual(first.pk, second.pk)
        self.assertEqual(InventorySnapshot.objects.count(), 1)
        self.assertEqual(second.total_units, 50)
        self.assertEqual(second.lines.count(), 1)

    def test_landed_cost_allocation_by_value(self):
        from purchase_orders.models import PurchaseOrder
        from suppliers.models import Supplier
        supplier = Supplier.objects.create(name='LC Supplier')
        po = PurchaseOrder.objects.create(
            po_number='PO-LC-1', supplier=supplier,
            items=[
                {'name': 'Cheap', 'qty': 100, 'unit_cost': 10},
                {'name': 'Pricey', 'qty': 100, 'unit_cost': 30},
            ], total_cost=4000, branch=self.branch)

        result = valuation.apply_landed_cost(po, freight=400)
        self.assertTrue(result['applied'])
        po.refresh_from_db()
        cheap = next(i for i in po.items if i['name'] == 'Cheap')
        pricey = next(i for i in po.items if i['name'] == 'Pricey')
        self.assertAlmostEqual(cheap['landed_unit_cost'], 11.0, places=2)
        self.assertAlmostEqual(pricey['landed_unit_cost'], 33.0, places=2)

    def test_landed_cost_no_extras_is_a_noop(self):
        from purchase_orders.models import PurchaseOrder
        from suppliers.models import Supplier
        po = PurchaseOrder.objects.create(
            po_number='PO-LC-2', supplier=Supplier.objects.create(name='X'),
            items=[{'name': 'A', 'qty': 1, 'unit_cost': 5}], branch=self.branch)
        self.assertFalse(valuation.apply_landed_cost(po)['applied'])

    def test_writeoff_decision_flow(self):
        stock = self._stock()
        self._batch(stock, 10)
        adjustment = StockAdjustment.objects.create(
            stock=stock, quantity_change=-2,
            reason=StockAdjustment.Reason.DAMAGE, adjusted_by=self.admin)
        from inventory.models import WriteOffRequest
        request_obj = WriteOffRequest.objects.create(
            adjustment=adjustment, stock=stock, quantity=2, value=Decimal('20.00'),
            requested_by=self.admin)

        self.client.force_authenticate(user=self.admin)
        response = self.client.post(
            f'/api/inventory/writeoffs/{request_obj.pk}/decide/',
            {'approve': True, 'note': 'ok'}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        request_obj.refresh_from_db()
        self.assertEqual(request_obj.status, WriteOffRequest.Status.APPROVED)

    def test_rejected_writeoff_restores_the_stock(self):
        """A rejection used to leave the loss in the ledger and off the shelf."""
        from inventory.models import WriteOffRequest
        from inventory.services import quality as quality_service

        stock = self._stock()
        self._batch(stock, 10)
        adjustment = StockAdjustment.objects.create(
            stock=stock, quantity_change=-4,
            reason=StockAdjustment.Reason.DAMAGE, adjusted_by=self.admin)
        before = stock.total_quantity
        request_obj = WriteOffRequest.objects.create(
            adjustment=adjustment, stock=stock, quantity=4,
            value=Decimal('40.00'), requested_by=self.admin)

        self.client.force_authenticate(user=self.admin)
        response = self.client.post(
            f'/api/inventory/writeoffs/{request_obj.pk}/decide/',
            {'approve': False, 'note': 'not damaged'}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['outcome'], 'reversed')
        stock.refresh_from_db()
        self.assertEqual(stock.total_quantity, before + 4)

    def test_threshold_opens_a_writeoff_request_automatically(self):
        from inventory.models import InventorySettings, WriteOffRequest
        from inventory.services import quality as quality_service

        settings_obj = InventorySettings.get()
        settings_obj.writeoff_approval_threshold = Decimal('1.00')
        settings_obj.save(update_fields=['writeoff_approval_threshold'])

        stock = self._stock(cost='50.00')
        self._batch(stock, 20)
        self.client.force_authenticate(user=self.admin)
        response = self.client.post('/api/inventory/adjustments/', {
            'stock': stock.id, 'quantity_change': -3, 'reason': 'damage',
            'notes': 'Crushed in transit',
        }, format='json')
        self.assertEqual(response.status_code, 201, response.data)

        request_obj = WriteOffRequest.objects.get(stock=stock)
        self.assertEqual(request_obj.quantity, 3)
        self.assertEqual(float(request_obj.value), 150.0)
        self.assertEqual(request_obj.status, WriteOffRequest.Status.PENDING)
        self.assertIn(request_obj.pk,
                      [r['id'] for r in quality_service.pending_writeoffs()])

    def test_below_threshold_does_not_ask_for_approval(self):
        from inventory.models import InventorySettings, WriteOffRequest

        settings_obj = InventorySettings.get()
        settings_obj.writeoff_approval_threshold = Decimal('10000.00')
        settings_obj.save(update_fields=['writeoff_approval_threshold'])

        stock = self._stock(cost='10.00')
        self._batch(stock, 20)
        self.client.force_authenticate(user=self.admin)
        self.client.post('/api/inventory/adjustments/', {
            'stock': stock.id, 'quantity_change': -1, 'reason': 'damage',
        }, format='json')
        self.assertFalse(WriteOffRequest.objects.filter(stock=stock).exists())


# ══════════════════════════════════════════════════════════════════════
#  Tier 6 — supplier scorecard
# ══════════════════════════════════════════════════════════════════════
class ScorecardTest(BaseTenantCase):
    schema_slug = 'prem_scorecard'
    domain = 'scorecard.test.localhost'
    def _po(self, supplier, ordered, expected, items):
        from purchase_orders.models import PurchaseOrder
        po = PurchaseOrder.objects.create(
            po_number=f'PO-{supplier.pk}-{ordered}',
            supplier=supplier, items=items, total_cost=100, branch=self.branch)
        PurchaseOrder.objects.filter(pk=po.pk).update(
            order_date=ordered, expected_delivery=expected)
        po.refresh_from_db()
        return po

    def test_full_marks_for_on_time_complete_supplier(self):
        from purchase_orders.models import GoodsReceivedNote
        from suppliers.models import Supplier

        supplier = Supplier.objects.create(name='Perfect Co')
        today = timezone.localdate()
        # GRN.received_date is auto_now_add, so the delivery lands today — the
        # promise must be today (or later) for the order to count as on time.
        po = self._po(supplier, today - timedelta(days=10), today,
                      [{'medication_stock_id': 1, 'name': 'A', 'qty': 100,
                        'unit_cost': 1, 'total': 100}])
        GoodsReceivedNote.objects.create(
            purchase_order=po, grn_number='GRN-1',
            items_received=[{'medication_stock_id': 1, 'qty': 100}])

        metrics = scorecard.compute_scorecard(
            supplier, today - timedelta(days=30), today)
        self.assertEqual(metrics['otif_pct'], 100.0)
        self.assertEqual(metrics['fill_rate_pct'], 100.0)
        self.assertGreaterEqual(metrics['score'], 90)
        self.assertEqual(metrics['grade'], 'A')

    def test_short_and_late_delivery_scores_badly(self):
        from purchase_orders.models import GoodsReceivedNote
        from suppliers.models import Supplier

        supplier = Supplier.objects.create(name='Late Co')
        today = timezone.localdate()
        po = self._po(supplier, today - timedelta(days=40), today - timedelta(days=30),
                      [{'medication_stock_id': 2, 'name': 'B', 'qty': 100,
                        'unit_cost': 1, 'total': 100}])
        GoodsReceivedNote.objects.create(
            purchase_order=po, grn_number='GRN-2',
            items_received=[{'medication_stock_id': 2, 'qty': 40}])

        metrics = scorecard.compute_scorecard(
            supplier, today - timedelta(days=60), today)
        self.assertEqual(metrics['fill_rate_pct'], 40.0)
        self.assertEqual(metrics['on_time_pct'], 0.0)
        self.assertLess(metrics['score'], 65)

    def test_no_orders_returns_zeroed_grade(self):
        from suppliers.models import Supplier
        supplier = Supplier.objects.create(name='New Co')
        metrics = scorecard.compute_scorecard(
            supplier, timezone.localdate() - timedelta(days=30), timezone.localdate())
        self.assertEqual(metrics['orders_count'], 0)
        self.assertFalse(metrics['is_rated'])
        self.assertEqual(metrics['grade'], scorecard.UNRATED_GRADE)

    def test_order_without_grn_is_unrated_not_failed(self):
        """A PO that has never been delivered says nothing about the supplier."""
        from suppliers.models import Supplier

        supplier = Supplier.objects.create(name='Silent Co')
        today = timezone.localdate()
        self._po(supplier, today - timedelta(days=5), today,
                 [{'medication_stock_id': 3, 'name': 'C', 'qty': 10,
                   'unit_cost': 1, 'total': 10}])

        metrics = scorecard.compute_scorecard(supplier, today - timedelta(days=30), today)
        self.assertEqual(metrics['orders_count'], 1)
        self.assertFalse(metrics['is_rated'], 'no GRN yet → not rated')
        self.assertEqual(metrics['grade'], scorecard.UNRATED_GRADE)

        scorecard.refresh_scorecards(days=30)
        ranked = {r['supplier_id']: r for r in scorecard.supplier_ranking()}
        self.assertFalse(ranked[supplier.id]['is_rated'])
        self.assertEqual(ranked[supplier.id]['risk'], 'unknown')

    def test_refresh_and_rank(self):
        from suppliers.models import Supplier
        Supplier.objects.create(name='Ranked Co')
        scorecard.refresh_scorecards(days=30)
        self.assertGreaterEqual(len(scorecard.supplier_ranking()), 1)

    def test_endpoint(self):
        from suppliers.models import Supplier
        Supplier.objects.create(name='API Co')
        self.client.force_authenticate(user=self.admin)
        response = self.client.post('/api/inventory/supplier-scorecards/',
                                    {'days': 30}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertIn('results', response.data)


# ══════════════════════════════════════════════════════════════════════
#  Tier 7 — analytics & anomalies
# ══════════════════════════════════════════════════════════════════════
class InsightsTest(BaseTenantCase):
    schema_slug = 'prem_insights'
    domain = 'insights.test.localhost'
    def test_kpi_dashboard_shape(self):
        stock = self._stock()
        self._batch(stock, 100)
        data = kpis.kpi_dashboard(days=30)
        for key in ('turns', 'dio_days', 'gmroi', 'fill_rate_pct',
                    'inventory_value_cost', 'excess_obsolete'):
            self.assertIn(key, data)
        self.assertGreater(data['inventory_value_cost'], 0)

    def test_excess_by_age_bands(self):
        stock = self._stock()
        self._batch(stock, 10)
        data = kpis.excess_by_age()
        self.assertTrue(data['bands'])
        self.assertGreater(data['total_value'], 0)

    def test_what_if_costs_more_at_higher_service(self):
        stock = self._stock()
        self._batch(stock, 500)
        planning.refresh_policies()
        low = kpis.whats_if(90)
        high = kpis.whats_if(99)
        self.assertGreaterEqual(high['extra_capital'], low['extra_capital'])

    def test_repeated_variance_detected(self):
        stock = self._stock()
        self._batch(stock, 100)
        for _ in range(4):
            StockAdjustment.objects.create(
                stock=stock, quantity_change=-1,
                reason=StockAdjustment.Reason.COUNT_CORRECTION,
                adjusted_by=self.admin)

        found = anomaly.detect_repeated_variances()
        self.assertGreaterEqual(found, 1)
        self.assertTrue(StockAnomaly.objects.filter(kind='variance').exists())

    def test_mass_expiry_detected(self):
        stock = self._stock()
        for i in range(6):
            StockBatch.objects.create(
                stock=stock, batch_number=f'EXP-{i}', quantity_received=5,
                quantity_remaining=5, cost_price_per_unit='1',
                expiry_date=timezone.localdate() + timedelta(days=10))
        found = anomaly.detect_mass_expiry(days=30, min_batches=5)
        self.assertGreaterEqual(found, 1)

    def test_anomaly_signature_prevents_duplicates(self):
        stock = self._stock()
        for _ in range(4):
            StockAdjustment.objects.create(
                stock=stock, quantity_change=-1,
                reason=StockAdjustment.Reason.COUNT_CORRECTION)
        anomaly.detect_repeated_variances()
        count_first = StockAnomaly.objects.count()
        anomaly.detect_repeated_variances()
        self.assertEqual(StockAnomaly.objects.count(), count_first)

    def test_insights_endpoint(self):
        stock = self._stock()
        self._batch(stock, 25)
        self.client.force_authenticate(user=self.admin)
        response = self.client.get('/api/inventory/insights/')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertIn('kpis', response.data)
        self.assertIn('valuation', response.data)


# ══════════════════════════════════════════════════════════════════════
#  RBAC on the new surfaces
# ══════════════════════════════════════════════════════════════════════
class NewSurfaceRBACTest(BaseTenantCase):
    schema_slug = 'prem_rbac'
    domain = 'premium-rbac.test.localhost'
    def test_cashier_cannot_read_insights(self):
        cashier = User.objects.create_user(
            email='till@test.local', password='x', first_name='Till',
            last_name='Op', role='cashier')
        self.client.force_authenticate(user=cashier)
        # cashier has stock.view, so insights are readable; but the settings
        # endpoint must stay admin-only.
        response = self.client.patch('/api/inventory/settings/',
                                     {'service_level': 99}, format='json')
        self.assertEqual(response.status_code, 403, response.data)

    def test_policy_update_is_audited(self):
        from audit.models import AuditEvent
        stock = self._stock()
        self._batch(stock, 10)
        planning.refresh_policies()
        policy = StockPolicy.objects.get(stock=stock)

        self.client.force_authenticate(user=self.admin)
        response = self.client.patch(
            f'/api/inventory/policies/{policy.pk}/',
            {'min_qty': 999}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(AuditEvent.objects.filter(action='policy_update').exists())

    def test_compliance_export_returns_csv(self):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get('/api/inventory/compliance/export/?days=7')
        self.assertEqual(response.status_code, 200)
        self.assertIn('text/csv', response['Content-Type'])


# ══════════════════════════════════════════════════════════════════════
#  Replenishment workbench (Tier 1 upgrade) — reviewed POs, supplier
#  linking and RFQs built from the plan
# ══════════════════════════════════════════════════════════════════════
class ReplenishmentWorkbenchTest(BaseTenantCase):
    schema_slug = 'prem_workbench'
    domain = 'premium-workbench.test.localhost'

    def setUp(self):
        super().setUp()
        from suppliers.models import Supplier
        self.supplier_a = Supplier.objects.create(name='Alpha Medical', is_active=True)
        self.supplier_b = Supplier.objects.create(name='Beta Pharma', is_active=True)
        self.client.force_authenticate(user=self.admin)

    # ── service: reviewed PO drafting ────────────────────────────────
    def test_create_purchase_orders_groups_per_supplier(self):
        s1 = self._stock('Amoxicillin 500mg', cost='8.00')
        s2 = self._stock('Ibuprofen 400mg', cost='4.00')
        s3 = self._stock('Paracetamol 500mg', cost='2.00')

        result = replenishment.create_purchase_orders([
            {'supplier_id': self.supplier_a.id, 'items': [
                {'stock_id': s1.id, 'name': s1.medication_name, 'qty': 100,
                 'unit_cost': 7.5},
                {'stock_id': s2.id, 'name': s2.medication_name, 'qty': 200,
                 'unit_cost': 4.0},
            ]},
            {'supplier_id': self.supplier_b.id, 'items': [
                {'stock_id': s3.id, 'name': s3.medication_name, 'qty': 50,
                 'unit_cost': 2.0},
            ]},
        ], user=self.admin, branch_id=self.branch.id)

        self.assertEqual(len(result['purchase_orders']), 2)
        self.assertEqual(result['lines'], 3)
        # 100*7.5 + 200*4.0 = 1550 ; 50*2.0 = 100
        self.assertAlmostEqual(result['total_cost'], 1650.0, places=2)
        self.assertEqual(result['skipped'], [])

        from purchase_orders.models import PurchaseOrder
        pos = PurchaseOrder.objects.all()
        self.assertEqual(pos.count(), 2)
        self.assertTrue(all(po.status == PurchaseOrder.Status.DRAFT for po in pos))
        self.assertTrue(all(po.po_number.startswith('AUTO-') for po in pos))
        self.assertTrue(all(po.notes for po in pos))

    def test_create_purchase_orders_marks_suggestions_ordered(self):
        from purchase_orders.models import ReorderSuggestion as POSuggestion
        stock = self._stock()
        self._batch(stock, 1)
        replenishment.build_suggestions(branch_id=self.branch.id, write=True)

        target = POSuggestion.objects.filter(status='pending').first()
        if target is None:
            # Nothing urgent enough on a fresh tenant — create one directly.
            target = POSuggestion.objects.create(
                stock=stock, current_quantity=1, reorder_level=20,
                suggested_quantity=100, recommended_supplier=self.supplier_a,
                last_unit_cost='10.00', estimated_cost='1000.00',
                status='pending', branch=self.branch)
        self.assertIsNotNone(target)

        replenishment.create_purchase_orders([
            {'supplier_id': self.supplier_a.id, 'items': [
                {'stock_id': stock.id, 'name': stock.medication_name,
                 'qty': 100, 'unit_cost': 10},
            ]},
        ], user=self.admin, branch_id=self.branch.id)

        target.refresh_from_db()
        self.assertEqual(target.status, 'ordered')

    def test_create_purchase_orders_skips_invalid_lines(self):
        stock = self._stock()
        result = replenishment.create_purchase_orders([
            {'supplier_id': self.supplier_a.id, 'items': [
                {'stock_id': stock.id, 'name': stock.medication_name, 'qty': 0,
                 'unit_cost': 5},
                {'stock_id': 987654, 'name': 'Ghost item', 'qty': 5,
                 'unit_cost': 5},
                {'stock_id': stock.id, 'name': stock.medication_name, 'qty': 10,
                 'unit_cost': -1},
                {'stock_id': stock.id, 'name': stock.medication_name, 'qty': 10,
                 'unit_cost': 5},
            ]},
        ], user=self.admin, branch_id=self.branch.id)

        reasons = ' | '.join(s['reason'] for s in result['skipped'])
        self.assertIn('greater than zero', reasons)
        self.assertIn('no longer exists', reasons)
        self.assertIn('cannot be negative', reasons)
        self.assertEqual(result['lines'], 1)
        self.assertAlmostEqual(result['total_cost'], 50.0, places=2)

    def test_create_purchase_orders_rejects_empty_groups(self):
        with self.assertRaises(replenishment.DraftError):
            replenishment.create_purchase_orders([], user=self.admin)

    def test_create_purchase_orders_rejects_other_warehouse_stock(self):
        other = Branch.objects.create(name='North WH', is_main=False)
        foreign = MedicationStock.objects.create(
            medication_name='Remote item', branch=other,
            cost_price='5.00', selling_price='9.00', reorder_level=5)

        result = replenishment.create_purchase_orders([
            {'supplier_id': self.supplier_a.id, 'items': [
                {'stock_id': foreign.id, 'name': 'Remote item', 'qty': 10,
                 'unit_cost': 5},
            ]},
        ], user=self.admin, branch_id=self.branch.id)

        self.assertEqual(result['purchase_orders'], [])
        self.assertTrue(any('another warehouse' in s['reason']
                            for s in result['skipped']))

    # ── service: supplier linking ────────────────────────────────────
    def test_link_supplier_item_creates_then_updates(self):
        from suppliers.models import SupplierItem
        stock = self._stock(cost='12.00')

        first = replenishment.link_supplier_item(
            supplier_id=self.supplier_a.id, stock_id=stock.id, unit_cost=11.5)
        self.assertTrue(first['created'])
        self.assertAlmostEqual(first['unit_cost'], 11.5, places=2)

        second = replenishment.link_supplier_item(
            supplier_id=self.supplier_a.id, stock_id=stock.id, unit_cost=9.75)
        self.assertFalse(second['created'])
        self.assertEqual(first['id'], second['id'])
        self.assertAlmostEqual(second['unit_cost'], 9.75, places=2)
        self.assertEqual(SupplierItem.objects.filter(stock=stock).count(), 1)

    def test_link_supplier_item_defaults_to_stock_cost(self):
        stock = self._stock(cost='12.00')
        result = replenishment.link_supplier_item(
            supplier_id=self.supplier_a.id, stock_id=stock.id)
        self.assertAlmostEqual(result['unit_cost'], 12.0, places=2)

    def test_link_supplier_item_validates_ids(self):
        stock = self._stock()
        with self.assertRaises(replenishment.DraftError):
            replenishment.link_supplier_item(supplier_id=999999, stock_id=stock.id)
        with self.assertRaises(replenishment.DraftError):
            replenishment.link_supplier_item(
                supplier_id=self.supplier_a.id, stock_id=999999)

    # ── service: RFQ creation ────────────────────────────────────────
    def test_create_rfq_precreates_a_quote_per_supplier(self):
        from purchase_orders.models import RFQQuote, RequestForQuotation
        stock = self._stock()

        result = replenishment.create_rfq(
            rows=[{'stock_id': stock.id, 'name': stock.medication_name,
                   'qty': 30, 'unit': 'tab', 'unit_cost': 9}],
            supplier_ids=[self.supplier_a.id, self.supplier_b.id],
            user=self.admin,
            branch_id=self.branch.id,
            title='Q3 top-up',
            notes='Deliver to the back dock.',
        )

        self.assertTrue(result['rfq_number'].startswith('RFQ-'))
        self.assertEqual(result['lines'], 1)
        self.assertEqual(len(result['invited']), 2)
        # Every invite carries the placeholder quote id so the client can PATCH
        # a bid instead of POSTing a duplicate (rfq, supplier) row.
        self.assertTrue(all(i.get('quote_id') for i in result['invited']))

        rfq = RequestForQuotation.objects.get(pk=result['id'])
        self.assertEqual(rfq.title, 'Q3 top-up')
        self.assertEqual(rfq.branch_id, self.branch.id)
        self.assertEqual(rfq.items[0]['qty'], 30)
        self.assertEqual(rfq.quotes.count(), 2)
        self.assertTrue(all(q.status == RFQQuote.Status.PENDING
                            for q in rfq.quotes.all()))

    def test_create_rfq_drops_zero_quantity_rows(self):
        stock = self._stock()
        with self.assertRaises(replenishment.DraftError):
            replenishment.create_rfq(
                rows=[{'stock_id': stock.id, 'name': 'x', 'qty': 0}],
                supplier_ids=[self.supplier_a.id], user=self.admin)

    def test_create_rfq_requires_a_supplier(self):
        stock = self._stock()
        with self.assertRaises(replenishment.DraftError):
            replenishment.create_rfq(
                rows=[{'stock_id': stock.id, 'name': 'x', 'qty': 5}],
                supplier_ids=[], user=self.admin)

    # ── API surface ──────────────────────────────────────────────────
    def test_reviewed_pos_endpoint(self):
        stock = self._stock()
        response = self.client.post(
            '/api/inventory/replenishment/reviewed-pos/',
            {'branch': self.branch.id,
             'notes': 'From the workbench',
             'groups': [{'supplier_id': self.supplier_a.id, 'items': [
                 {'stock_id': stock.id, 'name': stock.medication_name,
                  'qty': 25, 'unit_cost': 6}]}]},
            format='json')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(len(response.data['purchase_orders']), 1)
        self.assertAlmostEqual(response.data['total_cost'], 150.0, places=2)

    def test_link_supplier_endpoint(self):
        stock = self._stock()
        response = self.client.post(
            '/api/inventory/replenishment/link-supplier/',
            {'stock_id': stock.id, 'supplier_id': self.supplier_b.id,
             'unit_cost': 7.25},
            format='json')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['supplier_name'], 'Beta Pharma')
        self.assertAlmostEqual(response.data['unit_cost'], 7.25, places=2)

    def test_link_supplier_endpoint_requires_both_ids(self):
        response = self.client.post(
            '/api/inventory/replenishment/link-supplier/',
            {'stock_id': 1}, format='json')
        self.assertEqual(response.status_code, 400, response.data)

    def test_rfq_endpoint(self):
        stock = self._stock()
        response = self.client.post(
            '/api/inventory/replenishment/rfq/',
            {'branch': self.branch.id,
             'items': [{'stock_id': stock.id, 'name': stock.medication_name,
                        'qty': 12, 'unit': 'tab', 'unit_cost': 3}],
             'supplier_ids': [self.supplier_a.id],
             'title': 'Endpoint RFQ'},
            format='json')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(response.data['rfq_number'].startswith('RFQ-'))
        self.assertEqual(len(response.data['invited']), 1)

    def test_supplier_offers_endpoint(self):
        stock = self._stock()
        replenishment.link_supplier_item(
            supplier_id=self.supplier_a.id, stock_id=stock.id, unit_cost=5)
        response = self.client.get(
            '/api/inventory/replenishment/supplier-offers/',
            {'stocks': str(stock.id)})
        self.assertEqual(response.status_code, 200, response.data)
        offers = response.data['offers']
        self.assertIn(str(stock.id), offers)
        self.assertEqual(offers[str(stock.id)][0]['supplier_id'],
                         self.supplier_a.id)

    def test_replenishment_reports_branch_scope(self):
        stock = self._stock()
        self._batch(stock, 1)
        response = self.client.get('/api/inventory/replenishment/',
                                   {'branch': self.branch.id})
        self.assertEqual(response.status_code, 200, response.data)
        self.assertIn('branch_scope', response.data)
        self.assertFalse(response.data['branch_scope']['locked'])
        self.assertEqual(response.data['branch_scope']['branch_id'],
                         self.branch.id)

    def test_reviewed_pos_rejects_empty_payload(self):
        response = self.client.post(
            '/api/inventory/replenishment/reviewed-pos/',
            {'branch': self.branch.id, 'groups': []}, format='json')
        self.assertEqual(response.status_code, 400, response.data)


# ══════════════════════════════════════════════════════════════════════
#  Branch-aware stock policies
# ══════════════════════════════════════════════════════════════════════
class PolicyBranchScopeTest(BaseTenantCase):
    schema_slug = 'prem_policy_scope'
    domain = 'premium-policy.test.localhost'

    def setUp(self):
        super().setUp()
        self.other = Branch.objects.create(name='North WH', is_main=False)
        self.stock_main = self._stock('Main item', reorder=10)
        self.stock_other = MedicationStock.objects.create(
            medication_name='North item', branch=self.other,
            cost_price='5.00', selling_price='9.00', reorder_level=10)
        planning.refresh_policies()
        self.client.force_authenticate(user=self.admin)

    def _scoped_user(self, branch, email='store@test.local',
                     role='branch_admin'):
        # branch_admin has stock.manage but is NOT in BRANCH_ADMIN_BYPASS_ROLES,
        # so it is the right role for exercising warehouse-scoped writes.
        user = User.objects.create_user(
            email=email, password='x', first_name='Sam', last_name='Store',
            role=role)
        StaffProfile.objects.create(user=user, branch=branch)
        return user

    def test_list_returns_only_requested_branch(self):
        response = self.client.get('/api/inventory/policies/',
                                   {'branch': self.other.id, 'page_size': 500})
        self.assertEqual(response.status_code, 200, response.data)
        ids = [r['stock'] for r in response.data['results']]
        self.assertIn(self.stock_other.id, ids)
        self.assertNotIn(self.stock_main.id, ids)

    def test_list_reports_branch_scope_for_admin(self):
        response = self.client.get('/api/inventory/policies/',
                                   {'branch': self.branch.id})
        self.assertEqual(response.status_code, 200, response.data)
        self.assertFalse(response.data['branch_scope']['locked'])
        self.assertEqual(response.data['branch_scope']['branch_id'], self.branch.id)
        self.assertIn('summary', response.data)
        self.assertGreaterEqual(response.data['summary']['policies'], 1)

    def test_summary_counts_items_without_policy(self):
        MedicationStock.objects.create(
            medication_name='Unplanned item', branch=self.branch,
            cost_price='1.00', selling_price='2.00', reorder_level=5)
        response = self.client.get('/api/inventory/policies/',
                                   {'branch': self.branch.id})
        self.assertEqual(response.status_code, 200, response.data)
        self.assertGreaterEqual(response.data['summary']['without_policy'], 1)

    def test_scoped_user_is_locked_and_ignores_other_branch(self):
        scoped = self._scoped_user(self.branch)
        self.client.force_authenticate(user=scoped)

        # Asking for the other warehouse must silently resolve to their own.
        response = self.client.get('/api/inventory/policies/',
                                   {'branch': self.other.id, 'page_size': 500})
        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(response.data['branch_scope']['locked'])
        self.assertEqual(response.data['branch_scope']['branch_id'], self.branch.id)
        ids = [r['stock'] for r in response.data['results']]
        self.assertNotIn(self.stock_other.id, ids)

    def test_scoped_user_cannot_patch_another_branch_policy(self):
        from inventory.models import StockPolicy
        foreign = StockPolicy.objects.get(stock=self.stock_other)
        scoped = self._scoped_user(self.branch, email='store2@test.local')
        self.client.force_authenticate(user=scoped)

        response = self.client.patch(
            f'/api/inventory/policies/{foreign.pk}/',
            {'reorder_point': 999}, format='json')
        self.assertEqual(response.status_code, 404, response.data)
        foreign.refresh_from_db()
        self.assertNotEqual(foreign.reorder_point, 999)

    def test_scoped_user_can_patch_own_branch_policy(self):
        from inventory.models import StockPolicy
        own = StockPolicy.objects.get(stock=self.stock_main)
        scoped = self._scoped_user(self.branch, email='store3@test.local')
        self.client.force_authenticate(user=scoped)

        response = self.client.patch(
            f'/api/inventory/policies/{own.pk}/',
            {'reorder_point': 42, 'is_manual_reorder_point': True},
            format='json')
        self.assertEqual(response.status_code, 200, response.data)
        own.refresh_from_db()
        self.assertEqual(own.reorder_point, 42)
        self.assertTrue(own.is_manual_reorder_point)

    def test_branches_action_lists_warehouses_with_counts(self):
        response = self.client.get('/api/inventory/policies/branches/')
        self.assertEqual(response.status_code, 200, response.data)
        names = [b['name'] for b in response.data['branches']]
        self.assertIn('Main WH', names)
        self.assertIn('North WH', names)
        self.assertFalse(response.data['locked'])
        row = next(b for b in response.data['branches'] if b['name'] == 'North WH')
        self.assertGreaterEqual(row['policies'], 1)

    def test_branches_action_is_scoped_for_storekeeper(self):
        scoped = self._scoped_user(self.branch, email='store4@test.local')
        self.client.force_authenticate(user=scoped)
        response = self.client.get('/api/inventory/policies/branches/')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(response.data['locked'])
        self.assertEqual(len(response.data['branches']), 1)
        self.assertEqual(response.data['branches'][0]['id'], self.branch.id)

    def test_recompute_respects_branch(self):
        response = self.client.post('/api/inventory/policies/recompute/',
                                    {'branch': self.branch.id}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['branch'], self.branch.id)
        self.assertFalse(response.data['branch_locked'])

    def test_recompute_ignores_requested_branch_for_scoped_user(self):
        scoped = self._scoped_user(self.branch, email='store5@test.local')
        self.client.force_authenticate(user=scoped)
        response = self.client.post('/api/inventory/policies/recompute/',
                                    {'branch': self.other.id}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['branch'], self.branch.id)
        self.assertTrue(response.data['branch_locked'])

    def test_reset_manual_clears_flags_and_recomputes(self):
        from inventory.models import StockPolicy
        own = StockPolicy.objects.get(stock=self.stock_main)
        own.is_manual_reorder_point = True
        own.is_manual_lead_time = True
        own.reorder_point = 500
        own.save(update_fields=['is_manual_reorder_point', 'is_manual_lead_time',
                                'reorder_point'])

        response = self.client.post('/api/inventory/policies/reset-manual/',
                                    {'ids': [own.id]}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['reset'], 1)
        own.refresh_from_db()
        self.assertFalse(own.is_manual_reorder_point)
        self.assertFalse(own.is_manual_lead_time)

    def test_reset_manual_rejects_unknown_field(self):
        response = self.client.post('/api/inventory/policies/reset-manual/',
                                    {'field': 'nonsense'}, format='json')
        self.assertEqual(response.status_code, 400, response.data)

    def test_reset_manual_stays_inside_the_requested_branch(self):
        from inventory.models import StockPolicy
        own = StockPolicy.objects.get(stock=self.stock_main)
        foreign = StockPolicy.objects.get(stock=self.stock_other)
        StockPolicy.objects.update(
            is_manual_reorder_point=True, is_manual_lead_time=True)

        response = self.client.post('/api/inventory/policies/reset-manual/',
                                    {'branch': self.branch.id}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['branch'], self.branch.id)

        own.refresh_from_db()
        foreign.refresh_from_db()
        self.assertFalse(own.is_manual_reorder_point)
        # The other warehouse must be untouched by a branch-scoped reset.
        self.assertTrue(foreign.is_manual_reorder_point)

    def test_reset_manual_ignores_ids_from_another_branch(self):
        from inventory.models import StockPolicy
        foreign = StockPolicy.objects.get(stock=self.stock_other)
        foreign.is_manual_reorder_point = True
        foreign.save(update_fields=['is_manual_reorder_point'])

        scoped = self._scoped_user(self.branch, email='store6@test.local')
        self.client.force_authenticate(user=scoped)
        response = self.client.post('/api/inventory/policies/reset-manual/',
                                    {'ids': [foreign.id]}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['reset'], 0)
        foreign.refresh_from_db()
        self.assertTrue(foreign.is_manual_reorder_point)

    def test_manual_filter_returns_only_overridden_rows(self):
        from inventory.models import StockPolicy
        own = StockPolicy.objects.get(stock=self.stock_main)
        own.is_manual_service_level = True
        own.save(update_fields=['is_manual_service_level'])

        response = self.client.get('/api/inventory/policies/',
                                   {'manual': '1', 'page_size': 500})
        self.assertEqual(response.status_code, 200, response.data)
        ids = [r['id'] for r in response.data['results']]
        self.assertIn(own.id, ids)
        self.assertTrue(all(
            r['is_manual_reorder_point'] or r['is_manual_lead_time']
            or r['is_manual_service_level']
            for r in response.data['results']))
