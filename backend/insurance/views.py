from django.db.models import Sum, Count, Q
from django.utils import timezone
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import InsuranceProvider, InsuranceClaim
from .serializers import InsuranceProviderSerializer, InsuranceClaimSerializer


class InsuranceProviderViewSet(viewsets.ModelViewSet):
    queryset = InsuranceProvider.objects.all()
    serializer_class = InsuranceProviderSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active']
    search_fields = ['name', 'code', 'contact_person', 'email']
    ordering = ['name']


class InsuranceClaimViewSet(viewsets.ModelViewSet):
    queryset = InsuranceClaim.objects.select_related('provider', 'created_by').all()
    serializer_class = InsuranceClaimSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'provider', 'member_number']
    search_fields = ['reference', 'member_name', 'member_number', 'invoice_number']
    ordering = ['-created_at']

    @action(detail=True, methods=['post'])
    def submit(self, request, pk=None):
        claim = self.get_object()
        if claim.status != InsuranceClaim.Status.DRAFT:
            return Response({'detail': 'Only drafts can be submitted.'}, status=400)
        claim.status = InsuranceClaim.Status.SUBMITTED
        claim.submitted_at = timezone.now()
        claim.save(update_fields=['status', 'submitted_at'])
        return Response(self.get_serializer(claim).data)

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        claim = self.get_object()
        approved = request.data.get('approved_amount')
        if approved is None:
            approved = claim.claim_amount
        try:
            claim.approved_amount = float(approved)
        except (TypeError, ValueError):
            return Response({'detail': 'Invalid approved_amount'}, status=400)
        if claim.approved_amount <= 0:
            claim.status = InsuranceClaim.Status.REJECTED
            claim.rejection_reason = request.data.get('reason', '')
        elif claim.approved_amount < float(claim.claim_amount or 0):
            claim.status = InsuranceClaim.Status.PARTIALLY_APPROVED
        else:
            claim.status = InsuranceClaim.Status.APPROVED
        claim.save()
        return Response(self.get_serializer(claim).data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        claim = self.get_object()
        claim.status = InsuranceClaim.Status.REJECTED
        claim.rejection_reason = request.data.get('reason', '')
        claim.save(update_fields=['status', 'rejection_reason'])
        return Response(self.get_serializer(claim).data)

    @action(detail=True, methods=['post'], url_path='record-payment')
    def record_payment(self, request, pk=None):
        claim = self.get_object()
        try:
            amount = float(request.data.get('amount', 0))
        except (TypeError, ValueError):
            return Response({'detail': 'Invalid amount'}, status=400)
        if amount <= 0:
            return Response({'detail': 'Amount must be positive'}, status=400)
        claim.paid_amount = float(claim.paid_amount or 0) + amount
        claim.payment_reference = request.data.get('reference', claim.payment_reference)
        if claim.paid_amount >= float(claim.approved_amount or 0):
            claim.status = InsuranceClaim.Status.PAID
            claim.settled_at = timezone.now()
        claim.save()
        return Response(self.get_serializer(claim).data)

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.get_queryset()
        agg = qs.aggregate(
            total=Count('id'),
            claimed=Sum('claim_amount'),
            approved=Sum('approved_amount'),
            paid=Sum('paid_amount'),
        )
        by_status = list(qs.values('status').annotate(count=Count('id'), amount=Sum('claim_amount')))
        by_provider = list(
            qs.values('provider__name')
              .annotate(count=Count('id'), amount=Sum('claim_amount'))
              .order_by('-amount')[:10]
        )
        return Response({
            'totals': {
                'count': agg['total'] or 0,
                'claimed': float(agg['claimed'] or 0),
                'approved': float(agg['approved'] or 0),
                'paid': float(agg['paid'] or 0),
                'outstanding': float((agg['approved'] or 0) - (agg['paid'] or 0)),
            },
            'by_status': by_status,
            'by_provider': by_provider,
        })
