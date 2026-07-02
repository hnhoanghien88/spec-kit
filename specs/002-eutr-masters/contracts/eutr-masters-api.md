# API Contract: EUTR Masters (MỚI — cần tạo)

Đích: `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrMastersController.cs` (clone mẫu
`EutrStepsController`). Base route: `api/eutr-masters`. Tất cả endpoint yêu cầu `[Authorize]` + policy
tương ứng. Bao bọc phản hồi: `ApiResponse<T>` (`{ data, message, success }`).

| # | Method | Path | Policy | Body / Params | Trả về |
|---|--------|------|--------|---------------|--------|
| 1 | GET | `/api/eutr-masters/get-by-id/{id}` | `EutrMasters.ReadOne` | — | `EutrMastersResponseDto` |
| 2 | POST | `/api/eutr-masters/get-all` | `EutrMasters.ReadAll` | query: `page,pageSize,sortColumn,sortOrder`; body: `List<FilterRequest>` | `PagedResult<EutrMastersResponseDto>` |
| 3 | POST | `/api/eutr-masters` | `EutrMasters.Create` | `EutrMastersRequestDto { stepId, prefix }` | `long` (id mới) |
| 4 | PUT | `/api/eutr-masters/{id}` | `EutrMasters.Update` | `EutrMastersRequestDto { stepId, prefix }` | message |
| 5 | DELETE | `/api/eutr-masters/{id}` | `EutrMasters.Delete` | — | message |
| 6 | POST | `/api/eutr-masters/delete-multi` | `EutrMasters.Delete` | `IEnumerable<long> ids` | message |
| 7 | POST | `/api/eutr-masters/import` | `EutrMasters.Create` | `multipart/form-data`, field `file` (.xlsx) | `ImportEutrMastersResultDto` |
| 8 | GET | `/api/eutr-masters/export` | `EutrMasters.Download` | — | File `.xlsx` (2 cột: Step name, Prefix; dòng 1 tiêu đề) |

> Ghi chú: (a) endpoint `GET /api/eutr-masters` (get-all không phân trang) là tùy chọn — không bắt
> buộc cho màn hình này; select box "Step name" dùng `GET /api/eutr-steps` (đã có). (b) Áp policy
> Import = `EutrMasters.Create` (tạo bản ghi); có thể tách quyền `EutrMasters.Import` riêng nếu hệ
> thống quyền hỗ trợ.

## EutrMastersRequestDto

```json
{ "stepId": 12, "prefix": "BB-GN" }
```

- `stepId`: bắt buộc, > 0 (FluentValidation).
- `prefix`: bắt buộc, không rỗng.
- Ràng buộc dịch vụ: cặp (stepId, prefix) phải **duy nhất** → trùng trả lỗi (chặn lưu).

## EutrMastersResponseDto

```json
{
  "id": 100, "stepId": 12, "stepName": "biên bản giao nhận gỗ", "prefix": "BB-GN",
  "createdBy": "hien", "createdDate": "2026-07-02T03:00:00Z",
  "updatedBy": null, "updatedDate": null
}
```

- `stepName` do backend JOIN `eutr_steps` trả về (không lưu trong `eutr_master_documents`).

## ImportEutrMastersResultDto

```json
{
  "totalRows": 50, "successCount": 47, "failCount": 1, "duplicateCount": 2,
  "errors": [ { "rowNumber": 8, "stepName": "khong ton tai", "prefix": "X", "reason": "Step not found" } ],
  "duplicates": [ { "rowNumber": 15, "stepName": "hop dong mua ban", "prefix": "HD", "reason": "Duplicate step + prefix" } ]
}
```

## FilterRequest (cho get-all)

```json
{ "column": "StepName", "operator": "like", "value": "giao nhan" }
```

- Toán tử hỗ trợ: `like`, `between` (`"a,b"`), `in` (`"1,2,3"`), `>=`, `<=`, `>`, `<`, `=`.
- Lọc theo **tên bước** dùng cột logic `StepName` → service ánh xạ sang `eutr_steps.Name LIKE` trong
  câu JOIN (xem plan "Khác biệt backend" #2).

## Ánh xạ frontend (eutrMastersApi.js)

| Use case | Hàm api | Endpoint |
|----------|---------|----------|
| GetPagingEutrMasters | `getAllPaging(page,pageSize,sortColumn,sortOrder,payload)` | POST `/eutr-masters/get-all` |
| (by id) | `getById(id)` | GET `/eutr-masters/get-by-id/{id}` |
| CreateEutrMasters | `create(data)` | POST `/eutr-masters` |
| UpdateEutrMasters | `update(id,data)` | PUT `/eutr-masters/{id}` |
| DeleteEutrMasters | `delete(id)` | DELETE `/eutr-masters/{id}` |
| DeleteMultiEutrMasters | `deleteMulti(ids)` | POST `/eutr-masters/delete-multi` |
| ImportEutrMasters | `import(file)` | POST `/eutr-masters/import` (FormData, field `file`) |
| ExportEutrMasters | `export()` | GET `/eutr-masters/export` (responseType `blob`) → tải file |
| (select box steps) | `eutrStepApi.getAll()` | GET `/eutr-steps` |

## Export file format

- Dòng 1 (tiêu đề): `Step name` (cột A), `Prefix` (cột B).
- Từ dòng 2: mỗi master một dòng — A = tên bước (StepName), B = Prefix.
- Không có master → chỉ dòng tiêu đề. Định dạng trùng khớp file import (round-trip).
- Tên file: `eutr-master-yyyyMMddHHmmss.xlsx` (ví dụ `eutr-master-20260702153000.xlsx`).
