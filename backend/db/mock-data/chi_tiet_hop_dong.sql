-- Tập tin: chi_tiet_hop_dong.sql
USE insurance_management;

-- ============================================================================
-- THÊM CHI TIẾT HỢP ĐỒNG (ĐƯỢC HIỆU CHỈNH ĐỂ TRÁNH LỖI KHÓA NGOẠI)
-- ============================================================================

-- Tạm thời vô hiệu hóa kiểm tra khóa ngoại (BẮT BUỘC)
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------------------------------------------------------
-- 1. Kiểm tra ID hợp đồng hiện có
-- ----------------------------------------------------------------------------
-- Chạy lệnh bên dưới để xem các ID hợp đồng hiện có
SELECT id FROM HopDong ORDER BY id;
-- Hiện tại ID hợp đồng là: 1, 2, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22

-- ----------------------------------------------------------------------------
-- 2. Kiểm tra chi tiết hợp đồng hiện có
-- ----------------------------------------------------------------------------
SELECT id, idHopDong FROM ChiTietHopDong ORDER BY id;
-- Hiện tại chỉ có chi tiết cho hợp đồng ID 1 và 2

-- ----------------------------------------------------------------------------
-- 3. Thêm Chi tiết cho các hợp đồng bảo hiểm sức khỏe
-- ----------------------------------------------------------------------------
INSERT INTO ChiTietHopDong (idHopDong, HoTen, gioiTinh, ngaySinh, diachiCoQuan, diachiThuongTru, sodienthoai, lichsuBenh)
VALUES 
(13, 'Lê Văn Cường', 'male', '1982-03-10', 'Trường Đại học ABC', '789 Đường Cách Mạng Tháng 8, Quận 3, TP.HCM', '0934567890', 'Tiểu đường type 2'),
(14, 'Phạm Thị Dung', 'female', '1995-12-05', 'Bệnh viện XYZ', '101 Đường Võ Văn Tần, Quận 3, TP.HCM', '0945678901', 'Không có'),
(15, 'Hoàng Văn Eo', 'male', '1988-07-25', 'Ngân hàng DEF', '202 Đường Lý Tự Trọng, Quận 1, TP.HCM', '0956789012', 'Huyết áp cao'),
(16, 'Nguyễn Thị Phương', 'female', '1975-09-18', 'Công ty Điện lực', '303 Đường Hai Bà Trưng, Quận 1, TP.HCM', '0967890123', 'Không có'),
(17, 'Trần Văn Giang', 'male', '1980-11-30', 'Công ty Vận tải', '404 Đường Nguyễn Đình Chiểu, Quận 3, TP.HCM', '0978901234', 'Phẫu thuật ruột thừa năm 2022');

-- ----------------------------------------------------------------------------
-- 4. Thêm Chi tiết cho các hợp đồng bảo hiểm nhân thọ và tai nạn
-- ----------------------------------------------------------------------------
INSERT INTO ChiTietHopDong (idHopDong, HoTen, gioiTinh, ngaySinh, diachiCoQuan, diachiThuongTru, sodienthoai, lichsuBenh)
VALUES 
(18, 'Lê Thị Hoa', 'female', '1979-04-22', 'Công ty Du lịch', '505 Đường Điện Biên Phủ, Quận Bình Thạnh, TP.HCM', '0989012345', 'Không có'),
(19, 'Phạm Văn Ích', 'male', '1992-05-17', 'Công ty Xây dựng', '606 Đường Nguyễn Văn Linh, Quận 7, TP.HCM', '0990123456', 'Gãy tay phải năm 2024'),
(20, 'Hoàng Thị Kim', 'female', '1987-10-08', 'Công ty Thời trang', '707 Đường Võ Thị Sáu, Quận 3, TP.HCM', '0901234567', 'Không có'),
(21, 'Nguyễn Văn Lâm', 'male', '1990-03-21', 'Công ty Phần mềm ABC', '123 Đường Nguyễn Du, Quận 1, TP.HCM', '0912345678', 'Không có'),
(22, 'Trần Thị Mai', 'female', '1985-07-15', 'Công ty Dược phẩm XYZ', '456 Đường Lê Lợi, Quận 5, TP.HCM', '0923456789', 'Dị ứng nhẹ');

-- ----------------------------------------------------------------------------
-- 5. Kiểm tra chi tiết hợp đồng sau khi thêm
-- ----------------------------------------------------------------------------
SELECT cthd.id, hd.id AS idHopDong, cthd.gioiTinh, cthd.ngaySinh
FROM ChiTietHopDong cthd
JOIN HopDong hd ON cthd.idHopDong = hd.id
ORDER BY cthd.id;

-- Kích hoạt lại kiểm tra khóa ngoại
SET FOREIGN_KEY_CHECKS = 1;
