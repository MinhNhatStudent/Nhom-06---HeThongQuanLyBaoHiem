"""
Script để lấy activation token từ cơ sở dữ liệu
"""
import mysql.connector

def get_activation_token(user_id):
    try:
        # Kết nối đến cơ sở dữ liệu
        connection = mysql.connector.connect(
            host="localhost",
            user="root",
            password="",  # Thay đổi mật khẩu nếu cần
            database="insurance_management"
        )
        
        cursor = connection.cursor(dictionary=True)
        
        # Truy vấn token kích hoạt
        query = "SELECT id, username, email, activation_token FROM NguoiDung WHERE id = %s"
        cursor.execute(query, (user_id,))
        
        user = cursor.fetchone()
        
        if user:
            print(f"Thông tin người dùng có ID {user_id}:")
            print(f"Username: {user['username']}")
            print(f"Email: {user['email']}")
            print(f"Token kích hoạt: {user['activation_token']}")
            print("\nSử dụng token này để kích hoạt tài khoản với API /users/activate")
            print("Ví dụ:")
            print(f"""
curl -X 'POST' \\
  'http://127.0.0.1:8000/users/activate' \\
  -H 'accept: application/json' \\
  -H 'Content-Type: application/json' \\
  -d '{{
  "token": "{user['activation_token']}",
  "password": "Test@123"
}}'
            """)
        else:
            print(f"Không tìm thấy người dùng với ID {user_id}")
            
    except mysql.connector.Error as err:
        print(f"Lỗi: {err}")
    
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()
            print("Đã đóng kết nối MySQL")

if __name__ == "__main__":
    user_id = input("Nhập user ID từ API response (ví dụ: 13): ")
    try:
        user_id = int(user_id)
        get_activation_token(user_id)
    except ValueError:
        print("User ID phải là một số nguyên")
