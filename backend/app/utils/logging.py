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
    Middleware to audit API requests using ASGI interface
    """
    def __init__(self, app):
        # Store the ASGI app instance
        self.app = app
        
    async def __call__(self, scope, receive, send):
        # Check if this is an HTTP request (ignore WebSocket and lifespan)
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
            
        # Get start time
        start_time = datetime.now()
        
        # Extract request info from scope
        method = scope.get("method", "UNKNOWN")
        path = scope.get("path", "UNKNOWN")
        client_ip = None
        if "client" in scope and scope["client"]:
            client_ip = scope["client"][0]  # Get client IP
            
        # Create a send wrapper to capture response status
        status_code = [200]  # Default to 200 OK
        
        async def send_wrapper(message):
            if message["type"] == "http.response.start":
                # Capture the status code
                status_code[0] = message["status"]
            await send(message)
            
        # Process the request
        try:
            await self.app(scope, receive, send_wrapper)
            
            # Calculate request duration
            duration = (datetime.now() - start_time).total_seconds()
            
            # Log request details (skip health checks and other routine paths)
            if not path.startswith(("/docs", "/redoc", "/openapi.json", "/favicon.ico")):
                # Try to get user_id from state (if available)
                user_id = None
                if "state" in scope and hasattr(scope["state"], "user_id"):
                    user_id = scope["state"].user_id
                
                if user_id:
                    log_activity(
                        user_id=user_id,
                        activity_type="api_request",
                        description=f"{method} {path}",
                        ip_address=client_ip,
                        details={
                            "status_code": status_code[0],
                            "duration_seconds": duration
                        }
                    )
                else:
                    # Anonymous request
                    logger.info(f"Anonymous: {method} {path} - Status: {status_code[0]} - Duration: {duration:.3f}s")
        except Exception as e:
            logger.error(f"Error in audit middleware: {str(e)}")
            raise  # Re-raise the exception
