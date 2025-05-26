from fastapi import FastAPI, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from .config.settings import get_settings
from .utils.logging import AuditMiddleware
import time

# Get application settings
settings = get_settings()

# Initialize FastAPI application with proper OpenAPI security settings
app = FastAPI(
    title="Hệ thống Quản lý Bảo hiểm API",
    description="API cho Hệ thống Quản lý Bảo hiểm với tính năng bảo mật cao, mã hóa dữ liệu nhạy cảm và phân quyền nghiêm ngặt",
    version="1.0.0",
    debug=settings.debug
)

# Configure OAuth2 with correct token URL for Swagger UI
app.swagger_ui_init_oauth = {
    "usePkceWithAuthorizationCodeGrant": True,
    "useBasicAuthenticationWithAccessCodeGrant": True,
}

# Add OAuth2 security scheme with the correct tokenUrl
app.openapi_components = {
    "securitySchemes": {
        "OAuth2PasswordBearer": {
            "type": "oauth2",
            "flows": {
                "password": {
                    "tokenUrl": "/auth/login",
                    "scopes": {}
                }
            }
        }
    }
}

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.debug else ["https://yourproductionsite.com"],  # Restrict in production
    allow_credentials=True,
    allow_methods=["*"] if settings.debug else ["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"] if settings.debug else ["Content-Type", "Authorization"],
)

# Add audit logging middleware
app.add_middleware(AuditMiddleware)

# Root API endpoint
@app.get("/")
async def root():
    """
    Root endpoint for API health check
    """
    return {
        "message": "Hệ thống Quản lý Bảo hiểm API",
        "version": "1.0.0",
        "status": "running",
        "timestamp": time.time()
    }

# Redirect route for Swagger Auth
@app.post("/login")
async def login_redirect(request: Request):
    """
    Redirect /login to /auth/login for Swagger UI compatibility
    """
    from fastapi.responses import RedirectResponse
    return RedirectResponse(url="/auth/login", status_code=307)

# Health check endpoint for monitoring
@app.get("/health")
async def health_check():
    """
    Health check endpoint for monitoring
    """
    return {"status": "healthy", "timestamp": time.time()}

@app.post("/login")
async def login_redirect(request: Request):
    """
    Redirect /login to /auth/login for Swagger UI compatibility
    """
    return RedirectResponse(url="/auth/login", status_code=307)

# Test endpoint for logout that doesn't require authentication
@app.post("/test/auth/logout")
async def test_logout():
    """
    Test endpoint for logout (for testing in Swagger UI)
    """
    return {"message": "This is a test endpoint for logout. In a real application, you would use /auth/logout with proper JWT authentication"}

# Import and include routers
from .routes.auth import router as auth_router
from .routes.users import router as users_router
from .routes.contracts import router as contracts_router

# Include routers in application
app.include_router(auth_router)
app.include_router(users_router)
app.include_router(contracts_router)

# Initialize scheduled tasks
@app.on_event("startup")
async def startup_event():
    """Run tasks when application starts up"""
    # Initialize database connection
    from .utils.database import get_connection
    try:
        conn = get_connection()
        print("Database connection successful")
        conn.close()
    except Exception as e:
        print(f"Database connection failed: {str(e)}")
        
    # Schedule cleanup of old sessions
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
    from .utils.database import execute_procedure
    
    scheduler = AsyncIOScheduler()
    
    async def cleanup_sessions():
        try:
            execute_procedure("cleanup_old_sessions", [24])  # Clean sessions older than 24 hours
            print("Cleaned up old sessions")
        except Exception as e:
            print(f"Session cleanup failed: {str(e)}")
    
    # Schedule session cleanup to run every hour
    scheduler.add_job(cleanup_sessions, "interval", hours=1)
    scheduler.start()
# These will be implemented in the next tasks
# Example: app.include_router(user_router, prefix="/users", tags=["users"])
