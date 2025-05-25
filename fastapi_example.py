'''filepath: d:\\BaoMatThongTin\\Nhom 06 - HeThongQuanLyBaoHiem\\fastapi_example.py
This is an example of how to use the database with FastAPI
'''

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel, Field
from typing import Dict, List, Optional, Union, Any
import pymysql
import json
import uuid
import jwt
from datetime import datetime, timedelta
import os
from fastapi.middleware.cors import CORSMiddleware

# Cấu hình bảo mật
SECRET_KEY = "your-secret-key-here"  # Trong môi trường thực tế, nên lưu trong biến môi trường
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

app = FastAPI(title="Hệ Thống Quản Lý Bảo Hiểm API")

# Bật CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Trong môi trường thực tế, chỉ định cụ thể domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Thiết lập kết nối MySQL
def get_db():
    connection = pymysql.connect(
        host='localhost',
        user='root',
        password='your-password',  # Thay bằng mật khẩu MySQL thực tế
        db='insurance_management',
        charset='utf8mb4',
        cursorclass=pymysql.cursors.DictCursor
    )
    try:
        yield connection
    finally:
        connection.close()

# Các model Pydantic
class LoginRequest(BaseModel):
    username: str
    password: str
    client_ip: Optional[str] = None

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    session_id: Optional[str] = None

class UserInDB(BaseModel):
    id: int
    role: str
    insurance_type: Optional[int] = None
    session_id: str

class ContractCreate(BaseModel):
    insurance_type_id: int
    insured_id: int
    start_date: str
    end_date: str
    insurance_value: float
    personal_info: Dict[str, Any]

class PaymentCreate(BaseModel):
    contract_id: int
    payment_date: str
    amount: float

# OAuth2 scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Hàm tạo JWT token
def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# Lấy thông tin người dùng hiện tại
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: pymysql.Connection = Depends(get_db)
):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # Giải mã JWT để lấy session_id
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        session_id = payload.get("session_id")
        if session_id is None:
            raise credentials_exception
        
        # Xác thực phiên với database
        with db.cursor() as cursor:
            cursor.execute("CALL fastapi_validate_session(%s)", (session_id,))
            result = cursor.fetchone()
        
        session_data = json.loads(result["result"])
        if not session_data["valid"]:
            raise credentials_exception
            
        # Trả về thông tin người dùng và phiên
        return UserInDB(
            id=session_data["user_id"],
            role=session_data["role"],
            insurance_type=session_data["insurance_type"],
            session_id=session_id
        )
    except:
        raise credentials_exception

# API endpoint đăng nhập
@app.post("/login", response_model=Token)
async def login_for_access_token(request: LoginRequest, db: pymysql.Connection = Depends(get_db)):
    # Tạo session_id
    session_id = str(uuid.uuid4())
    
    # Lấy IP từ request
    client_ip = request.client_ip or "unknown"
    
    # Thực thi stored procedure đăng nhập
    with db.cursor() as cursor:
        cursor.execute(
            "CALL fastapi_login(%s, %s, %s, %s)", 
            (request.username, request.password, session_id, client_ip)
        )
        result = cursor.fetchone()
    
    db.commit()
    login_result = json.loads(result["result"])
    
    if login_result["success"]:
        # Tạo JWT token
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"session_id": session_id}, expires_delta=access_token_expires
        )
        return {"access_token": access_token, "token_type": "bearer"}
    else:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Tên đăng nhập hoặc mật khẩu không đúng",
            headers={"WWW-Authenticate": "Bearer"},
        )

# API endpoint đăng xuất
@app.post("/logout")
async def logout(current_user: UserInDB = Depends(get_current_user), db: pymysql.Connection = Depends(get_db)):
    with db.cursor() as cursor:
        cursor.execute("CALL fastapi_logout(%s)", (current_user.session_id,))
        result = cursor.fetchone()
    
    db.commit()
    logout_result = json.loads(result["result"])
    return {"success": logout_result["success"]}

# API endpoint lấy thông tin người dùng
@app.get("/users/me")
async def read_users_me(current_user: UserInDB = Depends(get_current_user), db: pymysql.Connection = Depends(get_db)):
    with db.cursor() as cursor:
        cursor.execute("CALL get_user_details_json(%s)", (current_user.id,))
        result = cursor.fetchone()
    
    user_details = json.loads(result["result"])
    return user_details

# API endpoint lấy danh sách người dùng (chỉ cho admin)
@app.get("/users")
async def get_users(
    search: str = None,
    role: str = None,
    status: str = None,
    page: int = 0,
    page_size: int = 10,
    current_user: UserInDB = Depends(get_current_user),
    db: pymysql.Connection = Depends(get_db)
):
    # Kiểm tra quyền admin (trong thực tế cần thêm role admin vào hệ thống)
    if current_user.role not in ["admin"]:
        raise HTTPException(status_code=403, detail="Không có quyền truy cập")
    
    with db.cursor() as cursor:
        cursor.execute(
            "CALL get_users_paginated(%s, %s, %s, %s, %s)",
            (search, role, status, page, page_size)
        )
        result = cursor.fetchone()
    
    return json.loads(result["result"])

# API endpoint lấy danh sách hợp đồng
@app.get("/contracts")
async def get_contracts(
    search: str = None,
    status: str = None,
    insurance_type: int = None,
    start_date: str = None,
    end_date: str = None,
    page: int = 0,
    page_size: int = 10,
    current_user: UserInDB = Depends(get_current_user),
    db: pymysql.Connection = Depends(get_db)
):
    with db.cursor() as cursor:
        cursor.execute(
            "CALL get_contracts_paginated(%s, %s, %s, %s, %s, %s, %s, %s)",
            (current_user.id, search, status, insurance_type, start_date, end_date, page, page_size)
        )
        result = cursor.fetchone()
    
    return json.loads(result["result"])

# API endpoint lấy chi tiết hợp đồng
@app.get("/contracts/{contract_id}")
async def get_contract_detail(
    contract_id: int,
    current_user: UserInDB = Depends(get_current_user),
    db: pymysql.Connection = Depends(get_db)
):
    with db.cursor() as cursor:
        cursor.execute(
            "CALL get_contract_detail(%s, %s)",
            (current_user.id, contract_id)
        )
        result = cursor.fetchone()
    
    detail = json.loads(result["result"])
    if not detail["access_granted"]:
        raise HTTPException(status_code=403, detail="Không có quyền truy cập hợp đồng này")
    
    return detail

# API endpoint tạo hợp đồng mới
@app.post("/contracts")
async def create_contract(
    contract: ContractCreate,
    current_user: UserInDB = Depends(get_current_user),
    db: pymysql.Connection = Depends(get_db)
):
    # Chỉ người tạo hợp đồng mới có thể tạo hợp đồng mới
    if current_user.role != "contract_creator":
        raise HTTPException(status_code=403, detail="Không có quyền tạo hợp đồng mới")
    
    with db.cursor() as cursor:
        cursor.execute(
            "CALL create_contract_json(%s, %s)",
            (current_user.id, json.dumps(contract.dict()))
        )
        result = cursor.fetchone()
    
    db.commit()
    create_result = json.loads(result["result"])
    
    if not create_result["success"]:
        raise HTTPException(status_code=400, detail=create_result["message"])
    
    return create_result

# API endpoint cập nhật trạng thái hợp đồng
@app.put("/contracts/{contract_id}/status")
async def update_contract_status(
    contract_id: int,
    status: str,
    current_user: UserInDB = Depends(get_current_user),
    db: pymysql.Connection = Depends(get_db)
):
    with db.cursor() as cursor:
        cursor.execute(
            "CALL update_contract_status_json(%s, %s, %s)",
            (current_user.id, contract_id, status)
        )
        result = cursor.fetchone()
    
    db.commit()
    update_result = json.loads(result["result"])
    
    if not update_result["success"]:
        raise HTTPException(status_code=403, detail=update_result["message"])
    
    return update_result

# API endpoint thêm kỳ thanh toán
@app.post("/payments")
async def add_payment(
    payment: PaymentCreate,
    current_user: UserInDB = Depends(get_current_user),
    db: pymysql.Connection = Depends(get_db)
):
    with db.cursor() as cursor:
        cursor.execute(
            "CALL add_payment_json(%s, %s, %s, %s)",
            (current_user.id, payment.contract_id, payment.payment_date, payment.amount)
        )
        result = cursor.fetchone()
    
    db.commit()
    payment_result = json.loads(result["result"])
    
    if not payment_result["success"]:
        raise HTTPException(status_code=403, detail=payment_result["message"])
    
    return payment_result

# API endpoint cập nhật trạng thái thanh toán
@app.put("/payments/{payment_id}/status")
async def update_payment_status(
    payment_id: int,
    status: str,
    current_user: UserInDB = Depends(get_current_user),
    db: pymysql.Connection = Depends(get_db)
):
    with db.cursor() as cursor:
        cursor.execute(
            "CALL update_payment_status_json(%s, %s, %s)",
            (current_user.id, payment_id, status)
        )
        result = cursor.fetchone()
    
    db.commit()
    update_result = json.loads(result["result"])
    
    if not update_result["success"]:
        raise HTTPException(status_code=403, detail=update_result["message"])
    
    return update_result

# API endpoint lấy lịch sử thanh toán của hợp đồng
@app.get("/contracts/{contract_id}/payments")
async def get_payment_history(
    contract_id: int,
    current_user: UserInDB = Depends(get_current_user),
    db: pymysql.Connection = Depends(get_db)
):
    with db.cursor() as cursor:
        cursor.execute(
            "CALL get_payment_history_json(%s, %s)",
            (current_user.id, contract_id)
        )
        result = cursor.fetchone()
    
    history = json.loads(result["result"])
    if not history["access_granted"]:
        raise HTTPException(status_code=403, detail="Không có quyền truy cập lịch sử thanh toán của hợp đồng này")
    
    return history

# API endpoint lấy tổng quan dashboard
@app.get("/dashboard")
async def get_dashboard(
    current_user: UserInDB = Depends(get_current_user),
    db: pymysql.Connection = Depends(get_db)
):
    with db.cursor() as cursor:
        cursor.execute(
            "CALL get_dashboard_json(%s)",
            (current_user.id,)
        )
        result = cursor.fetchone()
    
    return json.loads(result["result"])

# API endpoint lấy thống kê theo thời gian
@app.get("/statistics/time")
async def get_time_statistics(
    period: str = "month",  # 'day', 'week', 'month', 'year'
    start_date: str = None,
    end_date: str = None,
    current_user: UserInDB = Depends(get_current_user),
    db: pymysql.Connection = Depends(get_db)
):
    with db.cursor() as cursor:
        cursor.execute(
            "CALL get_time_statistics_json(%s, %s, %s, %s)",
            (current_user.id, period, start_date, end_date)
        )
        result = cursor.fetchone()
    
    return json.loads(result["result"])

# API endpoint lấy danh sách loại bảo hiểm
@app.get("/insurance-types")
async def get_insurance_types(
    current_user: UserInDB = Depends(get_current_user),
    db: pymysql.Connection = Depends(get_db)
):
    with db.cursor() as cursor:
        cursor.execute("CALL get_insurance_types_json()")
        result = cursor.fetchone()
    
    return json.loads(result["result"])

# Khởi động ứng dụng với uvicorn
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
