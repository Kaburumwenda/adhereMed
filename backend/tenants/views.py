from rest_framework import generics, serializers, status
from rest_framework.permissions import AllowAny, IsAdminUser
from rest_framework.response import Response
from django.db import connection, transaction
from .models import Tenant, Domain
from .serializers import TenantSerializer, TenantRegistrationSerializer


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
            phone=data.get('phone', ''),
            email=data.get('email', ''),
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

        return Response(
            TenantSerializer(tenant).data,
            status=status.HTTP_201_CREATED,
        )
