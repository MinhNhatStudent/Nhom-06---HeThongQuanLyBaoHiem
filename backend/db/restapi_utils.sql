-- ============================================================================
-- TIỆN ÍCH CHO RESTFUL API VỚI FASTAPI
-- ============================================================================
USE insurance_management;

-- ============================================================================
-- PHẦN 1: STORED PROCEDURES CHO PHÂN TRANG VÀ TÌM KIẾM
-- ============================================================================

-- Lấy danh sách người dùng với phân trang và tìm kiếm
DELIMITER //
CREATE PROCEDURE get_users_paginated(
    IN p_search VARCHAR(100),
    IN p_role VARCHAR(50),
    IN p_status VARCHAR(20),
    IN p_page INT,
    IN p_page_size INT
)
BEGIN
    DECLARE v_offset INT;
    DECLARE v_count INT;
    DECLARE v_where_clause TEXT DEFAULT '';
    
    -- Tính toán phân trang
    SET v_offset = p_page * p_page_size;
    
    -- Xây dựng điều kiện WHERE
    IF p_search IS NOT NULL AND p_search != '' THEN
        SET v_where_clause = CONCAT(v_where_clause, 
            " AND (username LIKE CONCAT('%', '", p_search, "', '%') OR email LIKE CONCAT('%', '", p_search, "', '%'))");
    END IF;
    
    IF p_role IS NOT NULL AND p_role != '' THEN
        SET v_where_clause = CONCAT(v_where_clause, " AND vaitro = '", p_role, "'");
    END IF;
    
    IF p_status IS NOT NULL AND p_status != '' THEN
        SET v_where_clause = CONCAT(v_where_clause, " AND TrangThai = '", p_status, "'");
    END IF;
    
    -- Đếm tổng số bản ghi
    SET @sql_count = CONCAT('SELECT COUNT(*) INTO @total_count FROM NguoiDung WHERE 1=1 ', v_where_clause);
    PREPARE stmt FROM @sql_count;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    -- Lấy dữ liệu
    SET @sql = CONCAT('
        SELECT 
            JSON_OBJECT(
                "total_count", @total_count,
                "page", ', p_page, ',
                "page_size", ', p_page_size, ',
                "total_pages", CEILING(@total_count / ', p_page_size, '),
                "data", IFNULL(
                    (SELECT JSON_ARRAYAGG(
                        JSON_OBJECT(
                            "id", id,
                            "username", username,
                            "email", email,
                            "role", vaitro,
                            "status", TrangThai,
                            "insurance_type_id", idLoaiBaoHiem,
                            "created_at", created_at,
                            "activated", activated
                        )
                    )
                    FROM NguoiDung
                    WHERE 1=1 ', v_where_clause, '
                    ORDER BY created_at DESC
                    LIMIT ', p_page_size, ' OFFSET ', v_offset, '),
                JSON_ARRAY()
                )
            ) AS result
    ');
    
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //
DELIMITER ;

-- Lấy danh sách hợp đồng với phân trang và tìm kiếm
DELIMITER //
CREATE PROCEDURE get_contracts_paginated(
    IN p_user_id INT,
    IN p_search VARCHAR(100),
    IN p_status VARCHAR(20),
    IN p_insurance_type INT,
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_page INT,
    IN p_page_size INT
)
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_insurance_type_id INT;
    DECLARE v_offset INT;
    DECLARE v_where_clause TEXT;
    
    -- Lấy vai trò và loại bảo hiểm của người dùng
    SELECT vaitro, idLoaiBaoHiem INTO v_role, v_insurance_type_id FROM NguoiDung WHERE id = p_user_id;
    
    -- Tính toán phân trang
    SET v_offset = p_page * p_page_size;
    
    -- Xây dựng điều kiện WHERE dựa trên vai trò
    CASE v_role
        WHEN 'contract_creator' THEN
            SET v_where_clause = CONCAT(' AND hd.creator_id = ', p_user_id);
        WHEN 'insured_person' THEN
            SET v_where_clause = CONCAT(' AND hd.idNguoiBH = ', p_user_id);
        WHEN 'accounting' THEN
            SET v_where_clause = CONCAT(' AND hd.idLoaiBaoHiem = ', v_insurance_type_id);
        WHEN 'supervisor' THEN
            SET v_where_clause = CONCAT(' AND hd.idLoaiBaoHiem = ', v_insurance_type_id);
        ELSE
            SET v_where_clause = '';
    END CASE;
    
    -- Thêm điều kiện tìm kiếm
    IF p_search IS NOT NULL AND p_search != '' THEN
        SET v_where_clause = CONCAT(v_where_clause, 
            " AND (decrypt_data(ct.HoTen) LIKE CONCAT('%', '", p_search, "', '%') OR ",
            "decrypt_data(ct.sodienthoai) LIKE CONCAT('%', '", p_search, "', '%'))");
    END IF;
    
    -- Lọc theo trạng thái
    IF p_status IS NOT NULL AND p_status != '' THEN
        SET v_where_clause = CONCAT(v_where_clause, " AND hd.TrangThai = '", p_status, "'");
    END IF;
    
    -- Lọc theo loại bảo hiểm (nếu vai trò không phải là kế toán hoặc giám sát)
    IF v_role NOT IN ('accounting', 'supervisor') AND p_insurance_type IS NOT NULL THEN
        SET v_where_clause = CONCAT(v_where_clause, " AND hd.idLoaiBaoHiem = ", p_insurance_type);
    END IF;
    
    -- Lọc theo ngày bắt đầu
    IF p_start_date IS NOT NULL THEN
        SET v_where_clause = CONCAT(v_where_clause, " AND hd.ngayKiHD >= '", p_start_date, "'");
    END IF;
    
    -- Lọc theo ngày kết thúc
    IF p_end_date IS NOT NULL THEN
        SET v_where_clause = CONCAT(v_where_clause, " AND hd.ngayCatHD <= '", p_end_date, "'");
    END IF;
    
    -- Đếm tổng số bản ghi
    SET @sql_count = CONCAT('
        SELECT COUNT(DISTINCT hd.id) INTO @total_count
        FROM HopDong hd
        JOIN ChiTietHopDong ct ON hd.id = ct.idHopDong
        JOIN insurance_types it ON hd.idLoaiBaoHiem = it.id
        LEFT JOIN ThanhToan tt ON hd.id = tt.idHopDong
        WHERE 1=1 ', v_where_clause
    );
    PREPARE stmt FROM @sql_count;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    -- Lấy dữ liệu
    SET @sql = CONCAT('
        SELECT 
            JSON_OBJECT(
                "total_count", @total_count,
                "page", ', p_page, ',
                "page_size", ', p_page_size, ',
                "total_pages", CEILING(@total_count / ', p_page_size, '),
                "data", IFNULL(
                    (SELECT JSON_ARRAYAGG(
                        JSON_OBJECT(
                            "id", hd.id,
                            "insurance_type", JSON_OBJECT(
                                "id", it.id,
                                "name", it.tenBH
                            ),
                            "name", decrypt_data(ct.HoTen),
                            "status", hd.TrangThai,
                            "start_date", hd.ngayKiHD,
                            "end_date", hd.ngayCatHD,
                            "insurance_value", hd.giaTriBaoHiem,
                            "created_at", hd.created_at
                        )
                    )
                    FROM HopDong hd
                    JOIN ChiTietHopDong ct ON hd.id = ct.idHopDong
                    JOIN insurance_types it ON hd.idLoaiBaoHiem = it.id
                    WHERE 1=1 ', v_where_clause, '
                    GROUP BY hd.id
                    ORDER BY hd.created_at DESC
                    LIMIT ', p_page_size, ' OFFSET ', v_offset, '),
                JSON_ARRAY()
                )
            ) AS result
    ');
    
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 2: STORED PROCEDURES CHO CÁC ENDPOINTS PHỔ BIẾN
-- ============================================================================

-- API endpoint để lấy tổng quan thông tin dashboard
DELIMITER //
CREATE PROCEDURE get_dashboard_json(IN p_user_id INT)
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_insurance_type_id INT;
    DECLARE v_total_contracts INT;
    DECLARE v_active_contracts INT;
    DECLARE v_expired_contracts INT;
    DECLARE v_processing_contracts INT;
    DECLARE v_this_month_payments DECIMAL(12, 2);
    DECLARE v_pending_payments INT;
    
    -- Lấy vai trò và loại bảo hiểm của người dùng
    SELECT vaitro, idLoaiBaoHiem INTO v_role, v_insurance_type_id FROM NguoiDung WHERE id = p_user_id;
    
    -- Dữ liệu dashboard tùy theo vai trò
    CASE v_role
        -- Người tạo hợp đồng
        WHEN 'contract_creator' THEN
            -- Tổng số hợp đồng
            SELECT COUNT(*) INTO v_total_contracts
            FROM HopDong WHERE creator_id = p_user_id;
            
            -- Số hợp đồng đang hoạt động
            SELECT COUNT(*) INTO v_active_contracts
            FROM HopDong WHERE creator_id = p_user_id AND TrangThai = 'active';
            
            -- Số hợp đồng đã hết hạn
            SELECT COUNT(*) INTO v_expired_contracts
            FROM HopDong WHERE creator_id = p_user_id AND TrangThai = 'expired';
            
            -- Số hợp đồng đang xử lý
            SELECT COUNT(*) INTO v_processing_contracts
            FROM HopDong WHERE creator_id = p_user_id AND TrangThai = 'processing';
            
            -- Số tiền đã thu tháng này
            SELECT IFNULL(SUM(soTienDong), 0) INTO v_this_month_payments
            FROM ThanhToan tt
            JOIN HopDong hd ON tt.idHopDong = hd.id
            WHERE hd.creator_id = p_user_id 
              AND tt.TrangThai = 'completed'
              AND YEAR(tt.ngayDongBaoHiem) = YEAR(CURRENT_DATE())
              AND MONTH(tt.ngayDongBaoHiem) = MONTH(CURRENT_DATE());
            
            -- Số kỳ thanh toán đang chờ xử lý
            SELECT COUNT(*) INTO v_pending_payments
            FROM ThanhToan tt
            JOIN HopDong hd ON tt.idHopDong = hd.id
            WHERE hd.creator_id = p_user_id AND tt.TrangThai = 'pending';
            
        -- Kế toán
        WHEN 'accounting' THEN
            -- Tổng số hợp đồng
            SELECT COUNT(*) INTO v_total_contracts
            FROM HopDong WHERE idLoaiBaoHiem = v_insurance_type_id;
            
            -- Số hợp đồng đang hoạt động
            SELECT COUNT(*) INTO v_active_contracts
            FROM HopDong WHERE idLoaiBaoHiem = v_insurance_type_id AND TrangThai = 'active';
            
            -- Số hợp đồng đã hết hạn
            SELECT COUNT(*) INTO v_expired_contracts
            FROM HopDong WHERE idLoaiBaoHiem = v_insurance_type_id AND TrangThai = 'expired';
            
            -- Số hợp đồng đang xử lý
            SELECT COUNT(*) INTO v_processing_contracts
            FROM HopDong WHERE idLoaiBaoHiem = v_insurance_type_id AND TrangThai = 'processing';
            
            -- Số tiền đã thu tháng này
            SELECT IFNULL(SUM(soTienDong), 0) INTO v_this_month_payments
            FROM ThanhToan tt
            JOIN HopDong hd ON tt.idHopDong = hd.id
            WHERE hd.idLoaiBaoHiem = v_insurance_type_id 
              AND tt.TrangThai = 'completed'
              AND YEAR(tt.ngayDongBaoHiem) = YEAR(CURRENT_DATE())
              AND MONTH(tt.ngayDongBaoHiem) = MONTH(CURRENT_DATE());
            
            -- Số kỳ thanh toán đang chờ xử lý
            SELECT COUNT(*) INTO v_pending_payments
            FROM ThanhToan tt
            JOIN HopDong hd ON tt.idHopDong = hd.id
            WHERE hd.idLoaiBaoHiem = v_insurance_type_id AND tt.TrangThai = 'pending';
            
        -- Giám sát
        WHEN 'supervisor' THEN
            -- Tổng số hợp đồng
            SELECT COUNT(*) INTO v_total_contracts
            FROM HopDong WHERE idLoaiBaoHiem = v_insurance_type_id;
            
            -- Số hợp đồng đang hoạt động
            SELECT COUNT(*) INTO v_active_contracts
            FROM HopDong WHERE idLoaiBaoHiem = v_insurance_type_id AND TrangThai = 'active';
            
            -- Số hợp đồng đã hết hạn
            SELECT COUNT(*) INTO v_expired_contracts
            FROM HopDong WHERE idLoaiBaoHiem = v_insurance_type_id AND TrangThai = 'expired';
            
            -- Số hợp đồng đang xử lý
            SELECT COUNT(*) INTO v_processing_contracts
            FROM HopDong WHERE idLoaiBaoHiem = v_insurance_type_id AND TrangThai = 'processing';
            
            -- Số tiền đã thu tháng này
            SELECT IFNULL(SUM(soTienDong), 0) INTO v_this_month_payments
            FROM ThanhToan tt
            JOIN HopDong hd ON tt.idHopDong = hd.id
            WHERE hd.idLoaiBaoHiem = v_insurance_type_id 
              AND tt.TrangThai = 'completed'
              AND YEAR(tt.ngayDongBaoHiem) = YEAR(CURRENT_DATE())
              AND MONTH(tt.ngayDongBaoHiem) = MONTH(CURRENT_DATE());
            
            -- Số kỳ thanh toán đang chờ xử lý
            SELECT COUNT(*) INTO v_pending_payments
            FROM ThanhToan tt
            JOIN HopDong hd ON tt.idHopDong = hd.id
            WHERE hd.idLoaiBaoHiem = v_insurance_type_id AND tt.TrangThai = 'pending';
            
        -- Người được bảo hiểm
        WHEN 'insured_person' THEN
            -- Tổng số hợp đồng
            SELECT COUNT(*) INTO v_total_contracts
            FROM HopDong WHERE idNguoiBH = p_user_id;
            
            -- Số hợp đồng đang hoạt động
            SELECT COUNT(*) INTO v_active_contracts
            FROM HopDong WHERE idNguoiBH = p_user_id AND TrangThai = 'active';
            
            -- Số hợp đồng đã hết hạn
            SELECT COUNT(*) INTO v_expired_contracts
            FROM HopDong WHERE idNguoiBH = p_user_id AND TrangThai = 'expired';
            
            -- Số hợp đồng đang xử lý
            SELECT COUNT(*) INTO v_processing_contracts
            FROM HopDong WHERE idNguoiBH = p_user_id AND TrangThai = 'processing';
            
            -- Số tiền đã đóng tháng này
            SELECT IFNULL(SUM(soTienDong), 0) INTO v_this_month_payments
            FROM ThanhToan tt
            JOIN HopDong hd ON tt.idHopDong = hd.id
            WHERE hd.idNguoiBH = p_user_id 
              AND tt.TrangThai = 'completed'
              AND YEAR(tt.ngayDongBaoHiem) = YEAR(CURRENT_DATE())
              AND MONTH(tt.ngayDongBaoHiem) = MONTH(CURRENT_DATE());
            
            -- Số kỳ thanh toán đang chờ xử lý
            SELECT COUNT(*) INTO v_pending_payments
            FROM ThanhToan tt
            JOIN HopDong hd ON tt.idHopDong = hd.id
            WHERE hd.idNguoiBH = p_user_id AND tt.TrangThai = 'pending';
    END CASE;
    
    -- Trả về kết quả JSON
    SELECT JSON_OBJECT(
        'role', v_role,
        'statistics', JSON_OBJECT(
            'total_contracts', v_total_contracts,
            'active_contracts', v_active_contracts,
            'expired_contracts', v_expired_contracts,
            'processing_contracts', v_processing_contracts,
            'this_month_payments', v_this_month_payments,
            'pending_payments', v_pending_payments
        )
    ) AS result;
END //
DELIMITER ;

-- API endpoint để lấy lịch sử thanh toán của hợp đồng
DELIMITER //
CREATE PROCEDURE get_payment_history_json(
    IN p_user_id INT, 
    IN p_contract_id INT
)
BEGIN
    DECLARE v_can_access BOOLEAN;
    
    -- Kiểm tra quyền truy cập
    SELECT can_access_contract(p_user_id, p_contract_id) INTO v_can_access;
    
    IF v_can_access THEN
        SELECT JSON_OBJECT(
            'access_granted', TRUE,
            'payments', IFNULL(
                (SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'id', tt.id,
                        'payment_date', tt.ngayDongBaoHiem, 
                        'amount', tt.soTienDong,
                        'status', tt.TrangThai,
                        'created_at', tt.created_at
                    )
                ) 
                FROM ThanhToan tt 
                WHERE tt.idHopDong = p_contract_id 
                ORDER BY tt.ngayDongBaoHiem DESC),
                JSON_ARRAY()
            )
        ) AS result;
    ELSE
        SELECT JSON_OBJECT(
            'access_granted', FALSE,
            'message', 'Không có quyền truy cập lịch sử thanh toán của hợp đồng này'
        ) AS result;
    END IF;
END //
DELIMITER ;

-- API endpoint để lấy thông tin chi tiết người dùng
DELIMITER //
CREATE PROCEDURE get_user_details_json(IN p_user_id INT)
BEGIN
    SELECT JSON_OBJECT(
        'id', u.id,
        'username', u.username,
        'email', u.email,
        'role', u.vaitro,
        'status', u.TrangThai,
        'created_at', u.created_at,
        'activated', u.activated,
        'insurance_type', CASE WHEN u.idLoaiBaoHiem IS NOT NULL THEN
            JSON_OBJECT(
                'id', it.id,
                'name', it.tenBH,
                'description', it.motaHD
            )
            ELSE NULL
        END
    ) AS result
    FROM NguoiDung u
    LEFT JOIN insurance_types it ON u.idLoaiBaoHiem = it.id
    WHERE u.id = p_user_id;
END //
DELIMITER ;

-- API endpoint để lấy báo cáo thống kê theo thời gian
DELIMITER //
CREATE PROCEDURE get_time_statistics_json(
    IN p_user_id INT,
    IN p_period VARCHAR(20), -- 'day', 'week', 'month', 'year'
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_insurance_type_id INT;
    DECLARE v_where_clause TEXT;
    DECLARE v_group_by TEXT;
    
    -- Lấy vai trò và loại bảo hiểm của người dùng
    SELECT vaitro, idLoaiBaoHiem INTO v_role, v_insurance_type_id FROM NguoiDung WHERE id = p_user_id;
    
    -- Xây dựng điều kiện WHERE dựa trên vai trò
    CASE v_role
        WHEN 'contract_creator' THEN
            SET v_where_clause = CONCAT(' AND hd.creator_id = ', p_user_id);
        WHEN 'insured_person' THEN
            SET v_where_clause = CONCAT(' AND hd.idNguoiBH = ', p_user_id);
        WHEN 'accounting' THEN
            SET v_where_clause = CONCAT(' AND hd.idLoaiBaoHiem = ', v_insurance_type_id);
        WHEN 'supervisor' THEN
            SET v_where_clause = CONCAT(' AND hd.idLoaiBaoHiem = ', v_insurance_type_id);
        ELSE
            SET v_where_clause = '';
    END CASE;
    
    -- Thêm điều kiện khoảng thời gian
    IF p_start_date IS NOT NULL THEN
        SET v_where_clause = CONCAT(v_where_clause, " AND tt.ngayDongBaoHiem >= '", p_start_date, "'");
    END IF;
    
    IF p_end_date IS NOT NULL THEN
        SET v_where_clause = CONCAT(v_where_clause, " AND tt.ngayDongBaoHiem <= '", p_end_date, "'");
    END IF;
    
    -- Xây dựng mệnh đề GROUP BY dựa trên period
    CASE p_period
        WHEN 'day' THEN
            SET v_group_by = 'DATE(tt.ngayDongBaoHiem)';
        WHEN 'week' THEN
            SET v_group_by = 'YEARWEEK(tt.ngayDongBaoHiem, 1)';
        WHEN 'month' THEN
            SET v_group_by = 'DATE_FORMAT(tt.ngayDongBaoHiem, "%Y-%m")';
        WHEN 'year' THEN
            SET v_group_by = 'YEAR(tt.ngayDongBaoHiem)';
        ELSE
            SET v_group_by = 'DATE(tt.ngayDongBaoHiem)';
    END CASE;
    
    -- Thống kê doanh thu theo thời gian
    SET @sql = CONCAT('
        SELECT JSON_OBJECT(
            "statistics", (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "period", period_label,
                        "completed_amount", completed_amount,
                        "pending_amount", pending_amount,
                        "failed_amount", failed_amount
                    )
                )
                FROM (
                    SELECT 
                        CASE "', p_period, '"
                            WHEN "day" THEN DATE_FORMAT(tt.ngayDongBaoHiem, "%Y-%m-%d")
                            WHEN "week" THEN CONCAT(
                                YEAR(tt.ngayDongBaoHiem), "-W", 
                                LPAD(WEEK(tt.ngayDongBaoHiem, 1), 2, "0")
                            )
                            WHEN "month" THEN DATE_FORMAT(tt.ngayDongBaoHiem, "%Y-%m")
                            WHEN "year" THEN YEAR(tt.ngayDongBaoHiem)
                        END AS period_label,
                        SUM(CASE WHEN tt.TrangThai = "completed" THEN tt.soTienDong ELSE 0 END) AS completed_amount,
                        SUM(CASE WHEN tt.TrangThai = "pending" THEN tt.soTienDong ELSE 0 END) AS pending_amount,
                        SUM(CASE WHEN tt.TrangThai = "failed" THEN tt.soTienDong ELSE 0 END) AS failed_amount
                    FROM ThanhToan tt
                    JOIN HopDong hd ON tt.idHopDong = hd.id
                    WHERE 1=1 ', v_where_clause, '
                    GROUP BY ', v_group_by, '
                    ORDER BY MIN(tt.ngayDongBaoHiem)
                ) AS time_stats
            )
        ) AS result'
    );
    
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //
DELIMITER ;

-- Kiểm tra quyền cần thiết và đã đăng nhập
DELIMITER //
CREATE PROCEDURE check_permission_json(
    IN p_session_id VARCHAR(255), 
    IN p_required_role VARCHAR(50)
)
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_is_active BOOLEAN;
    DECLARE v_user_role VARCHAR(50);
    
    -- Kiểm tra phiên đăng nhập
    SELECT user_id, is_active INTO v_user_id, v_is_active
    FROM phienlamviec 
    WHERE session_id = p_session_id;
    
    -- Nếu phiên hợp lệ, kiểm tra quyền
    IF v_user_id IS NOT NULL AND v_is_active = TRUE THEN
        -- Lấy vai trò của người dùng
        SELECT vaitro INTO v_user_role
        FROM NguoiDung
        WHERE id = v_user_id;
        
        -- Kiểm tra quyền
        IF v_user_role = p_required_role THEN
            SELECT JSON_OBJECT(
                'has_permission', TRUE,
                'user_id', v_user_id,
                'role', v_user_role
            ) AS result;
        ELSE
            SELECT JSON_OBJECT(
                'has_permission', FALSE,
                'message', 'Không có quyền thực hiện hành động này',
                'user_id', v_user_id,
                'role', v_user_role,
                'required_role', p_required_role
            ) AS result;
        END IF;
    ELSE
        SELECT JSON_OBJECT(
            'has_permission', FALSE,
            'message', 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn'
        ) AS result;
    END IF;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 3: STORED PROCEDURES TRIỂN KHAI RESTFUL API TRÊN FASTAPI
-- ============================================================================

/*
Hướng dẫn sử dụng các stored procedures này trong FastAPI:

1. Thiết lập kết nối database:
```python
import pymysql
from fastapi import Depends, FastAPI, HTTPException
from fastapi.security import OAuth2PasswordBearer
import json
import uuid
from typing import Optional, List
from pydantic import BaseModel
from datetime import datetime, timedelta

# Thiết lập kết nối MySQL
def get_db():
    connection = pymysql.connect(
        host='localhost',
        user='root',
        password='password',
        db='insurance_management',
        charset='utf8mb4',
        cursorclass=pymysql.cursors.DictCursor
    )
    try:
        yield connection
    finally:
        connection.close()
```

2. Xác thực phiên làm việc:
```python
# Tạo các model Pydantic
class LoginRequest(BaseModel):
    username: str
    password: str
    client_ip: Optional[str] = None

class Token(BaseModel):
    access_token: str
    token_type: str

class UserInDB(BaseModel):
    id: int
    role: str
    insurance_type: Optional[int] = None
    session_id: str

# OAuth2 scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Đăng nhập
@app.post("/login", response_model=Token)
async def login(request: LoginRequest, db: pymysql.Connection = Depends(get_db)):
    # Tạo session_id
    session_id = str(uuid.uuid4())
    
    # Thực thi stored procedure đăng nhập
    with db.cursor() as cursor:
        cursor.execute(
            "CALL fastapi_login(%s, %s, %s, %s)", 
            (request.username, request.password, session_id, request.client_ip or "unknown")
        )
        result = cursor.fetchone()
    
    db.commit()
    login_result = json.loads(result["result"])
    
    if login_result["success"]:
        # Tạo JWT token hoặc cookie chứa session_id
        access_token = create_access_token(data={"session_id": session_id})
        return {"access_token": access_token, "token_type": "bearer"}
    else:
        raise HTTPException(status_code=401, detail="Invalid credentials")

# Lấy thông tin người dùng hiện tại
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: pymysql.Connection = Depends(get_db)
):
    credentials_exception = HTTPException(
        status_code=401,
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
```

3. Sử dụng stored procedures để xây dựng API endpoint:
```python
# Lấy danh sách hợp đồng
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
            (current_user.id, search, status, insurance_type, 
             start_date, end_date, page, page_size)
        )
        result = cursor.fetchone()
    
    return json.loads(result["result"])

# Lấy chi tiết hợp đồng
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
        raise HTTPException(status_code=403, detail="Access denied")
    
    return detail

# Lấy tổng quan dashboard
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
```

4. Đảm bảo có đầy đủ endpoint cho tất cả các tính năng cần thiết:
   - Quản lý người dùng (đăng ký, đăng nhập, đăng xuất, quản lý thông tin cá nhân)
   - Quản lý hợp đồng (tạo mới, xem chi tiết, cập nhật, thay đổi trạng thái)
   - Quản lý thanh toán (thêm kỳ thanh toán, xem lịch sử, cập nhật trạng thái)
   - Dashboard và báo cáo thống kê
*/
