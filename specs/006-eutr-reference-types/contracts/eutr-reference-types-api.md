# API Contract: EUTR Reference Types (MỚI — cần tạo)

Khác với `001-eutr-steps` (contract chỉ để đối chiếu backend có sẵn), contract này là **thiết kế
cần triển khai**, mô phỏng 1-1 theo `EutrStepsController` (xem
`specs/001-eutr-steps/contracts/eutr-steps-api.md`) và điều chỉnh cho quy tắc chặn xóa (FR-009).

Base route: `api/eutr-reference-types`. Tất cả endpoint yêu cầu `[Authorize]` + policy tương ứng.
Bao bọc phản hồi: `ApiResponse<T>` (`{ data, message, success }`).

| # | Method | Path | Policy | Body / Params | Trả về |
|---|--------|------|--------|---------------|--------|
| 1 | GET | `/api/eutr-reference-types/get-by-id/{id}` | `EutrReferenceTypes.ReadOne` | — | `EutrReferenceTypes` |
| 2 | GET | `/api/eutr-reference-types` | `EutrReferenceTypes.ReadAll` | — | `IEnumerable<EutrReferenceTypes>` |
| 3 | POST | `/api/eutr-reference-types/get-all` | `EutrReferenceTypes.ReadAll` | query: `page,pageSize,sortColumn,sortOrder`; body: `List<FilterRequest>` | `PagedResult<EutrReferenceTypesResponseDto>` |
| 4 | POST | `/api/eutr-reference-types` | `EutrReferenceTypes.Create` | `EutrReferenceTypesRequestDto { name }` | `long` (id mới) |
| 5 | PUT | `/api/eutr-reference-types/{id}` | `EutrReferenceTypes.Update` | `EutrReferenceTypesRequestDto { name }` | message |
| 6 | DELETE | `/api/eutr-reference-types/{id}` | `EutrReferenceTypes.Delete` | — | message, hoặc **409** nếu đang được `eutr_references` tham chiếu |
| 7 | POST | `/api/eutr-reference-types/delete-multi` | `EutrReferenceTypes.Delete` | `IEnumerable<long> ids` | message, hoặc **409** nếu bất kỳ id nào đang được tham chiếu |

## FilterRequest (cho get-all)

```json
{ "column": "Name", "operator": "like", "value": "abc" }
```

Toán tử hỗ trợ: `like`, `between` (`"a,b"`), `in` (`"1,2,3"`), `>=`, `<=`, `>`, `<`, `=`.

## Phản hồi lỗi khi xóa bị chặn (409)

```json
{
  "data": null,
  "message": "This reference type is currently in use and cannot be deleted.",
  "success": false
}
```

Sinh ra khi `EutrReferenceTypesService.DeleteAsync`/`DeleteMultiAsync` bắt được
`MySqlException.Number == 1451` (FK `eutr_references_reftype_foreign`) và ném lại
`InvalidOperationException`, được `ValidationExceptionMiddleware` (mở rộng thêm 1 catch clause) map
sang `409 Conflict`.

## Ánh xạ frontend (`eutrReferenceTypesApi.js`)

| Use case | Hàm api | Endpoint |
|----------|---------|----------|
| GetEutrReferenceTypes | `getAll()` | GET `/eutr-reference-types` |
| GetPagingEutrReferenceTypes | `getAllPaging(page,pageSize,sortColumn,sortOrder,payload)` | POST `/eutr-reference-types/get-all` |
| (by id) | `getById(id)` | GET `/eutr-reference-types/get-by-id/{id}` |
| CreateEutrReferenceTypes | `create(data)` | POST `/eutr-reference-types` |
| UpdateEutrReferenceTypes | `update(id,data)` | PUT `/eutr-reference-types/{id}` |
| DeleteEutrReferenceTypes | `delete(id)` | DELETE `/eutr-reference-types/{id}` |
| DeleteMultiEutrReferenceTypes | `deleteMulti(ids)` | POST `/eutr-reference-types/delete-multi` |

> Theo mẫu `eutrStepApi.js`: dùng `GET /eutr-reference-types/get-by-id/{id}` (không phải
> `GET /eutr-reference-types/{id}` kiểu `document-type`).
