"""
Production environment settings
"""
import os
from .settings import Settings, DatabaseSettings, JWTSettings

# Production environment configuration
# In production, secrets should be loaded from environment variables
settings = Settings(
    debug=False,
    db=DatabaseSettings(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "prod_user"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "insurance_management")
    ),
    jwt=JWTSettings(
        secret_key=os.getenv("JWT_SECRET_KEY", ""),
        access_token_expire_minutes=int(os.getenv("JWT_EXPIRE_MINUTES", "30")),
    ),
    session_timeout_minutes=int(os.getenv("SESSION_TIMEOUT_MINUTES", "30")),
    encryption_key=os.getenv("ENCRYPTION_KEY", "")
)
