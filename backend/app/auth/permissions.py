"""
Permission handling for role-based access control
"""
from fastapi import Depends, HTTPException, status
from ..models.user import UserRole, TokenData
from .jwt import get_token_data
from ..utils.database import execute_procedure

def check_permission(required_role: UserRole, token_data: TokenData = Depends(get_token_data)) -> bool:
    """
    Check if user has required role
    
    Args:
        required_role: Role required for access
        token_data: User token data
        
    Returns:
        True if user has required role
        
    Raises:
        HTTPException: If user doesn't have required role
    """
    if token_data.vai_tro != required_role and token_data.vai_tro != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    return True

def get_current_user(token_data: TokenData = Depends(get_token_data)):
    """
    Get current user from database based on token
    
    Args:
        token_data: User token data
        
    Returns:
        User information from database
        
    Raises:
        HTTPException: If user not found or session invalid
    """
    try:
        # Call stored procedure to validate session and get user info
        user_data = execute_procedure("fastapi_validate_session", [token_data.sub])
        
        if not user_data or len(user_data) == 0:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
            
        return user_data[0]
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error validating session: {str(e)}"
        )

# Permission check dependency functions for different roles
def admin_only(token_data: TokenData = Depends(get_token_data)):
    """Admin only access"""
    return check_permission(UserRole.ADMIN, token_data)

def contract_creator_only(token_data: TokenData = Depends(get_token_data)):
    """Contract creator only access"""
    return check_permission(UserRole.CONTRACT_CREATOR, token_data)

def accounting_only(token_data: TokenData = Depends(get_token_data)):
    """Accounting only access"""
    return check_permission(UserRole.ACCOUNTING, token_data)

def supervisor_only(token_data: TokenData = Depends(get_token_data)):
    """Supervisor only access"""
    return check_permission(UserRole.SUPERVISOR, token_data)

def insured_only(token_data: TokenData = Depends(get_token_data)):
    """Insured person only access"""
    return check_permission(UserRole.INSURED, token_data)
