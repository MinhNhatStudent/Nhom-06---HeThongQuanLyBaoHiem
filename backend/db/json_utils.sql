-- ============================================================================
-- TẬP TIN TIỆN ÍCH JSON CHO FASTAPI
-- ============================================================================
USE insurance_management;

-- ============================================================================
-- PHẦN 1: HÀM TIỆN ÍCH JSON
-- ============================================================================

-- Hàm chuyển đổi ResultSet thành JSON
DELIMITER //
CREATE PROCEDURE result_to_json(IN p_query TEXT)
BEGIN
    SET @sql = CONCAT('SELECT JSON_ARRAYAGG(JSON_OBJECT(*)) AS result FROM (', p_query, ') AS subquery');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 2: CẬP NHẬT STORED PROCEDURE TRẢ VỀ JSON
-- ============================================================================

-- Stored Procedure cho danh sách loại bảo hiểm (JSON format)
DELIMITER //
CREATE PROCEDURE get_insurance_types_json()
BEGIN
    SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            'id', id,
            'name', tenBH,
            'description', motaHD,
            'created_at', created_at
        )
    ) AS result
    FROM insurance_types;
END //
DELIMITER ;

-- Stored Procedure cho thông tin người dùng (JSON format)
DELIMITER //
CREATE PROCEDURE get_user_info_json(IN p_user_id INT)
BEGIN
    SELECT JSON_OBJECT(
        'id', id,
        'username', username,
        'email', email,
        'role', vaitro,
        'status', TrangThai,
        'insurance_type', (
            SELECT JSON_OBJECT(
                'id', it.id,
                'name', it.tenBH
            )
            FROM insurance_types it
            WHERE it.id = idLoaiBaoHiem
        ),
        'created_at', created_at,
        'activated', activated
    ) AS result
    FROM NguoiDung
    WHERE id = p_user_id;
END //
DELIMITER ;

-- Stored Procedure cho thông tin người được bảo hiểm (JSON format)
DELIMITER //
CREATE PROCEDURE get_insured_person_data_json(IN p_user_id INT)
BEGIN
    SELECT JSON_OBJECT(
        'contracts', JSON_ARRAYAGG(
            JSON_OBJECT(
                'id', hd.id,
                'insurance_type', JSON_OBJECT(
                    'id', it.id,
                    'name', it.tenBH,
                    'description', it.motaHD
                ),
                'start_date', hd.ngayKiHD,
                'end_date', hd.ngayCatHD,
                'status', hd.TrangThai,
                'insurance_value', hd.giaTriBaoHiem,
                'personal_info', JSON_OBJECT(
                    'name', decrypt_data(ct.HoTen),
                    'gender', ct.gioiTinh,
                    'birth_date', ct.ngaySinh,
                    'workplace', decrypt_data(ct.diachiCoQuan),
                    'permanent_address', decrypt_data(ct.diachiThuongTru),
                    'temporary_address', decrypt_data(ct.diachiTamTru),
                    'contact_address', decrypt_data(ct.diachiLienLac),
                    'phone', decrypt_data(ct.sodienthoai),
                    'medical_history', decrypt_data(ct.lichsuBenh)
                ),
                'payments', (
                    SELECT JSON_ARRAYAGG(
                        JSON_OBJECT(
                            'id', pmt.id,
                            'payment_date', pmt.ngayDongBaoHiem,
                            'amount', pmt.soTienDong,
                            'status', pmt.TrangThai
                        )
                    )
                    FROM ThanhToan pmt
                    WHERE pmt.idHopDong = hd.id
                )
            )
        )
    ) AS result
    FROM HopDong hd
    JOIN ChiTietHopDong ct ON hd.id = ct.idHopDong
    JOIN insurance_types it ON hd.idLoaiBaoHiem = it.id
    LEFT JOIN ThanhToan tt ON hd.id = tt.idHopDong
    WHERE hd.idNguoiBH = p_user_id
    GROUP BY hd.idNguoiBH;
END //
DELIMITER ;

-- Stored Procedure cho thông tin người lập hợp đồng (JSON format)
DELIMITER //
CREATE PROCEDURE get_contract_creator_data_json(IN p_user_id INT)
BEGIN
    SELECT JSON_OBJECT(
        'contracts', JSON_ARRAYAGG(
            JSON_OBJECT(
                'id', hd.id,
                'insurance_type', JSON_OBJECT(
                    'id', it.id,
                    'name', it.tenBH
                ),
                'insured_person', JSON_OBJECT(
                    'id', insured.id,
                    'username', insured.username,
                    'email', insured.email
                ),
                'start_date', hd.ngayKiHD,
                'end_date', hd.ngayCatHD,
                'status', hd.TrangThai,
                'insurance_value', hd.giaTriBaoHiem,
                'personal_info', JSON_OBJECT(
                    'name', decrypt_data(ct.HoTen),
                    'gender', ct.gioiTinh,
                    'birth_date', ct.ngaySinh,
                    'workplace', decrypt_data(ct.diachiCoQuan),
                    'permanent_address', decrypt_data(ct.diachiThuongTru),
                    'temporary_address', decrypt_data(ct.diachiTamTru),
                    'contact_address', decrypt_data(ct.diachiLienLac),
                    'phone', decrypt_data(ct.sodienthoai),
                    'medical_history', decrypt_data(ct.lichsuBenh)
                ),
                'payments', (
                    SELECT JSON_ARRAYAGG(
                        JSON_OBJECT(
                            'id', pmt.id,
                            'payment_date', pmt.ngayDongBaoHiem,
                            'amount', pmt.soTienDong,
                            'status', pmt.TrangThai
                        )
                    )
                    FROM ThanhToan pmt
                    WHERE pmt.idHopDong = hd.id
                )
            )
        )
    ) AS result
    FROM HopDong hd
    JOIN ChiTietHopDong ct ON hd.id = ct.idHopDong
    JOIN insurance_types it ON hd.idLoaiBaoHiem = it.id
    JOIN NguoiDung insured ON hd.idNguoiBH = insured.id
    LEFT JOIN ThanhToan tt ON hd.id = tt.idHopDong
    WHERE hd.creator_id = p_user_id
    GROUP BY hd.creator_id;
END //
DELIMITER ;

-- Stored Procedure cho kế toán (JSON format)
DELIMITER //
CREATE PROCEDURE get_accounting_data_json(IN p_user_id INT)
BEGIN
    DECLARE insurance_type INT;
    
    -- Lấy loại bảo hiểm người dùng quản lý
    SELECT idLoaiBaoHiem INTO insurance_type FROM NguoiDung WHERE id = p_user_id;
    
    SELECT JSON_OBJECT(
        'insurance_type', JSON_OBJECT(
            'id', it.id,
            'name', it.tenBH
        ),
        'contracts', JSON_ARRAYAGG(
            JSON_OBJECT(
                'id', hd.id,
                'creator', JSON_OBJECT(
                    'id', creator.id,
                    'username', creator.username
                ),
                'insured_person', JSON_OBJECT(
                    'id', insured.id,
                    'name', decrypt_data(ct.HoTen),
                    'username', insured.username
                ),
                'start_date', hd.ngayKiHD,
                'end_date', hd.ngayCatHD,
                'status', hd.TrangThai,
                'insurance_value', hd.giaTriBaoHiem,
                'payments', (
                    SELECT JSON_ARRAYAGG(
                        JSON_OBJECT(
                            'id', pmt.id,
                            'payment_date', pmt.ngayDongBaoHiem,
                            'amount', pmt.soTienDong,
                            'status', pmt.TrangThai
                        )
                    )
                    FROM ThanhToan pmt
                    WHERE pmt.idHopDong = hd.id
                )
            )
        )
    ) AS result
    FROM HopDong hd
    JOIN ChiTietHopDong ct ON hd.id = ct.idHopDong
    JOIN NguoiDung creator ON hd.creator_id = creator.id
    JOIN NguoiDung insured ON hd.idNguoiBH = insured.id
    JOIN insurance_types it ON hd.idLoaiBaoHiem = it.id
    LEFT JOIN ThanhToan tt ON hd.id = tt.idHopDong
    WHERE hd.idLoaiBaoHiem = insurance_type
    GROUP BY insurance_type;
END //
DELIMITER ;

-- Stored Procedure cho giám sát (JSON format)
DELIMITER //
CREATE PROCEDURE get_supervisor_data_json(IN p_user_id INT)
BEGIN
    DECLARE insurance_type INT;
    
    -- Lấy loại bảo hiểm người dùng giám sát
    SELECT idLoaiBaoHiem INTO insurance_type FROM NguoiDung WHERE id = p_user_id;
    
    SELECT JSON_OBJECT(
        'insurance_type', JSON_OBJECT(
            'id', it.id,
            'name', it.tenBH
        ),
        'contracts', JSON_ARRAYAGG(
            JSON_OBJECT(
                'id', hd.id,
                'creator', JSON_OBJECT(
                    'id', creator.id,
                    'username', creator.username
                ),
                'insured_person', JSON_OBJECT(
                    'id', insured.id,
                    'username', insured.username
                ),
                'start_date', hd.ngayKiHD,
                'end_date', hd.ngayCatHD,
                'status', hd.TrangThai,
                'insurance_value', hd.giaTriBaoHiem,
                'personal_info', JSON_OBJECT(
                    'name', decrypt_data(ct.HoTen),
                    'gender', ct.gioiTinh,
                    'birth_date', ct.ngaySinh,
                    'workplace', decrypt_data(ct.diachiCoQuan),
                    'permanent_address', decrypt_data(ct.diachiThuongTru),
                    'temporary_address', decrypt_data(ct.diachiTamTru),
                    'contact_address', decrypt_data(ct.diachiLienLac),
                    'phone', decrypt_data(ct.sodienthoai),
                    'medical_history', decrypt_data(ct.lichsuBenh)
                ),
                'payments', (
                    SELECT JSON_ARRAYAGG(
                        JSON_OBJECT(
                            'id', pmt.id,
                            'payment_date', pmt.ngayDongBaoHiem,
                            'amount', pmt.soTienDong,
                            'status', pmt.TrangThai
                        )
                    )
                    FROM ThanhToan pmt
                    WHERE pmt.idHopDong = hd.id
                )
            )
        )
    ) AS result
    FROM HopDong hd
    JOIN ChiTietHopDong ct ON hd.id = ct.idHopDong
    JOIN NguoiDung creator ON hd.creator_id = creator.id
    JOIN NguoiDung insured ON hd.idNguoiBH = insured.id
    JOIN insurance_types it ON hd.idLoaiBaoHiem = it.id
    LEFT JOIN ThanhToan tt ON hd.id = tt.idHopDong
    WHERE hd.idLoaiBaoHiem = insurance_type
    GROUP BY insurance_type;
END //
DELIMITER ;

-- ============================================================================
-- PHẦN 3: STORED PROCEDURE THEO ENDPOINT CHO REST API
-- ============================================================================

-- Thêm hợp đồng mới với kiểm tra quyền (JSON format)
DELIMITER //
CREATE PROCEDURE create_contract_json(
    IN p_user_id INT,
    IN p_contract_data JSON
)
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_insurance_type_id INT;
    DECLARE v_insured_id INT;
    DECLARE v_contract_id INT;
    DECLARE v_result JSON;
    DECLARE v_can_create BOOLEAN;
    
    -- Kiểm tra quyền
    SELECT vaitro INTO v_role FROM NguoiDung WHERE id = p_user_id;
    
    -- Chỉ người tạo hợp đồng mới có quyền tạo hợp đồng mới
    IF v_role != 'contract_creator' THEN
        SET v_result = JSON_OBJECT(
            'success', FALSE,
            'message', 'Không có quyền tạo hợp đồng mới'
        );
    ELSE
        -- Lấy dữ liệu từ JSON
        SET v_insurance_type_id = JSON_UNQUOTE(JSON_EXTRACT(p_contract_data, '$.insurance_type_id'));
        SET v_insured_id = JSON_UNQUOTE(JSON_EXTRACT(p_contract_data, '$.insured_id'));
        
        -- Tạo hợp đồng mới
        INSERT INTO HopDong (
            creator_id, 
            idLoaiBaoHiem, 
            idNguoiBH, 
            ngayKiHD, 
            ngayCatHD,
            TrangThai,
            giaTriBaoHiem
        )
        VALUES (
            p_user_id,
            v_insurance_type_id,
            v_insured_id,
            JSON_UNQUOTE(JSON_EXTRACT(p_contract_data, '$.start_date')),
            JSON_UNQUOTE(JSON_EXTRACT(p_contract_data, '$.end_date')),
            'processing',
            JSON_UNQUOTE(JSON_EXTRACT(p_contract_data, '$.insurance_value'))
        );
        
        -- Lấy ID hợp đồng vừa tạo
        SET v_contract_id = LAST_INSERT_ID();
        
        -- Thêm chi tiết hợp đồng
        INSERT INTO ChiTietHopDong (
            idHopDong,
            HoTen,
            gioiTinh,
            ngaySinh,
            diachiCoQuan,
            diachiThuongTru,
            diachiTamTru,
            diachiLienLac,
            sodienthoai,
            lichsuBenh
        )
        VALUES (
            v_contract_id,
            encrypt_data(JSON_UNQUOTE(JSON_EXTRACT(p_contract_data, '$.personal_info.name'))),
            JSON_UNQUOTE(JSON_EXTRACT(p_contract_data, '$.personal_info.gender')),
            JSON_UNQUOTE(JSON_EXTRACT(p_contract_data, '$.personal_info.birth_date')),
            encrypt_data(JSON_UNQUOTE(JSON_EXTRACT(p_contract_data, '$.personal_info.workplace'))),
            encrypt_data(JSON_UNQUOTE(JSON_EXTRACT(p_contract_data, '$.personal_info.permanent_address'))),
            encrypt_data(JSON_UNQUOTE(JSON_EXTRACT(p_contract_data, '$.personal_info.temporary_address'))),
            encrypt_data(JSON_UNQUOTE(JSON_EXTRACT(p_contract_data, '$.personal_info.contact_address'))),
            encrypt_data(JSON_UNQUOTE(JSON_EXTRACT(p_contract_data, '$.personal_info.phone'))),
            encrypt_data(JSON_UNQUOTE(JSON_EXTRACT(p_contract_data, '$.personal_info.medical_history')))
        );
        
        SET v_result = JSON_OBJECT(
            'success', TRUE,
            'contract_id', v_contract_id,
            'message', 'Tạo hợp đồng thành công'
        );
    END IF;
    
    -- Trả về kết quả
    SELECT v_result AS result;
END //
DELIMITER ;

-- Cập nhật trạng thái hợp đồng với kiểm tra quyền
DELIMITER //
CREATE PROCEDURE update_contract_status_json(
    IN p_user_id INT,
    IN p_contract_id INT,
    IN p_status VARCHAR(20)
)
BEGIN
    DECLARE v_can_update BOOLEAN;
    DECLARE v_role VARCHAR(20);
    
    -- Kiểm tra quyền
    SELECT vaitro INTO v_role FROM NguoiDung WHERE id = p_user_id;
    
    -- Kiểm tra quyền cập nhật
    IF v_role = 'contract_creator' THEN
        -- Người tạo hợp đồng chỉ có thể cập nhật hợp đồng của mình
        SET v_can_update = EXISTS(
            SELECT 1 FROM HopDong 
            WHERE id = p_contract_id AND creator_id = p_user_id
        );
    ELSE
        SET v_can_update = FALSE;
    END IF;
    
    -- Thực hiện cập nhật nếu có quyền
    IF v_can_update THEN
        UPDATE HopDong SET TrangThai = p_status WHERE id = p_contract_id;
        
        SELECT JSON_OBJECT(
            'success', TRUE,
            'message', 'Cập nhật trạng thái hợp đồng thành công'
        ) AS result;
    ELSE
        SELECT JSON_OBJECT(
            'success', FALSE,
            'message', 'Không có quyền cập nhật trạng thái hợp đồng này'
        ) AS result;
    END IF;
END //
DELIMITER ;

-- Thêm kỳ thanh toán với kiểm tra quyền
DELIMITER //
CREATE PROCEDURE add_payment_json(
    IN p_user_id INT,
    IN p_contract_id INT,
    IN p_payment_date DATE,
    IN p_amount DECIMAL(10, 2)
)
BEGIN
    DECLARE v_can_add BOOLEAN;
    DECLARE v_role VARCHAR(20);
    DECLARE v_insurance_type INT;
    DECLARE v_payment_id INT;
    
    -- Kiểm tra quyền
    SELECT vaitro, idLoaiBaoHiem INTO v_role, v_insurance_type FROM NguoiDung WHERE id = p_user_id;
    
    -- Kiểm tra quyền thêm thanh toán
    CASE v_role
        -- Kế toán - Chỉ có thể thêm thanh toán cho hợp đồng thuộc loại bảo hiểm được phân công
        WHEN 'accounting' THEN
            SET v_can_add = EXISTS(
                SELECT 1 FROM HopDong 
                WHERE id = p_contract_id AND idLoaiBaoHiem = v_insurance_type
            );
        -- Người tạo hợp đồng - Có thể thêm thanh toán cho hợp đồng do mình tạo
        WHEN 'contract_creator' THEN
            SET v_can_add = EXISTS(
                SELECT 1 FROM HopDong 
                WHERE id = p_contract_id AND creator_id = p_user_id
            );
        ELSE
            SET v_can_add = FALSE;
    END CASE;
    
    -- Thực hiện thêm thanh toán nếu có quyền
    IF v_can_add THEN
        INSERT INTO ThanhToan (idHopDong, ngayDongBaoHiem, soTienDong, TrangThai)
        VALUES (p_contract_id, p_payment_date, p_amount, 'pending');
        
        SET v_payment_id = LAST_INSERT_ID();
        
        SELECT JSON_OBJECT(
            'success', TRUE,
            'payment_id', v_payment_id,
            'message', 'Thêm kỳ thanh toán thành công'
        ) AS result;
    ELSE
        SELECT JSON_OBJECT(
            'success', FALSE,
            'message', 'Không có quyền thêm thanh toán cho hợp đồng này'
        ) AS result;
    END IF;
END //
DELIMITER ;

-- Cập nhật trạng thái thanh toán với kiểm tra quyền
DELIMITER //
CREATE PROCEDURE update_payment_status_json(
    IN p_user_id INT,
    IN p_payment_id INT,
    IN p_status VARCHAR(20)
)
BEGIN
    DECLARE v_can_update BOOLEAN;
    DECLARE v_role VARCHAR(20);
    DECLARE v_insurance_type INT;
    DECLARE v_contract_id INT;
    
    -- Lấy thông tin hợp đồng từ thanh toán
    SELECT idHopDong INTO v_contract_id FROM ThanhToan WHERE id = p_payment_id;
    
    -- Kiểm tra quyền
    SELECT vaitro, idLoaiBaoHiem INTO v_role, v_insurance_type FROM NguoiDung WHERE id = p_user_id;
    
    -- Kiểm tra quyền cập nhật thanh toán
    IF v_role = 'accounting' THEN
        -- Kế toán - Chỉ có thể cập nhật thanh toán cho hợp đồng thuộc loại bảo hiểm được phân công
        SET v_can_update = EXISTS(
            SELECT 1 FROM HopDong 
            WHERE id = v_contract_id AND idLoaiBaoHiem = v_insurance_type
        );
    ELSE
        SET v_can_update = FALSE;
    END IF;
    
    -- Thực hiện cập nhật nếu có quyền
    IF v_can_update THEN
        UPDATE ThanhToan SET TrangThai = p_status WHERE id = p_payment_id;
        
        SELECT JSON_OBJECT(
            'success', TRUE,
            'message', 'Cập nhật trạng thái thanh toán thành công'
        ) AS result;
    ELSE
        SELECT JSON_OBJECT(
            'success', FALSE,
            'message', 'Không có quyền cập nhật trạng thái thanh toán này'
        ) AS result;
    END IF;
END //
DELIMITER ;
