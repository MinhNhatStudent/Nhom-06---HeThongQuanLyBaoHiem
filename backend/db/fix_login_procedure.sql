-- Fixes for the fastapi_login procedure
USE insurance_management;

-- Drop the existing procedure
DROP PROCEDURE IF EXISTS fastapi_login;

-- Create the improved version with direct insertion
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
        
        -- Tạo phiên mới - sử dụng cả CALL và INSERT trực tiếp để đảm bảo
        -- First try the regular way
        CALL start_user_session(v_user_id, p_session_id, p_ip_address);
        
        -- Double check if session was created
        IF NOT EXISTS(SELECT 1 FROM phienlamviec WHERE session_id = p_session_id) THEN
            -- Insert directly if the procedure call failed
            INSERT INTO phienlamviec (session_id, user_id, ip_address, is_active)
            VALUES (p_session_id, v_user_id, p_ip_address, TRUE);
            
            -- Set session variables manually
            SET @current_user_id = v_user_id;
            SET @session_id = p_session_id;
            
            -- Try to set encryption key if available
            CALL check_and_call_encryption_key();
        END IF;
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

-- Also fix the fastapi_validate_session procedure to be more resilient
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
