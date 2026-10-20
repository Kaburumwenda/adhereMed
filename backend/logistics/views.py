"""Warehouse Transport & Logistics API.

Endpoints are exposed under ``/api/logistics/`` and are consumed by the IMS
tenant frontend pages under ``/ims/logistics/*``.
"""
from decimal import Decimal

from django.db.models import Count, F, Q, Sum
from django.utils import timezone
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import (
    Carrier,
    DeliveryZone,
    Driver,
    RoutePlan,
    Shipment,
    ShipmentEvent,
    ShipmentItem,
    ShipmentStop,
    Vehicle,
    VehicleMaintenance,
)
from .serializers import (
    CarrierSerializer,
    DeliveryZoneSerializer,
    DriverSerializer,
    RoutePlanSerializer,
    ShipmentEventSerializer,
    ShipmentItemSerializer,
    ShipmentListSerializer,
    ShipmentSerializer,
    ShipmentStopSerializer,
    VehicleMaintenanceSerializer,
    VehicleSerializer,
)


def _dec(value):
    return Decimal(value or 0)


class LogisticsBaseViewSet(viewsets.ModelViewSet):
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]


# ─────────────────────────────────────────────────────────────────────────
#  Carriers
# ─────────────────────────────────────────────────────────────────────────
class CarrierViewSet(LogisticsBaseViewSet):
    queryset = Carrier.objects.all()
    serializer_class = CarrierSerializer
    filterset_fields = ['is_active', 'service_level']
    search_fields = ['name', 'code', 'contact_person', 'phone', 'service_area']
    ordering_fields = ['name', 'rating', 'on_time_rate', 'created_at']

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.get_queryset()
        active = qs.filter(is_active=True)
        agg = active.aggregate(
            avg_rating=Sum('rating'),
            avg_on_time=Sum('on_time_rate'),
        )
        count = active.count() or 1
        return Response({
            'total': qs.count(),
            'active': active.count(),
            'avg_rating': round((agg['avg_rating'] or 0) / count, 2),
            'avg_on_time_rate': round((agg['avg_on_time'] or 0) / count, 2),
            'by_level': list(active.values('service_level').annotate(count=Count('id'))),
        })


# ─────────────────────────────────────────────────────────────────────────
#  Fleet
# ─────────────────────────────────────────────────────────────────────────
class VehicleViewSet(LogisticsBaseViewSet):
    queryset = Vehicle.objects.select_related('carrier', 'home_branch').all()
    serializer_class = VehicleSerializer
    filterset_fields = ['status', 'vehicle_type', 'ownership', 'carrier', 'home_branch', 'is_active']
    search_fields = ['plate_number', 'name', 'make', 'model']
    ordering_fields = ['plate_number', 'status', 'created_at']

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.get_queryset()
        today = timezone.localdate()
        return Response({
            'total': qs.count(),
            'available': qs.filter(status=Vehicle.Status.AVAILABLE).count(),
            'in_use': qs.filter(status=Vehicle.Status.IN_USE).count(),
            'maintenance': qs.filter(status=Vehicle.Status.MAINTENANCE).count(),
            'retired': qs.filter(status=Vehicle.Status.RETIRED).count(),
            'active': qs.filter(is_active=True).count(),
            'capacity_kg': float(qs.aggregate(v=Sum('capacity_kg'))['v'] or 0),
            'insurance_expiring': qs.filter(
                insurance_expiry__isnull=False,
                insurance_expiry__lte=today + timezone.timedelta(days=30),
            ).count(),
            'by_type': list(qs.values('vehicle_type').annotate(count=Count('id'))),
        })

    @action(detail=True, methods=['post'], url_path='set-status')
    def set_status(self, request, pk=None):
        vehicle = self.get_object()
        new_status = request.data.get('status')
        allowed = {c[0] for c in Vehicle.Status.choices}
        if new_status not in allowed:
            return Response({'detail': 'Invalid status.'}, status=status.HTTP_400_BAD_REQUEST)
        vehicle.status = new_status
        vehicle.save(update_fields=['status', 'updated_at'])
        return Response(self.get_serializer(vehicle).data)

    @action(detail=True, methods=['get', 'post'], url_path='maintenance')
    def maintenance(self, request, pk=None):
        vehicle = self.get_object()
        if request.method == 'GET':
            qs = vehicle.maintenance.all()
            return Response(VehicleMaintenanceSerializer(qs, many=True).data)
        payload = {**request.data, 'vehicle': vehicle.id}
        serializer = VehicleMaintenanceSerializer(data=payload)
        serializer.is_valid(raise_exception=True)
        serializer.save(created_by=request.user if request.user.is_authenticated else None)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


# ─────────────────────────────────────────────────────────────────────────
#  Drivers
# ─────────────────────────────────────────────────────────────────────────
class DriverViewSet(LogisticsBaseViewSet):
    queryset = Driver.objects.select_related('assigned_vehicle', 'home_branch').all()
    serializer_class = DriverSerializer
    filterset_fields = ['status', 'home_branch', 'assigned_vehicle', 'is_active']
    search_fields = ['full_name', 'phone', 'license_number', 'email']
    ordering_fields = ['full_name', 'rating', 'total_trips', 'created_at']

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.get_queryset()
        today = timezone.localdate()
        return Response({
            'total': qs.count(),
            'available': qs.filter(status=Driver.Status.AVAILABLE).count(),
            'on_trip': qs.filter(status=Driver.Status.ON_TRIP).count(),
            'off_duty': qs.filter(status=Driver.Status.OFF_DUTY).count(),
            'suspended': qs.filter(status=Driver.Status.SUSPENDED).count(),
            'license_expiring': qs.filter(
                license_expiry__isnull=False,
                license_expiry__lte=today + timezone.timedelta(days=30),
            ).count(),
            'total_trips': qs.aggregate(v=Sum('total_trips'))['v'] or 0,
        })

    @action(detail=True, methods=['post'], url_path='set-status')
    def set_status(self, request, pk=None):
        driver = self.get_object()
        new_status = request.data.get('status')
        allowed = {c[0] for c in Driver.Status.choices}
        if new_status not in allowed:
            return Response({'detail': 'Invalid status.'}, status=status.HTTP_400_BAD_REQUEST)
        driver.status = new_status
        driver.save(update_fields=['status', 'updated_at'])
        return Response(self.get_serializer(driver).data)


# ─────────────────────────────────────────────────────────────────────────
#  Zones
# ─────────────────────────────────────────────────────────────────────────
class DeliveryZoneViewSet(LogisticsBaseViewSet):
    queryset = DeliveryZone.objects.select_related('branch').all()
    serializer_class = DeliveryZoneSerializer
    filterset_fields = ['is_active', 'zone_type', 'branch']
    search_fields = ['name', 'code']
    ordering_fields = ['name', 'base_fee', 'eta_hours']


# ─────────────────────────────────────────────────────────────────────────
#  Shipments
# ─────────────────────────────────────────────────────────────────────────
class ShipmentViewSet(LogisticsBaseViewSet):
    queryset = (
        Shipment.objects
        .select_related(
            'carrier', 'vehicle', 'driver', 'source_branch', 'dest_branch',
            'zone', 'stock_transfer', 'created_by',
        )
        .prefetch_related('stops', 'items', 'events__created_by')
        .all()
    )
    filterset_fields = [
        'status', 'movement_type', 'priority', 'source_type', 'dest_type',
        'carrier', 'vehicle', 'driver', 'source_branch', 'dest_branch',
        'requires_refrigeration',
    ]
    search_fields = [
        'reference', 'tracking_number', 'origin_name', 'dest_name',
        'origin_address', 'dest_address', 'dest_contact', 'origin_contact',
    ]
    ordering_fields = ['created_at', 'scheduled_delivery', 'status', 'priority', 'distance_km']

    def get_serializer_class(self):
        if self.action == 'list':
            return ShipmentListSerializer
        return ShipmentSerializer

    # ── analytics ────────────────────────────────────────────────────────
    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.filter_queryset(self.get_queryset())
        now = timezone.now()
        today = timezone.localdate()
        open_states = [
            Shipment.Status.DRAFT, Shipment.Status.PLANNED, Shipment.Status.ASSIGNED,
            Shipment.Status.PICKED_UP, Shipment.Status.IN_TRANSIT,
            Shipment.Status.OUT_FOR_DELIVERY,
        ]
        open_qs = qs.filter(status__in=open_states)
        late_qs = open_qs.filter(scheduled_delivery__lt=now)
        delivered = qs.filter(status=Shipment.Status.DELIVERED)

        agg = qs.aggregate(
            freight=Sum('freight_cost'),
            fuel=Sum('fuel_cost'),
            other=Sum('other_cost'),
            distance=Sum('distance_km'),
        )
        total_cost = _dec(agg['freight']) + _dec(agg['fuel']) + _dec(agg['other'])

        month_start = today.replace(day=1)
        delivered_month = delivered.filter(actual_delivery__date__gte=month_start).count()
        on_time = delivered.filter(
            actual_delivery__isnull=False,
            scheduled_delivery__isnull=False,
            actual_delivery__lte=F('scheduled_delivery'),
        ).count()

        return Response({
            'total': qs.count(),
            'open': open_qs.count(),
            'late': late_qs.count(),
            'delivered': delivered.count(),
            'delivered_this_month': delivered_month,
            'failed': qs.filter(status=Shipment.Status.FAILED).count(),
            'cancelled': qs.filter(status=Shipment.Status.CANCELLED).count(),
            'draft': qs.filter(status=Shipment.Status.DRAFT).count(),
            'planned': qs.filter(status=Shipment.Status.PLANNED).count(),
            'assigned': qs.filter(status=Shipment.Status.ASSIGNED).count(),
            'picked_up': qs.filter(status=Shipment.Status.PICKED_UP).count(),
            'in_transit': qs.filter(status=Shipment.Status.IN_TRANSIT).count(),
            'out_for_delivery': qs.filter(status=Shipment.Status.OUT_FOR_DELIVERY).count(),
            'unassigned': qs.filter(driver__isnull=True).exclude(
                status__in=[Shipment.Status.DELIVERED, Shipment.Status.CANCELLED],
            ).count(),
            'urgent': open_qs.filter(priority=Shipment.Priority.URGENT).count(),
            'requires_refrigeration': open_qs.filter(requires_refrigeration=True).count(),
            'total_cost': float(total_cost),
            'total_distance_km': float(agg['distance'] or 0),
            'by_status': list(qs.values('status').annotate(count=Count('id'))),
            'by_type': list(qs.values('movement_type').annotate(count=Count('id'))),
            'by_priority': list(open_qs.values('priority').annotate(count=Count('id'))),
            'on_time_pct': round((on_time / delivered.count()) * 100, 1) if delivered.exists() else 0,
        })

    @action(detail=False, methods=['get'])
    def board(self, request):
        """Grouped shipments for the dispatch board."""
        qs = self.filter_queryset(self.get_queryset())
        columns = {}
        for choice, label in Shipment.Status.choices:
            rows = qs.filter(status=choice)
            columns[choice] = {
                'status': choice,
                'label': label,
                'count': rows.count(),
                'shipments': ShipmentListSerializer(rows[:60], many=True).data,
            }
        return Response({'columns': columns})

    @action(detail=False, methods=['get'])
    def expiring(self, request):
        """Compliance alerts: vehicles / drivers nearing expiry."""
        today = timezone.localdate()
        horizon = today + timezone.timedelta(days=30)
        vehicles = Vehicle.objects.filter(
            Q(insurance_expiry__isnull=False, insurance_expiry__lte=horizon) |
            Q(inspection_expiry__isnull=False, inspection_expiry__lte=horizon),
        ).values('id', 'plate_number', 'insurance_expiry', 'inspection_expiry')
        drivers = Driver.objects.filter(
            license_expiry__isnull=False, license_expiry__lte=horizon,
        ).values('id', 'full_name', 'license_expiry')
        return Response({
            'vehicles': list(vehicles),
            'drivers': list(drivers),
        })

    # ── lifecycle ────────────────────────────────────────────────────────
    def _log(self, shipment, event_type, description='', location=''):
        ShipmentEvent.objects.create(
            shipment=shipment,
            event_type=event_type,
            description=description,
            location=location,
            created_by=self.request.user if self.request.user.is_authenticated else None,
        )

    @action(detail=True, methods=['post'])
    def assign(self, request, pk=None):
        shipment = self.get_object()
        fields = []
        for key in ('carrier', 'vehicle', 'driver', 'zone'):
            if key in request.data:
                setattr(shipment, f'{key}_id', request.data.get(key) or None)
                fields.append(key)
        if request.data.get('scheduled_pickup'):
            shipment.scheduled_pickup = request.data['scheduled_pickup']
            fields.append('scheduled_pickup')
        if request.data.get('scheduled_delivery'):
            shipment.scheduled_delivery = request.data['scheduled_delivery']
            fields.append('scheduled_delivery')
        if shipment.status in (Shipment.Status.DRAFT, Shipment.Status.PLANNED):
            shipment.status = Shipment.Status.ASSIGNED
            fields.append('status')
        if fields:
            fields.append('updated_at')
            shipment.save(update_fields=fields)
        label = shipment.driver.full_name if shipment.driver else 'a carrier'
        self._log(shipment, ShipmentEvent.EventType.ASSIGNED, f'Assigned to {label}')
        return Response(ShipmentSerializer(shipment).data)

    @action(detail=True, methods=['post'])
    def pickup(self, request, pk=None):
        shipment = self.get_object()
        shipment.status = Shipment.Status.PICKED_UP
        shipment.actual_pickup = request.data.get('actual_pickup') or timezone.now()
        shipment.save(update_fields=['status', 'actual_pickup', 'updated_at'])
        self._log(shipment, ShipmentEvent.EventType.PICKED_UP, 'Goods collected at origin')
        return Response(ShipmentSerializer(shipment).data)

    @action(detail=True, methods=['post'])
    def depart(self, request, pk=None):
        shipment = self.get_object()
        shipment.status = Shipment.Status.IN_TRANSIT
        shipment.save(update_fields=['status', 'updated_at'])
        self._log(
            shipment, ShipmentEvent.EventType.IN_TRANSIT,
            request.data.get('description') or 'Departed origin hub',
            request.data.get('location', ''),
        )
        return Response(ShipmentSerializer(shipment).data)

    @action(detail=True, methods=['post'])
    def out_for_delivery(self, request, pk=None):
        shipment = self.get_object()
        shipment.status = Shipment.Status.OUT_FOR_DELIVERY
        shipment.save(update_fields=['status', 'updated_at'])
        self._log(shipment, ShipmentEvent.EventType.IN_TRANSIT, 'Out for delivery')
        return Response(ShipmentSerializer(shipment).data)

    @action(detail=True, methods=['post'])
    def deliver(self, request, pk=None):
        shipment = self.get_object()
        shipment.status = Shipment.Status.DELIVERED
        shipment.actual_delivery = request.data.get('actual_delivery') or timezone.now()
        shipment.pod_received_by = request.data.get('pod_received_by', '')
        shipment.pod_signature = request.data.get('pod_signature', '')
        shipment.pod_notes = request.data.get('pod_notes', '')
        shipment.save(update_fields=[
            'status', 'actual_delivery', 'pod_received_by', 'pod_signature',
            'pod_notes', 'updated_at',
        ])

        # Roll driver + vehicle counters
        if shipment.driver:
            shipment.driver.total_trips = (shipment.driver.total_trips or 0) + 1
            shipment.driver.total_distance_km = (
                _dec(shipment.driver.total_distance_km) + _dec(shipment.distance_km)
            )
            shipment.driver.status = Driver.Status.AVAILABLE
            shipment.driver.save(update_fields=['total_trips', 'total_distance_km', 'status', 'updated_at'])
        if shipment.vehicle:
            shipment.vehicle.odometer_km = (
                _dec(shipment.vehicle.odometer_km) + _dec(shipment.distance_km)
            )
            shipment.vehicle.status = Vehicle.Status.AVAILABLE
            shipment.vehicle.save(update_fields=['odometer_km', 'status', 'updated_at'])

        self._log(
            shipment, ShipmentEvent.EventType.DELIVERED,
            f'Delivered to {shipment.pod_received_by or shipment.dest_name or "recipient"}',
            shipment.dest_address,
        )
        return Response(ShipmentSerializer(shipment).data)

    @action(detail=True, methods=['post'])
    def fail(self, request, pk=None):
        shipment = self.get_object()
        shipment.status = Shipment.Status.FAILED
        shipment.failure_reason = request.data.get('reason', '')
        shipment.save(update_fields=['status', 'failure_reason', 'updated_at'])
        if shipment.driver:
            shipment.driver.status = Driver.Status.AVAILABLE
            shipment.driver.save(update_fields=['status', 'updated_at'])
        if shipment.vehicle:
            shipment.vehicle.status = Vehicle.Status.AVAILABLE
            shipment.vehicle.save(update_fields=['status', 'updated_at'])
        self._log(
            shipment, ShipmentEvent.EventType.FAILED,
            shipment.failure_reason or 'Delivery attempt failed',
        )
        return Response(ShipmentSerializer(shipment).data)

    @action(detail=True, methods=['post'])
    def cancel_shipment(self, request, pk=None):
        shipment = self.get_object()
        shipment.status = Shipment.Status.CANCELLED
        shipment.notes = request.data.get('reason', shipment.notes)
        shipment.save(update_fields=['status', 'notes', 'updated_at'])
        self._log(shipment, ShipmentEvent.EventType.CANCELLED, request.data.get('reason', 'Cancelled'))
        return Response(ShipmentSerializer(shipment).data)

    # alias so the URL reads /cancel/
    @action(detail=True, methods=['post'], url_path='cancel')
    def cancel(self, request, pk=None):
        return self.cancel_shipment(request, pk=pk)

    @action(detail=True, methods=['post'], url_path='set-status')
    def set_status(self, request, pk=None):
        shipment = self.get_object()
        new_status = request.data.get('status')
        allowed = {c[0] for c in Shipment.Status.choices}
        if new_status not in allowed:
            return Response({'detail': 'Invalid status.'}, status=status.HTTP_400_BAD_REQUEST)
        shipment.status = new_status
        shipment.save(update_fields=['status', 'updated_at'])
        self._log(shipment, ShipmentEvent.EventType.NOTE, f'Status set to {new_status}')
        return Response(ShipmentSerializer(shipment).data)

    @action(detail=True, methods=['get'])
    def timeline(self, request, pk=None):
        shipment = self.get_object()
        return Response(ShipmentEventSerializer(shipment.events.all(), many=True).data)

    @action(detail=True, methods=['post'], url_path='add-event')
    def add_event(self, request, pk=None):
        shipment = self.get_object()
        serializer = ShipmentEventSerializer(data={**request.data, 'shipment': shipment.id})
        serializer.is_valid(raise_exception=True)
        serializer.save(created_by=request.user if request.user.is_authenticated else None)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    # ── nested children ──────────────────────────────────────────────────
    @action(detail=True, methods=['get', 'post'])
    def stops(self, request, pk=None):
        shipment = self.get_object()
        if request.method == 'GET':
            return Response(ShipmentStopSerializer(shipment.stops.all(), many=True).data)
        serializer = ShipmentStopSerializer(data={**request.data, 'shipment': shipment.id})
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['get', 'post'])
    def items(self, request, pk=None):
        shipment = self.get_object()
        if request.method == 'GET':
            return Response(ShipmentItemSerializer(shipment.items.all(), many=True).data)
        serializer = ShipmentItemSerializer(data={**request.data, 'shipment': shipment.id})
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'], url_path=r'from-transfer/(?P<transfer_id>[^/.]+)')
    def from_transfer(self, request, transfer_id=None):
        """Create a shipment for an existing inventory StockTransfer."""
        from inventory.models import StockTransfer

        try:
            transfer = StockTransfer.objects.select_related(
                'source_branch', 'dest_branch',
            ).get(pk=transfer_id)
        except StockTransfer.DoesNotExist:
            return Response({'detail': 'Transfer not found.'}, status=status.HTTP_404_NOT_FOUND)

        existing = Shipment.objects.filter(stock_transfer=transfer).first()
        if existing:
            return Response(ShipmentSerializer(existing).data)

        shipment = Shipment.objects.create(
            movement_type=Shipment.MovementType.TRANSFER,
            status=Shipment.Status.PLANNED,
            source_type=Shipment.PartyType.WAREHOUSE,
            dest_type=Shipment.PartyType.WAREHOUSE,
            source_branch=transfer.source_branch,
            dest_branch=transfer.dest_branch,
            origin_name=transfer.source_branch.name if transfer.source_branch else '',
            origin_address=transfer.source_branch.address if transfer.source_branch else '',
            dest_name=transfer.dest_branch.name if transfer.dest_branch else '',
            dest_address=transfer.dest_branch.address if transfer.dest_branch else '',
            stock_transfer=transfer,
            notes=f'Auto-created from stock transfer {transfer.reference}',
            created_by=request.user if request.user.is_authenticated else None,
        )
        ShipmentEvent.objects.create(
            shipment=shipment,
            event_type=ShipmentEvent.EventType.CREATED,
            description=f'Created from transfer {transfer.reference}',
            created_by=request.user if request.user.is_authenticated else None,
        )
        return Response(ShipmentSerializer(shipment).data, status=status.HTTP_201_CREATED)


# ─────────────────────────────────────────────────────────────────────────
#  Route plans
# ─────────────────────────────────────────────────────────────────────────
class RoutePlanViewSet(LogisticsBaseViewSet):
    queryset = RoutePlan.objects.select_related('driver', 'vehicle', 'carrier').prefetch_related('shipments').all()
    serializer_class = RoutePlanSerializer
    filterset_fields = ['status', 'plan_date', 'driver', 'vehicle', 'carrier']
    search_fields = ['name', 'notes']
    ordering_fields = ['plan_date', 'name', 'created_at']

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.get_queryset()
        return Response({
            'total': qs.count(),
            'draft': qs.filter(status=RoutePlan.Status.DRAFT).count(),
            'optimized': qs.filter(status=RoutePlan.Status.OPTIMIZED).count(),
            'dispatched': qs.filter(status=RoutePlan.Status.DISPATCHED).count(),
            'in_progress': qs.filter(status=RoutePlan.Status.IN_PROGRESS).count(),
            'completed': qs.filter(status=RoutePlan.Status.COMPLETED).count(),
            'planned_distance_km': float(qs.aggregate(v=Sum('planned_distance_km'))['v'] or 0),
        })

    @action(detail=True, methods=['post'])
    def optimize(self, request, pk=None):
        """Nearest-neighbour style sequencing of the plan's shipments.

        We order shipments by their scheduled delivery time then by distance,
        which is deterministic and good enough for a first-pass manifest.
        """
        plan = self.get_object()
        rows = list(plan.shipments.all().order_by('scheduled_delivery', '-priority'))
        sequence = []
        for idx, shp in enumerate(rows, start=1):
            sequence.append({
                'sequence': idx,
                'shipment_id': shp.id,
                'reference': shp.reference,
                'dest_name': shp.dest_name,
                'scheduled_delivery': (
                    shp.scheduled_delivery.isoformat() if shp.scheduled_delivery else None
                ),
            })
            for stop in shp.stops.all().order_by('sequence'):
                stop.sequence = idx
                stop.save(update_fields=['sequence'])
        plan.optimized_sequence = sequence
        plan.stop_count = sum(s.stops.count() for s in rows) or len(rows)
        plan.planned_distance_km = sum(_dec(s.distance_km) for s in rows)
        plan.planned_duration_minutes = sum((s.duration_minutes or 0) for s in rows)
        plan.status = RoutePlan.Status.OPTIMIZED
        plan.save()
        return Response(RoutePlanSerializer(plan).data)

    @action(detail=True, methods=['post'], url_path='dispatch')
    def dispatch_plan(self, request, pk=None):
        plan = self.get_object()
        plan.status = RoutePlan.Status.DISPATCHED
        plan.save(update_fields=['status', 'updated_at'])
        for shp in plan.shipments.all():
            if shp.status in (Shipment.Status.DRAFT, Shipment.Status.PLANNED):
                shp.status = Shipment.Status.ASSIGNED
                shp.save(update_fields=['status', 'updated_at'])
        if plan.driver:
            plan.driver.status = Driver.Status.ON_TRIP
            plan.driver.save(update_fields=['status', 'updated_at'])
        if plan.vehicle:
            plan.vehicle.status = Vehicle.Status.IN_USE
            plan.vehicle.save(update_fields=['status', 'updated_at'])
        return Response(RoutePlanSerializer(plan).data)

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        plan = self.get_object()
        plan.status = RoutePlan.Status.COMPLETED
        plan.save(update_fields=['status', 'updated_at'])
        if plan.driver:
            plan.driver.status = Driver.Status.AVAILABLE
            plan.driver.save(update_fields=['status', 'updated_at'])
        if plan.vehicle:
            plan.vehicle.status = Vehicle.Status.AVAILABLE
            plan.vehicle.save(update_fields=['status', 'updated_at'])
        return Response(RoutePlanSerializer(plan).data)
