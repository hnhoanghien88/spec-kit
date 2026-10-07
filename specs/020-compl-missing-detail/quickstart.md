# Quickstart: Compliance Missing Detail

## Prerequisites

- Chạy migration `35` (bảng snapshot) → `36` (bảng note). Menu/quyền `ComplianceMissingDetail` đã được app khác cập nhật (không có migration 34/37 trong repo).
- User có role được cấp `ComplianceMissingDetail.*` (ví dụ Compl Admin) và token đăng nhập.
- Backend: `dotnet run --project compliance-sys-api/src/ComplianceSys.Api`; Frontend: `npm run dev` trong `compliance-client`.
- Tránh giờ chạy alert/job đang ghi `compl_so_missing` (xem contract).

## Scenarios

1. **Menu và link** — Menu "Compliance missing detail" mở `/compliance-missing`; "Compliance missing" cũ mở `/compliance-missing-open-orders`; màn cũ không đổi (FR-001, FR-012, SC-005).
2. **Màn hình khi chưa có dữ liệu** — Bảng `compl_missing_detail` rỗng → trang hiện trạng thái "no data", không lỗi (US2-3).
3. **Chạy trigger** — `GET /api/compl-missing-detail/test-compliance-missing` với token: nhận `ApiResponse` có số liệu; kiểm tra không có email/notification mới được gửi (SC-006, US1-1).
4. **Group, không SalesId** — `SELECT COUNT(*), COUNT(DISTINCT MasterCode, Code, MappedRefTypeCode, MappedInputValue) FROM compl_missing_detail` hai giá trị bằng nhau, và bảng không có cột `SalesId`; bằng số nhóm phân biệt (chuẩn hóa null/'') trong `compl_so_missing` (SC-001, US1-2).
5. **Thay thế hoàn toàn** — Chạy trigger lần hai: không còn dòng cũ nào mà `compl_so_missing` không còn chứa; chạy khi không có gì thiếu → bảng rỗng (US1-3, US1-4).
6. **Lỗi giữa chừng** — Mô phỏng lỗi D365/DB ở giai đoạn đánh giá → trigger 500, `compl_missing_detail` giữ nguyên (US1-5, FR-008).
7. **Chạy chồng** — Gọi trigger khi một lần khác đang chạy → 409.
8. **Cột và filter** — Grid không có Sales order/ETD/Invoice date/Customer code/Customer name; không có filter Year/Week (FR-003, FR-002).
9. **Status lúc đọc** — Code rỗng → Missing; Code có và ValidTo < hôm nay → Expired, `-n days left`; ValidTo = hôm nay → không hiện (FR-013).
10. **Lọc** — Status = Expired chỉ còn dòng Expired; clear → đầy đủ (US3).
11. **Ghi chú bền** — Nhập Follow up date + Note → chạy lại trigger → còn nguyên với tổ hợp còn trong danh sách; nhập cùng khóa ở màn cũ không ảnh hưởng và ngược lại (US4, SC-007).
12. **Export** — File `compliance-missing-detail-*.xlsx` khớp grid + 2 cột ghi chú, không có cột SO, dòng Expired tô vàng (SC-004).
13. **Alert cũ nguyên vẹn** — `test-sales-order-alert` và `test-alert` vẫn chạy như trước (US1-6, SC-006).
14. **Quyền** — User thiếu `ComplianceMissingDetail.ReadAll`/`Update` không thấy menu, gọi `/search` hoặc trigger → 403.
15. **Hiệu năng** — Trang đầu hiện < 5 giây (SC-002).

Chi tiết endpoint: [contracts/compl-missing-detail-api.md](contracts/compl-missing-detail-api.md). Dữ liệu: [data-model.md](data-model.md).
