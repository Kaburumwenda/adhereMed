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
