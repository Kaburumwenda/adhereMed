from pathlib import Path
from datetime import timedelta
from decouple import config, Csv

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=False, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='', cast=Csv())

# ──────────────────────────────────────────────
# Apps
# ──────────────────────────────────────────────
SHARED_APPS = [
    'django_tenants',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # 3rd party
    'rest_framework',
    'corsheaders',
    'django_filters',
    'drf_spectacular',
    'storages',
    # shared apps
    'tenants',
    'accounts',
    'medications',
    'exchange',
    'doctors',
    'messaging',
    'superadmin',
    'clinical_catalog',
    'usage_billing',
    'django_celery_beat',
]

TENANT_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    # hospital apps
    'departments',
    'staff_profiles',
    'patients',
    'appointments',
    'consultations',
    'prescriptions',
    'lab',
    'radiology',
    'wards',
    'triage',
    'billing',
    'notifications',
    # pharmacy apps
    'pharmacy_profile',
    'inventory',
    'suppliers',
    'purchase_orders',
    'pos',
    'dispensing',
    'expenses',
    'insurance',
    'reports',
    # homecare tenant app
    'homecare',
]

INSTALLED_APPS = list(SHARED_APPS) + [
    app for app in TENANT_APPS if app not in SHARED_APPS
]

# ──────────────────────────────────────────────
# Multi-tenancy
# ──────────────────────────────────────────────
TENANT_MODEL = 'tenants.Tenant'
TENANT_DOMAIN_MODEL = 'tenants.Domain'
PUBLIC_SCHEMA_NAME = 'public'
SHOW_PUBLIC_IF_NO_TENANT_FOUND = True

# ──────────────────────────────────────────────
# Middleware
# ──────────────────────────────────────────────
MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'config.middleware.HeaderTenantMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'usage_billing.middleware.RequestUsageMiddleware',
    'homecare.audit.HomecareAuditMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

# ──────────────────────────────────────────────
# Database (PostgreSQL + django-tenants)
# ──────────────────────────────────────────────
DATABASES = {
    'default': {
        'ENGINE': 'django_tenants.postgresql_backend',
        'NAME': config('DB_NAME', default='adheremeddb'),
        'USER': config('DB_USER', default='adheremeduser'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST': config('DB_HOST', default='localhost'),
        'PORT': config('DB_PORT', default='5432'),
    }
}

DATABASE_ROUTERS = ('django_tenants.routers.TenantSyncRouter',)

# ──────────────────────────────────────────────
# Auth
# ──────────────────────────────────────────────
AUTH_USER_MODEL = 'accounts.User'

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# ──────────────────────────────────────────────
# REST Framework
# ──────────────────────────────────────────────
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'DEFAULT_FILTER_BACKENDS': (
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ),
    'DEFAULT_PAGINATION_CLASS': 'config.pagination.StandardPagination',
    'PAGE_SIZE': 20,
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
}

SIMPLE_JWT = {
    # No silent refresh: issue a long-lived access token so the user stays
    # logged in until they explicitly log out (which blacklists the refresh
    # token below). Adjust if a stricter session policy is required.
    'ACCESS_TOKEN_LIFETIME': timedelta(days=365),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=365),
    'ROTATE_REFRESH_TOKENS': False,
    'BLACKLIST_AFTER_ROTATION': False,
    'AUTH_HEADER_TYPES': ('Bearer',),
}

# ──────────────────────────────────────────────
# CORS
# ──────────────────────────────────────────────
CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOWED_ORIGINS = [] if DEBUG else []
CORS_ALLOW_HEADERS = [
    'accept',
    'authorization',
    'content-type',
    'origin',
    'user-agent',
    'x-csrftoken',
    'x-requested-with',
    'x-tenant-schema',
]

# ──────────────────────────────────────────────
# OpenAPI / Swagger
# ──────────────────────────────────────────────
SPECTACULAR_SETTINGS = {
    'TITLE': 'AfyaOne API',
    'DESCRIPTION': 'SaaS Hospital & Pharmacy Ecosystem',
    'VERSION': '1.0.0',
    'SERVE_INCLUDE_SCHEMA': False,
}

# ──────────────────────────────────────────────
# Email (SMTP / SSL)
# ──────────────────────────────────────────────
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = config('EMAIL_HOST', default='mail.tiktek-ex.com')
EMAIL_PORT = config('EMAIL_PORT', default=465, cast=int)
EMAIL_USE_SSL = True
EMAIL_HOST_USER = config('EMAIL_HOST_USER', default='afyaone@tiktek-ex.com')
EMAIL_HOST_PASSWORD = config('EMAIL_HOST_PASSWORD')
DEFAULT_FROM_EMAIL = 'AfyaOne <afyaone@tiktek-ex.com>'
FRONTEND_URL = config('FRONTEND_URL', default='http://localhost:3000')

# ──────────────────────────────────────────────
# Homecare tenant mailbox (IMAP + SMTP)
# Per-tenant configuration is stored in the tenant DB via the MailAccount
# model and managed at /homecare/mail/settings. No global defaults are
# provided — each homecare tenant must configure their own mailbox.
# ──────────────────────────────────────────────
HOMECARE_MAIL = {}

# ──────────────────────────────────────────────
# Internationalization
# ──────────────────────────────────────────────
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Africa/Nairobi'
USE_I18N = True
USE_TZ = True

# ──────────────────────────────────────────────
# Static & Media  (local dev or AWS S3)
# ──────────────────────────────────────────────
USE_S3 = config('USE_S3', default=False, cast=bool)

if USE_S3:
    # ── AWS credentials ──
    AWS_ACCESS_KEY_ID     = config('AWS_ACCESS_KEY_ID')
    AWS_SECRET_ACCESS_KEY = config('AWS_SECRET_ACCESS_KEY')
    AWS_STORAGE_BUCKET_NAME = config('AWS_STORAGE_BUCKET_NAME')
    AWS_S3_REGION_NAME      = config('AWS_S3_REGION_NAME', default='us-east-1')
    AWS_S3_SIGNATURE_VERSION = 's3v4'
    AWS_S3_ADDRESSING_STYLE  = 'virtual'

    # Optional CloudFront domain — only used for *public* assets (static files).
    # Private media MUST be served via signed URLs from the real S3 endpoint
    # (mixing custom domain + querystring auth causes 403 SignatureDoesNotMatch).
    AWS_CLOUDFRONT_DOMAIN = config('AWS_CLOUDFRONT_DOMAIN', default='')

    # Real S3 host used for signing media URLs.
    AWS_S3_ENDPOINT_HOST = f'{AWS_STORAGE_BUCKET_NAME}.s3.{AWS_S3_REGION_NAME}.amazonaws.com'

    # Public/static gets the CloudFront domain when configured, else S3.
    AWS_S3_CUSTOM_DOMAIN = AWS_CLOUDFRONT_DOMAIN or AWS_S3_ENDPOINT_HOST

    # ── Bucket behaviour ──
    # NOTE: django-storages uses HeadObject to test for filename collisions when
    # AWS_S3_FILE_OVERWRITE=False. If the IAM user lacks `s3:ListBucket`, S3
    # returns 403 instead of 404 for missing keys and uploads fail. We avoid
    # the probe entirely by enabling overwrite and pinning each upload to a
    # unique key via `UniqueKeyS3Storage.get_available_name` (see below).
    AWS_S3_FILE_OVERWRITE     = True
    AWS_DEFAULT_ACL           = None    # rely on bucket policy; don't set object ACLs
    AWS_S3_OBJECT_PARAMETERS  = {'CacheControl': 'max-age=86400'}
    AWS_QUERYSTRING_EXPIRE    = config('AWS_QUERYSTRING_EXPIRE', default=3600, cast=int)

    # ── Static files (public, no signed URLs) ──
    STATIC_LOCATION = 'static'
    STATIC_URL      = f'https://{AWS_S3_CUSTOM_DOMAIN}/{STATIC_LOCATION}/'

    # ── Media files (signed URLs for privacy) ──
    # Build the URL with the *real* S3 endpoint so signature host matches.
    MEDIA_LOCATION = 'media'
    MEDIA_URL      = f'https://{AWS_S3_ENDPOINT_HOST}/{MEDIA_LOCATION}/'

    STORAGES = {
        # media/upload files — private, signed URLs (NO custom_domain so
        # the URL host matches the signing host).
        'default': {
            'BACKEND': 'config.storage_backends.UniqueKeyS3Storage',
            'OPTIONS': {
                'location': MEDIA_LOCATION,
                'querystring_auth': True,
                'default_acl': None,
                'file_overwrite': True,
                'custom_domain': False,
                'signature_version': 's3v4',
                'addressing_style': 'virtual',
            },
        },
        # static files — public, no auth needed
        'staticfiles': {
            'BACKEND': 'storages.backends.s3boto3.S3StaticStorage',
            'OPTIONS': {
                'location': STATIC_LOCATION,
                'querystring_auth': False,
                'default_acl': None,
                'file_overwrite': True,
                'custom_domain': AWS_S3_CUSTOM_DOMAIN,
            },
        },
    }
else:
    STATIC_URL  = 'static/'
    STATIC_ROOT = BASE_DIR / 'static'
    MEDIA_URL   = 'media/'
    MEDIA_ROOT  = BASE_DIR / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ──────────────────────────────────────────────
# Celery / Beat
# ──────────────────────────────────────────────
CELERY_BROKER_URL = config('CELERY_BROKER_URL', default='redis://localhost:6379/0')
CELERY_RESULT_BACKEND = config('CELERY_RESULT_BACKEND', default='redis://localhost:6379/1')
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = TIME_ZONE
CELERY_ENABLE_UTC = True
CELERY_BEAT_SCHEDULER = 'django_celery_beat.schedulers:DatabaseScheduler'
# Eager mode for local dev/testing without a broker (override via env)
CELERY_TASK_ALWAYS_EAGER = config('CELERY_TASK_ALWAYS_EAGER', default=False, cast=bool)
CELERY_TASK_EAGER_PROPAGATES = True

