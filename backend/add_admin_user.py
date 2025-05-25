"""
Chạy script này để thêm giá trị 'admin' vào ENUM vaitro và tạo tài khoản admin
"""
import mysql.connector
import os
from pathlib import Path

def execute_sql_file(cursor, file_path):
    print(f"Thực thi tập tin SQL: {file_path}")
    
    # Đọc tập tin SQL
    with open(file_path, 'r', encoding='utf-8') as sql_file:
        sql_content = sql_file.read()
    
    # Chia theo DELIMITER để xử lý stored procedures
    statements = []
    current_delimiter = ";"
    buffer = ""
    
    for line in sql_content.splitlines():
        # Xử lý thay đổi delimiter
        if line.strip().startswith("DELIMITER "):
            # Hoàn thành câu lệnh hiện tại nếu có gì trong buffer
            if buffer.strip():
                statements.append((buffer, current_delimiter))
                buffer = ""
            # Đặt delimiter mới
            current_delimiter = line.strip().split()[1]
            continue
        
        # Thêm dòng vào buffer
        buffer += line + "\n"
        
        # Kiểm tra xem dòng này kết thúc bằng delimiter hiện tại không
        if line.strip().endswith(current_delimiter):
            statements.append((buffer, current_delimiter))
            buffer = ""
    
    # Thêm nội dung còn lại
    if buffer.strip():
        statements.append((buffer, current_delimiter))
    
    # Thực thi từng câu lệnh
    for statement, delimiter in statements:
        if statement.strip():
            try:
                # Xóa delimiter ở cuối trước khi thực thi
                clean_statement = statement.strip()
                if clean_statement.endswith(delimiter):
                    clean_statement = clean_statement[:-len(delimiter)]
                
                # In 100 ký tự đầu tiên của câu lệnh
                print(f"Thực thi: {clean_statement[:100]}...")
                
                cursor.execute(clean_statement)
                print("Câu lệnh thực thi thành công.")
            except mysql.connector.Error as err:
                print(f"Lỗi thực thi câu lệnh: {err}")
                print(f"Câu lệnh lỗi: {clean_statement}")

def main():
    # Cấu hình kết nối cơ sở dữ liệu
    config = {
        'user': 'root',
        'password': '',  # Cập nhật mật khẩu MySQL của bạn
        'host': 'localhost',
        'database': 'insurance_management',
        'raise_on_warnings': True
    }
    
    try:
        # Thiết lập kết nối
        print("Đang kết nối đến cơ sở dữ liệu...")
        connection = mysql.connector.connect(**config)
        
        if connection.is_connected():
            print("Đã kết nối đến cơ sở dữ liệu MySQL")
            
            # Tạo cursor
            cursor = connection.cursor()
            
            # Lấy đường dẫn thư mục script
            script_dir = Path(os.path.dirname(os.path.abspath(__file__)))
            db_dir = script_dir.parent / "db"
            
            # Thực thi tập tin SQL
            sql_file = db_dir / "add_admin_role.sql"
            
            if sql_file.exists():
                execute_sql_file(cursor, sql_file)
            else:
                print(f"Không tìm thấy tập tin: {sql_file}")
            
            # Commit các thay đổi
            connection.commit()
            print("Tất cả các thay đổi đã được lưu vào cơ sở dữ liệu")
            
            # Hiển thị thông tin người dùng admin
            cursor.execute("SELECT id, username, email, vaitro FROM NguoiDung WHERE username = 'admin'")
            admin_user = cursor.fetchone()
            
            if admin_user:
                print("\nThông tin tài khoản admin:")
                print(f"ID: {admin_user[0]}")
                print(f"Username: {admin_user[1]}")
                print(f"Email: {admin_user[2]}")
                print(f"Vai trò: {admin_user[3]}")
                print("\nChi tiết đăng nhập:")
                print("Username: admin")
                print("Password: Admin@123")
            else:
                print("Không tìm thấy tài khoản admin!")
            
    except mysql.connector.Error as err:
        print(f"Lỗi: {err}")
    
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()
            print("Đã đóng kết nối cơ sở dữ liệu")

if __name__ == "__main__":
    main()
