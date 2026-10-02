from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from datetime import datetime, timezone

from app.database import AsyncSessionLocal
from app.models import User, OtpCode
from app.schemas import RegisterRequest, VerifyOtpRequest, ResendOtpRequest, LoginRequest, TokenResponse
from app.deps import get_db
from app.security import hash_password, verify_password, create_access_token
from app.otp import (
    generate_otp_code, hash_otp, otp_expiry,
    evaluate_otp_attempt, OtpOutcome
)
from app.email_sender import send_otp_email
from app.redis_client import redis_client

router = APIRouter(prefix="/auth", tags=["auth"])

def get_now():
    return datetime.now(timezone.utc).replace(tzinfo=None)

@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(request: RegisterRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == request.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Email already exists")
    
    new_user = User(
        email=request.email,
        password_hash=hash_password(request.password)
    )
    db.add(new_user)
    
    code = generate_otp_code()
    otp_entry = OtpCode(
        user=new_user,
        code_hash=hash_otp(code),
        expires_at=otp_expiry(10)
    )
    db.add(otp_entry)
    
    await db.commit()
    
    send_otp_email(request.email, code)
    
    return {
        "message": "Account created. Check your email for a verification code.",
        "email": request.email
    }

@router.post("/resend-otp")
async def resend_otp(request: ResendOtpRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == request.email))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=404, detail="No account")
    
    if user.is_verified:
        raise HTTPException(status_code=400, detail="Already verified")
        
    cooldown_key = f"otp:resend_cooldown:{request.email}"
    ttl = await redis_client.ttl(cooldown_key)
    if ttl > 0:
        raise HTTPException(status_code=429, detail=f"Please wait {ttl}s before requesting another code")
        
    code = generate_otp_code()
    otp_entry = OtpCode(
        user=user,
        code_hash=hash_otp(code),
        expires_at=otp_expiry(10)
    )
    db.add(otp_entry)
    await db.commit()
    
    await redis_client.setex(cooldown_key, 30, "1")
    
    send_otp_email(request.email, code)
    
    return {"message": "A new verification code has been sent"}

@router.post("/verify-otp", response_model=TokenResponse)
async def verify_otp(request: VerifyOtpRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == request.email))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=404, detail="No account")
        
    if user.is_verified:
        raise HTTPException(status_code=400, detail="Already verified")
        
    otp_result = await db.execute(
        select(OtpCode)
        .where(OtpCode.user_id == user.id)
        .order_by(OtpCode.created_at.desc())
        .limit(1)
    )
    otp = otp_result.scalar_one_or_none()
    
    if not otp:
        raise HTTPException(status_code=400, detail="No active code")
        
    now = get_now()
    outcome = evaluate_otp_attempt(
        code_input=request.code,
        consumed=bool(otp.consumed),
        attempts=otp.attempts,
        expires_at=otp.expires_at,
        code_hash=otp.code_hash,
        now=now
    )
    
    if outcome == OtpOutcome.ALREADY_CONSUMED:
        raise HTTPException(status_code=400, detail="Already used")
    elif outcome == OtpOutcome.TOO_MANY_ATTEMPTS:
        raise HTTPException(status_code=429, detail="Too many wrong attempts. Please request a new code.")
    elif outcome == OtpOutcome.EXPIRED:
        raise HTTPException(status_code=400, detail="This code has expired. Please request a new one.")
    elif outcome == OtpOutcome.WRONG_CODE:
        otp.attempts += 1
        await db.commit()
        attempts_left = 5 - otp.attempts
        raise HTTPException(status_code=400, detail=f"Incorrect code. {attempts_left} attempt(s) left.")
    elif outcome == OtpOutcome.OK:
        otp.consumed = 1
        user.is_verified = 1
        await db.commit()
        
        token = create_access_token(data={"sub": user.id})
        return TokenResponse(
            access_token=token,
            has_completed_profile=bool(user.has_completed_profile)
        )

@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == request.email))
    user = result.scalar_one_or_none()
    
    if not user or not verify_password(request.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
        
    if not user.is_verified:
        raise HTTPException(status_code=403, detail="Please verify your email before logging in")
        
    token = create_access_token(data={"sub": user.id})
    return TokenResponse(
        access_token=token,
        has_completed_profile=bool(user.has_completed_profile)
    )
