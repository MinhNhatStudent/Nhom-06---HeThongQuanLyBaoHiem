-- ============================================================================
-- PHẦN 1: KHỞI TẠO MÔI TRƯỜNG MÃ HÓA
-- ============================================================================
USE insurance_management;

-- Tạo bảng lưu trữ khóa mã hóa
CREATE TABLE IF NOT EXISTS chiakhoa (
    id INT AUTO_INCREMENT PRIMARY KEY,
    key_name VARCHAR(50) NOT NULL UNIQUE,
    key_value VARCHAR(64) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT TRUE
);

-- Tạo khóa mã hóa mặc định cho hệ thống
-- Trong môi trường thực tế, khóa này nên được lưu trữ an toàn và được thay đổi định kỳ
DELIMITER //
CREATE PROCEDURE create_encryption_key()
BEGIN
    DECLARE new_key VARCHAR(64);
    -- Tạo khóa ngẫu nhiên 32 bytes (256 bit) được mã hóa base64
    SET new_key = TO_BASE64(RANDOM_BYTES(32));
    
    -- Thêm khóa vào bảng
    INSERT INTO chiakhoa (key_name, key_value)
    VALUES ('system_default_key', new_key);
    
    -- Set biến session cho khóa hiện tại
    SET @encryption_key = new_key;
END //
DELIMITER ;

-- Tạo khóa mã hóa nếu chưa tồn tại
DELIMITER //
CREATE PROCEDURE initialize_encryption()
BEGIN
    IF NOT EXISTS (SELECT 1 FROM chiakhoa WHERE key_name = 'system_default_key') THEN
        CALL create_encryption_key();
    ELSE
        -- Lấy khóa hiện tại
        SELECT key_value INTO @encryption_key FROM chiakhoa 
        WHERE key_name = 'system_default_key' AND active = TRUE
        ORDER BY created_at DESC LIMIT 1;
    END IF;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 2: HÀM MÃ HÓA VÀ GIẢI MÃ
-- ============================================================================

-- Hàm mã hóa dữ liệu
DELIMITER //
CREATE FUNCTION encrypt_data(data TEXT) 
RETURNS VARBINARY(1000)
DETERMINISTIC
BEGIN
    IF data IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Đảm bảo khóa đã được khởi tạo
    IF @encryption_key IS NULL THEN
        CALL initialize_encryption();
    END IF;
    
    -- Mã hóa dữ liệu với AES-256
    RETURN AES_ENCRYPT(data, @encryption_key);
END //
DELIMITER ;

-- Hàm giải mã dữ liệu
DELIMITER //
CREATE FUNCTION decrypt_data(encrypted_data VARBINARY(1000)) 
RETURNS TEXT
DETERMINISTIC
BEGIN
    IF encrypted_data IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Đảm bảo khóa đã được khởi tạo
    IF @encryption_key IS NULL THEN
        CALL initialize_encryption();
    END IF;
    
    -- Giải mã dữ liệu
    RETURN AES_DECRYPT(encrypted_data, @encryption_key);
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 3: THAY ĐỔI CẤU TRÚC BẢNG ĐỂ LƯU TRỮ DỮ LIỆU MÃ HÓA
-- ============================================================================

-- Khởi tạo khóa mã hóa trước khi thay đổi cấu trúc bảng
CALL initialize_encryption();

-- 3.1. Sửa đổi bảng ChiTietHopDong để lưu thông tin nhạy cảm dưới dạng mã hóa
ALTER TABLE ChiTietHopDong 
    MODIFY HoTen VARBINARY(1000),
    MODIFY diachiCoQuan VARBINARY(1000),
    MODIFY diachiThuongTru VARBINARY(1000),
    MODIFY sodienthoai VARBINARY(1000),
    MODIFY lichsuBenh VARBINARY(1000);

-- ============================================================================
-- PHẦN 4: VIEW GIẢI MÃ DỮ LIỆU THEO QUYỀN
-- ============================================================================

-- 4.1. Thủ tục giải mã cho người lập hợp đồng (thay thế decrypted_contract_creator_view)
DROP VIEW IF EXISTS decrypted_contract_creator_view;
DELIMITER //
CREATE PROCEDURE get_decrypted_creator_data(IN p_user_id INT)
BEGIN
    SELECT 
        hd.*,
        ct.id AS detail_id,
        decrypt_data(ct.HoTen) AS HoTen,
        ct.gioiTinh,
        ct.ngaySinh,
        decrypt_data(ct.diachiCoQuan) AS diachiCoQuan,
        decrypt_data(ct.diachiThuongTru) AS diachiThuongTru,
        decrypt_data(ct.sodienthoai) AS sodienthoai,
        decrypt_data(ct.lichsuBenh) AS lichsuBenh,
        tt.*
    FROM 
        HopDong hd
    JOIN 
        ChiTietHopDong ct ON hd.id = ct.idHopDong
    LEFT JOIN 
        ThanhToan tt ON hd.id = tt.idHopDong
    WHERE 
        hd.creator_id = p_user_id;
END //
DELIMITER ;

-- 4.2. Thủ tục giải mã cho người được bảo hiểm (thay thế decrypted_insured_person_view)
DROP VIEW IF EXISTS decrypted_insured_person_view;
DELIMITER //
CREATE PROCEDURE get_decrypted_insured_data(IN p_user_id INT)
BEGIN
    SELECT 
        hd.id, 
        hd.idLoaiBaoHiem, 
        hd.ngayKiHD, 
        hd.ngayCatHD,
        it.tenBH, 
        it.motaHD,
        ct.id AS detail_id,
        decrypt_data(ct.HoTen) AS HoTen,
        ct.gioiTinh,
        ct.ngaySinh,
        decrypt_data(ct.diachiCoQuan) AS diachiCoQuan,
        decrypt_data(ct.diachiThuongTru) AS diachiThuongTru,
        decrypt_data(ct.sodienthoai) AS sodienthoai,
        decrypt_data(ct.lichsuBenh) AS lichsuBenh,
        tt.*
    FROM 
        HopDong hd
    JOIN 
        ChiTietHopDong ct ON hd.id = ct.idHopDong
    JOIN 
        insurance_types it ON hd.idLoaiBaoHiem = it.id
    LEFT JOIN 
        ThanhToan tt ON hd.id = tt.idHopDong
    WHERE 
        hd.idNguoiBH = p_user_id;
END //
DELIMITER ;

-- 4.3. Thủ tục giải mã cho kế toán (thay thế decrypted_accounting_view)
DROP VIEW IF EXISTS decrypted_accounting_view;
DELIMITER //
CREATE PROCEDURE get_decrypted_accounting_data(IN p_user_id INT)
BEGIN
    DECLARE insurance_type INT;
    
    -- Lấy loại bảo hiểm người dùng quản lý
    SELECT idLoaiBaoHiem INTO insurance_type FROM NguoiDung WHERE id = p_user_id;
    
    SELECT 
        hd.id, 
        hd.creator_id, 
        hd.idLoaiBaoHiem, 
        hd.idNguoiBH,
        hd.ngayKiHD, 
        hd.ngayCatHD, 
        hd.created_at,
        nd_creator.username AS creator_username,
        nd_insured.username AS insured_username,
        decrypt_data(ct.HoTen) AS HoTen,
        tt.*
    FROM 
        HopDong hd
    JOIN 
        NguoiDung nd_creator ON hd.creator_id = nd_creator.id
    JOIN 
        NguoiDung nd_insured ON hd.idNguoiBH = nd_insured.id
    JOIN 
        ChiTietHopDong ct ON hd.id = ct.idHopDong
    LEFT JOIN 
        ThanhToan tt ON hd.id = tt.idHopDong
    WHERE 
        hd.idLoaiBaoHiem = insurance_type;
END //
DELIMITER ;

-- 4.4. Thủ tục giải mã cho giám sát (thay thế decrypted_supervisor_view)
DROP VIEW IF EXISTS decrypted_supervisor_view;
DELIMITER //
CREATE PROCEDURE get_decrypted_supervisor_data(IN p_user_id INT)
BEGIN
    DECLARE insurance_type INT;
    
    -- Lấy loại bảo hiểm người dùng giám sát
    SELECT idLoaiBaoHiem INTO insurance_type FROM NguoiDung WHERE id = p_user_id;
    
    SELECT 
        hd.*, 
        nd_creator.username AS creator_username,
        nd_insured.username AS insured_username,
        ct.id AS detail_id,
        decrypt_data(ct.HoTen) AS HoTen,
        ct.gioiTinh,
        ct.ngaySinh,
        decrypt_data(ct.diachiCoQuan) AS diachiCoQuan,
        decrypt_data(ct.diachiThuongTru) AS diachiThuongTru,
        decrypt_data(ct.sodienthoai) AS sodienthoai,
        decrypt_data(ct.lichsuBenh) AS lichsuBenh,
        tt.*
    FROM 
        HopDong hd
    JOIN 
        NguoiDung nd_creator ON hd.creator_id = nd_creator.id
    JOIN 
        NguoiDung nd_insured ON hd.idNguoiBH = nd_insured.id
    JOIN 
        ChiTietHopDong ct ON hd.id = ct.idHopDong
    LEFT JOIN 
        ThanhToan tt ON hd.id = tt.idHopDong
    WHERE 
        hd.idLoaiBaoHiem = insurance_type;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 5: TRIGGER MÃ HÓA DỮ LIỆU TỰ ĐỘNG
-- ============================================================================

-- 5.1. Trigger mã hóa khi thêm chi tiết hợp đồng mới
DELIMITER //
CREATE TRIGGER encrypt_contract_detail_insert
BEFORE INSERT ON ChiTietHopDong
FOR EACH ROW
BEGIN
    -- Đảm bảo khóa đã được khởi tạo
    IF @encryption_key IS NULL THEN
        CALL initialize_encryption();
    END IF;
    
    -- Mã hóa dữ liệu nhạy cảm
    SET NEW.HoTen = encrypt_data(NEW.HoTen);
    SET NEW.diachiCoQuan = encrypt_data(NEW.diachiCoQuan);
    SET NEW.diachiThuongTru = encrypt_data(NEW.diachiThuongTru);
    SET NEW.sodienthoai = encrypt_data(NEW.sodienthoai);
    SET NEW.lichsuBenh = encrypt_data(NEW.lichsuBenh);
END //
DELIMITER ;

-- 5.2. Trigger mã hóa khi cập nhật chi tiết hợp đồng
DELIMITER //
DROP TRIGGER IF EXISTS encrypt_contract_detail_update //
CREATE TRIGGER encrypt_contract_detail_update
BEFORE UPDATE ON ChiTietHopDong
FOR EACH ROW
BEGIN
    -- Đảm bảo khóa đã được khởi tạo
    IF @encryption_key IS NULL THEN
        CALL initialize_encryption();
    END IF;
    
    -- Kiểm tra nếu dữ liệu đầu vào là chuỗi ký tự (chưa mã hóa)
    -- Sử dụng LENGTH để kiểm tra - chuỗi mã hóa thường có độ dài cố định
    IF NEW.HoTen != OLD.HoTen AND (NEW.HoTen IS NULL OR CHAR_LENGTH(CONVERT(NEW.HoTen USING utf8mb4)) > 0) THEN
        SET NEW.HoTen = encrypt_data(NEW.HoTen);
    END IF;
    
    IF NEW.diachiCoQuan != OLD.diachiCoQuan AND (NEW.diachiCoQuan IS NULL OR CHAR_LENGTH(CONVERT(NEW.diachiCoQuan USING utf8mb4)) > 0) THEN
        SET NEW.diachiCoQuan = encrypt_data(NEW.diachiCoQuan);
    END IF;
    
    IF NEW.diachiThuongTru != OLD.diachiThuongTru AND (NEW.diachiThuongTru IS NULL OR CHAR_LENGTH(CONVERT(NEW.diachiThuongTru USING utf8mb4)) > 0) THEN
        SET NEW.diachiThuongTru = encrypt_data(NEW.diachiThuongTru);
    END IF;
    
    IF NEW.sodienthoai != OLD.sodienthoai AND (NEW.sodienthoai IS NULL OR CHAR_LENGTH(CONVERT(NEW.sodienthoai USING utf8mb4)) > 0) THEN
        SET NEW.sodienthoai = encrypt_data(NEW.sodienthoai);
    END IF;
    
    IF NEW.lichsuBenh != OLD.lichsuBenh AND (NEW.lichsuBenh IS NULL OR CHAR_LENGTH(CONVERT(NEW.lichsuBenh USING utf8mb4)) > 0) THEN
        SET NEW.lichsuBenh = encrypt_data(NEW.lichsuBenh);
    END IF;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 6: STORED PROCEDURES THAO TÁC VỚI DỮ LIỆU MÃ HÓA
-- ============================================================================

-- 6.1. Thủ tục thêm chi tiết hợp đồng với dữ liệu được mã hóa
DELIMITER //
CREATE PROCEDURE add_contract_detail(
    IN p_user_id INT,
    IN p_contract_id INT,
    IN p_ho_ten VARCHAR(100),
    IN p_gioi_tinh ENUM('male', 'female', 'other'),
    IN p_ngay_sinh DATE,
    IN p_diachi_co_quan VARCHAR(100),
    IN p_diachi_thuong_tru VARCHAR(255),
    IN p_sodienthoai VARCHAR(255),
    IN p_lichsu_benh TEXT
)
BEGIN
    -- Kiểm tra quyền
    DECLARE is_creator BOOLEAN;
    
    SELECT EXISTS(
        SELECT 1 FROM HopDong 
        WHERE id = p_contract_id AND creator_id = p_user_id
    ) INTO is_creator;
    
    IF NOT is_creator THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: You can only add details to your own contracts';
    END IF;
    
    -- Thêm dữ liệu (sẽ được mã hóa tự động bởi trigger)
    INSERT INTO ChiTietHopDong (
        idHopDong, HoTen, gioiTinh, ngaySinh, 
        diachiCoQuan, diachiThuongTru, sodienthoai, lichsuBenh
    ) VALUES (
        p_contract_id, p_ho_ten, p_gioi_tinh, p_ngay_sinh,
        p_diachi_co_quan, p_diachi_thuong_tru, p_sodienthoai, p_lichsu_benh
    );
    
    SELECT 'Contract detail added successfully' AS message;
END //
DELIMITER ;

-- 6.2. Thủ tục lấy chi tiết hợp đồng với dữ liệu được giải mã
DELIMITER //
DROP PROCEDURE IF EXISTS get_contract_detail //
CREATE PROCEDURE get_contract_detail(
    IN p_user_id INT,
    IN p_contract_id INT
)
BEGIN
    DECLARE role VARCHAR(20);
    DECLARE can_access BOOLEAN;
    
    -- Lấy vai trò của người dùng
    SELECT vaitro INTO role FROM NguoiDung WHERE id = p_user_id;
    
    -- Kiểm tra quyền truy cập
    SELECT can_access_contract(p_user_id, p_contract_id) INTO can_access;
    
    IF NOT can_access THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: You cannot access this contract';
    END IF;
    
    -- Tạm thời đặt biến phiên để thực thi thủ tục
    SET @temp_user_id = p_user_id;
    
    -- Trả về dữ liệu phù hợp với vai trò
    IF role = 'contract_creator' THEN
        CALL get_decrypted_creator_data(p_user_id);
    ELSEIF role = 'insured_person' THEN
        CALL get_decrypted_insured_data(p_user_id);
    ELSEIF role = 'accounting' THEN
        CALL get_decrypted_accounting_data(p_user_id);
    ELSEIF role = 'supervisor' THEN
        CALL get_decrypted_supervisor_data(p_user_id);
    END IF;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 7: MÃ HÓA DỮ LIỆU CŨ
-- ============================================================================

-- Thủ tục để mã hóa dữ liệu cũ đã có trong bảng ChiTietHopDong
DELIMITER //
DROP PROCEDURE IF EXISTS encrypt_existing_data //
CREATE PROCEDURE encrypt_existing_data()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE record_id INT;
    DECLARE v_HoTen VARCHAR(100);
    DECLARE v_diachiCoQuan VARCHAR(100);
    DECLARE v_diachiThuongTru VARCHAR(255);
    DECLARE v_sodienthoai VARCHAR(255);
    DECLARE v_lichsuBenh TEXT;
    DECLARE old_user_id INT;
    
    -- Tạo con trỏ để duyệt qua tất cả các bản ghi
    DECLARE cur CURSOR FOR 
        SELECT id, CONVERT(HoTen USING utf8mb4), 
               CONVERT(diachiCoQuan USING utf8mb4),
               CONVERT(diachiThuongTru USING utf8mb4), 
               CONVERT(sodienthoai USING utf8mb4),
               CONVERT(lichsuBenh USING utf8mb4)
        FROM ChiTietHopDong;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Lưu lại giá trị hiện tại của biến session (nếu có)
    SET old_user_id = @current_user_id;
    
    -- Thiết lập quyền admin tạm thời
    SET @current_user_id = 1;
    
    -- Đảm bảo khóa mã hóa đã được khởi tạo
    CALL initialize_encryption();
    
    OPEN cur;
    
    read_loop: LOOP
        FETCH cur INTO record_id, v_HoTen, v_diachiCoQuan, v_diachiThuongTru, v_sodienthoai, v_lichsuBenh;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Cập nhật với dữ liệu đã mã hóa
        UPDATE ChiTietHopDong SET 
            HoTen = encrypt_data(v_HoTen),
            diachiCoQuan = encrypt_data(v_diachiCoQuan),
            diachiThuongTru = encrypt_data(v_diachiThuongTru),
            sodienthoai = encrypt_data(v_sodienthoai),
            lichsuBenh = encrypt_data(v_lichsuBenh)
        WHERE id = record_id;
    END LOOP;
    
    CLOSE cur;
    
    -- Khôi phục biến session về giá trị ban đầu
    SET @current_user_id = old_user_id;
    
    SELECT 'All existing data has been encrypted' AS message;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 8: THIẾT LẬP KHÓA MÃ HÓA TRONG PHIÊN LÀM VIỆC
-- ============================================================================

-- Thủ tục thiết lập khóa mã hóa cho phiên làm việc
DELIMITER //
CREATE PROCEDURE set_encryption_session_key()
BEGIN
    -- Lấy khóa hiện tại
    SELECT key_value INTO @encryption_key FROM chiakhoa 
    WHERE key_name = 'system_default_key' AND active = TRUE
    ORDER BY created_at DESC LIMIT 1;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 9: CHẠY CÁC BƯỚC KHỞI TẠO
-- ============================================================================

-- Khởi tạo môi trường mã hóa
CALL initialize_encryption();

-- Mã hóa dữ liệu hiện có
CALL encrypt_existing_data();