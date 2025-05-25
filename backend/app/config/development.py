"""
Development environment settings
"""
from .settings import Settings, DatabaseSettings, JWTSettings

# Development environment configuration
settings = Settings(
    debug=True,
    db=DatabaseSettings(
        host="localhost",
        port=3306,
        user="root",
        password="",  # Empty password or enter your actual MySQL password here
        database="insurance_management"
    ),
    jwt=JWTSettings(
        secret_key="dev_secret_key_change_this_in_production",
        access_token_expire_minutes=60,  # Longer token life in development
    ),
    session_timeout_minutes=60,  # Longer sessions in development
    encryption_key="dev_encryption_key_32_chars_needed!"  # 32 bytes for AES-256
)
