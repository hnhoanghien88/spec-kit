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

---

## Assign Steps — EutrReferenceTypeDetails (MỚI — Update 1, cần tạo)

Mô phỏng theo `EutrTemplateReferencesController` (`api/eutr-template-references`, xem
`specs/003-eutr-templates/contracts/api-endpoints.md` Section 9 — Apply to Customer), bỏ Vendor và
From Date/To Date, thay bằng 1 trường Step; bỏ Import/Export.

Base route: `api/eutr-reference-type-details`. Tất cả endpoint yêu cầu `[Authorize]`. **Tái sử dụng
policy `EutrReferenceTypes.*` hiện có** (KHÔNG tạo policy family riêng), theo đúng tiền lệ
`EutrTemplateReferencesController` tái sử dụng `EutrTemplates.*`.

| # | Method | Path | Policy | Body / Params | Trả về |
|---|--------|------|--------|---------------|--------|
| 1 | GET | `/api/eutr-reference-type-details/by-type/{typeId}` | `EutrReferenceTypes.ReadOne` | — | `IEnumerable<EutrReferenceTypeDetailsResponseDto>` |
| 2 | POST | `/api/eutr-reference-type-details` | `EutrReferenceTypes.Update` | `EutrReferenceTypeDetailsRequestDto { typeId, stepId }` | `long` (id mới), hoặc lỗi validate nếu step đã gán |
| 3 | PUT | `/api/eutr-reference-type-details/{id}` | `EutrReferenceTypes.Update` | `EutrReferenceTypeDetailsRequestDto { typeId, stepId }` | message, hoặc lỗi validate nếu step đã gán (loại trừ chính bản ghi đang sửa) |
| 4 | DELETE | `/api/eutr-reference-type-details/{id}` | `EutrReferenceTypes.Delete` | — | message (hard delete thật, không có `IsDeleted`) |

### 1. Get Assigned Steps by Reference Type

```
GET api/eutr-reference-type-details/by-type/{typeId}
```

**Response**:
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "typeId": 5,
      "stepId": 3,
      "stepName": "Step 3 - Risk Assessment",
      "createdBy": "user@email.com",
      "createdDate": "2026-07-24T09:00:00",
      "updatedBy": "user@email.com",
      "updatedDate": "2026-07-24T09:00:00"
    }
  ]
}
```

**Notes**:
- `stepName` là trường response-only, resolve bằng JOIN cục bộ tới `eutr_steps` (KHÔNG qua D365 —
  khác `vendorName` bên `eutr_template_references`).
- Không phân trang — 1 reference type dự kiến chỉ có ít step gán; sắp xếp theo `CreatedDate DESC`.
- Gọi bởi `AssignStepsPage.jsx` khi mount, dùng route param `:id` (`/eutr/reference-types/assign-steps/:id`).

### 2. Assign Step (Create)

```
POST api/eutr-reference-type-details
```

**Request Body**:
```json
{ "typeId": 5, "stepId": 3 }
```

**Response**:
```json
{ "success": true, "data": { "id": 1 }, "message": "Step assigned successfully." }
```

**Response — trùng lặp bị từ chối** (FR-017):
```json
{ "success": false, "message": "This step is already assigned to this reference type." }
```

**Behavior**:
- Validation: `stepId` bắt buộc.
- Kiểm tra trùng: từ chối nếu tồn tại bản ghi khác cùng `typeId` VÀ cùng `stepId`.
- Không tự sinh `Code`/`VersionId` — bảng này không có 2 cột đó.

### 3. Update Assigned Step (Edit)

```
PUT api/eutr-reference-type-details/{id}
```

**Request Body**: giống Create (mục 2).

**Response**:
```json
{ "success": true, "message": "Step assignment updated successfully." }
```

**Behavior**: cập nhật `StepId` đè lên bản ghi (giữ `Id`/`TypeId`/`CreatedBy`/`CreatedDate`). Kiểm
tra trùng loại trừ chính bản ghi đang sửa (`id`).

### 4. Delete Assigned Step (Hard Delete)

```
DELETE api/eutr-reference-type-details/{id}
```

**Response**:
```json
{ "success": true, "message": "Step assignment removed successfully." }
```

**Behavior**: `DELETE FROM eutr_reference_type_details WHERE Id = @id` thật — bảng không có cột
`IsDeleted`. Xác nhận qua `ConfirmDialog` ở frontend trước khi gọi.

## Ánh xạ frontend (`eutrReferenceTypeDetailsApi.js`, Update 1)

| Use case | Hàm api | Endpoint |
|----------|---------|----------|
| GetByTypeIdEutrReferenceTypeDetails | `getByTypeId(typeId)` | GET `/eutr-reference-type-details/by-type/{typeId}` |
| CreateEutrReferenceTypeDetails | `create(data)` | POST `/eutr-reference-type-details` |
| UpdateEutrReferenceTypeDetails | `update(id,data)` | PUT `/eutr-reference-type-details/{id}` |
| DeleteEutrReferenceTypeDetails | `delete(id)` | DELETE `/eutr-reference-type-details/{id}` |

> Danh sách Step để chọn trong combobox Add/Edit KHÔNG gọi endpoint này — dùng lại
> `GET /api/eutr-steps` (`eutrStepApi.getAll()`, đã có sẵn từ `001-eutr-steps`).
