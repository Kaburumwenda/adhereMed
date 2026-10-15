"""Custom storage backends.

`TolerantExistsMixin` and `UniqueKeyS3Storage` were originally written to work
around a *too-narrow* IAM policy: the ``adheremed-s3-user`` was granted
``PutObject`` but **not** ``GetObject`` / ``ListBucket``, so a ``HeadObject``
on a missing key returned **403 Forbidden** instead of 404. django-storages
re-raises anything that is not a 404, which made callers such as Django's
``collectstatic`` crash::

    botocore.exceptions.ClientError: An error occurred (403) when calling the
    HeadObject operation: Forbidden

The deployment credentials have since been replaced by a properly
least-privileged IAM user (``adheremeds3``) that can ``GetObject`` /
``ListBucket`` / ``PutObject`` / ``DeleteObject``, so both workarounds are now
strictly unnecessary. They are retained deliberately as **defence in depth**:

* ``TolerantExistsMixin`` only changes behaviour on 401/403, which should never
  happen with the new credentials -- if the policy is ever tightened again,
  uploads keep working instead of failing outright.
* ``UniqueKeyS3Storage`` appends a short UUID to every uploaded media filename,
  which guarantees uniqueness without any existence probe *and* prevents two
  records that upload the same filename (e.g. ``logo.png``) from silently
  overwriting each other.
"""
from __future__ import annotations

import os
import uuid

from botocore.exceptions import ClientError
from storages.backends.s3boto3 import S3Boto3Storage, S3StaticStorage

#: HTTP statuses that mean "the credentials may not read this key" rather than
#: "the key does not exist".
_DENIED_STATUSES = (401, 403)


class TolerantExistsMixin:
    """Treat an unauthorized ``HeadObject`` (401/403) as "not found".

    Keep in mind this is a *workaround* for a too-narrow IAM policy. Granting
    ``s3:GetObject`` and ``s3:ListBucket`` on the bucket makes it unnecessary.
    """

    def exists(self, name: str) -> bool:
        try:
            return super().exists(name)
        except ClientError as err:
            status = err.response.get('ResponseMetadata', {}).get('HTTPStatusCode')
            if status in _DENIED_STATUSES:
                return False
            raise


class UniqueKeyS3Storage(TolerantExistsMixin, S3Boto3Storage):
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


class TolerantS3StaticStorage(TolerantExistsMixin, S3StaticStorage):
    """Static-file storage that survives the restricted IAM policy.

    Needed even though ``file_overwrite=True``: ``collectstatic`` calls
    ``storage.exists()`` for every file it copies (via ``delete_file``), which
    would otherwise raise 403 for every single static asset.
    """
