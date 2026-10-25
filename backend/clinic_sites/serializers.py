from rest_framework import serializers

from .models import ClinicSite


class ClinicSiteSerializer(serializers.ModelSerializer):
    manager_name = serializers.SerializerMethodField()
    display_name = serializers.CharField(read_only=True)
    counts = serializers.SerializerMethodField()

    class Meta:
        model = ClinicSite
        fields = [
            'id', 'profile',
            'name', 'code', 'display_name', 'kind',
            'is_hq', 'is_active',
            'address', 'place_name', 'city', 'phone', 'email',
            'latitude', 'longitude',
            'license_number', 'bed_capacity',
            'opening_hours', 'services',
            'manager', 'manager_name',
            'notes', 'counts',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'display_name', 'counts', 'created_at', 'updated_at']

    def get_manager_name(self, obj):
        user = obj.manager
        if not user:
            return None
        return getattr(user, 'full_name', '') or user.email or None

    def get_counts(self, obj):
        """Per-site volume counters.

        The viewset precomputes these with four grouped aggregates and hangs
        the result off ``obj._counts``; falling back to per-field queries here
        would issue four extra queries per row.
        """
        precomputed = getattr(obj, '_counts', None)
        if precomputed is not None:
            return {
                key: int(precomputed.get(key) or 0)
                for key in ('patients', 'appointments', 'consultations', 'invoices')
            }
        return {
            key: self._count(key, obj)
            for key in ('patients', 'appointments', 'consultations', 'invoices')
        }

    @staticmethod
    def _count(label, site):
        try:
            if label == 'patients':
                from patients.models import Patient
                return Patient.objects.filter(clinic_site=site).count()
            if label == 'appointments':
                from appointments.models import Appointment
                return Appointment.objects.filter(clinic_site=site).count()
            if label == 'consultations':
                from consultations.models import Consultation
                return Consultation.objects.filter(clinic_site=site).count()
            if label == 'invoices':
                from billing.models import Invoice
                return Invoice.objects.filter(clinic_site=site).count()
        except Exception:  # noqa: BLE001 - a site can be listed before apps migrate
            return 0
        return 0

    def validate(self, attrs):
        kind = attrs.get('kind', getattr(self.instance, 'kind', ClinicSite.Kind.BRANCH))
        is_hq = attrs.get('is_hq', getattr(self.instance, 'is_hq', False))
        if is_hq and kind != ClinicSite.Kind.HQ:
            attrs['kind'] = ClinicSite.Kind.HQ
        if not is_hq and kind == ClinicSite.Kind.HQ and self.instance is not None \
                and self.instance.is_hq:
            # Demoting the current HQ is allowed; keep the kind coherent.
            attrs['kind'] = ClinicSite.Kind.BRANCH
        if attrs.get('is_hq') and self.instance is None:
            # Only one HQ may exist; the model demotes the previous one.
            pass
        name = attrs.get('name', getattr(self.instance, 'name', ''))
        if not str(name or '').strip():
            raise serializers.ValidationError({'name': 'A clinic name is required.'})
        return attrs
