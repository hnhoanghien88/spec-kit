# Contract: get-by-attribute-combine (Update 1)

`POST /api/view-compliances/get-by-attribute-combine?attributeValueRecId={long}&deliveryDate={date?}` — `[Authorize(Policy="AllCompliance.ReadAll")]`, không body.

Response 200: `ApiResponse<IEnumerable<ViewCompliancesResponseDto>>` — cùng DTO với `get-for-so-detail`. RecId không có trong combine hoặc không khớp → `data: []`.
Lỗi: 500 `ApiResponse<string>.Fail(...)`. RecId không hợp lệ (≤0) → 400.

## Update 2 — thay bằng get-attribute-combine-groups

`POST /api/view-compliances/get-attribute-combine-groups?attributeValueRecId={long}` — `[Authorize(Policy="AllCompliance.ReadAll")]`.
Response: `ApiResponse<IEnumerable<AttributeCombineGroupDto>>`: `{ kind: "group"|"combine", title, itemId?, typeText?, nameText?, optionText?, groupValue?, payload: ViewCompliancesRequest[] }`. Nhóm `group` đứng trước; chi tiết compliance lấy bằng `POST get-for-so-detail` với `payload`. Endpoint `get-by-attribute-combine` (Update 1) bị gỡ.
