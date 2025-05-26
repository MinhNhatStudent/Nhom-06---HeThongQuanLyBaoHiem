"""
Permission handling for role-based access control
"""
from fastapi import Depends, HTTPException, status, Request
from ..models.user import UserRole, TokenData
from .jwt import get_token_data
from .session import validate_session
from ..utils.database import execute_procedure
from ..utils.logging import log_activity
from typing import List, Union, Optional
from functools import wraps

def check_permission(
    required_roles: Union[UserRole, List[UserRole]], 
    session_data = Depends(validate_session),
    request: Request = None
) -> bool:
    """
    Check if user has any of the required roles
    
    Args:
        required_roles: Role(s) required for access
        session_data: Session data with user role
        request: Request object for logging
        
    Returns:
        True if user has required role
        
    Raises:
        HTTPException: If user doesn't have required role
    """
    # Handle single role or list of roles
    if isinstance(required_roles, UserRole):
        required_roles = [required_roles]
        
    user_role = session_data.get('role')
    user_id = session_data.get('user_id')
    
    # Admin always has access
    if user_role == UserRole.ADMIN:
        return True
        
    # Check if user has any of the required roles
    if user_role not in required_roles:
        # Log failed permission check
        if request and user_id:
            log_activity(
                user_id=user_id,
                activity_type="permission_denied",
                description=f"Access denied to role {user_role}, required: {', '.join(required_roles)}",
                ip_address=request.client.host if request.client else None
            )
            
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
        
    # Call database to check specific permissions if needed
    try:
        result = execute_procedure("fastapi_check_permission", [user_id, ','.join(required_roles)])
        
        if not result or len(result) == 0 or not result[0].get('has_permission', True):
            # Log failed permission check
            if request and user_id:
                log_activity(
                    user_id=user_id,
                    activity_type="permission_denied",
                    description=f"Database permission check failed for role {user_role}",
                    ip_address=request.client.host if request.client else None
                )
                
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Permission denied by policy"
            )
    except Exception as e:
        # If procedure doesn't exist or fails, fall back to role-based check
        pass
        
    return True

def get_current_user(session_data = Depends(validate_session)):
    """
    Get current user from database based on session
    
    Args:
        session_data: Session data from validate_session
        
    Returns:
        User information from database
        
    Raises:
        HTTPException: If user not found
    """
    try:
        user_id = session_data.get('user_id')
        
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
            
        # Call stored procedure to get user details
        user_data = execute_procedure("get_user_details", [user_id])
        
        if not user_data or len(user_data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )
            
        return user_data[0]
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error retrieving user: {str(e)}"
        )

# Permission check dependency functions for different roles
def admin_only(session_data = Depends(validate_session), request: Request = None):
    """Admin only access"""
    return check_permission(UserRole.ADMIN, session_data, request)

def contract_creator_only(session_data = Depends(validate_session), request: Request = None):
    """Contract creator only access"""
    return check_permission(UserRole.CONTRACT_CREATOR, session_data, request)

def accounting_only(session_data = Depends(validate_session), request: Request = None):
    """Accounting only access"""
    return check_permission(UserRole.ACCOUNTING, session_data, request)

def supervisor_only(session_data = Depends(validate_session), request: Request = None):
    """Supervisor only access"""
    return check_permission(UserRole.SUPERVISOR, session_data, request)

def insured_only(session_data = Depends(validate_session), request: Request = None):
    """Insured person only access"""
    return check_permission(UserRole.INSURED, session_data, request)

# Permission decorator for functions
def requires_role(required_roles: Union[UserRole, List[UserRole]]):
    """
    Decorator for requiring specific role(s) for a function
    
    Args:
        required_roles: Role or list of roles required for access
        
    Returns:
        Decorator function
        
    Example:
        @requires_role([UserRole.ADMIN, UserRole.SUPERVISOR])
        def admin_or_supervisor_function():
            # Only admins or supervisors can run this
            pass
    """
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Get session_data and request if provided in kwargs
            session_data = kwargs.get('session_data')
            request = kwargs.get('request')
            
            # Check permission
            check_permission(required_roles, session_data, request)
            
            # Call original function
            return await func(*args, **kwargs)
        
        return wrapper
    
    return decorator

def require_authenticated(token_data: TokenData = Depends(get_token_data)) -> TokenData:
    """
    Dependency to ensure user is authenticated
    
    Args:
        token_data: Token data from JWT
        
    Returns:
        Token data if authenticated
        
    Raises:
        HTTPException: If user is not authenticated
    """
    if not token_data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated"
        )
    return token_data
