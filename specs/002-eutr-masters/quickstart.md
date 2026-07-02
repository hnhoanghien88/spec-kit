# Quickstart / Validation: EUTR Masters

Hướng dẫn chạy và kiểm thử thủ công feature EUTR Masters end-to-end.

## Tiền đề

- Bảng `eutr_master_documents` tồn tại trong DB (theo `docs/design/eutr/eutr_db.sql`), FK
  `StepId → eutr_steps(Id)`; danh mục `eutr_steps` đã có vài bước để chọn.
- Backend đã build được với controller mới `api/eutr-masters` (CRUD + import + export).
- **Menu + quyền được tạo động & phân quyền trong DB** (không seed bằng code): tạo menu code
  `eutr-masters` (url `/eutr/masters`) và các quyền `EutrMasters.ReadAll / ReadOne / Create /
  Update / Delete / Download`, rồi gán cho role/user đăng nhập (routing backend-driven — nếu thiếu
  menu/quyền trong DB, màn hình sẽ không truy cập được). Quyền **Download** dùng cho Export.

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

Mở SPA, đăng nhập, vào menu **EUTR masters** (đường dẫn `/eutr/masters`).

## Kịch bản kiểm thử (ánh xạ Acceptance Scenarios trong spec)

1. **Xem danh sách (US1)**: Mở `/eutr/masters` → thấy breadcrumb "EUTR > Masters" và bảng với cột
   Step name, Prefix, Created by, Created date, Action. Cột **Step name hiển thị TÊN bước** (không
   phải mã). Dữ liệu tải từ `POST /eutr-masters/get-all`.
2. **Tìm kiếm (US1)**: Nhập tên bước vào Search → bảng chỉ còn dòng có tên bước khớp; đổi trang đúng.
3. **Thêm (US2)**: Nhấn Add → mở modal → **Select "Step name"** liệt kê các bước (nạp từ
   `GET /eutr-steps`) → chọn 1 bước → nhập Prefix → Save → dòng mới xuất hiện với đúng tên bước +
   prefix, Created by/date có giá trị. Bỏ trống step hoặc prefix → bị chặn, hiện lỗi.
4. **Chống trùng (US2/US3)**: Tạo (hoặc sửa thành) một bản ghi trùng cả **step + prefix** với bản
   ghi đã có → hệ thống **cảnh báo trùng và không lưu**.
5. **Sửa (US3)**: Chọn 1 dòng → Edit → đổi step hoặc prefix → Save → giá trị cập nhật trong bảng.
6. **Xóa (US4)**: Delete trên 1 dòng → xác nhận → dòng biến mất. Chọn nhiều dòng → xóa nhiều → tất
   cả biến mất. Hủy ở hộp xác nhận → không xóa.
7. **Import (US5)**: Chuẩn bị file `.xlsx` 2 cột (A=Step name, B=Prefix), **dòng 1 là tiêu đề**, dữ
   liệu từ dòng 2. Nhấn **Import** → chọn file → hệ thống tạo các dòng hợp lệ và mở
   **ImportResultDialog** báo cáo successCount/failCount/duplicateCount + danh sách dòng bỏ qua kèm
   lý do. Kiểm: dòng step name không khớp → "Step not found"; dòng trùng step+prefix (với DB hoặc
   trong file) → "Duplicate"; file sai định dạng → báo lỗi định dạng, không import.
8. **Export (US6)**: Nhấn **Export** → tải về file `.xlsx`; mở file, xác nhận **dòng 1 là tiêu đề
   "Step name", "Prefix"** và mỗi master một dòng dữ liệu đúng tên bước + prefix. Khi danh sách
   rỗng → file chỉ có dòng tiêu đề. Dùng chính file này để Import lại → định dạng khớp, xử lý được.
9. **Quyền**: Đăng nhập user thiếu quyền Create/Update/Delete → nút tương ứng ẩn/disable.

## Tiêu chí đạt

- Tất cả 9 kịch bản trên hoạt động đúng.
- Không có lỗi console; gọi đúng các endpoint trong
  [contracts/eutr-masters-api.md](./contracts/eutr-masters-api.md).
- Ràng buộc **(StepId, Prefix) duy nhất** được thực thi ở Add/Update/Import (chặn lưu).
- Import là **import một phần** (giữ dòng hợp lệ, bỏ + báo cáo dòng lỗi).
- Toàn bộ văn bản hiển thị (label cột, nút Import/Add/Edit/Delete/Save/Cancel, breadcrumb, thông
  báo, cảnh báo trùng, báo cáo import, trạng thái rỗng, hộp thoại xác nhận) đều bằng **tiếng Anh**
  (FR-017).
