# API Contract: EUTR Steps (HIỆN HỮU — chỉ đối chiếu)

Nguồn: `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrStepsController.cs`
Base route: `api/eutr-steps`. Tất cả endpoint yêu cầu `[Authorize]` + policy tương ứng.
Bao bọc phản hồi: `ApiResponse<T>` (`{ data, message, success }`).

| # | Method | Path | Policy | Body / Params | Trả về |
|---|--------|------|--------|---------------|--------|
| 1 | GET | `/api/eutr-steps/get-by-id/{id}` | `EutrSteps.ReadOne` | — | `EutrStep` |
| 2 | GET | `/api/eutr-steps` | `EutrSteps.ReadAll` | — | `IEnumerable<EutrStep>` |
| 3 | POST | `/api/eutr-steps/get-all` | `EutrSteps.ReadAll` | query: `page,pageSize,sortColumn,sortOrder`; body: `List<FilterRequest>` | `PagedResult<EutrStepResponseDto>` |
| 4 | POST | `/api/eutr-steps` | `EutrSteps.Create` | `EutrStepRequestDto { name }` | `long` (id mới) |
| 5 | PUT | `/api/eutr-steps/{id}` | `EutrSteps.Update` | `EutrStepRequestDto { name }` | message |
| 6 | DELETE | `/api/eutr-steps/{id}` | `EutrSteps.Delete` | — | message |
| 7 | POST | `/api/eutr-steps/delete-multi` | `EutrSteps.Delete` | `IEnumerable<long> ids` | message |

## FilterRequest (cho get-all)

```json
{ "column": "Name", "operator": "like", "value": "abc" }
```

Toán tử hỗ trợ: `like`, `between` (`"a,b"`), `in` (`"1,2,3"`), `>=`, `<=`, `>`, `<`, `=`.

## Ánh xạ frontend (eutrStepApi.js)

| Use case | Hàm api | Endpoint |
|----------|---------|----------|
| GetEutrSteps | `getAll()` | GET `/eutr-steps` |
| GetPagingEutrSteps | `getAllPaging(page,pageSize,sortColumn,sortOrder,payload)` | POST `/eutr-steps/get-all` |
| (by id) | `getById(id)` | GET `/eutr-steps/get-by-id/{id}` |
| CreateEutrStep | `create(data)` | POST `/eutr-steps` |
| UpdateEutrStep | `update(id,data)` | PUT `/eutr-steps/{id}` |
| DeleteEutrStep | `delete(id)` | DELETE `/eutr-steps/{id}` |
| DeleteMultiEutrStep | `deleteMulti(ids)` | POST `/eutr-steps/delete-multi` |

> LƯU Ý: mẫu `documentTypeApi` dùng `getById: GET /document-types/{id}`, nhưng EUTR steps dùng
> `GET /eutr-steps/get-by-id/{id}`. Cần chỉnh đúng path này khi clone.
