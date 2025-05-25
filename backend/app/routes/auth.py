"""
Authentication routes for user login and logout
"""
from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordRequestForm
from ..models.user import UserLogin, Token
from ..auth.jwt import create_access_token, get_token_data
from ..utils.database import execute_procedure
from ..utils.logging import log_activity
from ..config.settings import get_settings

# Get application settings
settings = get_settings()
import uuid
import time
import json
from datetime import datetime

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
    responses={401: {"description": "Unauthorized"}},
)

@router.post("/login", response_model=Token)
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    request: Request = None
):
    """
    Log in and get JWT access token
    """
    # Generate session ID
    session_id = str(uuid.uuid4())
    
    # Get client IP
    client_ip = request.client.host if request and request.client else None
      # Call login procedure
    try:
        result = execute_procedure(
            "fastapi_login",
            [form_data.username, form_data.password, session_id, client_ip]
        )
        
        if not result or len(result) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Login procedure failed",
            )
        
        # Parse JSON result - the stored procedure returns a JSON string
        login_result_json = result[0].get('result', '{}')
        login_result = json.loads(login_result_json) if isinstance(login_result_json, str) else login_result_json
        
        if not login_result.get('success', False):
            # Log failed login attempt
            log_activity(
                user_id=0,  # 0 for anonymous
                activity_type="failed_login",
                description=f"Failed login attempt for user: {form_data.username}",
                ip_address=client_ip
            )
            
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        # Create token data
        token_data = {
            "sub": str(login_result.get('user_id')),
            "vai_tro": login_result.get('role'),
            "session_id": session_id
        }
        
        # Create access token
        access_token = create_access_token(token_data)
        
        # Calculate expiration timestamp
        expires_at = int(time.time() + 30 * 60)  # 30 minutes from now
        
        # Log successful login
        log_activity(
            user_id=login_result.get('user_id'),
            activity_type="login",
            description=f"User logged in successfully",
            ip_address=client_ip
        )
        
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_at": expires_at
        }
    except Exception as e:
        # Log error
        log_activity(
            user_id=0,
            activity_type="error",
            description=f"Login error: {str(e)}",
            ip_address=client_ip
        )
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Login failed: {str(e)}",
        )

@router.post("/logout")
async def logout(
    token_data = Depends(get_token_data),
    request: Request = None
):
    """
    Log out and end user session
    """
    # Get session ID from token
    session_id = getattr(token_data, 'session_id', None)
    user_id = token_data.sub if hasattr(token_data, 'sub') else "0"
    
    # Enhanced: For Swagger UI testing or when session ID is missing, be more lenient
    if not session_id:
        # When testing in Swagger UI without a proper token
        if settings.debug:
            # In debug mode, generate a temporary session ID
            import uuid
            session_id = f"auto-generated-{str(uuid.uuid4())}"
            print(f"[AUTH] Generated temporary session ID for logout: {session_id}")
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No session ID in token",
            )
    
    # Get client IP
    client_ip = request.client.host if request and request.client else None
    
    # Enhanced: First check if the session exists before trying to log out
    try:
        # Connect directly to DB for session check
        from ..utils.database import get_connection
        conn = get_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Check if session exists
        cursor.execute("SELECT * FROM phienlamviec WHERE session_id = %s", (session_id,))
        session = cursor.fetchone()
        
        if not session and settings.debug:
            # In debug mode, if session doesn't exist, create a temporary one
            print(f"[AUTH] Session {session_id} not found, creating temporary one for logout")
            cursor.execute(
                "INSERT INTO phienlamviec (session_id, user_id, ip_address, is_active) VALUES (%s, %s, %s, TRUE)",
                (session_id, user_id, client_ip or "127.0.0.1")
            )
            conn.commit()
            
        cursor.close()
        conn.close()
        
        # Call logout procedure 
        result = execute_procedure("fastapi_logout", [session_id])
        
        if not result or len(result) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Logout procedure failed",
            )
          # Parse JSON result - the stored procedure returns a JSON string
        logout_result_json = result[0].get('result', '{}')
        logout_result = json.loads(logout_result_json) if isinstance(logout_result_json, str) else logout_result_json
        
        # Log logout activity
        log_activity(
            user_id=int(token_data.sub) if token_data.sub.isdigit() else 0,
            activity_type="logout",
            description=f"User logged out",
            ip_address=client_ip
        )
        
        return {"success": logout_result.get('success', False)}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Logout failed: {str(e)}",
        )

@router.get("/validate")
async def validate_token(token_data = Depends(get_token_data), request: Request = None):
    """
    Validate JWT token and return user information
    """
    # If we get here, token is valid
    # Get client IP for logging
    client_ip = request.client.host if request and request.client else None
    
    # Extract session ID for debugging
    session_id = token_data.session_id if hasattr(token_data, "session_id") else None
    
    # Enhanced: For debugging, check session status in database
    if session_id and settings.debug:
        try:
            from ..utils.database import get_connection
            conn = get_connection()
            cursor = conn.cursor(dictionary=True)
            
            # Check session status for debugging
            cursor.execute("SELECT * FROM phienlamviec WHERE session_id = %s", (session_id,))
            session = cursor.fetchone()
            
            # If got here but session isn't in database, something is wrong with our validation
            if not session:
                print(f"[AUTH] Warning: Token validated but session {session_id} not found in database")
            elif not session.get('is_active'):
                print(f"[AUTH] Warning: Token validated but session {session_id} is marked inactive")
                
                # In debug mode, reactivate the session
                cursor.execute(
                    "UPDATE phienlamviec SET is_active = TRUE, last_activity = CURRENT_TIMESTAMP WHERE session_id = %s", 
                    (session_id,)
                )
                conn.commit()
                print(f"[AUTH] Reactivated session {session_id} in debug mode")
                
            cursor.close()
            conn.close()
            
        except Exception as e:
            print(f"[AUTH] Debug validation check error: {str(e)}")
    
    # Add detailed information to the response
    return {
        "valid": True,
        "user_id": token_data.sub,
        "role": token_data.vai_tro,
        "expires_at": token_data.exp,
        "session_id": session_id,
        "debug_mode": settings.debug
    }

# Non-secured endpoint for testing
@router.get("/test")
async def test_auth():
    """
    Test endpoint that doesn't require authentication
    """
    return {
        "message": "Authentication system is working",
        "timestamp": time.time()
    }

# Development-only non-secured endpoints for testing
@router.post("/test/logout")
async def test_logout(request: Request = None):
    """
    Test endpoint for logout that doesn't require authentication (for development only)
    """
    # Use a test session ID
    session_id = "test-session-" + str(uuid.uuid4())
    
    # Get client IP
    client_ip = request.client.host if request and request.client else None
    
    # Call logout procedure
    try:
        result = execute_procedure("fastapi_logout", [session_id])
        
        if not result or len(result) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Logout procedure failed",
            )
        
        logout_result_json = result[0].get('result', '{}')
        logout_result = json.loads(logout_result_json) if isinstance(logout_result_json, str) else logout_result_json
        
        return {
            "success": True,
            "message": "This is a test logout endpoint that doesn't require authentication",
            "timestamp": time.time()
        }
    except Exception as e:
        return {
            "success": False,
            "message": f"Test logout failed: {str(e)}",
            "timestamp": time.time()
        }

@router.get("/test/validate")
async def test_validate():
    """
    Test endpoint for token validation that doesn't require authentication (for development only)
    """
    return {
        "valid": True,
        "user_id": "test-user-id",
        "role": "test-role",
        "expires_at": int(time.time() + 30 * 60),
        "message": "This is a test validate endpoint that doesn't require authentication"
    }
