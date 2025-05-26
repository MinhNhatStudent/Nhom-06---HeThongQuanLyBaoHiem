-- Tập tin: thanh_toan.sql
USE insurance_management;

-- ============================================================================
-- THÊM DỮ LIỆU THANH TOÁN CHO HỢP ĐỒNG (ĐƯỢC HIỆU CHỈNH)
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
-- 2. Kiểm tra dữ liệu thanh toán hiện có
-- ----------------------------------------------------------------------------
SELECT * FROM ThanhToan ORDER BY id;
-- Xem đã có dữ liệu thanh toán nào chưa

-- ----------------------------------------------------------------------------
-- 3. Thêm dữ liệu thanh toán cho các hợp đồng
-- ----------------------------------------------------------------------------

-- Thanh toán cho hợp đồng Bảo hiểm sức khỏe
INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong)
VALUES
-- Hợp đồng ID 1 và 2 (đã tồn tại trước đó)
(1, '2025-01-15', 5000000),
(1, '2025-04-15', 5000000),
(2, '2025-01-20', 4500000),
(2, '2025-04-20', 4500000);

-- Thanh toán cho hợp đồng sức khỏe mới thêm (ID 13-17)
INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong)
VALUES
(13, '2025-01-15', 6000000),
(13, '2025-04-15', 6000000),
(14, '2025-01-20', 5500000),
(14, '2025-04-20', 5500000),
(15, '2025-02-01', 7000000),
(16, '2025-02-10', 5200000),
(17, '2025-02-15', 4800000);

-- Thanh toán cho hợp đồng bảo hiểm nhân thọ (ID 18-20)
INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong)
VALUES
(18, '2025-03-01', 10000000),
(19, '2025-03-10', 12000000),
(20, '2025-03-15', 9500000);

-- Thanh toán cho hợp đồng bảo hiểm tai nạn (ID 21-22)
INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong)
VALUES
(21, '2025-04-01', 3000000),
(22, '2025-04-10', 2800000);

-- ----------------------------------------------------------------------------
-- 4. Kiểm tra dữ liệu thanh toán sau khi thêm
-- ----------------------------------------------------------------------------
SELECT tt.id, hd.id AS idHopDong, tt.ngayDongBaoHiem, tt.soTienDong,
       nd.username AS nguoi_duoc_bao_hiem, bh.tenBH AS loai_bao_hiem
FROM ThanhToan tt
JOIN HopDong hd ON tt.idHopDong = hd.id
LEFT JOIN NguoiDung nd ON hd.idNguoiBH = nd.id
LEFT JOIN insurance_types bh ON hd.idLoaiBaoHiem = bh.id
ORDER BY tt.id;

-- Kích hoạt lại kiểm tra khóa ngoại
SET FOREIGN_KEY_CHECKS = 1;
