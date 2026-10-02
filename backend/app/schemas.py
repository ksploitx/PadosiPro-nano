import re
from pydantic import BaseModel, EmailStr, field_validator

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str

    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not re.search(r'[A-Za-z]', v):
            raise ValueError('Password must contain at least one letter')
        if not re.search(r'\d', v):
            raise ValueError('Password must contain at least one digit')
        return v

class VerifyOtpRequest(BaseModel):
    email: EmailStr
    code: str

    @field_validator('code')
    @classmethod
    def validate_code(cls, v):
        if not re.fullmatch(r'\d{6}', v):
            raise ValueError('Code must be exactly 6 digits')
        return v

class ResendOtpRequest(BaseModel):
    email: EmailStr

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    has_completed_profile: bool
