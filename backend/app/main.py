from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from .config.settings import get_settings
from .utils.logging import AuditMiddleware
import time

# Get application settings
settings = get_settings()

# Initialize FastAPI application
app = FastAPI(
    title="Hệ thống Quản lý Bảo hiểm API",
    description="API cho Hệ thống Quản lý Bảo hiểm với tính năng bảo mật cao, mã hóa dữ liệu nhạy cảm và phân quyền nghiêm ngặt",
    version="1.0.0",
    debug=settings.debug
)

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

# Health check endpoint for monitoring
@app.get("/health")
async def health_check():
    """
    Health check endpoint for monitoring
    """
    return {"status": "healthy", "timestamp": time.time()}

# Import and include routers
# These will be implemented in the next tasks
# Example: app.include_router(user_router, prefix="/users", tags=["users"])
