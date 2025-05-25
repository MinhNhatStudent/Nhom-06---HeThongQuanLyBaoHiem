"""
Debug version of JWT functions - USE ONLY FOR DEBUGGING!
This file contains simplified authentication logic that bypasses database validation
to help identify where authentication issues might be occurring
"""
from datetime import datetime, timedelta
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer as _OAuth2PasswordBearer
from ..config.settings import get_settings
from ..models.user import TokenData

# Get application settings
settings = get_settings()

# OAuth2 scheme for token authentication
oauth2_scheme = _OAuth2PasswordBearer(tokenUrl="auth/login")

def create_debug_token(data: dict) -> str:
    """
    Create JWT access token for debugging with minimal fields
    """
    to_encode = data.copy()
    
    # Set expiration time
    expire = datetime.utcnow() + timedelta(hours=24)  # Long expiry for testing
    to_encode.update({"exp": expire})
    
    # Create JWT token
    encoded_jwt = jwt.encode(
        to_encode, 
        settings.jwt.secret_key, 
        algorithm=settings.jwt.algorithm
    )
    
    return encoded_jwt

async def debug_token_validation(token: str = Depends(oauth2_scheme)) -> TokenData:
    """
    Validate token with minimal checks - FOR DEBUGGING ONLY!
    
    This function skips database session validation to help isolate JWT issues
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials in debug mode",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # Decode token
        payload = jwt.decode(
            token, 
            settings.jwt.secret_key, 
            algorithms=[settings.jwt.algorithm]
        )
        
        # Print the payload for debugging
        print(f"DEBUG - Token payload: {payload}")
        
        # Extract user information
        email_or_id = payload.get("sub", "debug-user")
        role = payload.get("vai_tro", "debug-role")
        exp = payload.get("exp")
        session_id = payload.get("session_id", "debug-session")
        
        # Create token data
        token_data = TokenData(
            sub=email_or_id, 
            vai_tro=role, 
            exp=exp or int((datetime.utcnow() + timedelta(hours=24)).timestamp()),
            session_id=session_id
        )
                
        return token_data
        
    except JWTError as e:
        print(f"DEBUG - JWT Error: {str(e)}")
        raise credentials_exception
