-- ============================================================================
-- PHẦN 1: QUẢN LÝ PHIÊN NGƯỜI DÙNG
-- ============================================================================
USE insurance_management;

-- Kiểm tra sự tồn tại của thủ tục trước khi gọi
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS check_and_call_encryption_key()
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.routines 
               WHERE routine_schema = 'insurance_management' 
               AND routine_name = 'set_encryption_session_key') THEN
        CALL set_encryption_session_key();
    ELSE
        SET @encryption_key = 'temporary_key';
        SELECT 'Warning: set_encryption_session_key not found, using temporary key' AS message;
    END IF;
END //
DELIMITER ;

-- Bảng lưu trữ thông tin phiên làm việc
CREATE TABLE phienlamviec (
    session_id VARCHAR(255) PRIMARY KEY,
    user_id INT NOT NULL,
    login_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (user_id) REFERENCES NguoiDung(id)
);

-- Thủ tục bắt đầu phiên làm việc
DELIMITER //
CREATE PROCEDURE start_user_session(
    IN p_user_id INT,
    IN p_session_id VARCHAR(255),
    IN p_ip_address VARCHAR(45)
)
BEGIN
    -- Xóa các phiên cũ của người dùng (tùy chọn - nếu muốn chỉ cho phép 1 phiên)
    -- UPDATE phienlamviec SET is_active = FALSE WHERE user_id = p_user_id AND is_active = TRUE;
    

    
    -- Thêm phiên mới
    INSERT INTO phienlamviec (session_id, user_id, ip_address)
    VALUES (p_session_id, p_user_id, p_ip_address);
    
    -- Thiết lập biến phiên
    SET @current_user_id = p_user_id;
    SET @session_id = p_session_id;
    
    -- Thiết lập khóa mã hóa
    CALL check_and_call_encryption_key();
END //
DELIMITER ;

-- Thủ tục kiểm tra và kích hoạt phiên
DELIMITER //
CREATE PROCEDURE validate_and_activate_session(
    IN p_session_id VARCHAR(255)
)
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_is_active BOOLEAN;
    
    -- Kiểm tra phiên hợp lệ
    SELECT user_id, is_active INTO v_user_id, v_is_active
    FROM phienlamviec 
    WHERE session_id = p_session_id;
    
    -- Nếu phiên hợp lệ và đang hoạt động
    IF v_user_id IS NOT NULL AND v_is_active = TRUE THEN
        -- Thiết lập biến phiên
        SET @current_user_id = v_user_id;
        SET @session_id = p_session_id;
        
        -- Thiết lập khóa mã hóa
        CALL check_and_call_encryption_key();
        
        -- Cập nhật thời gian hoạt động
        UPDATE phienlamviec 
        SET last_activity = CURRENT_TIMESTAMP 
        WHERE session_id = p_session_id;
        
        SELECT TRUE AS valid_session, v_user_id AS user_id;
    ELSE
        SET @current_user_id = NULL;
        SET @session_id = NULL;
        SELECT FALSE AS valid_session, NULL AS user_id;
    END IF;
END //
DELIMITER ;

-- Thủ tục kết thúc phiên
DELIMITER //
CREATE PROCEDURE end_user_session(
    IN p_session_id VARCHAR(255)
)
BEGIN
    UPDATE phienlamviec 
    SET is_active = FALSE 
    WHERE session_id = p_session_id;
    
    SET @current_user_id = NULL;
    SET @session_id = NULL;
END //
DELIMITER ;

-- Thủ tục dọn dẹp phiên cũ (chạy định kỳ hoặc bởi cronjob)
DELIMITER //
CREATE PROCEDURE cleanup_old_sessions(
    IN p_hours INT  -- Số giờ không hoạt động trước khi đánh dấu phiên hết hạn
)
BEGIN
    UPDATE phienlamviec 
    SET is_active = FALSE 
    WHERE last_activity < DATE_SUB(NOW(), INTERVAL p_hours HOUR);
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 2: TÍCH HỢP VỚI DJANGO
-- ============================================================================

/*
Khi tích hợp với Django, bạn cần:

# Đảm bảo thứ tự khởi tạo:
# 1. Đảm bảo tất cả các file SQL đã được thực thi theo thứ tự:
#    db.sql → baomat.sql → mahoa.sql → phien.sql

1. Khi người dùng đăng nhập:
   with connection.cursor() as cursor:
       cursor.execute("CALL start_user_session(%s, %s, %s)", 
                     [user.id, session.session_key, client_ip])

2. Trước mỗi request truy cập database:
   with connection.cursor() as cursor:
       cursor.execute("CALL validate_and_activate_session(%s)", 
                     [session.session_key])
       result = cursor.fetchone()
       if not result or not result[0]:  # Nếu phiên không hợp lệ
           # Yêu cầu đăng nhập lại

3. Khi người dùng đăng xuất:
   with connection.cursor() as cursor:
       cursor.execute("CALL end_user_session(%s)", 
                     [session.session_key])

4. Chạy dọn dẹp định kỳ (có thể thông qua Django celery):
   with connection.cursor() as cursor:
       cursor.execute("CALL cleanup_old_sessions(24)")  # Dọn phiên > 24 giờ
*/