from rest_framework import viewsets, generics, filters, status, permissions
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django_filters.rest_framework import DjangoFilterBackend

from accounts.serializers import UserSerializer
from .models import DoctorProfile
from .serializers import (
    DoctorProfileSerializer,
    DoctorRegistrationSerializer,
    DoctorDirectorySerializer,
)


class DoctorRegisterView(generics.CreateAPIView):
    """Public endpoint for doctor self-registration."""
    serializer_class = DoctorRegistrationSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile = serializer.save()

        refresh = RefreshToken.for_user(profile.user)
        return Response({
            'user': UserSerializer(profile.user).data,
            'doctor_profile': DoctorProfileSerializer(profile).data,
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            },
        }, status=status.HTTP_201_CREATED)


class DoctorDirectoryViewSet(viewsets.ReadOnlyModelViewSet):
    """Public directory of all verified, accepting doctors."""
    serializer_class = DoctorDirectorySerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['practice_type', 'is_accepting_patients', 'specialization']
    search_fields = ['user__first_name', 'user__last_name', 'specialization']
    ordering_fields = ['specialization', 'years_of_experience', 'consultation_fee', 'created_at']

    def get_queryset(self):
        return DoctorProfile.objects.select_related('user', 'hospital').filter(
            is_accepting_patients=True,
            user__is_active=True,
        )


class MyDoctorProfileView(generics.RetrieveUpdateAPIView):
    """Lets the logged-in doctor view/update their own profile."""
    serializer_class = DoctorProfileSerializer

    def get_object(self):
        return DoctorProfile.objects.select_related('user', 'hospital').get(
            user=self.request.user,
        )
