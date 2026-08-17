from rest_framework import generics, status, permissions, viewsets as _viewsets
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
                    'pharmacy_admin', 'lab_admin', 'radiology_admin', 'homecare_admin', 'admin'}

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
        # Tenant admins only see their own tenant's users; super admin sees all.
        if not getattr(u, 'is_superuser', False) and u.tenant_id:
            qs = qs.filter(tenant_id=u.tenant_id)
        return qs

    def perform_create(self, serializer):
        # Force the new user into the admin's tenant (unless super admin).
        u = self.request.user
        instance = serializer.save()
        if not getattr(u, 'is_superuser', False) and u.tenant_id and not instance.tenant_id:
            instance.tenant = u.tenant
            instance.save()


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

