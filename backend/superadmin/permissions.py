from rest_framework.permissions import BasePermission


class IsSuperAdmin(BasePermission):
    """Allow access only to users with role='super_admin'."""

    message = "Only super admins can access this endpoint."

    def has_permission(self, request, view):
        return (
            request.user
            and request.user.is_authenticated
            and request.user.role == "super_admin"
        )
