-- SQL script to update encryption mechanisms for new fields 
-- Date: May 25, 2025
USE insurance_management;

-- ============================================================================
-- CẬP NHẬT TRIGGER MÃ HÓA ĐỂ BAO GỒM CÁC TRƯỜNG ĐỊA CHỈ MỚI
-- ============================================================================

-- Cập nhật trigger mã hóa khi thêm chi tiết hợp đồng mới
DELIMITER //
DROP TRIGGER IF EXISTS encrypt_contract_detail_insert //
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
    
    -- Mã hóa các trường địa chỉ mới
    SET NEW.diachiTamTru = encrypt_data(NEW.diachiTamTru);
    SET NEW.diachiLienLac = encrypt_data(NEW.diachiLienLac);
    
    SET NEW.sodienthoai = encrypt_data(NEW.sodienthoai);
    SET NEW.lichsuBenh = encrypt_data(NEW.lichsuBenh);
END //
DELIMITER ;

-- Cập nhật trigger mã hóa khi cập nhật chi tiết hợp đồng
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
    
    -- Mã hóa trường địa chỉ tạm trú mới
    IF (OLD.diachiTamTru IS NULL AND NEW.diachiTamTru IS NOT NULL) OR 
       (NEW.diachiTamTru IS NOT NULL AND OLD.diachiTamTru IS NOT NULL AND NEW.diachiTamTru != OLD.diachiTamTru) THEN
        SET NEW.diachiTamTru = encrypt_data(NEW.diachiTamTru);
    END IF;
    
    -- Mã hóa trường địa chỉ liên lạc mới
    IF (OLD.diachiLienLac IS NULL AND NEW.diachiLienLac IS NOT NULL) OR 
       (NEW.diachiLienLac IS NOT NULL AND OLD.diachiLienLac IS NOT NULL AND NEW.diachiLienLac != OLD.diachiLienLac) THEN
        SET NEW.diachiLienLac = encrypt_data(NEW.diachiLienLac);
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
-- CẬP NHẬT STORED PROCEDURES VỚI CÁC TRƯỜNG MỚI
-- ============================================================================

-- Cập nhật thủ tục thêm chi tiết hợp đồng với dữ liệu được mã hóa
DELIMITER //
DROP PROCEDURE IF EXISTS add_contract_detail //
CREATE PROCEDURE add_contract_detail(
    IN p_user_id INT,
    IN p_contract_id INT,
    IN p_ho_ten VARCHAR(100),
    IN p_gioi_tinh ENUM('male', 'female', 'other'),
    IN p_ngay_sinh DATE,
    IN p_diachi_co_quan VARCHAR(100),
    IN p_diachi_thuong_tru VARCHAR(255),
    IN p_diachi_tam_tru VARCHAR(255),
    IN p_diachi_lien_lac VARCHAR(255),
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
        diachiCoQuan, diachiThuongTru, diachiTamTru, diachiLienLac, sodienthoai, lichsuBenh
    ) VALUES (
        p_contract_id, p_ho_ten, p_gioi_tinh, p_ngay_sinh,
        p_diachi_co_quan, p_diachi_thuong_tru, p_diachi_tam_tru, p_diachi_lien_lac, p_sodienthoai, p_lichsu_benh
    );
    
    -- Trả về kết quả JSON
    SELECT JSON_OBJECT(
        'success', TRUE, 
        'message', 'Thêm chi tiết hợp đồng thành công',
        'detail_id', LAST_INSERT_ID()
    ) AS result;
END //
DELIMITER ;

-- Cập nhật thủ tục tạo JSON cho ChiTietHopDong (nếu đã có)
DELIMITER //
DROP PROCEDURE IF EXISTS sp_get_contract_detail_json //
CREATE PROCEDURE sp_get_contract_detail_json(
    IN p_id INT
)
BEGIN
    SELECT JSON_OBJECT(
        'id', ct.id,
        'idHopDong', ct.idHopDong,
        'hoTen', decrypt_data(ct.HoTen),
        'gioiTinh', ct.gioiTinh,
        'ngaySinh', DATE_FORMAT(ct.ngaySinh, '%Y-%m-%d'),
        'diachiCoQuan', IFNULL(decrypt_data(ct.diachiCoQuan), ''),
        'diachiThuongTru', IFNULL(decrypt_data(ct.diachiThuongTru), ''),
        'diachiTamTru', IFNULL(decrypt_data(ct.diachiTamTru), ''),
        'diachiLienLac', IFNULL(decrypt_data(ct.diachiLienLac), ''),
        'sodienthoai', IFNULL(decrypt_data(ct.sodienthoai), ''),
        'lichsuBenh', IFNULL(decrypt_data(ct.lichsuBenh), '')
    ) AS contract_detail
    FROM ChiTietHopDong ct
    WHERE ct.id = p_id;
END //
DELIMITER ;

-- Cập nhật các chế độ xem giải mã cho các vai trò khác nhau
-- Creator view
DELIMITER //
DROP PROCEDURE IF EXISTS get_decrypted_creator_data //
CREATE PROCEDURE get_decrypted_creator_data(IN p_user_id INT)
BEGIN
    SELECT 
        hd.*, 
        nd_insured.username AS insured_username,
        ct.id AS detail_id,
        decrypt_data(ct.HoTen) AS HoTen,
        ct.gioiTinh,
        ct.ngaySinh,
        decrypt_data(ct.diachiCoQuan) AS diachiCoQuan,
        decrypt_data(ct.diachiThuongTru) AS diachiThuongTru,
        decrypt_data(ct.diachiTamTru) AS diachiTamTru,
        decrypt_data(ct.diachiLienLac) AS diachiLienLac,
        decrypt_data(ct.sodienthoai) AS sodienthoai,
        decrypt_data(ct.lichsuBenh) AS lichsuBenh,
        tt.*
    FROM 
        HopDong hd
    JOIN 
        NguoiDung nd_insured ON hd.idNguoiBH = nd_insured.id
    JOIN 
        ChiTietHopDong ct ON hd.id = ct.idHopDong
    LEFT JOIN 
        ThanhToan tt ON hd.id = tt.idHopDong
    WHERE 
        hd.creator_id = p_user_id;
END //
DELIMITER ;

-- Insured person view
DELIMITER //
DROP PROCEDURE IF EXISTS get_decrypted_insured_data //
CREATE PROCEDURE get_decrypted_insured_data(IN p_user_id INT)
BEGIN
    SELECT 
        hd.id AS contract_id,
        hd.idLoaiBaoHiem,
        hd.ngayKiHD,
        hd.ngayCatHD,
        hd.TrangThai,
        hd.giaTriBaoHiem,
        it.tenBH AS loaiBH,
        ct.id AS detail_id,
        decrypt_data(ct.HoTen) AS HoTen,
        ct.gioiTinh,
        ct.ngaySinh,
        decrypt_data(ct.diachiCoQuan) AS diachiCoQuan,
        decrypt_data(ct.diachiThuongTru) AS diachiThuongTru,
        decrypt_data(ct.diachiTamTru) AS diachiTamTru,
        decrypt_data(ct.diachiLienLac) AS diachiLienLac,
        decrypt_data(ct.sodienthoai) AS sodienthoai,
        tt.id AS thanhtoan_id,
        tt.ngayDongBaoHiem,
        tt.soTienDong,
        tt.TrangThai AS trangthaiThanhToan
    FROM 
        HopDong hd
    JOIN 
        insurance_types it ON hd.idLoaiBaoHiem = it.id
    JOIN 
        ChiTietHopDong ct ON hd.id = ct.idHopDong
    LEFT JOIN 
        ThanhToan tt ON hd.id = tt.idHopDong
    WHERE 
        hd.idNguoiBH = p_user_id;
END //
DELIMITER ;

-- Accounting view
DELIMITER //
DROP PROCEDURE IF EXISTS get_decrypted_accounting_data //
CREATE PROCEDURE get_decrypted_accounting_data(IN p_user_id INT)
BEGIN
    DECLARE insurance_type INT;
    
    -- Lấy loại bảo hiểm người dùng kế toán
    SELECT idLoaiBaoHiem INTO insurance_type FROM NguoiDung WHERE id = p_user_id;
    
    SELECT 
        hd.id,
        hd.idLoaiBaoHiem,
        hd.ngayKiHD,
        hd.ngayCatHD,
        hd.TrangThai,
        hd.giaTriBaoHiem,
        decrypt_data(ct.HoTen) AS HoTen,
        ct.gioiTinh,
        ct.ngaySinh,
        decrypt_data(ct.sodienthoai) AS sodienthoai,
        tt.*
    FROM 
        HopDong hd
    JOIN 
        ChiTietHopDong ct ON hd.id = ct.idHopDong
    LEFT JOIN 
        ThanhToan tt ON hd.id = tt.idHopDong
    WHERE 
        hd.idLoaiBaoHiem = insurance_type;
END //
DELIMITER ;

-- Supervisor view
DELIMITER //
DROP PROCEDURE IF EXISTS get_decrypted_supervisor_data //
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
        decrypt_data(ct.diachiTamTru) AS diachiTamTru,
        decrypt_data(ct.diachiLienLac) AS diachiLienLac,
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
-- MÃ HÓA DỮ LIỆU CŨ CHO CÁC TRƯỜNG ĐỊA CHỈ MỚI
-- ============================================================================

-- Thủ tục để mã hóa dữ liệu hiện có cho các trường địa chỉ mới
DELIMITER //
DROP PROCEDURE IF EXISTS encrypt_new_address_fields //
CREATE PROCEDURE encrypt_new_address_fields()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE record_id INT;
    DECLARE v_diachiTamTru VARCHAR(255);
    DECLARE v_diachiLienLac VARCHAR(255);
    DECLARE old_user_id INT;
    
    -- Tạo con trỏ để duyệt qua tất cả các bản ghi
    DECLARE cur CURSOR FOR 
        SELECT id, 
               CONVERT(diachiTamTru USING utf8mb4),
               CONVERT(diachiLienLac USING utf8mb4)
        FROM ChiTietHopDong
        WHERE diachiTamTru IS NOT NULL OR diachiLienLac IS NOT NULL;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Lưu lại giá trị hiện tại của biến session (nếu có)
    SET old_user_id = @current_user_id;
    
    -- Thiết lập quyền admin tạm thời
    SET @current_user_id = 1;
    
    -- Đảm bảo khóa mã hóa đã được khởi tạo
    CALL initialize_encryption();
    
    OPEN cur;
    
    read_loop: LOOP
        FETCH cur INTO record_id, v_diachiTamTru, v_diachiLienLac;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Cập nhật với dữ liệu đã mã hóa
        UPDATE ChiTietHopDong SET 
            diachiTamTru = CASE WHEN v_diachiTamTru IS NOT NULL THEN encrypt_data(v_diachiTamTru) ELSE NULL END,
            diachiLienLac = CASE WHEN v_diachiLienLac IS NOT NULL THEN encrypt_data(v_diachiLienLac) ELSE NULL END
        WHERE id = record_id;
    END LOOP;
    
    CLOSE cur;
    
    -- Khôi phục biến session về giá trị ban đầu
    SET @current_user_id = old_user_id;
    
    SELECT 'New address fields have been encrypted' AS message;
END //
DELIMITER ;

-- ============================================================================
-- TẠO THỐNG KÊ VỀ DỮ LIỆU MÃ HÓA
-- ============================================================================

-- Thống kê số lượng trường được mã hóa theo từng loại bảo hiểm
DELIMITER //
DROP PROCEDURE IF EXISTS sp_ThongKeFieldsMaHoa //
CREATE PROCEDURE sp_ThongKeFieldsMaHoa()
BEGIN
    SELECT 
        it.tenBH AS loai_bao_hiem,
        COUNT(hd.id) AS so_hop_dong,
        SUM(CASE WHEN ct.HoTen IS NOT NULL THEN 1 ELSE 0 END) AS so_ho_ten,
        SUM(CASE WHEN ct.diachiCoQuan IS NOT NULL THEN 1 ELSE 0 END) AS so_dia_chi_co_quan,
        SUM(CASE WHEN ct.diachiThuongTru IS NOT NULL THEN 1 ELSE 0 END) AS so_dia_chi_thuong_tru,
        SUM(CASE WHEN ct.diachiTamTru IS NOT NULL THEN 1 ELSE 0 END) AS so_dia_chi_tam_tru,
        SUM(CASE WHEN ct.diachiLienLac IS NOT NULL THEN 1 ELSE 0 END) AS so_dia_chi_lien_lac,
        SUM(CASE WHEN ct.sodienthoai IS NOT NULL THEN 1 ELSE 0 END) AS so_so_dien_thoai,
        SUM(CASE WHEN ct.lichsuBenh IS NOT NULL THEN 1 ELSE 0 END) AS so_lich_su_benh
    FROM 
        insurance_types it
    LEFT JOIN 
        HopDong hd ON it.id = hd.idLoaiBaoHiem
    LEFT JOIN 
        ChiTietHopDong ct ON hd.id = ct.idHopDong
    GROUP BY 
        it.tenBH
    ORDER BY 
        it.id;
END //
DELIMITER ;
