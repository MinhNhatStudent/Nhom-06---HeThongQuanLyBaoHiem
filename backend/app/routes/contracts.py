"""
API endpoints for contract management
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Path, status
from typing import Optional, List
import json
from datetime import date

from ..models.contract import (
    ContractCreate, ContractUpdate, ContractResponse, ContractListResponse,
    ContractDetailWithPayments, CreateInsuredUserRequest, CreateInsuredUserResponse,
    GenericResponse, ContractStatus
)
from ..auth.jwt import get_token_data, TokenData
from ..auth.permissions import require_authenticated
from ..utils.database import execute_procedure
from ..utils.email import send_activation_email
from ..utils.logging import log_activity

router = APIRouter(
    prefix="/contracts",
    tags=["Contract Management"],
    responses={401: {"description": "Unauthorized"}}
)

@router.get("/", response_model=ContractListResponse)
async def get_contracts(
    page: int = Query(1, description="Page number", ge=1),
    limit: int = Query(10, description="Items per page", ge=1, le=100),
    status_filter: Optional[ContractStatus] = Query(None, description="Filter by contract status"),
    search: Optional[str] = Query(None, description="Search term"),
    token_data: TokenData = Depends(require_authenticated)
):
    """
    Get list of contracts based on user role and permissions.
    Different user roles see different contracts:
    - contract_creator: only contracts created by them
    - insured_person: only contracts related to them
    - accounting/supervisor: only contracts of insurance types assigned to them
    - admin: all contracts
    """
    try:
        # Call stored procedure to get contracts
        results = execute_procedure(
            "sp_get_contracts_list",
            [
                token_data.sub,      # user_id
                page,                # page
                limit,               # limit
                search,              # search
                status_filter.value if status_filter else None  # status_filter
            ]
        )
        
        # Check for results
        if not results or len(results) < 2 or len(results[0]) == 0:
            return ContractListResponse(items=[], total=0, page=page, limit=limit)
          # Process results - map database field names to model field names
        contracts_data = []
        for contract in results[0]:
            mapped_contract = {
                "id": contract.get("id"),
                "loai_bao_hiem": contract.get("loai_bao_hiem"),
                "ten_nguoi_bh": contract.get("ten_nguoi_bh"),
                "nguoi_lap_hd": contract.get("nguoi_lap_hd"),
                "ngay_ki_hd": contract.get("ngayKiHD"),
                "ngay_cat_hd": contract.get("ngayCatHD"),
                "trang_thai": contract.get("TrangThai"),
                "so_ky_thanh_toan": contract.get("so_ky_thanh_toan")
            }
            contracts_data.append(mapped_contract)
            
        total = results[1][0]["total"] if results[1] else 0
        
        return ContractListResponse(
            items=contracts_data,
            total=total,
            page=page,
            limit=limit
        )
    except Exception as e:
        log_activity(token_data.sub, "error", f"Error getting contracts list: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error getting contracts: {str(e)}"
        )

@router.get("/{contract_id}", response_model=ContractDetailWithPayments)
async def get_contract_details(
    contract_id: int = Path(..., description="The ID of the contract"),
    token_data: TokenData = Depends(require_authenticated)
):
    """
    Get detailed information about a contract, including insured person details
    and payment history. Access is controlled by user permissions.
    """
    try:        # Call stored procedure to get contract details
        results = execute_procedure(
            "sp_get_contract_detail",
            [
                token_data.sub,      # user_id
                contract_id          # contract_id
            ]
        )
        
        # Check for error result
        if results and len(results) >= 1 and results[0] and 'status' in results[0][0] and results[0][0]['status'] == 'error':
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=results[0][0]['message']
            )
        
        # Check if we have all required result sets
        if not results or len(results) < 3 or len(results[0]) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Contract not found"
            )
        
        # Process results
        contract_data = results[0][0]
        details_data = results[1][0] if results[1] else None
        payments_data = results[2] if len(results) > 2 else []
        
        log_activity(token_data.sub, "view", f"Viewed contract details (ID: {contract_id})")
        
        return ContractDetailWithPayments(
            contract=contract_data,
            details=details_data,
            payments=payments_data
        )    
    except HTTPException:
        raise
    except Exception as e:
        log_activity(token_data.sub, "error", f"Error getting contract details: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error getting contract details: {str(e)}"
        )

@router.post("/", response_model=GenericResponse)
async def create_contract(
    contract: ContractCreate,
    token_data: TokenData = Depends(require_authenticated)
):
    """
    Create a new contract with optional contract details.
    Only contract_creator and admin roles can create contracts.
    """
    try:
        # Prepare contract details if provided
        contract_details_json = None
        if contract.contract_detail:
            contract_details_json = json.dumps({
                "ho_ten": contract.contract_detail.ho_ten,
                "gioi_tinh": contract.contract_detail.gioi_tinh.value,
                "ngay_sinh": contract.contract_detail.ngay_sinh.isoformat(),
                "dia_chi_co_quan": contract.contract_detail.dia_chi_co_quan or "",
                "dia_chi_thuong_tru": contract.contract_detail.dia_chi_thuong_tru,
                "so_dien_thoai": contract.contract_detail.so_dien_thoai,
                "lich_su_benh": contract.contract_detail.lich_su_benh or ""
            })
        
        # Call stored procedure to create contract
        results = execute_procedure(
            "sp_create_contract",
            [
                token_data.sub,               # user_id
                contract.insurance_type_id,   # insurance_type_id
                contract.insured_person_id,   # insured_person_id
                contract.ngay_ki_hd.isoformat(),  # ngay_ki
                contract.ngay_cat_hd.isoformat(), # ngay_cat
                contract.trang_thai.value,    # trang_thai
                contract_details_json         # contract_details
            ]
        )
        
        # Check for error result
        if not results or len(results) == 0 or not results[0] or 'status' not in results[0][0]:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Error creating contract"
            )
        
        result = results[0][0]
        if result['status'] == 'error':
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=result['message']
            )
        
        log_activity(token_data.sub, "create", f"Created contract (ID: {result.get('contract_id')})")
        
        return GenericResponse(
            status="success",
            message=result['message'],
            data={"contract_id": result.get('contract_id')}
        )
    except HTTPException:
        raise
    except Exception as e:
        log_activity(token_data.sub, "error", f"Error creating contract: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error creating contract: {str(e)}"
        )

@router.put("/{contract_id}", response_model=GenericResponse)
async def update_contract(
    contract: ContractUpdate,
    contract_id: int = Path(..., description="The ID of the contract to update"),
    token_data: TokenData = Depends(require_authenticated)
):
    """
    Update an existing contract and its details.
    Only the contract creator and admin can update contracts.
    """
    try:
        # Prepare contract details if provided
        contract_details_json = None
        if contract.contract_detail:
            contract_details_json = json.dumps({
                "id": contract.contract_detail.id,
                "ho_ten": contract.contract_detail.ho_ten,
                "gioi_tinh": contract.contract_detail.gioi_tinh.value if contract.contract_detail.gioi_tinh else None,
                "ngay_sinh": contract.contract_detail.ngay_sinh.isoformat() if contract.contract_detail.ngay_sinh else None,
                "dia_chi_co_quan": contract.contract_detail.dia_chi_co_quan,
                "dia_chi_thuong_tru": contract.contract_detail.dia_chi_thuong_tru,
                "so_dien_thoai": contract.contract_detail.so_dien_thoai,
                "lich_su_benh": contract.contract_detail.lich_su_benh
            })
        
        # Call stored procedure to update contract
        results = execute_procedure(
            "sp_update_contract",
            [
                token_data.sub,                              # user_id
                contract_id,                                 # contract_id
                contract.insurance_type_id,                  # insurance_type_id
                contract.insured_person_id,                  # insured_person_id
                contract.ngay_ki_hd.isoformat() if contract.ngay_ki_hd else None,  # ngay_ki
                contract.ngay_cat_hd.isoformat() if contract.ngay_cat_hd else None, # ngay_cat
                contract.trang_thai.value if contract.trang_thai else None, # trang_thai
                contract_details_json                        # contract_details
            ]
        )
        
        # Check for error result
        if not results or len(results) == 0 or not results[0] or 'status' not in results[0][0]:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Error updating contract"
            )
        
        result = results[0][0]
        if result['status'] == 'error':
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=result['message']
            )
        
        log_activity(token_data.sub, "update", f"Updated contract (ID: {contract_id})")
        
        return GenericResponse(
            status="success",
            message=result['message']
        )
    except HTTPException:
        raise
    except Exception as e:
        log_activity(token_data.sub, "error", f"Error updating contract: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error updating contract: {str(e)}"
        )

@router.delete("/{contract_id}", response_model=GenericResponse)
async def delete_contract(
    contract_id: int = Path(..., description="The ID of the contract to delete"),
    token_data: TokenData = Depends(require_authenticated)
):
    """
    Delete a contract and all associated data.
    Only the contract creator and admin can delete contracts.
    """
    try:
        # Call stored procedure to delete contract
        results = execute_procedure(
            "sp_delete_contract",
            [
                token_data.sub,  # user_id
                contract_id      # contract_id
            ]
        )
        
        # Check for error result
        if not results or len(results) == 0 or not results[0] or 'status' not in results[0][0]:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Error deleting contract"
            )
        
        result = results[0][0]
        if result['status'] == 'error':
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=result['message']
            )
        
        log_activity(token_data.sub, "delete", f"Deleted contract (ID: {contract_id})")
        
        return GenericResponse(
            status="success",
            message=result['message']
        )
    except HTTPException:
        raise
    except Exception as e:
        log_activity(token_data.sub, "error", f"Error deleting contract: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error deleting contract: {str(e)}"
        )

@router.post("/{contract_id}/create-insured-user", response_model=CreateInsuredUserResponse)
async def create_insured_user(
    request: CreateInsuredUserRequest,
    contract_id: int = Path(..., description="The ID of the contract"),
    token_data: TokenData = Depends(require_authenticated)
):
    """
    Create a user account for the insured person based on contract details.
    The account is created in inactive state and an activation email is sent.
    """
    try:
        # Call stored procedure to create insured user
        results = execute_procedure(
            "sp_create_insured_user_from_contract",
            [
                token_data.sub,  # user_id
                contract_id,         # contract_id
                request.email,       # email
                request.username     # username
            ]
        )
        
        # Check for error result
        if not results or len(results) == 0 or not results[0] or 'status' not in results[0][0]:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Error creating insured user"
            )
        
        result = results[0][0]
        if result['status'] == 'error':
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=result['message']
            )
        
        # Send activation email
        if 'activation_token' in result and 'email' in result:
            await send_activation_email(result['email'], result['activation_token'])
            log_activity(token_data.sub, "create", f"Created insured user for contract (ID: {contract_id})")
        
        return CreateInsuredUserResponse(
            status=result['status'],
            message=result['message'],
            activation_token=result.get('activation_token'),
            user_id=result.get('user_id'),
            email=result.get('email')
        )
    except HTTPException:
        raise
    except Exception as e:
        log_activity(token_data.sub, "error", f"Error creating insured user: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error creating insured user: {str(e)}"
        )
