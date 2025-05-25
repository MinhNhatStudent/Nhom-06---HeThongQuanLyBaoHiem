# Hệ thống Quản lý Bảo hiểm - Backend API

Backend API cho Hệ thống Quản lý Bảo hiểm với tính năng bảo mật cao, mã hóa dữ liệu nhạy cảm và phân quyền nghiêm ngặt.

## Cấu trúc dự án

```
backend/
├── app/                    # Mã nguồn chính của ứng dụng
│   ├── auth/               # Module xác thực và phân quyền
│   ├── config/             # Cấu hình ứng dụng và môi trường
│   ├── models/             # Pydantic models cho validation
│   ├── routes/             # API endpoints và routers
│   ├── services/           # Business logic và services
│   ├── utils/              # Tiện ích và helpers
│   └── main.py             # Entry point của FastAPI
├── run.py                  # Script chạy ứng dụng
└── .env.template           # Template cho environment variables
```

## Yêu cầu hệ thống

- Python 3.8 trở lên
- MySQL 8.0 trở lên

## Thư viện sử dụng

- FastAPI: Framework API
- Uvicorn: ASGI server
- Pydantic: Data validation
- python-jose: JWT token handling
- mysql-connector-python: MySQL driver
- cryptography: Mã hóa dữ liệu

## Cài đặt và chạy ứng dụng

### 1. Cài đặt dependencies

```bash
pip install -r requirements.txt
```

### 2. Cấu hình môi trường

Sao chép file `.env.template` thành `.env` và điền thông tin phù hợp:

```bash
cp .env.template .env
```

### 3. Chạy ứng dụng

```bash
python run.py
```

Truy cập API docs tại: http://localhost:8000/docs

## Triển khai

Xem thêm hướng dẫn triển khai tại file `DEPLOY_GUIDE.md`.
