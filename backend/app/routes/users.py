"""
User management API endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status, Request, Query
from fastapi.security import OAuth2PasswordBearer
from typing import Optional, List
import json
import uuid

from ..models.user import (
    UserCreate, UserActivate, UserPasswordReset, UserPasswordResetConfirm,
    UserResponse, UserUpdate, UserPasswordChange, ActivationResponse,
    ResetRequestResponse, ResetConfirmResponse, ChangePasswordResponse
)
from ..auth.jwt import get_token_data
from ..utils.database import execute_procedure
from ..utils.email import send_activation_email, send_password_reset_email
from ..utils.logging import log_activity
from ..config.settings import get_settings

# Get application settings
settings = get_settings()

router = APIRouter(
    prefix="/users",
    tags=["User Management"],
    responses={401: {"description": "Unauthorized"}},
)

# OAuth2 scheme for protected endpoints
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

# Helper function to check if user has admin role
def check_admin_permissions(token_data):
    if not token_data or token_data.vai_tro != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to perform this action"
        )

@router.post("/register", response_model=dict)
async def register_user(
    user: UserCreate,
    request: Request = None,
    token_data = Depends(get_token_data)
):
    """
    Register a new user (admin only)
    """
    # Check admin permissions
    check_admin_permissions(token_data)
    
    try:
        # Call registration procedure
        result = execute_procedure(
            "fastapi_register_user",
            [user.username, user.email, user.vai_tro, user.insurance_type_id]
        )
        
        if not result or len(result) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Registration procedure failed",
            )
        
        # Parse JSON result
        register_result_json = result[0].get('result', '{}')
        register_result = json.loads(register_result_json) if isinstance(register_result_json, str) else register_result_json
        
        if not register_result.get('success', False):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=register_result.get('message', 'Registration failed'),
            )
        
        # Send activation email
        activation_token = register_result.get('activation_token')
        if activation_token:
            # Log activity
            log_activity(
                user_id=int(token_data.sub) if token_data.sub.isdigit() else 0,
                activity_type="user_registration",
                description=f"Registered new user: {user.username} ({user.email})",
                ip_address=request.client.host if request and request.client else None
            )
            
            # Send activation email
            email_sent = send_activation_email(
                to_email=user.email,
                activation_token=activation_token,
                username=user.username
            )
            
            return {
                "success": True,
                "user_id": register_result.get('user_id'),
                "activation_email_sent": email_sent
            }
        else:
            return {
                "success": True,
                "user_id": register_result.get('user_id'),
                "activation_email_sent": False,
                "message": "Activation token could not be generated"
            }
            
    except Exception as e:
        # Log error
        log_activity(
            user_id=int(token_data.sub) if token_data.sub.isdigit() else 0,
            activity_type="error",
            description=f"Registration error: {str(e)}",
            ip_address=request.client.host if request and request.client else None
        )
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration failed: {str(e)}",
        )

@router.post("/activate", response_model=ActivationResponse)
async def activate_account(
    activation_data: UserActivate,
    request: Request = None,
):
    """
    Activate a user account using activation token and set password
    """
    try:
        # Call activation procedure
        result = execute_procedure(
            "fastapi_activate_account",
            [activation_data.token, activation_data.password]
        )
        
        if not result or len(result) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Activation procedure failed",
            )
        
        # Parse JSON result
        activation_result_json = result[0].get('result', '{}')
        activation_result = json.loads(activation_result_json) if isinstance(activation_result_json, str) else activation_result_json
        
        if not activation_result.get('success', False):
            return ActivationResponse(
                success=False,
                message=activation_result.get('message', 'Activation failed')
            )
        
        # Log activity
        log_activity(
            user_id=activation_result.get('user_id', 0),
            activity_type="account_activation",
            description=f"Account activated for user: {activation_result.get('username', 'unknown')}",
            ip_address=request.client.host if request and request.client else None
        )
        
        return ActivationResponse(
            success=True,
            message="Account activated successfully",
            user_id=activation_result.get('user_id'),
            username=activation_result.get('username')
        )
            
    except Exception as e:
        # Log error
        log_activity(
            user_id=0,  # Unknown user ID at this point
            activity_type="error",
            description=f"Activation error: {str(e)}",
            ip_address=request.client.host if request and request.client else None
        )
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Activation failed: {str(e)}",
        )

@router.post("/password-reset/request", response_model=ResetRequestResponse)
async def request_password_reset(
    reset_request: UserPasswordReset,
    request: Request = None,
):
    """
    Request a password reset
    """
    try:
        # Call password reset request procedure
        result = execute_procedure(
            "fastapi_request_password_reset",
            [reset_request.email]
        )
        
        if not result or len(result) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Password reset request procedure failed",
            )
        
        # Parse JSON result
        reset_result_json = result[0].get('result', '{}')
        reset_result = json.loads(reset_result_json) if isinstance(reset_result_json, str) else reset_result_json
        
        # Even if user isn't found, return success for security
        # But only send email if user actually exists
        email_sent = False
        if reset_result.get('success', False):
            reset_token = reset_result.get('reset_token')
            username = reset_result.get('username')
            
            if reset_token and username:
                # Send password reset email
                email_sent = send_password_reset_email(
                    to_email=reset_request.email,
                    reset_token=reset_token,
                    username=username
                )
                
                # Log activity
                log_activity(
                    user_id=reset_result.get('user_id', 0),
                    activity_type="password_reset_request",
                    description=f"Password reset requested for user: {username}",
                    ip_address=request.client.host if request and request.client else None
                )
        
        # Always return success for security (don't reveal if email exists)
        return ResetRequestResponse(
            success=True,
            message="If your email is registered, you will receive password reset instructions."
        )
            
    except Exception as e:
        # Log error but don't expose details
        log_activity(
            user_id=0,
            activity_type="error",
            description=f"Password reset request error: {str(e)}",
            ip_address=request.client.host if request and request.client else None
        )
        
        # For security, don't reveal specific errors
        return ResetRequestResponse(
            success=True,
            message="If your email is registered, you will receive password reset instructions."
        )

@router.post("/password-reset/confirm", response_model=ResetConfirmResponse)
async def confirm_password_reset(
    reset_confirm: UserPasswordResetConfirm,
    request: Request = None,
):
    """
    Confirm a password reset using token and new password
    """
    try:
        # Call password reset confirmation procedure
        result = execute_procedure(
            "fastapi_reset_password",
            [reset_confirm.token, reset_confirm.password]
        )
        
        if not result or len(result) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Password reset confirmation procedure failed",
            )
        
        # Parse JSON result
        reset_result_json = result[0].get('result', '{}')
        reset_result = json.loads(reset_result_json) if isinstance(reset_result_json, str) else reset_result_json
        
        if not reset_result.get('success', False):
            return ResetConfirmResponse(
                success=False,
                message=reset_result.get('message', 'Password reset failed')
            )
        
        # Log activity
        log_activity(
            user_id=reset_result.get('user_id', 0),
            activity_type="password_reset_complete",
            description=f"Password reset completed for user: {reset_result.get('username', 'unknown')}",
            ip_address=request.client.host if request and request.client else None
        )
        
        return ResetConfirmResponse(
            success=True,
            message="Password has been reset successfully"
        )
            
    except Exception as e:
        # Log error
        log_activity(
            user_id=0,
            activity_type="error",
            description=f"Password reset confirmation error: {str(e)}",
            ip_address=request.client.host if request and request.client else None
        )
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Password reset failed: {str(e)}",
        )

@router.get("/me", response_model=UserResponse)
async def get_current_user(
    token_data = Depends(get_token_data),
    request: Request = None
):
    """
    Get information about the current user
    """
    try:
        user_id = int(token_data.sub) if token_data.sub.isdigit() else None
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
            )
            
        # Call get user info procedure
        result = execute_procedure(
            "fastapi_get_user_info",
            [user_id]
        )
        
        if not result or len(result) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Get user info procedure failed",
            )
        
        # Parse JSON result
        user_info_json = result[0].get('result', '{}')
        user_info = json.loads(user_info_json) if isinstance(user_info_json, str) else user_info_json
        
        return user_info
            
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get user info: {str(e)}",
        )

@router.put("/me/password", response_model=ChangePasswordResponse)
async def change_password(
    password_data: UserPasswordChange,
    token_data = Depends(get_token_data),
    request: Request = None
):
    """
    Change the current user's password
    """
    try:
        user_id = int(token_data.sub) if token_data.sub.isdigit() else None
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
            )
            
        # Call change password procedure
        result = execute_procedure(
            "fastapi_change_password",
            [user_id, password_data.current_password, password_data.new_password]
        )
        
        if not result or len(result) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Change password procedure failed",
            )
        
        # Parse JSON result
        change_result_json = result[0].get('result', '{}')
        change_result = json.loads(change_result_json) if isinstance(change_result_json, str) else change_result_json
        
        if not change_result.get('success', False):
            return ChangePasswordResponse(
                success=False,
                message=change_result.get('message', 'Password change failed')
            )
        
        # Log activity
        log_activity(
            user_id=user_id,
            activity_type="password_change",
            description=f"User changed their password",
            ip_address=request.client.host if request and request.client else None
        )
        
        return ChangePasswordResponse(
            success=True,
            message="Password changed successfully"
        )
            
    except Exception as e:
        # Log error
        log_activity(
            user_id=user_id if user_id else 0,
            activity_type="error",
            description=f"Password change error: {str(e)}",
            ip_address=request.client.host if request and request.client else None
        )
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to change password: {str(e)}",
        )

@router.put("/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: int,
    user_data: UserUpdate,
    token_data = Depends(get_token_data),
    request: Request = None
):
    """
    Update user information (admin only)
    """
    # Check admin permissions
    check_admin_permissions(token_data)
    
    try:
        # Call update user procedure
        result = execute_procedure(
            "fastapi_update_user_info",
            [
                user_id, 
                user_data.email,
                user_data.vai_tro.value if user_data.vai_tro else None,
                user_data.trang_thai.value if user_data.trang_thai else None,
                user_data.insurance_type_id,
                int(token_data.sub) if token_data.sub.isdigit() else 0  # Current user ID
            ]
        )
        
        if not result or len(result) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Update user procedure failed",
            )
        
        # Parse JSON result
        update_result_json = result[0].get('result', '{}')
        update_result = json.loads(update_result_json) if isinstance(update_result_json, str) else update_result_json
        
        if not update_result.get('success', False):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=update_result.get('message', 'User update failed'),
            )
        
        # Log activity
        log_activity(
            user_id=int(token_data.sub) if token_data.sub.isdigit() else 0,
            activity_type="user_update",
            description=f"Updated user information for user ID: {user_id}",
            ip_address=request.client.host if request and request.client else None
        )
        
        # Get updated user info
        updated_user = execute_procedure(
            "fastapi_get_user_info",
            [user_id]
        )
        
        if updated_user and len(updated_user) > 0:
            user_info_json = updated_user[0].get('result', '{}')
            user_info = json.loads(user_info_json) if isinstance(user_info_json, str) else user_info_json
            return user_info
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found after update",
            )
            
    except HTTPException:
        raise
        
    except Exception as e:
        # Log error
        log_activity(
            user_id=int(token_data.sub) if token_data.sub.isdigit() else 0,
            activity_type="error",
            description=f"User update error: {str(e)}",
            ip_address=request.client.host if request and request.client else None
        )
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update user: {str(e)}",
        )

@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: int,
    token_data = Depends(get_token_data)
):
    """
    Get a specific user by ID (admin only)
    """
    # Check admin permissions
    check_admin_permissions(token_data)
    
    try:
        # Call get user info procedure
        result = execute_procedure(
            "fastapi_get_user_info",
            [user_id]
        )
        
        if not result or len(result) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )
        
        # Parse JSON result
        user_info_json = result[0].get('result', '{}')
        user_info = json.loads(user_info_json) if isinstance(user_info_json, str) else user_info_json
        
        if not user_info:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )
        
        return user_info
            
    except HTTPException:
        raise
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get user info: {str(e)}",
        )
