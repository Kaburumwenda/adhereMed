"""Customer Relationship Management API — ``/api/crm/``."""
from datetime import timedelta
from decimal import Decimal

from django.db.models import Count, Q, Sum
from django.utils import timezone
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from pos.models import Customer

from .models import (
    Campaign,
    CustomerProfile,
    Feedback,
    Interaction,
    Opportunity,
    PointsEntry,
    Segment,
    Tag,
    Task,
    Ticket,
)
from .serializers import (
    CampaignSerializer,
    CustomerCRMSerializer,
    CustomerProfileSerializer,
    FeedbackSerializer,
    InteractionSerializer,
    OpportunitySerializer,
    PointsEntrySerializer,
    SegmentSerializer,
    TagSerializer,
    TaskSerializer,
    TicketSerializer,
)


def _dec(v):
    return Decimal(v or 0)


class CRMBaseViewSet(viewsets.ModelViewSet):
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]

    def _user(self):
        u = getattr(self.request, 'user', None)
        return u if u and u.is_authenticated else None


# ─────────────────────────────────────────────────────────────────────────
#  Customers (profile-backed view over pos.Customer)
# ─────────────────────────────────────────────────────────────────────────
class CustomerCRMViewSet(CRMBaseViewSet):
    """CRM customer list — every pos.Customer with its profile joined in."""

    serializer_class = CustomerCRMSerializer
    search_fields = ['name', 'phone', 'email', 'address', 'crm_profile__company', 'crm_profile__tags__name']
    ordering_fields = ['name', 'created_at', 'total_purchases', 'loyalty_points', 'visit_count']

    def get_queryset(self):
        return (
            Customer.objects
            .select_related('branch', 'crm_profile__segment', 'crm_profile__owner')
            .prefetch_related('crm_profile__tags')
            .all()
        )

    def filter_queryset(self, queryset):
        qs = super().filter_queryset(queryset)
        p = self.request.query_params
        if p.get('lifecycle_stage'):
            qs = qs.filter(crm_profile__lifecycle_stage=p['lifecycle_stage'])
        if p.get('segment'):
            qs = qs.filter(crm_profile__segment_id=p['segment'])
        if p.get('tier'):
            qs = qs.filter(loyalty_tier=p['tier'])
        if p.get('owner'):
            qs = qs.filter(crm_profile__owner_id=p['owner'])
        if p.get('vip') in ('1', 'true'):
            qs = qs.filter(crm_profile__is_vip=True)
        if p.get('is_active') in ('0', 'false'):
            qs = qs.filter(is_active=False)
        elif p.get('is_active') in ('1', 'true'):
            qs = qs.filter(is_active=True)
        if p.get('branch'):
            qs = qs.filter(branch_id=p['branch'])
        if p.get('risk') == 'high':
            qs = qs.filter(crm_profile__churn_risk__gte=60)
        return qs

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.filter_queryset(self.get_queryset())
        now = timezone.now()
        profiles = CustomerProfile.objects.all()
        total = qs.count()

        lifecycle = {row['lifecycle_stage']: row['count'] for row in
                     profiles.values('lifecycle_stage').annotate(count=Count('id'))}
        tiers = {row['loyalty_tier']: row['count'] for row in
                 Customer.objects.values('loyalty_tier').annotate(count=Count('id'))}

        ltv = Customer.objects.aggregate(v=Sum('total_purchases'))['v'] or 0
        points = Customer.objects.aggregate(v=Sum('loyalty_points'))['v'] or 0
        outstanding = profiles.aggregate(v=Sum('outstanding_balance'))['v'] or 0

        new_30 = Customer.objects.filter(created_at__gte=now - timedelta(days=30)).count()
        vip = profiles.filter(is_vip=True).count()
        at_risk = profiles.filter(churn_risk__gte=60).count()
        follow_ups = profiles.filter(
            next_follow_up_at__isnull=False, next_follow_up_at__lte=now,
        ).count()

        return Response({
            'total_customers': total,
            'active': qs.filter(is_active=True).count(),
            'new_30_days': new_30,
            'vip': vip,
            'at_risk': at_risk,
            'follow_ups_due': follow_ups,
            'lifetime_value': float(ltv),
            'loyalty_points': points or 0,
            'outstanding_balance': float(outstanding),
            'avg_health': round(
                (profiles.aggregate(v=Sum('health_score'))['v'] or 0) / (profiles.count() or 1), 1,
            ),
            'by_lifecycle': lifecycle,
            'by_tier': tiers,
            'open_tickets': Ticket.objects.exclude(status__in=['resolved', 'closed']).count(),
            'open_opportunities': Opportunity.objects.exclude(stage__in=['won', 'lost']).count(),
            'pipeline_value': float(
                Opportunity.objects.exclude(stage__in=['won', 'lost']).aggregate(
                    v=Sum('value'))['v'] or 0
            ),
        })

    @action(detail=True, methods=['get'])
    def detail_360(self, request, pk=None):
        """Full 360° view: profile, interactions, tickets, deals, tasks, feedback, points."""
        customer = self.get_object()
        profile = getattr(customer, 'crm_profile', None)
        profile_data = CustomerProfileSerializer(profile).data if profile else None

        interactions = customer.crm_interactions.select_related('created_by')[:50]
        tickets = customer.crm_tickets.select_related('assigned_to')[:25]
        opportunities = customer.crm_opportunities.select_related('owner')[:25]
        tasks = customer.crm_tasks.select_related('assigned_to')[:25]
        feedback = customer.crm_feedback.all()[:20]
        points = customer.crm_points.all()[:30]

        # Simple spend trend from POS transactions (last 6 months)
        from pos.models import POSTransaction

        trend = []
        today = timezone.localdate()
        for i in range(5, -1, -1):
            month_start = (today.replace(day=1) - timedelta(days=30 * i)).replace(day=1)
            next_month = (month_start.replace(day=28) + timedelta(days=4)).replace(day=1)
            rows = POSTransaction.objects.filter(
                customer=customer,
                created_at__date__gte=month_start,
                created_at__date__lt=next_month,
            )
            agg = rows.aggregate(total=Sum('total'), n=Count('id'))
            trend.append({
                'month': month_start.strftime('%b %Y'),
                'total': float(agg['total'] or 0),
                'transactions': agg['n'] or 0,
            })

        return Response({
            'customer': CustomerCRMSerializer(customer).data,
            'profile': profile_data,
            'interactions': InteractionSerializer(interactions, many=True).data,
            'tickets': TicketSerializer(tickets, many=True).data,
            'opportunities': OpportunitySerializer(opportunities, many=True).data,
            'tasks': TaskSerializer(tasks, many=True).data,
            'feedback': FeedbackSerializer(feedback, many=True).data,
            'points': PointsEntrySerializer(points, many=True).data,
            'spend_trend': trend,
        })

    @action(detail=True, methods=['post'], url_path='ensure-profile')
    def ensure_profile(self, request, pk=None):
        customer = self.get_object()
        profile, created = CustomerProfile.objects.get_or_create(customer=customer)
        return Response({
            'created': created,
            'profile': CustomerProfileSerializer(profile).data,
        })

    @action(detail=True, methods=['post'], url_path='recompute-stats')
    def recompute_stats(self, request, pk=None):
        """Recompute lifetime metrics for one customer from POS transactions."""
        customer = self.get_object()
        payload = self._recompute_customer_stats(customer)
        return Response(payload)

    @action(detail=False, methods=['post'], url_path='recompute-all')
    def recompute_all(self, request):
        """Recompute lifetime metrics for every customer in the tenant."""
        updated = 0
        for customer in Customer.objects.all():
            self._recompute_customer_stats(customer)
            updated += 1
        return Response({'updated': updated})

    @staticmethod
    def _recompute_customer_stats(customer):
        from pos.models import POSTransaction

        rows = POSTransaction.objects.filter(customer=customer)
        agg = rows.aggregate(total=Sum('total'), n=Count('id'))
        spend = _dec(agg['total'])
        visits = agg['n'] or 0

        last = rows.order_by('-created_at').values_list('created_at', flat=True).first()

        customer.total_purchases = spend
        customer.visit_count = visits
        changed = customer.recompute_tier()
        customer.save(update_fields=['total_purchases', 'visit_count', 'loyalty_tier', 'updated_at'])

        profile, _ = CustomerProfile.objects.get_or_create(customer=customer)
        profile.lifetime_value = spend
        if last:
            profile.last_purchase_at = last
        profile.save(update_fields=['lifetime_value', 'last_purchase_at', 'updated_at'])

        return {
            'customer_id': customer.id,
            'lifetime_value': float(spend),
            'visit_count': visits,
            'loyalty_tier': customer.loyalty_tier,
            'tier_changed': changed,
            'last_purchase_at': last,
        }

    @action(detail=False, methods=['get'])
    def leaderboard(self, request):
        """Top customers by lifetime value / spend."""
        limit = int(request.query_params.get('limit', 10))
        rows = (
            Customer.objects
            .filter(total_purchases__gt=0)
            .order_by('-total_purchases')[:limit]
        )
        return Response([
            {
                'id': c.id,
                'name': c.name,
                'phone': c.phone,
                'total_purchases': float(c.total_purchases or 0),
                'visit_count': c.visit_count,
                'loyalty_tier': c.loyalty_tier,
                'loyalty_points': c.loyalty_points,
            }
            for c in rows
        ])

    @action(detail=False, methods=['get'])
    def birthdays(self, request):
        """Customers with a birthday in the next N days."""
        days = int(request.query_params.get('days', 30))
        today = timezone.localdate()
        horizon = today + timedelta(days=days)
        qs = CustomerProfile.objects.select_related('customer').filter(
            date_of_birth__isnull=False,
        )
        rows = []
        for p in qs:
            dob = p.date_of_birth
            try:
                this_year = dob.replace(year=today.year)
            except ValueError:  # Feb 29
                this_year = dob.replace(year=today.year, day=28)
            if today <= this_year <= horizon:
                rows.append({
                    'id': p.customer_id,
                    'name': p.customer.name,
                    'phone': p.customer.phone,
                    'date_of_birth': dob,
                    'in_days': (this_year - today).days,
                })
        rows.sort(key=lambda r: r['in_days'])
        return Response(rows)

    @action(detail=False, methods=['post'], url_path='bulk-assign-segment')
    def bulk_assign_segment(self, request):
        ids = request.data.get('customer_ids') or []
        segment_id = request.data.get('segment')
        if not ids:
            return Response({'detail': 'customer_ids is required.'}, status=status.HTTP_400_BAD_REQUEST)
        updated = 0
        for cid in ids:
            profile, _ = CustomerProfile.objects.get_or_create(customer_id=cid)
            profile.segment_id = segment_id
            profile.save(update_fields=['segment', 'updated_at'])
            updated += 1
        return Response({'updated': updated})


# ─────────────────────────────────────────────────────────────────────────
#  Profiles
# ─────────────────────────────────────────────────────────────────────────
class CustomerProfileViewSet(CRMBaseViewSet):
    queryset = CustomerProfile.objects.select_related(
        'customer', 'segment', 'owner',
    ).prefetch_related('tags').all()
    serializer_class = CustomerProfileSerializer
    filterset_fields = ['lifecycle_stage', 'segment', 'owner', 'is_vip', 'preferred_channel', 'lead_source']
    search_fields = ['customer__name', 'customer__phone', 'company', 'customer__email']
    ordering_fields = ['health_score', 'churn_risk', 'lifetime_value', '-updated_at']

    @action(detail=True, methods=['post'], url_path='recompute-health')
    def recompute_health(self, request, pk=None):
        profile = self.get_object()
        now = timezone.now()
        risk = 20
        if profile.last_purchase_at:
            days = (now - profile.last_purchase_at).days
            risk = min(100, max(0, int(days / 1.8)))
        health = max(0, 100 - risk)
        if profile.is_vip:
            health = min(100, health + 10)
        profile.churn_risk = risk
        profile.health_score = health
        profile.save(update_fields=['churn_risk', 'health_score', 'updated_at'])
        return Response(CustomerProfileSerializer(profile).data)


# ─────────────────────────────────────────────────────────────────────────
#  Segments & tags
# ─────────────────────────────────────────────────────────────────────────
class SegmentViewSet(CRMBaseViewSet):
    queryset = Segment.objects.all()
    serializer_class = SegmentSerializer
    filterset_fields = ['is_active', 'kind']
    search_fields = ['name', 'code', 'description']
    ordering_fields = ['name', 'created_at']

    @action(detail=True, methods=['get'])
    def members(self, request, pk=None):
        segment = self.get_object()
        qs = Customer.objects.filter(crm_profile__segment=segment).select_related('crm_profile')
        return Response(CustomerCRMSerializer(qs[:200], many=True).data)


class TagViewSet(CRMBaseViewSet):
    queryset = Tag.objects.all()
    serializer_class = TagSerializer
    search_fields = ['name']
    ordering_fields = ['name']


# ─────────────────────────────────────────────────────────────────────────
#  Interactions
# ─────────────────────────────────────────────────────────────────────────
class InteractionViewSet(CRMBaseViewSet):
    queryset = Interaction.objects.select_related('customer', 'created_by').all()
    serializer_class = InteractionSerializer
    filterset_fields = ['customer', 'kind', 'direction', 'outcome', 'follow_up_required']
    search_fields = ['subject', 'summary', 'customer__name']
    ordering_fields = ['occurred_at', 'created_at']

    def perform_create(self, serializer):
        obj = serializer.save(created_by=self._user() or serializer.validated_data.get('created_by'))
        # Mirror onto the customer profile for quick "last contact" reads.
        profile, _ = CustomerProfile.objects.get_or_create(customer=obj.customer)
        profile.last_contact_at = obj.occurred_at
        profile.last_activity_summary = obj.subject[:255]
        fields = ['last_contact_at', 'last_activity_summary', 'updated_at']
        if obj.follow_up_required and obj.follow_up_at:
            profile.next_follow_up_at = obj.follow_up_at
            fields.append('next_follow_up_at')
        profile.save(update_fields=fields)

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.filter_queryset(self.get_queryset())
        now = timezone.now()
        week_ago = now - timedelta(days=7)
        by_kind = {r['kind']: r['count'] for r in qs.values('kind').annotate(count=Count('id'))}
        return Response({
            'total': qs.count(),
            'this_week': qs.filter(occurred_at__gte=week_ago).count(),
            'follow_ups_open': qs.filter(follow_up_required=True, follow_up_at__gte=now).count(),
            'overdue_follow_ups': qs.filter(follow_up_required=True, follow_up_at__lt=now).count(),
            'by_kind': by_kind,
        })


# ─────────────────────────────────────────────────────────────────────────
#  Tickets
# ─────────────────────────────────────────────────────────────────────────
class TicketViewSet(CRMBaseViewSet):
    queryset = Ticket.objects.select_related('customer', 'assigned_to').all()
    serializer_class = TicketSerializer
    filterset_fields = ['status', 'priority', 'category', 'customer', 'assigned_to']
    search_fields = ['reference', 'subject', 'description', 'customer__name']
    ordering_fields = ['created_at', 'priority', 'sla_due_at', 'opened_at']

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.filter_queryset(self.get_queryset())
        now = timezone.now()
        open_qs = qs.exclude(status__in=['resolved', 'closed'])
        resolved = qs.filter(resolved_at__isnull=False)
        avg_hours = 0
        if resolved.exists():
            total = sum((t.resolved_at - t.opened_at).total_seconds() / 3600 for t in resolved[:200])
            avg_hours = round(total / min(resolved.count(), 200), 1)
        return Response({
            'total': qs.count(),
            'open': qs.filter(status='open').count(),
            'in_progress': qs.filter(status='in_progress').count(),
            'waiting': qs.filter(status='waiting').count(),
            'resolved': resolved.count(),
            'closed': qs.filter(status='closed').count(),
            'urgent': open_qs.filter(priority='urgent').count(),
            'overdue': open_qs.filter(sla_due_at__lt=now).count(),
            'avg_resolution_hours': avg_hours,
            'by_category': {r['category']: r['count'] for r in qs.values('category').annotate(count=Count('id'))},
        })

    @action(detail=True, methods=['post'])
    def resolve(self, request, pk=None):
        ticket = self.get_object()
        ticket.status = Ticket.Status.RESOLVED
        ticket.resolved_at = timezone.now()
        ticket.resolution_notes = request.data.get('resolution_notes', ticket.resolution_notes)
        ticket.save(update_fields=['status', 'resolved_at', 'resolution_notes', 'updated_at'])
        return Response(TicketSerializer(ticket).data)

    @action(detail=True, methods=['post'])
    def assign(self, request, pk=None):
        ticket = self.get_object()
        ticket.assigned_to_id = request.data.get('assigned_to') or None
        if not ticket.first_response_at:
            ticket.first_response_at = timezone.now()
        if ticket.status == Ticket.Status.OPEN:
            ticket.status = Ticket.Status.IN_PROGRESS
        ticket.save(update_fields=['assigned_to', 'first_response_at', 'status', 'updated_at'])
        return Response(TicketSerializer(ticket).data)

    @action(detail=True, methods=['post'], url_path='set-status')
    def set_status(self, request, pk=None):
        ticket = self.get_object()
        new_status = request.data.get('status')
        if new_status not in {c[0] for c in Ticket.Status.choices}:
            return Response({'detail': 'Invalid status.'}, status=status.HTTP_400_BAD_REQUEST)
        ticket.status = new_status
        if new_status in (Ticket.Status.RESOLVED, Ticket.Status.CLOSED):
            ticket.resolved_at = ticket.resolved_at or timezone.now()
        ticket.save(update_fields=['status', 'resolved_at', 'updated_at'])
        return Response(TicketSerializer(ticket).data)


# ─────────────────────────────────────────────────────────────────────────
#  Opportunities
# ─────────────────────────────────────────────────────────────────────────
class OpportunityViewSet(CRMBaseViewSet):
    queryset = Opportunity.objects.select_related('customer', 'owner').all()
    serializer_class = OpportunitySerializer
    filterset_fields = ['stage', 'customer', 'owner']
    search_fields = ['title', 'customer__name', 'source']
    ordering_fields = ['value', 'expected_close_date', 'created_at']

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.filter_queryset(self.get_queryset())
        open_qs = qs.exclude(stage__in=['won', 'lost'])
        won = qs.filter(stage='won')
        lost = qs.filter(stage='lost')
        closed = won.count() + lost.count()
        return Response({
            'total': qs.count(),
            'open': open_qs.count(),
            'won': won.count(),
            'lost': lost.count(),
            'pipeline_value': float(open_qs.aggregate(v=Sum('value'))['v'] or 0),
            'won_value': float(won.aggregate(v=Sum('value'))['v'] or 0),
            'expected_value': float(sum(_dec(o.value) * (o.probability or 0) / 100 for o in open_qs)),
            'win_rate': round(won.count() / closed * 100, 1) if closed else 0,
            'by_stage': {r['stage']: {'count': r['count'], 'value': float(r['value'] or 0)}
                         for r in qs.values('stage').annotate(count=Count('id'), value=Sum('value'))},
        })

    @action(detail=True, methods=['post'], url_path='move-stage')
    def move_stage(self, request, pk=None):
        opp = self.get_object()
        stage = request.data.get('stage')
        if stage not in {c[0] for c in Opportunity.Stage.choices}:
            return Response({'detail': 'Invalid stage.'}, status=status.HTTP_400_BAD_REQUEST)
        opp.stage = stage
        if stage == 'won':
            opp.won_at = timezone.now()
            opp.closed_at = timezone.now()
        elif stage == 'lost':
            opp.closed_at = timezone.now()
            opp.lost_reason = request.data.get('lost_reason', opp.lost_reason)
        opp.save()
        return Response(OpportunitySerializer(opp).data)


# ─────────────────────────────────────────────────────────────────────────
#  Campaigns
# ─────────────────────────────────────────────────────────────────────────
class CampaignViewSet(CRMBaseViewSet):
    queryset = Campaign.objects.select_related('segment', 'owner').all()
    serializer_class = CampaignSerializer
    filterset_fields = ['status', 'channel', 'segment']
    search_fields = ['name', 'notes']
    ordering_fields = ['created_at', 'start_date', 'revenue']

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.filter_queryset(self.get_queryset())
        agg = qs.aggregate(
            budget=Sum('budget'), cost=Sum('actual_cost'), revenue=Sum('revenue'),
            sent=Sum('sent_count'), converted=Sum('converted_count'),
        )
        sent = agg['sent'] or 0
        return Response({
            'total': qs.count(),
            'running': qs.filter(status='running').count(),
            'scheduled': qs.filter(status='scheduled').count(),
            'completed': qs.filter(status='completed').count(),
            'budget': float(agg['budget'] or 0),
            'spend': float(agg['cost'] or 0),
            'revenue': float(agg['revenue'] or 0),
            'sent': sent,
            'converted': agg['converted'] or 0,
            'conversion_rate': round((agg['converted'] or 0) / sent * 100, 1) if sent else 0,
            'by_channel': {r['channel']: r['count'] for r in qs.values('channel').annotate(count=Count('id'))},
        })


# ─────────────────────────────────────────────────────────────────────────
#  Tasks
# ─────────────────────────────────────────────────────────────────────────
class TaskViewSet(CRMBaseViewSet):
    queryset = Task.objects.select_related('customer', 'assigned_to').all()
    serializer_class = TaskSerializer
    filterset_fields = ['status', 'priority', 'customer', 'assigned_to']
    search_fields = ['title', 'description', 'customer__name']
    ordering_fields = ['due_at', 'priority', 'created_at']

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.filter_queryset(self.get_queryset())
        now = timezone.now()
        open_qs = qs.exclude(status__in=['done', 'cancelled'])
        return Response({
            'total': qs.count(),
            'todo': qs.filter(status='todo').count(),
            'in_progress': qs.filter(status='in_progress').count(),
            'done': qs.filter(status='done').count(),
            'overdue': open_qs.filter(due_at__lt=now).count(),
            'due_today': open_qs.filter(due_at__date=timezone.localdate()).count(),
        })

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        task = self.get_object()
        task.status = Task.Status.DONE
        task.completed_at = timezone.now()
        task.save(update_fields=['status', 'completed_at', 'updated_at'])
        return Response(TaskSerializer(task).data)


# ─────────────────────────────────────────────────────────────────────────
#  Feedback
# ─────────────────────────────────────────────────────────────────────────
class FeedbackViewSet(CRMBaseViewSet):
    queryset = Feedback.objects.select_related('customer').all()
    serializer_class = FeedbackSerializer
    filterset_fields = ['kind', 'customer', 'handled']
    search_fields = ['comment', 'customer__name']
    ordering_fields = ['submitted_at', 'score']

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.filter_queryset(self.get_queryset())
        nps_qs = qs.filter(kind='nps')
        promoters = nps_qs.filter(score__gte=9).count()
        detractors = nps_qs.filter(score__lte=6).count()
        total = nps_qs.count()
        nps = round((promoters - detractors) / total * 100, 1) if total else 0
        csat_qs = qs.filter(kind='csat')
        csat = round(
            (csat_qs.aggregate(v=Sum('score'))['v'] or 0) / (csat_qs.count() or 1), 2,
        ) if csat_qs.exists() else 0
        return Response({
            'total': qs.count(),
            'nps': nps,
            'promoters': promoters,
            'passives': total - promoters - detractors,
            'detractors': detractors,
            'csat': csat,
            'unhandled': qs.filter(handled=False).count(),
            'by_kind': {r['kind']: r['count'] for r in qs.values('kind').annotate(count=Count('id'))},
        })


# ─────────────────────────────────────────────────────────────────────────
#  Loyalty points ledger
# ─────────────────────────────────────────────────────────────────────────
class PointsEntryViewSet(CRMBaseViewSet):
    queryset = PointsEntry.objects.select_related('customer').all()
    serializer_class = PointsEntrySerializer
    filterset_fields = ['kind', 'customer']
    search_fields = ['reason', 'reference', 'customer__name']
    ordering_fields = ['created_at', 'points']

    def perform_create(self, serializer):
        entry = serializer.save(created_by=self._user())
        customer = entry.customer
        new_balance = (customer.loyalty_points or 0) + (entry.points or 0)
        customer.loyalty_points = new_balance
        customer.save(update_fields=['loyalty_points', 'updated_at'])
        entry.balance_after = new_balance
        entry.save(update_fields=['balance_after'])

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.filter_queryset(self.get_queryset())
        earned = qs.filter(points__gt=0).aggregate(v=Sum('points'))['v'] or 0
        redeemed = qs.filter(points__lt=0).aggregate(v=Sum('points'))['v'] or 0
        return Response({
            'total_entries': qs.count(),
            'points_earned': earned,
            'points_redeemed': abs(redeemed),
            'net': earned + redeemed,
            'liability_points': Customer.objects.aggregate(v=Sum('loyalty_points'))['v'] or 0,
        })
