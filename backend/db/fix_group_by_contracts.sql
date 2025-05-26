-- Fix GROUP BY issue in sp_get_contracts_list stored procedure
-- This fixes the MySQL ONLY_FULL_GROUP_BY compatibility issue

DROP PROCEDURE IF EXISTS sp_get_contracts_list;

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
    
    -- Tạo câu truy vấn với GROUP BY đầy đủ để tương thích với ONLY_FULL_GROUP_BY
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
    
    -- Thực thi câu truy vấn đếm
    PREPARE count_stmt FROM @count_query;
    EXECUTE count_stmt;
    DEALLOCATE PREPARE count_stmt;
END //

DELIMITER ;
