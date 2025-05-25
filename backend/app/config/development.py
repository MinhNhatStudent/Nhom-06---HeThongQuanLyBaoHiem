"""
Development environment settings
"""
from .settings import Settings, DatabaseSettings, JWTSettings, EmailSettings, AppURLSettings

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
    ),    email=EmailSettings(
        smtp_server="smtp.gmail.com",
        smtp_port=587,
        smtp_username="nhatalex14@gmail.com",  # Thay bằng email test thực tế
        smtp_password="aaaq awzc tjil tdmh",     # Thay bằng mật khẩu ứng dụng chính xác từ Google
        sender_email="baohiem.system@gmail.com",
        use_tls=True
    ),
    app=AppURLSettings(
        api_url="http://localhost:8000",
        frontend_url="http://localhost:5500"   # Adjust based on how you serve your frontend
    ),
    session_timeout_minutes=60,  # Longer sessions in development
    encryption_key="dev_encryption_key_32_chars_needed!"  # 32 bytes for AES-256
)
