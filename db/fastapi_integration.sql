-- ============================================================================
-- PHẦN 1: TÍCH HỢP VỚI FASTAPI
-- ============================================================================
USE insurance_management;

-- Đảm bảo rằng các stored procedure quản lý phiên đã được tạo từ phien.sql
-- File này cung cấp các hàm hỗ trợ tích hợp với FastAPI

-- ============================================================================
-- PHẦN 1.1: STORED PROCEDURE TRẢ VỀ KẾT QUẢ JSON
-- ============================================================================

-- Thủ tục đăng nhập và bắt đầu phiên làm việc cho FastAPI
DELIMITER //
CREATE PROCEDURE fastapi_login(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255),
    IN p_session_id VARCHAR(255),
    IN p_ip_address VARCHAR(45)
)
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_user_role VARCHAR(50);
    DECLARE v_login_success BOOLEAN;
    
    -- Kiểm tra thông tin đăng nhập
    SELECT id, vaitro INTO v_user_id, v_user_role
    FROM NguoiDung
    WHERE username = p_username AND pass = SHA2(p_password, 256) AND TrangThai = 'active';
    
    -- Đặt biến thành công
    SET v_login_success = (v_user_id IS NOT NULL);
    
    -- Nếu đăng nhập thành công, bắt đầu phiên
    IF v_login_success THEN
        -- Xóa phiên cũ của người dùng nếu có
        UPDATE phienlamviec SET is_active = FALSE WHERE user_id = v_user_id AND is_active = TRUE;
        
        -- Tạo phiên mới
        CALL start_user_session(v_user_id, p_session_id, p_ip_address);
    END IF;
    
    -- Trả về kết quả dạng JSON
    SELECT JSON_OBJECT(
        'success', v_login_success,
        'user_id', v_user_id,
        'role', v_user_role,
        'session_id', IF(v_login_success, p_session_id, NULL)
    ) AS result;
END //
DELIMITER ;

-- Thủ tục xác thực phiên làm việc cho FastAPI
DELIMITER //
CREATE PROCEDURE fastapi_validate_session(
    IN p_session_id VARCHAR(255)
)
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_is_active BOOLEAN;
    DECLARE v_user_role VARCHAR(50);
    DECLARE v_insurance_type INT;
    
    -- Kiểm tra phiên hợp lệ
    SELECT p.user_id, p.is_active INTO v_user_id, v_is_active
    FROM phienlamviec p
    WHERE p.session_id = p_session_id;
    
    -- Nếu phiên hợp lệ, lấy thêm thông tin người dùng
    IF v_user_id IS NOT NULL AND v_is_active = TRUE THEN
        SELECT vaitro, idLoaiBaoHiem INTO v_user_role, v_insurance_type
        FROM NguoiDung
        WHERE id = v_user_id;
        
        -- Thiết lập biến phiên
        SET @current_user_id = v_user_id;
        SET @session_id = p_session_id;
        
        -- Thiết lập khóa mã hóa
        CALL check_and_call_encryption_key();
        
        -- Cập nhật thời gian hoạt động
        UPDATE phienlamviec 
        SET last_activity = CURRENT_TIMESTAMP 
        WHERE session_id = p_session_id;
    ELSE
        SET @current_user_id = NULL;
        SET @session_id = NULL;
    END IF;
    
    -- Trả về kết quả dạng JSON
    SELECT JSON_OBJECT(
        'valid', (v_user_id IS NOT NULL AND v_is_active = TRUE),
        'user_id', v_user_id,
        'role', v_user_role,
        'insurance_type', v_insurance_type
    ) AS result;
END //
DELIMITER ;

-- Thủ tục đăng xuất và kết thúc phiên làm việc
DELIMITER //
CREATE PROCEDURE fastapi_logout(
    IN p_session_id VARCHAR(255)
)
BEGIN
    DECLARE v_success BOOLEAN;
    
    -- Kiểm tra phiên tồn tại
    SET v_success = EXISTS(SELECT 1 FROM phienlamviec WHERE session_id = p_session_id AND is_active = TRUE);
    
    -- Kết thúc phiên
    IF v_success THEN
        CALL end_user_session(p_session_id);
    END IF;
    
    -- Trả về kết quả dạng JSON
    SELECT JSON_OBJECT(
        'success', v_success
    ) AS result;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 1.2: STORED PROCEDURE HỖ TRỢ PHÂN TRANG
-- ============================================================================

-- Lấy hợp đồng với phân trang theo vai trò của người dùng
-- Sửa stored procedure get_contracts_with_pagination
DELIMITER //
CREATE PROCEDURE get_contracts_with_pagination(
    IN p_user_id INT,
    IN p_page INT,
    IN p_page_size INT,
    IN p_filter VARCHAR(100),
    IN p_sort_by VARCHAR(50),
    IN p_sort_dir VARCHAR(4)
)
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_insurance_type INT;
    DECLARE v_offset INT;
    DECLARE v_limit INT;
    DECLARE v_filter_condition TEXT;
    DECLARE v_sort_clause TEXT;
    DECLARE v_total_count INT;
    DECLARE v_query TEXT;
    
    -- Xác định vai trò và loại bảo hiểm của người dùng
    SELECT vaitro, idLoaiBaoHiem INTO v_role, v_insurance_type 
    FROM NguoiDung 
    WHERE id = p_user_id;
    
    -- Tính toán phân trang
    SET v_limit = p_page_size;
    SET v_offset = p_page * p_page_size;
    
    -- Xây dựng điều kiện filter
    IF p_filter IS NOT NULL AND p_filter != '' THEN
        SET v_filter_condition = CONCAT(" AND (hd.id LIKE '%", p_filter, "%' OR ct.HoTen LIKE '%", p_filter, "%')");
    ELSE
        SET v_filter_condition = '';
    END IF;
    
    -- Xây dựng điều kiện sắp xếp
    IF p_sort_by IS NOT NULL AND p_sort_by != '' THEN
        SET v_sort_clause = CONCAT(p_sort_by, ' ', IF(p_sort_dir = 'DESC', 'DESC', 'ASC'));
    ELSE
        SET v_sort_clause = 'hd.created_at DESC';
    END IF;
    
    -- Xây dựng câu truy vấn dựa trên vai trò
    SET v_query = CONCAT('
        SELECT hd.id, hd.idLoaiBaoHiem, hd.ngayKiHD, hd.ngayCatHD, hd.TrangThai,
               ct.HoTen, ct.sodienthoai
        FROM HopDong hd
        JOIN ChiTietHopDong ct ON hd.id = ct.idHopDong
        WHERE 1=1 ',
        CASE 
            WHEN v_role = 'contract_creator' THEN ' AND hd.creator_id = ' 
            WHEN v_role = 'insured_person' THEN ' AND hd.idNguoiBH = '
            WHEN v_role = 'accounting' OR v_role = 'supervisor' THEN ' AND hd.idLoaiBaoHiem = ' 
            ELSE ' AND FALSE' -- Nếu không phải vai trò hợp lệ, không trả về kết quả
        END,
        CASE
            WHEN v_role IN ('contract_creator', 'insured_person') THEN p_user_id
            WHEN v_role IN ('accounting', 'supervisor') THEN v_insurance_type
            ELSE '0'
        END,        v_filter_condition,
        ' ORDER BY ', v_sort_clause,
        ' LIMIT ', v_limit,
        ' OFFSET ', v_offset
    );
    
    -- Thực thi truy vấn
    SET @stmt = v_query;
    PREPARE stmt FROM @stmt;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 1.3: STORED PROCEDURE TÌM KIẾM VÀ LỌC DỮ LIỆU
-- ============================================================================

-- Tìm kiếm người dùng
DELIMITER //
CREATE PROCEDURE search_users(
    IN p_search_term VARCHAR(100),
    IN p_role VARCHAR(50),
    IN p_status VARCHAR(20),
    IN p_page INT,
    IN p_page_size INT
)
BEGIN
    DECLARE v_offset INT;
    DECLARE v_filter_condition TEXT DEFAULT '';
    
    -- Tính toán phân trang
    SET v_offset = p_page * p_page_size;
    
    -- Xây dựng điều kiện tìm kiếm
    IF p_search_term IS NOT NULL AND p_search_term != '' THEN
        SET v_filter_condition = CONCAT(v_filter_condition, 
            " AND (username LIKE '%", p_search_term, "%' OR email LIKE '%", p_search_term, "%')");
    END IF;
    
    -- Lọc theo vai trò
    IF p_role IS NOT NULL AND p_role != '' THEN
        SET v_filter_condition = CONCAT(v_filter_condition, 
            " AND vaitro = '", p_role, "'");
    END IF;
    
    -- Lọc theo trạng thái
    IF p_status IS NOT NULL AND p_status != '' THEN
        SET v_filter_condition = CONCAT(v_filter_condition, 
            " AND TrangThai = '", p_status, "'");
    END IF;
    
    -- Đếm tổng số bản ghi
    SET @sql = CONCAT("
        SELECT COUNT(*) INTO @total_count
        FROM NguoiDung
        WHERE 1=1", v_filter_condition);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    -- Lấy dữ liệu
    SET @sql = CONCAT("
        SELECT 
            JSON_OBJECT(
                'total_count', @total_count,
                'page', ", p_page, ",
                'page_size', ", p_page_size, ",
                'data', JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'id', id,
                        'username', username,
                        'email', email,
                        'role', vaitro,
                        'status', TrangThai,
                        'insurance_type', idLoaiBaoHiem,
                        'created_at', created_at
                    )
                )
            ) AS result
        FROM NguoiDung
        WHERE 1=1", v_filter_condition, "
        ORDER BY created_at DESC
        LIMIT ", p_page_size, " OFFSET ", v_offset);
    
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 2: TỐI ƯU HÓA TRUY VẤN CHO RESTFUL API
-- ============================================================================

-- Lấy chi tiết hợp đồng theo ID và quyền của người dùng
DELIMITER //
CREATE PROCEDURE get_contract_detail(
    IN p_user_id INT,
    IN p_contract_id INT
)
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_insurance_type INT;
    DECLARE v_can_access BOOLEAN;
    
    -- Xác định vai trò và loại bảo hiểm của người dùng
    SELECT vaitro, idLoaiBaoHiem INTO v_role, v_insurance_type 
    FROM NguoiDung 
    WHERE id = p_user_id;
    
    -- Kiểm tra quyền truy cập với hàm can_access_contract
    SELECT can_access_contract(p_user_id, p_contract_id) INTO v_can_access;
    
    -- Nếu có quyền truy cập, trả về chi tiết hợp đồng
    IF v_can_access THEN
        -- Mỗi vai trò sẽ thấy thông tin khác nhau
        CASE v_role
            -- Người tạo hợp đồng - Thấy đầy đủ thông tin
            WHEN 'contract_creator' THEN
                SELECT JSON_OBJECT(
                    'access_granted', TRUE,
                    'contract', JSON_OBJECT(
                        'id', hd.id,
                        'insurance_type', it.tenBH,
                        'creator_id', hd.creator_id,
                        'insured_id', hd.idNguoiBH,
                        'start_date', hd.ngayKiHD,
                        'end_date', hd.ngayCatHD,
                        'status', hd.TrangThai,
                        'insurance_value', hd.giaTriBaoHiem,
                        'created_at', hd.created_at,
                        'detail', JSON_OBJECT(
                            'name', decrypt_data(ct.HoTen),
                            'gender', ct.gioiTinh,
                            'birth_date', ct.ngaySinh,
                            'workplace', decrypt_data(ct.diachiCoQuan),
                            'permanent_address', decrypt_data(ct.diachiThuongTru),
                            'temporary_address', decrypt_data(ct.diachiTamTru),
                            'contact_address', decrypt_data(ct.diachiLienLac),
                            'phone', decrypt_data(ct.sodienthoai),
                            'medical_history', decrypt_data(ct.lichsuBenh)
                        ),
                        'payments', (
                            SELECT JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    'id', tt.id,
                                    'payment_date', tt.ngayDongBaoHiem, 
                                    'amount', tt.soTienDong,
                                    'status', tt.TrangThai
                                )
                            )
                            FROM ThanhToan tt
                            WHERE tt.idHopDong = hd.id
                        )
                    )
                ) AS result
                FROM HopDong hd
                JOIN ChiTietHopDong ct ON hd.id = ct.idHopDong
                JOIN insurance_types it ON hd.idLoaiBaoHiem = it.id
                LEFT JOIN ThanhToan tt ON hd.id = tt.idHopDong
                WHERE hd.id = p_contract_id
                GROUP BY hd.id;
                
            -- Người được bảo hiểm - Chỉ thấy thông tin của mình
            WHEN 'insured_person' THEN
                SELECT JSON_OBJECT(
                    'access_granted', TRUE,
                    'contract', JSON_OBJECT(
                        'id', hd.id,
                        'insurance_type', it.tenBH,
                        'insurance_desc', it.motaHD,
                        'start_date', hd.ngayKiHD,
                        'end_date', hd.ngayCatHD,
                        'status', hd.TrangThai,
                        'insurance_value', hd.giaTriBaoHiem,
                        'detail', JSON_OBJECT(
                            'name', decrypt_data(ct.HoTen),
                            'gender', ct.gioiTinh,
                            'birth_date', ct.ngaySinh,
                            'workplace', decrypt_data(ct.diachiCoQuan),
                            'permanent_address', decrypt_data(ct.diachiThuongTru),
                            'temporary_address', decrypt_data(ct.diachiTamTru),
                            'contact_address', decrypt_data(ct.diachiLienLac),
                            'phone', decrypt_data(ct.sodienthoai),
                            'medical_history', decrypt_data(ct.lichsuBenh)
                        ),
                        'payments', (
                            SELECT JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    'payment_date', tt.ngayDongBaoHiem, 
                                    'amount', tt.soTienDong,
                                    'status', tt.TrangThai
                                )
                            )
                            FROM ThanhToan tt
                            WHERE tt.idHopDong = hd.id
                        )
                    )
                ) AS result
                FROM HopDong hd
                JOIN ChiTietHopDong ct ON hd.id = ct.idHopDong
                JOIN insurance_types it ON hd.idLoaiBaoHiem = it.id
                LEFT JOIN ThanhToan tt ON hd.id = tt.idHopDong
                WHERE hd.id = p_contract_id
                GROUP BY hd.id;
                
            -- Kế toán - Chỉ thấy thông tin tài chính
            WHEN 'accounting' THEN
                SELECT JSON_OBJECT(
                    'access_granted', TRUE,
                    'contract', JSON_OBJECT(
                        'id', hd.id,
                        'insurance_type', it.tenBH,
                        'creator', creator.username,
                        'insured_name', decrypt_data(ct.HoTen),
                        'status', hd.TrangThai,
                        'insurance_value', hd.giaTriBaoHiem,
                        'start_date', hd.ngayKiHD,
                        'end_date', hd.ngayCatHD,
                        'payments', (
                            SELECT JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    'id', tt.id,
                                    'payment_date', tt.ngayDongBaoHiem, 
                                    'amount', tt.soTienDong,
                                    'status', tt.TrangThai
                                )
                            )
                            FROM ThanhToan tt
                            WHERE tt.idHopDong = hd.id
                        )
                    )
                ) AS result
                FROM HopDong hd
                JOIN ChiTietHopDong ct ON hd.id = ct.idHopDong
                JOIN insurance_types it ON hd.idLoaiBaoHiem = it.id
                JOIN NguoiDung creator ON hd.creator_id = creator.id
                WHERE hd.id = p_contract_id
                GROUP BY hd.id;
                
            -- Giám sát - Thấy đầy đủ thông tin nhưng không có quyền sửa
            WHEN 'supervisor' THEN
                SELECT JSON_OBJECT(
                    'access_granted', TRUE,
                    'contract', JSON_OBJECT(
                        'id', hd.id,
                        'insurance_type', it.tenBH,
                        'creator', creator.username,
                        'insured_name', decrypt_data(ct.HoTen),
                        'status', hd.TrangThai,
                        'insurance_value', hd.giaTriBaoHiem,
                        'start_date', hd.ngayKiHD,
                        'end_date', hd.ngayCatHD,
                        'detail', JSON_OBJECT(
                            'name', decrypt_data(ct.HoTen),
                            'gender', ct.gioiTinh,
                            'birth_date', ct.ngaySinh,
                            'workplace', decrypt_data(ct.diachiCoQuan),
                            'permanent_address', decrypt_data(ct.diachiThuongTru),
                            'temporary_address', decrypt_data(ct.diachiTamTru),
                            'contact_address', decrypt_data(ct.diachiLienLac),
                            'phone', decrypt_data(ct.sodienthoai),
                            'medical_history', decrypt_data(ct.lichsuBenh)
                        ),
                        'payments', (
                            SELECT JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    'payment_date', tt.ngayDongBaoHiem, 
                                    'amount', tt.soTienDong,
                                    'status', tt.TrangThai
                                )
                            )
                            FROM ThanhToan tt
                            WHERE tt.idHopDong = hd.id
                        )
                    )
                ) AS result
                FROM HopDong hd
                JOIN ChiTietHopDong ct ON hd.id = ct.idHopDong
                JOIN insurance_types it ON hd.idLoaiBaoHiem = it.id
                JOIN NguoiDung creator ON hd.creator_id = creator.id
                WHERE hd.id = p_contract_id
                GROUP BY hd.id;
        END CASE;
    ELSE
        -- Không có quyền truy cập
        SELECT JSON_OBJECT(
            'access_granted', FALSE,
            'message', 'Bạn không có quyền truy cập hợp đồng này'
        ) AS result;
    END IF;
END //
DELIMITER ;

-- ============================================================================
-- HƯỚNG DẪN SỬ DỤNG PHIÊN NGƯỜI DÙNG TRONG FASTAPI
-- ============================================================================

/*
Khi tích hợp với FastAPI, bạn cần:

# Đảm bảo thứ tự khởi tạo:
# 1. Đảm bảo tất cả các file SQL đã được thực thi theo thứ tự:
#    db.sql → baomat.sql → mahoa.sql → phien.sql → fastapi_integration.sql

1. Quản lý phiên làm việc với FastAPI:

   a. Đăng nhập và tạo phiên:
      ```python
      @app.post("/login")
      async def login(request: LoginRequest, db: MySQLConnection = Depends(get_db)):
          # Tạo session_id (có thể dùng JWT hoặc UUID)
          session_id = str(uuid.uuid4())
          
          # Thực thi stored procedure đăng nhập
          cursor = db.cursor(dictionary=True)
          cursor.execute(
              "CALL fastapi_login(%s, %s, %s, %s)", 
              (request.username, request.password, session_id, request.client_ip)
          )
          result = cursor.fetchone()
          cursor.close()
          
          # Xử lý kết quả
          login_result = json.loads(result["result"])
          if login_result["success"]:
              # Tạo JWT token hoặc cookie chứa session_id
              access_token = create_access_token(data={"session_id": session_id})
              return {"access_token": access_token, "token_type": "bearer"}
          else:
              raise HTTPException(status_code=401, detail="Invalid credentials")
      ```

   b. Kiểm tra phiên trước mỗi request:
      ```python
      async def get_current_user(
          token: str = Depends(oauth2_scheme),
          db: MySQLConnection = Depends(get_db)
      ):
          try:
              # Giải mã JWT để lấy session_id
              payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
              session_id = payload.get("session_id")
              if session_id is None:
                  raise credentials_exception
              
              # Xác thực phiên với database
              cursor = db.cursor(dictionary=True)
              cursor.execute("CALL fastapi_validate_session(%s)", (session_id,))
              result = cursor.fetchone()
              cursor.close()
              
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

   c. Đăng xuất và kết thúc phiên:
      ```python
      @app.post("/logout")
      async def logout(
          current_user: UserInDB = Depends(get_current_user),
          db: MySQLConnection = Depends(get_db)
      ):
          cursor = db.cursor(dictionary=True)
          cursor.execute("CALL fastapi_logout(%s)", (current_user.session_id,))
          result = cursor.fetchone()
          cursor.close()
          
          logout_result = json.loads(result["result"])
          return {"success": logout_result["success"]}
      ```

2. Đảm bảo bảo mật phiên làm việc:
   - Sử dụng HTTPS để bảo vệ truyền tải token
   - Thiết lập thời gian hết hạn cho JWT tokens
   - Thực hiện xác thực phiên trước mỗi request API
   - Lưu trữ tokens an toàn ở phía client (httpOnly cookies hoặc secure storage)

3. Dọn dẹp phiên cũ:
   - Tạo một cronjob hoặc background task để gọi định kỳ:
   ```python
   @app.on.event("startup")
   async def setup_cleanup_task():
       scheduler = AsyncIOScheduler()
       scheduler.add_job(cleanup_old_sessions, "interval", hours=1)
       scheduler.start()

   async def cleanup_old_sessions():
       db = get_db_connection()
       cursor = db.cursor()
       cursor.execute("CALL cleanup_old_sessions(24)")  # Dọn phiên > 24 giờ
       cursor.close()
       db.close()
   ```
*/
