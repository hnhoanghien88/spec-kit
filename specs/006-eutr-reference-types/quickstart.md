# Quickstart / Validation: EUTR Reference Types

Hướng dẫn chạy và kiểm thử thủ công feature EUTR Reference Types end-to-end. Khác với
`001-eutr-steps`, backend PHẢI được build/chạy sau khi implement (không có sẵn từ trước).

## Tiền đề

- Bảng `eutr_reference_types` đã tồn tại trên DB (theo `docs/design/eutr/eutr_db.sql`), kèm FK
  `eutr_references_reftype_foreign`.
- Backend `compliance-sys-api` đã implement xong endpoint `api/eutr-reference-types` (Phase 2/3).
- Menu + quyền đã được seed trên DB Authorization theo
  `docs/design/eutr/seed_eutr_reference_types_menu.sql`: `code = "eutr-reference-types"`,
  `url = "/eutr/reference-types"`, quyền `EutrReferenceTypes.ReadAll/Create/Update/Delete` cấp cho
  role kiểm thử (xem ADR `docs/adr/0002-backend-driven-routing.md` — thiếu bước này màn hình sẽ ra
  NotFound dù code frontend đã đúng).

## Chạy

```bash
# Backend
cd compliance-sys-api
dotnet run --project src/ComplianceSys.Api

# Frontend
cd compliance-client
npm install   # nếu chưa cài
npm run dev
```

Mở SPA, đăng nhập bằng user đã được cấp quyền + menu ở trên, vào menu **EUTR reference types**
(đường dẫn `/eutr/reference-types`). Nếu `userMenu` đã cache cũ, xóa cache trước:
`localStorage.removeItem('userMenu')` rồi reload.

## Kịch bản kiểm thử (ánh xạ Acceptance Scenarios trong spec)

1. **Xem danh sách (US1)**: Mở `/eutr/reference-types` → thấy bảng với cột Name, Created by,
   Created date, Action; dữ liệu tải từ `POST /eutr-reference-types/get-all`.
2. **Tìm kiếm (US1)**: Lọc cột Name → bảng chỉ còn dòng khớp; phân trang đổi trang đúng.
3. **Thêm (US2)**: Nhấn Add → nhập tên hợp lệ → Lưu → dòng mới xuất hiện, Created by/date có giá
   trị. Để trống tên → bị chặn, hiện lỗi.
4. **Sửa (US3)**: Chọn 1 dòng → Edit → đổi tên → Lưu → tên cập nhật trong bảng. Xóa trống tên → bị
   chặn.
5. **Xóa — trường hợp bình thường (US4)**: Tạo 1 reference type mới KHÔNG được `eutr_references`
   nào tham chiếu → Delete → xác nhận → dòng biến mất. Chọn nhiều dòng (không đang dùng) → xóa
   nhiều → tất cả biến mất. Hủy ở hộp xác nhận → không xóa.
6. **Xóa — trường hợp bị chặn (US4, FR-009)**: Chuẩn bị 1 reference type có ít nhất 1 bản ghi
   `eutr_references.RefType` trỏ tới (insert thủ công qua DB hoặc qua tính năng liên quan nếu có) →
   Delete → xác nhận → hệ thống hiển thị lỗi rõ ràng ("... currently in use ...") và dòng KHÔNG
   biến mất khỏi bảng. Thử xóa nhiều gồm cả id này → toàn bộ batch báo lỗi, không dòng nào bị xóa
   (xem `data-model.md` phần giả định `DeleteMultiAsync`).
7. **Quyền**: Đăng nhập user thiếu quyền Create/Update/Delete → nút tương ứng ẩn/disable.

## Tiêu chí đạt

- Tất cả 7 kịch bản trên hoạt động đúng.
- Không có lỗi console; gọi đúng các endpoint trong
  [contracts/eutr-reference-types-api.md](./contracts/eutr-reference-types-api.md).
- Xóa bản ghi đang được tham chiếu trả về `409` với thông báo rõ ràng, không phải lỗi 500 chung
  chung (FR-009, SC-006).
- Toàn bộ văn bản hiển thị (label cột, nút, breadcrumb, thông báo, trạng thái rỗng, hộp thoại xác
  nhận) đều bằng **tiếng Anh** (FR-012).
