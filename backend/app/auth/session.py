"""
Session management module for tracking user sessions
"""
from fastapi import Depends, HTTPException, status, Request
from ..models.user import TokenData
from .jwt import get_token_data
from ..utils.database import execute_procedure
from uuid import uuid4
from datetime import datetime

class SessionManager:
    """
    Session management for user sessions
    """
    @staticmethod
    async def validate_session(token_data: TokenData = Depends(get_token_data), request: Request = None):
        """
        Validate user session and update last activity
        
        Args:
            token_data: Token data from JWT
            request: Request object for client IP
            
        Returns:
            Session information
            
        Raises:
            HTTPException: If session is invalid
        """
        if not token_data or not token_data.session_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid session",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        # Get client IP
        client_ip = request.client.host if request and request.client else None
        
        try:
            # Call session validation procedure
            result = execute_procedure("fastapi_validate_session", [token_data.session_id])
            
            if not result or len(result) == 0:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Session validation failed",
                )
              # Parse result - the stored procedure returns JSON as a string
            session_result_json = result[0].get('result', '{}')
            if isinstance(session_result_json, str):
                import json
                session_result = json.loads(session_result_json)
            else:
                session_result = session_result_json
            
            if not session_result.get('valid', False):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Session expired or invalid",
                    headers={"WWW-Authenticate": "Bearer"},
                )
                
            # Add user information to request state for logging
            if request:
                request.state.user_id = session_result.get('user_id')
                request.state.user_role = session_result.get('role')
            
            return {
                "user_id": session_result.get('user_id'),
                "role": session_result.get('role'),
                "insurance_type": session_result.get('insurance_type'),
                "session_id": token_data.session_id
            }
            
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Session validation error: {str(e)}",
            )
    
    @staticmethod
    def generate_session_id():
        """Generate unique session ID"""
        return str(uuid4())

# Create session manager instance
session_manager = SessionManager()

# Dependency for session validation
async def validate_session(token_data: TokenData = Depends(get_token_data), request: Request = None):
    """
    Dependency for validating user session
    
    Args:
        token_data: Token data from JWT
        request: Request object for client IP
        
    Returns:
        Session information
    """
    return await session_manager.validate_session(token_data, request)
