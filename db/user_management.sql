USE insurance_management;

-- ============================================================================
-- PHẦN 1: STORED PROCEDURE QUẢN LÝ NGƯỜI DÙNG
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1 Đăng ký người dùng mới
-- ----------------------------------------------------------------------------
DELIMITER //
CREATE PROCEDURE fastapi_register_user(
    IN p_username VARCHAR(50),
    IN p_email VARCHAR(100),
    IN p_vai_tro ENUM('contract_creator', 'insured_person', 'accounting', 'supervisor'),
    IN p_loai_bao_hiem INT
)
BEGIN
    DECLARE v_user_exists BOOLEAN;
    DECLARE v_user_id INT;
    DECLARE v_activation_token VARCHAR(255);
    
    -- Kiểm tra người dùng đã tồn tại
    SELECT id INTO v_user_id
    FROM NguoiDung
    WHERE username = p_username OR email = p_email
    LIMIT 1;
    
    SET v_user_exists = (v_user_id IS NOT NULL);
    
    -- Nếu người dùng đã tồn tại, trả về thông báo lỗi
    IF v_user_exists THEN
        SELECT JSON_OBJECT(
            'success', FALSE,
            'message', 'Username or email already exists',
            'user_id', v_user_id
        ) AS result;
    ELSE
        -- Tạo token kích hoạt
        SET v_activation_token = UUID();
        
        -- Tạo tài khoản mới
        INSERT INTO NguoiDung (
            username, 
            email, 
            pass, 
            TrangThai, 
            vaitro, 
            idLoaiBaoHiem, 
            activation_token, 
            activated
        ) VALUES (
            p_username,
            p_email,
            '', -- Mật khẩu sẽ được đặt khi kích hoạt
            'inactive',
            p_vai_tro,
            p_loai_bao_hiem,
            v_activation_token,
            FALSE
        );
        
        -- Ghi log và trả kết quả
        SELECT JSON_OBJECT(
            'success', TRUE,
            'user_id', LAST_INSERT_ID(),
            'activation_token', v_activation_token
        ) AS result;
    END IF;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- 1.2 Kích hoạt tài khoản người dùng
-- ----------------------------------------------------------------------------
DELIMITER //
CREATE PROCEDURE fastapi_activate_account(
    IN p_activation_token VARCHAR(255),
    IN p_password VARCHAR(255)
)
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_already_activated BOOLEAN;
    DECLARE v_username VARCHAR(50);
    
    -- Tìm người dùng theo token
    SELECT id, activated, username INTO v_user_id, v_already_activated, v_username
    FROM NguoiDung
    WHERE activation_token = p_activation_token
    LIMIT 1;
    
    -- Kiểm tra người dùng tồn tại và chưa kích hoạt
    IF v_user_id IS NULL THEN
        SELECT JSON_OBJECT(
            'success', FALSE,
            'message', 'Invalid activation token'
        ) AS result;
    ELSEIF v_already_activated THEN
        SELECT JSON_OBJECT(
            'success', FALSE,
            'message', 'Account already activated'
        ) AS result;
    ELSE
        -- Cập nhật trạng thái và mật khẩu
        UPDATE NguoiDung
        SET 
            TrangThai = 'active',
            activated = TRUE,
            pass = SHA2(p_password, 256),
            activation_token = NULL -- Xóa token sau khi kích hoạt
        WHERE id = v_user_id;
        
        -- Trả kết quả
        SELECT JSON_OBJECT(
            'success', TRUE,
            'user_id', v_user_id,
            'username', v_username
        ) AS result;
    END IF;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- 1.3 Yêu cầu đặt lại mật khẩu
-- ----------------------------------------------------------------------------
DELIMITER //
CREATE PROCEDURE fastapi_request_password_reset(
    IN p_email VARCHAR(100)
)
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_username VARCHAR(50);
    DECLARE v_reset_token VARCHAR(255);
    DECLARE v_user_active BOOLEAN;
    
    -- Tìm người dùng theo email
    SELECT id, username, TrangThai = 'active' INTO v_user_id, v_username, v_user_active
    FROM NguoiDung
    WHERE email = p_email
    LIMIT 1;
    
    -- Kiểm tra người dùng tồn tại và đang hoạt động
    IF v_user_id IS NULL THEN
        SELECT JSON_OBJECT(
            'success', FALSE,
            'message', 'User not found'
        ) AS result;
    ELSEIF NOT v_user_active THEN
        SELECT JSON_OBJECT(
            'success', FALSE,
            'message', 'Account is not active'
        ) AS result;
    ELSE
        -- Tạo token đặt lại mật khẩu
        SET v_reset_token = UUID();
        
        -- Cập nhật token vào CSDL
        UPDATE NguoiDung
        SET 
            reset_password_token = v_reset_token,
            reset_password_expires = DATE_ADD(NOW(), INTERVAL 1 HOUR)
        WHERE id = v_user_id;
        
        -- Trả kết quả
        SELECT JSON_OBJECT(
            'success', TRUE,
            'user_id', v_user_id,
            'username', v_username,
            'reset_token', v_reset_token
        ) AS result;
    END IF;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- 1.4 Đặt lại mật khẩu
-- ----------------------------------------------------------------------------
DELIMITER //
CREATE PROCEDURE fastapi_reset_password(
    IN p_reset_token VARCHAR(255),
    IN p_password VARCHAR(255)
)
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_token_valid BOOLEAN;
    DECLARE v_username VARCHAR(50);
    
    -- Kiểm tra token hợp lệ và chưa hết hạn
    SELECT id, username INTO v_user_id, v_username
    FROM NguoiDung
    WHERE 
        reset_password_token = p_reset_token
        AND reset_password_expires > NOW()
    LIMIT 1;
    
    -- Kiểm tra token
    IF v_user_id IS NULL THEN
        SELECT JSON_OBJECT(
            'success', FALSE,
            'message', 'Invalid or expired reset token'
        ) AS result;
    ELSE
        -- Cập nhật mật khẩu
        UPDATE NguoiDung
        SET 
            pass = SHA2(p_password, 256),
            reset_password_token = NULL,
            reset_password_expires = NULL
        WHERE id = v_user_id;
        
        -- Trả kết quả
        SELECT JSON_OBJECT(
            'success', TRUE,
            'user_id', v_user_id,
            'username', v_username
        ) AS result;
    END IF;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- 1.5 Lấy thông tin người dùng
-- ----------------------------------------------------------------------------
DELIMITER //
CREATE PROCEDURE fastapi_get_user_info(
    IN p_user_id INT
)
BEGIN
    -- Kiểm tra quyền truy cập sẽ được thực hiện ở tầng API
    
    -- Lấy thông tin người dùng
    SELECT 
        JSON_OBJECT(
            'id', id,
            'username', username,
            'email', email,
            'role', vaitro,
            'status', TrangThai,
            'insurance_type', idLoaiBaoHiem,
            'created_at', created_at,
            'activated', activated
        ) AS result
    FROM NguoiDung
    WHERE id = p_user_id;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- 1.6 Cập nhật thông tin người dùng
-- ----------------------------------------------------------------------------
DELIMITER //
CREATE PROCEDURE fastapi_update_user_info(
    IN p_user_id INT,
    IN p_email VARCHAR(100),
    IN p_vai_tro ENUM('contract_creator', 'insured_person', 'accounting', 'supervisor'),
    IN p_trang_thai ENUM('active', 'inactive'),
    IN p_loai_bao_hiem INT,
    IN p_updated_by INT -- ID của người thực hiện cập nhật
)
BEGIN
    DECLARE v_success BOOLEAN DEFAULT FALSE;
    DECLARE v_message VARCHAR(255);
    DECLARE v_current_role VARCHAR(50);
    
    -- Kiểm tra người dùng tồn tại
    SELECT vaitro INTO v_current_role
    FROM NguoiDung
    WHERE id = p_user_id;
    
    IF v_current_role IS NULL THEN
        SET v_message = 'User not found';
    ELSE
        -- Kiểm tra email đã tồn tại cho người dùng khác
        IF EXISTS (SELECT 1 FROM NguoiDung WHERE email = p_email AND id != p_user_id) THEN
            SET v_message = 'Email already in use by another user';
        ELSE
            -- Cập nhật thông tin
            UPDATE NguoiDung
            SET 
                email = p_email,
                vaitro = p_vai_tro,
                TrangThai = p_trang_thai,
                idLoaiBaoHiem = p_loai_bao_hiem
            WHERE id = p_user_id;
            
            SET v_success = TRUE;
            SET v_message = 'User information updated successfully';
            
            -- Ghi log cập nhật (sử dụng trigger)
        END IF;
    END IF;
    
    -- Trả kết quả
    SELECT JSON_OBJECT(
        'success', v_success,
        'message', v_message,
        'user_id', p_user_id
    ) AS result;
END //
DELIMITER ;

-- ----------------------------------------------------------------------------
-- 1.7 Thay đổi mật khẩu
-- ----------------------------------------------------------------------------
DELIMITER //
CREATE PROCEDURE fastapi_change_password(
    IN p_user_id INT,
    IN p_current_password VARCHAR(255),
    IN p_new_password VARCHAR(255)
)
BEGIN
    DECLARE v_password_correct BOOLEAN;
    
    -- Kiểm tra mật khẩu hiện tại
    SELECT COUNT(*) > 0 INTO v_password_correct
    FROM NguoiDung
    WHERE id = p_user_id AND pass = SHA2(p_current_password, 256);
    
    IF NOT v_password_correct THEN
        SELECT JSON_OBJECT(
            'success', FALSE,
            'message', 'Current password is incorrect'
        ) AS result;
    ELSE
        -- Cập nhật mật khẩu mới
        UPDATE NguoiDung
        SET pass = SHA2(p_new_password, 256)
        WHERE id = p_user_id;
        
        SELECT JSON_OBJECT(
            'success', TRUE,
            'message', 'Password changed successfully'
        ) AS result;
    END IF;
END //
DELIMITER ;
