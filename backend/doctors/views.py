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

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx['request'] = self.request
        return ctx


class UploadDoctorPictureView(generics.GenericAPIView):
    """PATCH /doctors/me/upload-picture/ — multipart profile picture upload."""
    serializer_class = DoctorProfileSerializer

    def patch(self, request, *args, **kwargs):
        profile = DoctorProfile.objects.get(user=request.user)
        picture = request.FILES.get('profile_picture')
        if picture is None:
            return Response(
                {'detail': 'No file provided. Send a multipart/form-data request with field "profile_picture".'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        # Validate MIME type
        content_type = getattr(picture, 'content_type', '')
        if not content_type.startswith('image/'):
            return Response(
                {'detail': 'Only image files are accepted.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        # Delete old picture to avoid orphan files
        if profile.profile_picture:
            profile.profile_picture.delete(save=False)
        profile.profile_picture = picture
        profile.save(update_fields=['profile_picture'])
        serializer = self.get_serializer(profile, context={'request': request})
        return Response(serializer.data)


class UploadDoctorSignatureView(generics.GenericAPIView):
    """PATCH /doctors/me/upload-signature/ — saves the doctor's digital signature."""
    serializer_class = DoctorProfileSerializer

    def patch(self, request, *args, **kwargs):
        profile = DoctorProfile.objects.get(user=request.user)
        signature_file = request.FILES.get('signature')
        if signature_file is None:
            return Response(
                {'detail': 'No file provided. Send multipart/form-data with field "signature".'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        content_type = getattr(signature_file, 'content_type', '')
        if not content_type.startswith('image/'):
            return Response(
                {'detail': 'Only image files are accepted.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if profile.signature:
            profile.signature.delete(save=False)
        profile.signature = signature_file
        profile.save(update_fields=['signature'])
        serializer = self.get_serializer(profile, context={'request': request})
        return Response(serializer.data)


class DeleteDoctorSignatureView(generics.GenericAPIView):
    """DELETE /doctors/me/upload-signature/ — removes the stored signature."""
    serializer_class = DoctorProfileSerializer

    def delete(self, request, *args, **kwargs):
        profile = DoctorProfile.objects.get(user=request.user)
        if profile.signature:
            profile.signature.delete(save=False)
            profile.save(update_fields=['signature'])
        serializer = self.get_serializer(profile, context={'request': request})
        return Response(serializer.data)
