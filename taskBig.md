As you complete tasks and references revelant files update this files this file as our memory to help with future task

# Danh sách nhiệm vụ phát triển Hệ thống Quản lý Bảo hiểm

## Tổng quan tiến độ
- [x] Phân tích và thiết kế cơ sở dữ liệu
- [x] Cập nhật cơ sở dữ liệu để tích hợp với FastAPI
- [x] Bổ sung cải tiến trong cơ sở dữ liệu (trạng thái hợp đồng, thanh toán, địa chỉ...)
- [ ] Phát triển FastAPI Backend
- [ ] Tích hợp giao diện người dùng với API
- [ ] Triển khai và kiểm thử hệ thống

## 1. Phát triển Backend với FastAPI

### 1.1 Thiết lập dự án FastAPI
- [x] Tạo cấu trúc thư mục dự án
  - [x] Models
  - [x] Routes
  - [x] Services
  - [x] Auth
  - [x] Utils
- [x] Thiết lập cấu hình môi trường (development, production)
- [x] Cài đặt và thiết lập các thư viện cần thiết
(Đã chạy lệnh cài đặt các thư viện trong file requirements.txt)

### 1.2 Phát triển module xác thực và quản lý phiên

#### 1.2.1 Xác thực người dùng
- [ ] Tạo endpoint `/login` cho đăng nhập và sinh token JWT
- [ ] Tích hợp với stored procedure `fastapi_login` để xác thực thông tin đăng nhập
- [ ] Triển khai OAuth2PasswordBearer cho FastAPI
- [ ] Cài đặt JWT với các tùy chọn bảo mật (thời gian hết hạn, thuật toán mã hóa)
- [ ] Tạo endpoint `/logout` và tích hợp với `fastapi_logout`

#### 1.2.2 Quản lý phiên làm việc
- [ ] Tạo model Pydantic cho session data
- [ ] Tích hợp với stored procedure `fastapi_validate_session` để xác thực phiên
- [ ] Triển khai cơ chế theo dõi và refresh token
- [ ] Cài đặt cơ chế timeout và tự động đăng xuất

#### 1.2.3 Triển khai middleware bảo mật
- [ ] Tạo middleware xác thực token JWT cho các API bảo mật
- [ ] Cài đặt middleware kiểm tra thông tin phiên làm việc
- [ ] Xây dựng dependency để lấy thông tin người dùng hiện tại
- [ ] Thêm middleware ghi log hoạt động người dùng

#### 1.2.4 Phân quyền theo vai trò
- [ ] Tạo hệ thống kiểm tra quyền hạn dựa trên token
- [ ] Tích hợp với stored procedure `fastapi_check_permission`
- [ ] Xây dựng các decorators cho phép kiểm tra quyền ở cấp endpoint
- [ ] Triển khai cơ chế cache thông tin phân quyền để tăng hiệu suất

### 1.3 Phát triển các endpoints API cho quản lý người dùng
- [ ] API đăng ký người dùng
- [ ] API kích hoạt tài khoản qua email
- [ ] API quản lý thông tin người dùng
- [ ] API đặt lại mật khẩu
- [ ] API quản lý vai trò

### 1.4 Phát triển các endpoints API cho quản lý hợp đồng
- [ ] API tạo và cập nhật hợp đồng
- [ ] API xem danh sách và chi tiết hợp đồng
- [ ] API quản lý trạng thái hợp đồng
- [ ] API tính toán và cập nhật giá trị bảo hiểm
- [ ] Kiểm tra phân quyền cho các API hợp đồng

### 1.5 Phát triển các endpoints API cho quản lý thanh toán
- [ ] API tạo kỳ thanh toán mới
- [ ] API cập nhật trạng thái thanh toán
- [ ] API xem lịch sử thanh toán
- [ ] API thống kê thanh toán theo thời gian/loại bảo hiểm

### 1.6 Phát triển API xử lý dữ liệu mã hóa
- [ ] API giải mã dữ liệu nhạy cảm theo quyền
- [ ] API quản lý khóa mã hóa (cho admin)
- [ ] Lớp trung gian xử lý dữ liệu mã hóa/giải mã

### 1.7 Phát triển API báo cáo và thống kê
- [ ] API báo cáo theo loại bảo hiểm

### 1.8 Viết tài liệu API và kiểm thử
- [ ] Tạo tài liệu API với OpenAPI/Swagger
- [ ] Viết unit tests cho các endpoints
- [ ] Viết integration tests kiểm tra luồng dữ liệu

## 2. Tích hợp Frontend với Backend

### 2.1 Cập nhật các trang người dùng
- [ ] Cập nhật trang đăng nhập/đăng ký để sử dụng API
- [ ] Cập nhật trang kích hoạt tài khoản
- [ ] Cập nhật trang quên mật khẩu

### 2.2 Tích hợp các trang quản lý hợp đồng
- [ ] Tích hợp trang xem danh sách hợp đồng
- [ ] Tích hợp trang tạo và cập nhật hợp đồng
- [ ] Tích hợp trang chi tiết hợp đồng
- [ ] Thêm tính năng quản lý trạng thái hợp đồng

### 2.3 Tích hợp các trang quản lý thanh toán
- [ ] Tích hợp trang xem lịch sử thanh toán
- [ ] Tích hợp trang tạo kỳ thanh toán mới
- [ ] Tích hợp trang cập nhật trạng thái thanh toán

### 2.4 Tích hợp các trang theo vai trò người dùng
- [ ] Cập nhật trang giám sát (`giamsat.html`)
- [ ] Cập nhật trang kế toán (`ketoan.html`)
- [ ] Cập nhật trang người lập hợp đồng (`nlhd.html`)
- [ ] Cập nhật trang khách hàng (`kh_*.html`)
- [ ] Cập nhật trang quản trị (`admin_*.html`)

### 2.5 Cải thiện giao diện người dùng
- [ ] Thêm thông báo và xử lý lỗi
- [ ] Thêm tính năng phân trang cho bảng dữ liệu

## 3. Bảo mật và Kiểm thử

### 3.1 Kiểm thử bảo mật
- [ ] Kiểm tra xác thực và phân quyền
- [ ] Kiểm tra mã hóa dữ liệu

## Lưu ý quan trọng
- Phát triển theo phương pháp Agile, ưu tiên những tính năng cốt lõi trước
- Đảm bảo mỗi chức năng đều được kiểm thử kỹ lưỡng trước khi tích hợp
- Bảo mật luôn là ưu tiên hàng đầu, đặc biệt với dữ liệu nhạy cảm
- Kiểm tra các stored procedure trước khi tích hợp với FastAPI
- Tuân thủ các nguyên tắc RESTful API để API dễ sử dụng và mở rộng
- Đảm bảo phân quyền chặt chẽ theo vai trò người dùng
