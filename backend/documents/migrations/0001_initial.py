from django.db import migrations, models
import django.db.models.deletion
from django.conf import settings


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('pharmacy_profile', '0011_alter_delivery_status'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='DocumentCategory',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=150)),
                ('color', models.CharField(default='#0D9488', help_text='Hex color', max_length=7)),
                ('icon', models.CharField(default='mdi-folder-outline', help_text='MDI icon name', max_length=50)),
                ('description', models.TextField(blank=True)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('parent', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='children', to='documents.documentcategory')),
            ],
            options={
                'verbose_name_plural': 'Document categories',
                'ordering': ['name'],
            },
        ),
        migrations.CreateModel(
            name='Tag',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=50, unique=True)),
                ('color', models.CharField(default='#6366F1', max_length=7)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
            ],
            options={'ordering': ['name']},
        ),
        migrations.CreateModel(
            name='Document',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title', models.CharField(max_length=255)),
                ('description', models.TextField(blank=True)),
                ('reference_number', models.CharField(blank=True, db_index=True, help_text='External reference / tracking number (auto-generated if blank)', max_length=100)),
                ('status', models.CharField(choices=[('draft', 'Draft'), ('in_review', 'In Review'), ('approved', 'Approved'), ('published', 'Published'), ('archived', 'Archived'), ('expired', 'Expired')], default='draft', max_length=20)),
                ('priority', models.CharField(choices=[('low', 'Low'), ('normal', 'Normal'), ('high', 'High'), ('critical', 'Critical')], default='normal', max_length=20)),
                ('expires_at', models.DateField(blank=True, help_text='Document expiry date', null=True)),
                ('is_deleted', models.BooleanField(db_index=True, default=False)),
                ('deleted_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('branch', models.ForeignKey(blank=True, help_text='Warehouse this document belongs to (blank = org-wide)', null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='documents', to='pharmacy_profile.branch')),
                ('category', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='documents', to='documents.documentcategory')),
                ('checked_out_by', models.ForeignKey(blank=True, help_text='User who has locked the document for editing', null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='checked_out_documents', to=settings.AUTH_USER_MODEL)),
                ('is_starred_by', models.ManyToManyField(blank=True, related_name='starred_documents', to=settings.AUTH_USER_MODEL)),
                ('tags', models.ManyToManyField(blank=True, related_name='documents', to='documents.tag')),
                ('uploaded_by', models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='uploaded_documents', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-updated_at'],
                'indexes': [models.Index(fields=['status', 'is_deleted'], name='doc_status_del_idx'), models.Index(fields=['priority', 'is_deleted'], name='doc_priority_del_idx')],
            },
        ),
        migrations.CreateModel(
            name='DocumentVersion',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('version_number', models.PositiveIntegerField()),
                ('file', models.FileField(upload_to='documents/versions/')),
                ('file_size', models.PositiveBigIntegerField(default=0)),
                ('file_type', models.CharField(blank=True, max_length=50)),
                ('checksum', models.CharField(blank=True, help_text='SHA-256 checksum', max_length=64)),
                ('change_summary', models.TextField(blank=True, help_text='What changed in this version')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('document', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='versions', to='documents.document')),
                ('uploaded_by', models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='document_versions', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-version_number'],
                'unique_together': {('document', 'version_number')},
            },
        ),
        migrations.CreateModel(
            name='DocumentShare',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('permission', models.CharField(choices=[('view', 'View only'), ('comment', 'View & comment'), ('edit', 'View, comment & edit'), ('download', 'View & download')], default='view', max_length=20)),
                ('message', models.TextField(blank=True)),
                ('expires_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('document', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='shares', to='documents.document')),
                ('shared_by', models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='shared_by_me', to=settings.AUTH_USER_MODEL)),
                ('shared_with', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='shared_documents', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-created_at'],
                'unique_together': {('document', 'shared_with')},
            },
        ),
        migrations.CreateModel(
            name='DocumentComment',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('body', models.TextField()),
                ('is_resolved', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('author', models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='document_comments', to=settings.AUTH_USER_MODEL)),
                ('document', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='comments', to='documents.document')),
                ('parent', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='replies', to='documents.documentcomment')),
            ],
            options={'ordering': ['created_at']},
        ),
        migrations.CreateModel(
            name='DocumentActivity',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('action', models.CharField(choices=[('created', 'Created'), ('viewed', 'Viewed'), ('downloaded', 'Downloaded'), ('version_uploaded', 'Version uploaded'), ('shared', 'Shared'), ('commented', 'Commented'), ('checked_out', 'Checked out'), ('checked_in', 'Checked in'), ('restored', 'Version restored'), ('status_changed', 'Status changed'), ('moved', 'Moved'), ('tagged', 'Tagged'), ('deleted', 'Deleted'), ('restored_from_trash', 'Restored from trash')], max_length=30)),
                ('detail', models.CharField(blank=True, max_length=500)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('document', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='activities', to='documents.document')),
                ('user', models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='document_activities', to=settings.AUTH_USER_MODEL)),
            ],
            options={'ordering': ['-created_at']},
        ),
        migrations.CreateModel(
            name='SignatureRequest',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('status', models.CharField(choices=[('pending', 'Pending'), ('signed', 'Signed'), ('rejected', 'Rejected'), ('expired', 'Expired')], default='pending', max_length=20)),
                ('message', models.TextField(blank=True)),
                ('signed_at', models.DateTimeField(blank=True, null=True)),
                ('signed_ip', models.GenericIPAddressField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('document', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='signature_requests', to='documents.document')),
                ('requested_by', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='signature_requested', to=settings.AUTH_USER_MODEL)),
                ('requested_from', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='signature_requests', to=settings.AUTH_USER_MODEL)),
            ],
            options={'ordering': ['-created_at']},
        ),
    ]
