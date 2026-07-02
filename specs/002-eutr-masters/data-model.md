# Data Model: EUTR Masters

## Thực thể: EutrMastersDocument (bảng `eutr_master_documents`)

Nguồn sự thật DB: `docs/design/eutr/eutr_db.sql`. Entity backend mới:
`compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrMastersDocument.cs` (kế thừa `BaseEntity`).

| Trường | Kiểu | Nguồn | Ghi chú |
|--------|------|-------|---------|
| `Id` | long (BIGINT UNSIGNED) | DB | Khóa chính, auto-increment, chỉ đọc |
| `StepId` | long? | Người dùng chọn | **Bắt buộc**; FK → `eutr_steps(Id)` |
| `Prefix` | string? | Người dùng nhập | **Bắt buộc, không rỗng** |
| `CreatedBy` | string | Hệ thống | Ghi tự động từ user đăng nhập |
| `CreatedDate` | datetime | Hệ thống | Ghi tự động |
| `UpdatedBy` | string | Hệ thống | Ghi tự động khi sửa |
| `UpdatedDate` | datetime | Hệ thống | Ghi tự động khi sửa |

## Trường dẫn xuất (không lưu, chỉ đọc/hiển thị)

| Trường | Kiểu | Nguồn | Ghi chú |
|--------|------|-------|---------|
| `StepName` | string | JOIN `eutr_steps.Name` | Hiển thị ở grid; do backend trả trong `EutrMastersResponseDto` |

## Quy tắc nghiệp vụ (validation)

- `StepId` bắt buộc (> 0) → chặn submit ở modal (select box) + FluentValidation ở backend.
- `Prefix` bắt buộc, không rỗng/chỉ khoảng trắng → chặn ở modal + validator backend.
- **Duy nhất (StepId, Prefix)**: không được tồn tại 2 bản ghi cùng cặp. Kiểm tra ở service khi
  Add/Update/Import; trùng → **chặn lưu** kèm thông báo tiếng Anh (FR-007/FR-013). Khi Update, loại
  trừ chính bản ghi đang sửa khỏi phép kiểm tra.
- `Id` không sửa được; khi Update gửi qua URL `PUT /eutr-masters/{id}`.

## Đối tượng truyền (frontend ↔ backend)

- **Tạo/Sửa (request)** — `EutrMastersRequestDto`: `{ stepId, prefix }` (Update kèm `id` ở URL).
- **Phản hồi danh sách (get-all)**: `PagedResult<EutrMastersResponseDto>` →
  `{ items: [{ id, stepId, stepName, prefix, createdBy, createdDate, updatedBy, updatedDate }], totalCount }`.
- **Xóa nhiều**: mảng `ids` (number[]) → `POST /eutr-masters/delete-multi`.
- **Import (request)**: `multipart/form-data`, field `file` (.xlsx) → `POST /eutr-masters/import`.
- **Import (response)** — `ImportEutrMastersResultDto`:
  `{ totalRows, successCount, failCount, duplicateCount, errors: [{ rowNumber, stepName, prefix, reason }], duplicates: [{ rowNumber, stepName, prefix, reason }] }`.

## Định dạng file Excel import

| Cột | Nội dung | Ghi chú |
|-----|----------|---------|
| A | Step name | Khớp `eutr_steps.Name` (không phân biệt hoa/thường, trim) |
| B | Prefix | Bắt buộc |

- **Dòng 1 = tiêu đề** (Step name, Prefix) → bỏ qua; dữ liệu bắt đầu từ **dòng 2**.
- Dòng lỗi (không tìm thấy step / thiếu prefix / trùng cặp) → bỏ qua và báo cáo; dòng hợp lệ vẫn
  import (import một phần).

## Định dạng file Excel export

- Giống hệt định dạng import: dòng 1 tiêu đề (A=Step name, B=Prefix), dữ liệu từ dòng 2 (A=tên
  bước, B=prefix). Không có master → chỉ dòng tiêu đề. Export toàn bộ danh sách (không phân trang),
  không kèm cột audit. Không phát sinh entity/bảng mới.

## Quan hệ

- `EutrMastersDocument.StepId` → `EutrStep.Id` (nhiều master có thể trỏ tới cùng một step, nhưng cặp
  (StepId, Prefix) là duy nhất).
- Select box "Step name" nạp từ danh mục `eutr_steps` (GET `/eutr-steps`). Feature này **chỉ đọc**
  `eutr_steps`, không tạo/sửa/xóa bước.
