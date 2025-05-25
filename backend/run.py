"""
Main entry point to run the FastAPI application
"""
import os
import uvicorn
from app.config.settings import get_settings

if __name__ == "__main__":
    # Get settings based on environment
    settings = get_settings()
    
    # Set environment variables for development if needed
    if settings.debug:
        os.environ["APP_ENV"] = "development"
    
    # Start the application with uvicorn
    uvicorn.run(
        "app.main:app", 
        host="0.0.0.0", 
        port=8000, 
        reload=settings.debug,
        log_level="debug" if settings.debug else "info"
    )
