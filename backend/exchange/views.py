from decimal import Decimal
from datetime import timedelta

from django.db import connection, models
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response

from tenants.models import Tenant
from .models import (
    PrescriptionExchange, PharmacyQuote, PatientOrder, LabOrderExchange,
    PatientLabRecord,
)
from .serializers import (
    PrescriptionExchangeSerializer,
    PharmacyQuoteSerializer,
    PatientOrderSerializer,
    LabOrderExchangeSerializer,
    PatientLabRecordSerializer,
)


class ExchangeListCreateView(generics.ListCreateAPIView):
    serializer_class = PrescriptionExchangeSerializer
    filterset_fields = ['status']

    def get_queryset(self):
        user = self.request.user
        return PrescriptionExchange.objects.filter(patient_user_id=user.id)

    def perform_create(self, serializer):
        exchange = serializer.save(patient_user_id=self.request.user.id)
        _generate_quotes_for_exchange(exchange)


class ExchangeDetailView(generics.RetrieveAPIView):
    serializer_class = PrescriptionExchangeSerializer

    def get_queryset(self):
        return PrescriptionExchange.objects.filter(patient_user_id=self.request.user.id)


class QuoteListView(generics.ListAPIView):
    serializer_class = PharmacyQuoteSerializer

    def get_queryset(self):
        return PharmacyQuote.objects.filter(
            exchange_id=self.kwargs['exchange_id'],
            exchange__patient_user_id=self.request.user.id,
        )


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def accept_quote(request, exchange_id, quote_id):
    """Patient accepts a pharmacy quote."""
    try:
        exchange = PrescriptionExchange.objects.get(
            id=exchange_id, patient_user_id=request.user.id,
        )
    except PrescriptionExchange.DoesNotExist:
        return Response({'detail': 'Exchange not found.'}, status=status.HTTP_404_NOT_FOUND)

    try:
        quote = PharmacyQuote.objects.get(id=quote_id, exchange=exchange)
    except PharmacyQuote.DoesNotExist:
        return Response({'detail': 'Quote not found.'}, status=status.HTTP_404_NOT_FOUND)

    if exchange.status not in (PrescriptionExchange.Status.PENDING, PrescriptionExchange.Status.QUOTED):
        return Response({'detail': 'Exchange is no longer accepting quotes.'}, status=status.HTTP_400_BAD_REQUEST)

    # Accept this quote, reject all others
    quote.status = PharmacyQuote.Status.ACCEPTED
    quote.save(update_fields=['status'])

    exchange.quotes.exclude(id=quote_id).update(status=PharmacyQuote.Status.REJECTED)
    exchange.status = PrescriptionExchange.Status.ACCEPTED
    exchange.selected_pharmacy_tenant_id = quote.pharmacy_tenant_id
    exchange.save(update_fields=['status', 'selected_pharmacy_tenant_id'])

    return Response(PrescriptionExchangeSerializer(exchange).data)


def _generate_quotes_for_exchange(exchange):
    """Query all pharmacy tenants for medication pricing and create quotes."""
    pharmacy_tenants = Tenant.objects.filter(type='pharmacy', is_active=True)
    items = exchange.items  # JSON list: [{medication_id, medication_name, quantity, ...}]

    for tenant in pharmacy_tenants:
        try:
            items_pricing = []
            subtotal = Decimal('0.00')
            all_available = True

            # Switch to tenant schema to query inventory
            with connection.cursor() as cursor:
                cursor.execute(f'SET search_path TO "{tenant.schema_name}"')

                for item in items:
                    med_id = item.get('medication_id')
                    qty = int(item.get('quantity', 1))

                    if not med_id:
                        all_available = False
                        continue

                    cursor.execute(
                        'SELECT id, medication_name, selling_price FROM inventory_medicationstock '
                        'WHERE medication_id = %s AND is_active = TRUE',
                        [med_id],
                    )
                    row = cursor.fetchone()
                    if row:
                        # Check stock availability
                        cursor.execute(
                            'SELECT COALESCE(SUM(quantity_remaining), 0) '
                            'FROM inventory_stockbatch WHERE stock_id = %s AND quantity_remaining > 0 '
                            'AND expiry_date > CURRENT_DATE',
                            [row[0]],
                        )
                        available_qty = cursor.fetchone()[0]
                        if available_qty < qty:
                            all_available = False
                            continue

                        unit_price = Decimal(str(row[2]))
                        line_total = unit_price * qty
                        items_pricing.append({
                            'medication_id': med_id,
                            'name': row[1],
                            'quantity': qty,
                            'unit_price': str(unit_price),
                            'total': str(line_total),
                        })
                        subtotal += line_total
                    else:
                        all_available = False

                # Reset search path
                cursor.execute('SET search_path TO "public"')

            if items_pricing and all_available:
                PharmacyQuote.objects.create(
                    exchange=exchange,
                    pharmacy_tenant_id=tenant.id,
                    pharmacy_name=tenant.name,
                    items_pricing=items_pricing,
                    subtotal=subtotal,
                    total_cost=subtotal,
                    valid_until=timezone.now() + timedelta(hours=24),
                    status=PharmacyQuote.Status.QUOTED,
                )
        except Exception:
            # If a pharmacy query fails, skip it
            try:
                with connection.cursor() as cursor:
                    cursor.execute('SET search_path TO "public"')
            except Exception:
                pass
            continue

    # Update exchange status if we got quotes
    if exchange.quotes.exists():
        exchange.status = PrescriptionExchange.Status.QUOTED
        exchange.save(update_fields=['status'])


def _generate_quote_for_pharmacy(exchange, tenant):
    """Generate a quote from a specific pharmacy tenant for an exchange."""
    items = exchange.items

    try:
        items_pricing = []
        subtotal = Decimal('0.00')

        with connection.cursor() as cursor:
            cursor.execute(f'SET search_path TO "{tenant.schema_name}"')

            for item in items:
                med_id = item.get('medication_id')
                med_name = item.get('medication_name') or item.get('custom_medication_name') or 'Unknown'
                qty = int(item.get('quantity', 1))

                if not med_id:
                    items_pricing.append({
                        'medication_id': None,
                        'name': med_name,
                        'quantity': qty,
                        'unit_price': '0',
                        'total': '0',
                        'available': False,
                        'reason': 'No medication reference',
                    })
                    continue

                cursor.execute(
                    'SELECT id, medication_name, selling_price FROM inventory_medicationstock '
                    'WHERE medication_id = %s AND is_active = TRUE',
                    [med_id],
                )
                row = cursor.fetchone()
                if row:
                    cursor.execute(
                        'SELECT COALESCE(SUM(quantity_remaining), 0) '
                        'FROM inventory_stockbatch WHERE stock_id = %s AND quantity_remaining > 0 '
                        'AND expiry_date > CURRENT_DATE',
                        [row[0]],
                    )
                    available_qty = cursor.fetchone()[0]
                    if available_qty < qty:
                        items_pricing.append({
                            'medication_id': med_id,
                            'name': row[1],
                            'quantity': qty,
                            'unit_price': str(row[2]),
                            'total': '0',
                            'available': False,
                            'reason': f'Insufficient stock ({available_qty} available)',
                        })
                        continue

                    unit_price = Decimal(str(row[2]))
                    line_total = unit_price * qty
                    items_pricing.append({
                        'medication_id': med_id,
                        'name': row[1],
                        'quantity': qty,
                        'unit_price': str(unit_price),
                        'total': str(line_total),
                        'available': True,
                    })
                    subtotal += line_total
                else:
                    items_pricing.append({
                        'medication_id': med_id,
                        'name': med_name,
                        'quantity': qty,
                        'unit_price': '0',
                        'total': '0',
                        'available': False,
                        'reason': 'Not stocked',
                    })

            cursor.execute('SET search_path TO "public"')

        if not items_pricing:
            return None, 'No medications could be processed for this pharmacy.'

        # Check if quote already exists for this pharmacy
        existing = PharmacyQuote.objects.filter(
            exchange=exchange,
            pharmacy_tenant_id=tenant.id,
        ).first()
        if existing:
            # Update existing quote
            existing.items_pricing = items_pricing
            existing.subtotal = subtotal
            existing.total_cost = subtotal
            existing.valid_until = timezone.now() + timedelta(hours=24)
            existing.status = PharmacyQuote.Status.QUOTED
            existing.save()
            return existing, None

        quote = PharmacyQuote.objects.create(
            exchange=exchange,
            pharmacy_tenant_id=tenant.id,
            pharmacy_name=tenant.name,
            items_pricing=items_pricing,
            subtotal=subtotal,
            total_cost=subtotal,
            valid_until=timezone.now() + timedelta(hours=24),
            status=PharmacyQuote.Status.QUOTED,
        )
        return quote, None

    except Exception as e:
        try:
            with connection.cursor() as cursor:
                cursor.execute('SET search_path TO "public"')
        except Exception:
            pass
        return None, f'Error generating quote: {str(e)}'


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def generate_quote(request, exchange_id):
    """Patient requests a quote from a specific pharmacy."""
    try:
        exchange = PrescriptionExchange.objects.get(
            id=exchange_id, patient_user_id=request.user.id,
        )
    except PrescriptionExchange.DoesNotExist:
        return Response({'detail': 'Exchange not found.'}, status=status.HTTP_404_NOT_FOUND)

    if exchange.status not in (PrescriptionExchange.Status.PENDING, PrescriptionExchange.Status.QUOTED):
        return Response(
            {'detail': 'Exchange is no longer accepting quotes.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    pharmacy_id = request.data.get('pharmacy_tenant_id')
    if not pharmacy_id:
        return Response(
            {'detail': 'pharmacy_tenant_id is required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        tenant = Tenant.objects.get(id=pharmacy_id, type='pharmacy', is_active=True)
    except Tenant.DoesNotExist:
        return Response({'detail': 'Pharmacy not found.'}, status=status.HTTP_404_NOT_FOUND)

    quote, error = _generate_quote_for_pharmacy(exchange, tenant)
    if error:
        return Response({'detail': error}, status=status.HTTP_400_BAD_REQUEST)

    # Update exchange status
    if exchange.status == PrescriptionExchange.Status.PENDING:
        exchange.status = PrescriptionExchange.Status.QUOTED
        exchange.save(update_fields=['status'])

    return Response(PharmacyQuoteSerializer(quote).data, status=status.HTTP_201_CREATED)


# ─── Pharmacy Store (Patient-facing) ───────────────────────────────────────


class _StandardPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def pharmacy_list(request):
    """List all active pharmacy tenants with profile info."""
    pharmacies = Tenant.objects.filter(type='pharmacy', is_active=True).values(
        'id', 'name', 'schema_name', 'address', 'city', 'phone', 'email',
    )
    results = []
    for ph in pharmacies:
        profile = {}
        try:
            with connection.cursor() as cursor:
                cursor.execute(f'SET search_path TO "{ph["schema_name"]}"')
                cursor.execute(
                    'SELECT delivery_radius_km, delivery_fee, accepts_insurance, '
                    'description, operating_hours, services '
                    'FROM pharmacy_profile_pharmacydetail LIMIT 1'
                )
                row = cursor.fetchone()
                if row:
                    import json
                    profile = {
                        'delivery_radius_km': float(row[0] or 0),
                        'delivery_fee': float(row[1] or 0),
                        'accepts_insurance': row[2],
                        'description': row[3] or '',
                        'operating_hours': row[4] if isinstance(row[4], dict) else {},
                        'services': row[5] if isinstance(row[5], list) else [],
                    }
                # Count available products
                cursor.execute(
                    'SELECT COUNT(*) FROM inventory_medicationstock WHERE is_active = TRUE'
                )
                profile['product_count'] = cursor.fetchone()[0]
                cursor.execute('SET search_path TO "public"')
        except Exception:
            try:
                with connection.cursor() as cursor:
                    cursor.execute('SET search_path TO "public"')
            except Exception:
                pass

        results.append({
            'id': ph['id'],
            'name': ph['name'],
            'address': ph['address'],
            'city': ph['city'],
            'phone': ph['phone'],
            'email': ph['email'],
            **profile,
        })

    return Response(results)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def pharmacy_products(request, pharmacy_id):
    """List products from a specific pharmacy with pricing and stock info."""
    try:
        tenant = Tenant.objects.get(id=pharmacy_id, type='pharmacy', is_active=True)
    except Tenant.DoesNotExist:
        return Response({'detail': 'Pharmacy not found.'}, status=status.HTTP_404_NOT_FOUND)

    search = request.query_params.get('search', '')
    category = request.query_params.get('category', '')
    page = int(request.query_params.get('page', 1))
    page_size = min(int(request.query_params.get('page_size', 20)), 100)
    offset = (page - 1) * page_size

    products = []
    total_count = 0
    categories = []

    try:
        with connection.cursor() as cursor:
            cursor.execute(f'SET search_path TO "{tenant.schema_name}"')

            # Get categories for filter
            cursor.execute(
                'SELECT id, name FROM inventory_category ORDER BY name'
            )
            categories = [{'id': r[0], 'name': r[1]} for r in cursor.fetchall()]

            # Build query
            where_clauses = ['ms.is_active = TRUE']
            params = []

            if search:
                where_clauses.append('LOWER(ms.medication_name) LIKE LOWER(%s)')
                params.append(f'%{search}%')

            if category:
                where_clauses.append('ms.category_id = %s')
                params.append(int(category))

            where_sql = ' AND '.join(where_clauses)

            # Count
            cursor.execute(
                f'SELECT COUNT(*) FROM inventory_medicationstock ms WHERE {where_sql}',
                params,
            )
            total_count = cursor.fetchone()[0]

            # Fetch products with stock
            cursor.execute(
                f'''SELECT ms.id, ms.medication_id, ms.medication_name,
                       ms.selling_price, c.name as category_name, u.name as unit_name,
                       COALESCE(
                           (SELECT SUM(sb.quantity_remaining)
                            FROM inventory_stockbatch sb
                            WHERE sb.stock_id = ms.id
                              AND sb.quantity_remaining > 0
                              AND sb.expiry_date > CURRENT_DATE), 0
                       ) as available_qty
                FROM inventory_medicationstock ms
                LEFT JOIN inventory_category c ON c.id = ms.category_id
                LEFT JOIN inventory_unit u ON u.id = ms.unit_id
                WHERE {where_sql}
                ORDER BY ms.medication_name
                LIMIT %s OFFSET %s''',
                params + [page_size, offset],
            )
            columns = [col[0] for col in cursor.description]
            for row in cursor.fetchall():
                product = dict(zip(columns, row))
                product['selling_price'] = float(product['selling_price'] or 0)
                product['in_stock'] = product['available_qty'] > 0
                products.append(product)

            cursor.execute('SET search_path TO "public"')
    except Exception:
        try:
            with connection.cursor() as cursor:
                cursor.execute('SET search_path TO "public"')
        except Exception:
            pass
        return Response({'detail': 'Error fetching products.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    return Response({
        'count': total_count,
        'next': f'?page={page + 1}' if offset + page_size < total_count else None,
        'previous': f'?page={page - 1}' if page > 1 else None,
        'pharmacy_name': tenant.name,
        'categories': categories,
        'results': products,
    })


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def create_patient_order(request):
    """Patient places a medicine order to a pharmacy."""
    user = request.user
    data = request.data

    pharmacy_id = data.get('pharmacy_tenant_id')
    items = data.get('items', [])
    delivery_address = data.get('delivery_address', '')
    payment_method = data.get('payment_method', 'cash')
    notes = data.get('notes', '')

    if not pharmacy_id or not items:
        return Response(
            {'detail': 'pharmacy_tenant_id and items are required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        tenant = Tenant.objects.get(id=pharmacy_id, type='pharmacy', is_active=True)
    except Tenant.DoesNotExist:
        return Response({'detail': 'Pharmacy not found.'}, status=status.HTTP_404_NOT_FOUND)

    # Validate items and compute prices from actual pharmacy inventory
    order_items = []
    subtotal = Decimal('0.00')
    delivery_fee = Decimal('0.00')

    try:
        with connection.cursor() as cursor:
            cursor.execute(f'SET search_path TO "{tenant.schema_name}"')

            # Get delivery fee
            cursor.execute(
                'SELECT delivery_fee FROM pharmacy_profile_pharmacydetail LIMIT 1'
            )
            row = cursor.fetchone()
            if row and row[0] and delivery_address:
                delivery_fee = Decimal(str(row[0]))

            for item in items:
                med_name = item.get('medication_name', '')
                qty = int(item.get('quantity', 1))

                if not med_name or qty < 1:
                    cursor.execute('SET search_path TO "public"')
                    return Response(
                        {'detail': f'Invalid item: {med_name}'},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                # Lookup by name
                cursor.execute(
                    'SELECT id, medication_name, selling_price FROM inventory_medicationstock '
                    'WHERE LOWER(medication_name) = LOWER(%s) AND is_active = TRUE',
                    [med_name],
                )
                stock_row = cursor.fetchone()
                if not stock_row:
                    cursor.execute('SET search_path TO "public"')
                    return Response(
                        {'detail': f'"{med_name}" not available at this pharmacy.'},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                # Check stock
                cursor.execute(
                    'SELECT COALESCE(SUM(quantity_remaining), 0) '
                    'FROM inventory_stockbatch WHERE stock_id = %s '
                    'AND quantity_remaining > 0 AND expiry_date > CURRENT_DATE',
                    [stock_row[0]],
                )
                available = cursor.fetchone()[0]
                if available < qty:
                    cursor.execute('SET search_path TO "public"')
                    return Response(
                        {'detail': f'Only {available} of "{med_name}" in stock.'},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                unit_price = Decimal(str(stock_row[2]))
                line_total = unit_price * qty
                order_items.append({
                    'medication_name': stock_row[1],
                    'quantity': qty,
                    'unit_price': str(unit_price),
                    'total': str(line_total),
                })
                subtotal += line_total

            cursor.execute('SET search_path TO "public"')
    except Exception as e:
        try:
            with connection.cursor() as cursor:
                cursor.execute('SET search_path TO "public"')
        except Exception:
            pass
        return Response({'detail': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    total = subtotal + delivery_fee
    patient_name = f'{user.first_name} {user.last_name}'.strip() or user.email

    order = PatientOrder.objects.create(
        patient_user_id=user.id,
        patient_name=patient_name,
        patient_phone=getattr(user, 'phone', ''),
        pharmacy_tenant_id=tenant.id,
        pharmacy_name=tenant.name,
        items=order_items,
        subtotal=subtotal,
        delivery_fee=delivery_fee,
        total=total,
        delivery_address=delivery_address,
        payment_method=payment_method,
        notes=notes,
    )

    return Response(PatientOrderSerializer(order).data, status=status.HTTP_201_CREATED)


class PatientOrderListView(generics.ListAPIView):
    serializer_class = PatientOrderSerializer

    def get_queryset(self):
        return PatientOrder.objects.filter(patient_user_id=self.request.user.id)


class PatientOrderDetailView(generics.RetrieveAPIView):
    serializer_class = PatientOrderSerializer

    def get_queryset(self):
        return PatientOrder.objects.filter(patient_user_id=self.request.user.id)


# ─── Pharmacy-side Order Management ───────────────────────────────────────


class PharmacyOrderListView(generics.ListAPIView):
    """Orders placed to the pharmacy of the authenticated staff user."""
    serializer_class = PatientOrderSerializer
    pagination_class = _StandardPagination

    def get_queryset(self):
        tenant = getattr(self.request.user, 'tenant', None)
        if not tenant:
            return PatientOrder.objects.none()
        qs = PatientOrder.objects.filter(pharmacy_tenant_id=tenant.id)
        status_filter = self.request.query_params.get('status')
        search = self.request.query_params.get('search')
        if status_filter:
            qs = qs.filter(status=status_filter)
        if search:
            qs = qs.filter(
                models.Q(order_number__icontains=search)
                | models.Q(patient_name__icontains=search)
            )
        return qs


@api_view(['PATCH'])
@permission_classes([permissions.IsAuthenticated])
def pharmacy_update_order_status(request, pk):
    """Pharmacy staff updates order status."""
    tenant = getattr(request.user, 'tenant', None)
    if not tenant:
        return Response({'detail': 'No tenant.'}, status=status.HTTP_403_FORBIDDEN)

    try:
        order = PatientOrder.objects.get(pk=pk, pharmacy_tenant_id=tenant.id)
    except PatientOrder.DoesNotExist:
        return Response({'detail': 'Order not found.'}, status=status.HTTP_404_NOT_FOUND)

    new_status = request.data.get('status')
    valid_statuses = [c[0] for c in PatientOrder.Status.choices]
    if new_status not in valid_statuses:
        return Response(
            {'detail': f'Invalid status. Choose from: {", ".join(valid_statuses)}'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    order.status = new_status
    order.save(update_fields=['status', 'updated_at'])
    return Response(PatientOrderSerializer(order).data)


class LabExchangeListCreateView(generics.ListCreateAPIView):
    """
    Hospital/doctor staff POST to create a lab exchange request.
    Lab tenants GET to list pending requests.
    """
    serializer_class = LabOrderExchangeSerializer
    pagination_class = _StandardPagination

    def get_queryset(self):
        user = self.request.user
        tenant = getattr(user, 'tenant', None)
        qs = LabOrderExchange.objects.all()

        # Lab tenants see orders sent to them OR unclaimed pending orders
        if tenant and tenant.type == 'lab':
            qs = qs.filter(
                models.Q(lab_tenant_id=tenant.id) | models.Q(status='pending')
            )
        # Hospital tenants see orders they sent
        elif tenant and tenant.type == 'hospital':
            qs = qs.filter(source_tenant_id=tenant.id)
        # Doctors may see orders they placed
        elif user.role in ('doctor', 'clinical_officer', 'dentist'):
            qs = qs.filter(ordering_doctor_user_id=user.id)

        # Filtering
        status_filter = self.request.query_params.get('status')
        priority = self.request.query_params.get('priority')
        search = self.request.query_params.get('search')

        if status_filter:
            qs = qs.filter(status=status_filter)
        if priority:
            qs = qs.filter(priority=priority)
        if search:
            qs = qs.filter(
                models.Q(patient_name__icontains=search)
                | models.Q(ordering_doctor_name__icontains=search)
                | models.Q(source_tenant_name__icontains=search)
            )
        return qs

    def perform_create(self, serializer):
        user = self.request.user
        tenant = getattr(user, 'tenant', None)
        extra = {}
        if tenant:
            extra['source_tenant_id'] = tenant.id
            extra['source_tenant_name'] = tenant.name
        extra['ordering_doctor_user_id'] = user.id
        extra['ordering_doctor_name'] = f'{user.first_name} {user.last_name}'.strip()
        serializer.save(**extra)


class LabExchangeDetailView(generics.RetrieveUpdateAPIView):
    """Retrieve or update a lab exchange (e.g. accept, add results)."""
    serializer_class = LabOrderExchangeSerializer

    def get_queryset(self):
        return LabOrderExchange.objects.all()


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def lab_exchange_accept(request, pk):
    """Lab tenant accepts a pending lab order exchange."""
    user = request.user
    tenant = getattr(user, 'tenant', None)

    if not tenant or tenant.type != 'lab':
        return Response(
            {'detail': 'Only lab tenants can accept lab orders.'},
            status=status.HTTP_403_FORBIDDEN,
        )

    try:
        exchange = LabOrderExchange.objects.get(id=pk)
    except LabOrderExchange.DoesNotExist:
        return Response(
            {'detail': 'Lab order not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if exchange.status != 'pending':
        return Response(
            {'detail': 'This order has already been accepted or is not pending.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    exchange.lab_tenant_id = tenant.id
    exchange.lab_tenant_name = tenant.name
    exchange.status = LabOrderExchange.Status.ACCEPTED
    exchange.save(update_fields=['lab_tenant_id', 'lab_tenant_name', 'status', 'updated_at'])

    return Response(LabOrderExchangeSerializer(exchange).data)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def lab_exchange_submit_results(request, pk):
    """Lab submits results for an accepted lab order."""
    user = request.user
    tenant = getattr(user, 'tenant', None)

    if not tenant or tenant.type != 'lab':
        return Response(
            {'detail': 'Only lab tenants can submit results.'},
            status=status.HTTP_403_FORBIDDEN,
        )

    try:
        exchange = LabOrderExchange.objects.get(id=pk, lab_tenant_id=tenant.id)
    except LabOrderExchange.DoesNotExist:
        return Response(
            {'detail': 'Lab order not found or not assigned to your lab.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if exchange.status not in ('accepted', 'sample_collected', 'processing'):
        return Response(
            {'detail': 'Cannot submit results for this order status.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    results = request.data.get('results')
    if not results:
        return Response(
            {'detail': 'Results data is required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    exchange.results = results
    exchange.status = LabOrderExchange.Status.COMPLETED
    exchange.save(update_fields=['results', 'status', 'updated_at'])

    return Response(LabOrderExchangeSerializer(exchange).data)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def lab_dashboard_stats(request):
    """Dashboard stats for a lab tenant."""
    user = request.user
    tenant = getattr(user, 'tenant', None)

    if not tenant or tenant.type != 'lab':
        return Response(
            {'detail': 'Only lab tenants can access lab dashboard.'},
            status=status.HTTP_403_FORBIDDEN,
        )

    from django.utils import timezone
    today = timezone.now().date()

    all_orders = LabOrderExchange.objects.filter(
        models.Q(lab_tenant_id=tenant.id) | models.Q(status='pending')
    )
    my_orders = LabOrderExchange.objects.filter(lab_tenant_id=tenant.id)

    stats = {
        'pending_requests': all_orders.filter(status='pending').count(),
        'accepted_orders': my_orders.filter(status='accepted').count(),
        'processing': my_orders.filter(status='processing').count(),
        'sample_collected': my_orders.filter(status='sample_collected').count(),
        'completed_today': my_orders.filter(
            status='completed', updated_at__date=today
        ).count(),
        'completed_total': my_orders.filter(status='completed').count(),
        'urgent_orders': all_orders.filter(
            priority__in=['urgent', 'stat'],
            status__in=['pending', 'accepted', 'sample_collected', 'processing'],
        ).count(),
        'home_collections': all_orders.filter(
            is_home_collection=True,
            status__in=['pending', 'accepted', 'sample_collected'],
        ).count(),
    }
    return Response(stats)


# ─── Clinic → Patient lab sharing ─────────────────────────────────────────
#
# The patient dashboard has no access to a clinic schema, so clinic lab orders
# are mirrored into ``exchange.PatientLabRecord`` (public schema) as they move
# through the benchmark. The patient portal reads only its own rows.

#: Internal clinic status → the simpler stage the patient is shown.
_PATIENT_STAGE = PatientLabRecord.CLINIC_STAGE_MAP

#: Roles allowed to publish a lab record into a patient's portal. Patients are
#: deliberately absent — sharing is a clinical action, not a self-service one.
CAN_SHARE_LAB_ROLES = {
    'super_admin', 'tenant_admin', 'admin', 'doctor', 'clinical_officer',
    'dentist', 'nurse', 'midwife', 'lab_tech', 'radiologist', 'receptionist',
    'homecare_admin',
}


def _patient_record_payload(record, tenant=None):
    """Normalise one record from a clinic push.

    Only these fields are accepted from the caller — anything else (another
    patient's id, a foreign tenant, the verified flag of someone else) is
    derived server-side so a clinic cannot write into another patient's chart.
    """
    data = {k: v for k, v in record.items() if k in {
        'source_order_id', 'order_ref', 'patient_user_id', 'patient_name',
        'patient_number', 'tests', 'priority', 'clinical_notes',
        'ordered_by_name', 'clinic_site_name', 'is_home_collection',
        'requested_on', 'raw_status', 'stage', 'stage_updated_at',
        'results', 'result_summary', 'abnormal_count', 'performed_by_name',
        'performed_at', 'verified_by_name', 'verified_at', 'is_verified',
        'turnaround_seconds',
    }}

    # The stage is always derived — never taken from the client.
    data['stage'] = PatientLabRecord.stage_for(
        data.get('raw_status'), bool(data.get('is_verified')),
    )

    # Result summary and abnormal count are computed, not trusted.
    results = data.get('results') or []
    data['abnormal_count'] = sum(1 for r in results if r.get('is_abnormal'))
    data['result_summary'] = PatientLabRecord.summarise(results)

    if tenant is not None:
        data['source_tenant_id'] = tenant.id
        data['source_tenant_name'] = tenant.name
    return data


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def patient_lab_records(request):
    """The signed-in patient's own shared lab orders.

    ``?status=released|processing|awaiting`` narrows the list; the default is
    everything, newest first.
    """
    qs = PatientLabRecord.objects.filter(patient_user_id=request.user.id)

    bucket = (request.query_params.get('status') or '').strip().lower()
    if bucket in {'released', 'ready', 'verified'}:
        qs = qs.filter(is_verified=True)
    elif bucket in {'awaiting', 'pending', 'in_progress'}:
        qs = qs.exclude(stage=PatientLabRecord.Stage.CANCELLED).filter(is_verified=False)

    tennant_filter = request.query_params.get('clinic')
    if tennant_filter:
        qs = qs.filter(source_tenant_id=tennant_filter)

    return Response(PatientLabRecordSerializer(qs, many=True).data)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def patient_lab_record_detail(request, pk):
    """One shared lab order — only if it belongs to the caller."""
    record = PatientLabRecord.objects.filter(
        pk=pk, patient_user_id=request.user.id,
    ).first()
    if record is None:
        return Response({'detail': 'Lab record not found.'},
                        status=status.HTTP_404_NOT_FOUND)
    return Response(PatientLabRecordSerializer(record).data)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def patient_lab_report_pdf(request, pk):
    """Download the patient-friendly PDF report for one released result.

    A draft report is never rendered — the patient must not receive a document
    that has not been signed off.
    """
    from django.http import HttpResponse

    record = PatientLabRecord.objects.filter(
        pk=pk, patient_user_id=request.user.id,
    ).first()
    if record is None:
        return Response({'detail': 'Lab record not found.'},
                        status=status.HTTP_404_NOT_FOUND)
    if not record.is_verified or not record.results:
        return Response(
            {
                'detail': 'This report has not been released yet.',
                'code': 'report_not_released',
            },
            status=status.HTTP_409_CONFLICT,
        )

    try:
        from .patient_report_pdf import build_patient_lab_report
    except ImportError:
        return Response({'detail': 'reportlab is not installed.'},
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    tenant = Tenant.objects.filter(pk=record.source_tenant_id).first()
    pdf = build_patient_lab_report(record, tenant=tenant)
    filename = f'lab_report_{record.order_ref or record.pk}.pdf'
    return HttpResponse(
        pdf,
        content_type='application/pdf',
        headers={'Content-Disposition': f'inline; filename="{filename}"'},
    )


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def patient_lab_summary(request):
    """Counts for the patient dashboard cards."""
    qs = PatientLabRecord.objects.filter(patient_user_id=request.user.id)
    released = qs.filter(is_verified=True, stage=PatientLabRecord.Stage.RELEASED)
    in_progress = qs.exclude(
        stage__in=[PatientLabRecord.Stage.CANCELLED, PatientLabRecord.Stage.RELEASED],
    )
    abnormal = sum(r.abnormal_count for r in released)
    return Response({
        'total': qs.count(),
        'in_progress': in_progress.count(),
        'released': released.count(),
        'abnormal_results': abnormal,
        'latest': PatientLabRecordSerializer(
            qs.order_by('-requested_on', '-id')[:3], many=True,
        ).data,
    })


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def patient_lab_sync(request):
    """Clinic staff push a snapshot of a lab order to the patient's portal.

    Body::

        {"records": [ { "source_order_id": 26, "patient_user_id": 310, ... } ]}

    A single record object is also accepted. Rows are upserted on
    ``(source_tenant_id, source_order_id)`` so repeated pushes update rather
    than duplicate. Never raises into the caller's flow: the lab app calls this
    best-effort, so a sharing hiccup must not roll back the clinical write.
    """
    tenant = getattr(request.user, 'tenant', None)
    if tenant is None:
        return Response(
            {'detail': 'Sharing requires a clinic context.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Only clinical staff may publish records. A patient must never be able to
    # write into a chart — not even their own.
    role = getattr(request.user, 'role', '')
    if role not in CAN_SHARE_LAB_ROLES:
        return Response(
            {'detail': 'Your role cannot publish lab records to patients.'},
            status=status.HTTP_403_FORBIDDEN,
        )

    records = request.data.get('records')
    if records is None:
        records = [request.data] if request.data.get('source_order_id') else []
    if not isinstance(records, list) or not records:
        return Response(
            {'detail': 'Provide at least one record to share.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    synced, skipped = 0, 0
    for raw in records:
        if not isinstance(raw, dict):
            skipped += 1
            continue
        source_order_id = raw.get('source_order_id')
        patient_user_id = raw.get('patient_user_id')
        if not source_order_id or not patient_user_id:
            skipped += 1
            continue

        payload = _patient_record_payload(raw, tenant=tenant)
        # The lookup keys travel through update_or_create's arguments, not
        # through defaults — leaving them in causes a duplicate-kwarg TypeError.
        payload.pop('source_order_id', None)
        payload.pop('source_tenant_id', None)
        PatientLabRecord.objects.update_or_create(
            source_tenant_id=tenant.id,
            source_order_id=source_order_id,
            defaults=payload,
        )
        synced += 1

    return Response({'synced': synced, 'skipped': skipped})
