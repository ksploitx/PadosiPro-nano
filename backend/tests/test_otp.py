import pytest
from datetime import datetime, timedelta, timezone
from app.otp import (
    generate_otp_code,
    hash_otp,
    verify_otp_hash,
    evaluate_otp_attempt,
    OtpOutcome
)

def test_generate_otp_code():
    code = generate_otp_code()
    assert len(code) == 6
    assert code.isdigit()

def test_evaluate_otp_attempt_consumed():
    now = datetime.now(timezone.utc)
    outcome = evaluate_otp_attempt(
        code_input="123456",
        consumed=True,
        attempts=0,
        expires_at=now + timedelta(minutes=5),
        code_hash="fakehash",
        now=now
    )
    assert outcome == OtpOutcome.ALREADY_CONSUMED

def test_evaluate_otp_attempt_too_many_attempts():
    now = datetime.now(timezone.utc)
    outcome = evaluate_otp_attempt(
        code_input="123456",
        consumed=False,
        attempts=5,
        expires_at=now + timedelta(minutes=5),
        code_hash="fakehash",
        now=now
    )
    assert outcome == OtpOutcome.TOO_MANY_ATTEMPTS

def test_evaluate_otp_attempt_expired():
    now = datetime.now(timezone.utc)
    outcome = evaluate_otp_attempt(
        code_input="123456",
        consumed=False,
        attempts=0,
        expires_at=now - timedelta(minutes=5),
        code_hash="fakehash",
        now=now
    )
    assert outcome == OtpOutcome.EXPIRED

def test_evaluate_otp_attempt_wrong_code():
    now = datetime.now(timezone.utc)
    real_code = "123456"
    hashed = hash_otp(real_code)
    
    outcome = evaluate_otp_attempt(
        code_input="654321",
        consumed=False,
        attempts=0,
        expires_at=now + timedelta(minutes=5),
        code_hash=hashed,
        now=now
    )
    assert outcome == OtpOutcome.WRONG_CODE

def test_evaluate_otp_attempt_ok():
    now = datetime.now(timezone.utc)
    real_code = "123456"
    hashed = hash_otp(real_code)
    
    outcome = evaluate_otp_attempt(
        code_input=real_code,
        consumed=False,
        attempts=0,
        expires_at=now + timedelta(minutes=5),
        code_hash=hashed,
        now=now
    )
    assert outcome == OtpOutcome.OK

def test_evaluate_otp_attempt_hierarchy():
    # Consumed beats too many attempts
    now = datetime.now(timezone.utc)
    outcome = evaluate_otp_attempt(
        code_input="123456",
        consumed=True,
        attempts=5,
        expires_at=now - timedelta(minutes=5),
        code_hash="fakehash",
        now=now
    )
    assert outcome == OtpOutcome.ALREADY_CONSUMED

    # Too many attempts beats expired
    outcome2 = evaluate_otp_attempt(
        code_input="123456",
        consumed=False,
        attempts=5,
        expires_at=now - timedelta(minutes=5),
        code_hash="fakehash",
        now=now
    )
    assert outcome2 == OtpOutcome.TOO_MANY_ATTEMPTS
