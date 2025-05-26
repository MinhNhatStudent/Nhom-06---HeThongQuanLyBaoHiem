-- Tập tin: contract_data.sql
USE insurance_management;

-- ============================================================================
-- THÊM DỮ LIỆU HỢP ĐỒNG VÀ CHI TIẾT HỢP ĐỒNG (ĐÃ HIỆU CHỈNH)
-- ============================================================================

-- LƯU Ý QUAN TRỌNG:
-- 1. Tệp này đã được hiệu chỉnh để phù hợp với cấu trúc dữ liệu hiện tại
-- 2. Những phần dữ liệu có thể gây xung đột đã được comment lại
-- 3. Để tránh lỗi khóa ngoại, bạn nên chạy dòng lệnh dưới đây TRƯỚC KHI thêm dữ liệu

-- Tạm thời vô hiệu hóa kiểm tra khóa ngoại (BẮT BUỘC)
SET FOREIGN_KEY_CHECKS = 0;

-- Tạm thời đặt giá trị cho current_user_id (mô phỏng người dùng đang đăng nhập)
-- Trong thực tế, biến này sẽ được thiết lập khi người dùng đăng nhập
-- Đặt là ID của creatorA
SET @current_user_id = 31; -- ID của creatorA trong bảng NguoiDung

-- ----------------------------------------------------------------------------
-- 1. Thêm dữ liệu cho bảng HopDong (Bảo hiểm Sức khỏe)
-- ----------------------------------------------------------------------------
INSERT INTO HopDong (creator_id, idLoaiBaoHiem, idNguoiBH, ngayKiHD, ngayCatHD)
VALUES 
(31, 1, 36, '2025-01-15', '2026-01-15'), -- creatorA tạo hợp đồng cho nguyenvana
(31, 1, 37, '2025-01-20', '2026-01-20'), -- creatorA tạo hợp đồng cho tranthib
(31, 1, 38, '2025-02-01', '2026-02-01'), -- creatorA tạo hợp đồng cho levanc
(32, 1, 39, '2025-02-10', '2026-02-10'), -- creatorB tạo hợp đồng cho phamthid
(32, 1, 40, '2025-02-15', '2026-02-15'); -- creatorB tạo hợp đồng cho hoangvane

-- Thay đổi người tạo hợp đồng
SET @current_user_id = 32; -- ID của creatorB trong bảng NguoiDung

-- ----------------------------------------------------------------------------
-- 2. Thêm dữ liệu cho bảng HopDong (Bảo hiểm Nhân thọ)
-- ----------------------------------------------------------------------------
INSERT INTO HopDong (creator_id, idLoaiBaoHiem, idNguoiBH, ngayKiHD, ngayCatHD)
VALUES 
(32, 2, 41, '2025-03-01', '2030-03-01'), -- creatorB tạo hợp đồng cho nguyenthif
(32, 2, 42, '2025-03-10', '2030-03-10'), -- creatorB tạo hợp đồng cho tran_van_g
(33, 2, 43, '2025-03-15', '2030-03-15'); -- creatorC tạo hợp đồng cho lethih

-- Thay đổi người tạo hợp đồng
SET @current_user_id = 33; -- ID của creatorC trong bảng NguoiDung

-- ----------------------------------------------------------------------------
-- 3. Thêm dữ liệu cho bảng HopDong (Bảo hiểm Tai nạn)
-- ----------------------------------------------------------------------------
INSERT INTO HopDong (creator_id, idLoaiBaoHiem, idNguoiBH, ngayKiHD, ngayCatHD)
VALUES 
(33, 3, 44, '2025-04-01', '2026-04-01'), -- creatorC tạo hợp đồng cho phamvani
(33, 3, 45, '2025-04-10', '2026-04-10'); -- creatorC tạo hợp đồng cho hoangthik

-- Xác định ID của các hợp đồng đã tạo để thêm chi tiết
-- SELECT * FROM HopDong ORDER BY id;

-- ----------------------------------------------------------------------------
-- 4. Thêm Chi tiết Hợp đồng
-- ----------------------------------------------------------------------------
-- Ghi chú: Bỏ qua phần insert chi tiết hợp đồng vì đã có dữ liệu
-- Dữ liệu hiện có trong bảng ChiTietHopDong có cấu trúc khác với dự kiến ban đầu
-- Các trường dữ liệu đã được mã hóa thành dạng binary

/* 
-- CHỈ SỬ DỤNG KHI CẦN INSERT MỚI và đã kiểm tra cấu trúc bảng và ID hợp đồng
-- LƯU Ý: ID hợp đồng trong bảng HopDong hiện tại là: 1, 2, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22

-- Thêm chi tiết cho các hợp đồng bảo hiểm sức khỏe (sử dụng các ID tương ứng)
INSERT INTO ChiTietHopDong (idHopDong, HoTen, gioiTinh, ngaySinh, diachiCoQuan, diachiThuongTru, sodienthoai, lichsuBenh)
VALUES 
(13, 'Lê Văn Cường', 'male', '1982-03-10', 'Trường Đại học ABC', '789 Đường Cách Mạng Tháng 8, Quận 3, TP.HCM', '0934567890', 'Tiểu đường type 2'),
(14, 'Phạm Thị Dung', 'female', '1995-12-05', 'Bệnh viện XYZ', '101 Đường Võ Văn Tần, Quận 3, TP.HCM', '0945678901', 'Không có'),
(15, 'Hoàng Văn Eo', 'male', '1988-07-25', 'Ngân hàng DEF', '202 Đường Lý Tự Trọng, Quận 1, TP.HCM', '0956789012', 'Huyết áp cao'),
(16, 'Nguyễn Thị Phương', 'female', '1975-09-18', 'Công ty Điện lực', '303 Đường Hai Bà Trưng, Quận 1, TP.HCM', '0967890123', 'Không có'),
(17, 'Trần Văn Giang', 'male', '1980-11-30', 'Công ty Vận tải', '404 Đường Nguyễn Đình Chiểu, Quận 3, TP.HCM', '0978901234', 'Phẫu thuật ruột thừa năm 2022');

-- Thêm chi tiết cho các hợp đồng bảo hiểm nhân thọ và tai nạn
INSERT INTO ChiTietHopDong (idHopDong, HoTen, gioiTinh, ngaySinh, diachiCoQuan, diachiThuongTru, sodienthoai, lichsuBenh)
VALUES 
(18, 'Lê Thị Hoa', 'female', '1979-04-22', 'Công ty Du lịch', '505 Đường Điện Biên Phủ, Quận Bình Thạnh, TP.HCM', '0989012345', 'Không có'),
(19, 'Phạm Văn Ích', 'male', '1992-05-17', 'Công ty Xây dựng', '606 Đường Nguyễn Văn Linh, Quận 7, TP.HCM', '0990123456', 'Gãy tay phải năm 2024'),
(20, 'Hoàng Thị Kim', 'female', '1987-10-08', 'Công ty Thời trang', '707 Đường Võ Thị Sáu, Quận 3, TP.HCM', '0901234567', 'Không có'),
(21, 'Nguyễn Văn Lâm', 'male', '1990-03-21', 'Công ty Phần mềm ABC', '123 Đường Nguyễn Du, Quận 1, TP.HCM', '0912345678', 'Không có'),
(22, 'Trần Thị Mai', 'female', '1985-07-15', 'Công ty Dược phẩm XYZ', '456 Đường Lê Lợi, Quận 5, TP.HCM', '0923456789', 'Dị ứng nhẹ');
*/

-- ----------------------------------------------------------------------------
-- 7. Thêm dữ liệu thanh toán cho các hợp đồng
-- ----------------------------------------------------------------------------
-- Lưu ý: Trước khi thêm dữ liệu thanh toán, hãy kiểm tra ID của các hợp đồng đã tạo
-- Chạy câu lệnh sau để xem ID hợp đồng: 
-- SELECT * FROM HopDong ORDER BY id;

/* 
-- Mẫu câu lệnh thêm dữ liệu thanh toán
-- Thanh toán cho hợp đồng Bảo hiểm sức khỏe (thay thế [ID] bằng ID hợp đồng thực tế)
INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong)
VALUES
([ID], CURRENT_DATE(), 5000000),
([ID], DATE_ADD(CURRENT_DATE(), INTERVAL 3 MONTH), 5000000);
*/

-- Đoạn code bên dưới đã được điều chỉnh để sử dụng các ID hợp đồng thực tế
-- Hãy bỏ comment để thêm dữ liệu thanh toán

/*
-- Thanh toán cho hợp đồng Bảo hiểm sức khỏe
INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong)
VALUES
-- Hợp đồng ID 1 và 2 (đã tồn tại trước đó)
(1, '2025-01-15', 5000000),
(1, '2025-04-15', 5000000),
(2, '2025-01-20', 4500000),
(2, '2025-04-20', 4500000),

-- Hợp đồng ID 13-17 (bảo hiểm sức khỏe đã thêm mới)
(13, '2025-01-15', 6000000),
(13, '2025-04-15', 6000000),
(14, '2025-01-20', 5500000),
(14, '2025-04-20', 5500000),
(15, '2025-02-01', 7000000),
(16, '2025-02-10', 5200000),
(17, '2025-02-15', 4800000);

-- Thanh toán cho hợp đồng bảo hiểm nhân thọ và tai nạn
INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong)
VALUES
(18, '2025-03-01', 10000000),
(19, '2025-03-10', 12000000),
(20, '2025-03-15', 9500000),
(21, '2025-04-01', 3000000),
(22, '2025-04-10', 2800000);
*/

-- Kích hoạt lại kiểm tra khóa ngoại (BẮT BUỘC)
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- KIỂM TRA DỮ LIỆU
-- ============================================================================

-- Kiểm tra dữ liệu người dùng - xem người dùng đã được thêm vào hay chưa
SELECT id, username, email, vaitro, TrangThai, activated, created_at 
FROM NguoiDung 
WHERE vaitro IN ('contract_creator', 'insured_person')
ORDER BY vaitro, id;

-- Kiểm tra dữ liệu hợp đồng đã thêm vào
SELECT hd.id, creator.username AS nguoi_tao, bh.tenBH AS loai_bao_hiem, nd.username AS nguoi_duoc_bao_hiem,
       hd.ngayKiHD, hd.ngayCatHD
FROM HopDong hd
LEFT JOIN NguoiDung creator ON hd.creator_id = creator.id
LEFT JOIN insurance_types bh ON hd.idLoaiBaoHiem = bh.id
LEFT JOIN NguoiDung nd ON hd.idNguoiBH = nd.id
ORDER BY hd.id;

-- Kiểm tra chi tiết hợp đồng (chỉ hiển thị một số trường vì dữ liệu có thể đã được mã hóa)
SELECT cthd.id, hd.id AS idHopDong, cthd.gioiTinh, cthd.ngaySinh
FROM ChiTietHopDong cthd
JOIN HopDong hd ON cthd.idHopDong = hd.id
ORDER BY cthd.id;

-- Kiểm tra thanh toán
SELECT tt.id, hd.id AS idHopDong, tt.ngayDongBaoHiem, tt.soTienDong,
       nd.username AS nguoi_duoc_bao_hiem, bh.tenBH AS loai_bao_hiem
FROM ThanhToan tt
JOIN HopDong hd ON tt.idHopDong = hd.id
LEFT JOIN NguoiDung nd ON hd.idNguoiBH = nd.id
LEFT JOIN insurance_types bh ON hd.idLoaiBaoHiem = bh.id
ORDER BY tt.id;
