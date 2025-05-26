-- ============================================================================
-- WRAPPER FUNCTIONS FOR ENCRYPTION/DECRYPTION
-- ============================================================================
USE insurance_management;

-- Create wrapper function for encrypt_data
DELIMITER //
DROP FUNCTION IF EXISTS encrypt_text //
CREATE FUNCTION encrypt_text(data TEXT) 
RETURNS VARBINARY(1000)
DETERMINISTIC
BEGIN
    -- Just call the existing encrypt_data function
    RETURN encrypt_data(data);
END //
DELIMITER ;

-- Create wrapper function for decrypt_data
DELIMITER //
DROP FUNCTION IF EXISTS decrypt_text //
CREATE FUNCTION decrypt_text(encrypted_data VARBINARY(1000)) 
RETURNS TEXT
DETERMINISTIC
BEGIN
    -- Just call the existing decrypt_data function
    RETURN decrypt_data(encrypted_data);
END //
DELIMITER ;
