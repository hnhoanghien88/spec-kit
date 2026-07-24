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

---

## Update 1 — Assign Steps

### Tiền đề bổ sung

- Bảng `eutr_reference_type_details` đã tồn tại trên DB (theo `docs/design/eutr/eutr_db.sql` dòng
  152-164), kèm FK `eutr_reference_type_details_typeid_foreign`,
  `eutr_reference_type_details_stepid_foreign`.
- Backend đã implement xong endpoint `api/eutr-reference-type-details` (xem
  [contracts/eutr-reference-types-api.md](./contracts/eutr-reference-types-api.md)).
- Đã có ít nhất 1-2 bản ghi trong `eutr_steps` (feature `001-eutr-steps`) để combobox Step có dữ
  liệu chọn.
- KHÔNG cần seed `userMenu`/quyền mới — Assign Steps là route con tĩnh trong `MainRoutes.jsx`, tái
  sử dụng quyền `EutrReferenceTypes.*` đã seed ở T021 (xem plan.md Update 1, Quyết định 10/11 trong
  research.md).

### Kịch bản kiểm thử (ánh xạ Acceptance Scenarios của User Story 5)

8. **Mở màn hình Assign Steps (US5)**: Từ danh sách `/eutr/reference-types`, nhấn icon **Assign
   Steps** trên một dòng → điều hướng tới `/eutr/reference-types/assign-steps/{id}` → thấy
   breadcrumb "EUTR > Reference Types > {Name} > Assign Steps" và bảng step đã gán (rỗng nếu chưa
   gán step nào, hiển thị "No data").
9. **Gán step mới (US5)**: Nhấn Add → chọn 1 step từ combobox (nạp từ `GET /api/eutr-steps`) → lưu
   → step xuất hiện trong bảng, dữ liệu ghi vào `eutr_reference_type_details`. Không chọn step nào
   → bị chặn, hiện lỗi yêu cầu chọn step.
10. **Gán trùng bị chặn (US5, FR-017/SC-008)**: Với step đã gán ở bước trên, mở lại Add, chọn đúng
    step đó lần nữa → lưu → hệ thống báo lỗi "This step is already assigned to this reference
    type." và KHÔNG tạo bản ghi trùng.
11. **Sửa step đã gán (US5)**: Nhấn Edit trên 1 dòng đã gán → chọn 1 step khác chưa được gán → lưu
    → bảng hiển thị step mới, bản ghi cũ (Id) được cập nhật đè (không tạo dòng mới).
12. **Xóa step đã gán (US5)**: Nhấn Delete trên 1 dòng → `ConfirmDialog` nêu tên step → xác nhận →
    dòng biến mất, bản ghi bị xóa thật khỏi `eutr_reference_type_details`. Hủy ở hộp xác nhận →
    không có gì thay đổi.
13. **Không có Import/Export (US5, FR-019)**: Xác nhận toolbar của màn hình Assign Steps KHÔNG có
    nút Import/Export.
14. **Quyền (US5)**: User thiếu quyền Update trên `EutrReferenceTypes` → icon Assign Steps trên
    danh sách ẩn/disable giống Edit; user thiếu quyền Delete → icon Delete trên bảng step đã gán
    ẩn/disable.

### Tiêu chí đạt (bổ sung)

- Toàn bộ 7 kịch bản mới (8-14) hoạt động đúng.
- Gọi đúng các endpoint mới trong
  [contracts/eutr-reference-types-api.md](./contracts/eutr-reference-types-api.md) (mục "Assign
  Steps — EutrReferenceTypeDetails").
- Gán trùng step trả về lỗi validate rõ ràng (không phải lỗi 500 chung chung) — FR-017/SC-008.
- Xóa step đã gán là xóa thật (kiểm tra trực tiếp trong DB nếu cần), không còn xuất hiện lại sau
  khi tải lại trang.
- Toàn bộ văn bản hiển thị trên màn hình Assign Steps (breadcrumb, nút, dialog, thông báo, trạng
  thái rỗng, hộp thoại xác nhận) bằng **tiếng Anh** (FR-020).
