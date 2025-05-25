"""
Email utility functions for sending emails
"""
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from ..config.settings import get_settings
import logging

# Get application settings
settings = get_settings()

# Import mock email functions for development mode
if settings.debug:
    try:
        from .email_mock import mock_send_email, mock_send_activation_email, mock_send_password_reset_email
        print("DEBUG MODE: Using mock email functions")
    except ImportError:
        print("WARNING: Mock email functions not found, will use real email even in debug mode")

def send_email(to_email, subject, html_content, text_content=None):
    """
    Send an email with both HTML and plain text content
    
    Args:
        to_email (str): Recipient email address
        subject (str): Email subject
        html_content (str): HTML content of the email
        text_content (str): Plain text content of the email (optional)
    
    Returns:
        bool: True if email was sent successfully, False otherwise
    """
    # Use mock email in debug mode to avoid SMTP errors
    if settings.debug and 'mock_send_email' in globals():
        return mock_send_email(to_email, subject, html_content, text_content)
        
    try:
        # Create message container
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = settings.email.sender_email
        msg['To'] = to_email
        
        # Add plain text version if provided, otherwise create a simple one
        if text_content is None:
            # Create a simple text version from HTML (very basic)
            text_content = html_content.replace('<br>', '\n').replace('</p>', '\n').replace('<p>', '')
            
            # Remove any remaining HTML tags (very basic)
            import re
            text_content = re.sub('<[^<]+?>', '', text_content)
        
        # Record the MIME types of both parts
        part1 = MIMEText(text_content, 'plain')
        part2 = MIMEText(html_content, 'html')

        # Attach parts into message container
        msg.attach(part1)
        msg.attach(part2)

        # Connect to SMTP server
        server = smtplib.SMTP(settings.email.smtp_server, settings.email.smtp_port)
        server.ehlo()
        
        # Use TLS if configured
        if settings.email.use_tls:
            server.starttls()
            server.ehlo()
            
        # Login if credentials are provided
        if settings.email.smtp_username and settings.email.smtp_password:
            server.login(settings.email.smtp_username, settings.email.smtp_password)
        
        # Send email
        server.sendmail(settings.email.sender_email, to_email, msg.as_string())
        server.quit()
        
        logging.info(f"Email sent successfully to {to_email}")
        return True
    except Exception as e:
        logging.error(f"Failed to send email: {str(e)}")
        return False

def send_activation_email(to_email, activation_token, username):
    """
    Send account activation email
    
    Args:
        to_email (str): Recipient email address
        activation_token (str): Token for account activation
        username (str): Username of the recipient
    
    Returns:
        bool: True if email was sent successfully, False otherwise
    """
    # Use mock email in debug mode to avoid SMTP errors
    if settings.debug and 'mock_send_activation_email' in globals():
        return mock_send_activation_email(to_email, activation_token, username)
        
    activation_url = f"{settings.app.frontend_url}/kichhoattaikhoan.html?token={activation_token}"
    
    subject = "Kích hoạt tài khoản - Hệ thống Quản lý Bảo hiểm"
    
    html_content = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #ddd; border-radius: 5px;">
        <h2 style="color: #333; text-align: center;">Kích hoạt tài khoản</h2>
        <p>Xin chào {username},</p>
        <p>Cảm ơn bạn đã đăng ký tài khoản trên Hệ thống Quản lý Bảo hiểm của chúng tôi.</p>
        <p>Để kích hoạt tài khoản và đặt mật khẩu, vui lòng nhấp vào nút bên dưới:</p>
        <div style="text-align: center; margin: 30px 0;">
            <a href="{activation_url}" style="background-color: #4CAF50; color: white; padding: 12px 20px; text-decoration: none; border-radius: 4px; font-weight: bold;">
                Kích hoạt tài khoản
            </a>
        </div>
        <p>Hoặc sao chép và dán liên kết sau vào trình duyệt của bạn:</p>
        <p style="background-color: #f5f5f5; padding: 10px; word-break: break-all;">{activation_url}</p>
        <p>Liên kết này có hiệu lực trong 24 giờ.</p>
        <p>Nếu bạn không yêu cầu đăng ký tài khoản này, vui lòng bỏ qua email này.</p>
        <p>Trân trọng,<br>Hệ thống Quản lý Bảo hiểm</p>
    </div>
    """
    
    return send_email(to_email, subject, html_content)

def send_password_reset_email(to_email, reset_token, username):
    """
    Send password reset email
    
    Args:
        to_email (str): Recipient email address
        reset_token (str): Token for password reset
        username (str): Username of the recipient
    
    Returns:
        bool: True if email was sent successfully, False otherwise
    """
    reset_url = f"{settings.app.frontend_url}/quenmatkhau.html?token={reset_token}"
    
    subject = "Đặt lại mật khẩu - Hệ thống Quản lý Bảo hiểm"
    
    html_content = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #ddd; border-radius: 5px;">
        <h2 style="color: #333; text-align: center;">Đặt lại mật khẩu</h2>
        <p>Xin chào {username},</p>
        <p>Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho tài khoản của bạn trên Hệ thống Quản lý Bảo hiểm.</p>
        <p>Để đặt lại mật khẩu, vui lòng nhấp vào nút bên dưới:</p>
        <div style="text-align: center; margin: 30px 0;">
            <a href="{reset_url}" style="background-color: #2196F3; color: white; padding: 12px 20px; text-decoration: none; border-radius: 4px; font-weight: bold;">
                Đặt lại mật khẩu
            </a>
        </div>
        <p>Hoặc sao chép và dán liên kết sau vào trình duyệt của bạn:</p>
        <p style="background-color: #f5f5f5; padding: 10px; word-break: break-all;">{reset_url}</p>
        <p>Liên kết này có hiệu lực trong 1 giờ.</p>
        <p>Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này.</p>
        <p>Trân trọng,<br>Hệ thống Quản lý Bảo hiểm</p>
    </div>
    """
    
    return send_email(to_email, subject, html_content)
