"""
Logging and audit trail utilities
"""
import logging
import json
from datetime import datetime
from fastapi import Request
from .database import execute_procedure

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("app.log"),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger("insurance-app")

def log_activity(user_id: int, activity_type: str, description: str, ip_address: str = None, details: dict = None):
    """
    Log user activity to database and application log
    
    Args:
        user_id: ID of the user performing the action
        activity_type: Type of activity (e.g., 'login', 'view', 'edit')
        description: Brief description of the activity
        ip_address: IP address of the user
        details: Additional details about the activity (will be stored as JSON)
    """
    # Log to application log
    log_message = f"User {user_id}: {activity_type} - {description}"
    if details:
        log_message += f" - Details: {json.dumps(details)}"
    
    logger.info(log_message)
    
    # Log to database
    try:
        details_json = json.dumps(details) if details else None
        execute_procedure(
            "log_user_activity",
            [user_id, activity_type, description, ip_address, details_json]
        )
    except Exception as e:
        logger.error(f"Failed to log activity to database: {str(e)}")

class AuditMiddleware:
    """
    Middleware to audit API requests
    """
    async def __call__(self, request: Request, call_next):
        # Get start time
        start_time = datetime.now()
        
        # Get client IP
        client_ip = request.client.host if request.client else None
        
        # Track request path and method
        path = request.url.path
        method = request.method
        
        # Process the request
        response = await call_next(request)
        
        # Calculate request duration
        duration = (datetime.now() - start_time).total_seconds()
        
        # Log request details (skip health checks and other routine paths)
        if not path.startswith(("/docs", "/redoc", "/openapi.json", "/favicon.ico")):
            # Get user ID from request state if authenticated
            user_id = getattr(request.state, "user_id", None)
            
            if user_id:
                log_activity(
                    user_id=user_id,
                    activity_type="api_request",
                    description=f"{method} {path}",
                    ip_address=client_ip,
                    details={
                        "status_code": response.status_code,
                        "duration_seconds": duration
                    }
                )
            else:
                # Anonymous request
                logger.info(f"Anonymous: {method} {path} - Status: {response.status_code} - Duration: {duration:.3f}s")
        
        return response
