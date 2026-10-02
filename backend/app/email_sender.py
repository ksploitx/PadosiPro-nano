import smtplib
from email.message import EmailMessage
from app.config import settings
import logging

logger = logging.getLogger(__name__)

def send_otp_email(to_email: str, code: str):
    msg = EmailMessage()
    msg.set_content(f"Your PadosiPro verification code is: {code}\n\nIt expires in 10 minutes.")
    msg['Subject'] = "PadosiPro Verification Code"
    msg['From'] = "noreply@padosipro.local"
    msg['To'] = to_email

    try:
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
            server.send_message(msg)
            logger.info(f"Sent OTP email to {to_email}")
    except Exception as e:
        logger.error(f"Failed to send email to {to_email}: {e}")
