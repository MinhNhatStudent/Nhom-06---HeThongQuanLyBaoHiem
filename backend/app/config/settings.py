"""
Environment-specific settings
"""
import os
from pydantic import BaseModel

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

class Settings(BaseModel):
    """Application settings"""
    app_name: str = "Hệ thống Quản lý Bảo hiểm"
    debug: bool = False
    db: DatabaseSettings
    jwt: JWTSettings
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
