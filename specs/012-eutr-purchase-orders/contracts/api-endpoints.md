
## Update 54
Không thêm/đổi endpoint; bảng `eutr_purchase_relationship` chỉ được ghi nội bộ bởi hàm tính Progress.

## Update 55 — Trader relationship

### GET `/api/eutr-purchase-orders/{purchId}/trader-relationship`
Response 200:
```json
{ "vendors": [ { "code": "AP", "name": "Atlantic" } ],
  "edges":   [ { "from": "AP", "to": "PD" } ] }
```
`vendors` = `eutr_purchase_relationship` của PO (kèm Name từ `eutr_vendors`); `edges` = `eutr_trader_relationship` của PO.

### PUT `/api/eutr-purchase-orders/{purchId}/trader-relationship`
Body: `{ "edges": [ { "from": "AP", "to": "PD" } ] }` — thay thế toàn bộ mũi tên của PO (rỗng = xóa hết).
- 200: lưu thành công (trả lại `edges` đã lưu).
- 400: `PurchId` rỗng, Vendor ngoài PO, tự nối, trùng cặp hoặc tạo vòng — không ghi gì.
- `CreatedBy` lấy từ `HttpContext.Items["UserEmail"]` (mặc định "system").

## Update 56 — Cột Trader relationship

### POST `/api/eutr-purchase-orders/trader-relationships`
Policy `EutrPurchaseOrders.Read`. Body: `["PO00000720", "PO00000721"]`. Response 200 (chỉ PO có dữ liệu):
```json
[ { "purchId": "PO00000720",
    "lines": [ "Devereaux sawmill > Phương Đông", "Atlantic Paciffic > Phương Đông", "Phương Đông > Response" ] } ]
```
Body rỗng/PurchId trắng → `[]`.

## Update 58

- `GET /api/eutr-purchase-orders/{purchId}/trader-relationship`: policy đổi `.Update` → `.Read` (response không đổi).
- Chi tiết Template (`EutrTemplateDetailsResponseDto`) thêm `isGroup` (bool).
