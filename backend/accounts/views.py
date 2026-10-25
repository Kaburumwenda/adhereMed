from rest_framework import generics, status, permissions, viewsets as _viewsets
from rest_framework import decorators as _decorators
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.pagination import PageNumberPagination as _pagination
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth.tokens import default_token_generator
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from django.utils.encoding import force_bytes, force_str
from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters as _filters
from django.conf import settings
from .models import User
from .serializers import (
    UserSerializer,
    UserManagementSerializer,
    UserRegistrationSerializer,
    LoginSerializer,
    ChangePasswordSerializer,
    PasswordResetRequestSerializer,
    PasswordResetConfirmSerializer,
)


class RegisterView(generics.CreateAPIView):
    serializer_class = UserRegistrationSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserSerializer(user).data,
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }
        }, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']

        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserSerializer(user).data,
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }
        })


class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer

    def get_object(self):
        return self.request.user


class ChangePasswordView(APIView):
    def post(self, request):
        serializer = ChangePasswordSerializer(
            data=request.data, context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        request.user.set_password(serializer.validated_data['new_password'])
        request.user.save()
        return Response({'detail': 'Password updated successfully.'})


class LogoutView(APIView):
    def post(self, request):
        try:
            token = RefreshToken(request.data.get('refresh'))
            token.blacklist()
        except Exception:
            pass
        return Response({'detail': 'Logged out successfully.'})


class PasswordResetRequestView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data['email']

        # Always return success to prevent email enumeration
        try:
            user = User.objects.get(email=email, is_active=True)
        except User.DoesNotExist:
            return Response({'detail': 'If that email exists, a reset link has been sent.'})

        uid = urlsafe_base64_encode(force_bytes(user.pk))
        token = default_token_generator.make_token(user)
        frontend_url = getattr(settings, 'FRONTEND_URL', 'http://localhost:3000')
        reset_link = f'{frontend_url}/#/reset-password?uid={uid}&token={token}'

        context = {'user': user, 'reset_link': reset_link}
        html_message = render_to_string('emails/password_reset.html', context)
        plain_message = strip_tags(html_message)

        send_mail(
            subject='AfyaOne - Password Reset',
            message=plain_message,
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            html_message=html_message,
            fail_silently=True,
        )
        return Response({'detail': 'If that email exists, a reset link has been sent.'})


class PasswordResetConfirmView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            uid = force_str(urlsafe_base64_decode(serializer.validated_data['uid']))
            user = User.objects.get(pk=uid)
        except (TypeError, ValueError, OverflowError, User.DoesNotExist):
            return Response(
                {'detail': 'Invalid reset link.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not default_token_generator.check_token(user, serializer.validated_data['token']):
            return Response(
                {'detail': 'Reset link has expired or is invalid.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.set_password(serializer.validated_data['new_password'])
        user.save()
        return Response({'detail': 'Password has been reset successfully.'})


class VerifyPinView(APIView):
    """Confirm a PIN belongs to the currently logged-in user."""

    def post(self, request):
        pin = str(request.data.get('pin', '')).strip()
        if not pin:
            return Response(
                {'detail': 'PIN is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not request.user.pin or request.user.pin != pin:
            return Response(
                {'detail': 'PIN does not match the logged-in user.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return Response({
            'valid': True,
            'user_id': request.user.id,
            'role': request.user.role,
            'full_name': request.user.full_name,
        })


class VerifyPasswordView(APIView):
    """Confirm the currently logged-in user's password.

    Used by the frontend as a re-authentication step before destructive actions
    (e.g. approving or cancelling a stock transfer). Pure precondition check —
    does NOT issue new JWT tokens or modify session state.
    """

    def post(self, request):
        password = str(request.data.get('password', ''))
        if not password:
            return Response(
                {'detail': 'Password is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not request.user.check_password(password):
            return Response(
                {'detail': 'Incorrect password.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return Response({
            'valid': True,
            'user_id': request.user.id,
            'full_name': request.user.full_name,
        })


class RegeneratePinView(APIView):
    """Issue a fresh unique PIN for the current user."""

    def post(self, request):
        from .models import _generate_unique_pin
        request.user.pin = _generate_unique_pin()
        request.user.save(update_fields=['pin'])
        return Response({'pin': request.user.pin})


# ---------------------------------------------------------------------------
# Lightweight serializer + list view for selecting clinical staff (doctors,
# clinical officers, nurses, tenant admins) in form dropdowns.  Exposed at
# /api/auth/staff/ so the frontend can populate "Doctor / Staff" picks without
# relying on StaffProfile records (which may not exist for every tenant).
# ---------------------------------------------------------------------------
from rest_framework import serializers as _serializers


class StaffListItemSerializer(_serializers.ModelSerializer):
    full_name = _serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'full_name', 'email', 'role', 'phone', 'is_active']
        read_only_fields = fields

    def get_full_name(self, obj):
        return f'{obj.first_name} {obj.last_name}'.strip() or obj.email


class StaffListView(generics.ListAPIView):
    """Return active users with clinical / administrative roles.

    Query params:
        search   — case-insensitive match on full_name or email
        roles    — comma-separated role override list
        page_size — standard DRF pagination
    """
    serializer_class = StaffListItemSerializer

    class _Pagination(_pagination):
        page_size = 100
        page_size_query_param = 'page_size'
        max_page_size = 5000

    pagination_class = _Pagination

    def get_queryset(self):
        roles_param = self.request.query_params.get('roles', '')
        if roles_param:
            roles = [r.strip() for r in roles_param.split(',') if r.strip()]
        else:
            roles = [
                'doctor', 'clinical_officer', 'nurse', 'pharmacist',
                'lab_tech', 'radiographer', 'tenant_admin', 'admin',
            ]
        qs = User.objects.filter(is_active=True, role__in=roles).order_by('first_name', 'last_name')
        # Scope to the active request tenant (set by HeaderTenantMiddleware).
        req_tenant = getattr(self.request, 'tenant', None)
        u = self.request.user
        if not getattr(u, 'is_superuser', False):
            if req_tenant and req_tenant.pk != u.tenant_id:
                qs = qs.filter(tenant_id=req_tenant.pk)
            elif u.tenant_id:
                qs = qs.filter(tenant_id=u.tenant_id)
        search = self.request.query_params.get('search', '').strip()
        if search:
            from django.db.models import Q
            qs = qs.filter(
                Q(first_name__icontains=search)
                | Q(last_name__icontains=search)
                | Q(email__icontains=search)
            )
        return qs


class IsTenantAdminOrSuperAdmin(permissions.BasePermission):
    """Only tenant admins, clinic/hospital/pharmacy admins, or the super admin may manage users."""
    ADMIN_ROLES = {'super_admin', 'tenant_admin', 'clinic_admin', 'hospital_admin',
                    'pharmacy_admin', 'lab_admin', 'radiology_admin', 'homecare_admin',
                    'inventory_admin', 'admin'}

    def has_permission(self, request, view):
        u = request.user
        if not (u and u.is_authenticated):
            return False
        if getattr(u, 'is_superuser', False):
            return True
        return u.role in self.ADMIN_ROLES


class UserManagementViewSet(_viewsets.GenericViewSet,
                            generics.mixins.ListModelMixin,
                            generics.mixins.CreateModelMixin,
                            generics.mixins.RetrieveModelMixin,
                            generics.mixins.UpdateModelMixin,
                            generics.mixins.DestroyModelMixin):
    """CRUD for tenant admins to manage staff users within their tenant.

    Mounted at /api/auth/users/<id>/ so the clinic/hospital staff pages can
    list, create, patch, and delete users without needing a separate app.
    """
    permission_classes = [IsTenantAdminOrSuperAdmin]
    serializer_class = UserManagementSerializer
    filter_backends = [DjangoFilterBackend, _filters.SearchFilter, _filters.OrderingFilter]
    search_fields = ['first_name', 'last_name', 'email', 'role']
    ordering_fields = ['first_name', 'last_name', 'email', 'role', 'date_joined']
    ordering = ['first_name', 'last_name']

    class _Pagination(_pagination):
        page_size = 100
        page_size_query_param = 'page_size'
        max_page_size = 5000
    pagination_class = _Pagination

    def get_queryset(self):
        u = self.request.user
        qs = User.objects.exclude(role=User.Role.PATIENT).exclude(
            role=User.Role.SUPER_ADMIN
        ).order_by('first_name', 'last_name')
        if getattr(u, 'is_superuser', False):
            # Super admin sees all users.
            return qs
        # Use the request tenant (set by HeaderTenantMiddleware from X-Tenant-Schema)
        # when available — an org admin may switch between linked tenants, so we
        # want the users of the *active* tenant, not the admin's home tenant.
        req_tenant = getattr(self.request, 'tenant', None)
        if req_tenant and req_tenant.pk != u.tenant_id:
            qs = qs.filter(tenant_id=req_tenant.pk)
        elif u.tenant_id:
            qs = qs.filter(tenant_id=u.tenant_id)
        return qs

    def perform_create(self, serializer):
        # Force the new user into the active request tenant (unless super admin).
        u = self.request.user
        instance = serializer.save()
        if getattr(u, 'is_superuser', False):
            return
        req_tenant = getattr(self.request, 'tenant', None)
        target_tenant = req_tenant or u.tenant
        if target_tenant and not instance.tenant_id:
            instance.tenant = target_tenant
            instance.save()

    # ── Staff overview (premium staff page) ─────────────────────────────
    CLINICAL_ROLES = {
        'doctor', 'clinical_officer', 'dentist', 'nurse', 'midwife',
        'lab_tech', 'radiologist', 'pharmacist', 'pharmacy_tech',
    }

    @_decorators.action(detail=False, methods=['get'], url_path='overview')
    def overview(self, request):
        """Roster + workload aggregates for the staff directory page.

        Every cross-app aggregate is guarded: a tenant schema can be missing an
        optional table, and the directory must still render.
        """
        from datetime import timedelta
        from django.db.models import Count
        from django.utils import timezone

        qs = self.get_queryset()
        users = list(qs)
        user_ids = [u.id for u in users]
        today = timezone.localdate()
        month_start = today.replace(day=1)
        since = timezone.now() - timedelta(days=30)

        consultations = {}
        appointments_today = {}
        appointments_upcoming = {}
        visits_30d = {}
        try:
            from consultations.models import Consultation
            rows = (
                Consultation.objects
                .filter(doctor_id__in=user_ids, created_at__gte=since)
                .values('doctor_id').annotate(n=Count('id'))
            )
            consultations = {r['doctor_id']: r['n'] for r in rows}
        except Exception:
            pass
        try:
            from appointments.models import Appointment
            rows = (
                Appointment.objects
                .filter(staff_id__in=user_ids, appointment_date=today)
                .exclude(status__in=['cancelled', 'no_show'])
                .values('staff_id').annotate(n=Count('id'))
            )
            appointments_today = {r['staff_id']: r['n'] for r in rows}
            rows = (
                Appointment.objects
                .filter(staff_id__in=user_ids, appointment_date__gt=today)
                .exclude(status__in=['cancelled', 'no_show'])
                .values('staff_id').annotate(n=Count('id'))
            )
            appointments_upcoming = {r['staff_id']: r['n'] for r in rows}
        except Exception:
            pass
        try:
            from visits.models import PatientVisit
            rows = (
                PatientVisit.objects
                .filter(doctor_id__in=user_ids, arrived_at__date__gte=month_start)
                .values('doctor_id').annotate(n=Count('id'))
            )
            visits_30d = {r['doctor_id']: r['n'] for r in rows}
        except Exception:
            pass

        # Optional professional details — present only where staff profiles exist.
        profiles = {}
        try:
            from staff_profiles.models import StaffProfile
            rows = (
                StaffProfile.objects
                .filter(user_id__in=user_ids)
                .select_related('department', 'specialization')
            )
            for p in rows:
                profiles[p.user_id] = p
        except Exception:
            profiles = {}

        roster = []
        for u in users:
            profile = profiles.get(u.id)
            department = getattr(getattr(profile, 'department', None), 'name', '') or ''
            specialization = getattr(getattr(profile, 'specialization', None), 'name', '') or ''
            roster.append({
                'id': u.id,
                'full_name': ' '.join(
                    p for p in [u.first_name, u.middle_name, u.last_name] if p
                ).strip() or u.email,
                'first_name': u.first_name,
                'middle_name': u.middle_name,
                'last_name': u.last_name,
                'initials': (
                    (u.first_name or ' ')[:1] + (u.last_name or ' ')[:1]
                ).strip().upper() or '?',
                'email': u.email,
                'phone': u.phone,
                'role': u.role,
                'role_label': u.get_role_display() if hasattr(u, 'get_role_display') else u.role,
                'is_active': u.is_active,
                'is_clinical': u.role in self.CLINICAL_ROLES,
                'date_joined': u.date_joined,
                'last_login': u.last_login,
                'department': department,
                'specialization': specialization,
                'license_number': getattr(profile, 'license_number', '') or '',
                'qualification': getattr(profile, 'qualification', '') or '',
                'years_of_experience': getattr(profile, 'years_of_experience', 0) or 0,
                'is_available': getattr(profile, 'is_available', True),
                'has_profile': bool(profile),
                'consultations_30d': consultations.get(u.id, 0),
                'appointments_today': appointments_today.get(u.id, 0),
                'appointments_upcoming': appointments_upcoming.get(u.id, 0),
                'visits_month': visits_30d.get(u.id, 0),
            })

        role_counts = {}
        for row in roster:
            role_counts[row['role']] = role_counts.get(row['role'], 0) + 1

        clinical = sum(1 for u in users if u.role in self.CLINICAL_ROLES)
        admins = sum(
            1 for u in users
            if u.role in {'tenant_admin', 'clinic_admin', 'admin', 'branch_admin'}
        )
        inactive = sum(1 for u in users if not u.is_active)
        new_this_month = sum(
            1 for u in users if u.date_joined and u.date_joined.date() >= month_start
        )

        return Response({
            'generated_at': timezone.now(),
            'kpis': {
                'total': len(users),
                'active': len(users) - inactive,
                'inactive': inactive,
                'clinical': clinical,
                'admin': admins,
                'new_this_month': new_this_month,
                'on_shift_today': sum(
                    1 for u in users
                    if appointments_today.get(u.id, 0) > 0 and u.is_active
                ),
                'consultations_30d': sum(consultations.values()),
                'visits_month': sum(visits_30d.values()),
            },
            'roles': [
                {
                    'role': role,
                    'label': dict(User.Role.choices).get(
                        role, role.replace('_', ' ').title(),
                    ),
                    'count': count,
                }
                for role, count in sorted(role_counts.items(), key=lambda i: -i[1])
            ],
            'staff': roster,
        })


# ---------------------------------------------------------------------------
# Roles & Permissions (IAM & Security)
# ---------------------------------------------------------------------------

from django.contrib.auth.models import Group, Permission


class RolePermissionViewSet(_viewsets.ModelViewSet):
    """CRUD for tenant roles (auth.Group) with permission assignment.

    Mounted at:
        /api/auth/roles/                 -> list / create
        /api/auth/roles/<id>/              -> retrieve / update / destroy
        /api/auth/permissions/             -> list all available permissions
    """
    permission_classes = [IsTenantAdminOrSuperAdmin]
    filter_backends = [DjangoFilterBackend, _filters.SearchFilter, _filters.OrderingFilter]
    search_fields = ['name']
    ordering_fields = ['name']
    ordering = ['name']

    class _Pagination(_pagination):
        page_size = 100
        page_size_query_param = 'page_size'
        max_page_size = 5000
    pagination_class = _Pagination

    def get_serializer_class(self):
        from .serializers import RoleSerializer
        return RoleSerializer

    def get_queryset(self):
        qs = Group.objects.all().order_by('name')
        search = self.request.query_params.get('search', '').strip()
        if search:
            qs = qs.filter(name__icontains=search)
        return qs


class PermissionListView(generics.ListAPIView):
    """List all Django auth Permissions available in this tenant schema."""
    permission_classes = [IsTenantAdminOrSuperAdmin]

    def get_serializer_class(self):
        from .serializers import PermissionSerializer
        return PermissionSerializer

    def list(self, request, *args, **kwargs):
        qs = Permission.objects.select_related('content_type').order_by(
            'content_type__app_label', 'content_type__model', 'codename'
        )
        data = [
            {
                'id': p.id,
                'name': p.name,
                'codename': p.codename,
                'app_label': p.content_type.app_label if p.content_type else '',
                'model': p.content_type.model if p.content_type else '',
            }
            for p in qs
        ]
        return Response({'results': data, 'count': len(data)})

