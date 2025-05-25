"""
Fix for user activation endpoint
"""
from fastapi import APIRouter, HTTPException, status, Request
from ..models.user import UserActivate, ActivationResponse
from ..utils.database import execute_procedure
from ..utils.logging import log_activity
import json

router = APIRouter()

@router.post("/activate", response_model=ActivationResponse)
async def activate_account(
    activation_data: UserActivate,
    request: Request = None,
):
    """
    Activate a user account using activation token and set password
    """
    try:
        # Set @current_user_id to NULL before executing the procedure to avoid trigger errors
        execute_procedure("SET @current_user_id = NULL", [])
        
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
