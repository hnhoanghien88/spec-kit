# Data Model: EUTR Dashboard

Không thêm bảng/cột. Chỉ đọc các bảng sau; mọi đối tượng dưới đây là DTO tổng hợp (không lưu).

## Nguồn (đọc)
| Bảng | Dùng cho |
|---|---|
| `eutr_progression` (Type, SalesId, PurchId, Total, Missing, Finished, Status) | Progress SO/PO |
| `compl_sync_sales_line` (SalesId, SalesStatus) | Xác định Sales Order đang mở (`Backorder`) |
| `eutr_purchase_attachments` (SalesId, PurchId, TemplateCode) | Liên kết SO↔PO, Template của PO |
| `eutr_purchase_relationship`, `eutr_trader_relationship` | Cảnh báo Trader relationship (FR-014) |
| `eutr_documents` (ValidFrom, ValidTo, CreatedDate), `eutr_references`, `eutr_reference_types` | Thống kê tài liệu |

## DTO
- **EutrPoSummaryDto**: total, completed, inProgress, noTemplate, noRequiredStep, completedPercent, withTraderRelationship, needTraderRelationship, lowestProgress[] (purchId, vendor, finished, total, percent).
- **EutrSoSummaryDto**: totalOpen, completed, inProgress, noTemplate, mappedSteps, missingSteps, mappedPercent, lowestProgress[] (salesId, finished, total, percent).
- **EutrDocumentSummaryDto**: total, uploadedLast7Days, uploadedLast30Days, byType[] (type, count), expiringSoon, expired, expiringList[] (fileName, type, step, validTo).
- Mọi DTO kèm `asOf` (thời điểm tính).

## Quy tắc
- Percent = Finished/Total (chỉ step Required); mẫu số FR-012 loại noTemplate/noRequiredStep.
- Tổng các nhóm Progress = total (FR-011).
- Customer, Vendor name, ETD của danh sách top lấy ở frontend qua API tham chiếu hiện có (hoặc bỏ cột nếu không sẵn).
