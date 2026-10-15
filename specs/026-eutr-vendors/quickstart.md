# Quickstart: EUTR Vendors

## Chuẩn bị
1. Chạy migration `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/42_create_eutr_vendors.sql`.
2. Đảm bảo menu `eutr-vendors` (url `/eutr/vendors`) và quyền `EutrVendors.*` đã có trong dữ liệu và được gán cho role của bạn.
3. Backend: `dotnet build` trong `compliance-sys-api`; chạy API. Frontend: `npm run dev` trong `compliance-client`.

## Kiểm tra
1. Mở **EUTR > Vendors**: bảng hiển thị (rỗng nếu chưa có dữ liệu).
2. Add `V001` / `Vendor A` → xuất hiện trong danh sách, Created by/date đúng.
3. Add lại `v001` → báo trùng Code, không lưu.
4. Add với Code hoặc Name trống → báo bắt buộc.
5. Edit đổi Name → lưu; Created by/date không đổi. Edit Code thành Code vendor khác → báo trùng.
6. Search theo Code/Name → danh sách thu hẹp.
7. Delete một dòng và Delete nhiều dòng → biến mất khỏi danh sách.

Tests backend: `dotnet test compliance-sys-api` (lọc `EutrVendorsServiceTests`). Contract: [contracts/eutr-vendors-api.md](contracts/eutr-vendors-api.md).
