"""
User models for authentication and data validation
"""
from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional, List
from datetime import datetime
from enum import Enum

class UserRole(str, Enum):
    """User roles enum for role-based access control"""
    ADMIN = "admin"
    CONTRACT_CREATOR = "nguoi_lap_hop_dong"
    INSURED = "nguoi_duoc_bao_hiem"
    ACCOUNTING = "ke_toan"
    SUPERVISOR = "giam_sat"

class UserBase(BaseModel):
    """Base user model"""
    email: EmailStr
    ho_ten: str

class UserCreate(UserBase):
    """Model for user creation"""
    password: str = Field(..., min_length=8)
    so_dien_thoai: Optional[str] = None
    dia_chi: Optional[str] = None
    
    @validator('password')
    def password_strength(cls, v):
        """Validate password strength"""
        if not any(c.isupper() for c in v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not any(c.islower() for c in v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain at least one number")
        return v

class UserLogin(BaseModel):
    """Model for user login"""
    email: EmailStr
    password: str

class UserDB(UserBase):
    """User model as stored in database"""
    id: int
    vai_tro: UserRole
    trang_thai: bool
    ngay_tao: datetime
    ngay_cap_nhat: Optional[datetime] = None

class UserResponse(UserBase):
    """User model for API responses"""
    id: int
    vai_tro: UserRole
    trang_thai: bool
    ngay_tao: datetime
    ngay_cap_nhat: Optional[datetime] = None

class Token(BaseModel):
    """Token model for JWT authentication"""
    access_token: str
    token_type: str = "bearer"
    expires_at: int  # Unix timestamp for token expiration

class TokenData(BaseModel):
    """Token payload data"""
    sub: str  # User email or ID
    exp: int  # Expiration time
    vai_tro: str  # User role
