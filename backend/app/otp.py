import secrets
from passlib.context import CryptContext
from datetime import datetime, timedelta, timezone
from enum import Enum

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def generate_otp_code() -> str:
    return "".join(secrets.choice("0123456789") for _ in range(6))

def hash_otp(code: str) -> str:
    return pwd_context.hash(code)

def verify_otp_hash(code: str, hashed: str) -> bool:
    return pwd_context.verify(code, hashed)

def otp_expiry(minutes: int = 10) -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(minutes=minutes)

class OtpOutcome(Enum):
    OK = "ok"
    EXPIRED = "expired"
    WRONG_CODE = "wrong_code"
    TOO_MANY_ATTEMPTS = "too_many_attempts"
    ALREADY_CONSUMED = "already_consumed"

def evaluate_otp_attempt(
    code_input: str,
    consumed: bool,
    attempts: int,
    expires_at: datetime,
    code_hash: str,
    now: datetime
) -> OtpOutcome:
    if consumed:
        return OtpOutcome.ALREADY_CONSUMED
    if attempts >= 5:
        return OtpOutcome.TOO_MANY_ATTEMPTS
    if now > expires_at:
        return OtpOutcome.EXPIRED
    
    if verify_otp_hash(code_input, code_hash):
        return OtpOutcome.OK
    else:
        return OtpOutcome.WRONG_CODE
