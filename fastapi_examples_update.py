from fastapi import FastAPI, Depends, HTTPException, status, Query
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel, Field
from typing import Optional, List
import mysql.connector
from datetime import date, datetime, timedelta
import json

app = FastAPI(title="Hệ thống Quản lý Bảo hiểm")

# Kết nối database
def get_db_connection():
    connection = mysql.connector.connect(
        host="localhost",
        user="root",
        password="password",
        database="insurance_management2"
    )
    return connection

# ---- PHẦN 1: MÔ HÌNH DỮ LIỆU PYDANTIC ----

# Mô hình cho trạng thái hợp đồng
class ContractStatus(BaseModel):
    contract_id: int
    status: str = Field(..., description="Trạng thái hợp đồng: processing, active, expired, cancelled")

# Mô hình cho trạng thái thanh toán
class PaymentStatus(BaseModel):
    payment_id: int
    status: str = Field(..., description="Trạng thái thanh toán: pending, completed, failed, cancelled")
    note: Optional[str] = None

# Mô hình cho cập nhật địa chỉ
class AddressUpdate(BaseModel):
    id: int
    diachi_thuong_tru: Optional[str] = None
    diachi_tam_tru: Optional[str] = None 
    diachi_lien_lac: Optional[str] = None

# Mô hình cho giá trị bảo hiểm
class InsuranceValue(BaseModel):
    contract_id: int
    insurance_value: float = Field(..., description="Giá trị bảo hiểm")

# Mô hình cho chi tiết hợp đồng với địa chỉ mới
class ContractDetailCreate(BaseModel):
    contract_id: int
    ho_ten: str
    gioi_tinh: str = Field(..., description="male, female, other")
    ngay_sinh: date
    diachi_co_quan: Optional[str] = None
    diachi_thuong_tru: str
    diachi_tam_tru: Optional[str] = None
    diachi_lien_lac: Optional[str] = None
    sodienthoai: str
    lichsu_benh: Optional[str] = None

# Mô hình cho đọc chi tiết hợp đồng
class ContractDetail(BaseModel):
    id: int
    idHopDong: int
    hoTen: str
    gioiTinh: str
    ngaySinh: date
    diachiCoQuan: Optional[str] = None
    diachiThuongTru: str
    diachiTamTru: Optional[str] = None
    diachiLienLac: Optional[str] = None
    sodienthoai: str
    lichsuBenh: Optional[str] = None

# Mô hình cho thanh toán
class Payment(BaseModel):
    id: int
    idHopDong: int
    ngayDongBaoHiem: date
    soTienDong: float
    trangThai: str

# ---- PHẦN 2: ENDPOINT TRẠNG THÁI HỢP ĐỒNG ----

@app.put("/contracts/{contract_id}/status", tags=["contracts"])
def update_contract_status(contract_id: int, status: ContractStatus):
    if status.contract_id != contract_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Path contract ID and body contract ID don't match"
        )
    
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.callproc("sp_CapNhatTrangThaiHopDong", [contract_id, status.status])
        
        # Lấy kết quả từ stored procedure
        for result in cursor.stored_results():
            return result.fetchone()
        
        conn.commit()
        return {"success": True, "message": "Cập nhật trạng thái hợp đồng thành công"}
    except mysql.connector.Error as err:
        conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Database error: {str(err)}"
        )
    finally:
        cursor.close()
        conn.close()

@app.get("/contracts/status/{status_type}", tags=["contracts"])
def get_contracts_by_status(status_type: str = Path(..., description="processing, active, expired, cancelled")):
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        
        # Kiểm tra quyền truy cập và lọc theo vai trò
        query = """
        SELECT 
            hd.id, hd.ngayKiHD, hd.ngayCatHD, hd.TrangThai, hd.giaTriBaoHiem, 
            it.tenBH, 
            JSON_OBJECT('id', ct.id, 'hoTen', CONVERT(ct.HoTen, CHAR)) as chi_tiet
        FROM 
            HopDong hd
        JOIN 
            insurance_types it ON hd.idLoaiBaoHiem = it.id
        JOIN 
            ChiTietHopDong ct ON hd.id = ct.idHopDong
        WHERE 
            hd.TrangThai = %s
        ORDER BY 
            hd.ngayKiHD DESC
        """
        
        cursor.execute(query, (status_type,))
        results = cursor.fetchall()
        
        # Xử lý kết quả để đảm bảo JSON chính xác
        for row in results:
            if 'chi_tiet' in row and row['chi_tiet']:
                row['chi_tiet'] = json.loads(row['chi_tiet'])
        
        return {"contracts": results}
    except mysql.connector.Error as err:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Database error: {str(err)}"
        )
    finally:
        cursor.close()
        conn.close()

# ---- PHẦN 3: ENDPOINT TRẠNG THÁI THANH TOÁN ----

@app.put("/payments/{payment_id}/status", tags=["payments"])
def update_payment_status(payment_id: int, payment_status: PaymentStatus):
    if payment_status.payment_id != payment_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Path payment ID and body payment ID don't match"
        )
    
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.callproc("sp_CapNhatTrangThaiThanhToan", [
            payment_id, 
            payment_status.status, 
            payment_status.note
        ])
        
        # Lấy kết quả từ stored procedure
        for result in cursor.stored_results():
            return result.fetchone()
        
        conn.commit()
        return {"success": True, "message": "Cập nhật trạng thái thanh toán thành công"}
    except mysql.connector.Error as err:
        conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Database error: {str(err)}"
        )
    finally:
        cursor.close()
        conn.close()

@app.get("/payments/status/{status_type}", tags=["payments"])
def get_payments_by_status(
    status_type: str = Path(..., description="pending, completed, failed, cancelled"),
    contract_id: Optional[int] = Query(None, description="Lọc theo ID hợp đồng")
):
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        
        if contract_id:
            query = """
            SELECT * FROM ThanhToan
            WHERE TrangThai = %s AND idHopDong = %s
            ORDER BY ngayDongBaoHiem DESC
            """
            cursor.execute(query, (status_type, contract_id))
        else:
            query = """
            SELECT * FROM ThanhToan
            WHERE TrangThai = %s
            ORDER BY ngayDongBaoHiem DESC
            """
            cursor.execute(query, (status_type,))
            
        results = cursor.fetchall()
        return {"payments": results}
    except mysql.connector.Error as err:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Database error: {str(err)}"
        )
    finally:
        cursor.close()
        conn.close()

# ---- PHẦN 4: ENDPOINT ĐỊA CHỈ MỚI ----

@app.put("/contract-details/{detail_id}/addresses", tags=["contract-details"])
def update_contract_addresses(detail_id: int, address_data: AddressUpdate):
    if address_data.id != detail_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Path detail ID and body ID don't match"
        )
    
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.callproc("sp_CapNhatDiaChiChiTietHopDong", [
            detail_id, 
            address_data.diachi_thuong_tru, 
            address_data.diachi_tam_tru,
            address_data.diachi_lien_lac
        ])
        
        # Lấy kết quả từ stored procedure
        for result in cursor.stored_results():
            return result.fetchone()
        
        conn.commit()
        return {"success": True, "message": "Cập nhật địa chỉ thành công"}
    except mysql.connector.Error as err:
        conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Database error: {str(err)}"
        )
    finally:
        cursor.close()
        conn.close()

# ---- PHẦN 5: ENDPOINT GIÁ TRỊ BẢO HIỂM ----

@app.put("/contracts/{contract_id}/insurance-value", tags=["contracts"])
def update_insurance_value(contract_id: int, insurance_data: InsuranceValue):
    if insurance_data.contract_id != contract_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Path contract ID and body contract ID don't match"
        )
    
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.callproc("sp_CapNhatGiaTriBaoHiem", [
            contract_id, 
            insurance_data.insurance_value
        ])
        
        # Lấy kết quả từ stored procedure
        for result in cursor.stored_results():
            return result.fetchone()
        
        conn.commit()
        return {"success": True, "message": "Cập nhật giá trị bảo hiểm thành công"}
    except mysql.connector.Error as err:
        conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Database error: {str(err)}"
        )
    finally:
        cursor.close()
        conn.close()

@app.post("/contracts/{contract_id}/calculate-insurance-value", tags=["contracts"])
def calculate_insurance_value(contract_id: int):
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.callproc("sp_TinhGiaTriBaoHiem", [contract_id])
        
        # Lấy kết quả từ stored procedure
        for result in cursor.stored_results():
            return result.fetchone()
        
        conn.commit()
        return {"success": True, "message": "Tính toán giá trị bảo hiểm thành công"}
    except mysql.connector.Error as err:
        conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Database error: {str(err)}"
        )
    finally:
        cursor.close()
        conn.close()

@app.post("/contracts/calculate-all-insurance-values", tags=["contracts"])
def calculate_all_insurance_values():
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.callproc("sp_TinhLaiTatCaGiaTriBaoHiem", [])
        
        # Lấy kết quả từ stored procedure
        for result in cursor.stored_results():
            return result.fetchone()
        
        conn.commit()
        return {"success": True, "message": "Đã tính lại tất cả giá trị bảo hiểm"}
    except mysql.connector.Error as err:
        conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Database error: {str(err)}"
        )
    finally:
        cursor.close()
        conn.close()

# ---- PHẦN 6: ENDPOINT CHI TIẾT HỢP ĐỒNG VỚI TRƯỜNG MỚI ----

@app.post("/contract-details", tags=["contract-details"])
def create_contract_detail(detail_data: ContractDetailCreate):
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        
        # Ví dụ với phiên đơn giản, thực tế cần lấy user_id từ token
        user_id = 1  # Giả định là người lập hợp đồng ID = 1
        
        cursor.callproc("add_contract_detail", [
            user_id,
            detail_data.contract_id,
            detail_data.ho_ten,
            detail_data.gioi_tinh,
            detail_data.ngay_sinh,
            detail_data.diachi_co_quan,
            detail_data.diachi_thuong_tru,
            detail_data.diachi_tam_tru,
            detail_data.diachi_lien_lac,
            detail_data.sodienthoai,
            detail_data.lichsu_benh
        ])
        
        # Lấy kết quả từ stored procedure
        for result in cursor.stored_results():
            return result.fetchone()
        
        conn.commit()
        return {"success": True, "message": "Thêm chi tiết hợp đồng thành công"}
    except mysql.connector.Error as err:
        conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Database error: {str(err)}"
        )
    finally:
        cursor.close()
        conn.close()

@app.get("/contract-details/{detail_id}", tags=["contract-details"])
def get_contract_detail(detail_id: int):
    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.callproc("sp_get_contract_detail_json", [detail_id])
        
        # Lấy kết quả từ stored procedure
        result = None
        for result_cursor in cursor.stored_results():
            result = result_cursor.fetchone()
        
        if not result or 'contract_detail' not in result:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, 
                detail="Chi tiết hợp đồng không tìm thấy"
            )
        
        # Chuyển đổi chuỗi JSON thành đối tượng Python
        contract_detail = json.loads(result['contract_detail'])
        return contract_detail
    except mysql.connector.Error as err:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Database error: {str(err)}"
        )
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
