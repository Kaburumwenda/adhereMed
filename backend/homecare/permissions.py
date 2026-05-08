from rest_framework import permissions

HOMECARE_STAFF_ROLES = {'tenant_admin', 'homecare_admin', 'admin', 'super_admin', 'caregiver'}
HOMECARE_ADMIN_ROLES = {'tenant_admin', 'homecare_admin', 'admin', 'super_admin'}


class IsHomecareStaff(permissions.BasePermission):
    """Allow homecare admins and caregivers."""

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.role in HOMECARE_STAFF_ROLES


class IsHomecareAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.role in HOMECARE_ADMIN_ROLES


class IsHomecareStaffOrPatient(permissions.BasePermission):
    """Staff have full access; patients can read/write only their own records."""

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.role in HOMECARE_STAFF_ROLES or request.user.role == 'patient'

    def has_object_permission(self, request, view, obj):
        if request.user.role in HOMECARE_STAFF_ROLES:
            return True
        # Patient: object must reference them
        patient_user_id = getattr(getattr(obj, 'patient', None), 'user_id', None)
        if patient_user_id is None:
            patient_user_id = getattr(obj, 'user_id', None)
        return patient_user_id == request.user.id
