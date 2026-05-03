from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from django.conf import settings


def send_welcome_email(user_id):
    from accounts.models import User
    try:
        user = User.objects.select_related('tenant').get(id=user_id)
    except User.DoesNotExist:
        return

    context = {
        'user': user,
        'tenant': user.tenant,
        'role': user.get_role_display(),
        'login_url': settings.ALLOWED_HOSTS[0] if settings.ALLOWED_HOSTS else 'localhost:8080',
    }

    html_message = render_to_string('emails/welcome.html', context)
    plain_message = strip_tags(html_message)

    send_mail(
        subject='Welcome to AfyaOne!',
        message=plain_message,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[user.email],
        html_message=html_message,
        fail_silently=True,
    )
