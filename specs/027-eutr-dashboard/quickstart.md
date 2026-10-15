# Quickstart: EUTR Dashboard

## Chạy
- API: chạy `compliance-sys-api` như thường lệ; client: `npm run dev` trong `compliance-client`.
- Đăng nhập user có quyền đọc menu Documents/Sales Orders/Purchase Orders, mở `/dashboard`.

## Kịch bản kiểm tra
1. Cuộn xuống: thấy khu vực **EUTR** (ghi "Open orders only") bên dưới phần Compliance; phần Compliance không đổi.
2. PO: tổng PO = tổng 4 nhóm Progress; đối chiếu một PO ở màn hình Purchase Orders.
3. Sales Order: tổng = số Sales Order Open order; Mapped/Missing khớp màn hình Sales Orders.
4. Documents: Expiring/Expired khớp danh sách Documents lọc Valid to; Type PO/General không bị tính Expired.
5. Đổi ngưỡng 30 → 60: các thẻ phụ thuộc ngưỡng tính lại.
6. Nhấn một thẻ/dòng top → mở đúng màn hình danh sách/View.
7. Tắt quyền một menu: khối tương ứng ẩn; tắt cả ba: toàn khu vực EUTR ẩn.
8. Giả lập một endpoint lỗi: chỉ khối đó báo lỗi + Retry, khối khác vẫn hiển thị.

Chi tiết endpoint: [contracts/eutr-dashboard-api.md](contracts/eutr-dashboard-api.md).
