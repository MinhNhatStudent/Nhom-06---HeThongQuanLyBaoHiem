USE insurance_management;

-- Drop the existing trigger first
DROP TRIGGER IF EXISTS nguoidung_update_with_reset_fields_trigger;

-- Create the corrected trigger
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
       
        -- Lưu vào bảng audit_logs với tên trường đúng là action_time (không phải action_timestamp)
        INSERT INTO audit_logs (
            table_name,
            action_type,
            record_id,
            old_values,
            new_values,
            user_id,
            action_time
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

-- This should fix the "Unknown column 'action_timestamp'" error when activating users
