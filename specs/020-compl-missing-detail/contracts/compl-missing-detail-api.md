# Contract: `api/compl-missing-detail`

Tất cả endpoint `[Authorize]`; trả `ApiResponse<T>` như `ComplSoMissingController`. Lỗi: 400 (validation), 499 (client hủy), 500.

| Method | Path | Policy | Mô tả |
|--------|------|--------|-------|
| GET | `/test-compliance-missing` | `ComplianceMissingDetail.Update` | Làm mới snapshot (không gửi mail) |
| POST | `/search` | `ComplianceMissingDetail.ReadAll` | Danh sách phân trang |
| POST | `/export` | `ComplianceMissingDetail.Download` | Excel toàn bộ kết quả |
| POST | `/note` | `ComplianceMissingDetail.Update` | Lưu/xóa ghi chú một dòng |
| POST | `/note/import` | `ComplianceMissingDetail.Update` | Import Follow up date/Note từ Excel đã export |

## GET /test-compliance-missing

Chạy đồng bộ: (1) bản copy refresh làm mới `compl_so_missing` từ open sales order, (2) đọc lại và group theo (MasterCode, Code, MappedRefTypeCode, MappedInputValue), (3) thay toàn bộ `compl_missing_detail` trong một transaction. Không gửi email/notification.

Thành công → `ApiResponse<MissingDetailRefreshResultDto>`:

```json
{ "success": true, "data": { "salesOrdersEvaluated": 1240, "salesOrdersFailed": 2, "soMissingRows": 5310, "detailRows": 842, "startedAt": "…", "finishedAt": "…" } }
```

- Đang có một lần chạy khác → 409 `"A refresh is already running"` (không chạy chồng).
- Lỗi toàn cục → 500, snapshot cũ giữ nguyên.
- Khuyến cáo: không chạy cùng lúc với `test-sales-order-alert*` hoặc job alert (cùng ghi `compl_so_missing`).

## POST /search, /export — body `MissingDetailSearchRequestDto`

```json
{
  "filters": [ { "column": "Status", "operator": "equals", "value": "Expired" } ],
  "page": 1, "pageSize": 50,
  "sortColumn": "MasterCode", "sortOrder": "asc"
}
```

Không có `salesId`, không có filter ETD/Year/Week; không bắt buộc filter. Cột lọc/sort hợp lệ: `MasterCode, MasterName, Status, Code, Name, MappedRefTypeCode, MappedInputValue, ValidFrom, ValidTo`; cột khác → 400.

`/search` → `ApiResponse<PagedResult<MissingDetailRowDto>>` (`items`, `totalCount`); `Status`/`DaysRemaining` tính lúc đọc (FR-013); chưa chạy trigger lần nào → `items: []`.

`/export` → `compliance-missing-detail-{yyyyMMddHHmmss}.xlsx`: cột = cột grid + Follow up date + Note; không có 5 cột SO; dòng Expired tô vàng.

## POST /note

```json
{ "masterCode": "MAS-01021", "code": "C-1", "mappedRefTypeCode": "PRODUCT",
  "mappedInputValue": "P-001", "followUpDate": "2026-10-20", "note": "Chờ NCC" }
```

`followUpDate` và `note` cùng rỗng = xóa ghi chú của dòng.

## POST /note/import

`multipart/form-data` (file `.xlsx`); trả số dòng cập nhật và danh sách lỗi theo dòng (cùng hình dạng import màn cũ), khóa dòng là 4 cột Master code, Code, Type, Product.

## Menu (res_auth_db)

`userMenu` trả mục `code = compliance-missing-detail`, `url = /compliance-missing`, `permissionList` chứa `ComplianceMissingDetail.*`.
