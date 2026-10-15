# Storing media & static on AWS S3

Status: **code is ready, the switch is deliberately OFF** (`USE_S3=False`) in both
`backend/.env` (local) and `/home/ubuntu/adheremed/.env` (production).

Reason: the IAM user currently attached to the app **can upload but cannot read**
from the bucket, so turning S3 on today would make every uploaded file return
`403 Forbidden`.

## Verified bucket permissions (2026-10-15)

Bucket `adheremed-s3-bucket`, region `us-east-2`, IAM user `adheremed-s3-user`
(account `110820223590`). Probed directly:

| Operation | Result |
|---|---|
| `PutObject` | OK |
| `GetBucketLocation` | OK |
| Presign URL generation | OK |
| `ListBucket` | **AccessDenied** |
| `HeadObject` | **403 Forbidden** |
| `GetObject` (direct) | **AccessDenied** |
| `DeleteObject` | **AccessDenied** |
| Presigned `GET` fetched over HTTPS | **403 Forbidden** |
| Unsigned (public) `GET` | **403 Forbidden** |

Writes succeed; **all reads fail**. That is what blocks the migration.

## 1. Grant read permissions (required, AWS console or CLI)

Attach this inline policy to `adheremed-s3-user` (replace the account id if you
are in a different account):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BucketLevel",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::adheremed-s3-bucket"
    },
    {
      "Sid": "ObjectLevel",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::adheremed-s3-bucket/*"
    }
  ]
}
```

`GetObject` makes media readable (media URLs are presigned).
`ListBucket` + `DeleteObject` let `collectstatic` run natively; without them the
`s3_sync` command below still works, because it uploads with `put_object` and
never probes for existing keys.

### Static files need one extra decision

Static URLs are **not** presigned (`querystring_auth: False`), so pick one:

* **Public static prefix (recommended for CDN/caching).** Add a bucket policy
  allowing `s3:GetObject` on `arn:aws:s3:::adheremed-s3-bucket/static/*` for
  `Principal: "*"`. Static assets contain no tenant data.
* **Keep the bucket fully private.** In `config/settings.py`, set
  `'querystring_auth': True` for the `staticfiles` storage so static URLs are
  presigned too. Costs per-request signing and no CDN caching.

## 2. Upload the files that already exist

Production has ~5.5 MB of uploads on local disk
(`media/org_logos`, `media/pharmacy_logos`, `media/doctor_pictures`,
`media/doctor_signatures`, `media/homecare`, `media/po_proofs`, ...).
Once `USE_S3=True` those `FileField` values resolve against the bucket, so they
must be uploaded first or every existing image 404s.

```bash
cd /home/ubuntu/adheremed && source venv/bin/activate
python manage.py s3_sync --dry-run     # preview
python manage.py s3_sync               # media + collected static
```

Options: `--media` (only `MEDIA_ROOT`), `--static` (collect then upload),
`--verbose` (per-file log). Uploading is idempotent — keys are overwritten.
It never deletes, which is also why `collectstatic --clear/--delete` must be
avoided with this IAM user.

## 3. Turn S3 on

In each `.env`:

```
USE_S3=True
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_STORAGE_BUCKET_NAME=adheremed-s3-bucket
AWS_S3_REGION_NAME=us-east-2
AWS_CLOUDFRONT_DOMAIN=          # optional, public assets only
```

Then restart the app (`sudo systemctl restart gunicorn`).

## 4. Verify

```bash
python manage.py shell -c "
from django.core.files.storage import default_storage
from django.contrib.staticfiles.storage import staticfiles_storage
from django.core.files.base import ContentFile
n = default_storage.save('_probe/x.txt', ContentFile(b'ok'))
print('saved:', n); print('url:', default_storage.url(n))
print('static:', staticfiles_storage.url('admin/css/base.css'))
"
```

Then fetch the printed media URL and confirm it returns **HTTP 200**, and load
the app to confirm CSS/JS resolve.

## Code changes that support S3 (already in place)

| File | Change |
|---|---|
| `config/settings.py` | `USE_S3` gate; `STATIC_ROOT`/`MEDIA_ROOT` now always defined (the DEBUG media route and tooling expect them); staticfiles storage switched to the tolerant backend |
| `config/storage_backends.py` | `TolerantExistsMixin` (treats 401/403 on `HeadObject` as "not found" so `collectstatic` does not crash; workaround for the narrow IAM policy) + `TolerantS3StaticStorage` |
| `config/urls.py` | local media route only registered when *not* using S3 (with S3, `MEDIA_URL` is an absolute bucket URL) |
| `config/pdf_branding.py` | **functional fix** — reportlab needs a real path, but S3 raises `NotImplementedError` for `FileField.path`. Non-local logos are now downloaded into a per-process temp dir (`tempfile.gettempdir()/adheremed-branding`). Without this, every PDF would silently fall back to the bundled default logo. |
| `tenants/management/commands/s3_sync.py` | backfill/upload command described above |

## Known leftovers to clean up

Two tiny probe objects were created while testing and **could not be deleted**
(no `s3:DeleteObject`):

* `s3://adheremed-s3-bucket/_probe/read-me.txt`
* `s3://adheremed-s3-bucket/_probe/django-write-1d7fc0ee.txt`

Remove them from the console once `s3:DeleteObject` is granted.

## Provisioning jobs and S3

`provision_tenant_task` runs through Celery. Celery must **not** be in
`CELERY_TASK_ALWAYS_EAGER` mode in production, and the broker must be reachable
so schema provisioning happens in the worker rather than the request thread.
