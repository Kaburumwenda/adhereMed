from rest_framework import serializers

from .models import Appointment


class AppointmentSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    staff_name = serializers.CharField(source='staff.full_name', read_only=True)
    department_name = serializers.CharField(source='department.name', read_only=True)
    clinic_site_name = serializers.CharField(source='clinic_site.name', read_only=True, default=None)

    class Meta:
        model = Appointment
        fields = [
            'id', 'patient', 'patient_name',
            'staff', 'staff_name',
            'department', 'department_name',
            'clinic_site', 'clinic_site_name',
            'appointment_date', 'appointment_time', 'duration_minutes',
            'status', 'reason', 'notes',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
