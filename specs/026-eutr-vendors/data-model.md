# Data Model: EUTR Vendors

## Bảng `eutr_vendors`

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| Id | BIGINT UNSIGNED | PK, AUTO_INCREMENT |
| Code | VARCHAR(50) | NOT NULL, UNIQUE |
| Name | VARCHAR(255) | NOT NULL |
| CreatedBy | VARCHAR(50) | NULL (email người tạo) |
| CreatedDate | DATETIME | NULL |

Không có cột Updated*; không có khóa ngoại.

## Quy tắc validation
- Code, Name: bắt buộc (sau khi trim), Code ≤ 50, Name ≤ 255 ký tự.
- Code duy nhất không phân biệt hoa/thường (kiểm tra ở service + UNIQUE index).
- Sửa: giữ nguyên CreatedBy/CreatedDate.

## Entity `EutrVendors` (không kế thừa BaseEntity)
`Id (long)`, `Code`, `Name`, `CreatedBy`, `CreatedDate`.
