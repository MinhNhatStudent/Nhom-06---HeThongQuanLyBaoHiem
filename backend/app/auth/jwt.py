"""
Authentication module for JWT token handling and validation
"""
from datetime import datetime, timedelta
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from ..config.settings import get_settings
from ..models.user import TokenData

# Get application settings
settings = get_settings()

# OAuth2 scheme for token authentication
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

def create_access_token(data: dict) -> str:
    """
    Create JWT access token
    
    Args:
        data: Data to encode into token
        
    Returns:
        JWT token string
    """
    to_encode = data.copy()
    
    # Set expiration time
    expire = datetime.utcnow() + timedelta(minutes=settings.jwt.access_token_expire_minutes)
    to_encode.update({"exp": expire})
    
    # Create JWT token
    encoded_jwt = jwt.encode(
        to_encode, 
        settings.jwt.secret_key, 
        algorithm=settings.jwt.algorithm
    )
    
    return encoded_jwt

async def get_token_data(token: str = Depends(oauth2_scheme)) -> TokenData:
    """
    Validate token and return token data
    
    Args:
        token: JWT token from authorization header
        
    Returns:
        TokenData object with user information
    
    Raises:
        HTTPException: If token is invalid or expired
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # Decode token
        payload = jwt.decode(
            token, 
            settings.jwt.secret_key, 
            algorithms=[settings.jwt.algorithm]
        )
        
        # Extract user information
        email_or_id: str = payload.get("sub")
        role: str = payload.get("vai_tro")
        exp: int = payload.get("exp")
        
        if email_or_id is None or role is None or exp is None:
            raise credentials_exception
            
        # Create token data
        token_data = TokenData(sub=email_or_id, vai_tro=role, exp=exp)
        return token_data
        
    except JWTError:
        raise credentials_exception
