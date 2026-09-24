"""
Generic, append-only audit trail for every tenant.

Captures *who* did *what* to *which object* and *when* — plus the request
method, path, IP, user-agent, payload diff and HTTP status. Designed for
compliance review (HIPAA / Kenya DPA).

The companion :mod:`audit.middleware` writes a record for every mutating
request (POST/PUT/PATCH/DELETE) hit on the tenant's API. Sensitive views
can additionally call :func:`audit.utils.log_event` to record READ actions,
login/logout, or business-rule events.
"""
from django.db import models


class AuditEvent(models.Model):
    """Append-only audit trail.

    Records one row per audited request. `actor_*` fields are denormalised
    on purpose so the trail survives user deletion and stays fast to query.
    """

    class Action(models.TextChoices):
        CREATE = 'create', 'Create'
        UPDATE = 'update', 'Update'
        DELETE = 'delete', 'Delete'
        VIEW = 'view', 'View'
        LOGIN = 'login', 'Login'
        LOGOUT = 'logout', 'Logout'
        EXPORT = 'export', 'Export'
        PRINT = 'print', 'Print'
        CONFIG = 'config', 'Config Change'
        ACTION = 'action', 'Custom Action'

    class Severity(models.TextChoices):
        INFO = 'info', 'Info'
        NOTICE = 'notice', 'Notice'
        WARNING = 'warning', 'Warning'
        CRITICAL = 'critical', 'Critical'

    # ── Actor ────────────────────────────────────────────────────────
    actor_user_id = models.IntegerField(null=True, blank=True, db_index=True)
    actor_email = models.CharField(max_length=255, blank=True, db_index=True)
    actor_role = models.CharField(max_length=64, blank=True)

    # ── Action / target ───────────────────────────────────────────────
    action = models.CharField(max_length=16, choices=Action.choices, db_index=True)
    severity = models.CharField(max_length=16, choices=Severity.choices,
                                default=Severity.INFO, db_index=True)
    object_type = models.CharField(max_length=120, blank=True, db_index=True)
    object_id = models.CharField(max_length=64, blank=True, db_index=True)
    object_repr = models.CharField(max_length=255, blank=True)
    description = models.CharField(max_length=255, blank=True,
                                   help_text='Human-readable summary of the event.')

    # ── HTTP request metadata ────────────────────────────────────────
    method = models.CharField(max_length=10, blank=True, db_index=True)
    path = models.CharField(max_length=512, blank=True, db_index=True)
    ip = models.GenericIPAddressField(null=True, blank=True)
    latitude = models.DecimalField(
        max_digits=30, decimal_places=12, null=True, blank=True,
        help_text='GPS latitude of the actor at the time of the event.',
    )
    longitude = models.DecimalField(
        max_digits=30, decimal_places=12, null=True, blank=True,
        help_text='GPS longitude of the actor at the time of the event.',
    )
    user_agent = models.CharField(max_length=512, blank=True)
    status_code = models.PositiveSmallIntegerField(null=True, blank=True)

    # ── Payload / context ────────────────────────────────────────────
    payload_diff = models.JSONField(
        default=dict, blank=True,
        help_text='Before/after snapshot or redacted request body.',
    )
    extra = models.JSONField(
        default=dict, blank=True,
        help_text='Free-form context (session id, branch, tenant module...).',
    )

    # ── Lifecycle ────────────────────────────────────────────────────
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    session_id = models.CharField(max_length=64, blank=True, db_index=True,
                                  help_text='Correlation id linking related events.')

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Audit event'
        verbose_name_plural = 'Audit events'
        indexes = [
            models.Index(fields=['object_type', 'object_id']),
            models.Index(fields=['actor_user_id', '-created_at']),
            models.Index(fields=['-created_at', 'action']),
            models.Index(fields=['severity', '-created_at']),
        ]

    def __str__(self):
        target = self.object_repr or f'{self.object_type}#{self.object_id}'
        return f'{self.action} {target} by {self.actor_email or self.actor_user_id or "anonymous"}'

    @property
    def actor_display(self):
        return self.actor_email or (f'user#{self.actor_user_id}' if self.actor_user_id else 'anonymous')
