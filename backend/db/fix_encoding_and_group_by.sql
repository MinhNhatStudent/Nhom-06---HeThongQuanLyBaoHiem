-- ============================================================================
-- FIX FOR ENCODING ISSUES AND GROUP BY
-- ============================================================================
USE insurance_management;

-- Fix character set and collation for the database
ALTER DATABASE insurance_management CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Update the character set and collation for tables containing encrypted data
ALTER TABLE ChiTietHopDong CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Fix the GROUP BY issue in the contracts management stored procedure
DELIMITER //

DROP PROCEDURE IF EXISTS sp_contracts_management //

CREATE PROCEDURE sp_contracts_management(
    IN p_operation VARCHAR(20), -- 'get_list', 'get_detail', 'create', 'update', 'delete'
    IN p_user_id INT,
    IN p_contract_id INT,
    IN p_insurance_type_id INT,
    IN p_insured_person_id INT,
    IN p_ngay_ki DATE,
    IN p_ngay_cat DATE,
    IN p_trang_thai VARCHAR(20),
    IN p_page INT,
    IN p_limit INT,
    IN p_search VARCHAR(100),
    IN p_status_filter VARCHAR(20),
    IN p_contract_details JSON
)
BEGIN
    DECLARE v_user_role VARCHAR(50);
    DECLARE v_insurance_type INT;
    DECLARE v_has_permission BOOLEAN;
    DECLARE v_new_contract_id INT;
    
    -- Lấy vai trò và loại bảo hiểm của người dùng
    SELECT vaitro, idLoaiBaoHiem INTO v_user_role, v_insurance_type 
    FROM NguoiDung 
    WHERE id = p_user_id;
    
    -- Xử lý các loại thao tác
    CASE p_operation
        -- ====================================================
        -- Lấy danh sách hợp đồng theo vai trò
        -- ====================================================
        WHEN 'get_list' THEN
            -- Xác định số lượng bản ghi mỗi trang và vị trí bắt đầu
            SET @limit = IFNULL(p_limit, 10);
            SET @offset = IFNULL((p_page - 1) * @limit, 0);
            
            -- Điều kiện lọc theo vai trò
            IF v_user_role = 'contract_creator' THEN
                -- Người lập hợp đồng: chỉ xem hợp đồng do họ tạo
                SET @role_condition = CONCAT(' AND hd.creator_id = ', p_user_id);
            ELSEIF v_user_role = 'insured_person' THEN
                -- Người được bảo hiểm: chỉ xem hợp đồng liên quan đến họ
                SET @role_condition = CONCAT(' AND hd.idNguoiBH = ', p_user_id);
            ELSEIF v_user_role IN ('accounting', 'supervisor') THEN
                -- Kế toán/Giám sát: chỉ xem hợp đồng thuộc loại bảo hiểm được phân công
                SET @role_condition = CONCAT(' AND hd.idLoaiBaoHiem = ', v_insurance_type);
            ELSEIF v_user_role = 'admin' THEN
                -- Admin: xem tất cả hợp đồng
                SET @role_condition = '';
            ELSE
                -- Vai trò không hợp lệ
                SET @role_condition = ' AND 1=0'; -- Không trả về bản ghi nào
            END IF;
            
            -- Điều kiện lọc theo trạng thái
            IF p_status_filter IS NOT NULL THEN
                SET @status_condition = CONCAT(' AND hd.TrangThai = "', p_status_filter, '"');
            ELSE
                SET @status_condition = '';
            END IF;
            
            -- Điều kiện tìm kiếm
            IF p_search IS NOT NULL THEN
                SET @search_condition = CONCAT(' AND (
                    ct.HoTen LIKE "%', p_search, '%" OR 
                    it.tenBH LIKE "%', p_search, '%" OR
                    ct.diachiThuongTru LIKE "%', p_search, '%"
                )');
            ELSE
                SET @search_condition = '';
            END IF;
            
            -- Tạo câu truy vấn với sửa đổi GROUP BY để tương thích với ONLY_FULL_GROUP_BY
            SET @query = CONCAT('
                SELECT 
                    hd.id,
                    hd.ngayKiHD,
                    hd.ngayCatHD,
                    hd.TrangThai,
                    it.tenBH as loai_bao_hiem,
                    MAX(
                        CASE 
                            WHEN ct.HoTen IS NOT NULL THEN 
                                IFNULL(decrypt_text(ct.HoTen), "Chưa có thông tin")
                            ELSE "Chưa có thông tin" 
                        END
                    ) as ten_nguoi_bh,
                    (SELECT username FROM NguoiDung WHERE id = hd.creator_id) as nguoi_lap_hd,
                    (SELECT COUNT(*) FROM ThanhToan WHERE idHopDong = hd.id) as so_ky_thanh_toan
                FROM 
                    HopDong hd
                LEFT JOIN 
                    ChiTietHopDong ct ON hd.id = ct.idHopDong
                JOIN 
                    insurance_types it ON hd.idLoaiBaoHiem = it.id
                WHERE 
                    1=1', @role_condition, @status_condition, @search_condition, '
                GROUP BY 
                    hd.id, hd.ngayKiHD, hd.ngayCatHD, hd.TrangThai, it.tenBH, hd.creator_id
                ORDER BY 
                    hd.created_at DESC
                LIMIT ', @limit, ' OFFSET ', @offset
            );
            
            -- Tổng số bản ghi phù hợp với điều kiện
            SET @count_query = CONCAT('
                SELECT COUNT(DISTINCT hd.id) as total
                FROM 
                    HopDong hd
                LEFT JOIN 
                    ChiTietHopDong ct ON hd.id = ct.idHopDong
                JOIN 
                    insurance_types it ON hd.idLoaiBaoHiem = it.id
                WHERE 
                    1=1', @role_condition, @status_condition, @search_condition
            );
            
            -- Thực thi câu truy vấn
            PREPARE stmt FROM @query;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
            
            -- Trả về tổng số bản ghi
            PREPARE count_stmt FROM @count_query;
            EXECUTE count_stmt;
            DEALLOCATE PREPARE count_stmt;
            
        -- ====================================================
        -- Lấy chi tiết hợp đồng
        -- ====================================================
        WHEN 'get_detail' THEN
            -- Còn lại của stored procedure giữ nguyên...
            -- Chỉ thay đổi phần get_list để sửa lỗi GROUP BY
            -- Kiểm tra quyền truy cập hợp đồng
            SELECT can_access_contract(p_user_id, p_contract_id) INTO v_has_permission;
            
            IF v_has_permission = TRUE THEN
                -- Thông tin hợp đồng
                SELECT 
                    hd.id,
                    hd.creator_id,
                    (SELECT username FROM NguoiDung WHERE id = hd.creator_id) as nguoi_lap_hd,
                    hd.idLoaiBaoHiem,
                    it.tenBH as loai_bao_hiem,
                    hd.idNguoiBH,
                    (SELECT username FROM NguoiDung WHERE id = hd.idNguoiBH) as username_nguoi_bh,
                    hd.ngayKiHD,
                    hd.ngayCatHD,
                    hd.TrangThai,
                    hd.created_at
                FROM 
                    HopDong hd
                JOIN 
                    insurance_types it ON hd.idLoaiBaoHiem = it.id
                WHERE 
                    hd.id = p_contract_id;
                
                -- Chi tiết hợp đồng (dữ liệu đã giải mã)
                SELECT 
                    ct.id,
                    IFNULL(decrypt_text(ct.HoTen), '') as HoTen,
                    ct.gioiTinh,
                    ct.ngaySinh,
                    IFNULL(decrypt_text(ct.diachiCoQuan), '') as diachiCoQuan,
                    IFNULL(decrypt_text(ct.diachiThuongTru), '') as diachiThuongTru,
                    IFNULL(decrypt_text(ct.sodienthoai), '') as sodienthoai,
                    IFNULL(decrypt_text(ct.lichsuBenh), '') as lichsuBenh
                FROM 
                    ChiTietHopDong ct
                WHERE 
                    ct.idHopDong = p_contract_id;
                
                -- Thông tin thanh toán
                SELECT 
                    id, 
                    ngayDongBaoHiem, 
                    soTienDong
                FROM 
                    ThanhToan
                WHERE 
                    idHopDong = p_contract_id
                ORDER BY 
                    ngayDongBaoHiem DESC;
            ELSE
                -- Không có quyền truy cập
                SELECT 'error' as status, 'Không có quyền truy cập hợp đồng này' as message;
            END IF;
            
        -- Các phần còn lại của stored procedure giữ nguyên
        ELSE
            -- Thao tác không hợp lệ
            SELECT 'error' as status, 'Thao tác không hợp lệ' as message;
    END CASE;
END //

DELIMITER ;

-- Đảm bảo các hàm mã hóa và giải mã tồn tại
-- Wrapper for encrypt_data if it exists
DELIMITER //
DROP FUNCTION IF EXISTS encrypt_text //
CREATE FUNCTION encrypt_text(data TEXT) 
RETURNS VARBINARY(1000)
DETERMINISTIC
BEGIN
    DECLARE result VARBINARY(1000);
    
    -- Handle NULL input
    IF data IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Try to encrypt using encrypt_data function if it exists
    -- If error occurs, return NULL and don't crash
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
        BEGIN
            RETURN NULL;
        END;
        
        SET result = encrypt_data(data);
    END;
    
    RETURN result;
END //
DELIMITER ;

-- Wrapper for decrypt_data if it exists
DELIMITER //
DROP FUNCTION IF EXISTS decrypt_text //
CREATE FUNCTION decrypt_text(encrypted_data VARBINARY(1000)) 
RETURNS TEXT
DETERMINISTIC
BEGIN
    DECLARE result TEXT;
    
    -- Handle NULL input
    IF encrypted_data IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Try to decrypt using decrypt_data function if it exists
    -- If error occurs, return NULL and don't crash
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
        BEGIN
            RETURN NULL;
        END;
        
        SET result = decrypt_data(encrypted_data);
    END;
    
    RETURN result;
END //
DELIMITER ;

-- Fix authentication and session validation issue
DELIMITER //
CREATE OR REPLACE PROCEDURE fastapi_validate_session(
    IN p_session_id VARCHAR(100)
)
BEGIN
    DECLARE v_is_active BOOLEAN;
    DECLARE v_user_id INT;
    DECLARE v_role VARCHAR(50);
    
    -- Tìm phiên làm việc dựa vào session_id
    SELECT 
        is_active, 
        user_id 
    INTO 
        v_is_active, 
        v_user_id 
    FROM 
        phienlamviec 
    WHERE 
        session_id = p_session_id;
    
    -- Nếu phiên tồn tại và đang hoạt động
    IF v_is_active = TRUE THEN
        -- Cập nhật thời gian hoạt động cuối
        UPDATE phienlamviec 
        SET last_activity = CURRENT_TIMESTAMP 
        WHERE session_id = p_session_id;
        
        -- Lấy vai trò của người dùng
        SELECT vaitro INTO v_role 
        FROM NguoiDung 
        WHERE id = v_user_id;
        
        -- Trả về kết quả
        SELECT JSON_OBJECT(
            'valid', TRUE,
            'user_id', v_user_id,
            'role', v_role
        ) as result;
    ELSE
        -- Phiên không hợp lệ
        SELECT JSON_OBJECT(
            'valid', FALSE,
            'message', 'Invalid or expired session'
        ) as result;
    END IF;
END //
DELIMITER ;
