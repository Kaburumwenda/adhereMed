"""Item traceability API: life-of-item trace, custody export, item picker."""
from __future__ import annotations

import csv
import io
import re

from django.http import HttpResponse
from django.utils import timezone
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import MedicationStock
from ..rbac import InventoryPermission
from ..services import traceability
from .base import _audit, _forced_branch_id


def _int(value, default=None):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _parse_date(value):
    from ..reports.datasets import parse_date
    return parse_date(value)


def _window(request):
    data = request.query_params if request.method == 'GET' else request.data
    date_from = _parse_date(data.get('date_from'))
    date_to = _parse_date(data.get('date_to'))
    days = _int(data.get('days'))
    return date_from, date_to, days


def _scope_label(*, branch_name, locked):
    """One sentence describing what the reader was allowed to see.

    A custody record that does not say whether it covers one warehouse or all
    of them is ambiguous the moment it is filed: two copies of the same item
    can reconcile differently depending on who exported them, and without this
    line nothing on the page explains why.
    """
    if locked:
        return f'{branch_name} - locked to the reader\'s warehouse'
    return f'All warehouses - item held at {branch_name}'


def _scoped_stock(request, pk):
    """The stock row for ``pk``, or ``None`` when out of the reader's reach.

    A branch-scoped user (storekeeper, branch admin) must not be able to pull
    another warehouse's custody record just by walking ids. Returns ``None``
    rather than raising so the caller can answer 404 - deliberately *not* 403,
    because a distinct error would confirm that the id exists elsewhere.

    Stock with no branch stays visible to everyone, mirroring
    :class:`config.branch_scope.BranchScopedMixin`.
    """
    stock = (MedicationStock.objects
             .select_related('branch', 'category', 'unit')
             .filter(pk=pk).first())
    if stock is None:
        return None
    forced = _forced_branch_id(request.user)
    if forced and stock.branch_id and stock.branch_id != forced:
        return None
    return stock


def _branch_scope(request, stock):
    """Payload block telling the page and the exported record where it sits."""
    forced = _forced_branch_id(request.user)
    name = traceability.branch_label(stock.branch)
    locked = bool(forced)
    return {
        'locked': locked,
        'branch_id': stock.branch_id,
        'branch': name,
        'label': _scope_label(branch_name=name, locked=locked),
    }


def _slug(text, limit=44):
    """A filename-safe slug: collapse separators, trim to a word boundary.

    Item names arrive with slashes and parentheses (``Adrenaline (Epinephrine)
    1mg/ml Injection``), so a naive "alnum else dash" map produces
    ``Adrenaline--Epinephrine--1mg-ml-Injectio`` - doubled dashes and a chopped
    word. Collapse runs, drop the trailing partial token, and fall back to
    ``item`` when nothing survives.
    """
    slug = re.sub(r'[^A-Za-z0-9]+', '-', str(text or '')).strip('-')
    if len(slug) > limit:
        slug = slug[:limit].rsplit('-', 1)[0] or slug[:limit]
    return slug.strip('-') or 'item'


class TraceBranchesView(APIView):
    """Warehouses a reader may trace, and how many items each holds.

    Powers the branch switcher. A scoped user gets exactly one row and
    ``locked: true``, so the control collapses to a lock chip instead of
    offering a choice the server would refuse.
    """

    permission_classes = [InventoryPermission]

    def get(self, request):
        from django.db.models import Count

        from pharmacy_profile.models import Branch

        forced = _forced_branch_id(request.user)

        counts = {
            row['branch_id']: row['items']
            for row in (MedicationStock.objects
                        .filter(is_active=True)
                        .values('branch_id')
                        .annotate(items=Count('id')))
        }

        branches = Branch.objects.all().order_by('-is_main', 'name')
        if forced:
            branches = branches.filter(id=forced)

        return Response({
            'branches': [
                {
                    'id': branch.id,
                    'name': branch.name,
                    'is_main': branch.is_main,
                    'items': counts.get(branch.id, 0),
                }
                for branch in branches
            ],
            'locked': bool(forced),
            'branch_id': forced,
        })


class TraceSearchView(APIView):
    """Items that can be traced — search by name, SKU, barcode or lot number."""

    permission_classes = [InventoryPermission]

    def get(self, request):
        from django.db.models import Q

        qs = MedicationStock.objects.all()
        forced = _forced_branch_id(request.user)
        branch_id = forced or _int(request.query_params.get('branch'))

        if forced:
            # Unassigned rows stay visible to a scoped user, mirroring
            # ``BranchScopedMixin`` - otherwise legacy stock disappears from the
            # picker for exactly the people who physically hold it.
            qs = qs.filter(Q(branch_id=forced) | Q(branch__isnull=True))
        elif branch_id:
            # An explicit choice by an admin means that warehouse only.
            qs = qs.filter(branch_id=branch_id)

        search = (request.query_params.get('q') or '').strip()
        limit = min(max(_int(request.query_params.get('limit'), 40), 1), 200)
        rows = traceability.trace_candidates(qs, search=search, limit=limit)
        return Response({
            'results': rows,
            'count': len(rows),
            'search': search,
            'branch_scope': {
                'locked': bool(forced),
                'branch_id': branch_id,
            },
        })


class StockTraceView(APIView):
    """The full life of one stock item, from receipt to customer.

    Branch-scoped: an item held at another warehouse answers 404.
    """

    permission_classes = [InventoryPermission]

    def get(self, request, pk):
        stock = _scoped_stock(request, pk)
        if not stock:
            return Response({'detail': 'Stock item not found.'}, status=404)

        date_from, date_to, days = _window(request)
        payload = traceability.trace_stock(
            stock, date_from=date_from, date_to=date_to, limit_days=days)
        payload['window'] = {
            'date_from': date_from.isoformat() if date_from else None,
            'date_to': date_to.isoformat() if date_to else None,
            'windowed': bool(date_from or date_to or days),
        }
        payload['branch_scope'] = _branch_scope(request, stock)
        _audit(request, 'trace_view', stock,
               description=f'Traced {stock.medication_name} '
                           f'({payload["summary"]["events"]} events) '
                           f'at {payload["branch_scope"]["branch"]}')
        return Response(payload)


class StockTraceExportView(APIView):
    """CSV export of the trace — the auditor's copy.

    Includes the custody digest so a recipient can confirm the file is the one
    that was generated, not one edited afterwards, and the branch scope so the
    sheet says which warehouse it covers.
    """

    permission_classes = [InventoryPermission]

    def get(self, request, pk):
        stock = _scoped_stock(request, pk)
        if not stock:
            return Response({'detail': 'Stock item not found.'}, status=404)

        date_from, date_to, days = _window(request)
        payload = traceability.trace_stock(
            stock, date_from=date_from, date_to=date_to, limit_days=days)
        summary = payload['summary']
        scope = _branch_scope(request, stock)

        buffer = io.StringIO()
        writer = csv.writer(buffer)

        writer.writerow(['AdhereMed item traceability record'])
        writer.writerow(['Item', summary['name']])
        writer.writerow(['SKU', summary['medication_id']])
        writer.writerow(['Warehouse', summary['branch']])
        writer.writerow(['Branch scope', scope['label']])
        writer.writerow(['Units received', summary['received']])
        writer.writerow(['Units sold', summary['sold']])
        writer.writerow(['Units on hand', summary['on_hand']])
        writer.writerow(['Custody digest', summary['custody_digest']])
        writer.writerow(['Generated',
                         timezone.localtime(timezone.now()).strftime(
                             '%Y-%m-%d %H:%M')])
        reconciliation = payload['reconciliation']
        writer.writerow(['Reconciliation',
                         reconciliation['verdict'],
                         reconciliation['residual']])
        writer.writerow([])

        writer.writerow(['#', 'Timestamp', 'Event', 'Reference', 'Batch',
                         'Warehouse', 'Party', 'Quantity', 'Balance',
                         'Detail', 'Custody hash'])
        for event in payload['events']:
            writer.writerow([
                event['seq'], event['at_display'], event['label'],
                event['reference'], event['batch_number'], event['branch'],
                event['party'], event['quantity'], event['balance'],
                event['detail'], event['hash'],
            ])

        writer.writerow([])
        writer.writerow(['Lots'])
        writer.writerow(['#', 'Batch', 'Received', 'Expiry', 'Supplier',
                         'Warehouse', 'Received qty', 'Sold', 'On hand',
                         'Sell-through %', 'Status'])
        for index, lot in enumerate(payload['batches'], start=1):
            writer.writerow([
                index, lot['batch_number'], lot['received_date'] or '',
                lot['expiry_date'] or '', lot['supplier'], lot['branch'],
                lot['received'], lot['sold'], lot['on_hand'],
                lot['sell_through_pct'], lot['status'],
            ])

        if payload['anomalies']:
            writer.writerow([])
            writer.writerow(['Integrity findings'])
            writer.writerow(['#', 'Severity', 'Finding', 'Detail'])
            for index, finding in enumerate(payload['anomalies'], start=1):
                writer.writerow([index, finding['severity'], finding['label'],
                                 finding['detail']])

        body = buffer.getvalue()
        buffer.close()

        stamp = timezone.localtime(timezone.now()).strftime('%Y%m%d-%H%M')
        safe = _slug(summary['name'])
        response = HttpResponse(
            body, content_type='text/csv; charset=utf-8')
        response['Content-Disposition'] = (
            f'attachment; filename="trace-{safe}-{stamp}.csv"')
        return response


class StockTracePdfView(APIView):
    """The trace as a signed-off chain-of-custody PDF.

    Unlike the BI pack this document has **no presentation switches at all**: an
    audit record that omits movements, or hides them behind a watermark, is not
    evidence. Everything the caller can influence is the date window, which is
    stated in the document itself.
    """

    permission_classes = [InventoryPermission]

    def get(self, request, pk):
        stock = _scoped_stock(request, pk)
        if not stock:
            return Response({'detail': 'Stock item not found.'}, status=404)

        date_from, date_to, days = _window(request)
        payload = traceability.trace_stock(
            stock, date_from=date_from, date_to=date_to, limit_days=days)
        payload['branch_scope'] = _branch_scope(request, stock)

        from config.pdf_branding import resolve_branding, resolve_palette
        try:
            logo_path, business_name = resolve_branding(request)
            palette = resolve_palette(request)
        except Exception:
            logo_path, business_name, palette = None, '', None

        tenant = getattr(request, 'tenant', None)
        org = {
            'name': getattr(tenant, 'name', '') or business_name or '',
            'address': getattr(tenant, 'address', '') or '',
            'city': getattr(tenant, 'city', '') or '',
            'country': getattr(tenant, 'country', '') or '',
            'phone': getattr(tenant, 'phone', '') or '',
            'email': getattr(tenant, 'email', '') or '',
            'website': getattr(tenant, 'website', '') or '',
        }
        business_name = org['name'] or business_name

        prepared_by = ''
        user = getattr(request, 'user', None)
        if user is not None and getattr(user, 'is_authenticated', False):
            prepared_by = (getattr(user, 'full_name', '')
                           or getattr(user, 'email', '') or '')

        from .base import _audit
        try:
            _audit(request, 'trace_export', stock,
                   description=f'Exported the custody PDF for '
                               f'{stock.medication_name} '
                               f'({payload["summary"]["events"]} movements) '
                               f'at {payload["branch_scope"]["branch"]}')
        except Exception:
            pass

        from ..reports.trace_render import render_trace_pdf
        try:
            body = render_trace_pdf(
                payload=payload, org=org, logo_path=logo_path,
                palette=palette, business_name=business_name,
                prepared_by=prepared_by, scope=payload['branch_scope'],
            )
        except Exception:
            import logging
            logging.getLogger(__name__).exception(
                'traceability PDF render failed')
            return Response({'detail': 'Could not build this document.'},
                            status=500)

        stamp = timezone.localtime(timezone.now()).strftime('%Y%m%d-%H%M')
        safe = _slug(payload['summary']['name'])
        response = HttpResponse(body, content_type='application/pdf')
        response['Content-Disposition'] = (
            f'attachment; filename="custody-{safe}-{stamp}.pdf"')
        response['X-Trace-Events'] = str(payload['summary']['events'])
        return response


# ── Batch (lot) trace ────────────────────────────────────────────────────
def _scoped_batches(request, lot_number):
    """Every ``StockBatch`` row for this lot the reader is allowed to see.

    A lot number is not unique per item or per warehouse, so this returns a
    list rather than one row. Empty means "not found *or* not visible" - the
    caller answers 404 either way, so the status code cannot be used to probe
    whether another warehouse holds a given lot.
    """
    from django.db.models import Q

    from ..models import StockBatch

    lot_number = (lot_number or '').strip()
    if not lot_number:
        return []

    qs = (StockBatch.objects
          .filter(batch_number__iexact=lot_number)
          .select_related('stock', 'stock__branch', 'stock__category', 'branch',
                          'supplier'))

    forced = _forced_branch_id(request.user)
    if forced:
        # A lot may be recorded with no batch branch, in which case the item's
        # branch is the physical location - check both or scoped users lose
        # their own stock.
        qs = qs.filter(Q(branch_id=forced)
                       | Q(branch__isnull=True, stock__branch_id=forced)
                       | Q(branch__isnull=True, stock__branch__isnull=True))
    return list(qs.order_by('branch_id', 'stock__medication_name'))


class BatchTraceSearchView(APIView):
    """Lots that can be traced — aggregated across items and warehouses."""

    permission_classes = [InventoryPermission]

    def get(self, request):
        from django.db.models import Q

        from ..models import StockBatch

        qs = StockBatch.objects.all()
        forced = _forced_branch_id(request.user)
        branch_id = forced or _int(request.query_params.get('branch'))

        if forced:
            qs = qs.filter(Q(branch_id=forced)
                           | Q(branch__isnull=True, stock__branch_id=forced)
                           | Q(branch__isnull=True, stock__branch__isnull=True))
        elif branch_id:
            qs = qs.filter(Q(branch_id=branch_id) | Q(branch__isnull=True))

        search = (request.query_params.get('q') or '').strip()
        limit = min(max(_int(request.query_params.get('limit'), 40), 1), 200)
        rows = traceability.batch_candidates(qs, search=search, limit=limit)
        return Response({
            'results': rows,
            'count': len(rows),
            'search': search,
            'branch_scope': {'locked': bool(forced), 'branch_id': branch_id},
        })


class BatchTraceView(APIView):
    """The whole life of one lot number: receipt → warehouse moves → recipient.

    This is the recall question, not the catalogue question, so the payload
    leads with *exposure* (who received units) rather than stock levels.
    """

    permission_classes = [InventoryPermission]

    def get(self, request):
        lot = (request.query_params.get('lot') or '').strip()
        if not lot:
            return Response({'detail': 'A lot number is required.'},
                            status=400)

        batches = _scoped_batches(request, lot)
        if not batches:
            return Response({'detail': 'No lot with that number is visible.'},
                            status=404)

        date_from, date_to, days = _window(request)
        payload = traceability.trace_batch(
            lot, batches, date_from=date_from, date_to=date_to,
            limit_days=days)
        payload['window'] = {
            'date_from': date_from.isoformat() if date_from else None,
            'date_to': date_to.isoformat() if date_to else None,
            'windowed': bool(date_from or date_to or days),
        }
        forced = _forced_branch_id(request.user)
        payload['branch_scope'] = {
            'locked': bool(forced),
            'label': (f"Locked to the reader's warehouse"
                      if forced else 'All warehouses'),
        }
        _audit(request, 'trace_view', batches[0].stock,
               description=(f'Traced lot {lot} '
                            f'({payload["summary"]["events"]} movements, '
                            f'{payload["summary"]["units_downstream"]} units '
                            f'downstream)'))
        return Response(payload)


class BatchTraceExportView(APIView):
    """CSV of the lot trace — the recall worklist.

    Sectioned so it can be handed to someone who does not have the app: the
    positions sheet is for the warehouse, the recipients sheet is the call-list.
    """

    permission_classes = [InventoryPermission]

    def get(self, request):
        lot = (request.query_params.get('lot') or '').strip()
        if not lot:
            return Response({'detail': 'A lot number is required.'},
                            status=400)

        batches = _scoped_batches(request, lot)
        if not batches:
            return Response({'detail': 'No lot with that number is visible.'},
                            status=404)

        date_from, date_to, days = _window(request)
        payload = traceability.trace_batch(
            lot, batches, date_from=date_from, date_to=date_to,
            limit_days=days)
        summary = payload['summary']
        forced = _forced_branch_id(request.user)

        buffer = io.StringIO()
        writer = csv.writer(buffer)

        writer.writerow(['AdhereMed batch traceability record'])
        writer.writerow(['Lot', summary['batch_number']])
        writer.writerow(['Items', ', '.join(summary['item_names']) or '-'])
        writer.writerow(['Warehouses', ', '.join(summary['branch_names']) or '-'])
        writer.writerow(['Branch scope',
                         'Locked to the reader\'s warehouse' if forced
                         else 'All warehouses'])
        writer.writerow(['Suppliers', ', '.join(summary['suppliers']) or '-'])
        writer.writerow(['Expiry', summary['expiry_date'] or '-'])
        writer.writerow(['Units received', summary['received']])
        writer.writerow(['Units sold / dispensed', summary['sold']])
        writer.writerow(['Units transferred out', summary['moved_out']])
        writer.writerow(['Units on hand', summary['on_hand']])
        writer.writerow(['Units downstream', summary['units_downstream']])
        writer.writerow(['Recipients', summary['recipients']])
        writer.writerow(['Custody digest', summary['custody_digest']])
        writer.writerow(['Generated',
                         timezone.localtime(timezone.now()).strftime(
                             '%Y-%m-%d %H:%M')])
        reconciliation = payload['reconciliation']
        writer.writerow(['Reconciliation', reconciliation['verdict'],
                         reconciliation['residual']])
        writer.writerow([])

        writer.writerow(['Positions'])
        writer.writerow(['#', 'Item', 'SKU', 'Warehouse', 'Received',
                         'Expiry', 'Supplier', 'In', 'Sold', 'Moved',
                         'On hand', 'Sell-through %', 'Status'])
        for index, row in enumerate(payload['positions'], start=1):
            writer.writerow([
                index, row['item'], row['medication_id'], row['branch'],
                row['received_date'] or '', row['expiry_date'] or '',
                row['supplier'], row['received'], row['sold'], row['moved'],
                row['on_hand'], row['sell_through_pct'], row['status'],
            ])

        writer.writerow([])
        writer.writerow(['Movements'])
        writer.writerow(['#', 'Timestamp', 'Event', 'Reference', 'Item',
                         'Warehouse', 'Party', 'Quantity', 'Balance',
                         'Detail', 'Custody hash'])
        for event in payload['events']:
            writer.writerow([
                event['seq'], event['at_display'], event['label'],
                event['reference'], event.get('item') or '', event['branch'],
                event['party'], event['quantity'], event['balance'],
                event['detail'], event['hash'],
            ])

        if payload['exposure']:
            writer.writerow([])
            writer.writerow(['Recipients — recall call-list'])
            writer.writerow(['#', 'Recipient', 'Channel', 'Units',
                             'Last movement', 'References'])
            for index, row in enumerate(payload['exposure'], start=1):
                writer.writerow([
                    index, row['party'], row['kind_label'], row['quantity'],
                    row['last'], ' '.join(row['references']),
                ])

        if payload['anomalies']:
            writer.writerow([])
            writer.writerow(['Integrity findings'])
            writer.writerow(['#', 'Severity', 'Finding', 'Detail'])
            for index, finding in enumerate(payload['anomalies'], start=1):
                writer.writerow([index, finding['severity'], finding['label'],
                                 finding['detail']])

        body = buffer.getvalue()
        buffer.close()

        stamp = timezone.localtime(timezone.now()).strftime('%Y%m%d-%H%M')
        safe = _slug(lot)
        response = HttpResponse(body, content_type='text/csv; charset=utf-8')
        response['Content-Disposition'] = (
            f'attachment; filename="batch-{safe}-{stamp}.csv"')
        return response


class BatchTracePdfView(APIView):
    """The lot trace as a signed-off recall dossier."""

    permission_classes = [InventoryPermission]

    def get(self, request):
        lot = (request.query_params.get('lot') or '').strip()
        if not lot:
            return Response({'detail': 'A lot number is required.'},
                            status=400)

        batches = _scoped_batches(request, lot)
        if not batches:
            return Response({'detail': 'No lot with that number is visible.'},
                            status=404)

        date_from, date_to, days = _window(request)
        payload = traceability.trace_batch(
            lot, batches, date_from=date_from, date_to=date_to,
            limit_days=days)

        from config.pdf_branding import resolve_branding, resolve_palette
        try:
            logo_path, business_name = resolve_branding(request)
            palette = resolve_palette(request)
        except Exception:
            logo_path, business_name, palette = None, '', None

        tenant = getattr(request, 'tenant', None)
        org = {
            'name': getattr(tenant, 'name', '') or business_name or '',
            'address': getattr(tenant, 'address', '') or '',
            'city': getattr(tenant, 'city', '') or '',
            'country': getattr(tenant, 'country', '') or '',
            'phone': getattr(tenant, 'phone', '') or '',
            'email': getattr(tenant, 'email', '') or '',
            'website': getattr(tenant, 'website', '') or '',
        }
        business_name = org['name'] or business_name

        prepared_by = ''
        user = getattr(request, 'user', None)
        if user is not None and getattr(user, 'is_authenticated', False):
            prepared_by = (getattr(user, 'full_name', '')
                           or getattr(user, 'email', '') or '')

        forced = _forced_branch_id(request.user)
        scope = {
            'locked': bool(forced),
            'label': ('Locked to the reader\'s warehouse' if forced
                      else 'All warehouses'),
        }

        try:
            _audit(request, 'trace_export', batches[0].stock,
                   description=(f'Exported the batch dossier for lot {lot}'))
        except Exception:
            pass

        from ..reports.batch_render import render_batch_pdf
        try:
            body = render_batch_pdf(
                payload=payload, org=org, logo_path=logo_path,
                palette=palette, business_name=business_name,
                prepared_by=prepared_by, scope=scope,
            )
        except Exception:
            import logging
            logging.getLogger(__name__).exception(
                'batch PDF render failed')
            return Response({'detail': 'Could not build this document.'},
                            status=500)

        stamp = timezone.localtime(timezone.now()).strftime('%Y%m%d-%H%M')
        safe = _slug(lot)
        response = HttpResponse(body, content_type='application/pdf')
        response['Content-Disposition'] = (
            f'attachment; filename="batch-{safe}-{stamp}.pdf"')
        response['X-Trace-Events'] = str(payload['summary']['events'])
        return response

