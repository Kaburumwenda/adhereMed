from rest_framework import serializers
from django.conf import settings
from .models import (
    DocumentCategory, Tag, Document, DocumentVersion,
    DocumentShare, DocumentComment, DocumentActivity, SignatureRequest,
)


class DocumentCategorySerializer(serializers.ModelSerializer):
    parent_name = serializers.CharField(source='parent.name', read_only=True, default=None)
    document_count = serializers.IntegerField(read_only=True, default=0)
    breadcrumb = serializers.CharField(read_only=True, default='')

    class Meta:
        model = DocumentCategory
        fields = ['id', 'name', 'parent', 'parent_name', 'color', 'icon',
                   'description', 'is_active', 'document_count', 'breadcrumb',
                   'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']


class TagSerializer(serializers.ModelSerializer):
    document_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = Tag
        fields = ['id', 'name', 'color', 'document_count', 'created_at']
        read_only_fields = ['id', 'created_at']


class DocumentVersionSerializer(serializers.ModelSerializer):
    uploaded_by_name = serializers.CharField(source='uploaded_by.full_name', read_only=True, default=None)
    file_url = serializers.SerializerMethodField()
    is_current = serializers.BooleanField(read_only=True)

    class Meta:
        model = DocumentVersion
        fields = ['id', 'document', 'version_number', 'file', 'file_url',
                   'file_size', 'file_type', 'checksum', 'change_summary',
                   'uploaded_by', 'uploaded_by_name', 'is_current', 'created_at']
        read_only_fields = ['id', 'version_number', 'file_size', 'file_type',
                             'checksum', 'uploaded_by', 'created_at']

    def get_file_url(self, obj):
        request = self.context.get('request')
        if obj.file:
            url = obj.file.url
            return url
        return None


class DocumentCommentSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.full_name', read_only=True, default=None)
    author_avatar = serializers.SerializerMethodField()
    replies = serializers.SerializerMethodField()

    class Meta:
        model = DocumentComment
        fields = ['id', 'document', 'parent', 'author', 'author_name',
                   'author_avatar', 'body', 'is_resolved', 'replies',
                   'created_at', 'updated_at']
        read_only_fields = ['id', 'author', 'created_at', 'updated_at']

    def get_author_avatar(self, obj):
        if obj.author and getattr(obj.author, 'avatar', None):
            return obj.author.avatar.url
        return None

    def get_replies(self, obj):
        if obj.parent is not None:
            return []
        replies = obj.replies.select_related('author').all()
        return DocumentCommentSerializer(replies, many=True, context=self.context).data


class DocumentShareSerializer(serializers.ModelSerializer):
    shared_with_name = serializers.CharField(source='shared_with.full_name', read_only=True, default=None)
    shared_by_name = serializers.CharField(source='shared_by.full_name', read_only=True, default=None)

    class Meta:
        model = DocumentShare
        fields = ['id', 'document', 'shared_with', 'shared_with_name',
                   'shared_by', 'shared_by_name', 'permission', 'message',
                   'expires_at', 'created_at']
        read_only_fields = ['id', 'shared_by', 'created_at']


class DocumentActivitySerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.full_name', read_only=True, default=None)

    class Meta:
        model = DocumentActivity
        fields = ['id', 'document', 'user', 'user_name', 'action',
                   'detail', 'created_at']
        read_only_fields = ['id', 'user', 'created_at']


class SignatureRequestSerializer(serializers.ModelSerializer):
    requested_by_name = serializers.CharField(source='requested_by.full_name', read_only=True, default=None)
    requested_from_name = serializers.CharField(source='requested_from.full_name', read_only=True, default=None)

    class Meta:
        model = SignatureRequest
        fields = ['id', 'document', 'requested_by', 'requested_by_name',
                   'requested_from', 'requested_from_name', 'status',
                   'message', 'signed_at', 'signed_ip', 'created_at']
        read_only_fields = ['id', 'requested_by', 'signed_at', 'signed_ip', 'created_at']


class DocumentSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source='category.name', read_only=True, default=None)
    category_color = serializers.CharField(source='category.color', read_only=True, default=None)
    branch_name = serializers.CharField(source='branch.name', read_only=True, default=None)
    uploaded_by_name = serializers.CharField(source='uploaded_by.full_name', read_only=True, default=None)
    checked_out_by_name = serializers.CharField(source='checked_out_by.full_name', read_only=True, default=None)
    tag_names = serializers.SlugRelatedField(many=True, slug_field='name', queryset=Tag.objects.all(), required=False)
    tags_detail = TagSerializer(source='tags', many=True, read_only=True)
    current_version = DocumentVersionSerializer(read_only=True)
    version_count = serializers.IntegerField(read_only=True, default=0)
    share_count = serializers.IntegerField(read_only=True, default=0)
    comment_count = serializers.IntegerField(read_only=True, default=0)
    is_starred = serializers.SerializerMethodField()
    file_extension = serializers.CharField(read_only=True)

    class Meta:
        model = Document
        fields = ['id', 'title', 'description', 'reference_number',
                   'category', 'category_name', 'category_color',
                   'branch', 'branch_name',
                   'tags', 'tag_names', 'tags_detail',
                   'status', 'priority', 'expires_at',
                   'file',
                   'uploaded_by', 'uploaded_by_name',
                   'checked_out_by', 'checked_out_by_name',
                   'is_starred', 'file_extension',
                   'current_version', 'version_count',
                   'share_count', 'comment_count',
                   'is_deleted', 'deleted_at',
                   'created_at', 'updated_at']
        read_only_fields = ['id', 'uploaded_by', 'checked_out_by',
                             'is_deleted', 'deleted_at', 'created_at', 'updated_at']
        extra_kwargs = {
            'file': {'write_only': True, 'required': False},
        }

    def get_is_starred(self, obj):
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return False
        return obj.is_starred_by.filter(id=request.user.id).exists()

    def create(self, validated_data):
        tag_names = validated_data.pop('tag_names', [])
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            validated_data['uploaded_by'] = request.user
        # Pop the file from validated_data if present (FormData upload)
        upload_file = validated_data.pop('file', None)
        if upload_file is None and request:
            upload_file = request.FILES.get('file')
        doc = super().create(validated_data)
        if tag_names:
            for name in tag_names:
                tag, _ = Tag.objects.get_or_create(name=name)
                doc.tags.add(tag)
        if not doc.reference_number:
            doc.reference_number = f'DOC-{doc.pk:06d}'
            doc.save(update_fields=['reference_number'])
        # Create initial version if a file was uploaded
        if upload_file:
            import hashlib
            upload_file.seek(0)
            checksum = hashlib.sha256(upload_file.read()).hexdigest()
            upload_file.seek(0)
            DocumentVersion.objects.create(
                document=doc,
                version_number=1,
                file=upload_file,
                file_size=upload_file.size,
                file_type=upload_file.content_type or '',
                checksum=checksum,
                change_summary='Initial upload',
                uploaded_by=request.user if request else None,
            )
        DocumentActivity.objects.create(
            document=doc, user=request.user if request else None,
            action=DocumentActivity.Action.CREATED,
            detail=f'"{doc.title}" created',
        )
        return doc


class DocumentDetailSerializer(DocumentSerializer):
    """Extended serializer for the detail view — includes related data."""
    versions = DocumentVersionSerializer(many=True, read_only=True)
    shares = DocumentShareSerializer(many=True, read_only=True)
    comments = DocumentCommentSerializer(many=True, read_only=True)
    activities = DocumentActivitySerializer(many=True, read_only=True)
    signature_requests = SignatureRequestSerializer(many=True, read_only=True)

    class Meta(DocumentSerializer.Meta):
        fields = DocumentSerializer.Meta.fields + [
            'versions', 'shares', 'comments', 'activities', 'signature_requests',
        ]
