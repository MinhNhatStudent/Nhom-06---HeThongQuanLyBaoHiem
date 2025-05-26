-- ============================================================================
-- PHẦN 1: KHỞI TẠO DATABASE
-- ============================================================================
USE insurance_management;

-- ============================================================================
-- PHẦN 2: RBAC PHÂN QUYỀN THEO VAI TRÒ
-- ============================================================================


-- 1. Stored Procedure cho Người lập hợp đồng (thay thế contract_creator_view)
DROP VIEW IF EXISTS contract_creator_view;
DELIMITER //
CREATE PROCEDURE get_contract_creator_data(IN p_user_id INT)
BEGIN
    SELECT hd.*, ct.*, tt.*
    FROM HopDong hd
    JOIN ChiTietHopDong ct ON hd.id = ct.idHopDong
    LEFT JOIN ThanhToan tt ON hd.id = tt.idHopDong
    WHERE hd.creator_id = p_user_id;
END //
DELIMITER ;

-- 2. Stored Procedure cho Người được bảo hiểm (thay thế insured_person_view)
DROP VIEW IF EXISTS insured_person_view;
DELIMITER //
CREATE PROCEDURE get_insured_person_data(IN p_user_id INT)
BEGIN
    SELECT hd.id, hd.idLoaiBaoHiem, hd.ngayKiHD, hd.ngayCatHD, 
           it.tenBH, it.motaHD,
           ct.*, tt.*
    FROM HopDong hd
    JOIN ChiTietHopDong ct ON hd.id = ct.idHopDong
    JOIN insurance_types it ON hd.idLoaiBaoHiem = it.id
    LEFT JOIN ThanhToan tt ON hd.id = tt.idHopDong
    WHERE hd.idNguoiBH = p_user_id;
END //
DELIMITER ;

-- 3. Stored Procedure cho Kế toán (thay thế accounting_view)
DROP VIEW IF EXISTS accounting_view;
DELIMITER //
CREATE PROCEDURE get_accounting_data(IN p_user_id INT)
BEGIN
    DECLARE insurance_type INT;
    
    -- Lấy loại bảo hiểm người dùng quản lý
    SELECT idLoaiBaoHiem INTO insurance_type FROM NguoiDung WHERE id = p_user_id;
    
    SELECT hd.id, hd.creator_id, hd.idLoaiBaoHiem, hd.idNguoiBH, 
           hd.ngayKiHD, hd.ngayCatHD, hd.created_at,
           nd_creator.username AS creator_username,
           nd_insured.username AS insured_username,
           tt.*
    FROM HopDong hd
    JOIN NguoiDung nd_creator ON hd.creator_id = nd_creator.id
    JOIN NguoiDung nd_insured ON hd.idNguoiBH = nd_insured.id
    LEFT JOIN ThanhToan tt ON hd.id = tt.idHopDong
    WHERE hd.idLoaiBaoHiem = insurance_type;
END //
DELIMITER ;

-- 4. Stored Procedure cho Giám sát (thay thế supervisor_view)
DROP VIEW IF EXISTS supervisor_view;
DELIMITER //
CREATE PROCEDURE get_supervisor_data(IN p_user_id INT)
BEGIN
    DECLARE insurance_type INT;
    
    -- Lấy loại bảo hiểm người dùng giám sát
    SELECT idLoaiBaoHiem INTO insurance_type FROM NguoiDung WHERE id = p_user_id;
    
    SELECT hd.*, nd_creator.username AS creator_username, 
           nd_insured.username AS insured_username,
           ct.*, tt.*
    FROM HopDong hd
    JOIN NguoiDung nd_creator ON hd.creator_id = nd_creator.id
    JOIN NguoiDung nd_insured ON hd.idNguoiBH = nd_insured.id
    JOIN ChiTietHopDong ct ON hd.id = ct.idHopDong
    LEFT JOIN ThanhToan tt ON hd.id = tt.idHopDong
    WHERE hd.idLoaiBaoHiem = insurance_type;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 3: HÀM KIỂM TRA QUYỀN TRUY CẬP
-- ============================================================================

-- 3.1. Hàm kiểm tra quyền truy cập hợp đồng
DELIMITER //
CREATE FUNCTION can_access_contract(user_id INT, contract_id INT) 
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE role VARCHAR(20);
    DECLARE insurance_type INT;
    DECLARE result BOOLEAN;
    
    -- Lấy vai trò của người dùng
    SELECT vaitro, idLoaiBaoHiem INTO role, insurance_type FROM NguoiDung WHERE id = user_id;
    
    -- Kiểm tra quyền dựa trên vai trò
    IF role = 'contract_creator' THEN
        SELECT EXISTS(SELECT 1 FROM HopDong WHERE id = contract_id AND creator_id = user_id) INTO result;
    ELSEIF role = 'insured_person' THEN
        SELECT EXISTS(SELECT 1 FROM HopDong WHERE id = contract_id AND idNguoiBH = user_id) INTO result;
    ELSEIF role = 'accounting' OR role = 'supervisor' THEN
        SELECT EXISTS(
            SELECT 1 FROM HopDong 
            WHERE id = contract_id AND idLoaiBaoHiem = insurance_type
        ) INTO result;
    ELSE
        SET result = FALSE;
    END IF;
    
    RETURN result;
END //
DELIMITER ;

-- 3.2. Hàm kiểm tra quyền chỉnh sửa hợp đồng
DELIMITER //
CREATE FUNCTION can_edit_contract(user_id INT, contract_id INT) 
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE role VARCHAR(20);
    
    -- Lấy vai trò của người dùng
    SELECT vaitro INTO role FROM NguoiDung WHERE id = user_id;
    
    -- Chỉ người lập hợp đồng có thể chỉnh sửa, và chỉ những hợp đồng họ đã tạo
    IF role = 'contract_creator' THEN
        RETURN EXISTS(SELECT 1 FROM HopDong WHERE id = contract_id AND creator_id = user_id);
    ELSE
        RETURN FALSE;
    END IF;
END //
DELIMITER ;

-- 3.3. Hàm kiểm tra quyền chỉnh sửa chi tiết hợp đồng
DELIMITER //
CREATE FUNCTION can_edit_contract_detail(user_id INT, contract_detail_id INT) 
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE contract_id INT;
    
    -- Lấy id hợp đồng từ chi tiết hợp đồng
    SELECT idHopDong INTO contract_id FROM ChiTietHopDong WHERE id = contract_detail_id;
    
    -- Sử dụng lại hàm kiểm tra quyền edit hợp đồng
    RETURN can_edit_contract(user_id, contract_id);
END //
DELIMITER ;

-- 3.4. Hàm kiểm tra quyền quản lý thanh toán
DELIMITER //
CREATE FUNCTION can_manage_payment(user_id INT, hop_dong_id INT) 
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE role VARCHAR(20);
    DECLARE insurance_type INT;
    DECLARE contract_insurance_type INT;
    
    -- Lấy vai trò và loại bảo hiểm của người dùng
    SELECT vaitro, idLoaiBaoHiem INTO role, insurance_type 
    FROM NguoiDung 
    WHERE id = user_id;
    
    -- Lấy loại bảo hiểm của hợp đồng
    SELECT idLoaiBaoHiem INTO contract_insurance_type 
    FROM HopDong 
    WHERE id = hop_dong_id;
    
    -- Kiểm tra quyền: Kế toán quản lý thanh toán cho loại bảo hiểm họ phụ trách
    -- Người tạo hợp đồng cũng có thể thêm thanh toán
    IF (role = 'accounting' AND insurance_type = contract_insurance_type) OR
       (role = 'contract_creator' AND EXISTS(SELECT 1 FROM HopDong WHERE id = hop_dong_id AND creator_id = user_id)) THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END //
DELIMITER ;

-- 3.5. Hàm kiểm tra quyền quản lý người dùng
DELIMITER //
CREATE FUNCTION is_admin(user_id INT) 
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    -- Giả sử bạn xác định admin bằng cách kiểm tra một giá trị cụ thể
    -- Bạn có thể thay đổi logic này tùy theo cách hệ thống xác định admin
    RETURN user_id = 1; -- Giả sử user ID 1 là admin
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 4: STORED PROCEDURES XỬ LÝ DỮ LIỆU
-- ============================================================================

-- 4.1. Thủ tục lấy danh sách hợp đồng theo quyền người dùng
DELIMITER //
CREATE PROCEDURE get_contracts_for_user(IN user_id INT)
BEGIN
    DECLARE role VARCHAR(20);
    DECLARE insurance_type INT;
    
    -- Lấy vai trò của người dùng
    SELECT vaitro, idLoaiBaoHiem INTO role, insurance_type FROM NguoiDung WHERE id = user_id;
    
    -- Trả về dữ liệu dựa trên vai trò
    IF role = 'contract_creator' THEN
        SELECT * FROM HopDong WHERE creator_id = user_id;
    ELSEIF role = 'insured_person' THEN
        SELECT * FROM HopDong WHERE idNguoiBH = user_id;
    ELSEIF role = 'accounting' OR role = 'supervisor' THEN
        SELECT * FROM HopDong WHERE idLoaiBaoHiem = insurance_type;
    END IF;
END //
DELIMITER ;

-- 4.2. Thủ tục cập nhật hợp đồng với kiểm tra quyền
DELIMITER //
CREATE PROCEDURE update_contract(
    IN p_user_id INT,
    IN p_contract_id INT,
    IN p_idLoaiBaoHiem INT,
    IN p_ngayKiHD DATE,
    IN p_ngayCatHD DATE
)
BEGIN
    -- Kiểm tra quyền chỉnh sửa
    IF can_edit_contract(p_user_id, p_contract_id) THEN
        UPDATE HopDong 
        SET idLoaiBaoHiem = p_idLoaiBaoHiem,
            ngayKiHD = p_ngayKiHD,
            ngayCatHD = p_ngayCatHD
        WHERE id = p_contract_id;
        SELECT 'Contract updated successfully' AS message;
    ELSE
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: You cannot edit this contract';
    END IF;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 5: HỆ THỐNG GHI LOG (AUDIT)
-- ============================================================================

-- Bảng lưu trữ log các thay đổi dữ liệu
CREATE TABLE audit_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action_type ENUM('INSERT', 'UPDATE', 'DELETE'),
    table_name VARCHAR(50),
    record_id INT,
    old_values TEXT,
    new_values TEXT,
    action_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES NguoiDung(id)
);

-- ============================================================================
-- PHẦN 6: TRIGGERS CHO BẢNG HOPDONG
-- ============================================================================

-- 6.1. Trigger kiểm tra quyền và ghi log khi cập nhật hợp đồng
DELIMITER //
CREATE TRIGGER before_update_contract
BEFORE UPDATE ON HopDong
FOR EACH ROW
BEGIN
    -- @current_user_id phải được thiết lập trong phiên làm việc của ứng dụng
    IF NOT can_edit_contract(@current_user_id, OLD.id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: You cannot update this contract';
    END IF;
    
    -- Ghi log sự thay đổi
    INSERT INTO audit_logs (user_id, action_type, table_name, record_id, old_values, new_values)
    VALUES (
        @current_user_id,
        'UPDATE',
        'HopDong',
        OLD.id,
        JSON_OBJECT(
            'idLoaiBaoHiem', OLD.idLoaiBaoHiem,
            'ngayKiHD', OLD.ngayKiHD,
            'ngayCatHD', OLD.ngayCatHD
        ),
        JSON_OBJECT(
            'idLoaiBaoHiem', NEW.idLoaiBaoHiem,
            'ngayKiHD', NEW.ngayKiHD,
            'ngayCatHD', NEW.ngayCatHD
        )
    );
END //
DELIMITER ;

-- 6.2. Trigger kiểm tra quyền khi thêm hợp đồng mới
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

-- 6.3. Trigger kiểm tra quyền khi xóa hợp đồng
DELIMITER //
CREATE TRIGGER before_delete_contract
BEFORE DELETE ON HopDong
FOR EACH ROW
BEGIN
    -- Kiểm tra quyền xóa (chỉ người tạo hợp đồng mới được xóa hợp đồng đó)
    IF NOT can_edit_contract(@current_user_id, OLD.id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: You cannot delete this contract';
    END IF;
    
    -- Ghi log trước khi xóa
    INSERT INTO audit_logs (user_id, action_type, table_name, record_id, old_values)
    VALUES (
        @current_user_id,
        'DELETE',
        'HopDong',
        OLD.id,
        JSON_OBJECT(
            'creator_id', OLD.creator_id,
            'idLoaiBaoHiem', OLD.idLoaiBaoHiem,
            'idNguoiBH', OLD.idNguoiBH,
            'ngayKiHD', OLD.ngayKiHD,
            'ngayCatHD', OLD.ngayCatHD
        )
    );
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 7: TRIGGERS CHO BẢNG CHITIETHOPDONG
-- ============================================================================

-- 7.1. Trigger khi thêm chi tiết hợp đồng
DELIMITER //
CREATE TRIGGER before_insert_contract_detail
BEFORE INSERT ON ChiTietHopDong
FOR EACH ROW
BEGIN
    DECLARE creator_id INT;
    
    -- Lấy creator_id của hợp đồng
    SELECT creator_id INTO creator_id FROM HopDong WHERE id = NEW.idHopDong;
    
    -- Kiểm tra xem người đang thực hiện có phải là người tạo hợp đồng không
    IF creator_id != @current_user_id THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: Only contract creator can add details';
    END IF;
    
    -- Ghi log
    INSERT INTO audit_logs (user_id, action_type, table_name, record_id, new_values)
    VALUES (
        @current_user_id,
        'INSERT',
        'ChiTietHopDong',
        NULL,
        JSON_OBJECT(
            'idHopDong', NEW.idHopDong,
            'HoTen', NEW.HoTen,
            'gioiTinh', NEW.gioiTinh,
            'ngaySinh', NEW.ngaySinh,
            'diachiCoQuan', NEW.diachiCoQuan,
            'diachiThuongTru', NEW.diachiThuongTru,
            'sodienthoai', NEW.sodienthoai,
            'lichsuBenh', NEW.lichsuBenh
        )
    );
END //
DELIMITER ;

-- 7.2. Trigger khi cập nhật chi tiết hợp đồng
DELIMITER //
CREATE TRIGGER before_update_contract_detail
BEFORE UPDATE ON ChiTietHopDong
FOR EACH ROW
BEGIN
    -- Kiểm tra quyền chỉnh sửa
    IF NOT can_edit_contract_detail(@current_user_id, OLD.id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: You cannot update this contract detail';
    END IF;
    
    -- Ghi log
    INSERT INTO audit_logs (user_id, action_type, table_name, record_id, old_values, new_values)
    VALUES (
        @current_user_id,
        'UPDATE',
        'ChiTietHopDong',
        OLD.id,
        JSON_OBJECT(
            'HoTen', OLD.HoTen,
            'gioiTinh', OLD.gioiTinh,
            'ngaySinh', OLD.ngaySinh,
            'diachiCoQuan', OLD.diachiCoQuan,
            'diachiThuongTru', OLD.diachiThuongTru,
            'sodienthoai', OLD.sodienthoai,
            'lichsuBenh', OLD.lichsuBenh
        ),
        JSON_OBJECT(
            'HoTen', NEW.HoTen,
            'gioiTinh', NEW.gioiTinh,
            'ngaySinh', NEW.ngaySinh,
            'diachiCoQuan', NEW.diachiCoQuan,
            'diachiThuongTru', NEW.diachiThuongTru,
            'sodienthoai', NEW.sodienthoai,
            'lichsuBenh', NEW.lichsuBenh
        )
    );
END //
DELIMITER ;

-- 7.3. Trigger khi xóa chi tiết hợp đồng
DELIMITER //
CREATE TRIGGER before_delete_contract_detail
BEFORE DELETE ON ChiTietHopDong
FOR EACH ROW
BEGIN
    -- Kiểm tra quyền xóa
    IF NOT can_edit_contract_detail(@current_user_id, OLD.id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: You cannot delete this contract detail';
    END IF;
    
    -- Ghi log
    INSERT INTO audit_logs (user_id, action_type, table_name, record_id, old_values)
    VALUES (
        @current_user_id,
        'DELETE',
        'ChiTietHopDong',
        OLD.id,
        JSON_OBJECT(
            'idHopDong', OLD.idHopDong,
            'HoTen', OLD.HoTen,
            'gioiTinh', OLD.gioiTinh,
            'ngaySinh', OLD.ngaySinh,
            'diachiCoQuan', OLD.diachiCoQuan,
            'diachiThuongTru', OLD.diachiThuongTru,
            'sodienthoai', OLD.sodienthoai,
            'lichsuBenh', OLD.lichsuBenh
        )
    );
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 8: TRIGGERS CHO BẢNG THANHTOAN
-- ============================================================================

-- 8.1. Trigger khi thêm thanh toán
DELIMITER //
CREATE TRIGGER before_insert_payment
BEFORE INSERT ON ThanhToan
FOR EACH ROW
BEGIN
    -- Kiểm tra quyền thêm thanh toán
    IF NOT can_manage_payment(@current_user_id, NEW.idHopDong) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: You cannot add payment for this contract';
    END IF;
    
    -- Ghi log
    INSERT INTO audit_logs (user_id, action_type, table_name, record_id, new_values)
    VALUES (
        @current_user_id,
        'INSERT',
        'ThanhToan',
        NULL,
        JSON_OBJECT(
            'idHopDong', NEW.idHopDong,
            'ngayDongBaoHiem', NEW.ngayDongBaoHiem,
            'soTienDong', NEW.soTienDong
        )
    );
END //
DELIMITER ;

-- 8.2. Trigger khi cập nhật thanh toán
DELIMITER //
CREATE TRIGGER before_update_payment
BEFORE UPDATE ON ThanhToan
FOR EACH ROW
BEGIN
    -- Kiểm tra quyền cập nhật thanh toán
    IF NOT can_manage_payment(@current_user_id, NEW.idHopDong) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: You cannot update this payment';
    END IF;
    
    -- Ghi log
    INSERT INTO audit_logs (user_id, action_type, table_name, record_id, old_values, new_values)
    VALUES (
        @current_user_id,
        'UPDATE',
        'ThanhToan',
        OLD.id,
        JSON_OBJECT(
            'idHopDong', OLD.idHopDong,
            'ngayDongBaoHiem', OLD.ngayDongBaoHiem,
            'soTienDong', OLD.soTienDong
        ),
        JSON_OBJECT(
            'idHopDong', NEW.idHopDong,
            'ngayDongBaoHiem', NEW.ngayDongBaoHiem,
            'soTienDong', NEW.soTienDong
        )
    );
END //
DELIMITER ;

-- 8.3. Trigger khi xóa thanh toán
DELIMITER //
CREATE TRIGGER before_delete_payment
BEFORE DELETE ON ThanhToan
FOR EACH ROW
BEGIN
    -- Kiểm tra quyền xóa thanh toán
    IF NOT can_manage_payment(@current_user_id, OLD.idHopDong) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: You cannot delete this payment';
    END IF;
    
    -- Ghi log
    INSERT INTO audit_logs (user_id, action_type, table_name, record_id, old_values)
    VALUES (
        @current_user_id,
        'DELETE',
        'ThanhToan',
        OLD.id,
        JSON_OBJECT(
            'idHopDong', OLD.idHopDong,
            'ngayDongBaoHiem', OLD.ngayDongBaoHiem,
            'soTienDong', OLD.soTienDong
        )
    );
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 9: TRIGGERS CHO BẢNG NGUOIDUNG
-- ============================================================================

-- 9.1. Trigger khi cập nhật thông tin người dùng
DELIMITER //
CREATE TRIGGER before_update_user
BEFORE UPDATE ON NguoiDung
FOR EACH ROW
BEGIN
    -- Nếu thay đổi vai trò hoặc loại bảo hiểm quản lý, yêu cầu quyền admin
    IF (OLD.vaitro != NEW.vaitro OR 
        IFNULL(OLD.idLoaiBaoHiem, 0) != IFNULL(NEW.idLoaiBaoHiem, 0)) AND 
        NOT is_admin(@current_user_id) THEN
        
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: Only administrators can change user roles or insurance types';
    END IF;
    
    -- Người dùng có thể thay đổi thông tin cá nhân của chính họ
    IF @current_user_id != OLD.id AND NOT is_admin(@current_user_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Permission denied: You can only modify your own account';
    END IF;
    
    -- Ghi log
    INSERT INTO audit_logs (user_id, action_type, table_name, record_id, old_values, new_values)
    VALUES (
        @current_user_id,
        'UPDATE',
        'NguoiDung',
        OLD.id,
        JSON_OBJECT(
            'username', OLD.username,
            'email', OLD.email,
            'TrangThai', OLD.TrangThai,
            'vaitro', OLD.vaitro,
            'idLoaiBaoHiem', OLD.idLoaiBaoHiem,
            'activated', OLD.activated
        ),
        JSON_OBJECT(
            'username', NEW.username,
            'email', NEW.email,
            'TrangThai', NEW.TrangThai,
            'vaitro', NEW.vaitro, 
            'idLoaiBaoHiem', NEW.idLoaiBaoHiem,
            'activated', NEW.activated
        )
    );
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 10: THIẾT LẬP PHIÊN LÀM VIỆC
-- ============================================================================

-- Khi sử dụng trong Django, thay vì truy vấn trực tiếp các view, bạn sẽ gọi các stored procedure này: