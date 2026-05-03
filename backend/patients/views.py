import uuid
import secrets

from django.contrib.auth import get_user_model
from rest_framework import viewsets, filters, status
from rest_framework.generics import CreateAPIView
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from .models import Patient
from .serializers import PatientSerializer, PatientRegistrationSerializer

User = get_user_model()


def _to_list(val):
    """Accept a string or list for allergies / chronic_conditions."""
    if not val:
        return []
    if isinstance(val, list):
        return val
    return [v.strip() for v in str(val).split(',') if v.strip()]


class PatientViewSet(viewsets.ModelViewSet):
    queryset = Patient.objects.select_related('user').all()
    serializer_class = PatientSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['gender', 'blood_type']
    search_fields = ['patient_number', 'user__first_name', 'user__last_name']
    ordering_fields = ['created_at', 'patient_number']

    def create(self, request, *args, **kwargs):
        data = request.data
        email = data.get('email', '').strip()
        if not email:
            return Response({'email': ['Email is required.']}, status=status.HTTP_400_BAD_REQUEST)
        if User.objects.filter(email=email).exists():
            return Response({'email': ['A user with this email already exists.']}, status=status.HTTP_400_BAD_REQUEST)

        password = data.get('password') or secrets.token_urlsafe(12)
        user = User(
            email=email,
            first_name=data.get('first_name', ''),
            last_name=data.get('last_name', ''),
            phone=data.get('phone', ''),
            role=User.Role.PATIENT,
        )
        user.set_password(password)
        user.save()

        patient = Patient.objects.create(
            user=user,
            patient_number=f'PT-{uuid.uuid4().hex[:8].upper()}',
            date_of_birth=data.get('date_of_birth') or '1900-01-01',
            gender=data.get('gender') or 'other',
            blood_type=data.get('blood_type') or data.get('blood_group', ''),
            national_id=data.get('national_id') or data.get('id_number', ''),
            address=data.get('address', ''),
            allergies=_to_list(data.get('allergies', [])),
            chronic_conditions=_to_list(data.get('chronic_conditions', [])),
            emergency_contact_name=data.get('emergency_contact_name', ''),
            emergency_contact_phone=data.get('emergency_contact_phone', ''),
            emergency_contact_relation=data.get('emergency_contact_relation', ''),
            insurance_provider=data.get('insurance_provider', ''),
            insurance_number=data.get('insurance_number') or data.get('insurance_policy_number', ''),
        )
        return Response(PatientSerializer(patient).data, status=status.HTTP_201_CREATED)

    def partial_update(self, request, *args, **kwargs):
        patient = self.get_object()
        data = request.data

        # Patient profile fields (with frontend alias support)
        profile_map = {
            'date_of_birth': 'date_of_birth',
            'gender': 'gender',
            'address': 'address',
            'emergency_contact_name': 'emergency_contact_name',
            'emergency_contact_phone': 'emergency_contact_phone',
            'emergency_contact_relation': 'emergency_contact_relation',
            'insurance_provider': 'insurance_provider',
        }
        for src, dest in profile_map.items():
            if src in data:
                setattr(patient, dest, data[src])

        # Field name aliases
        if 'blood_type' in data:
            patient.blood_type = data['blood_type']
        elif 'blood_group' in data:
            patient.blood_type = data['blood_group']
        if 'national_id' in data:
            patient.national_id = data['national_id']
        elif 'id_number' in data:
            patient.national_id = data['id_number']
        if 'insurance_number' in data:
            patient.insurance_number = data['insurance_number']
        elif 'insurance_policy_number' in data:
            patient.insurance_number = data['insurance_policy_number']
        if 'allergies' in data:
            patient.allergies = _to_list(data['allergies'])
        if 'chronic_conditions' in data:
            patient.chronic_conditions = _to_list(data['chronic_conditions'])
        patient.save()

        # Update user fields
        user = patient.user
        user_changed = False
        for f in ['first_name', 'last_name', 'email', 'phone']:
            if f in data and data[f]:
                setattr(user, f, data[f])
                user_changed = True
        if user_changed:
            user.save()

        return Response(PatientSerializer(patient).data)


class PatientRegistrationView(CreateAPIView):
    serializer_class = PatientRegistrationSerializer
