# Contract: test-compl-sync-attributes

`GET /api/compl-synchronize-data/test-compl-sync-attributes` — `[Authorize]`, không tham số.

Response 200: `ApiResponse<ComplSyncAttributesSummaryDto>`

```json
{ "data": { "fetched": 10, "added": 9, "skipped": 1, "success": true, "message": "..." } }
```

Lỗi D365/ghi DB: `success=false`, `message` mô tả bước dừng; dữ liệu cũ giữ nguyên nếu lỗi xảy ra trước bước ghi.
