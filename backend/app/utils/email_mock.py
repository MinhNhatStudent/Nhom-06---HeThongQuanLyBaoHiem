"""
Email mock utilities cho môi trường phát triển
"""
import logging

logger = logging.getLogger("insurance-app")

def mock_send_email(to_email, subject, html_content, text_content=None):
    """
    Giả lập gửi email cho môi trường phát triển
    
    Args:
        to_email (str): Địa chỉ người nhận
        subject (str): Tiêu đề email
        html_content (str): Nội dung HTML của email
        text_content (str): Nội dung text của email (optional)
    
    Returns:
        bool: Luôn trả về True (giả lập thành công)
    """
    logger.info("=== MOCK EMAIL ===")
    logger.info(f"To: {to_email}")
    logger.info(f"Subject: {subject}")
    logger.info("Content preview: " + html_content[:100] + "...")
    logger.info("=== END MOCK EMAIL ===")
    
    return True

def mock_send_activation_email(to_email, activation_token, username):
    """
    Giả lập gửi email kích hoạt tài khoản
    
    Args:
        to_email (str): Địa chỉ email người nhận
        activation_token (str): Token kích hoạt tài khoản
        username (str): Tên người dùng
    
    Returns:
        bool: Luôn trả về True (giả lập thành công)
    """
    logger.info("=== MOCK ACTIVATION EMAIL ===")
    logger.info(f"To: {to_email}")
    logger.info(f"Username: {username}")
    logger.info(f"Activation Token: {activation_token}")
    logger.info(f"Activation URL: http://localhost:5500/kichhoattaikhoan.html?token={activation_token}")
    logger.info("=== END MOCK ACTIVATION EMAIL ===")
    
    return True

def mock_send_password_reset_email(to_email, reset_token, username):
    """
    Giả lập gửi email đặt lại mật khẩu
    
    Args:
        to_email (str): Địa chỉ email người nhận
        reset_token (str): Token đặt lại mật khẩu
        username (str): Tên người dùng
    
    Returns:
        bool: Luôn trả về True (giả lập thành công)
    """
    logger.info("=== MOCK PASSWORD RESET EMAIL ===") 
    logger.info(f"To: {to_email}")
    logger.info(f"Username: {username}")
    logger.info(f"Reset Token: {reset_token}")
    logger.info(f"Reset URL: http://localhost:5500/quenmatkhau.html?token={reset_token}")
    logger.info("=== END MOCK PASSWORD RESET EMAIL ===")
    
    return True
