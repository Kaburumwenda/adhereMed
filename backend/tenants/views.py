from rest_framework import generics, serializers, status
from rest_framework.permissions import AllowAny, IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.db import connection, transaction
from .models import Tenant, Domain
from .serializers import (
    TenantSerializer, TenantRegistrationSerializer, TenantProfileSerializer,
)


# Roles allowed to update their tenant's organization profile (viewing is
# allowed for every authenticated member of the tenant).
TENANT_PROFILE_ADMIN_ROLES = {
    'super_admin', 'tenant_admin', 'clinic_admin', 'hospital_admin',
    'pharmacy_admin', 'lab_admin', 'radiology_admin', 'homecare_admin',
    'inventory_admin', 'admin',
}


class TenantListView(generics.ListAPIView):
    queryset = Tenant.objects.filter(is_active=True)
    serializer_class = TenantSerializer
    permission_classes = [IsAdminUser]
    search_fields = ['name', 'slug']
    filterset_fields = ['type', 'is_active']


class PublicHospitalListView(generics.ListAPIView):
    """Public endpoint returning active hospitals (id + name) for registration forms."""
    permission_classes = [AllowAny]
    serializer_class = TenantSerializer  # overridden in get_serializer_class

    class _Serializer(serializers.ModelSerializer):
        class Meta:
            model = Tenant
            fields = ['id', 'name']

    def get_serializer_class(self):
        return self._Serializer

    def get_queryset(self):
        return Tenant.objects.filter(is_active=True, type='hospital').order_by('name')


class TenantDetailView(generics.RetrieveAPIView):
    queryset = Tenant.objects.all()
    serializer_class = TenantSerializer
    permission_classes = [IsAdminUser]
    lookup_field = 'slug'


class TenantRegistrationView(generics.CreateAPIView):
    serializer_class = TenantRegistrationSerializer
    permission_classes = [AllowAny]

    @transaction.atomic
    def create(self, request, *args, **kwargs):
        # Tenant creation must happen in the public schema
        connection.set_schema_to_public()

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        tenant = Tenant.objects.create(
            name=data['name'],
            type=data['type'],
            slug=data['slug'],
            schema_name=data['slug'].replace('-', '_'),
            address=data.get('address', ''),
            city=data.get('city', ''),
            country=data.get('country', 'Kenya'),
            phone=data.get('phone', ''),
            email=data.get('email', ''),
            latitude=data.get('latitude'),
            longitude=data.get('longitude'),
            place_name=data.get('place_name', ''),
        )

        Domain.objects.create(
            domain=data['domain'],
            tenant=tenant,
            is_primary=True,
        )

        from accounts.models import User
        user = User.objects.create_user(
            email=data['admin_email'],
            password=data['admin_password'],
            first_name=data['admin_first_name'],
            last_name=data['admin_last_name'],
            role=User.Role.TENANT_ADMIN,
            tenant=tenant,
        )

        from accounts.tasks import send_welcome_email
        send_welcome_email(user.id)

        # ── Referral system: create profile for new tenant ────────────
        from usage_billing.referral_models import CoinTransaction, Referral, ReferralProfile
        new_profile = ReferralProfile.objects.create(tenant=tenant)

        # ── Auto-grant 300 coins for new pharmacy / inventory accounts ───
        if tenant.type in ('pharmacy', 'inventory'):
            new_profile.credit(300, 'Welcome bonus: 300 Adhere Coins on registration')

        referral_code = data.get('referral_code', '').strip().upper()
        if referral_code:
            try:
                referrer_profile = ReferralProfile.objects.select_related('tenant').get(
                    referral_code=referral_code,
                )
                # Don't allow self-referral
                if referrer_profile.tenant_id != tenant.id:
                    Referral.objects.create(
                        referrer=referrer_profile.tenant,
                        referred=tenant,
                        status=Referral.Status.ACTIVE,
                        bonus_awarded=True,
                    )
                    # Award 100 Adhere Coins to the referrer
                    referrer_profile.credit(
                        100,
                        f'Referral bonus: {tenant.name} joined using your code',
                        related_tenant=tenant,
                    )
                    referrer_profile.referral_count += 1
                    referrer_profile.save(update_fields=['referral_count'])
            except ReferralProfile.DoesNotExist:
                pass  # Invalid code — silently ignore

        return Response(
            TenantSerializer(tenant).data,
            status=status.HTTP_201_CREATED,
        )


class TenantMeView(APIView):
    """Organization profile self-service.

    GET   /tenants/me/  -> full tenant details (any authenticated member)
    PATCH /tenants/me/  -> update editable details (tenant admin roles only)
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    @staticmethod
    def _get_tenant(request):
        tenant = getattr(request, 'tenant', None) or getattr(request.user, 'tenant', None)
        if tenant is None or getattr(tenant, 'schema_name', 'public') == 'public':
            return None
        return tenant

    def get(self, request):
        tenant = self._get_tenant(request)
        if tenant is None:
            return Response(
                {'detail': 'No organization is associated with this account.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(
            TenantSerializer(tenant, context={'request': request}).data
        )

    def patch(self, request):
        tenant = self._get_tenant(request)
        if tenant is None:
            return Response(
                {'detail': 'No organization is associated with this account.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        if request.user.role not in TENANT_PROFILE_ADMIN_ROLES:
            return Response(
                {'detail': 'You do not have permission to update the organization profile.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = TenantProfileSerializer(
            tenant, data=request.data, partial=True,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(
            TenantSerializer(tenant, context={'request': request}).data
        )


class TenantMeLogoUploadView(APIView):
    """POST /tenants/me/upload-logo/ (multipart) — update the org logo."""
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        tenant = getattr(request, 'tenant', None) or getattr(request.user, 'tenant', None)
        if tenant is None or getattr(tenant, 'schema_name', 'public') == 'public':
            return Response(
                {'detail': 'No organization is associated with this account.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        if request.user.role not in TENANT_PROFILE_ADMIN_ROLES:
            return Response(
                {'detail': 'You do not have permission to update the organization profile.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        logo = request.FILES.get('logo')
        if not logo:
            return Response({'detail': 'No logo file provided.'}, status=status.HTTP_400_BAD_REQUEST)
        # Housekeeping: replace the previous file to avoid orphaned uploads.
        if tenant.logo:
            try:
                tenant.logo.delete(save=False)
            except Exception:
                pass
        tenant.logo = logo
        tenant.save(update_fields=['logo'])
        return Response(
            TenantSerializer(tenant, context={'request': request}).data
        )
