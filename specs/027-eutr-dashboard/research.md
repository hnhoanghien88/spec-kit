# Research: EUTR Dashboard

## R1 — Nguồn số liệu Progress
- **Decision**: Tổng hợp từ bảng cache `eutr_progression` (Type 0 = Sales Order theo SalesId, Type 1 = Purchase Order theo PurchId; cột Total/Missing/Finished/Status).
- **Rationale**: Progress đã tính sẵn đúng công thức 005/012 (chỉ step Required) → khớp FR-052, không gọi ERP, nhanh.
- **Alternatives**: Tính lại động theo Template (chậm, trùng logic); gọi D365 từng đơn (quá chậm).

## R2 — Xác định "đơn đang mở" (FR-005)
- **Decision**: Sales Order mở = SalesId có dòng trong `compl_sync_sales_line` với `SalesStatus = 'Backorder'` (bảng do job đồng bộ 011 đổ từ D365 chỉ-Backorder). PO trong phạm vi = PurchId xuất hiện trong `eutr_purchase_attachments` của các Sales Order mở.
- **Rationale**: Toàn bộ nằm trong DB cục bộ; "Backorder" = "Open order" theo 005 Update 25.
- **Alternatives**: Hỏi D365 mỗi lần mở dashboard (chậm, phụ thuộc ERP). Hạn chế: PO chưa từng được map vào Sales Order nào sẽ không nằm trong phạm vi; ghi vào Assumptions.

## R3 — Phân loại PO (FR-011)
- **Decision**: Với PO trong phạm vi: có `TemplateCode` rỗng ở `eutr_purchase_attachments` → No template; còn lại dựa `eutr_progression` Type 1: Total = 0 → No required step; Missing = 0 và Total > 0 → Completed; ngược lại In progress. PO không có bản ghi progression (chưa tính) → gộp vào "No template" (012 hiển thị 0%/trạng thái trống cho PO chưa tính), không tính vào mẫu số FR-012.
- **Rationale**: Khớp FR-006/FR-007 của 012; không suy diễn 0%.

## R4 — ETD sắp đến hạn (FR-024)
- **Decision**: ETD (`RsVnETD`) chỉ có ở D365 nên frontend gọi endpoint tham chiếu sales-order hiện có (reference type 11) với bộ lọc ETD trong khoảng + Open order, lấy số lượng; kết quả lỗi chỉ ảnh hưởng thẻ đó.
- **Alternatives**: Đồng bộ ETD về bảng cục bộ (cần migration + đổi job 011) — ngoài phạm vi.

## R5 — Documents (FR-030..033)
- **Decision**: Truy vấn trực tiếp `eutr_documents` join `eutr_references`/`eutr_reference_types` (Type, Step). Expiring/Expired chỉ tính `ValidTo IS NOT NULL`. "Tải lên N ngày" theo `CreatedDate`.
- **Rationale**: Dữ liệu cục bộ, khớp màn hình 004.

## R6 — Phân quyền (FR-002)
- **Decision**: Mỗi endpoint dùng policy Read của module tương ứng (Documents / Sales Orders / Purchase Orders); frontend ẩn khối theo `permissionList` của menu tương ứng, ẩn cả khu vực khi không có quyền nào; không tạo policy mới.

## R7 — Giao diện
- **Decision**: Component `EutrDashboardSection` chèn cuối `dashboard/index.jsx`; mỗi khối tự gọi API, tự có loading/empty/error + nút Refresh chung; ngưỡng ngày mặc định 30 dùng state ở section; biểu đồ tròn gom phần < 3% thành "Other". Dùng recharts + MUI đã có.
- **Alternatives**: Tab (đã loại ở clarify).
