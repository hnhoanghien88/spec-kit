# ERD tổng

Tài liệu này là **điểm vào** cho mô hình dữ liệu toàn dự án. ERD chi tiết theo nghiệp vụ nằm ở
nguồn gốc; đây chỉ tổng hợp và bổ sung phần còn thiếu.

## Nguồn ERD chi tiết

- **Nghiệp vụ Compliance** (rule, condition, actual, object map…): xem `compliance-client/ERD.md`.
- **Mô hình dữ liệu theo feature**: xem `specs/NNN-*/data-model.md` (vd
  [specs/001-eutr-steps/data-model.md](../../specs/001-eutr-steps/data-model.md)).

## Bảng theo feature đã triển khai

### `eutr_steps` (feature 001-eutr-steps)

| Cột | Kiểu | Ghi chú |
|-----|------|---------|
| `Id` | bigint (PK) | khóa chính |
| `Name` | nvarchar | tên bước, bắt buộc |
| `CreatedDate` | datetime | audit (BaseEntity) |
| `CreatedBy` | nvarchar | audit |
| `UpdatedDate` | datetime | audit |
| `UpdatedBy` | nvarchar | audit |

> "Prefix" hiển thị trên UI là **slug suy ra từ `Name`**, KHÔNG phải cột lưu trong DB.

## Quy ước

Quy ước đặt tên & trường audit: xem [conventions.md](conventions.md).
