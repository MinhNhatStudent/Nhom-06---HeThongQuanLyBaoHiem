-- ============================================================================
-- STORED PROCEDURE FOR USER ACTIVITY LOGGING
-- ============================================================================
USE insurance_management;

-- Create user activity logs table if it doesn't exist
CREATE TABLE IF NOT EXISTS user_activity_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    activity_type VARCHAR(50),
    description TEXT,
    ip_address VARCHAR(45),
    details JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES NguoiDung(id)
);

-- Stored procedure to log user activity
DELIMITER //
CREATE PROCEDURE log_user_activity(
    IN p_user_id INT,
    IN p_activity_type VARCHAR(50),
    IN p_description TEXT,
    IN p_ip_address VARCHAR(45),
    IN p_details_json TEXT
)
BEGIN
    -- Insert user activity log
    INSERT INTO user_activity_logs (
        user_id,
        activity_type,
        description,
        ip_address,
        details,
        created_at
    ) VALUES (
        p_user_id,
        p_activity_type,
        p_description,
        p_ip_address,
        CASE 
            WHEN p_details_json IS NOT NULL AND p_details_json != '' 
            THEN CAST(p_details_json AS JSON)
            ELSE NULL
        END,
        CURRENT_TIMESTAMP
    );
END //
DELIMITER ;

-- Additional procedure to get user activity logs (for audit purposes)
DELIMITER //
CREATE PROCEDURE get_user_activity_logs(
    IN p_user_id INT,
    IN p_limit INT,
    IN p_offset INT
)
BEGIN
    SELECT 
        id,
        user_id,
        activity_type,
        description,
        ip_address,
        details,
        created_at
    FROM user_activity_logs
    WHERE p_user_id IS NULL OR user_id = p_user_id
    ORDER BY created_at DESC
    LIMIT p_limit OFFSET p_offset;
END //
DELIMITER ;

-- Procedure to clean up old activity logs (for maintenance)
DELIMITER //
CREATE PROCEDURE cleanup_old_activity_logs(
    IN p_days INT
)
BEGIN
    DELETE FROM user_activity_logs
    WHERE created_at < DATE_SUB(NOW(), INTERVAL p_days DAY);
    
    SELECT ROW_COUNT() as deleted_records;
END //
DELIMITER ;
