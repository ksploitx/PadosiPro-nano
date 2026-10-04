import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, Index, UniqueConstraint, Text
from sqlalchemy.orm import relationship
from app.database import Base

def generate_uuid():
    return str(uuid.uuid4())

def utcnow():
    return datetime.now(timezone.utc)

class User(Base):
    __tablename__ = 'users'

    id = Column(String, primary_key=True, default=generate_uuid)
    email = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=False)
    is_verified = Column(Integer, nullable=False, default=0)
    has_completed_profile = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, nullable=False, default=utcnow)

    otp_codes = relationship("OtpCode", back_populates="user", cascade="all, delete-orphan")
    profile = relationship("Profile", back_populates="user", uselist=False, cascade="all, delete-orphan")
    task_selections = relationship("TaskSelection", back_populates="user", cascade="all, delete-orphan")

class Profile(Base):
    __tablename__ = 'profiles'

    id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, ForeignKey('users.id', ondelete='CASCADE'), unique=True, nullable=False)
    name = Column(String, nullable=False)
    mobile_number = Column(String, nullable=False)
    address = Column(String, nullable=False)
    business_name = Column(String, nullable=True)
    updated_at = Column(DateTime, nullable=False, default=utcnow, onupdate=utcnow)

    user = relationship("User", back_populates="profile")

class OtpCode(Base):
    __tablename__ = 'otp_codes'
    __table_args__ = (
        Index('idx_otp_user_created', 'user_id', 'created_at', sqlite_where=None),
    )

    id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    code_hash = Column(String, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    attempts = Column(Integer, nullable=False, default=0)
    consumed = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, nullable=False, default=utcnow)

    user = relationship("User", back_populates="otp_codes")

class Task(Base):
    __tablename__ = 'tasks'

    id = Column(String, primary_key=True, default=generate_uuid)
    name = Column(String, nullable=False)
    category = Column(String, nullable=False, index=True)
    description = Column(String, nullable=False)

    task_selections = relationship("TaskSelection", back_populates="task", cascade="all, delete-orphan")

class TaskSelection(Base):
    __tablename__ = 'task_selections'
    __table_args__ = (
        UniqueConstraint('user_id', 'task_id', name='uq_user_task'),
    )

    id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    task_id = Column(String, ForeignKey('tasks.id', ondelete='CASCADE'), nullable=False)
    requested_time = Column(DateTime, nullable=True)          # customer's preferred service time
    note = Column(String(280), nullable=True)                 # short note ≤ 280 chars
    created_at = Column(DateTime, nullable=False, default=utcnow)

    user = relationship("User", back_populates="task_selections")
    task = relationship("Task", back_populates="task_selections")
