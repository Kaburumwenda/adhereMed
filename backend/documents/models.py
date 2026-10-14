"""
Premium Document Management System (DMS) for IMS / warehouse tenants.

Features
========
* Hierarchical folder / category tree with colour & icon
* Document records with rich metadata: title, description, tags,
  category, status, priority, expiry tracking, custom reference #
* Versioning — every upload creates a new DocumentVersion; the latest
  version is always the ``current_version``.  Old versions are retained
  for full audit history and can be compared / restored.
* Tagging — free-form tags, multi-tag filtering
* Checkout / check-in — lock a document so only the holder can upload
  a new version (prevents concurrent edits).
* Sharing — share with specific users with view/edit/download perms
  and an optional expiry date.
* Comments / annotations — threaded comments per document
* Activity log — every action (upload, view, download, share, comment,
  checkout, check-in, version restore, delete) is recorded.
* Electronic signatures — request & record e-signatures on documents
* Starred / favourites per user
* Soft-delete with trash recovery
* RBAC — tenant-admin, branch-admin, and staff roles via the shared
  ``InventoryPermission`` pattern from the inventory module.
"""
from django.db import models
from django.conf import settings


class DocumentCategory(models.Model):
    """Hierarchical folder / category for organising documents."""
    name = models.CharField(max_length=150)
    parent = models.ForeignKey(
        'self', on_delete=models.CASCADE, null=True, blank=True,
        related_name='children',
    )
    color = models.CharField(max_length=7, default='#0D9488', help_text='Hex color')
    icon = models.CharField(max_length=50, default='mdi-folder-outline', help_text='MDI icon name')
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        verbose_name_plural = 'Document categories'

    def __str__(self):
        return self.name

    @property
    def breadcrumb(self):
        parts = []
        node = self
        while node:
            parts.append(node.name)
            node = node.parent
        return ' / '.join(reversed(parts))


class Tag(models.Model):
    name = models.CharField(max_length=50, unique=True)
    color = models.CharField(max_length=7, default='#6366F1')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class Document(models.Model):
    """Master document record. The actual files live in DocumentVersion."""

    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        IN_REVIEW = 'in_review', 'In Review'
        APPROVED = 'approved', 'Approved'
        PUBLISHED = 'published', 'Published'
        ARCHIVED = 'archived', 'Archived'
        EXPIRED = 'expired', 'Expired'

    class Priority(models.TextChoices):
        LOW = 'low', 'Low'
        NORMAL = 'normal', 'Normal'
        HIGH = 'high', 'High'
        CRITICAL = 'critical', 'Critical'

    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    reference_number = models.CharField(
        max_length=100, blank=True, db_index=True,
        help_text='External reference / tracking number (auto-generated if blank)',
    )
    category = models.ForeignKey(
        DocumentCategory, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='documents',
    )
    tags = models.ManyToManyField(Tag, blank=True, related_name='documents')
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    priority = models.CharField(max_length=20, choices=Priority.choices, default=Priority.NORMAL)
    expires_at = models.DateField(null=True, blank=True, help_text='Document expiry date')
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='documents',
        help_text='Warehouse this document belongs to (blank = org-wide)',
    )
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='uploaded_documents',
    )
    checked_out_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='checked_out_documents',
        help_text='User who has locked the document for editing',
    )
    is_starred_by = models.ManyToManyField(
        settings.AUTH_USER_MODEL, blank=True,
        related_name='starred_documents',
    )
    is_deleted = models.BooleanField(default=False, db_index=True)
    deleted_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']
        indexes = [
            models.Index(fields=['status', 'is_deleted'], name='doc_status_del_idx'),
            models.Index(fields=['priority', 'is_deleted'], name='doc_priority_del_idx'),
        ]

    def __str__(self):
        return self.title

    @property
    def current_version(self):
        return self.versions.order_by('-version_number').first()

    @property
    def file_extension(self):
        cv = self.current_version
        if cv:
            import os
            return os.path.splitext(cv.file.name or '')[1].lstrip('.').lower()
        return ''


class DocumentVersion(models.Model):
    """Immutable version snapshot. Each upload creates a new row."""
    document = models.ForeignKey(Document, on_delete=models.CASCADE, related_name='versions')
    version_number = models.PositiveIntegerField()
    file = models.FileField(upload_to='documents/versions/')
    file_size = models.PositiveBigIntegerField(default=0)
    file_type = models.CharField(max_length=50, blank=True)
    checksum = models.CharField(max_length=64, blank=True, help_text='SHA-256 checksum')
    change_summary = models.TextField(blank=True, help_text='What changed in this version')
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='document_versions',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-version_number']
        unique_together = ['document', 'version_number']

    def __str__(self):
        return f'{self.document.title} v{self.version_number}'

    @property
    def is_current(self):
        return self.version_number == (self.document.current_version.version_number if self.document.current_version else 0)


class DocumentShare(models.Model):
    """Share a document with specific users with scoped permissions."""
    class Permission(models.TextChoices):
        VIEW = 'view', 'View only'
        COMMENT = 'comment', 'View & comment'
        EDIT = 'edit', 'View, comment & edit'
        DOWNLOAD = 'download', 'View & download'

    document = models.ForeignKey(Document, on_delete=models.CASCADE, related_name='shares')
    shared_with = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='shared_documents',
    )
    permission = models.CharField(max_length=20, choices=Permission.choices, default=Permission.VIEW)
    shared_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='shared_by_me',
    )
    message = models.TextField(blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['document', 'shared_with']
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.document.title} → {self.shared_with}'


class DocumentComment(models.Model):
    """Threaded comments / annotations on a document."""
    document = models.ForeignKey(Document, on_delete=models.CASCADE, related_name='comments')
    parent = models.ForeignKey(
        'self', on_delete=models.CASCADE, null=True, blank=True,
        related_name='replies',
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='document_comments',
    )
    body = models.TextField()
    is_resolved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f'Comment on {self.document.title} by {self.author}'


class DocumentActivity(models.Model):
    """Append-only activity log per document."""
    class Action(models.TextChoices):
        CREATED = 'created', 'Created'
        VIEWED = 'viewed', 'Viewed'
        DOWNLOADED = 'downloaded', 'Downloaded'
        VERSION_UPLOADED = 'version_uploaded', 'Version uploaded'
        SHARED = 'shared', 'Shared'
        COMMENTED = 'commented', 'Commented'
        CHECKED_OUT = 'checked_out', 'Checked out'
        CHECKED_IN = 'checked_in', 'Checked in'
        RESTORED = 'restored', 'Version restored'
        STATUS_CHANGED = 'status_changed', 'Status changed'
        MOVED = 'moved', 'Moved'
        TAGGED = 'tagged', 'Tagged'
        DELETED = 'deleted', 'Deleted'
        RESTORED_FROM_TRASH = 'restored_from_trash', 'Restored from trash'

    document = models.ForeignKey(Document, on_delete=models.CASCADE, related_name='activities')
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='document_activities',
    )
    action = models.CharField(max_length=30, choices=Action.choices)
    detail = models.CharField(max_length=500, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.action} — {self.document.title}'


class SignatureRequest(models.Model):
    """Electronic signature request on a document."""
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        SIGNED = 'signed', 'Signed'
        REJECTED = 'rejected', 'Rejected'
        EXPIRED = 'expired', 'Expired'

    document = models.ForeignKey(Document, on_delete=models.CASCADE, related_name='signature_requests')
    requested_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='signature_requested',
    )
    requested_from = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='signature_requests',
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    message = models.TextField(blank=True)
    signed_at = models.DateTimeField(null=True, blank=True)
    signed_ip = models.GenericIPAddressField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Signature request: {self.document.title} → {self.requested_from}'
