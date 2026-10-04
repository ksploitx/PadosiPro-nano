import re
from datetime import datetime
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


# ── Profile ──────────────────────────────────────────────────────────────────

class ProfileRequest(BaseModel):
    name: str
    mobile_number: str
    address: str
    business_name: str | None = None

    @field_validator('name')
    @classmethod
    def validate_name(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 2:
            raise ValueError('Name must be at least 2 characters')
        return v

    @field_validator('mobile_number')
    @classmethod
    def validate_mobile(cls, v: str) -> str:
        v = v.strip()
        if not re.fullmatch(r'[6-9]\d{9}', v):
            raise ValueError(
                'Mobile number must be exactly 10 digits and start with 6, 7, 8, or 9'
            )
        return v

    @field_validator('address')
    @classmethod
    def validate_address(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 5:
            raise ValueError('Address must be at least 5 characters')
        return v


class ProfileResponse(BaseModel):
    name: str
    mobile_number: str
    address: str
    business_name: str | None

    model_config = {"from_attributes": True}


# ── Tasks ─────────────────────────────────────────────────────────────────────

class TaskResponse(BaseModel):
    id: str
    name: str
    category: str
    description: str

    model_config = {"from_attributes": True}


# ── Task Selection (Phase 5) ──────────────────────────────────────────────────

class TaskSelectionItem(BaseModel):
    """One item in a task-selection batch: the task id plus optional scheduling hints."""
    task_id: str
    requested_time: datetime | None = None
    note: str | None = None

    @field_validator('note')
    @classmethod
    def validate_note_length(cls, v: str | None) -> str | None:
        if v is not None and len(v) > 280:
            raise ValueError('note must be 280 characters or fewer')
        return v


class TaskSelectionRequest(BaseModel):
    selections: list[TaskSelectionItem]

    @field_validator('selections')
    @classmethod
    def validate_not_empty(cls, v: list[TaskSelectionItem]) -> list[TaskSelectionItem]:
        if not v:
            raise ValueError('selections must contain at least one item')
        return v


class TaskSelectionResponse(BaseModel):
    """A selected task enriched with the user's scheduling hints."""
    id: str
    name: str
    category: str
    description: str
    requested_time: datetime | None
    note: str | None

    model_config = {"from_attributes": True}
