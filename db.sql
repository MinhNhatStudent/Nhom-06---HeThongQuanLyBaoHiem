-- Thêm ở đầu file để tránh lỗi khi chạy lại nhiều lần
DROP DATABASE IF EXISTS insurance_management2;

-- Tạo cơ sở dữ liệu
CREATE DATABASE insurance_management2;
USE insurance_management2;

-- Bảng insurance_types: Lưu các loại bảo hiểm
CREATE TABLE insurance_types (
    id INT AUTO_INCREMENT PRIMARY KEY,  -- ID duy nhất cho mỗi loại bảo hiểm
    tenBH VARCHAR(100) NOT NULL UNIQUE,  -- Tên loại bảo hiểm
    motaHD TEXT,  -- Mô tả về loại bảo hiểm (tuỳ chọn)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- Thời gian tạo loại bảo hiểm
);

-- Bảng NguoiDung: Lưu thông tin người dùng
CREATE TABLE NguoiDung (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE, -- Tên đăng nhập
    pass VARCHAR(255) NOT NULL, -- Mật khẩu (được mã hóa)
    email VARCHAR(100) NOT NULL UNIQUE, -- Địa chỉ email
    TrangThai ENUM('active', 'inactive') DEFAULT 'inactive', -- Trạng thái tài khoản
    vaitro ENUM('contract_creator', 'insured_person', 'accounting', 'supervisor') NOT NULL, -- Vai trò
    idLoaiBaoHiem INT, -- Loại bảo hiểm mà kế toán hoặc giám sát quản lý (nếu có)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Thời gian tạo tài khoản
    activation_token VARCHAR(255),  -- Token xác nhận tài khoản
    activated BOOLEAN DEFAULT FALSE,  -- Trạng thái tài khoản đã được kích hoạt
    FOREIGN KEY (idLoaiBaoHiem) REFERENCES insurance_types(id) ON DELETE SET NULL
) DEFAULT CHARSET=utf8mb4;

-- Bảng HopDong: Lưu thông tin hợp đồng bảo hiểm
CREATE TABLE HopDong (
    id INT AUTO_INCREMENT PRIMARY KEY,
    creator_id INT NOT NULL, -- Người lập hợp đồng (tham chiếu đến bảng NguoiDung)
    idLoaiBaoHiem INT NOT NULL, -- Loại bảo hiểm (tham chiếu đến bảng insurance_types)
    idNguoiBH INT NOT NULL, -- Người được bảo hiểm (tham chiếu đến bảng NguoiDung)
    ngayKiHD DATE NOT NULL, -- Ngày bắt đầu bảo hiểm
    ngayCatHD DATE NOT NULL, -- Ngày kết thúc hợp đồng
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (creator_id) REFERENCES NguoiDung(id) ON DELETE CASCADE,
    FOREIGN KEY (idNguoiBH) REFERENCES NguoiDung(id) ON DELETE CASCADE,
    FOREIGN KEY (idLoaiBaoHiem) REFERENCES insurance_types(id) ON DELETE CASCADE
) DEFAULT CHARSET=utf8mb4;

-- Bảng ChiTietHopDong: Lưu thông tin chi tiết của người được bảo hiểm
CREATE TABLE ChiTietHopDong (
    id INT AUTO_INCREMENT PRIMARY KEY,
    idHopDong INT NOT NULL, -- Tham chiếu đến hợp đồng bảo hiểm
    HoTen VARCHAR(100) NOT NULL, -- Họ tên
    gioiTinh ENUM('male', 'female', 'other') NOT NULL, -- Phái
    ngaySinh DATE NOT NULL, -- Ngày tháng năm sinh
    diachiCoQuan VARCHAR(100), -- Cơ quan công tác
    diachiThuongTru VARCHAR(255), -- Địa chỉ thường trú
    sodienthoai VARCHAR(255), -- So điện thoại
    lichsuBenh TEXT, -- Lịch sử bệnh (nếu có)
    FOREIGN KEY (idHopDong) REFERENCES HopDong(id) ON DELETE CASCADE
) DEFAULT CHARSET=utf8mb4;

-- Bảng ThanhToan: Lưu thông tin đóng bảo hiểm
CREATE TABLE ThanhToan (
    id INT AUTO_INCREMENT PRIMARY KEY,
    idHopDong INT NOT NULL, -- Tham chiếu đến hợp đồng bảo hiểm
    ngayDongBaoHiem DATE NOT NULL, -- Ngày đóng bảo hiểm
    soTienDong DECIMAL(10, 2) NOT NULL, -- Số tiền đóng
    FOREIGN KEY (idHopDong) REFERENCES HopDong(id) ON DELETE CASCADE
) DEFAULT CHARSET=utf8mb4;

-- Chèn một số loại bảo hiểm vào bảng insurance_types
INSERT INTO insurance_types (tenBH, motaHD)
VALUES
    ('Sức khỏe', 'Bảo hiểm y tế, chăm sóc sức khỏe cho người tham gia'),
    ('Nhân thọ', 'Bảo hiểm tử vong, bảo vệ người tham gia khỏi các rủi ro về tử vong'),
    ('Tai nạn', 'Bảo hiểm tai nạn, bảo vệ người tham gia trong trường hợp bị tai nạn');

-- Ví dụ: Thêm một người dùng và một hợp đồng
-- Thêm người lập hợp đồng
INSERT INTO NguoiDung (username, pass, email, vaitro, TrangThai)
VALUES ('creator_user', SHA2('123456', 256), 'creator@example.com', 'contract_creator', 'active');

-- Thêm người được bảo hiểm
INSERT INTO NguoiDung (username, pass, email, vaitro, TrangThai)
VALUES ('insured_user', SHA2('123456', 256), 'insured@example.com', 'insured_person', 'inactive');

-- Thêm một hợp đồng bảo hiểm giữa người lập hợp đồng và người được bảo hiểm
INSERT INTO HopDong (creator_id, idLoaiBaoHiem, idNguoiBH, ngayKiHD, ngayCatHD)
VALUES (1, 1, 2, '2025-01-01', '2026-01-01');

-- Thêm thông tin chi tiết của người được bảo hiểm
INSERT INTO ChiTietHopDong (idHopDong, HoTen, gioiTinh, ngaySinh, diachiCoQuan, diachiThuongTru, sodienthoai)
VALUES (1, 'Nguyễn Văn A', 'male', '1990-01-01', 'Công ty A', 'Hà Nội', '0912345678');

-- Thêm thông tin thanh toán
INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong)
VALUES (1, '2025-02-01', 500000);

-- Gửi email xác nhận (Bước này sẽ cần thực hiện trong ứng dụng của bạn)
-- Tạo token xác nhận khi tạo hợp đồng thành công
SET @activation_token = UUID();
UPDATE NguoiDung SET activation_token = @activation_token WHERE email = 'insured@example.com';

-- Ví dụ về email xác nhận:
-- Link gửi đến người được bảo hiểm: http://yourwebsite.com/activate?token=UUID12345
-- Khi nhấp vào link, người dùng sẽ được yêu cầu nhập mật khẩu và tài khoản sẽ được kích hoạt.

