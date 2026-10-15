# API Contract: EUTR Vendors

Base route: `api/eutr-vendors` (JWT bắt buộc). Response bọc `ApiResponse<T>`.

| Method | Path | Policy | Body | Kết quả |
|---|---|---|---|---|
| GET | `/get-by-id/{id}` | EutrVendors.ReadOne | — | vendor |
| GET | `/` | EutrVendors.ReadAll | — | danh sách vendor |
| POST | `/get-all?page&pageSize&sortColumn&sortOrder` | EutrVendors.ReadAll | `FilterRequest[]` (Code/Name like, ...) | `PagedResult<Vendor>` |
| POST | `/` | EutrVendors.Create | `{ code, name }` | id (long) |
| PUT | `/{id}` | EutrVendors.Update | `{ code, name }` | — |
| DELETE | `/{id}` | EutrVendors.Delete | — | — |
| POST | `/delete-multi` | EutrVendors.Delete | `long[]` | — |

Vendor: `{ id, code, name, createdBy, createdDate }`.

Lỗi: 400 khi thiếu/quá dài Code hoặc Name (validator); lỗi nghiệp vụ "A vendor with the same code already exists." khi trùng Code (InvalidOperationException → cùng cơ chế middleware hiện có như Masters); 404 khi id không tồn tại.
