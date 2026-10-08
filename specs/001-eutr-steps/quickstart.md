# Quickstart / Validation: EUTR Steps

Hướng dẫn chạy và kiểm thử thủ công feature EUTR Steps end-to-end.

## Tiền đề

- Backend `compliance-sys-api` chạy được, đã có endpoint `api/eutr-steps` và bảng `eutr_steps`.
- Người dùng đăng nhập có các quyền `EutrSteps.ReadAll / Create / Update / Delete`, và menu chứa
  mục code `eutr-steps`.

## Chạy

```bash
# Backend (đã có, chỉ cần chạy)
cd compliance-sys-api
dotnet run --project src/ComplianceSys.Api

# Frontend
cd compliance-client
npm install   # nếu chưa cài
npm run dev
```

Mở SPA, đăng nhập, vào menu **EUTR steps** (đường dẫn `/eutr-steps`).

## Kịch bản kiểm thử (ánh xạ Acceptance Scenarios trong spec)

1. **Xem danh sách (US1)**: Mở `/eutr-steps` → thấy bảng với cột Step name, Created by,
   Created date, Action (không có cột Prefix); dữ liệu tải từ `POST /eutr-steps/get-all`.
2. **Tìm kiếm (US1)**: Lọc cột Name → bảng chỉ còn dòng khớp; phân trang đổi trang đúng.
3. **Thêm (US2)**: Nhấn Add → nhập tên hợp lệ → Lưu → dòng mới xuất hiện, Created by/date có giá
   trị. Để trống tên → bị chặn, hiện lỗi.
4. **Sửa (US3)**: Chọn 1 dòng → Edit → đổi tên → Lưu → tên cập nhật trong bảng.
5. **Xóa (US4)**: Delete trên 1 dòng → xác nhận → dòng biến mất. Chọn nhiều dòng → xóa nhiều →
   tất cả biến mất. Hủy ở hộp xác nhận → không xóa.
6. **Quyền**: Đăng nhập user thiếu quyền Create/Update/Delete → nút tương ứng ẩn/disable.
7. **Chống trùng tên khi thêm (FR-005a)**: Đã có bước tên "Sourcing" → nhấn Add, nhập "Sourcing"
   (hoặc "sourcing", " Sourcing ") → Lưu → bị chặn, snackbar báo lỗi "A step with this name
   already exists.", không có dòng mới được tạo.
8. **Chống trùng tên khi sửa (FR-005a)**: Có 2 bước "Sourcing" và "Processing" → Edit bước
   "Processing" đổi tên thành "Sourcing" → Lưu → bị chặn, snackbar báo lỗi trùng, tên không đổi.
   Edit lại bước "Sourcing" nhưng giữ nguyên tên "Sourcing" và Lưu → phải thành công (không tự báo
   trùng với chính nó).

## Tiêu chí đạt

- Tất cả 8 kịch bản trên hoạt động đúng.
- Không có lỗi console; gọi đúng các endpoint trong [contracts/eutr-steps-api.md](./contracts/eutr-steps-api.md).
- Toàn bộ văn bản hiển thị (label cột, nút, breadcrumb, thông báo, trạng thái rỗng, hộp thoại xác
  nhận) đều bằng **tiếng Anh** (FR-011).

## Update 2 (2026-10-08) — Xóa Step kèm dữ liệu liên quan

Chạy trên DB thử nghiệm (thao tác phá hủy dữ liệu).
1. Step KHÔNG nằm trong Template: Delete → hộp xác nhận chung → xóa thành công (SC-007).
2. Step nằm trong Template A, B: Delete → hộp nêu "used in template(s): A, B" → Hủy → không đổi gì.
3. Như 2, bấm Delete xác nhận → Step biến mất; kiểm tra DB: không còn dòng `StepId` đó ở `eutr_template_details`, `eutr_master_documents`, `eutr_reference_type_details`, `eutr_references`/`eutr_reference_details` liên quan; Template A, B vẫn còn các step khác, cây không lỗi.
4. Chọn nhiều Step (một số nằm trong Template) → hộp liệt kê theo từng Step → xác nhận → tất cả xóa.
5. Lỗi giữa chừng (mô phỏng) → không xóa gì (transaction).
