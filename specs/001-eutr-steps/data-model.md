# Data Model: EUTR Steps

## Thực thể: EutrStep (bảng `eutr_steps`)

Nguồn sự thật: `compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrStep.cs` (kế thừa
`BaseEntity`). Frontend phản chiếu các trường này.

| Trường | Kiểu | Nguồn | Ghi chú |
|--------|------|-------|---------|
| `id` | long | DB | Khóa chính, chỉ đọc |
| `name` | string | Người dùng nhập | **Bắt buộc, không rỗng** (FluentValidation `NotEmpty`) |
| `createdBy` | string | Hệ thống | Ghi tự động từ user đăng nhập |
| `createdDate` | datetime | Hệ thống | Ghi tự động |
| `updatedBy` | string | Hệ thống | Ghi tự động khi sửa |
| `updatedDate` | datetime | Hệ thống | Ghi tự động khi sửa |

## Quy tắc nghiệp vụ (validation)

- `name` bắt buộc, không được rỗng/chỉ khoảng trắng → chặn ở modal trước khi submit (khớp validator
  backend). Thông báo lỗi hiển thị bằng **tiếng Anh** (FR-011).
- **`name` MUST là duy nhất trong toàn bộ `eutr_steps`** (FR-005a): so khớp không phân biệt
  hoa/thường và đã trim khoảng trắng đầu/cuối (`LOWER(TRIM(Name))`); khi Update, bản ghi đang sửa
  bị loại khỏi so khớp (`AND Id <> @excludeId`). Vi phạm → backend trả HTTP 409 với message "A
  step with this name already exists."; frontend hiển thị message này qua snackbar, không tạo bản
  ghi/không lưu thay đổi.
- `id` không sửa được; khi Edit, gửi kèm `id` trong payload `update`.

## Đối tượng truyền (frontend ↔ backend)

- **Tạo/Sửa (request)**: `{ name }` (kèm `id` khi sửa, đặt ở URL `PUT /eutr-steps/{id}`).
- **Phản hồi danh sách (get-all)**: `PagedResult<EutrStepResponseDto>` → `{ items: [...], totalCount }`
  (frontend đọc theo `response.data.items` / `response.data.totalCount`, có fallback như mẫu).
- **Xóa nhiều**: mảng `ids` (number[]) gửi tới `POST /eutr-steps/delete-multi`.

## Quan hệ

- Không có quan hệ ràng buộc với thực thể khác trong phạm vi feature này.
