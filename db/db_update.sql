-- SQL script to implement Task 2 changes for the Insurance Management System
-- Date: May 25, 2025

USE insurance_management;

-- ----------------------------------------------------------------
-- 2.1 Thêm trạng thái hợp đồng
-- ----------------------------------------------------------------

-- Thêm trường TrangThai vào bảng HopDong
ALTER TABLE HopDong ADD COLUMN TrangThai ENUM('processing', 'active', 'expired', 'cancelled') 
DEFAULT 'processing' NOT NULL AFTER ngayCatHD;

-- Cập nhật trạng thái cho các hợp đồng hiện có
UPDATE HopDong SET TrangThai = 'active' 
WHERE CURDATE() BETWEEN ngayKiHD AND ngayCatHD;

UPDATE HopDong SET TrangThai = 'expired' 
WHERE CURDATE() > ngayCatHD;

-- Tạo trigger để tự động cập nhật trạng thái dựa trên ngày hiệu lực
DELIMITER //
CREATE TRIGGER update_hopdong_status BEFORE UPDATE ON HopDong
FOR EACH ROW
BEGIN
    DECLARE today DATE;
    SET today = CURDATE();
    
    -- Chỉ tự động cập nhật trạng thái khi không có sự thay đổi trực tiếp từ người dùng
    IF OLD.TrangThai = NEW.TrangThai THEN
        -- Nếu ngày hiện tại lớn hơn ngày kết thúc hợp đồng và trạng thái không phải 'cancelled'
        IF today > NEW.ngayCatHD AND NEW.TrangThai != 'cancelled' THEN
            SET NEW.TrangThai = 'expired';
        -- Nếu ngày hiện tại nằm giữa ngày bắt đầu và kết thúc hợp đồng
        ELSEIF today BETWEEN NEW.ngayKiHD AND NEW.ngayCatHD AND NEW.TrangThai = 'processing' THEN
            SET NEW.TrangThai = 'active';
        END IF;
    END IF;
END //
DELIMITER ;

-- Tạo trigger khi chèn hợp đồng mới
DELIMITER //
CREATE TRIGGER insert_hopdong_status BEFORE INSERT ON HopDong
FOR EACH ROW
BEGIN
    DECLARE today DATE;
    SET today = CURDATE();
    
    -- Nếu ngày bắt đầu hợp đồng là ngày hiện tại hoặc trong quá khứ
    -- và ngày kết thúc hợp đồng là trong tương lai, set trạng thái là 'active'
    IF today BETWEEN NEW.ngayKiHD AND NEW.ngayCatHD THEN
        SET NEW.TrangThai = 'active';
    -- Nếu ngày bắt đầu hợp đồng là trong tương lai, set trạng thái là 'processing'
    ELSEIF today < NEW.ngayKiHD THEN
        SET NEW.TrangThai = 'processing';
    -- Nếu ngày kết thúc hợp đồng là trong quá khứ, set trạng thái là 'expired'
    ELSEIF today > NEW.ngayCatHD THEN
        SET NEW.TrangThai = 'expired';
    END IF;
END //
DELIMITER ;

-- Thủ tục lưu trữ để cập nhật trạng thái hợp đồng
DELIMITER //
CREATE PROCEDURE sp_CapNhatTrangThaiHopDong(IN p_id INT, IN p_trangThai VARCHAR(20))
BEGIN
    -- Kiểm tra tính hợp lệ của trạng thái
    IF p_trangThai NOT IN ('processing', 'active', 'expired', 'cancelled') THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Trạng thái không hợp lệ. Chỉ chấp nhận: processing, active, expired, cancelled';
    ELSE
        UPDATE HopDong SET TrangThai = p_trangThai WHERE id = p_id;
        
        -- Thêm vào nhật ký nếu cần
        -- INSERT INTO AuditLog(...) VALUES (...);
        
        SELECT JSON_OBJECT('success', TRUE, 'message', 'Cập nhật trạng thái hợp đồng thành công') AS result;
    END IF;
END //
DELIMITER ;

-- ----------------------------------------------------------------
-- 2.2 Thêm trạng thái thanh toán
-- ----------------------------------------------------------------

-- Thêm trường TrangThai vào bảng ThanhToan
ALTER TABLE ThanhToan ADD COLUMN TrangThai ENUM('pending', 'completed', 'failed', 'cancelled') 
DEFAULT 'pending' NOT NULL AFTER soTienDong;

-- Cập nhật trạng thái cho các thanh toán hiện có
UPDATE ThanhToan SET TrangThai = 'completed';

-- Thủ tục lưu trữ để xử lý cập nhật thanh toán
DELIMITER //
CREATE PROCEDURE sp_CapNhatTrangThaiThanhToan(
    IN p_id INT, 
    IN p_trangThai VARCHAR(20),
    IN p_ghiChu TEXT
)
BEGIN
    DECLARE v_result JSON;
    
    -- Kiểm tra tính hợp lệ của trạng thái
    IF p_trangThai NOT IN ('pending', 'completed', 'failed', 'cancelled') THEN
        SET v_result = JSON_OBJECT(
            'success', FALSE, 
            'message', 'Trạng thái không hợp lệ. Chỉ chấp nhận: pending, completed, failed, cancelled'
        );
    ELSE
        -- Cập nhật trạng thái thanh toán
        UPDATE ThanhToan SET TrangThai = p_trangThai WHERE id = p_id;
        
        -- Thêm ghi chú nếu cần
        -- ALTER TABLE ThanhToan ADD COLUMN ghiChu TEXT;
        -- UPDATE ThanhToan SET ghiChu = p_ghiChu WHERE id = p_id;
        
        -- Thêm vào nhật ký nếu cần
        -- INSERT INTO AuditLog(...) VALUES (...);
        
        SET v_result = JSON_OBJECT(
            'success', TRUE, 
            'message', 'Cập nhật trạng thái thanh toán thành công'
        );
    END IF;
    
    SELECT v_result AS result;
END //
DELIMITER ;

-- Thủ tục lấy danh sách thanh toán theo trạng thái
DELIMITER //
CREATE PROCEDURE sp_LayDanhSachThanhToanTheoTrangThai(
    IN p_trangThai VARCHAR(20),
    IN p_idHopDong INT
)
BEGIN
    -- Tạo truy vấn SQL động
    SET @where_clause = '';
    
    -- Thêm điều kiện lọc theo trạng thái
    IF p_trangThai IS NOT NULL THEN
        SET @where_clause = CONCAT(@where_clause, ' AND TrangThai = "', p_trangThai, '"');
    END IF;
    
    -- Thêm điều kiện lọc theo hợp đồng
    IF p_idHopDong IS NOT NULL THEN
        SET @where_clause = CONCAT(@where_clause, ' AND idHopDong = ', p_idHopDong);
    END IF;
    
    -- Tạo truy vấn SELECT dữ liệu
    SET @sql_query = CONCAT('
        SELECT 
            JSON_ARRAYAGG(
                JSON_OBJECT(
                    "id", id,
                    "idHopDong", idHopDong,
                    "ngayDongBaoHiem", ngayDongBaoHiem,
                    "soTienDong", soTienDong,
                    "TrangThai", TrangThai
                )
            ) AS result_data
        FROM ThanhToan 
        WHERE 1=1 ', @where_clause, '
        ORDER BY ngayDongBaoHiem DESC'
    );
    
    -- Thực thi truy vấn
    PREPARE stmt FROM @sql_query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
END //
DELIMITER ;

-- ----------------------------------------------------------------
-- 2.3 Thêm địa chỉ tạm trú và địa chỉ liên lạc
-- ----------------------------------------------------------------

-- Thêm trường diachiTamTru và diachiLienLac vào bảng ChiTietHopDong
ALTER TABLE ChiTietHopDong ADD COLUMN diachiTamTru VARCHAR(255) AFTER diachiThuongTru;
ALTER TABLE ChiTietHopDong ADD COLUMN diachiLienLac VARCHAR(255) AFTER diachiTamTru;

-- Thủ tục cập nhật thông tin địa chỉ mới
DELIMITER //
CREATE PROCEDURE sp_CapNhatDiaChiChiTietHopDong(
    IN p_id INT,
    IN p_diachiThuongTru VARCHAR(255),
    IN p_diachiTamTru VARCHAR(255),
    IN p_diachiLienLac VARCHAR(255)
)
BEGIN
    UPDATE ChiTietHopDong 
    SET 
        diachiThuongTru = COALESCE(p_diachiThuongTru, diachiThuongTru),
        diachiTamTru = COALESCE(p_diachiTamTru, diachiTamTru),
        diachiLienLac = COALESCE(p_diachiLienLac, diachiLienLac)
    WHERE id = p_id;
    
    SELECT JSON_OBJECT(
        'success', TRUE, 
        'message', 'Cập nhật địa chỉ thành công'
    ) AS result;
END //
DELIMITER ;

-- ----------------------------------------------------------------
-- 2.4 Thêm giá trị bảo hiểm
-- ----------------------------------------------------------------

-- Thêm trường giaTriBaoHiem vào bảng HopDong
ALTER TABLE HopDong ADD COLUMN giaTriBaoHiem DECIMAL(15, 2) DEFAULT 0 NOT NULL AFTER TrangThai;

-- Thủ tục lưu trữ để tính toán giá trị bảo hiểm
DELIMITER //
CREATE PROCEDURE sp_TinhGiaTriBaoHiem(
    IN p_idHopDong INT
)
BEGIN
    DECLARE v_loaiBaoHiem INT;
    DECLARE v_tuoi INT;
    DECLARE v_ngaySinh DATE;
    DECLARE v_gioiTinh VARCHAR(10);
    DECLARE v_thoiHanBaoHiem INT;
    DECLARE v_ngayKiHD DATE;
    DECLARE v_ngayCatHD DATE;
    DECLARE v_giaTriBaoHiem DECIMAL(15, 2);
    DECLARE v_lichsuBenh TEXT;
    DECLARE v_heSoRuiRo DECIMAL(5, 2) DEFAULT 1.0;
    
    -- Lấy thông tin từ hợp đồng
    SELECT 
        h.idLoaiBaoHiem, 
        h.ngayKiHD, 
        h.ngayCatHD,
        c.ngaySinh,
        c.gioiTinh,
        c.lichsuBenh
    INTO 
        v_loaiBaoHiem, 
        v_ngayKiHD, 
        v_ngayCatHD,
        v_ngaySinh,
        v_gioiTinh,
        v_lichsuBenh
    FROM 
        HopDong h
    JOIN
        ChiTietHopDong c ON h.id = c.idHopDong
    WHERE 
        h.id = p_idHopDong;
    
    -- Tính tuổi
    SET v_tuoi = YEAR(CURDATE()) - YEAR(v_ngaySinh);
    
    -- Tính thời hạn bảo hiểm (tháng)
    SET v_thoiHanBaoHiem = PERIOD_DIFF(
        EXTRACT(YEAR_MONTH FROM v_ngayCatHD),
        EXTRACT(YEAR_MONTH FROM v_ngayKiHD)
    );
    
    -- Tính hệ số rủi ro dựa trên lịch sử bệnh
    IF v_lichsuBenh IS NOT NULL AND LENGTH(v_lichsuBenh) > 0 THEN
        SET v_heSoRuiRo = 1.5;  -- Tăng hệ số nếu có lịch sử bệnh
    END IF;
    
    -- Tính giá trị bảo hiểm theo loại bảo hiểm và thông tin khách hàng
    CASE v_loaiBaoHiem
        -- Loại 1: Sức khỏe
        WHEN 1 THEN 
            -- Công thức: Mức cơ bản + (hệ số tuổi * tuổi) + (hệ số thời hạn * thời hạn)
            SET v_giaTriBaoHiem = 10000000 + (v_tuoi * 100000) + (v_thoiHanBaoHiem * 50000);
            
            -- Điều chỉnh theo giới tính (khác nhau tùy loại bảo hiểm)
            IF v_gioiTinh = 'female' THEN
                SET v_giaTriBaoHiem = v_giaTriBaoHiem * 0.95;  -- Giảm 5% cho nữ
            END IF;
            
        -- Loại 2: Nhân thọ
        WHEN 2 THEN 
            -- Công thức: Mức cơ bản + (hệ số tuổi * tuổi^2) + (hệ số thời hạn * thời hạn)
            SET v_giaTriBaoHiem = 50000000 + (v_tuoi * v_tuoi * 50000) + (v_thoiHanBaoHiem * 100000);
            
            -- Điều chỉnh theo giới tính
            IF v_gioiTinh = 'female' THEN
                SET v_giaTriBaoHiem = v_giaTriBaoHiem * 1.1;  -- Tăng 10% cho nữ
            END IF;
            
        -- Loại 3: Tai nạn
        WHEN 3 THEN 
            -- Công thức: Mức cơ bản + (hệ số tuổi * tuổi) + (hệ số thời hạn * thời hạn)
            SET v_giaTriBaoHiem = 30000000 + (v_tuoi * 80000) + (v_thoiHanBaoHiem * 70000);
            
            -- Không điều chỉnh theo giới tính cho bảo hiểm tai nạn
            
        -- Loại bảo hiểm khác
        ELSE
            SET v_giaTriBaoHiem = 20000000;  -- Giá trị mặc định
    END CASE;
    
    -- Điều chỉnh theo hệ số rủi ro
    SET v_giaTriBaoHiem = v_giaTriBaoHiem * v_heSoRuiRo;
    
    -- Cập nhật giá trị bảo hiểm vào hợp đồng
    UPDATE HopDong SET giaTriBaoHiem = v_giaTriBaoHiem WHERE id = p_idHopDong;
    
    -- Trả về kết quả
    SELECT JSON_OBJECT(
        'success', TRUE, 
        'giaTriBaoHiem', v_giaTriBaoHiem,
        'message', 'Tính toán giá trị bảo hiểm thành công'
    ) AS result;
END //
DELIMITER ;

-- Thủ tục cập nhật giá trị bảo hiểm
DELIMITER //
CREATE PROCEDURE sp_CapNhatGiaTriBaoHiem(
    IN p_idHopDong INT,
    IN p_giaTriBaoHiem DECIMAL(15, 2)
)
BEGIN
    UPDATE HopDong SET giaTriBaoHiem = p_giaTriBaoHiem WHERE id = p_idHopDong;
    
    SELECT JSON_OBJECT(
        'success', TRUE, 
        'message', 'Cập nhật giá trị bảo hiểm thành công'
    ) AS result;
END //
DELIMITER ;

-- Thủ tục tính lại tất cả giá trị bảo hiểm cho hệ thống
DELIMITER //
CREATE PROCEDURE sp_TinhLaiTatCaGiaTriBaoHiem()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_idHopDong INT;
    DECLARE cur CURSOR FOR SELECT id FROM HopDong;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Mở cursor
    OPEN cur;
    
    -- Lặp qua từng hợp đồng
    read_loop: LOOP
        FETCH cur INTO v_idHopDong;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Gọi thủ tục tính giá trị bảo hiểm
        CALL sp_TinhGiaTriBaoHiem(v_idHopDong);
    END LOOP;
    
    -- Đóng cursor
    CLOSE cur;
    
    SELECT JSON_OBJECT(
        'success', TRUE, 
        'message', 'Đã tính lại tất cả giá trị bảo hiểm'
    ) AS result;
END //
DELIMITER ;

-- Tạo trigger để tính giá trị bảo hiểm khi tạo hợp đồng mới
DELIMITER //
CREATE TRIGGER after_hopdong_insert AFTER INSERT ON HopDong
FOR EACH ROW
BEGIN
    -- Gọi thủ tục tính giá trị bảo hiểm
    CALL sp_TinhGiaTriBaoHiem(NEW.id);
END //
DELIMITER ;

-- Tạo trigger để tính lại giá trị bảo hiểm khi cập nhật hợp đồng
DELIMITER //
CREATE TRIGGER after_hopdong_update AFTER UPDATE ON HopDong
FOR EACH ROW
BEGIN
    -- Nếu có thay đổi về ngày bắt đầu hoặc kết thúc, tính lại giá trị bảo hiểm
    IF NEW.ngayKiHD != OLD.ngayKiHD OR NEW.ngayCatHD != OLD.ngayCatHD OR 
       NEW.idLoaiBaoHiem != OLD.idLoaiBaoHiem THEN
        CALL sp_TinhGiaTriBaoHiem(NEW.id);
    END IF;
END //
DELIMITER ;

-- Tạo trigger để tính lại giá trị bảo hiểm khi cập nhật chi tiết hợp đồng
DELIMITER //
CREATE TRIGGER after_chitiethopdong_update AFTER UPDATE ON ChiTietHopDong
FOR EACH ROW
BEGIN
    -- Nếu có thay đổi về ngày sinh, giới tính hoặc lịch sử bệnh, tính lại giá trị bảo hiểm
    IF NEW.ngaySinh != OLD.ngaySinh OR NEW.gioiTinh != OLD.gioiTinh OR 
       ((NEW.lichsuBenh IS NULL AND OLD.lichsuBenh IS NOT NULL) OR 
        (NEW.lichsuBenh IS NOT NULL AND OLD.lichsuBenh IS NULL) OR 
        (NEW.lichsuBenh IS NOT NULL AND OLD.lichsuBenh IS NOT NULL AND NEW.lichsuBenh != OLD.lichsuBenh)) THEN
        CALL sp_TinhGiaTriBaoHiem(NEW.idHopDong);
    END IF;
END //
DELIMITER ;

-- Mã hóa các trường địa chỉ mới như các trường nhạy cảm khác
-- (Thực hiện sau khi tích hợp với mã hóa hiện có)

-- Note: Để tích hợp với các hàm mã hóa hiện có, các trường địa chỉ mới cần được thêm vào
-- bên trong các stored procedures xử lý mã hóa trong tệp mahoa.sql
