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

### 1.2 Phát triển module xác thực và phân quyền

#### 1.2.1 Xác thực người dùng
- [x] Tạo endpoint `/login` cho đăng nhập và sinh token JWT
- [x] Tích hợp với stored procedure `fastapi_login` để xác thực thông tin đăng nhập
- [x] Triển khai JWT cơ bản với thời hạn hợp lý
- [x] Tạo endpoint `/logout` và tích hợp với `fastapi_logout`

#### 1.2.2 Quản lý phiên làm việc
- [x] Tạo model Pydantic cho session data
- [x] Tích hợp với stored procedure `fastapi_validate_session` để xác thực phiên
- [x] Cài đặt cơ chế timeout và tự động đăng xuất

#### 1.2.3 Triển khai middleware bảo mật
- [x] Tạo middleware xác thực token JWT cho các API bảo mật
- [x] Xây dựng dependency để lấy thông tin người dùng hiện tại
- [x] Thêm middleware ghi log hoạt động người dùng

#### 1.2.4 Phân quyền theo vai trò
- [x] Tạo hệ thống kiểm tra quyền hạn dựa trên token
- [x] Tích hợp với stored procedure `fastapi_check_permission`
- [x] Xây dựng các decorators cho phép kiểm tra quyền ở cấp endpoint

### 1.3 Phát triển API quản lý người dùng
- [ ] API đăng ký người dùng
- [ ] API kích hoạt tài khoản qua email
- [ ] API quản lý thông tin người dùng và vai trò
- [ ] API đặt lại mật khẩu 

### 1.4 Phát triển API quản lý hợp đồng
- [ ] API tạo và cập nhật hợp đồng
- [ ] API xem danh sách và chi tiết hợp đồng
- [ ] API quản lý trạng thái hợp đồng
- [ ] API tính toán và cập nhật giá trị bảo hiểm
- [ ] Kiểm tra phân quyền cho các API hợp đồng

### 1.5 Phát triển API quản lý thanh toán
- [ ] API tạo kỳ thanh toán mới
- [ ] API cập nhật trạng thái thanh toán
- [ ] API xem lịch sử thanh toán

### 1.7 Triển khai audit log
- [ ] API xem các log trong bảng audit_logs của user ID nhất định
- [ ] API xem các log trong bảng user_activity logs của user ID nhất định

### 1.8 Viết tài liệu API và kiểm thử cơ bản
- [ ] Tạo tài liệu API với OpenAPI/Swagger
- [ ] Viết kiểm thử cơ bản cho các API chính

## 2. Tích hợp Frontend với Backend

### 2.1 Tích hợp các trang xác thực
- [ ] Cập nhật trang đăng nhập/đăng ký để sử dụng API
- [ ] Cập nhật trang kích hoạt tài khoản

### 2.2 Tích hợp các trang quản lý hợp đồng chính
- [ ] Tích hợp trang xem danh sách hợp đồng
- [ ] Tích hợp trang tạo và cập nhật hợp đồng
- [ ] Tích hợp trang chi tiết hợp đồng
- [ ] Thêm tính năng quản lý trạng thái hợp đồng

### 2.3 Tích hợp các trang quản lý thanh toán chính
- [ ] Tích hợp trang xem lịch sử thanh toán
- [ ] Tích hợp trang cập nhật trạng thái thanh toán

### 2.4 Tích hợp các trang theo vai trò chính
- [ ] Cập nhật trang giám sát (`giamsat.html`) 
- [ ] Cập nhật trang kế toán (`ketoan.html`)
- [ ] Cập nhật trang người lập hợp đồng (`nlhd.html`)
- [ ] Cập nhật trang khách hàng (`kh_*.html`) cơ bản
- [ ] Cập nhật trang quản trị (`admin_*.html`) cơ bản

## 3. Bảo mật và Kiểm thử

### 3.1 Kiểm thử cơ bản
- [ ] Kiểm tra chức năng xác thực và phân quyền
- [ ] Kiểm tra chức năng mã hóa/giải mã dữ liệu
- [ ] Kiểm tra ghi và xem audit log

## Lưu ý quan trọng
- Tập trung vào yêu cầu cốt lõi: mã hóa dữ liệu, RBAC và audit hành vi người dùng
- Ưu tiên phát triển các tính năng cần thiết cho môn học Bảo mật cơ sở dữ liệu
- Đơn giản hóa các tính năng phức tạp không cần thiết
- Đảm bảo phân quyền chặt chẽ theo vai trò người dùng
- Kiểm tra các stored procedure trước khi tích hợp với FastAPI
- Tuân thủ các nguyên tắc RESTful API để API dễ sử dụng
