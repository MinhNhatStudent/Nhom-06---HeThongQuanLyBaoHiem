-- Tập tin: insert_test_users.sql
USE insurance_management;

-- ============================================================================
-- THÊM DỮ LIỆU NGƯỜI DÙNG MẪU CHO HỆ THỐNG BẢO HIỂM
-- ============================================================================
-- {user admin
--  "current_password": "Admin@123",
--  "new_password": "Admin@1234"
-- }
-- ----------------------------------------------------------------------------
-- 1. Thêm người dùng supervisor
-- ----------------------------------------------------------------------------
INSERT INTO NguoiDung (username, pass, email, TrangThai, vaitro, idLoaiBaoHiem, activated)
VALUES 
('svi1', SHA2('Admin@2025', 256), 'admin@insurance.com', 'active', 'supervisor', NULL, TRUE),
('svhealth', SHA2('Secure@123', 256), 'health_supervisor@insurance.com', 'active', 'supervisor', 1, TRUE),
('svkhac', SHA2('Life@2025', 256), 'life_supervisor@insurance.com', 'active', 'supervisor', 2, TRUE),
('svtainan', SHA2('Accident@456', 256), 'accident_supervisor@insurance.com', 'active', 'supervisor', 3, TRUE);

-- ----------------------------------------------------------------------------
-- 2. Thêm nhân viên kế toán (accounting)
-- ----------------------------------------------------------------------------
INSERT INTO NguoiDung (username, pass, email, TrangThai, vaitro, idLoaiBaoHiem, activated)
VALUES 
('account1', SHA2('Account#123', 256), 'accountant1@insurance.com', 'active', 'accounting', 1, TRUE),
('account2', SHA2('Account#234', 256), 'accountant2@insurance.com', 'active', 'accounting', 2, TRUE),
('account3', SHA2('Account#345', 256), 'accountant3@insurance.com', 'active', 'accounting', 3, TRUE),
('account4', SHA2('Account#456', 256), 'accountant4@insurance.com', 'active', 'accounting', 1, TRUE),
('account5', SHA2('Account#567', 256), 'accountant5@insurance.com', 'active', 'accounting', 2, TRUE);

-- ----------------------------------------------------------------------------
-- 3. Thêm nhân viên lập hợp đồng (contract_creator)
-- ----------------------------------------------------------------------------
INSERT INTO NguoiDung (username, pass, email, TrangThai, vaitro, idLoaiBaoHiem, activated)
VALUES 
('creatorA', SHA2('Creator@123', 256), 'creator1@insurance.com', 'active', 'contract_creator', NULL, TRUE),
('creatorB', SHA2('Creator@234', 256), 'creator2@insurance.com', 'active', 'contract_creator', NULL, TRUE),
('creatorC', SHA2('Creator@345', 256), 'creator3@insurance.com', 'active', 'contract_creator', NULL, TRUE),
('creatorD', SHA2('Creator@456', 256), 'creator4@insurance.com', 'active', 'contract_creator', NULL, TRUE),
('creatorE', SHA2('Creator@567', 256), 'creator5@insurance.com', 'active', 'contract_creator', NULL, TRUE);

-- ----------------------------------------------------------------------------
-- 4. Thêm người được bảo hiểm (insured_person)
-- ----------------------------------------------------------------------------
INSERT INTO NguoiDung (username, pass, email, TrangThai, vaitro, idLoaiBaoHiem, activated)
VALUES 
('nguyenvana', SHA2('User@123', 256), 'nguyenvana@gmail.com', 'active', 'insured_person', NULL, TRUE),
('tranthib', SHA2('User@234', 256), 'tranthib@gmail.com', 'active', 'insured_person', NULL, TRUE),
('levanc', SHA2('User@345', 256), 'levanc@gmail.com', 'active', 'insured_person', NULL, TRUE),
('phamthid', SHA2('User@456', 256), 'phamthid@gmail.com', 'active', 'insured_person', NULL, TRUE),
('hoangvane', SHA2('User@567', 256), 'hoangvane@gmail.com', 'active', 'insured_person', NULL, TRUE),
('nguyenthif', SHA2('User@678', 256), 'nguyenthif@gmail.com', 'active', 'insured_person', NULL, TRUE),
('tran_van_g', SHA2('User@789', 256), 'tranvang@gmail.com', 'active', 'insured_person', NULL, TRUE),
('lethih', SHA2('User@890', 256), 'lethih@gmail.com', 'active', 'insured_person', NULL, TRUE),
('phamvani', SHA2('User@901', 256), 'phamvani@gmail.com', 'active', 'insured_person', NULL, TRUE),
('hoangthik', SHA2('User@012', 256), 'hoangthik@gmail.com', 'active', 'insured_person', NULL, TRUE);

-- ----------------------------------------------------------------------------
-- 5. Thêm người dùng chưa kích hoạt (chờ xác nhận qua email)
-- ----------------------------------------------------------------------------
INSERT INTO NguoiDung (username, pass, email, TrangThai, vaitro, idLoaiBaoHiem, activation_token, activated)
VALUES 
('new_user1', '', 'newuser1@gmail.com', 'inactive', 'insured_person', NULL, UUID(), FALSE),
('new_user2', '', 'newuser2@gmail.com', 'inactive', 'insured_person', NULL, UUID(), FALSE),
('new_user3', '', 'newuser3@gmail.com', 'inactive', 'insured_person', NULL, UUID(), FALSE);

-- Không vô hiệu hóa khóa ngoại nếu bạn thêm người dùng tương ứng với một loại bảo hiểm không tồn tại
-- SET FOREIGN_KEY_CHECKS = 0; 
-- INSERT INTO NguoiDung ... Các truy vấn chèn dữ liệu
-- SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------------------------
-- 6. Cập nhật thời gian tạo cho một số người dùng (tùy chọn)
-- ----------------------------------------------------------------------------
UPDATE NguoiDung 
SET created_at = DATE_SUB(NOW(), INTERVAL FLOOR(1 + RAND() * 30) DAY)
WHERE id <= 10;

UPDATE NguoiDung 
SET created_at = DATE_SUB(NOW(), INTERVAL FLOOR(1 + RAND() * 15) DAY)
WHERE id > 10 AND id <= 20;

-- ----------------------------------------------------------------------------
-- 7. Kiểm tra dữ liệu đã thêm vào
-- ----------------------------------------------------------------------------
SELECT id, username, email, vaitro, TrangThai, activated, created_at 
FROM NguoiDung 
ORDER BY id;


-- Hướng dẫn thêm dữ liệu cho bảng HopDong
-- Bạn có thể sử dụng các câu lệnh INSERT tương tự để thêm dữ liệu vào bảng HopDong
-- Dau tien drop procedure nay (nho cai lai sau do)
DROP TRIGGER IF EXISTS before_insert_contract;
DELIMITER //
CREATE TRIGGER before_insert_contract
BEFORE INSERT ON HopDong
FOR EACH ROW
BEGIN
    DECLARE role VARCHAR(20);
    
    -- Lấy vai trò của người dùng
    SELECT vaitro INTO role FROM NguoiDung WHERE id = @current_user_id;
    
    -- Chỉ người lập hợp đồng mới có thể tạo hợp đồng mới
    IF role != 'contract_creator' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: Only contract creators can add new contracts';
    END IF;
    
    -- Tự động gán người tạo là người đang đăng nhập
    SET NEW.creator_id = @current_user_id;
    
    -- Ghi log
    INSERT INTO audit_logs (user_id, action_type, table_name, record_id, new_values)
    VALUES (
        @current_user_id,
        'INSERT',
        'HopDong',
        NULL, -- ID sẽ được tạo sau khi INSERT
        JSON_OBJECT(
            'creator_id', NEW.creator_id,
            'idLoaiBaoHiem', NEW.idLoaiBaoHiem,
            'idNguoiBH', NEW.idNguoiBH,
            'ngayKiHD', NEW.ngayKiHD,
            'ngayCatHD', NEW.ngayCatHD
        )
    );
END //
DELIMITER ;

-- ============================================================================
-- THÊM DỮ LIỆU HỢP ĐỒNG VÀ CHI TIẾT HỢP ĐỒNG
-- ============================================================================

-- Tạm thời đặt giá trị cho current_user_id (mô phỏng người dùng đang đăng nhập)
-- Trong thực tế, biến này sẽ được thiết lập khi người dùng đăng nhập
-- Đặt là ID của creatorA
SET @current_user_id = 11;

-- ----------------------------------------------------------------------------
-- 1. Thêm dữ liệu cho bảng HopDong (Bảo hiểm Sức khỏe)
-- ----------------------------------------------------------------------------
INSERT INTO HopDong (creator_id, idLoaiBaoHiem, idNguoiBH, ngayKiHD, ngayCatHD)
VALUES 
(11, 1, 16, '2025-01-15', '2026-01-15'), -- creatorA tạo hợp đồng cho nguyenvana
(11, 1, 17, '2025-01-20', '2026-01-20'), -- creatorA tạo hợp đồng cho tranthib
(11, 1, 18, '2025-02-01', '2026-02-01'), -- creatorA tạo hợp đồng cho levanc
(12, 1, 19, '2025-02-10', '2026-02-10'), -- creatorB tạo hợp đồng cho phamthid
(12, 1, 20, '2025-02-15', '2026-02-15'); -- creatorB tạo hợp đồng cho hoangvane

-- Thay đổi người tạo hợp đồng
SET @current_user_id = 12;

-- ----------------------------------------------------------------------------
-- 2. Thêm dữ liệu cho bảng HopDong (Bảo hiểm Nhân thọ)
-- ----------------------------------------------------------------------------
INSERT INTO HopDong (creator_id, idLoaiBaoHiem, idNguoiBH, ngayKiHD, ngayCatHD)
VALUES 
(12, 2, 21, '2025-03-01', '2030-03-01'), -- creatorB tạo hợp đồng cho nguyenthif
(12, 2, 22, '2025-03-10', '2030-03-10'), -- creatorB tạo hợp đồng cho tran_van_g
(13, 2, 23, '2025-03-15', '2030-03-15'); -- creatorC tạo hợp đồng cho lethih

-- Thay đổi người tạo hợp đồng
SET @current_user_id = 13;

-- ----------------------------------------------------------------------------
-- 3. Thêm dữ liệu cho bảng HopDong (Bảo hiểm Tai nạn)
-- ----------------------------------------------------------------------------
INSERT INTO HopDong (creator_id, idLoaiBaoHiem, idNguoiBH, ngayKiHD, ngayCatHD)
VALUES 
(13, 3, 24, '2025-04-01', '2026-04-01'), -- creatorC tạo hợp đồng cho phamvani
(13, 3, 25, '2025-04-10', '2026-04-10'); -- creatorC tạo hợp đồng cho hoangthik

-- Xác định ID của các hợp đồng đã tạo để thêm chi tiết
-- SELECT * FROM HopDong ORDER BY id;

-- ----------------------------------------------------------------------------
-- 4. Thêm Chi tiết Hợp đồng Bảo hiểm Sức khỏe
-- ----------------------------------------------------------------------------
INSERT INTO ChiTietHopDong (idHopDong, HoTen, gioiTinh, ngaySinh, diachiCoQuan, diachiThuongTru, sodienthoai, lichsuBenh)
VALUES 
(1, 'Nguyễn Văn An', 'male', '1985-06-15', 'Công ty TNHH ABC', 'Số 123 Đường Lê Lợi, Quận 1, TP.HCM', '0912345678', 'Không có tiền sử bệnh'),
(2, 'Trần Thị Bình', 'female', '1990-08-20', 'Công ty CP XYZ', 'Số 456 Đường Nguyễn Huệ, Quận 1, TP.HCM', '0923456789', 'Viêm phổi nhẹ năm 2023'),
(3, 'Lê Văn Cường', 'male', '1982-03-10', 'Trường Đại học ABC', '789 Đường Cách Mạng Tháng 8, Quận 3, TP.HCM', '0934567890', 'Tiểu đường type 2'),
(4, 'Phạm Thị Dung', 'female', '1995-12-05', 'Bệnh viện XYZ', '101 Đường Võ Văn Tần, Quận 3, TP.HCM', '0945678901', 'Không có'),
(5, 'Hoàng Văn Eo', 'male', '1988-07-25', 'Ngân hàng DEF', '202 Đường Lý Tự Trọng, Quận 1, TP.HCM', '0956789012', 'Huyết áp cao');

-- ----------------------------------------------------------------------------
-- 5. Thêm Chi tiết Hợp đồng Bảo hiểm Nhân thọ
-- ----------------------------------------------------------------------------
INSERT INTO ChiTietHopDong (idHopDong, HoTen, gioiTinh, ngaySinh, diachiCoQuan, diachiThuongTru, sodienthoai, lichsuBenh)
VALUES 
(6, 'Nguyễn Thị Phương', 'female', '1975-09-18', 'Công ty Điện lực', '303 Đường Hai Bà Trưng, Quận 1, TP.HCM', '0967890123', 'Không có'),
(7, 'Trần Văn Giang', 'male', '1980-11-30', 'Công ty Vận tải', '404 Đường Nguyễn Đình Chiểu, Quận 3, TP.HCM', '0978901234', 'Phẫu thuật ruột thừa năm 2022'),
(8, 'Lê Thị Hoa', 'female', '1979-04-22', 'Công ty Du lịch', '505 Đường Điện Biên Phủ, Quận Bình Thạnh, TP.HCM', '0989012345', 'Không có');

-- ----------------------------------------------------------------------------
-- 6. Thêm Chi tiết Hợp đồng Bảo hiểm Tai nạn
-- ----------------------------------------------------------------------------
INSERT INTO ChiTietHopDong (idHopDong, HoTen, gioiTinh, ngaySinh, diachiCoQuan, diachiThuongTru, sodienthoai, lichsuBenh)
VALUES 
(9, 'Phạm Văn Ích', 'male', '1992-05-17', 'Công ty Xây dựng', '606 Đường Nguyễn Văn Linh, Quận 7, TP.HCM', '0990123456', 'Gãy tay phải năm 2024'),
(10, 'Hoàng Thị Kim', 'female', '1987-10-08', 'Công ty Thời trang', '707 Đường Võ Thị Sáu, Quận 3, TP.HCM', '0901234567', 'Không có');

-- ----------------------------------------------------------------------------
-- 7. Thêm dữ liệu thanh toán cho các hợp đồng
-- ----------------------------------------------------------------------------
-- Thanh toán cho hợp đồng Bảo hiểm sức khỏe
INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong)
VALUES
(1, '2025-01-15', 5000000),
(1, '2025-04-15', 5000000),
(2, '2025-01-20', 4500000),
(2, '2025-04-20', 4500000),
(3, '2025-02-01', 6000000),
(4, '2025-02-10', 5200000),
(5, '2025-02-15', 4800000);

-- Thanh toán cho hợp đồng Bảo hiểm nhân thọ
INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong)
VALUES
(6, '2025-03-01', 10000000),
(7, '2025-03-10', 12000000),
(8, '2025-03-15', 9500000);

-- Thanh toán cho hợp đồng Bảo hiểm tai nạn
INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong)
VALUES
(9, '2025-04-01', 3000000),
(10, '2025-04-10', 2800000);

-- Kiểm tra dữ liệu hợp đồng đã thêm vào
SELECT hd.id, creator.username AS nguoi_tao, bh.tenBH AS loai_bao_hiem, nd.username AS nguoi_duoc_bao_hiem,
       hd.ngayKiHD, hd.ngayCatHD
FROM HopDong hd
JOIN NguoiDung creator ON hd.creator_id = creator.id
JOIN insurance_types bh ON hd.idLoaiBaoHiem = bh.id
JOIN NguoiDung nd ON hd.idNguoiBH = nd.id
ORDER BY hd.id;

-- Kiểm tra chi tiết hợp đồng
SELECT cthd.id, hd.id AS idHopDong, cthd.HoTen, cthd.gioiTinh, cthd.ngaySinh,
       cthd.diachiCoQuan, cthd.diachiThuongTru, cthd.sodienthoai
FROM ChiTietHopDong cthd
JOIN HopDong hd ON cthd.idHopDong = hd.id
ORDER BY cthd.id;

-- Kiểm tra thanh toán
SELECT tt.id, hd.id AS idHopDong, nd.username AS nguoi_duoc_bao_hiem,
       bh.tenBH AS loai_bao_hiem, tt.ngayDongBaoHiem, tt.soTienDong
FROM ThanhToan tt
JOIN HopDong hd ON tt.idHopDong = hd.id
JOIN NguoiDung nd ON hd.idNguoiBH = nd.id
JOIN insurance_types bh ON hd.idLoaiBaoHiem = bh.id
ORDER BY tt.id;


-- Tập tin: insert_test_users.sql
USE insurance_management;

-- ============================================================================
-- THÊM DỮ LIỆU NGƯỜI DÙNG MẪU CHO HỆ THỐNG BẢO HIỂM
-- ============================================================================
-- {user admin
--  "current_password": "Admin@123",
--  "new_password": "Admin@1234"
-- }
-- ----------------------------------------------------------------------------
-- 1. Thêm người dùng supervisor
-- ----------------------------------------------------------------------------
INSERT INTO NguoiDung (username, pass, email, TrangThai, vaitro, idLoaiBaoHiem, activated)
VALUES 
('svi1', SHA2('Admin@2025', 256), 'admin@insurance.com', 'active', 'supervisor', NULL, TRUE),
('svhealth', SHA2('Secure@123', 256), 'health_supervisor@insurance.com', 'active', 'supervisor', 1, TRUE),
('svkhac', SHA2('Life@2025', 256), 'life_supervisor@insurance.com', 'active', 'supervisor', 2, TRUE),
('svtainan', SHA2('Accident@456', 256), 'accident_supervisor@insurance.com', 'active', 'supervisor', 3, TRUE);

-- ----------------------------------------------------------------------------
-- 2. Thêm nhân viên kế toán (accounting)
-- ----------------------------------------------------------------------------
INSERT INTO NguoiDung (username, pass, email, TrangThai, vaitro, idLoaiBaoHiem, activated)
VALUES 
('account1', SHA2('Account#123', 256), 'accountant1@insurance.com', 'active', 'accounting', 1, TRUE),
('account2', SHA2('Account#234', 256), 'accountant2@insurance.com', 'active', 'accounting', 2, TRUE),
('account3', SHA2('Account#345', 256), 'accountant3@insurance.com', 'active', 'accounting', 3, TRUE),
('account4', SHA2('Account#456', 256), 'accountant4@insurance.com', 'active', 'accounting', 1, TRUE),
('account5', SHA2('Account#567', 256), 'accountant5@insurance.com', 'active', 'accounting', 2, TRUE);

-- ----------------------------------------------------------------------------
-- 3. Thêm nhân viên lập hợp đồng (contract_creator)
-- ----------------------------------------------------------------------------
INSERT INTO NguoiDung (username, pass, email, TrangThai, vaitro, idLoaiBaoHiem, activated)
VALUES 
('creatorA', SHA2('Creator@123', 256), 'creator1@insurance.com', 'active', 'contract_creator', NULL, TRUE),
('creatorB', SHA2('Creator@234', 256), 'creator2@insurance.com', 'active', 'contract_creator', NULL, TRUE),
('creatorC', SHA2('Creator@345', 256), 'creator3@insurance.com', 'active', 'contract_creator', NULL, TRUE),
('creatorD', SHA2('Creator@456', 256), 'creator4@insurance.com', 'active', 'contract_creator', NULL, TRUE),
('creatorE', SHA2('Creator@567', 256), 'creator5@insurance.com', 'active', 'contract_creator', NULL, TRUE);

-- ----------------------------------------------------------------------------
-- 4. Thêm người được bảo hiểm (insured_person)
-- ----------------------------------------------------------------------------
INSERT INTO NguoiDung (username, pass, email, TrangThai, vaitro, idLoaiBaoHiem, activated)
VALUES 
('nguyenvana', SHA2('User@123', 256), 'nguyenvana@gmail.com', 'active', 'insured_person', NULL, TRUE),
('tranthib', SHA2('User@234', 256), 'tranthib@gmail.com', 'active', 'insured_person', NULL, TRUE),
('levanc', SHA2('User@345', 256), 'levanc@gmail.com', 'active', 'insured_person', NULL, TRUE),
('phamthid', SHA2('User@456', 256), 'phamthid@gmail.com', 'active', 'insured_person', NULL, TRUE),
('hoangvane', SHA2('User@567', 256), 'hoangvane@gmail.com', 'active', 'insured_person', NULL, TRUE),
('nguyenthif', SHA2('User@678', 256), 'nguyenthif@gmail.com', 'active', 'insured_person', NULL, TRUE),
('tran_van_g', SHA2('User@789', 256), 'tranvang@gmail.com', 'active', 'insured_person', NULL, TRUE),
('lethih', SHA2('User@890', 256), 'lethih@gmail.com', 'active', 'insured_person', NULL, TRUE),
('phamvani', SHA2('User@901', 256), 'phamvani@gmail.com', 'active', 'insured_person', NULL, TRUE),
('hoangthik', SHA2('User@012', 256), 'hoangthik@gmail.com', 'active', 'insured_person', NULL, TRUE);

-- ----------------------------------------------------------------------------
-- 5. Thêm người dùng chưa kích hoạt (chờ xác nhận qua email)
-- ----------------------------------------------------------------------------
INSERT INTO NguoiDung (username, pass, email, TrangThai, vaitro, idLoaiBaoHiem, activation_token, activated)
VALUES 
('new_user1', '', 'newuser1@gmail.com', 'inactive', 'insured_person', NULL, UUID(), FALSE),
('new_user2', '', 'newuser2@gmail.com', 'inactive', 'insured_person', NULL, UUID(), FALSE),
('new_user3', '', 'newuser3@gmail.com', 'inactive', 'insured_person', NULL, UUID(), FALSE);

-- Không vô hiệu hóa khóa ngoại nếu bạn thêm người dùng tương ứng với một loại bảo hiểm không tồn tại
-- SET FOREIGN_KEY_CHECKS = 0; 
-- INSERT INTO NguoiDung ... Các truy vấn chèn dữ liệu
-- SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------------------------
-- 6. Cập nhật thời gian tạo cho một số người dùng (tùy chọn)
-- ----------------------------------------------------------------------------
UPDATE NguoiDung 
SET created_at = DATE_SUB(NOW(), INTERVAL FLOOR(1 + RAND() * 30) DAY)
WHERE id <= 10;

UPDATE NguoiDung 
SET created_at = DATE_SUB(NOW(), INTERVAL FLOOR(1 + RAND() * 15) DAY)
WHERE id > 10 AND id <= 20;

-- ----------------------------------------------------------------------------
-- 7. Kiểm tra dữ liệu đã thêm vào
-- ----------------------------------------------------------------------------
SELECT id, username, email, vaitro, TrangThai, activated, created_at 
FROM NguoiDung 
ORDER BY id;


-- Hướng dẫn thêm dữ liệu cho bảng HopDong
-- Bạn có thể sử dụng các câu lệnh INSERT tương tự để thêm dữ liệu vào bảng HopDong
-- Dau tien drop procedure nay (nho cai lai sau do)
DROP TRIGGER IF EXISTS before_insert_contract;
DELIMITER //
CREATE TRIGGER before_insert_contract
BEFORE INSERT ON HopDong
FOR EACH ROW
BEGIN
    DECLARE role VARCHAR(20);
    
    -- Lấy vai trò của người dùng
    SELECT vaitro INTO role FROM NguoiDung WHERE id = @current_user_id;
    
    -- Chỉ người lập hợp đồng mới có thể tạo hợp đồng mới
    IF role != 'contract_creator' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: Only contract creators can add new contracts';
    END IF;
    
    -- Tự động gán người tạo là người đang đăng nhập
    SET NEW.creator_id = @current_user_id;
    
    -- Ghi log
    INSERT INTO audit_logs (user_id, action_type, table_name, record_id, new_values)
    VALUES (
        @current_user_id,
        'INSERT',
        'HopDong',
        NULL, -- ID sẽ được tạo sau khi INSERT
        JSON_OBJECT(
            'creator_id', NEW.creator_id,
            'idLoaiBaoHiem', NEW.idLoaiBaoHiem,
            'idNguoiBH', NEW.idNguoiBH,
            'ngayKiHD', NEW.ngayKiHD,
            'ngayCatHD', NEW.ngayCatHD
        )
    );
END //
DELIMITER ;

-- ============================================================================
-- THÊM DỮ LIỆU HỢP ĐỒNG VÀ CHI TIẾT HỢP ĐỒNG
-- ============================================================================

-- Tạm thời đặt giá trị cho current_user_id (mô phỏng người dùng đang đăng nhập)
-- Trong thực tế, biến này sẽ được thiết lập khi người dùng đăng nhập
-- Đặt là ID của creatorA
SET @current_user_id = 11;

-- ----------------------------------------------------------------------------
-- 1. Thêm dữ liệu cho bảng HopDong (Bảo hiểm Sức khỏe)
-- ----------------------------------------------------------------------------
INSERT INTO HopDong (creator_id, idLoaiBaoHiem, idNguoiBH, ngayKiHD, ngayCatHD)
VALUES 
(11, 1, 16, '2025-01-15', '2026-01-15'), -- creatorA tạo hợp đồng cho nguyenvana
(11, 1, 17, '2025-01-20', '2026-01-20'), -- creatorA tạo hợp đồng cho tranthib
(11, 1, 18, '2025-02-01', '2026-02-01'), -- creatorA tạo hợp đồng cho levanc
(12, 1, 19, '2025-02-10', '2026-02-10'), -- creatorB tạo hợp đồng cho phamthid
(12, 1, 20, '2025-02-15', '2026-02-15'); -- creatorB tạo hợp đồng cho hoangvane

-- Thay đổi người tạo hợp đồng
SET @current_user_id = 12;

-- ----------------------------------------------------------------------------
-- 2. Thêm dữ liệu cho bảng HopDong (Bảo hiểm Nhân thọ)
-- ----------------------------------------------------------------------------
INSERT INTO HopDong (creator_id, idLoaiBaoHiem, idNguoiBH, ngayKiHD, ngayCatHD)
VALUES 
(12, 2, 21, '2025-03-01', '2030-03-01'), -- creatorB tạo hợp đồng cho nguyenthif
(12, 2, 22, '2025-03-10', '2030-03-10'), -- creatorB tạo hợp đồng cho tran_van_g
(13, 2, 23, '2025-03-15', '2030-03-15'); -- creatorC tạo hợp đồng cho lethih

-- Thay đổi người tạo hợp đồng
SET @current_user_id = 13;

-- ----------------------------------------------------------------------------
-- 3. Thêm dữ liệu cho bảng HopDong (Bảo hiểm Tai nạn)
-- ----------------------------------------------------------------------------
INSERT INTO HopDong (creator_id, idLoaiBaoHiem, idNguoiBH, ngayKiHD, ngayCatHD)
VALUES 
(13, 3, 24, '2025-04-01', '2026-04-01'), -- creatorC tạo hợp đồng cho phamvani
(13, 3, 25, '2025-04-10', '2026-04-10'); -- creatorC tạo hợp đồng cho hoangthik

-- Xác định ID của các hợp đồng đã tạo để thêm chi tiết
-- SELECT * FROM HopDong ORDER BY id;

-- ----------------------------------------------------------------------------
-- 4. Thêm Chi tiết Hợp đồng Bảo hiểm Sức khỏe
-- ----------------------------------------------------------------------------
INSERT INTO ChiTietHopDong (idHopDong, HoTen, gioiTinh, ngaySinh, diachiCoQuan, diachiThuongTru, sodienthoai, lichsuBenh)
VALUES 
(1, 'Nguyễn Văn An', 'male', '1985-06-15', 'Công ty TNHH ABC', 'Số 123 Đường Lê Lợi, Quận 1, TP.HCM', '0912345678', 'Không có tiền sử bệnh'),
(2, 'Trần Thị Bình', 'female', '1990-08-20', 'Công ty CP XYZ', 'Số 456 Đường Nguyễn Huệ, Quận 1, TP.HCM', '0923456789', 'Viêm phổi nhẹ năm 2023'),
(3, 'Lê Văn Cường', 'male', '1982-03-10', 'Trường Đại học ABC', '789 Đường Cách Mạng Tháng 8, Quận 3, TP.HCM', '0934567890', 'Tiểu đường type 2'),
(4, 'Phạm Thị Dung', 'female', '1995-12-05', 'Bệnh viện XYZ', '101 Đường Võ Văn Tần, Quận 3, TP.HCM', '0945678901', 'Không có'),
(5, 'Hoàng Văn Eo', 'male', '1988-07-25', 'Ngân hàng DEF', '202 Đường Lý Tự Trọng, Quận 1, TP.HCM', '0956789012', 'Huyết áp cao');

-- ----------------------------------------------------------------------------
-- 5. Thêm Chi tiết Hợp đồng Bảo hiểm Nhân thọ
-- ----------------------------------------------------------------------------
INSERT INTO ChiTietHopDong (idHopDong, HoTen, gioiTinh, ngaySinh, diachiCoQuan, diachiThuongTru, sodienthoai, lichsuBenh)
VALUES 
(6, 'Nguyễn Thị Phương', 'female', '1975-09-18', 'Công ty Điện lực', '303 Đường Hai Bà Trưng, Quận 1, TP.HCM', '0967890123', 'Không có'),
(7, 'Trần Văn Giang', 'male', '1980-11-30', 'Công ty Vận tải', '404 Đường Nguyễn Đình Chiểu, Quận 3, TP.HCM', '0978901234', 'Phẫu thuật ruột thừa năm 2022'),
(8, 'Lê Thị Hoa', 'female', '1979-04-22', 'Công ty Du lịch', '505 Đường Điện Biên Phủ, Quận Bình Thạnh, TP.HCM', '0989012345', 'Không có');

-- ----------------------------------------------------------------------------
-- 6. Thêm Chi tiết Hợp đồng Bảo hiểm Tai nạn
-- ----------------------------------------------------------------------------
INSERT INTO ChiTietHopDong (idHopDong, HoTen, gioiTinh, ngaySinh, diachiCoQuan, diachiThuongTru, sodienthoai, lichsuBenh)
VALUES 
(9, 'Phạm Văn Ích', 'male', '1992-05-17', 'Công ty Xây dựng', '606 Đường Nguyễn Văn Linh, Quận 7, TP.HCM', '0990123456', 'Gãy tay phải năm 2024'),
(10, 'Hoàng Thị Kim', 'female', '1987-10-08', 'Công ty Thời trang', '707 Đường Võ Thị Sáu, Quận 3, TP.HCM', '0901234567', 'Không có');

-- ----------------------------------------------------------------------------
-- 7. Thêm dữ liệu thanh toán cho các hợp đồng
-- ----------------------------------------------------------------------------
-- Thanh toán cho hợp đồng Bảo hiểm sức khỏe
INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong)
VALUES
(1, '2025-01-15', 5000000),
(1, '2025-04-15', 5000000),
(2, '2025-01-20', 4500000),
(2, '2025-04-20', 4500000),
(3, '2025-02-01', 6000000),
(4, '2025-02-10', 5200000),
(5, '2025-02-15', 4800000);

-- Thanh toán cho hợp đồng Bảo hiểm nhân thọ
INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong)
VALUES
(6, '2025-03-01', 10000000),
(7, '2025-03-10', 12000000),
(8, '2025-03-15', 9500000);

-- Thanh toán cho hợp đồng Bảo hiểm tai nạn
INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong)
VALUES
(9, '2025-04-01', 3000000),
(10, '2025-04-10', 2800000);

-- Kiểm tra dữ liệu hợp đồng đã thêm vào
SELECT hd.id, creator.username AS nguoi_tao, bh.tenBH AS loai_bao_hiem, nd.username AS nguoi_duoc_bao_hiem,
       hd.ngayKiHD, hd.ngayCatHD
FROM HopDong hd
JOIN NguoiDung creator ON hd.creator_id = creator.id
JOIN insurance_types bh ON hd.idLoaiBaoHiem = bh.id
JOIN NguoiDung nd ON hd.idNguoiBH = nd.id
ORDER BY hd.id;

-- Kiểm tra chi tiết hợp đồng
SELECT cthd.id, hd.id AS idHopDong, cthd.HoTen, cthd.gioiTinh, cthd.ngaySinh,
       cthd.diachiCoQuan, cthd.diachiThuongTru, cthd.sodienthoai
FROM ChiTietHopDong cthd
JOIN HopDong hd ON cthd.idHopDong = hd.id
ORDER BY cthd.id;

-- Kiểm tra thanh toán
SELECT tt.id, hd.id AS idHopDong, nd.username AS nguoi_duoc_bao_hiem,
       bh.tenBH AS loai_bao_hiem, tt.ngayDongBaoHiem, tt.soTienDong
FROM ThanhToan tt
JOIN HopDong hd ON tt.idHopDong = hd.id
JOIN NguoiDung nd ON hd.idNguoiBH = nd.id
JOIN insurance_types bh ON hd.idLoaiBaoHiem = bh.id
ORDER BY tt.id;


