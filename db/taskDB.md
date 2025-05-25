As you complete tasks and references revelant files update this files this file as our memory to help with future task

# Danh sách nhiệm vụ cập nhật cơ sở dữ liệu

## 1. Thay đổi DB để tích hợp với FastAPI

### 1.1 Tạo file chuyển đổi phiên từ Django sang FastAPI
- [x] Tạo file `fastapi_integration.sql` để thay thế đoạn tích hợp Django trong `phien.sql`
- [x] Viết các hàm stored procedure với đầu vào/đầu ra phù hợp cho FastAPI
- [x] Bổ sung hướng dẫn sử dụng phiên trong FastAPI

### 1.2 Cập nhật stored procedures để tương thích với FastAPI
- [x] Điều chỉnh các stored procedures để trả về kết quả JSON
- [x] Đảm bảo kết quả trả về có cấu trúc phù hợp cho Pydantic models
- [x] Cập nhật các stored procedures để xử lý lỗi tốt hơn

### 1.3 Thêm các hàm hỗ trợ cho API
- [x] Tạo các stored procedures để hỗ trợ API phân trang
- [x] Tạo các stored procedures để hỗ trợ tìm kiếm và lọc dữ liệu

### 1.4 Tối ưu hóa truy vấn cho RESTful API
- [x] Chuẩn bị các stored procedures cho các endpoint thường dùng

## 2. Bổ sung các đề xuất cải tiến

### 2.1 Thêm trạng thái hợp đồng
- [x] Thêm trường `TrangThai` vào bảng `HopDong` với các giá trị: 'processing', 'active', 'expired', 'cancelled'
- [x] Cập nhật các procedures liên quan để xử lý trạng thái mới
- [x] Tạo trigger để tự động cập nhật trạng thái dựa trên ngày hiệu lực

### 2.2 Thêm trạng thái thanh toán
- [x] Thêm trường `TrangThai` vào bảng `ThanhToan` với các giá trị: 'pending', 'completed', 'failed', 'cancelled'
- [x] Cập nhật các procedures liên quan đến thanh toán
- [x] Tạo stored procedure để xử lý cập nhật thanh toán

### 2.3 Thêm địa chỉ tạm trú và địa chỉ liên lạc
- [x] Thêm trường `diachiTamTru` vào bảng `ChiTietHopDong`
- [x] Thêm trường `diachiLienLac` vào bảng `ChiTietHopDong`
- [x] Cập nhật các procedures đọc/ghi dữ liệu chứa địa chỉ
- [x] Mã hóa các trường địa chỉ mới như các trường nhạy cảm khác

### 2.4 Thêm giá trị bảo hiểm
- [x] Thêm trường `giaTriBaoHiem` vào bảng `HopDong`
- [x] Cập nhật các stored procedures liên quan
- [x] Tạo stored procedure tính toán giá trị bảo hiểm dựa trên các thông số 

## 3. Kiểm thử và triển khai

### 3.1 Cập nhật hướng dẫn triển khai
- [x] Cập nhật thứ tự thực thi các tập tin SQL
- [x] Viết hướng dẫn tích hợp với FastAPI
- [x] Mô tả cách sử dụng các stored procedures mới
