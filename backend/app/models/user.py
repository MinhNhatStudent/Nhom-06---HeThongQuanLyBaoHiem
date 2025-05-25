"""
User models for authentication and data validation
"""
from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional, List, Union
from datetime import datetime
from enum import Enum

class UserRole(str, Enum):
    """User roles enum for role-based access control"""
    ADMIN = "admin"
    CONTRACT_CREATOR = "contract_creator" 
    INSURED = "insured_person"
    ACCOUNTING = "accounting"
    SUPERVISOR = "supervisor"

class UserStatus(str, Enum):
    """User status enum"""
    ACTIVE = "active"
    INACTIVE = "inactive"

class UserBase(BaseModel):
    """Base user model"""
    email: EmailStr

class UserCreate(BaseModel):
    """Model for user creation"""
    username: str = Field(..., min_length=3)
    email: EmailStr
    vai_tro: UserRole
    insurance_type_id: Optional[int] = None

class UserActivate(BaseModel):
    """Model for user activation"""
    token: str
    password: str = Field(..., min_length=8)
    
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
    username: str
    password: str

class UserPasswordReset(BaseModel):
    """Model for requesting a password reset"""
    email: EmailStr

class UserPasswordResetConfirm(BaseModel):
    """Model for confirming a password reset"""
    token: str
    password: str = Field(..., min_length=8)
    
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

class UserPasswordChange(BaseModel):
    """Model for changing password"""
    current_password: str
    new_password: str = Field(..., min_length=8)
    
    @validator('new_password')
    def password_strength(cls, v):
        """Validate password strength"""
        if not any(c.isupper() for c in v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not any(c.islower() for c in v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain at least one number")
        return v

class UserUpdate(BaseModel):
    """Model for user update"""
    email: Optional[EmailStr] = None
    vai_tro: Optional[UserRole] = None
    trang_thai: Optional[UserStatus] = None
    insurance_type_id: Optional[int] = None

class UserDB(BaseModel):
    """User model as stored in database"""
    id: int
    username: str
    email: EmailStr
    vai_tro: UserRole
    trang_thai: UserStatus
    insurance_type_id: Optional[int] = None
    activated: bool
    created_at: datetime

class UserResponse(BaseModel):
    """User model for API responses"""
    id: int
    username: str
    email: EmailStr
    vai_tro: UserRole
    trang_thai: UserStatus
    insurance_type_id: Optional[int] = None
    activated: bool
    created_at: Union[datetime, str]

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
    session_id: Optional[str] = None  # Session ID for session management

class ActivationResponse(BaseModel):
    """Response model for user activation"""
    success: bool
    message: str
    user_id: Optional[int] = None
    username: Optional[str] = None

class ResetRequestResponse(BaseModel):
    """Response model for password reset request"""
    success: bool
    message: str

class ResetConfirmResponse(BaseModel):
    """Response model for password reset confirmation"""
    success: bool
    message: str

class ChangePasswordResponse(BaseModel):
    """Response model for password change"""
    success: bool
    message: str
