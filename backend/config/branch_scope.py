"""
Branch-scoping mixin for DRF viewsets.

Automatically filters querysets by the requesting user's assigned branch
for non-admin roles. Tenant admins and super admins see all data.

Usage:
    class MyViewSet(BranchScopedMixin, viewsets.ModelViewSet):
        branch_field = 'branch'  # default FK field name on the model
        ...
"""

# Roles that bypass branch scoping and see all branches' data.
BRANCH_ADMIN_BYPASS_ROLES = {'super_admin', 'tenant_admin'}

# Roles that are soft-assigned to a branch but allowed to view other branches
# when they explicitly pass a ?branch= filter.
SOFT_ASSIGN_ROLES = {'cashier', 'pharmacist', 'pharmacy_tech', 'storekeeper'}


def get_user_branch(user):
    """Return the branch (id) assigned to a user via their staff profile, or None."""
    if not user or not getattr(user, 'is_authenticated', False):
        return None
    try:
        profile = user.staff_profile
        return getattr(profile, 'branch_id', None)
    except Exception:
        return None


def is_branch_scoped_user(user):
    """Return True if this user should be restricted to their branch only."""
    if not user or not getattr(user, 'is_authenticated', False):
        return False
    role = getattr(user, 'role', None)
    if role in BRANCH_ADMIN_BYPASS_ROLES:
        return False
    if getattr(user, 'is_superuser', False):
        return False
    return get_user_branch(user) is not None


class BranchScopedMixin:
    """
    Mixin that filters the queryset by the user's branch.

    - For tenant_admin / super_admin: no filtering (sees all).
    - For other roles with an assigned branch: filters to their branch.
    - Items with branch=NULL are visible to everyone (legacy/unassigned).

    Set `branch_field` on the viewset to customize the FK lookup
    (default: 'branch').
    """

    branch_field = 'branch'

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user

        if not user or not getattr(user, 'is_authenticated', False):
            return qs

        role = getattr(user, 'role', '')

        # Admins bypass all branch scoping
        if role in BRANCH_ADMIN_BYPASS_ROLES or getattr(user, 'is_superuser', False):
            return qs

        branch_id = get_user_branch(user)
        explicit_branch = self.request.query_params.get(self.branch_field)

        # Soft-assign roles: use explicit branch param if provided, else fall back to assigned branch
        if role in SOFT_ASSIGN_ROLES:
            filter_branch = explicit_branch or (str(branch_id) if branch_id else None)
            if filter_branch:
                from django.db.models import Q
                lookup = {self.branch_field: filter_branch}
                qs = qs.filter(Q(**lookup) | Q(**{f'{self.branch_field}__isnull': True}))
            return qs

        # Other roles (branch_admin, etc.): strictly scoped to their assigned branch
        if branch_id:
            from django.db.models import Q
            lookup = {self.branch_field: branch_id}
            qs = qs.filter(Q(**lookup) | Q(**{f'{self.branch_field}__isnull': True}))

        return qs

    def perform_create(self, serializer):
        """Auto-assign branch on create if not provided and user has a branch."""
        user = self.request.user
        branch_id = get_user_branch(user)
        data = serializer.validated_data

        # Only set branch if the model has the field and no value was provided
        if branch_id and self.branch_field in [f.name for f in serializer.Meta.model._meta.get_fields()]:
            field_value = data.get(self.branch_field) or data.get(f'{self.branch_field}_id')
            if not field_value:
                serializer.save(**{self.branch_field + '_id': branch_id})
                return
        super().perform_create(serializer)
