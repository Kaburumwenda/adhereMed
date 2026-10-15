"""Upload local media (and/or collected static) to the S3 bucket.

Why this exists
---------------
Production has been storing uploads on local disk (``MEDIA_ROOT``). Turning on
``USE_S3`` re-points every ``FileField`` at the bucket, so the *existing* files
must be uploaded first or every previously uploaded image/PDF 404s.

It deliberately uses boto3 ``put_object`` rather than the Django storage API:

* the deployment IAM user is not granted ``GetObject`` / ``ListBucket``, so
  ``storage.exists()`` / ``storage.listdir()`` return 403 and higher-level APIs
  such as ``collectstatic`` cannot run against S3 at all;
* ``PutObject`` works, and every file is uploaded unconditionally
  (overwrite semantics match ``AWS_S3_FILE_OVERWRITE = True``).

Usage::

    # Everything: existing media + freshly collected static
    python manage.py s3_sync

    # Only media already on local disk
    python manage.py s3_sync --media

    # Only static (runs collectstatic into a temp dir, then uploads)
    python manage.py s3_sync --static

    # See what would happen without uploading
    python manage.py s3_sync --dry-run

NOTE: objects are never deleted -- uploading is idempotent and existing keys
are simply overwritten.
"""
from __future__ import annotations

import mimetypes
import os
import shutil
import tempfile

import boto3
from botocore.config import Config
from django.conf import settings
from django.core.management import call_command
from django.core.management.base import BaseCommand, CommandError

#: Fallback cache-control, mirrors AWS_S3_OBJECT_PARAMETERS.
DEFAULT_CACHE_CONTROL = 'max-age=86400'


class Command(BaseCommand):
    help = 'Upload local media and/or static files to the configured S3 bucket.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--media', action='store_true', default=False,
            help='Upload files from MEDIA_ROOT.',
        )
        parser.add_argument(
            '--static', action='store_true', default=False,
            help='Run collectstatic, then upload the result.',
        )
        parser.add_argument(
            '--dry-run', action='store_true', default=False,
            help='List what would be uploaded without uploading anything.',
        )
        parser.add_argument(
            '--verbose', action='store_true', default=False,
            help='Print every file as it is uploaded.',
        )

    # ── S3 plumbing ──────────────────────────────────────────────────────

    @staticmethod
    def _setting(name, default=None):
        """Read an AWS setting, falling back to ``.env`` when ``USE_S3`` is off.

        ``config/settings.py`` only defines the ``AWS_*`` settings inside its
        ``if USE_S3:`` branch, yet the whole point of this command is to run
        *before* ``USE_S3`` is flipped. Fall back to decouple so the command
        works in both modes.
        """
        value = getattr(settings, name, None)
        if value:
            return value
        from decouple import config as env_config
        return env_config(name, default=default)

    def _client(self):
        bucket = self._setting('AWS_STORAGE_BUCKET_NAME', '') or ''
        if not bucket:
            raise CommandError(
                'AWS_STORAGE_BUCKET_NAME is not set. Configure the AWS_* '
                'variables in .env first.'
            )
        region = self._setting('AWS_S3_REGION_NAME', 'us-east-1') or 'us-east-1'
        return boto3.client(
            's3',
            aws_access_key_id=self._setting('AWS_ACCESS_KEY_ID'),
            aws_secret_access_key=self._setting('AWS_SECRET_ACCESS_KEY'),
            region_name=region,
            config=Config(
                signature_version=getattr(settings, 'AWS_S3_SIGNATURE_VERSION', 's3v4'),
                s3={'addressing_style': getattr(settings, 'AWS_S3_ADDRESSING_STYLE', 'virtual')},
            ),
        ), bucket

    @staticmethod
    def _content_type(path):
        guessed, _ = mimetypes.guess_type(path)
        return guessed or 'application/octet-stream'

    def _upload_tree(self, client, bucket, root, key_prefix, label, dry_run, verbose):
        """Upload every file under ``root`` to ``key_prefix``. Returns count."""
        if not root or not os.path.isdir(root):
            self.stdout.write(self.style.WARNING(
                f'  {label}: directory not found ({root}) -- skipping'
            ))
            return 0

        uploaded = 0
        for dirpath, _dirnames, filenames in os.walk(root):
            for filename in filenames:
                absolute = os.path.join(dirpath, filename)
                relative = os.path.relpath(absolute, root).replace(os.sep, '/')
                key = f'{key_prefix}/{relative}'

                if dry_run:
                    if verbose:
                        self.stdout.write(f'    [dry-run] {key}')
                    uploaded += 1
                    continue

                try:
                    with open(absolute, 'rb') as handle:
                        client.put_object(
                            Bucket=bucket,
                            Key=key,
                            Body=handle,
                            ContentType=self._content_type(absolute),
                            CacheControl=DEFAULT_CACHE_CONTROL,
                        )
                    uploaded += 1
                    if verbose:
                        self.stdout.write(f'    uploaded {key}')
                except Exception as exc:
                    self.stderr.write(self.style.ERROR(
                        f'    FAILED {key} -> {str(exc).splitlines()[0][:140]}'
                    ))
        return uploaded

    # ── Static collection ────────────────────────────────────────────────

    def _collect_static_to(self, target_dir):
        """Run collectstatic into a local directory.

        The staticfiles storage is swapped for the plain filesystem backend so
        the command never touches S3 (where ``exists()`` would 403).
        """
        from django.test.utils import override_settings

        local_storages = {
            'default': {
                'BACKEND': 'django.core.files.storage.FileSystemStorage',
            },
            'staticfiles': {
                'BACKEND': 'django.contrib.staticfiles.storage.StaticFilesStorage',
            },
        }
        with override_settings(STATIC_ROOT=target_dir, STORAGES=local_storages):
            call_command('collectstatic', interactive=False, verbosity=0, clear=False)

    # ── Entry point ──────────────────────────────────────────────────────

    def handle(self, *args, **options):
        do_media = options['media']
        do_static = options['static']
        if not do_media and not do_static:
            do_media = do_static = True

        dry_run = options['dry_run']
        verbose = options['verbose']

        client, bucket = self._client()
        media_location = getattr(settings, 'MEDIA_LOCATION', 'media')
        static_location = getattr(settings, 'STATIC_LOCATION', 'static')
        region = self._setting('AWS_S3_REGION_NAME', 'us-east-1')

        self.stdout.write(
            f'Bucket: {bucket}  region: {region}'
            + ('  (DRY RUN)' if dry_run else '')
        )

        total = 0

        if do_media:
            media_root = str(getattr(settings, 'MEDIA_ROOT', '') or '')
            self.stdout.write(f'Media  <- {media_root}  =>  s3://{bucket}/{media_location}/')
            total += self._upload_tree(
                client, bucket, media_root, media_location, 'media',
                dry_run, verbose,
            )

        if do_static:
            temp_dir = tempfile.mkdtemp(prefix='adheremed-static-')
            try:
                self.stdout.write('Collecting static files locally...')
                self._collect_static_to(temp_dir)
                self.stdout.write(
                    f'Static <- {temp_dir}  =>  s3://{bucket}/{static_location}/'
                )
                total += self._upload_tree(
                    client, bucket, temp_dir, static_location, 'static',
                    dry_run, verbose,
                )
            finally:
                shutil.rmtree(temp_dir, ignore_errors=True)

        verb = 'would upload' if dry_run else 'uploaded'
        self.stdout.write(self.style.SUCCESS(f'Done. {verb} {total} file(s).'))
