"""
Environment-specific settings
"""
import os
from pydantic import BaseModel, EmailStr

class DatabaseSettings(BaseModel):
    """Database connection settings"""
    host: str
    port: int
    user: str
    password: str
    database: str

class JWTSettings(BaseModel):
    """JWT authentication settings"""
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30

class EmailSettings(BaseModel):
    """Email settings"""
    smtp_server: str
    smtp_port: int
    smtp_username: str = None
    smtp_password: str = None
    sender_email: str
    use_tls: bool = True
    
class AppURLSettings(BaseModel):
    """Application URL settings"""
    api_url: str
    frontend_url: str

class Settings(BaseModel):
    """Application settings"""
    app_name: str = "Hệ thống Quản lý Bảo hiểm"
    debug: bool = False
    db: DatabaseSettings
    jwt: JWTSettings
    email: EmailSettings
    app: AppURLSettings
    session_timeout_minutes: int = 30
    encryption_key: str

# Load environment-specific settings
def get_settings():
    """Get environment-specific settings"""
    env = os.getenv("APP_ENV", "development")
    
    if env == "production":
        # Production settings would typically be loaded from environment variables
        from .production import settings
    else:
        # Development settings
        from .development import settings
    
    return settings
