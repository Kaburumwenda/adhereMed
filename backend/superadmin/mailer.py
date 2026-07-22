"""Platform email helpers.

Sends transactional emails (e.g. patient welcome messages) using the active
``MailConfiguration`` stored in the public schema, falling back to the Django
``settings`` email defaults when no active configuration exists.
"""
import logging

from django.conf import settings
from django.core.mail import EmailMultiAlternatives, get_connection
from django.utils import timezone

logger = logging.getLogger(__name__)


def _get_active_config():
    """Return the active MailConfiguration row, or None on any failure."""
    try:
        from .models import MailConfiguration
        cfg = MailConfiguration.get_solo()
        if cfg and cfg.is_active and cfg.smtp_host and cfg.username:
            return cfg
    except Exception:  # pragma: no cover - defensive
        logger.exception("Failed to load MailConfiguration")
    return None


def get_mail_connection():
    """Build an SMTP connection and resolve the From address.

    Returns a tuple ``(connection, from_email)``.
    """
    cfg = _get_active_config()
    if cfg:
        connection = get_connection(
            backend="django.core.mail.backends.smtp.EmailBackend",
            host=cfg.smtp_host,
            port=cfg.smtp_port,
            username=cfg.username,
            password=cfg.password,
            use_ssl=cfg.smtp_use_ssl,
            use_tls=not cfg.smtp_use_ssl,
        )
        from_email = f"{cfg.from_name} <{cfg.from_email}>" if cfg.from_name else cfg.from_email
        return connection, from_email

    # Fall back to Django settings.
    return get_connection(), settings.DEFAULT_FROM_EMAIL


def send_platform_mail(subject, to, text_body, html_body=None):
    """Send an email using the active platform mail configuration.

    Returns True on success, False on failure (never raises).
    """
    if isinstance(to, str):
        to = [to]
    to = [addr for addr in to if addr]
    if not to:
        return False

    try:
        connection, from_email = get_mail_connection()
        msg = EmailMultiAlternatives(
            subject=subject,
            body=text_body,
            from_email=from_email,
            to=to,
            connection=connection,
        )
        if html_body:
            msg.attach_alternative(html_body, "text/html")
        msg.send()
        return True
    except Exception:
        logger.exception("Failed to send platform mail to %s", to)
        return False


def send_test_mail(to):
    """Send a verification email and record the result on the config row.

    Returns a tuple ``(ok, error_message)``.
    """
    subject = "AdhereMed mail configuration test"
    text = (
        "This is a test message confirming that your AdhereMed mail "
        "configuration is working correctly."
    )
    ok = send_platform_mail(subject, to, text)
    try:
        from .models import MailConfiguration
        cfg = MailConfiguration.get_solo()
        cfg.last_verified_at = timezone.now()
        cfg.last_verified_ok = ok
        cfg.last_error = "" if ok else "Test message could not be delivered."
        cfg.save(update_fields=["last_verified_at", "last_verified_ok", "last_error"])
    except Exception:
        logger.exception("Failed to record mail test result")
    return ok, "" if ok else "Test message could not be delivered."


def send_patient_welcome_email(user, patient):
    """Send the welcome email to a newly registered patient.

    Includes their AdhereMed patient ID and instructions to use it across
    all AdhereMed services. Never raises.
    """
    try:
        email = getattr(user, "email", None)
        if not email:
            return False
        patient_id = getattr(patient, "patient_id", "") or getattr(patient, "patient_number", "")
        first_name = getattr(user, "first_name", "") or "there"

        subject = "Welcome to AdhereMed — Your Patient ID"
        text_body = (
            f"Hello {first_name},\n\n"
            f"Welcome to AdhereMed! Your account has been created successfully.\n\n"
            f"Your unique Patient ID is: {patient_id}\n\n"
            f"Please keep this ID safe. Use it to access AdhereMed services "
            f"everywhere — at pharmacies, hospitals, laboratories, radiology "
            f"centres, homecare providers and with your insurer across the "
            f"AdhereMed ecosystem.\n\n"
            f"Thank you for choosing AdhereMed.\n\n"
            f"— The AdhereMed Team\n"
            f"info@adheremed.co | https://adheremed.co/"
        )
        html_body = f"""
        <div style="font-family:Segoe UI,Arial,sans-serif;max-width:560px;margin:0 auto;color:#0f172a">
          <div style="background:linear-gradient(135deg,#0d9488,#2563EB);padding:24px;border-radius:14px 14px 0 0">
            <h1 style="color:#fff;margin:0;font-size:20px">Welcome to AdhereMed</h1>
          </div>
          <div style="border:1px solid #e2e8f0;border-top:none;padding:24px;border-radius:0 0 14px 14px">
            <p>Hello {first_name},</p>
            <p>Welcome to AdhereMed! Your account has been created successfully.</p>
            <div style="text-align:center;margin:22px 0">
              <div style="font-size:12px;color:#64748b;text-transform:uppercase;letter-spacing:1px">Your Patient ID</div>
              <div style="font-size:32px;font-weight:800;letter-spacing:2px;color:#0d9488">{patient_id}</div>
            </div>
            <p>Please keep this ID safe. Use it to access AdhereMed services
            <strong>everywhere</strong> — at pharmacies, hospitals, laboratories,
            radiology centres, homecare providers and with your insurer across the
            AdhereMed ecosystem.</p>
            <p>Thank you for choosing AdhereMed.</p>
            <p style="color:#64748b;font-size:13px;margin-top:24px">
              — The AdhereMed Team<br>
              <a href="mailto:info@adheremed.co" style="color:#0d9488">info@adheremed.co</a> ·
              <a href="https://adheremed.co/" style="color:#0d9488">adheremed.co</a>
            </p>
          </div>
        </div>
        """
        return send_platform_mail(subject, email, text_body, html_body)
    except Exception:
        logger.exception("Failed to send patient welcome email")
        return False


def send_homecare_enrollment_email(user, patient_id, login_email=None,
                                   temporary_password=None, homecare_name=None):
    """Send a welcome email to a patient enrolled by a homecare provider.

    Includes the AdhereMed patient ID, the login email and — only when the
    account was newly created — a temporary password. Never raises.
    """
    try:
        email = login_email or getattr(user, "email", None)
        if not email:
            return False
        first_name = getattr(user, "first_name", "") or "there"
        provider = homecare_name or "your homecare provider"

        pw_text = ""
        if temporary_password:
            pw_text = (
                f"Temporary password: {temporary_password}\n"
                f"(Please change it after your first login.)\n\n"
            )
        subject = "Welcome to AdhereMed Homecare — Your account details"
        text_body = (
            f"Hello {first_name},\n\n"
            f"You have been enrolled for homecare with {provider} on AdhereMed.\n\n"
            f"Your AdhereMed Patient ID: {patient_id}\n"
            f"Login email: {email}\n"
            f"{pw_text}"
            f"Sign in to your patient dashboard to view your homecare, doses, "
            f"medications, care team and consents. Your Patient ID also works "
            f"across AdhereMed — at pharmacies, hospitals, laboratories, radiology "
            f"centres and with your insurer.\n\n"
            f"Thank you for choosing AdhereMed.\n\n"
            f"— The AdhereMed Team\n"
            f"info@adheremed.co | https://adheremed.co/"
        )
        pw_html = ""
        if temporary_password:
            pw_html = f"""
            <tr>
              <td style="padding:6px 0;color:#64748b">Temporary password</td>
              <td style="padding:6px 0;font-weight:700;text-align:right">{temporary_password}</td>
            </tr>
            <tr><td colspan="2" style="font-size:12px;color:#94a3b8;padding-bottom:6px">
              Please change it after your first login.</td></tr>
            """
        html_body = f"""
        <div style="font-family:Segoe UI,Arial,sans-serif;max-width:560px;margin:0 auto;color:#0f172a">
          <div style="background:linear-gradient(135deg,#0d9488,#2563EB);padding:24px;border-radius:14px 14px 0 0">
            <h1 style="color:#fff;margin:0;font-size:20px">Welcome to AdhereMed Homecare</h1>
          </div>
          <div style="border:1px solid #e2e8f0;border-top:none;padding:24px;border-radius:0 0 14px 14px">
            <p>Hello {first_name},</p>
            <p>You have been enrolled for homecare with <strong>{provider}</strong> on AdhereMed.</p>
            <div style="text-align:center;margin:22px 0">
              <div style="font-size:12px;color:#64748b;text-transform:uppercase;letter-spacing:1px">Your Patient ID</div>
              <div style="font-size:32px;font-weight:800;letter-spacing:2px;color:#0d9488">{patient_id}</div>
            </div>
            <table style="width:100%;border-collapse:collapse;margin:8px 0 16px">
              <tr>
                <td style="padding:6px 0;color:#64748b">Login email</td>
                <td style="padding:6px 0;font-weight:700;text-align:right">{email}</td>
              </tr>
              {pw_html}
            </table>
            <p>Sign in to your patient dashboard to view your homecare, doses,
            medications, care team and consents. Your Patient ID also works
            <strong>everywhere</strong> across AdhereMed — at pharmacies, hospitals,
            laboratories, radiology centres and with your insurer.</p>
            <p>Thank you for choosing AdhereMed.</p>
            <p style="color:#64748b;font-size:13px;margin-top:24px">
              — The AdhereMed Team<br>
              <a href="mailto:info@adheremed.co" style="color:#0d9488">info@adheremed.co</a> ·
              <a href="https://adheremed.co/" style="color:#0d9488">adheremed.co</a>
            </p>
          </div>
        </div>
        """
        return send_platform_mail(subject, email, text_body, html_body)
    except Exception:
        logger.exception("Failed to send homecare enrollment email")
        return False


def send_vitals_escalation_email(to, *, patient_name, news2_total, band,
                                 vitals_summary, recorded_at=None,
                                 homecare_name=None, recipient_role="clinician"):
    """Notify a doctor or patient that recorded vitals triggered an escalation.

    ``vitals_summary`` is a list of ``(label, value)`` tuples. ``to`` may be a
    single address or a list. Never raises; returns True/False.
    """
    try:
        if isinstance(to, str):
            to = [to]
        to = [addr for addr in to if addr]
        if not to:
            return False

        provider = homecare_name or "your homecare provider"
        band_colors = {
            'High': '#b91c1c', 'Medium': '#d97706',
            'Low-Medium': '#0284c7', 'Low': '#059669',
        }
        accent = band_colors.get(band, '#b91c1c')
        when = ""
        if recorded_at:
            try:
                when = recorded_at.strftime('%d %b %Y, %H:%M')
            except Exception:
                when = str(recorded_at)

        is_patient = recipient_role == "patient"
        if is_patient:
            intro = (
                f"During a recent check by {provider}, some of your vital signs "
                f"were outside the expected range and your care team has been "
                f"alerted so they can follow up with you."
            )
            closing = (
                "Please follow any instructions from your care team. If you feel "
                "unwell or your symptoms get worse, seek medical help right away."
            )
        else:
            intro = (
                f"An automatic early-warning escalation was raised for "
                f"<strong>{patient_name}</strong> ({provider}). The recorded "
                f"vitals produced a NEWS2 score of <strong>{news2_total}</strong> "
                f"({band} risk). Please review the patient and take appropriate "
                f"clinical action."
            )
            closing = (
                "This is an automated clinical alert generated when recorded "
                "vitals meet the NEWS2 escalation threshold."
            )

        rows_html = "".join(
            f"<tr><td style='padding:6px 0;color:#64748b'>{label}</td>"
            f"<td style='padding:6px 0;font-weight:700;text-align:right'>{value}</td></tr>"
            for label, value in (vitals_summary or [])
        )
        rows_text = "\n".join(f"  {label}: {value}" for label, value in (vitals_summary or []))

        subject = (
            "AdhereMed Homecare — Your care team has been alerted"
            if is_patient else
            f"AdhereMed Homecare ALERT — {patient_name} (NEWS2 {news2_total}, {band})"
        )
        text_body = (
            f"{'Hello,' if is_patient else 'Clinical alert'}\n\n"
            f"{intro.replace('<strong>', '').replace('</strong>', '')}\n\n"
            f"NEWS2 score: {news2_total} ({band} risk)\n"
            f"Patient: {patient_name}\n"
            f"{('Recorded: ' + when) if when else ''}\n\n"
            f"Vitals:\n{rows_text}\n\n"
            f"{closing}\n\n"
            f"— AdhereMed Homecare\n"
            f"info@adheremed.co | https://adheremed.co/"
        )
        html_body = f"""
        <div style="font-family:Segoe UI,Arial,sans-serif;max-width:560px;margin:0 auto;color:#0f172a">
          <div style="background:{accent};padding:20px 24px;border-radius:14px 14px 0 0">
            <h1 style="color:#fff;margin:0;font-size:19px">
              {'Your care team has been alerted' if is_patient else 'Clinical escalation alert'}
            </h1>
          </div>
          <div style="border:1px solid #e2e8f0;border-top:none;padding:24px;border-radius:0 0 14px 14px">
            <p>{intro}</p>
            <div style="text-align:center;margin:20px 0">
              <div style="font-size:12px;color:#64748b;text-transform:uppercase;letter-spacing:1px">NEWS2 score</div>
              <div style="font-size:34px;font-weight:800;color:{accent}">{news2_total}</div>
              <div style="font-size:13px;font-weight:700;color:{accent}">{band} risk</div>
            </div>
            <table style="width:100%;border-collapse:collapse;margin:8px 0 16px">
              <tr><td style="padding:6px 0;color:#64748b">Patient</td>
                  <td style="padding:6px 0;font-weight:700;text-align:right">{patient_name}</td></tr>
              {f"<tr><td style='padding:6px 0;color:#64748b'>Recorded</td><td style='padding:6px 0;font-weight:700;text-align:right'>{when}</td></tr>" if when else ""}
              {rows_html}
            </table>
            <p style="color:#64748b;font-size:13px">{closing}</p>
            <p style="color:#64748b;font-size:13px;margin-top:20px">
              — AdhereMed Homecare<br>
              <a href="mailto:info@adheremed.co" style="color:#0d9488">info@adheremed.co</a> ·
              <a href="https://adheremed.co/" style="color:#0d9488">adheremed.co</a>
            </p>
          </div>
        </div>
        """
        try:
            from django_tenants.utils import schema_context
            with schema_context('public'):
                return send_platform_mail(subject, to, text_body, html_body)
        except Exception:
            return send_platform_mail(subject, to, text_body, html_body)
    except Exception:
        logger.exception("Failed to send vitals escalation email")
        return False
