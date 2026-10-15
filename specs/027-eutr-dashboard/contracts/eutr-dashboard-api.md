# Contract: EUTR Dashboard API

Base: `api/eutr-dashboard`. Tất cả `GET`, `[Authorize]`, bọc `ApiResponse<T>` như dashboard hiện có. Lỗi → 500 `ApiResponse<string>.Fail`.

| Endpoint | Policy | Response data |
|---|---|---|
| `GET /po-summary` | `EutrPurchaseOrders.Read` | `EutrPoSummaryDto` |
| `GET /so-summary` | `EutrSalesOrders.Read` | `EutrSoSummaryDto` |
| `GET /document-summary?dueDays=30` | `EutrDocuments.Read` | `EutrDocumentSummaryDto` |

- `dueDays`: int, mặc định 30, 0–365.
- Phạm vi PO/SO: chỉ đơn đang mở (spec FR-005).
- Policy thực tế được xác nhận theo tên policy đang dùng ở các controller 004/005/012 khi implement.

Frontend (`dashboardApi`): `getEutrPoSummary()`, `getEutrSoSummary()`, `getEutrDocumentSummary(dueDays)`.
