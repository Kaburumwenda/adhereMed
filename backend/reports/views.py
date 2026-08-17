"""Aggregated read-only reports for the pharmacy dashboard."""
from datetime import datetime, timedelta
from decimal import Decimal

from django.db.models import Sum, Count, F, Q
from django.utils import timezone
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView


def _parse_range(request):
    """Return (start, end) datetimes from ?date_from=&date_to= or ?period=today|week|month."""
    today = timezone.now().date()
    period = (request.query_params.get('period') or '').lower()
    df = request.query_params.get('date_from')
    dt = request.query_params.get('date_to')
    if df and dt:
        try:
            return (datetime.strptime(df, '%Y-%m-%d'),
                    datetime.strptime(dt, '%Y-%m-%d') + timedelta(days=1))
        except ValueError:
            pass
    if period == 'today':
        start = today
    elif period == 'yesterday':
        start = today - timedelta(days=1)
        return (datetime.combine(start, datetime.min.time()),
                datetime.combine(today, datetime.min.time()))
    elif period == 'week':
        start = today - timedelta(days=today.weekday())
    elif period in ('last7', 'last_7', '7d'):
        start = today - timedelta(days=6)
    elif period in ('last30', 'last_30', '30d'):
        start = today - timedelta(days=29)
    elif period in ('last90', 'last_90', '90d'):
        start = today - timedelta(days=89)
    elif period == 'year':
        start = today.replace(month=1, day=1)
    else:  # month default
        start = today.replace(day=1)
    return (datetime.combine(start, datetime.min.time()),
            datetime.combine(today + timedelta(days=1), datetime.min.time()))


class SalesSummaryView(APIView):
    """Daily / range sales summary across POS + Dispensing."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from pos.models import POSTransaction
        from dispensing.models import DispensingRecord

        start, end = _parse_range(request)
        pos_qs = POSTransaction.objects.filter(
            created_at__gte=start, created_at__lt=end, status='completed'
        )
        disp_qs = DispensingRecord.objects.filter(
            dispensed_at__gte=start, dispensed_at__lt=end, status='completed'
        )

        pos_agg = pos_qs.aggregate(count=Count('id'), revenue=Sum('total'),
                                   discount=Sum('discount'), tax=Sum('tax'))
        disp_agg = disp_qs.aggregate(count=Count('id'), revenue=Sum('total'),
                                     discount=Sum('discount'))

        # Daily breakdown
        from django.db.models.functions import TruncDate
        daily_pos = list(pos_qs.annotate(d=TruncDate('created_at'))
                         .values('d').annotate(revenue=Sum('total'), count=Count('id'))
                         .order_by('d'))
        daily_disp = list(disp_qs.annotate(d=TruncDate('dispensed_at'))
                          .values('d').annotate(revenue=Sum('total'), count=Count('id'))
                          .order_by('d'))

        # Payment method mix
        pm_pos = list(pos_qs.values('payment_method').annotate(count=Count('id'), revenue=Sum('total')))
        pm_disp = list(disp_qs.values('payment_method').annotate(count=Count('id'), revenue=Sum('total')))

        return Response({
            'range': {'start': start, 'end': end},
            'pos': {
                'count': pos_agg['count'] or 0,
                'revenue': float(pos_agg['revenue'] or 0),
                'discount': float(pos_agg['discount'] or 0),
                'tax': float(pos_agg['tax'] or 0),
            },
            'dispensing': {
                'count': disp_agg['count'] or 0,
                'revenue': float(disp_agg['revenue'] or 0),
                'discount': float(disp_agg['discount'] or 0),
            },
            'combined_revenue': float((pos_agg['revenue'] or 0) + (disp_agg['revenue'] or 0)),
            'combined_count': (pos_agg['count'] or 0) + (disp_agg['count'] or 0),
            'daily_pos': [{'date': d['d'], 'revenue': float(d['revenue'] or 0), 'count': d['count']} for d in daily_pos],
            'daily_dispensing': [{'date': d['d'], 'revenue': float(d['revenue'] or 0), 'count': d['count']} for d in daily_disp],
            'payment_mix_pos': pm_pos,
            'payment_mix_dispensing': pm_disp,
        })


class TopProductsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from pos.models import TransactionItem
        start, end = _parse_range(request)
        try:
            limit = int(request.query_params.get('limit', 20))
        except ValueError:
            limit = 20
        rows = (TransactionItem.objects
                .filter(transaction__created_at__gte=start, transaction__created_at__lt=end,
                        transaction__status='completed')
                .values('medication_name')
                .annotate(quantity=Sum('quantity'),
                          revenue=Sum('total_price'),
                          orders=Count('transaction', distinct=True))
                .order_by('-revenue')[:limit])
        return Response({
            'range': {'start': start, 'end': end},
            'items': [{
                'medication_name': r['medication_name'],
                'quantity': r['quantity'] or 0,
                'revenue': float(r['revenue'] or 0),
                'orders': r['orders'] or 0,
            } for r in rows],
        })


class CashierPerformanceView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from pos.models import POSTransaction
        start, end = _parse_range(request)
        rows = (POSTransaction.objects
                .filter(created_at__gte=start, created_at__lt=end, status='completed')
                .values('cashier_id', 'cashier__first_name', 'cashier__last_name', 'cashier__email')
                .annotate(transactions=Count('id'),
                          revenue=Sum('total'),
                          discount=Sum('discount'))
                .order_by('-revenue'))
        return Response({
            'range': {'start': start, 'end': end},
            'cashiers': [{
                'cashier_id': r['cashier_id'],
                'name': (f"{r['cashier__first_name'] or ''} {r['cashier__last_name'] or ''}".strip()
                         or r['cashier__email'] or 'Unknown'),
                'transactions': r['transactions'],
                'revenue': float(r['revenue'] or 0),
                'discount': float(r['discount'] or 0),
                'avg_basket': float((r['revenue'] or 0) / max(1, r['transactions'])),
            } for r in rows],
        })


class InventoryValuationView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from inventory.models import StockBatch, MedicationStock
        batches = (StockBatch.objects
                   .filter(quantity_remaining__gt=0)
                   .select_related('stock'))
        cost_value = 0.0
        sale_value = 0.0
        item_count = 0
        per_category = {}
        for b in batches:
            qty = float(b.quantity_remaining or 0)
            cost = float(b.cost_price_per_unit or 0)
            sell = float(b.stock.selling_price or 0) if b.stock else 0
            cv = qty * cost
            sv = qty * sell
            cost_value += cv
            sale_value += sv
            item_count += int(qty)
            cat = (b.stock.category.name if (b.stock and b.stock.category_id) else 'Uncategorized')
            d = per_category.setdefault(cat, {'cost': 0.0, 'sale': 0.0, 'units': 0})
            d['cost'] += cv
            d['sale'] += sv
            d['units'] += int(qty)

        return Response({
            'cost_value': cost_value,
            'sale_value': sale_value,
            'potential_margin': sale_value - cost_value,
            'unit_count': item_count,
            'sku_count': MedicationStock.objects.filter(is_active=True).count(),
            'by_category': [{'category': k, **v} for k, v in
                            sorted(per_category.items(), key=lambda x: -x[1]['cost'])],
        })


class ExpiryReportView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from inventory.models import StockBatch
        try:
            days = int(request.query_params.get('days', 90))
        except ValueError:
            days = 90
        today = timezone.now().date()
        cutoff = today + timedelta(days=days)
        batches = (StockBatch.objects
                   .filter(quantity_remaining__gt=0, expiry_date__isnull=False,
                           expiry_date__lte=cutoff)
                   .select_related('stock'))
        rows = []
        loss = 0.0
        for b in batches:
            days_left = (b.expiry_date - today).days
            cost = float(b.cost_price_per_unit or 0) * float(b.quantity_remaining or 0)
            loss += cost if days_left < 0 else 0
            rows.append({
                'stock_id': b.stock_id,
                'medication_name': b.stock.medication_name if b.stock else '',
                'batch_number': b.batch_number,
                'quantity_remaining': b.quantity_remaining,
                'expiry_date': b.expiry_date,
                'days_left': days_left,
                'cost_value': cost,
            })
        rows.sort(key=lambda r: r['days_left'])
        return Response({
            'days_horizon': days,
            'expired_loss_value': loss,
            'count': len(rows),
            'batches': rows,
        })


class LowStockReportView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from inventory.models import MedicationStock
        items = []
        for s in MedicationStock.objects.filter(is_active=True).select_related('category'):
            qty = s.total_quantity
            if qty <= (s.reorder_level or 0):
                items.append({
                    'id': s.id,
                    'medication_name': s.medication_name,
                    'category': s.category.name if s.category_id else '',
                    'quantity': qty,
                    'reorder_level': s.reorder_level,
                    'reorder_quantity': s.reorder_quantity,
                    'cost_price': float(s.cost_price or 0),
                    'estimated_reorder_cost': float(s.cost_price or 0) * float(s.reorder_quantity or 0),
                })
        items.sort(key=lambda x: x['quantity'])
        return Response({
            'count': len(items),
            'estimated_reorder_value': sum(x['estimated_reorder_cost'] for x in items),
            'items': items,
        })


class ProfitLossView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from pos.models import TransactionItem
        from dispensing.models import DispensingRecord
        from expenses.models import Expense
        start, end = _parse_range(request)

        # Sales revenue + COGS from POS line items
        ti = TransactionItem.objects.filter(
            transaction__created_at__gte=start, transaction__created_at__lt=end,
            transaction__status='completed',
        ).select_related('stock')
        pos_revenue = 0.0
        cogs = 0.0
        for it in ti:
            pos_revenue += float(it.total_price or 0)
            cogs += float(it.quantity or 0) * float((it.stock.cost_price if it.stock else 0) or 0)

        # Dispensing revenue
        disp_revenue = float(DispensingRecord.objects
                             .filter(dispensed_at__gte=start, dispensed_at__lt=end, status='completed')
                             .aggregate(s=Sum('total'))['s'] or 0)

        # Expenses
        try:
            expenses_total = float(Expense.objects
                                   .filter(date__gte=start.date(), date__lt=end.date())
                                   .aggregate(s=Sum('amount'))['s'] or 0)
        except Exception:
            expenses_total = 0.0

        revenue = pos_revenue + disp_revenue
        gross = revenue - cogs
        net = gross - expenses_total
        return Response({
            'range': {'start': start, 'end': end},
            'revenue': revenue,
            'pos_revenue': pos_revenue,
            'dispensing_revenue': disp_revenue,
            'cogs': cogs,
            'gross_profit': gross,
            'gross_margin_pct': (gross / revenue * 100) if revenue > 0 else 0,
            'expenses': expenses_total,
            'net_profit': net,
        })


class ROIView(APIView):
    """Return on Investment (ROI) for the pharmacy.

    ROI = net_profit / inventory_cost_value × 100, where:
      net_profit        = revenue − COGS − operating_expenses
      inventory_cost_value = Σ StockBatch.quantity_remaining × cost_price_per_unit
                             (current snapshot; approximates average inventory)
    Optional ?branch_id=? filters POS revenue/COGS and inventory by branch.
    Date range via ?date_from=&date_to= or ?period=last7|last30|last90|month|year.
    Returns KPIs, per-day trend, top contributors, cost breakdown (for donut),
    and a revenue-vs-cost bucketed series (for bars).
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from pos.models import TransactionItem
        from dispensing.models import DispensingRecord
        from expenses.models import Expense
        from inventory.models import StockBatch, MedicationStock
        from django.db.models.functions import TruncDate

        start, end = _parse_range(request)
        branch_id = request.query_params.get('branch_id')
        branch_q_pos = Q(transaction__branch_id=branch_id) if branch_id else Q()
        branch_q_inv = Q(branch_id=branch_id) if branch_id else Q()

        # ── POS revenue + COGS (current cost_price snapshot) ──────────
        ti_qs = (TransactionItem.objects
                 .filter(transaction__created_at__gte=start,
                         transaction__created_at__lt=end,
                         transaction__status='completed')
                 .filter(branch_q_pos)
                 .select_related('stock'))
        pos_revenue = 0.0
        cogs = 0.0
        per_product = {}  # name → {revenue, cost, qty}
        for it in ti_qs:
            rev = float(it.total_price or 0)
            cp = float(it.stock.cost_price if it.stock else 0) or 0
            qty = float(it.quantity or 0)
            pos_revenue += rev
            cogs += qty * cp
            name = (it.stock.medication_name if it.stock else it.medication_name) or 'Unknown'
            d = per_product.setdefault(name, {'revenue': 0.0, 'cost': 0.0, 'qty': 0.0})
            d['revenue'] += rev
            d['cost'] += qty * cp
            d['qty'] += qty

        # ── Dispensing revenue (no COGS available — matches ProfitLossView) ──
        disp_qs = DispensingRecord.objects.filter(
            dispensed_at__gte=start, dispensed_at__lt=end, status='completed')
        disp_revenue = float(disp_qs.aggregate(s=Sum('total'))['s'] or 0)

        # ── Operating expenses (correct field: expense_date; exclude rejected/cancelled) ──
        try:
            exp_qs = (Expense.objects
                      .filter(expense_date__gte=start.date(),
                              expense_date__lt=end.date())
                      .exclude(status__in=['rejected', 'cancelled']))
            operating_expenses = float(exp_qs.aggregate(s=Sum('amount'))['s'] or 0)
        except Exception:
            exp_qs = Expense.objects.none()
            operating_expenses = 0.0

        # API usage cost (separate cost bucket for the donut) — pulled from
        # the same usage-billing dashboard shape used by the front-end. Since
        # usage_billing summary is tenant-wide and dated by bill, we treat it
        # as a subset of operating_expenses here (set to 0 unless the data lives
        # inside Expense rows with category 'API Usage & Billing', already
        # captured above). Kept as a separate slot for the donut.
        api_usage_cost = 0.0
        try:
            api_usage_cost = float(exp_qs
                                   .filter(category__name__iexact='API Usage & Billing')
                                   .aggregate(s=Sum('amount'))['s'] or 0)
        except Exception:
            api_usage_cost = 0.0

        revenue = pos_revenue + disp_revenue
        gross_profit = revenue - cogs
        net_profit = gross_profit - operating_expenses
        gross_margin_pct = (gross_profit / revenue * 100) if revenue > 0 else 0
        net_margin_pct = (net_profit / revenue * 100) if revenue > 0 else 0

        # ── Inventory valuation (current snapshot) ───────────────────
        batches = (StockBatch.objects
                   .filter(quantity_remaining__gt=0)
                   .filter(branch_q_inv)
                   .select_related('stock', 'stock__category'))
        inv_cost = 0.0
        inv_sale = 0.0
        # Per-stock investment for ROI-per-product denominator
        product_inv = {}  # name → current invested cost (qty × cost_price)
        for b in batches:
            qty = float(b.quantity_remaining or 0)
            cpu = float(b.cost_price_per_unit or 0)
            sell = float(b.stock.selling_price or 0) if b.stock else 0
            inv_cost += qty * cpu
            inv_sale += qty * sell
            sname = b.stock.medication_name if b.stock else None
            if sname:
                product_inv[sname] = product_inv.get(sname, 0.0) + qty * cpu

        roi_pct = (net_profit / inv_cost * 100) if inv_cost > 0 else 0
        capital_turnover = (revenue / inv_cost) if inv_cost > 0 else 0  # full precision kept in response
        # Payback months: months_in_range = (end - start).days / 30.44
        days_in_range = max(1, (end - start).days)
        months_in_range = days_in_range / 30.44
        avg_monthly_net = net_profit / months_in_range if months_in_range > 0 else 0
        payback_months = (inv_cost / avg_monthly_net) if avg_monthly_net > 0 else 0

        # ── Trend series (per-day, capped to keep payload sane) ────────
        # Build per-day {date → {revenue, cost, expenses}} then compute a
        # 7-day rolling net profit and per-day ROI using the constant
        # inventory_cost_value as denominator.
        num_days = (end.date() - start.date()).days
        step = 1
        if num_days > 90:
            step = max(1, num_days // 60)  # downsample to ~60 points
        day_index = []  # list of (date_str)
        d0 = start.date()
        for k in range(0, num_days + 1, step):
            day_index.append((d0 + timedelta(days=k)).isoformat())

        # POS per-day (revenue + cost)
        pos_daily = {}
        for row in (ti_qs.annotate(d=TruncDate('transaction__created_at'))
                    .values('d')
                    .annotate(rev=Sum('total_price'),
                              cost=Sum(F('quantity') * F('stock__cost_price')))):
            if row['d']:
                pos_daily[row['d'].isoformat()] = {
                    'revenue': float(row['rev'] or 0),
                    'cost': float(row['cost'] or 0),
                }
        # Dispensing per-day revenue
        disp_daily = {}
        for row in (DispensingRecord.objects
                    .filter(dispensed_at__gte=start, dispensed_at__lt=end,
                            status='completed')
                    .annotate(d=TruncDate('dispensed_at'))
                    .values('d')
                    .annotate(rev=Sum('total'))):
            if row['d']:
                disp_daily[row['d'].isoformat()] = float(row['rev'] or 0)
        # Expenses per-day
        exp_daily = {}
        try:
            for row in (exp_qs.annotate(d=TruncDate('expense_date'))
                        .values('d')
                        .annotate(s=Sum('amount'))):
                if row['d']:
                    exp_daily[row['d'].isoformat()] = float(row['s'] or 0)
        except Exception:
            pass

        trend = []
        rolling_net = []
        window = 7  # 7-day rolling net
        for ds in day_index:
            p = pos_daily.get(ds, {'revenue': 0.0, 'cost': 0.0})
            dr = disp_daily.get(ds, 0.0)
            ex = exp_daily.get(ds, 0.0)
            day_rev = p['revenue'] + dr
            day_cost = p['cost']
            day_net = day_rev - day_cost - ex
            rolling_net.append(day_net)
            if len(rolling_net) > window:
                rolling_net = rolling_net[-window:]
            rolling_sum = sum(rolling_net)
            day_roi = (rolling_sum / inv_cost * 100) if inv_cost > 0 else 0
            trend.append({
                'date': ds,
                'revenue': round(day_rev, 2),
                'cost': round(day_cost, 2),
                'net_profit': round(day_net, 2),
                'roi_pct': round(day_roi, 2),
            })

        # ── Top contributors (by product) ──────────────────────────────
        # Per-product ROI uses current invested inventory as denominator
        # when present; otherwise falls back to COGS (the cost the sale
        # incurred) so out-of-stock products still surface a meaningful
        # return-on-cost figure.
        contributors = []
        for name, v in per_product.items():
            profit = v['revenue'] - v['cost']
            inv = product_inv.get(name, 0.0)
            denom = inv if inv > 0 else v['cost']
            roi_p = (profit / denom * 100) if denom > 0 else 0
            contributors.append({
                'name': name,
                'revenue': round(v['revenue'], 2),
                'cost': round(v['cost'], 2),
                'profit': round(profit, 2),
                'roi_pct': round(roi_p, 2),
                'qty_sold': int(v['qty']),
            })
        contributors.sort(key=lambda x: -x['profit'])
        top_contributors = contributors[:8]

        # ── Cost breakdown (donut) ────────────────────────────────────
        cost_breakdown = [
            {'label': 'COGS', 'value': round(cogs, 2), 'color': '#ef4444'},
            {'label': 'Operating expenses', 'value': round(operating_expenses - api_usage_cost, 2),
             'color': '#f59e0b'},
            {'label': 'API usage', 'value': round(api_usage_cost, 2), 'color': '#8b5cf6'},
        ]
        # Drop zero buckets
        cost_breakdown = [c for c in cost_breakdown if c['value'] > 0]

        # ── Revenue vs Cost buckets (weekly if range > 14 days else daily) ──
        use_weekly = num_days > 14
        rvc_map = {}  # bucket_key → {revenue, cost}
        for ds, p in pos_daily.items():
            dsdate = datetime.fromisoformat(ds).date()
            if use_weekly:
                # ISO week starting Monday
                wk_start = dsdate - timedelta(days=dsdate.weekday())
                key = wk_start.isoformat()
            else:
                key = ds
            d = rvc_map.setdefault(key, {'revenue': 0.0, 'cost': 0.0})
            d['revenue'] += p['revenue']
            d['cost'] += p['cost']
        for ds, dr in disp_daily.items():
            dsdate = datetime.fromisoformat(ds).date()
            if use_weekly:
                wk_start = dsdate - timedelta(days=dsdate.weekday())
                key = wk_start.isoformat()
            else:
                key = ds
            d = rvc_map.setdefault(key, {'revenue': 0.0, 'cost': 0.0})
            d['revenue'] += dr
        revenue_vs_cost = [
            {'period': k, 'revenue': round(v['revenue'], 2), 'cost': round(v['cost'], 2)}
            for k, v in sorted(rvc_map.items())
        ][:30]  # cap to keep payload small

        return Response({
            'range': {'start': start, 'end': end},
            'kpis': {
                'roi_pct': round(roi_pct, 2),
                'net_profit': round(net_profit, 2),
                'cogs': round(cogs, 2),
                'gross_margin_pct': round(gross_margin_pct, 2),
                'net_margin_pct': round(net_margin_pct, 2),
                'operating_expenses': round(operating_expenses, 2),
                'revenue': round(revenue, 2),
                'pos_revenue': round(pos_revenue, 2),
                'dispensing_revenue': round(disp_revenue, 2),
                'inventory_cost_value': round(inv_cost, 2),
                'inventory_sale_value': round(inv_sale, 2),
                'potential_gross_profit': round(inv_sale - inv_cost, 2),
                'capital_turnover': round(capital_turnover, 4),
                'payback_months': round(payback_months, 2),
                'gross_profit': round(gross_profit, 2),
            },
            'trend': trend,
            'top_contributors': top_contributors,
            'cost_breakdown': cost_breakdown,
            'revenue_vs_cost': revenue_vs_cost,
        })


class CashFlowView(APIView):
    """Cash Flow statement for the pharmacy (direct method).

    Aggregates actual cash inflows and outflows within the chosen range:
      Inflows  : POS sales, dispensing receipts, billing payments, credit-settlements
      Outflows : paid expenses, purchase orders (received / partial)
    Optional ?branch_id=? filters POS/dispensing by branch.
    Date range via ?date_from=&date_to= or ?period=last7|last30|last90|month|year.
    Returns KPIs, per-day trend (inflow/outflow/net), method breakdown (donut),
    inflow vs outflow bucketed series (bars), and a running cumulative cash line.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from pos.models import POSTransaction, CreditPayment
        from dispensing.models import DispensingRecord
        from billing.models import Payment
        from expenses.models import Expense
        from purchase_orders.models import PurchaseOrder
        from django.db.models.functions import TruncDate

        start, end = _parse_range(request)
        branch_id = request.query_params.get('branch_id')
        branch_q_pos = Q(branch_id=branch_id) if branch_id else Q()

        # ── Inflows ─────────────────────────────────────────────────────
        pos_qs = (POSTransaction.objects
                  .filter(created_at__gte=start, created_at__lt=end,
                          status='completed')
                  .filter(branch_q_pos))
        inflow_pos = float(pos_qs.aggregate(s=Sum('total'))['s'] or 0)

        disp_qs = (DispensingRecord.objects
                   .filter(dispensed_at__gte=start, dispensed_at__lt=end,
                           status='completed')
                   .filter(branch_q_pos))
        inflow_disp = float(disp_qs.aggregate(s=Sum('paid_amount'))['s'] or 0)

        bill_qs = Payment.objects.filter(paid_at__gte=start, paid_at__lt=end)
        inflow_bill = float(bill_qs.aggregate(s=Sum('amount'))['s'] or 0)

        credit_qs = CreditPayment.objects.filter(paid_at__gte=start, paid_at__lt=end)
        inflow_credit = float(credit_qs.aggregate(s=Sum('amount'))['s'] or 0)

        total_inflow = inflow_pos + inflow_disp + inflow_bill + inflow_credit

        # ── Outflows ────────────────────────────────────────────────────
        try:
            exp_qs = (Expense.objects
                      .filter(expense_date__gte=start.date(),
                              expense_date__lt=end.date())
                      .exclude(status__in=['rejected', 'cancelled', 'pending']))
        except Exception:
            exp_qs = Expense.objects.none()
        # Use amount + tax_amount for the actual cash outlay
        exp_agg = exp_qs.aggregate(s=Sum('amount'), t=Sum('tax_amount'))
        outflow_exp = float(exp_agg['s'] or 0) + float(exp_agg['t'] or 0)

        try:
            po_qs = (PurchaseOrder.objects
                     .filter(created_at__gte=start, created_at__lt=end,
                             status__in=['received', 'partial']))
            outflow_po = float(po_qs.aggregate(s=Sum('total_cost'))['s'] or 0)
        except Exception:
            outflow_po = 0.0

        total_outflow = outflow_exp + outflow_po

        net_cash_flow = total_inflow - total_outflow

        # ── Per-day trend ───────────────────────────────────────────────
        pos_daily = {}
        for row in (pos_qs.annotate(d=TruncDate('created_at'))
                    .values('d').annotate(v=Sum('total'))):
            if row['d']:
                pos_daily[row['d'].isoformat()] = float(row['v'] or 0)
        disp_daily = {}
        for row in (disp_qs.annotate(d=TruncDate('dispensed_at'))
                    .values('d').annotate(v=Sum('paid_amount'))):
            if row['d']:
                disp_daily[row['d'].isoformat()] = float(row['v'] or 0)
        bill_daily = {}
        for row in (bill_qs.annotate(d=TruncDate('paid_at'))
                    .values('d').annotate(v=Sum('amount'))):
            if row['d']:
                bill_daily[row['d'].isoformat()] = float(row['v'] or 0)
        credit_daily = {}
        for row in (credit_qs.annotate(d=TruncDate('paid_at'))
                    .values('d').annotate(v=Sum('amount'))):
            if row['d']:
                credit_daily[row['d'].isoformat()] = float(row['v'] or 0)
        exp_daily = {}
        try:
            for row in (exp_qs.annotate(d=TruncDate('expense_date'))
                        .values('d')
                        .annotate(v=Sum('amount'), t=Sum('tax_amount'))):
                if row['d']:
                    exp_daily[row['d'].isoformat()] = (
                        float(row['v'] or 0) + float(row['t'] or 0)
                    )
        except Exception:
            pass

        # Build day index
        num_days = max(1, (end.date() - start.date()).days)
        step = 1
        if num_days > 90:
            step = max(1, num_days // 60)
        day_index = []
        d0 = start.date()
        for k in range(0, num_days + 1, step):
            day_index.append((d0 + timedelta(days=k)).isoformat())

        trend = []
        cumulative = 0.0
        for ds in day_index:
            day_in = (pos_daily.get(ds, 0) + disp_daily.get(ds, 0)
                      + bill_daily.get(ds, 0) + credit_daily.get(ds, 0))
            day_out = exp_daily.get(ds, 0)
            day_net = day_in - day_out
            cumulative += day_net
            trend.append({
                'date': ds,
                'inflow': round(day_in, 2),
                'outflow': round(day_out, 2),
                'net': round(day_net, 2),
                'cumulative': round(cumulative, 2),
            })

        # ── Inflow breakdown (donut) ───────────────────────────────────
        inflow_segments = [
            {'label': 'POS sales', 'value': round(inflow_pos, 2), 'color': '#16a34a'},
            {'label': 'Dispensing', 'value': round(inflow_disp, 2), 'color': '#22c55e'},
            {'label': 'Bill payments', 'value': round(inflow_bill, 2), 'color': '#84cc16'},
            {'label': 'Credit settlements', 'value': round(inflow_credit, 2), 'color': '#0ea5e9'},
        ]
        inflow_segments = [s for s in inflow_segments if s['value'] > 0]

        # ── Outflow breakdown (donut) ───────────────────────────────────
        outflow_segments = [
            {'label': 'Expenses', 'value': round(outflow_exp, 2), 'color': '#ef4444'},
            {'label': 'Purchase orders', 'value': round(outflow_po, 2), 'color': '#f59e0b'},
        ]
        outflow_segments = [s for s in outflow_segments if s['value'] > 0]

        # ── Inflow vs Outflow buckets (weekly if range > 14 days) ────────
        use_weekly = num_days > 14
        rvc_map = {}
        for ds, v in {**pos_daily, **disp_daily, **bill_daily, **credit_daily}.items():
            dsdate = datetime.fromisoformat(ds).date()
            key = (dsdate - timedelta(days=dsdate.weekday())).isoformat() if use_weekly else ds
            rvc_map.setdefault(key, {'inflow': 0.0, 'outflow': 0.0})
            rvc_map[key]['inflow'] += v
        for ds, v in exp_daily.items():
            dsdate = datetime.fromisoformat(ds).date()
            key = (dsdate - timedelta(days=dsdate.weekday())).isoformat() if use_weekly else ds
            rvc_map.setdefault(key, {'inflow': 0.0, 'outflow': 0.0})
            rvc_map[key]['outflow'] += v
        inflow_vs_outflow = [
            {'period': k, 'inflow': round(v['inflow'], 2), 'outflow': round(v['outflow'], 2)}
            for k, v in sorted(rvc_map.items())
        ][:30]

        # ── Payment method breakdown (cash vs mpesa vs card etc) ────────
        method_map = {}
        for row in pos_qs.values('payment_method').annotate(s=Sum('total')):
            m = (row['payment_method'] or 'other')
            method_map[m] = method_map.get(m, 0.0) + float(row['s'] or 0)
        for row in disp_qs.values('payment_method').annotate(s=Sum('paid_amount')):
            m = (row['payment_method'] or 'other')
            method_map[m] = method_map.get(m, 0.0) + float(row['s'] or 0)
        for row in bill_qs.values('method').annotate(s=Sum('amount')):
            m = (row['method'] or 'other')
            method_map[m] = method_map.get(m, 0.0) + float(row['s'] or 0)
        for row in credit_qs.values('payment_method').annotate(s=Sum('amount')):
            m = (row['payment_method'] or 'other')
            method_map[m] = method_map.get(m, 0.0) + float(row['s'] or 0)
        method_colors = {
            'cash': '#16a34a', 'mpesa': '#0ea5e9', 'card': '#8b5cf6',
            'insurance': '#f59e0b', 'bank_transfer': '#6366f1', 'credit': '#ec4899',
            'other': '#64748b',
        }
        method_segments = [
            {'label': m, 'value': round(v, 2),
             'color': method_colors.get(m, '#64748b')}
            for m, v in sorted(method_map.items(), key=lambda x: -x[1])
            if v > 0
        ]

        # Operating cash flow = business cash only (exclude PO investing outflow)
        operating_cash_flow = total_inflow - outflow_exp
        # Cash balance proxy ending = cumulative net within range
        ending_cash_proxy = cumulative

        daily_burn = total_outflow / max(1, num_days)
        runway_days = (ending_cash_proxy / daily_burn) if daily_burn > 0 and ending_cash_proxy > 0 else 0

        # ── Unified transactions list (inflows + outflows) for the table ──
        transactions = []
        # POS inflows
        for tx in pos_qs.only('id', 'created_at', 'total', 'payment_method',
                             'transaction_number').order_by('-created_at'):
            transactions.append({
                'date': tx.created_at.date().isoformat() if tx.created_at else '',
                'direction': 'inflow',
                'source': 'POS Sale',
                'reference': tx.transaction_number or f'POS-{tx.id}',
                'method': tx.payment_method or '',
                'amount': float(tx.total or 0),
            })
        # Dispensing inflows
        for tx in disp_qs.only('id', 'dispensed_at', 'paid_amount',
                              'payment_method').order_by('-dispensed_at'):
            transactions.append({
                'date': tx.dispensed_at.date().isoformat() if tx.dispensed_at else '',
                'direction': 'inflow',
                'source': 'Dispensing',
                'reference': f'DISP-{tx.id}',
                'method': tx.payment_method or '',
                'amount': float(tx.paid_amount or 0),
            })
        # Billing payments
        for tx in bill_qs.only('id', 'paid_at', 'amount', 'method').order_by('-paid_at'):
            transactions.append({
                'date': tx.paid_at.date().isoformat() if tx.paid_at else '',
                'direction': 'inflow',
                'source': 'Bill Payment',
                'reference': f'PAY-{tx.id}',
                'method': tx.method or '',
                'amount': float(tx.amount or 0),
            })
        # Credit settlements
        for tx in credit_qs.only('id', 'paid_at', 'amount',
                                 'payment_method').order_by('-paid_at'):
            transactions.append({
                'date': tx.paid_at.date().isoformat() if tx.paid_at else '',
                'direction': 'inflow',
                'source': 'Credit Settlement',
                'reference': f'CRP-{tx.id}',
                'method': tx.payment_method or '',
                'amount': float(tx.amount or 0),
            })
        # Expense outflows
        for tx in exp_qs.only('id', 'expense_date', 'amount', 'tax_amount',
                              'payment_method', 'title', 'vendor').order_by('-expense_date'):
            transactions.append({
                'date': tx.expense_date.isoformat() if tx.expense_date else '',
                'direction': 'outflow',
                'source': 'Expense',
                'reference': tx.title or f'EXP-{tx.id}',
                'method': tx.payment_method or '',
                'amount': -(float(tx.amount or 0) + float(tx.tax_amount or 0)),
            })
        # Purchase order outflows
        try:
            for tx in po_qs.only('id', 'created_at', 'total_cost',
                               'po_number').order_by('-created_at'):
                transactions.append({
                    'date': tx.created_at.date().isoformat() if tx.created_at else '',
                    'direction': 'outflow',
                    'source': 'Purchase Order',
                    'reference': tx.po_number or f'PO-{tx.id}',
                    'method': '',
                    'amount': -float(tx.total_cost or 0),
                })
        except Exception:
            pass
        # Cap to keep payload sane
        transactions.sort(key=lambda x: x['date'], reverse=True)
        transactions = transactions[:200]

        return Response({
            'range': {'start': start, 'end': end},
            'kpis': {
                'total_inflow': round(total_inflow, 2),
                'total_outflow': round(total_outflow, 2),
                'net_cash_flow': round(net_cash_flow, 2),
                'operating_cash_flow': round(operating_cash_flow, 2),
                'ending_cash_proxy': round(ending_cash_proxy, 2),
                'inflow_count': (pos_qs.count() + disp_qs.count()
                                 + bill_qs.count() + credit_qs.count()),
                'outflow_count': exp_qs.count() + getattr(po_qs, 'count', lambda: 0)(),
                'burn_rate': round(daily_burn, 2),
                'runway_days': round(runway_days, 1),
            },
            'trend': trend,
            'inflow_segments': inflow_segments,
            'outflow_segments': outflow_segments,
            'method_segments': method_segments,
            'inflow_vs_outflow': inflow_vs_outflow,
            'transactions': transactions,
        })
