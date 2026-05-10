"""Custom storage backends.

`UniqueKeyS3Storage` overrides the default django-storages behaviour to avoid
calling `HeadObject` on every save. django-storages uses `HeadObject` to find
a non-colliding filename when `AWS_S3_FILE_OVERWRITE=False`; when the IAM
user lacks `s3:ListBucket` on the bucket, S3 returns 403 (Forbidden) for
missing keys instead of 404 and the upload fails with::

    botocore.exceptions.ClientError: An error occurred (403) when calling the
    HeadObject operation: Forbidden

By appending a short UUID to every uploaded filename we guarantee uniqueness
without ever asking S3 whether the key exists.
"""
from __future__ import annotations

import os
import uuid

from storages.backends.s3boto3 import S3Boto3Storage


class UniqueKeyS3Storage(S3Boto3Storage):
    """S3 storage that suffixes every upload with a short UUID.

    Overwrite is enabled at the boto3 layer (see settings) so no HeadObject
    probe is performed.
    """

    def get_available_name(self, name: str, max_length: int | None = None) -> str:
        directory, filename = os.path.split(name)
        base, ext = os.path.splitext(filename)
        unique = uuid.uuid4().hex[:8]
        new_name = f'{base}-{unique}{ext}'
        full = os.path.join(directory, new_name) if directory else new_name
        if max_length and len(full) > max_length:
            # Trim the base, keep the unique suffix + extension intact.
            keep = max_length - len(directory) - len(ext) - len(unique) - 2
            keep = max(keep, 1)
            base = base[:keep]
            new_name = f'{base}-{unique}{ext}'
            full = os.path.join(directory, new_name) if directory else new_name
        return full
