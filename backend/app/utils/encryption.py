"""
Encryption and decryption utilities for sensitive data
Using AES encryption as specified in requirements
"""
import base64
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.backends import default_backend
from ..config.settings import get_settings

settings = get_settings()

def encrypt_data(data: str) -> str:
    """
    Encrypts data using AES encryption
    
    Args:
        data: String data to encrypt
    
    Returns:
        Base64 encoded encrypted string
    """
    if not data:
        return None
        
    # Get encryption key from settings
    key = settings.encryption_key.encode('utf-8')
    
    # Ensure key is 32 bytes (256 bits) for AES-256
    if len(key) != 32:
        raise ValueError("Encryption key must be exactly 32 bytes for AES-256")
    
    # Create an initialization vector
    iv = b'\0' * 16  # In production, use a random IV and store it with the data
    
    # Convert string to bytes
    data_bytes = data.encode('utf-8')
    
    # Pad data
    padder = padding.PKCS7(algorithms.AES.block_size).padder()
    padded_data = padder.update(data_bytes) + padder.finalize()
    
    # Create AES cipher
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    encryptor = cipher.encryptor()
    
    # Encrypt data
    encrypted_data = encryptor.update(padded_data) + encryptor.finalize()
    
    # Base64 encode for storage
    return base64.b64encode(encrypted_data).decode('utf-8')

def decrypt_data(encrypted_data: str) -> str:
    """
    Decrypts AES encrypted data
    
    Args:
        encrypted_data: Base64 encoded encrypted string
    
    Returns:
        Decrypted string
    """
    if not encrypted_data:
        return None
        
    # Get encryption key from settings
    key = settings.encryption_key.encode('utf-8')
    
    # Ensure key is 32 bytes (256 bits) for AES-256
    if len(key) != 32:
        raise ValueError("Encryption key must be exactly 32 bytes for AES-256")
    
    # Create an initialization vector
    iv = b'\0' * 16  # Must match the IV used for encryption
    
    # Base64 decode
    encrypted_bytes = base64.b64decode(encrypted_data)
    
    # Create AES cipher
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    decryptor = cipher.decryptor()
    
    # Decrypt data
    padded_data = decryptor.update(encrypted_bytes) + decryptor.finalize()
    
    # Unpad data
    unpadder = padding.PKCS7(algorithms.AES.block_size).unpadder()
    data_bytes = unpadder.update(padded_data) + unpadder.finalize()
    
    # Convert bytes to string
    return data_bytes.decode('utf-8')
