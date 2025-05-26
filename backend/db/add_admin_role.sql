USE insurance_management;

-- Thêm giá trị 'admin' vào ENUM vaitro trong bảng NguoiDung
ALTER TABLE NguoiDung MODIFY COLUMN vaitro ENUM('contract_creator', 'insured_person', 'accounting', 'supervisor', 'admin') NOT NULL;

-- Kiểm tra xem có người dùng admin chưa
SELECT COUNT(*) INTO @admin_exists FROM NguoiDung WHERE username = 'admin';

-- Tạo mật khẩu mã hóa cho admin
SET @admin_password = SHA2('Admin@123', 256);

-- Nếu chưa tồn tại, tạo người dùng admin mới
INSERT INTO NguoiDung (username, email, pass, TrangThai, vaitro, activated, created_at)
SELECT 'admin', 'admin@baohiem.com', @admin_password, 'active', 'admin', TRUE, NOW()
WHERE @admin_exists = 0;

-- Hiển thị thông tin admin
SELECT id, username, email, vaitro, TrangThai, activated FROM NguoiDung WHERE username = 'admin';
