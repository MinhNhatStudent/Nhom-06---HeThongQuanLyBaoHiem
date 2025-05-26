-- ============================================================================
-- CHUYỂN ĐỔI TẤT CẢ BẢNG SANG UTF8MB4 VÀ TẠO WRAPPER FUNCTIONS CHO ENCRYPTION/DECRYPTION
-- ============================================================================
USE insurance_management;

-- Đặt lại character set và collation cho toàn bộ database
ALTER DATABASE insurance_management CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Chuyển đổi tất cả bảng sang utf8mb4
ALTER TABLE NguoiDung CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
ALTER TABLE HopDong CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
ALTER TABLE ChiTietHopDong CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
ALTER TABLE ThanhToan CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
ALTER TABLE insurance_types CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
ALTER TABLE phienlamviec CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
ALTER TABLE audit_logs CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Tạo các wrapper functions cho mã hóa/giải mã nếu chúng chưa tồn tại
DELIMITER //

-- Kiểm tra xem hàm encrypt_text đã tồn tại chưa, nếu chưa thì tạo mới
DROP FUNCTION IF EXISTS encrypt_text //
CREATE FUNCTION encrypt_text(data TEXT) 
RETURNS VARBINARY(1000)
DETERMINISTIC
BEGIN
    -- Gọi hàm encrypt_data đã có sẵn trong hệ thống
    RETURN encrypt_data(data);
END //

-- Kiểm tra xem hàm decrypt_text đã tồn tại chưa, nếu chưa thì tạo mới
DROP FUNCTION IF EXISTS decrypt_text //
CREATE FUNCTION decrypt_text(encrypted_data VARBINARY(1000)) 
RETURNS TEXT
DETERMINISTIC
BEGIN
    -- Gọi hàm decrypt_data đã có sẵn trong hệ thống
    RETURN decrypt_data(encrypted_data);
END //

DELIMITER ;
