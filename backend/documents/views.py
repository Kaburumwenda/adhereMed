import hashlib
import os

from rest_framework import viewsets, filters, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, SAFE_METHODS
from django_filters.rest_framework import DjangoFilterBackend
from django.db import models
from django.db.models import Count, Q
from django.utils import timezone
from django.http import HttpResponse

from .models import (
    DocumentCategory, Tag, Document, DocumentVersion,
    DocumentShare, DocumentComment, DocumentActivity, SignatureRequest,
)
from .serializers import (
    DocumentCategorySerializer, TagSerializer,
    DocumentSerializer, DocumentDetailSerializer,
    DocumentVersionSerializer, DocumentShareSerializer,
    DocumentCommentSerializer, DocumentActivitySerializer,
    SignatureRequestSerializer,
)
from config.branch_scope import BranchScopedMixin

from django.contrib.auth import get_user_model

User = get_user_model()


# Import the canonical bypass role set so branch-scoping is consistent across the app.
from config.branch_scope import BRANCH_ADMIN_BYPASS_ROLES
ADMIN_ROLES = BRANCH_ADMIN_BYPASS_ROLES
SUPERVISOR_ROLES = ADMIN_ROLES


class DocumentPermission(permissions.BasePermission):
    """Admins manage everything; staff can view/create; only admins delete."""

    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False
        if request.method in SAFE_METHODS:
            return True
        if request.method == 'DELETE':
            return request.user.role in ADMIN_ROLES
        return True


def _log(doc, user, action, detail=''):
    DocumentActivity.objects.create(
        document=doc, user=user, action=action, detail=detail,
    )


# ── Category ViewSet ──────────────────────────────────────────────────────
class DocumentCategoryViewSet(viewsets.ModelViewSet):
    serializer_class = DocumentCategorySerializer
    permission_classes = [DocumentPermission]
    pagination_class = None
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'created_at']
    filterset_fields = ['parent', 'is_active']

    def get_queryset(self):
        return DocumentCategory.objects.annotate(
            document_count=Count('documents', filter=Q(documents__is_deleted=False)),
        ).order_by('name')


# ── Tag ViewSet ──────────────────────────────────────────────────────────
class TagViewSet(viewsets.ModelViewSet):
    serializer_class = TagSerializer
    permission_classes = [DocumentPermission]
    pagination_class = None
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name']
    ordering_fields = ['name', 'created_at']

    def get_queryset(self):
        return Tag.objects.annotate(
            document_count=Count('documents', filter=Q(documents__is_deleted=False)),
        ).order_by('name')


# ── Document ViewSet ────────────────────────────────────────────────────
class DocumentViewSet(viewsets.ModelViewSet):
    serializer_class = DocumentSerializer
    permission_classes = [DocumentPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'priority', 'category', 'branch']
    search_fields = ['title', 'description', 'reference_number']
    ordering_fields = ['title', 'status', 'priority', 'created_at', 'updated_at', 'expires_at']

    def get_queryset(self):
        qs = Document.objects.select_related(
            'category', 'branch', 'uploaded_by', 'checked_out_by',
        ).prefetch_related('tags').filter(is_deleted=False)
        # Branch scoping: non-admins only see docs in their branch + org-wide
        user = self.request.user
        if user.role not in ADMIN_ROLES and getattr(user, 'branch_id', None):
            qs = qs.filter(Q(branch_id=user.branch_id) | Q(branch__isnull=True))
        qs = qs.annotate(
            version_count=Count('versions'),
            share_count=Count('shares'),
            comment_count=Count('comments'),
        )
        return qs

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return DocumentDetailSerializer
        return DocumentSerializer

    def perform_create(self, serializer):
        serializer.save()

    # ── Custom actions ───────────────────────────────────────────────

    @action(detail=True, methods=['post'])
    def upload_version(self, request, pk=None):
        """Upload a new file version for an existing document."""
        doc = self.get_object()
        file = request.FILES.get('file')
        if not file:
            return Response({'detail': 'No file provided.'}, status=400)
        change_summary = request.data.get('change_summary', '')
        # Determine next version number
        last_ver = doc.versions.order_by('-version_number').first()
        next_num = (last_ver.version_number + 1) if last_ver else 1
        # Compute checksum
        file.seek(0)
        checksum = hashlib.sha256(file.read()).hexdigest()
        file.seek(0)
        version = DocumentVersion.objects.create(
            document=doc,
            version_number=next_num,
            file=file,
            file_size=file.size,
            file_type=file.content_type or '',
            checksum=checksum,
            change_summary=change_summary,
            uploaded_by=request.user,
        )
        _log(doc, request.user, DocumentActivity.Action.VERSION_UPLOADED,
             f'v{next_num} uploaded ({file.name})')
        return Response(DocumentVersionSerializer(version, context={'request': request}).data, status=201)

    @action(detail=True, methods=['get'])
    def download(self, request, pk=None):
        """Download the current (or specified) version."""
        doc = self.get_object()
        ver_id = request.query_params.get('version')
        ver_num = request.query_params.get('version_number')
        if ver_id:
            version = doc.versions.filter(id=ver_id).first()
        elif ver_num:
            version = doc.versions.filter(version_number=ver_num).first()
        else:
            version = doc.current_version
        if not version:
            return Response({'detail': 'No file available.'}, status=404)
        _log(doc, request.user, DocumentActivity.Action.DOWNLOADED,
             f'v{version.version_number}')
        # Serve the file directly
        from django.core.files.base import ContentFile
        try:
            version.file.open('rb')
            content = version.file.read()
            version.file.close()
        except Exception:
            return Response({'detail': 'File not accessible.'}, status=500)
        import os
        ext = os.path.splitext(version.file.name)[1]
        filename = f'{doc.title}_v{version.version_number}{ext}'
        response = HttpResponse(content, content_type='application/octet-stream')
        response['Content-Disposition'] = f'attachment; filename="{filename}"'
        response['Content-Length'] = str(len(content))
        return response

    @action(detail=True, methods=['post'])
    def checkout(self, request, pk=None):
        """Lock a document for editing."""
        doc = self.get_object()
        if doc.checked_out_by and doc.checked_out_by != request.user:
            return Response({'detail': f'Already checked out by {doc.checked_out_by.full_name}.'}, status=409)
        doc.checked_out_by = request.user
        doc.save(update_fields=['checked_out_by'])
        _log(doc, request.user, DocumentActivity.Action.CHECKED_OUT)
        return Response({'detail': 'Document checked out.'})

    @action(detail=True, methods=['post'])
    def checkin(self, request, pk=None):
        """Release the edit lock."""
        doc = self.get_object()
        if doc.checked_out_by != request.user and request.user.role not in ADMIN_ROLES:
            return Response({'detail': 'You do not have this document checked out.'}, status=403)
        doc.checked_out_by = None
        doc.save(update_fields=['checked_out_by'])
        _log(doc, request.user, DocumentActivity.Action.CHECKED_IN)
        return Response({'detail': 'Document checked in.'})

    @action(detail=True, methods=['post'])
    def star(self, request, pk=None):
        doc = self.get_object()
        if doc.is_starred_by.filter(id=request.user.id).exists():
            doc.is_starred_by.remove(request.user)
            return Response({'is_starred': False})
        else:
            doc.is_starred_by.add(request.user)
            return Response({'is_starred': True})

    @action(detail=True, methods=['post'])
    def change_status(self, request, pk=None):
        doc = self.get_object()
        new_status = request.data.get('status')
        if new_status not in dict(Document.Status.choices):
            return Response({'detail': 'Invalid status.'}, status=400)
        old_status = doc.get_status_display()
        doc.status = new_status
        doc.save(update_fields=['status'])
        _log(doc, request.user, DocumentActivity.Action.STATUS_CHANGED,
             f'{old_status} → {doc.get_status_display()}')
        return Response({'status': doc.status})

    @action(detail=True, methods=['post'])
    def restore_version(self, request, pk=None):
        """Make an old version the new current by creating a new version from it."""
        doc = self.get_object()
        ver_id = request.data.get('version_id')
        ver_num = request.data.get('version_number')
        if ver_id:
            old_ver = doc.versions.filter(id=ver_id).first()
        elif ver_num:
            old_ver = doc.versions.filter(version_number=ver_num).first()
        else:
            old_ver = None
        if not old_ver:
            return Response({'detail': 'Version not found.'}, status=404)
        next_num = (doc.versions.order_by('-version_number').first().version_number + 1)
        new_ver = DocumentVersion.objects.create(
            document=doc,
            version_number=next_num,
            file=old_ver.file,
            file_size=old_ver.file_size,
            file_type=old_ver.file_type,
            checksum=old_ver.checksum,
            change_summary=f'Restored from v{old_ver.version_number}',
            uploaded_by=request.user,
        )
        _log(doc, request.user, DocumentActivity.Action.RESTORED,
             f'Restored v{old_ver.version_number} as v{next_num}')
        return Response(DocumentVersionSerializer(new_ver, context={'request': request}).data, status=201)

    @action(detail=True, methods=['post'])
    def soft_delete(self, request, pk=None):
        doc = self.get_object()
        doc.is_deleted = True
        doc.deleted_at = timezone.now()
        doc.save(update_fields=['is_deleted', 'deleted_at'])
        _log(doc, request.user, DocumentActivity.Action.DELETED)
        return Response({'detail': 'Document moved to trash.'})

    @action(detail=True, methods=['post'])
    def restore(self, request, pk=None):
        """Restore from trash."""
        doc = Document.objects.filter(pk=pk, is_deleted=True).first()
        if not doc:
            return Response({'detail': 'Not found in trash.'}, status=404)
        doc.is_deleted = False
        doc.deleted_at = None
        doc.save(update_fields=['is_deleted', 'deleted_at'])
        _log(doc, request.user, DocumentActivity.Action.RESTORED_FROM_TRASH)
        return Response({'detail': 'Document restored.'})

    @action(detail=False, methods=['get'])
    def trash(self, request):
        """List soft-deleted documents."""
        qs = Document.objects.filter(is_deleted=True).select_related('uploaded_by')
        if request.user.role not in ADMIN_ROLES and getattr(request.user, 'branch_id', None):
            qs = qs.filter(Q(branch_id=request.user.branch_id) | Q(branch__isnull=True))
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def starred(self, request):
        """List documents starred by the current user."""
        qs = self.get_queryset().filter(is_starred_by=request.user)
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def shared_with_me(self, request):
        """Documents shared with the current user."""
        qs = Document.objects.filter(
            shares__shared_with=request.user,
            is_deleted=False,
        ).select_related('category', 'uploaded_by').distinct()
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def dashboard(self, request):
        """KPI summary for the DMS dashboard."""
        qs = self.get_queryset()
        total = qs.count()
        by_status = qs.values('status').annotate(count=Count('id'))
        by_category = qs.values('category__name', 'category__color').annotate(count=Count('id'))
        expiring = qs.filter(
            expires_at__isnull=False,
            expires_at__lte=timezone.now().date() + timezone.timedelta(days=30),
        ).count()
        starred = qs.filter(is_starred_by=request.user).count()
        shared = Document.objects.filter(shares__shared_with=request.user, is_deleted=False).distinct().count()
        return Response({
            'total': total,
            'by_status': list(by_status),
            'by_category': list(by_category),
            'expiring_soon': expiring,
            'starred': starred,
            'shared_with_me': shared,
        })


# ── Comment ViewSet ─────────────────────────────────────────────────────
class DocumentCommentViewSet(viewsets.ModelViewSet):
    serializer_class = DocumentCommentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = DocumentComment.objects.select_related('author').filter(parent__isnull=True)
        doc_id = self.request.query_params.get('document')
        if doc_id:
            qs = qs.filter(document_id=doc_id)
        return qs

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)
        doc = serializer.instance.document
        _log(doc, self.request.user, DocumentActivity.Action.COMMENTED)


# ── Share ViewSet ───────────────────────────────────────────────────────
class DocumentShareViewSet(viewsets.ModelViewSet):
    serializer_class = DocumentShareSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['document', 'shared_with']

    def get_queryset(self):
        return DocumentShare.objects.select_related('shared_with', 'shared_by')

    def perform_create(self, serializer):
        share = serializer.save(shared_by=self.request.user)
        _log(share.document, self.request.user, DocumentActivity.Action.SHARED,
             f'Shared with {share.shared_with.full_name}')


# ── Activity ViewSet (read-only) ────────────────────────────────────────
class DocumentActivityViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = DocumentActivitySerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['document', 'action']
    ordering_fields = ['created_at']
    ordering = ['-created_at']

    def get_queryset(self):
        return DocumentActivity.objects.select_related('user')


# ── Signature Request ViewSet ──────────────────────────────────────────
class SignatureRequestViewSet(viewsets.ModelViewSet):
    serializer_class = SignatureRequestSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['document', 'status', 'requested_from']
    ordering_fields = ['created_at']
    ordering = ['-created_at']

    def get_queryset(self):
        qs = SignatureRequest.objects.select_related('requested_by', 'requested_from')
        # User sees requests they made or need to sign
        user = self.request.user
        return qs.filter(Q(requested_by=user) | Q(requested_from=user))

    def perform_create(self, serializer):
        serializer.save(requested_by=self.request.user)

    @action(detail=True, methods=['post'])
    def sign(self, request, pk=None):
        req = self.get_object()
        if req.requested_from != request.user:
            return Response({'detail': 'Only the requested signer can sign.'}, status=403)
        if req.status != SignatureRequest.Status.PENDING:
            return Response({'detail': 'Request is no longer pending.'}, status=400)
        req.status = SignatureRequest.Status.SIGNED
        req.signed_at = timezone.now()
        req.signed_ip = request.META.get('REMOTE_ADDR')
        req.save(update_fields=['status', 'signed_at', 'signed_ip'])
        _log(req.document, request.user, 'signed',
             f'Signed by {request.user.full_name}')
        return Response({'detail': 'Document signed.'})

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        req = self.get_object()
        if req.requested_from != request.user:
            return Response({'detail': 'Only the requested signer can reject.'}, status=403)
        req.status = SignatureRequest.Status.REJECTED
        req.save(update_fields=['status'])
        _log(req.document, request.user, 'rejected',
             f'Rejected by {request.user.full_name}')
        return Response({'detail': 'Signature rejected.'})
