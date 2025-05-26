USE insurance_management;

-- Drop the existing procedure first
DROP PROCEDURE IF EXISTS fastapi_get_user_info;

-- Create the corrected procedure with proper field names matching the API model
DELIMITER //
CREATE PROCEDURE fastapi_get_user_info(
    IN p_user_id INT
)
BEGIN
    -- Kiểm tra quyền truy cập sẽ được thực hiện ở tầng API
    
    -- Lấy thông tin người dùng với tên trường phù hợp với model UserResponse
    SELECT 
        JSON_OBJECT(
            'id', id,
            'username', username,
            'email', email,
            'vai_tro', vaitro,  -- Change 'role' to 'vai_tro'
            'trang_thai', TrangThai,  -- Change 'status' to 'trang_thai'
            'insurance_type_id', idLoaiBaoHiem,  -- Change 'insurance_type' to 'insurance_type_id'
            'created_at', created_at,
            'activated', activated
        ) AS result
    FROM NguoiDung
    WHERE id = p_user_id;
END //
DELIMITER ;
