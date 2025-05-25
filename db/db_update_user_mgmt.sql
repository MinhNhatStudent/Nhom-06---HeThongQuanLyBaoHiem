USE insurance_management;

-- Thêm các trường cần thiết cho việc đặt lại mật khẩu vào bảng NguoiDung
ALTER TABLE NguoiDung
ADD COLUMN reset_password_token VARCHAR(255) NULL,
ADD COLUMN reset_password_expires DATETIME NULL;

-- Cập nhật audit trigger để ghi log cho các trường mới
DELIMITER //
CREATE TRIGGER nguoidung_update_with_reset_fields_trigger
AFTER UPDATE ON NguoiDung
FOR EACH ROW
BEGIN
    -- Chỉ ghi log nếu có thay đổi ở các trường quan trọng
    IF OLD.username != NEW.username OR 
       OLD.email != NEW.email OR
       OLD.pass != NEW.pass OR
       OLD.TrangThai != NEW.TrangThai OR
       OLD.vaitro != NEW.vaitro OR
       OLD.activation_token != NEW.activation_token OR
       OLD.activated != NEW.activated OR
       OLD.reset_password_token != NEW.reset_password_token OR
       OLD.reset_password_expires != NEW.reset_password_expires THEN
       
        -- Lưu vào bảng audit_logs
        INSERT INTO audit_logs (
            table_name,
            action_type,
            record_id,
            old_values,
            new_values,
            user_id,
            action_timestamp
        ) VALUES (
            'NguoiDung',
            'UPDATE',
            NEW.id,
            JSON_OBJECT(
                'username', OLD.username,
                'email', OLD.email,
                'trangThai', OLD.TrangThai,
                'vaitro', OLD.vaitro,
                'activation_token', IF(OLD.activation_token IS NULL, NULL, 'REDACTED'),
                'activated', OLD.activated,
                'reset_token', IF(OLD.reset_password_token IS NULL, NULL, 'REDACTED')
            ),
            JSON_OBJECT(
                'username', NEW.username,
                'email', NEW.email,
                'trangThai', NEW.TrangThai,
                'vaitro', NEW.vaitro,
                'activation_token', IF(NEW.activation_token IS NULL, NULL, 'REDACTED'),
                'activated', NEW.activated,
                'reset_token', IF(NEW.reset_password_token IS NULL, NULL, 'REDACTED')
            ),
            @current_user_id,  -- Người dùng hiện tại từ biến phiên
            NOW()
        );
    END IF;
END //
DELIMITER ;
