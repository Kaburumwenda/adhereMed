from rest_framework import viewsets, filters, status
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from .models import PharmacyDetail, Delivery, Branch
from .serializers import PharmacyDetailSerializer, DeliverySerializer, BranchSerializer


class BranchViewSet(viewsets.ModelViewSet):
    queryset = Branch.objects.all()
    serializer_class = BranchSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active', 'is_main']
    search_fields = ['name', 'address']
    ordering_fields = ['name', 'created_at']


class PharmacyDetailViewSet(viewsets.ModelViewSet):
    queryset = PharmacyDetail.objects.all()
    serializer_class = PharmacyDetailSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name']
    ordering_fields = ['name', 'created_at']

    @action(detail=True, methods=['post'], parser_classes=[MultiPartParser, FormParser], url_path='upload-logo')
    def upload_logo(self, request, pk=None):
        instance = self.get_object()
        logo = request.FILES.get('logo')
        if not logo:
            return Response({'error': 'No logo file provided.'}, status=status.HTTP_400_BAD_REQUEST)
        # Basic validation: image only
        if not logo.content_type.startswith('image/'):
            return Response({'error': 'File must be an image.'}, status=status.HTTP_400_BAD_REQUEST)
        # Remove old logo if exists
        if instance.logo:
            instance.logo.delete(save=False)
        instance.logo = logo
        instance.save(update_fields=['logo'])
        serializer = self.get_serializer(instance, context={'request': request})
        return Response(serializer.data)


class DeliveryViewSet(viewsets.ModelViewSet):
    queryset = Delivery.objects.select_related('transaction', 'assigned_to').all()
    serializer_class = DeliverySerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'assigned_to']
    search_fields = ['recipient_name', 'recipient_phone', 'delivery_address']
    ordering_fields = ['created_at', 'scheduled_at', 'status']
    ordering = ['-created_at']

    @action(detail=True, methods=['post'])
    def update_status(self, request, pk=None):
        delivery = self.get_object()
        new_status = request.data.get('status')
        valid_statuses = [c[0] for c in Delivery.Status.choices]
        if new_status not in valid_statuses:
            return Response(
                {'error': f'Invalid status. Must be one of: {valid_statuses}'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        delivery.status = new_status
        if new_status == 'delivered':
            from django.utils import timezone
            delivery.delivered_at = timezone.now()
        delivery.save()
        return Response(DeliverySerializer(delivery).data)


# ── Pharmacy Setup / Seed ────────────────────────────────────────────────────────

PHARMACY_SEED_COMMANDS = {
    "categories_units": {
        "label": "Categories & Units",
        "description": "34 stock categories and 24 measurement units (subset of full stock seed)",
        "command": "seed_pharmacy_stock",
        "args": {"skip_existing": True},
    },
    "medications": {
        "label": "Medication Catalog",
        "description": "~120 common medications (analgesics, antibiotics, etc.)",
        "command": "seed_medications",
        "args": {"skip_existing": True},
    },
    "interactions": {
        "label": "Drug Interactions",
        "description": "~30 common drug-drug interaction pairs with severity & advice",
        "command": "seed_interactions",
        "args": {"skip_existing": True},
    },
}

ALLOWED_SEED_ROLES = {"tenant_admin", "branch_admin", "pharmacist", "admin"}


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def pharmacy_seed_catalog(request):
    """Return available pharmacy seed commands for tenant/branch admins."""
    if request.user.role not in ALLOWED_SEED_ROLES:
        return Response(
            {"detail": "You do not have permission to seed data."},
            status=status.HTTP_403_FORBIDDEN,
        )
    items = []
    for key, info in PHARMACY_SEED_COMMANDS.items():
        items.append({
            "key": key,
            "label": info["label"],
            "description": info["description"],
        })
    return Response(items)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def pharmacy_run_seed(request):
    """
    Run a pharmacy seed command for the current tenant.
    Body: { "command": "pharmacy_stock" }
    """
    from django.core.management import call_command

    if request.user.role not in ALLOWED_SEED_ROLES:
        return Response(
            {"detail": "You do not have permission to seed data."},
            status=status.HTTP_403_FORBIDDEN,
        )

    cmd_key = request.data.get("command", "")
    if cmd_key not in PHARMACY_SEED_COMMANDS:
        return Response(
            {"detail": f"Unknown seed command: {cmd_key}"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    info = PHARMACY_SEED_COMMANDS[cmd_key]
    try:
        kwargs = info.get("args", {})
        call_command(info["command"], **kwargs)
        return Response({
            "detail": f"'{info['label']}' seeded successfully.",
            "command": cmd_key,
        })
    except Exception as e:
        return Response(
            {"detail": f"Seed failed: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
