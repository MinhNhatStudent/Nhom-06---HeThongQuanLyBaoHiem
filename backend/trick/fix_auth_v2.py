"""
Fix authentication issues in the FastAPI backend
"""
import json
import sys
from jose import jwt
from app.config.settings import get_settings
from app.utils.database import execute_procedure
import mysql.connector

# Get settings
settings = get_settings()

def debug_token_with_db(token):
    """Debug a JWT token and check the session validation in the database"""
    print("\n=== JWT Token and Database Session Debug ===")
    
    # Step 1: Decode token (without verification)
    try:
        # Get the token parts
        parts = token.split('.')
        if len(parts) != 3:
            print("❌ Invalid token format")
            return False
            
        # Add padding if needed and decode header and payload
        def decode_base64_part(b64_str):
            from base64 import urlsafe_b64decode
            padding = 4 - (len(b64_str) % 4)
            if padding < 4:
                b64_str += '=' * padding
            return urlsafe_b64decode(b64_str.encode()).decode()
            
        header_json = json.loads(decode_base64_part(parts[0]))
        payload_json = json.loads(decode_base64_part(parts[1]))
        
        print("\n✅ Token structure is valid")
        print(f"Header: {json.dumps(header_json, indent=2)}")
        print(f"Payload: {json.dumps(payload_json, indent=2)}")
        
        # Step 2: Check session in database
        session_id = payload_json.get('session_id')
        if not session_id:
            print("\n❌ No session_id in token")
            return False
            
        print(f"\nChecking session_id {session_id} in database...")
        
        try:
            # Call procedure directly
            result = execute_procedure("fastapi_validate_session", [session_id])
            
            if result and len(result) > 0:
                session_result = result[0].get('result', '{}')
                if isinstance(session_result, str):
                    session_data = json.loads(session_result)
                else:
                    session_data = session_result
                    
                print(f"Database session check result: {json.dumps(session_data, indent=2)}")
                
                if session_data.get('valid', False):
                    print("\n✅ Session is VALID in database")
                    
                    # Check other token data
                    user_id = payload_json.get('sub')
                    role = payload_json.get('vai_tro')
                    
                    if user_id != str(session_data.get('user_id')):
                        print(f"\n⚠️ User ID mismatch: {user_id} in token, {session_data.get('user_id')} in session")
                    
                    if role != session_data.get('role'):
                        print(f"\n⚠️ Role mismatch: {role} in token, {session_data.get('role')} in session")
                    
                    return True
                else:
                    print("\n❌ Session is INVALID in database")
                    return False
            else:
                print("\n❌ No results from database session check")
                return False
                
        except mysql.connector.Error as err:
            print(f"\n❌ Database error: {err}")
            return False
            
    except Exception as e:
        print(f"\n❌ Error decoding token: {str(e)}")
        return False

def fix_session(token):
    """Fix the session in the database if needed"""
    # First let's decode the token
    try:
        # Decode token (without verification)
        # Get the token parts
        parts = token.split('.')
        if len(parts) != 3:
            print("❌ Invalid token format")
            return False
            
        # Add padding if needed and decode header and payload
        def decode_base64_part(b64_str):
            from base64 import urlsafe_b64decode
            padding = 4 - (len(b64_str) % 4)
            if padding < 4:
                b64_str += '=' * padding
            return urlsafe_b64decode(b64_str.encode()).decode()
            
        payload_json = json.loads(decode_base64_part(parts[1]))
        
        # Get session ID from token
        session_id = payload_json.get('session_id')
        user_id = payload_json.get('sub')
        
        if not session_id or not user_id:
            print("❌ Missing session_id or sub (user_id) in token")
            return False
        
        # Check if the session exists in the database
        print("\n=== Checking Session in Database ===")
        
        try:
            # Connect to the database directly for manual query
            from app.utils.database import get_connection
            
            conn = get_connection()
            cursor = conn.cursor(dictionary=True)
            
            # Check if the session exists
            cursor.execute("SELECT * FROM phienlamviec WHERE session_id = %s", (session_id,))
            session = cursor.fetchone()
            
            if session:
                print(f"Session found: {json.dumps(session, default=str, indent=2)}")
                
                # Check if the session is active
                if session.get('is_active') == 1:
                    print("✅ Session is active")
                else:
                    print("❌ Session is inactive, updating...")
                    
                    # Update the session
                    cursor.execute(
                        "UPDATE phienlamviec SET is_active = 1, last_activity = CURRENT_TIMESTAMP WHERE session_id = %s", 
                        (session_id,)
                    )
                    conn.commit()
                    print("✅ Session activated")
                    
            else:
                print("❌ Session not found in database, creating new session...")
                
                # Create a new session
                # First, let's check the table structure to use the correct column names
                cursor.execute("DESCRIBE phienlamviec")
                columns = [column['Field'] for column in cursor.fetchall()]
                print(f"Available columns in phienlamviec table: {columns}")
                
                # Create insert statement based on available columns
                if 'created_at' in columns:
                    creation_time_column = 'created_at'
                elif 'ngay_tao' in columns:
                    creation_time_column = 'ngay_tao'
                else:
                    print("⚠️ Could not find creation time column, using default columns")
                    cursor.execute(
                        "INSERT INTO phienlamviec (session_id, user_id, is_active) VALUES (%s, %s, 1)",
                        (session_id, user_id)
                    )
                    conn.commit()
                    print("✅ New session created with minimal fields")
                    return True
                
                # Insert with the correct column name for creation time
                cursor.execute(
                    f"INSERT INTO phienlamviec (session_id, user_id, is_active, {creation_time_column}, last_activity) VALUES (%s, %s, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                    (session_id, user_id)
                )
                conn.commit()
                print("✅ New session created")
            
            # Verify the session
            cursor.execute("SELECT * FROM phienlamviec WHERE session_id = %s", (session_id,))
            updated_session = cursor.fetchone()
            print(f"Updated session: {json.dumps(updated_session, default=str, indent=2)}")
            
            # Close connections
            cursor.close()
            conn.close()
            
            return True
            
        except mysql.connector.Error as err:
            print(f"❌ Database error: {err}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False

def bypass_session_validation():
    """Temporarily modify the JWT validation to bypass session validation"""
    
    jwt_file_path = "d:/BaoMatThongTin/Nhom 06 - HeThongQuanLyBaoHiem/backend/app/auth/jwt.py"
    
    print("\n=== Creating JWT Validation Bypass ===")
    
    try:
        with open(jwt_file_path, 'r', encoding='utf-8') as file:
            content = file.read()
            
        # Create backup file
        with open(jwt_file_path + '.bak', 'w', encoding='utf-8') as file:
            file.write(content)
        
        # Look for the session validation part
        session_validation = """        # Validate session with database
        if session_id:
            try:
                result = execute_procedure("fastapi_validate_session", [session_id])
                if not result or len(result) == 0 or not result[0].get('result', {}).get('valid', False):
                    raise credentials_exception
            except Exception:
                raise credentials_exception"""
                
        # Create a bypassed version that only logs
        bypassed_validation = """        # Validate session with database - BYPASSED FOR DEBUGGING
        if session_id:
            try:
                # Debug log only
                print(f"[DEBUG] Session ID {session_id} - VALIDATION BYPASSED")
                # Comment out the validation temporarily
                # result = execute_procedure("fastapi_validate_session", [session_id])
                # if not result or len(result) == 0 or not result[0].get('result', {}).get('valid', False):
                #     raise credentials_exception
            except Exception as e:
                print(f"[DEBUG] Session validation error: {str(e)}")
                # Don't raise exception during debugging
                # raise credentials_exception"""
        
        # Replace the validation code
        new_content = content.replace(session_validation, bypassed_validation)
        
        if new_content != content:
            with open(jwt_file_path, 'w', encoding='utf-8') as file:
                file.write(new_content)
            print("✅ JWT validation modified to bypass session checks")
            print("A backup was created at:", jwt_file_path + '.bak')
            return True
        else:
            print("❌ Could not find the session validation code to modify")
            return False
            
    except Exception as e:
        print(f"❌ Error modifying JWT file: {str(e)}")
        return False

def restore_jwt_file():
    """Restore the original JWT file from backup"""
    jwt_file_path = "d:/BaoMatThongTin/Nhom 06 - HeThongQuanLyBaoHiem/backend/app/auth/jwt.py"
    
    try:
        # Check if backup exists
        import os
        if not os.path.exists(jwt_file_path + '.bak'):
            print("❌ No backup file found at:", jwt_file_path + '.bak')
            return False
            
        # Restore from backup
        with open(jwt_file_path + '.bak', 'r', encoding='utf-8') as file:
            content = file.read()
            
        with open(jwt_file_path, 'w', encoding='utf-8') as file:
            file.write(content)
            
        print("✅ JWT file restored from backup")
        return True
        
    except Exception as e:
        print(f"❌ Error restoring JWT file: {str(e)}")
        return False

def check_database_tables():
    """Check the structure of important tables in the database"""
    print("\n=== Database Table Structure Check ===")
    
    try:
        # Connect to the database directly
        from app.utils.database import get_connection
        
        conn = get_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Check session table structure
        print("\nChecking 'phienlamviec' table structure:")
        try:
            cursor.execute("DESCRIBE phienlamviec")
            columns = cursor.fetchall()
            for col in columns:
                print(f"- {col['Field']}: {col['Type']} (Null: {col['Null']}, Key: {col['Key']}, Default: {col['Default']})")
        except mysql.connector.Error as err:
            print(f"❌ Error checking phienlamviec table: {err}")
        
        # Check if there are any sessions in the table
        try:
            cursor.execute("SELECT COUNT(*) as count FROM phienlamviec")
            count = cursor.fetchone()['count']
            print(f"\nSessions in database: {count}")
            
            if count > 0:
                print("\nSample of existing sessions:")
                cursor.execute("SELECT * FROM phienlamviec LIMIT 3")
                sessions = cursor.fetchall()
                for session in sessions:
                    print(json.dumps(session, default=str, indent=2))
        except mysql.connector.Error as err:
            print(f"❌ Error checking sessions: {err}")
        
        # Close connections
        cursor.close()
        conn.close()
        
        return True
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False

def menu():
    """Display the menu options"""
    print("\n=== Authentication Debug and Fix Tools ===")
    print("1. Debug token and check session in database")
    print("2. Fix session in database")
    print("3. Bypass session validation (temporary debug measure)")
    print("4. Restore original JWT validation")
    print("5. Check database table structure")
    print("6. Exit")
    
    choice = input("\nEnter your choice (1-6): ")
    
    if choice == '1':
        token = input("\nEnter your JWT token: ")
        debug_token_with_db(token)
    elif choice == '2':
        token = input("\nEnter your JWT token: ")
        fix_session(token)
    elif choice == '3':
        bypass_session_validation()
    elif choice == '4':
        restore_jwt_file()
    elif choice == '5':
        check_database_tables()
    elif choice == '6':
        sys.exit(0)
    else:
        print("Invalid choice, please try again")
    
    # Show menu again
    menu()

if __name__ == "__main__":
    print("\nWelcome to the Authentication Debug Tool")
    menu()
