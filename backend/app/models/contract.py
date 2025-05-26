"""
Contract models for data validation and response schemas
"""
from pydantic import BaseModel, Field, EmailStr, validator
from typing import Optional, List, Dict, Any, Union
from datetime import date
from enum import Enum

class ContractStatus(str, Enum):
    """Contract status enum"""
    PROCESSING = "processing"
    ACTIVE = "active"
    EXPIRED = "expired"
    CANCELLED = "cancelled"

class Gender(str, Enum):
    """Gender enum"""
    MALE = "male"
    FEMALE = "female"
    OTHER = "other"

class ContractDetailBase(BaseModel):
    """Base model for contract details"""
    ho_ten: str
    gioi_tinh: Gender
    ngay_sinh: date
    dia_chi_co_quan: Optional[str] = None
    dia_chi_thuong_tru: str
    so_dien_thoai: str
    lich_su_benh: Optional[str] = None

class ContractDetailCreate(ContractDetailBase):
    """Model for creating contract details"""
    pass

class ContractDetailUpdate(BaseModel):
    """Model for updating contract details"""
    id: int
    ho_ten: Optional[str] = None
    gioi_tinh: Optional[Gender] = None
    ngay_sinh: Optional[date] = None
    dia_chi_co_quan: Optional[str] = None
    dia_chi_thuong_tru: Optional[str] = None
    so_dien_thoai: Optional[str] = None
    lich_su_benh: Optional[str] = None

class ContractDetailResponse(ContractDetailBase):
    """Response model for contract details"""
    id: int
    
    class Config:
        orm_mode = True

class ContractBase(BaseModel):
    """Base model for insurance contract"""
    insurance_type_id: int
    ngay_ki_hd: date
    ngay_cat_hd: date
    trang_thai: Optional[ContractStatus] = ContractStatus.PROCESSING

    @validator('ngay_cat_hd')
    def validate_end_date(cls, v, values):
        if 'ngay_ki_hd' in values and v < values['ngay_ki_hd']:
            raise ValueError("Ngày kết thúc phải sau ngày bắt đầu")
        return v

class ContractCreate(ContractBase):
    """Model for creating a new contract"""
    insured_person_id: Optional[int] = None
    contract_detail: Optional[ContractDetailCreate] = None

class ContractUpdate(BaseModel):
    """Model for updating a contract"""
    insurance_type_id: Optional[int] = None
    insured_person_id: Optional[int] = None
    ngay_ki_hd: Optional[date] = None
    ngay_cat_hd: Optional[date] = None
    trang_thai: Optional[ContractStatus] = None
    contract_detail: Optional[ContractDetailUpdate] = None
    
    @validator('ngay_cat_hd')
    def validate_end_date(cls, v, values):
        if v and 'ngay_ki_hd' in values and values['ngay_ki_hd'] and v < values['ngay_ki_hd']:
            raise ValueError("Ngày kết thúc phải sau ngày bắt đầu")
        return v

class PaymentInfo(BaseModel):
    """Payment information for contract"""
    id: int
    ngay_dong_bao_hiem: date
    so_tien_dong: float

class ContractResponse(BaseModel):
    """Response model for a contract"""
    id: int
    creator_id: int
    nguoi_lap_hd: str
    insurance_type_id: int
    loai_bao_hiem: str
    insured_person_id: Optional[int] = None
    username_nguoi_bh: Optional[str] = None
    ngay_ki_hd: date
    ngay_cat_hd: date
    trang_thai: ContractStatus
    created_at: Any
    
    class Config:
        orm_mode = True

class ContractListItem(BaseModel):
    """Model for contract list item"""
    id: int
    loai_bao_hiem: str
    ten_nguoi_bh: str
    nguoi_lap_hd: str
    ngay_ki_hd: date
    ngay_cat_hd: date
    trang_thai: ContractStatus
    so_ky_thanh_toan: int
    
    class Config:
        orm_mode = True

class ContractListResponse(BaseModel):
    """Response model for contract list"""
    items: List[ContractListItem]
    total: int
    page: int
    limit: int

class ContractDetailWithPayments(BaseModel):
    """Response model for contract details with payments"""
    contract: ContractResponse
    details: ContractDetailResponse
    payments: List[PaymentInfo]

class CreateInsuredUserRequest(BaseModel):
    """Request model for creating an insured user from contract"""
    email: EmailStr
    username: str = Field(..., min_length=3)

class CreateInsuredUserResponse(BaseModel):
    """Response model for creating an insured user"""
    status: str
    message: str
    activation_token: Optional[str] = None
    user_id: Optional[int] = None
    email: Optional[str] = None

class GenericResponse(BaseModel):
    """Generic response model"""
    status: str
    message: str
    data: Optional[Dict[str, Any]] = None
