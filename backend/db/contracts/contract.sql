DELIMITER //

CREATE PROCEDURE sp_get_contracts_list(
    IN p_user_id INT,
    IN p_page INT,
    IN p_limit INT,
    IN p_search VARCHAR(100),
    IN p_status_filter VARCHAR(20)
)
BEGIN
    DECLARE v_user_role VARCHAR(50);
    DECLARE v_insurance_type INT;
    
    -- Lấy vai trò và loại bảo hiểm của người dùng
    SELECT vaitro, idLoaiBaoHiem INTO v_user_role, v_insurance_type 
    FROM NguoiDung 
    WHERE id = p_user_id;
    
    -- Xác định số lượng bản ghi mỗi trang và vị trí bắt đầu
    SET @limit = IFNULL(p_limit, 10);
    SET @offset = IFNULL((p_page - 1) * @limit, 0);
    
    -- Điều kiện lọc theo vai trò
    IF v_user_role = 'contract_creator' THEN
        SET @role_condition = CONCAT(' AND hd.creator_id = ', p_user_id);
    ELSEIF v_user_role = 'insured_person' THEN
        SET @role_condition = CONCAT(' AND hd.idNguoiBH = ', p_user_id);
    ELSEIF v_user_role IN ('accounting', 'supervisor') THEN
        SET @role_condition = CONCAT(' AND hd.idLoaiBaoHiem = ', v_insurance_type);
    ELSEIF v_user_role = 'admin' THEN
        SET @role_condition = '';
    ELSE
        SET @role_condition = ' AND 1=0';
    END IF;
    
    -- Điều kiện lọc theo trạng thái
    IF p_status_filter IS NOT NULL THEN
        SET @status_condition = CONCAT(' AND hd.TrangThai = "', p_status_filter, '"');
    ELSE
        SET @status_condition = '';
    END IF;
    
    -- Điều kiện tìm kiếm
    IF p_search IS NOT NULL THEN
        SET @search_condition = CONCAT(' AND (
            ct.HoTen LIKE "%', p_search, '%" OR 
            it.tenBH LIKE "%', p_search, '%" OR
            ct.diachiThuongTru LIKE "%', p_search, '%"
        )');
    ELSE
        SET @search_condition = '';
    END IF;
      -- Tạo câu truy vấn
    SET @query = CONCAT('
        SELECT 
            hd.id,
            hd.ngayKiHD,
            hd.ngayCatHD,
            hd.TrangThai,
            it.tenBH as loai_bao_hiem,
            CONCAT(
                CASE 
                    WHEN MAX(ct.HoTen) IS NOT NULL THEN decrypt_text(MAX(ct.HoTen))
                    ELSE "Chưa có thông tin" 
                END
            ) as ten_nguoi_bh,
            (SELECT username FROM NguoiDung WHERE id = hd.creator_id) as nguoi_lap_hd,
            (SELECT COUNT(*) FROM ThanhToan WHERE idHopDong = hd.id) as so_ky_thanh_toan
        FROM 
            HopDong hd
        LEFT JOIN 
            ChiTietHopDong ct ON hd.id = ct.idHopDong
        JOIN 
            insurance_types it ON hd.idLoaiBaoHiem = it.id
        WHERE 
            1=1', @role_condition, @status_condition, @search_condition, '
        GROUP BY 
            hd.id, hd.ngayKiHD, hd.ngayCatHD, hd.TrangThai, it.tenBH, hd.creator_id, hd.created_at
        ORDER BY 
            hd.created_at DESC
        LIMIT ', @limit, ' OFFSET ', @offset
    );
    
    -- Tổng số bản ghi phù hợp với điều kiện
    SET @count_query = CONCAT('
        SELECT COUNT(DISTINCT hd.id) as total
        FROM 
            HopDong hd
        LEFT JOIN 
            ChiTietHopDong ct ON hd.id = ct.idHopDong
        JOIN 
            insurance_types it ON hd.idLoaiBaoHiem = it.id
        WHERE 
            1=1', @role_condition, @status_condition, @search_condition
    );
    
    -- Thực thi câu truy vấn
    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    -- Trả về tổng số bản ghi
    PREPARE count_stmt FROM @count_query;
    EXECUTE count_stmt;
    DEALLOCATE PREPARE count_stmt;
END //

DELIMITER ;

-- Lay chi tiet hop dong theo id
DELIMITER //

CREATE PROCEDURE sp_get_contract_detail(
    IN p_user_id INT,
    IN p_contract_id INT
)
BEGIN
    DECLARE v_has_permission BOOLEAN;
    
    -- Kiểm tra quyền truy cập hợp đồng
    SELECT can_access_contract(p_user_id, p_contract_id) INTO v_has_permission;
    
    IF v_has_permission = TRUE THEN
        -- Thông tin hợp đồng
        SELECT 
            hd.id,
            hd.creator_id,
            (SELECT username FROM NguoiDung WHERE id = hd.creator_id) as nguoi_lap_hd,
            hd.idLoaiBaoHiem,
            it.tenBH as loai_bao_hiem,
            hd.idNguoiBH,
            (SELECT username FROM NguoiDung WHERE id = hd.idNguoiBH) as username_nguoi_bh,
            hd.ngayKiHD,
            hd.ngayCatHD,
            hd.TrangThai,
            hd.created_at
        FROM 
            HopDong hd
        JOIN 
            insurance_types it ON hd.idLoaiBaoHiem = it.id
        WHERE 
            hd.id = p_contract_id;
        
        -- Chi tiết hợp đồng (dữ liệu đã giải mã)
        SELECT 
            ct.id,
            decrypt_text(ct.HoTen) as HoTen,
            ct.gioiTinh,
            ct.ngaySinh,
            decrypt_text(ct.diachiCoQuan) as diachiCoQuan,
            decrypt_text(ct.diachiThuongTru) as diachiThuongTru,
            decrypt_text(ct.sodienthoai) as sodienthoai,
            decrypt_text(ct.lichsuBenh) as lichsuBenh
        FROM 
            ChiTietHopDong ct
        WHERE 
            ct.idHopDong = p_contract_id;
        
        -- Thông tin thanh toán
        SELECT 
            id, 
            ngayDongBaoHiem, 
            soTienDong
        FROM 
            ThanhToan
        WHERE 
            idHopDong = p_contract_id
        ORDER BY 
            ngayDongBaoHiem DESC;
    ELSE
        -- Không có quyền truy cập
        SELECT 'error' as status, 'Không có quyền truy cập hợp đồng này' as message;
    END IF;
END //

DELIMITER ;

-- Them hop dong moi
DELIMITER //

CREATE PROCEDURE sp_create_contract(
    IN p_user_id INT,
    IN p_insurance_type_id INT,
    IN p_insured_person_id INT,
    IN p_ngay_ki DATE,
    IN p_ngay_cat DATE,
    IN p_trang_thai VARCHAR(20),
    IN p_contract_details JSON
)
BEGIN
    DECLARE v_user_role VARCHAR(50);
    DECLARE v_new_contract_id INT;
    
    -- Lấy vai trò của người dùng
    SELECT vaitro INTO v_user_role FROM NguoiDung WHERE id = p_user_id;
    
    -- Kiểm tra quyền tạo hợp đồng
    IF v_user_role IN ('contract_creator', 'admin') THEN
        -- Tạo hợp đồng mới
        INSERT INTO HopDong (
            creator_id,
            idLoaiBaoHiem,
            idNguoiBH,
            ngayKiHD,
            ngayCatHD,
            TrangThai
        ) VALUES (
            p_user_id,
            p_insurance_type_id,
            p_insured_person_id,
            p_ngay_ki,
            p_ngay_cat,
            IFNULL(p_trang_thai, 'processing')
        );
        
        -- Lấy ID của hợp đồng vừa tạo
        SET v_new_contract_id = LAST_INSERT_ID();
        
        -- Nếu có thông tin chi tiết hợp đồng
        IF p_contract_details IS NOT NULL THEN
            -- Parse JSON và lấy thông tin
            SET @ho_ten = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.ho_ten'));
            SET @gioi_tinh = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.gioi_tinh'));
            SET @ngay_sinh = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.ngay_sinh'));
            SET @dia_chi_co_quan = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.dia_chi_co_quan'));
            SET @dia_chi_thuong_tru = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.dia_chi_thuong_tru'));
            SET @so_dien_thoai = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.so_dien_thoai'));
            SET @lich_su_benh = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.lich_su_benh'));
            
            -- Thêm chi tiết hợp đồng với dữ liệu đã mã hóa
            INSERT INTO ChiTietHopDong (
                idHopDong,
                HoTen,
                gioiTinh,
                ngaySinh,
                diachiCoQuan,
                diachiThuongTru,
                sodienthoai,
                lichsuBenh
            ) VALUES (
                v_new_contract_id,
                encrypt_text(@ho_ten),
                @gioi_tinh,
                @ngay_sinh,
                encrypt_text(@dia_chi_co_quan),
                encrypt_text(@dia_chi_thuong_tru),
                encrypt_text(@so_dien_thoai),
                encrypt_text(@lich_su_benh)
            );
        END IF;
        
        -- Trả về kết quả thành công và ID của hợp đồng mới
        SELECT 'success' as status, v_new_contract_id as contract_id, 'Hợp đồng đã được tạo thành công' as message;
    ELSE
        -- Không có quyền tạo hợp đồng
        SELECT 'error' as status, 'Không có quyền tạo hợp đồng' as message;
    END IF;
END //

DELIMITER ;


-- Cap nhat hop dong
DELIMITER //

CREATE PROCEDURE sp_update_contract(
    IN p_user_id INT,
    IN p_contract_id INT,
    IN p_insurance_type_id INT,
    IN p_insured_person_id INT,
    IN p_ngay_ki DATE,
    IN p_ngay_cat DATE,
    IN p_trang_thai VARCHAR(20),
    IN p_contract_details JSON
)
BEGIN
    DECLARE v_has_permission BOOLEAN;
    
    -- Kiểm tra quyền chỉnh sửa hợp đồng
    SELECT can_edit_contract(p_user_id, p_contract_id) INTO v_has_permission;
    
    IF v_has_permission = TRUE THEN
        -- Cập nhật thông tin hợp đồng
        UPDATE HopDong
        SET
            idLoaiBaoHiem = IFNULL(p_insurance_type_id, idLoaiBaoHiem),
            idNguoiBH = IFNULL(p_insured_person_id, idNguoiBH),
            ngayKiHD = IFNULL(p_ngay_ki, ngayKiHD),
            ngayCatHD = IFNULL(p_ngay_cat, ngayCatHD),
            TrangThai = IFNULL(p_trang_thai, TrangThai)
        WHERE
            id = p_contract_id;
        
        -- Nếu có thông tin chi tiết hợp đồng
        IF p_contract_details IS NOT NULL THEN
            -- Parse JSON và lấy thông tin
            SET @detail_id = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.id'));
            SET @ho_ten = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.ho_ten'));
            SET @gioi_tinh = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.gioi_tinh'));
            SET @ngay_sinh = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.ngay_sinh'));
            SET @dia_chi_co_quan = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.dia_chi_co_quan'));
            SET @dia_chi_thuong_tru = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.dia_chi_thuong_tru'));
            SET @so_dien_thoai = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.so_dien_thoai'));
            SET @lich_su_benh = JSON_UNQUOTE(JSON_EXTRACT(p_contract_details, '$.lich_su_benh'));
            
            -- Cập nhật chi tiết hợp đồng
            UPDATE ChiTietHopDong
            SET
                HoTen = CASE WHEN @ho_ten IS NOT NULL THEN encrypt_text(@ho_ten) ELSE HoTen END,
                gioiTinh = IFNULL(@gioi_tinh, gioiTinh),
                ngaySinh = IFNULL(@ngay_sinh, ngaySinh),
                diachiCoQuan = CASE WHEN @dia_chi_co_quan IS NOT NULL THEN encrypt_text(@dia_chi_co_quan) ELSE diachiCoQuan END,
                diachiThuongTru = CASE WHEN @dia_chi_thuong_tru IS NOT NULL THEN encrypt_text(@dia_chi_thuong_tru) ELSE diachiThuongTru END,
                sodienthoai = CASE WHEN @so_dien_thoai IS NOT NULL THEN encrypt_text(@so_dien_thoai) ELSE sodienthoai END,
                lichsuBenh = CASE WHEN @lich_su_benh IS NOT NULL THEN encrypt_text(@lich_su_benh) ELSE lichsuBenh END
            WHERE
                id = @detail_id AND idHopDong = p_contract_id;
        END IF;
        
        -- Trả về kết quả thành công
        SELECT 'success' as status, 'Hợp đồng đã được cập nhật thành công' as message;
    ELSE
        -- Không có quyền chỉnh sửa
        SELECT 'error' as status, 'Không có quyền chỉnh sửa hợp đồng này' as message;
    END IF;
END //

DELIMITER ;


-- Xoa hop dong
DELIMITER //

CREATE PROCEDURE sp_delete_contract(
    IN p_user_id INT,
    IN p_contract_id INT
)
BEGIN
    DECLARE v_has_permission BOOLEAN;
    
    -- Kiểm tra quyền xóa hợp đồng
    SELECT can_edit_contract(p_user_id, p_contract_id) INTO v_has_permission;
    
    IF v_has_permission = TRUE THEN
        -- Xóa chi tiết hợp đồng và thanh toán trước để tránh lỗi khóa ngoại
        DELETE FROM ChiTietHopDong WHERE idHopDong = p_contract_id;
        DELETE FROM ThanhToan WHERE idHopDong = p_contract_id;
        
        -- Xóa hợp đồng
        DELETE FROM HopDong WHERE id = p_contract_id;
        
        -- Trả về kết quả thành công
        SELECT 'success' as status, 'Hợp đồng đã được xóa thành công' as message;
    ELSE
        -- Không có quyền xóa
        SELECT 'error' as status, 'Không có quyền xóa hợp đồng này' as message;
    END IF;
END //

DELIMITER ;


