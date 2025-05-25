"""
Authentication and Authorization modules
"""
from .jwt import create_access_token, get_token_data
from .session import validate_session, SessionManager
from .permissions import (
    check_permission, get_current_user, 
    admin_only, contract_creator_only, accounting_only,
    supervisor_only, insured_only, requires_role
)
