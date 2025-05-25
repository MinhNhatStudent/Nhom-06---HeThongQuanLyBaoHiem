"""
API Routes and Endpoints
"""
from .auth import router as auth_router

# List of all routers to be included in the app
routers = [
    auth_router,
]
