USE insurance_management; SHOW TABLE STATUS WHERE Name IN ('NguoiDung', 'insurance_types','audit_logs', 'chiakhoa', 'chitiethopdong', 'hopdong', 'phienlamviec', 'thanhtoan', 'user_activity_logs');

SELECT SCHEMA_NAME, DEFAULT_CHARACTER_SET_NAME, DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = 'insurance_management';

ALTER TABLE chiakhoa CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
ALTER TABLE nguoidung CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
ALTER TABLE hopdong CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
ALTER TABLE chitiethopdong CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
ALTER TABLE insurance_types CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
ALTER TABLE phienlamviec CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
ALTER TABLE thanhtoan CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
ALTER TABLE user_activity_logs CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
ALTER TABLE audit_logs CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
ALTER DATABASE insurance_management CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
ALTER TABLE ChiTietHopDong CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;


DROP PROCEDURE IF EXISTS fastapi_validate_session;

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
    IF v_user_id IS NOT NULL THEN
        -- If session exists but is inactive, reactivate it for convenience during development
        IF v_is_active = FALSE THEN
            UPDATE phienlamviec SET is_active = TRUE WHERE session_id = p_session_id;
            SET v_is_active = TRUE;
        END IF;
        
        -- Get user info
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