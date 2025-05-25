# Hướng dẫn triển khai cập nhật cơ sở dữ liệu

## Tổng quan về cập nhật
Tài liệu này hướng dẫn triển khai các cập nhật cho hệ thống Quản lý Bảo hiểm từ Task 2, bao gồm:
1. Thêm trạng thái hợp đồng
2. Thêm trạng thái thanh toán
3. Thêm địa chỉ tạm trú và địa chỉ liên lạc
4. Thêm giá trị bảo hiểm

## Thứ tự thực thi các tệp SQL

Để tránh xung đột và đảm bảo tất cả các chức năng hoạt động đúng, hãy thực thi các tệp SQL theo thứ tự sau:

1. `db.sql` - Tạo cấu trúc cơ sở dữ liệu ban đầu (bỏ qua nếu đã được thực hiện từ trước)
2. `mahoa.sql` - Thiết lập hệ thống mã hóa ban đầu (bỏ qua nếu đã được thực hiện từ trước)
3. `phien.sql` - Thiết lập hệ thống quản lý phiên làm việc (bỏ qua nếu đã được thực hiện từ trước)
4. `db_update.sql` - Cập nhật cấu trúc cơ sở dữ liệu và thêm các trường mới
5. `mahoa_update.sql` - Cập nhật hệ thống mã hóa cho trường mới
6. `json_utils.sql` - Thêm các tiện ích xử lý JSON cho API
7. `fastapi_integration.sql` - Thêm các stored procedures đặc biệt cho tích hợp FastAPI
8. `restapi_utils.sql` - Thêm các tiện ích hỗ trợ RESTful API như phân trang, tìm kiếm, và lọc

## Hướng dẫn chi tiết

### Bước 1: Cập nhật cấu trúc cơ sở dữ liệu

Thực thi tệp `db_update.sql`:

```bash
mysql -u [username] -p [database_name] < db_update.sql
```

Tệp này thực hiện:
- Thêm trường `TrangThai` vào bảng `HopDong`
- Thêm trường `TrangThai` vào bảng `ThanhToan`
- Thêm trường `diachiTamTru` và `diachiLienLac` vào bảng `ChiTietHopDong`
- Thêm trường `giaTriBaoHiem` vào bảng `HopDong`
- Tạo các trigger cần thiết
- Tạo các stored procedure mới

### Bước 2: Cập nhật hệ thống mã hóa

Thực thi tệp `mahoa_update.sql`:

```bash
mysql -u [username] -p [database_name] < mahoa_update.sql
```

Tệp này thực hiện:
- Cập nhật trigger mã hóa để hỗ trợ các trường địa chỉ mới
- Cập nhật các thủ tục lưu trữ để xử lý các trường mới
- Thêm thủ tục để mã hóa dữ liệu hiện có cho các trường mới

### Bước 3: Mã hóa dữ liệu hiện có (nếu cần)

Nếu đã có dữ liệu trong hệ thống, chạy thủ tục để mã hóa các trường mới:

```sql
CALL encrypt_new_address_fields();
```

### Bước 4: Kiểm tra và tính toán giá trị bảo hiểm

Tính giá trị bảo hiểm cho tất cả hợp đồng hiện có:

```sql
CALL sp_TinhLaiTatCaGiaTriBaoHiem();
```

## Tích hợp với FastAPI

Dự án đã được chuyển từ Django sang FastAPI. Các tệp `fastapi_example.py` và `fastapi_examples_update.py` cung cấp code mẫu để tích hợp với FastAPI. Dưới đây là hướng dẫn chi tiết:

### 1. Cài đặt các thư viện cần thiết:
```bash
pip install fastapi uvicorn mysql-connector-python python-jose python-multipart
```

### 2. Định nghĩa mô hình Pydantic:
FastAPI sử dụng Pydantic để xác thực dữ liệu và tự động tạo tài liệu API. Các model mới cần được định nghĩa:
- `ContractStatus`: Cho trạng thái hợp đồng (`processing`, `active`, `expired`, `cancelled`)
- `PaymentStatus`: Cho trạng thái thanh toán (`pending`, `completed`, `failed`, `cancelled`)
- `AddressUpdate`: Cho các trường địa chỉ mới (`diachi_tam_tru`, `diachi_lien_lac`)
- `InsuranceValue`: Cho giá trị bảo hiểm

Ví dụ mẫu từ `fastapi_examples_update.py`:
```python
class ContractStatus(BaseModel):
    contract_id: int
    status: str = Field(..., description="Trạng thái hợp đồng: processing, active, expired, cancelled")

class PaymentStatus(BaseModel):
    payment_id: int
    status: str = Field(..., description="Trạng thái thanh toán: pending, completed, failed, cancelled")
    note: Optional[str] = None
```

### 3. Tạo các endpoint REST API:
#### Endpoints cho hợp đồng:
- `GET /contracts`: Lấy danh sách hợp đồng (với phân trang và tìm kiếm)
- `GET /contracts/{contract_id}`: Lấy chi tiết một hợp đồng
- `POST /contracts`: Tạo hợp đồng mới
- `PUT /contracts/{contract_id}`: Cập nhật thông tin hợp đồng
- `PUT /contracts/{contract_id}/status`: Cập nhật trạng thái hợp đồng
- `PUT /contracts/{contract_id}/insurance-value`: Cập nhật giá trị bảo hiểm
- `POST /contracts/{contract_id}/calculate-insurance-value`: Tính giá trị bảo hiểm

#### Endpoints cho thanh toán:
- `GET /payments`: Lấy danh sách thanh toán (với phân trang và lọc)
- `GET /payments/{payment_id}`: Lấy chi tiết một thanh toán
- `POST /payments`: Tạo thanh toán mới
- `PUT /payments/{payment_id}/status`: Cập nhật trạng thái thanh toán

#### Endpoints cho thông tin người dùng và địa chỉ:
- `PUT /contract-details/{detail_id}/addresses`: Cập nhật địa chỉ mới (thường trú, tạm trú, liên lạc)

### 4. Xử lý phiên và xác thực:
FastAPI sử dụng các stored procedures đặc biệt để quản lý phiên làm việc và xác thực người dùng:

#### Đăng nhập và tạo token:
```python
@app.post("/login", response_model=TokenResponse)
async def login(form_data: OAuth2PasswordRequestForm = Depends(), conn: Connection = Depends(get_db_connection)):
    cursor = conn.cursor(dictionary=True)
    session_id = str(uuid.uuid4())
    
    # Gọi stored procedure đăng nhập với FastAPI
    cursor.execute("CALL fastapi_login(%s, %s, %s, %s)", 
                  (form_data.username, form_data.password, session_id, get_client_ip()))
    result = cursor.fetchone()["result"]
    response = json.loads(result)
    
    if not response["success"]:
        raise HTTPException(status_code=401, detail="Tên đăng nhập hoặc mật khẩu không đúng")
    
    # Tạo JWT token
    access_token = create_access_token(
        data={"sub": form_data.username, "session_id": session_id, "user_id": response["user_id"]}
    )
    
    return {"access_token": access_token, "token_type": "bearer", "role": response["role"]}
```

#### Xác thực người dùng cho mỗi request:
```python
async def get_current_user(token: str = Depends(oauth2_scheme), conn: Connection = Depends(get_db_connection)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
        session_id = payload.get("session_id")
        
        if username is None or session_id is None:
            raise HTTPException(status_code=401, detail="Token không hợp lệ")
        
        # Kiểm tra phiên có hợp lệ không
        cursor = conn.cursor(dictionary=True)
        cursor.execute("CALL fastapi_validate_session(%s)", (session_id,))
        validation = json.loads(cursor.fetchone()["result"])
        
        if not validation["valid"]:
            raise HTTPException(status_code=401, detail="Phiên làm việc không hợp lệ")
        
        return {
            "username": username, 
            "session_id": session_id,
            "user_id": validation["user_id"],
            "role": validation["role"],
            "insurance_type": validation["insurance_type"]
        }
    except JWTError:
        raise HTTPException(status_code=401, detail="Token không hợp lệ hoặc đã hết hạn")
```

### 5. Gọi stored procedures để truy vấn dữ liệu:
Các stored procedure đã được tối ưu để trả về kết quả dạng JSON, giúp tích hợp dễ dàng với FastAPI:

```python
@app.get("/contracts", response_model=Dict[str, Any])
async def get_contracts(
    search: Optional[str] = None,
    status: Optional[str] = None,
    page: int = Query(0, ge=0),
    page_size: int = Query(10, ge=1, le=100),
    current_user: dict = Depends(get_current_user),
    conn: Connection = Depends(get_db_connection)
):
    cursor = conn.cursor(dictionary=True)
    cursor.execute("CALL get_contracts_paginated(%s, %s, %s, %s, %s, %s)",
                  (current_user["user_id"], current_user["role"], search, status, page, page_size))
    result = cursor.fetchone()["result"]
    return json.loads(result)
```

## Cách sử dụng các Stored Procedures mới

### 1. Quản lý trạng thái hợp đồng:
```sql
-- Cập nhật trạng thái hợp đồng
CALL sp_CapNhatTrangThaiHopDong(id_hopdong, 'active');

-- Lấy danh sách hợp đồng theo trạng thái (trả về JSON)
CALL get_contracts_by_status_json('active', id_nguoi_dung, vai_tro);

-- Kiểm tra trạng thái hợp đồng
CALL check_contract_status_json(id_hopdong);
```

### 2. Quản lý trạng thái thanh toán:
```sql
-- Cập nhật trạng thái thanh toán
CALL sp_CapNhatTrangThaiThanhToan(id_thanhtoan, 'completed', 'Đã thanh toán qua ngân hàng');

-- Lấy danh sách thanh toán theo trạng thái
CALL sp_LayDanhSachThanhToanTheoTrangThai('pending', id_hopdong);

-- Lấy danh sách thanh toán theo trạng thái (trả về JSON)
CALL get_payments_by_status_json('pending', id_hopdong, id_nguoi_dung, vai_tro);
```

### 3. Cập nhật địa chỉ:
```sql
-- Cập nhật địa chỉ cho chi tiết hợp đồng
CALL sp_CapNhatDiaChiChiTietHopDong(id_chitiet, 'Địa chỉ thường trú mới', 'Địa chỉ tạm trú', 'Địa chỉ liên lạc');

-- Lấy thông tin địa chỉ đã giải mã (trả về JSON)
CALL get_contract_addresses_json(id_chitiet, id_nguoi_dung, vai_tro);
```

### 4. Quản lý giá trị bảo hiểm:
```sql
-- Tính giá trị bảo hiểm cho một hợp đồng
CALL sp_TinhGiaTriBaoHiem(id_hopdong);

-- Cập nhật giá trị bảo hiểm
CALL sp_CapNhatGiaTriBaoHiem(id_hopdong, 5000000);

-- Tính lại giá trị bảo hiểm cho tất cả hợp đồng
CALL sp_TinhLaiTatCaGiaTriBaoHiem();

-- Lấy thông tin giá trị bảo hiểm (trả về JSON)
CALL get_insurance_value_json(id_hopdong, id_nguoi_dung, vai_tro);
```

### 5. Stored Procedures cho phân trang và tìm kiếm:
```sql
-- Lấy danh sách người dùng có phân trang và tìm kiếm
CALL get_users_paginated('tên_tìm_kiếm', 'vai_trò', 'trạng_thái', trang, số_phần_tử_mỗi_trang);

-- Lấy danh sách hợp đồng có phân trang và tìm kiếm
CALL get_contracts_paginated(id_nguoi_dung, vai_tro, 'tên_tìm_kiếm', 'trạng_thái', trang, số_phần_tử_mỗi_trang);

-- Lấy danh sách thanh toán có phân trang và tìm kiếm
CALL get_payments_paginated(id_nguoi_dung, vai_tro, 'trạng_thái', id_hopdong, trang, số_phần_tử_mỗi_trang);
```

### 6. Stored Procedures dành riêng cho FastAPI:
```sql
-- Đăng nhập và bắt đầu phiên FastAPI
CALL fastapi_login('username', 'password', 'session_id', 'ip_address');

-- Xác thực phiên FastAPI
CALL fastapi_validate_session('session_id');

-- Đăng xuất và kết thúc phiên FastAPI
CALL fastapi_logout('session_id');

-- Đổi mật khẩu
CALL fastapi_change_password(id_nguoi_dung, 'mật_khẩu_cũ', 'mật_khẩu_mới', 'session_id');

-- Kiểm tra quyền truy cập
CALL fastapi_check_permission(id_nguoi_dung, 'phạm_vi', id_đối_tượng);
```

## Lưu ý quan trọng

1. **Xử lý dữ liệu mã hóa**: Tất cả các trường địa chỉ mới đều được mã hóa tự động. Khi truy xuất, hãy sử dụng các stored procedure đã được cung cấp để giải mã. Các thủ tục trả về JSON đã tự động giải mã dữ liệu cho bạn.

2. **Trigger tự động**: Hệ thống có các trigger tự động cập nhật trạng thái hợp đồng và tính toán lại giá trị bảo hiểm. Không cần gọi thủ tục cập nhật mỗi khi thay đổi dữ liệu liên quan.

3. **RESTful API**: Các stored procedure mới đã được tối ưu hóa để trả về dữ liệu dạng JSON, phù hợp với các API RESTful. Sử dụng các thủ tục có hậu tố `_json` để tích hợp dễ dàng với FastAPI.

4. **Phân trang**: Các stored procedure hỗ trợ phân trang và tìm kiếm cho tất cả các truy vấn lấy danh sách, giúp tối ưu hóa hiệu suất khi làm việc với lượng dữ liệu lớn.

5. **Phiên và bảo mật**: Các thủ tục dành cho FastAPI có sẵn cơ chế xác thực phiên và quản lý bảo mật. Hãy sử dụng chúng thay vì tự xây dựng cơ chế xác thực riêng.

6. **Production**: Trước khi triển khai vào môi trường sản xuất, hãy kiểm tra kỹ các thay đổi trong môi trường thử nghiệm, đặc biệt là các chức năng mã hóa và quản lý phiên làm việc.

## Hướng dẫn di chuyển từ Django sang FastAPI

### Tổng quan về việc di chuyển
Dự án đã được chuyển từ Django sang FastAPI để cải thiện hiệu suất và tối ưu hoá cho API. Các thay đổi chính bao gồm:
1. Thay đổi hệ thống xác thực và phiên làm việc
2. Chuyển đổi các view thành endpoint API
3. Chuyển đổi Django ORM thành các stored procedure
4. Cập nhật hệ thống phân quyền

### So sánh kiến trúc
| Tính năng | Django | FastAPI |
|-----------|--------|---------|
| ORM | Django ORM | Truy vấn trực tiếp qua stored procedure |
| Xác thực | Session-based | Token-based (JWT) |
| Form | Django Forms | Pydantic Models |
| Định tuyến | URL patterns | Decorator @app.route |
| Template | Django Templates | Frontend riêng biệt |
| Middleware | Django Middleware | FastAPI Middleware |

### Các bước di chuyển chi tiết

#### 1. Chuyển đổi mô hình dữ liệu
- Django Models → Pydantic Models
- Validators → Pydantic Field Validators

```python
# Django Model (cũ)
class HopDong(models.Model):
    tenBH = models.CharField(max_length=100)
    ngayKiHD = models.DateField()
    ngayCatHD = models.DateField()
    
# Pydantic Model (mới)
class Contract(BaseModel):
    contract_id: Optional[int] = None
    insurance_name: str
    start_date: date
    end_date: date
    status: str = Field(..., description="Trạng thái: processing, active, expired, cancelled")
    insurance_value: Optional[float] = None
```

#### 2. Chuyển đổi xác thực
Django sử dụng hệ thống phiên dựa trên cookie, trong khi FastAPI sử dụng xác thực dựa trên token JWT.

```python
# FastAPI Authentication
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

@app.post("/login")
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    # Xác thực và tạo token
    access_token = create_access_token(data={"sub": username, "session_id": session_id})
    return {"access_token": access_token, "token_type": "bearer"}
    
async def get_current_user(token: str = Depends(oauth2_scheme)):
    # Xác thực token và trả về thông tin người dùng
```

#### 3. Chuyển đổi view thành endpoint API

```python
# Django View (cũ)
@login_required
def view_contract(request, contract_id):
    contract = get_object_or_404(HopDong, pk=contract_id)
    return render(request, 'contract_detail.html', {'contract': contract})

# FastAPI Endpoint (mới)
@app.get("/contracts/{contract_id}", response_model=ContractDetail)
async def get_contract(
    contract_id: int,
    current_user: dict = Depends(get_current_user),
    conn: Connection = Depends(get_db_connection)
):
    cursor = conn.cursor(dictionary=True)
    cursor.execute("CALL get_contract_detail_json(%s, %s, %s)",
                   (contract_id, current_user["user_id"], current_user["role"]))
    result = cursor.fetchone()["result"]
    if not result:
        raise HTTPException(status_code=404, detail="Hợp đồng không tồn tại")
    return json.loads(result)
```

### Một số lưu ý khi di chuyển

1. **Các endpoint API mới**:
   - Đọc tài liệu API dưới dạng Swagger UI tại `/docs` hoặc ReDoc tại `/redoc` sau khi khởi chạy ứng dụng FastAPI.
   - Tất cả các endpoint đều tuân theo nguyên tắc RESTful.

2. **Phiên và xác thực**:
   - Phiên làm việc bây giờ được quản lý thông qua token JWT.
   - Các token có thời hạn, cần làm mới token khi hết hạn.
   - Stored procedures `fastapi_login`, `fastapi_validate_session` và `fastapi_logout` được sử dụng để quản lý phiên.

3. **Phân quyền**:
   - Phân quyền vẫn dựa trên vai trò (RBAC) nhưng được xử lý ở stored procedure thay vì middleware.
   - Mọi stored procedure phải kiểm tra quyền dựa trên vai trò và phạm vi truy cập.

4. **Xử lý lỗi**:
   - Sử dụng HTTP status code thay vì Django messages để thông báo lỗi.
   - Stored procedure trả về các đối tượng JSON với trường `success` và `error_message` để xử lý lỗi một cách nhất quán.

## Ví dụ cách chạy ứng dụng FastAPI

### 1. Cài đặt các thư viện cần thiết
```bash
pip install fastapi uvicorn mysql-connector-python python-jose python-multipart
```

### 2. Khởi chạy ứng dụng
```bash
uvicorn fastapi_example:app --reload
```

### 3. Truy cập tài liệu API
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### 4. Sử dụng công cụ API testing
Bạn có thể sử dụng các công cụ như Postman, Insomnia hoặc curl để kiểm tra API. Ví dụ với curl:

```bash
# Đăng nhập và lấy token
curl -X POST "http://localhost:8000/login" -H "Content-Type: application/x-www-form-urlencoded" -d "username=admin&password=admin"

# Sử dụng token để truy cập API
curl -X GET "http://localhost:8000/contracts" -H "Authorization: Bearer {token}"
```
