# Data Model: EUTR Reference Types

## Thực thể: EutrReferenceTypes (bảng `eutr_reference_types`)

Nguồn sự thật (Phase 1 thiết kế, chưa tồn tại — sẽ tạo tại):
`compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrReferenceTypes.cs` (kế thừa `BaseEntity`,
mẫu `EutrStep.cs`). Định nghĩa bảng: `docs/design/eutr/eutr_db.sql` dòng 141-148.

| Trường | Kiểu (DB) | Kiểu (C#/entity) | Nguồn | Ghi chú |
|--------|-----------|-------------------|-------|---------|
| `Id` | `TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY` | `long` | DB | Khóa chính, chỉ đọc. Dùng `long` theo quy ước toàn codebase (xem research.md Quyết định 3), dù cột DB là TINYINT |
| `Name` | `VARCHAR(255) NULL` | `string?` | Người dùng nhập | **Bắt buộc, không rỗng** ở tầng ứng dụng (FluentValidation `NotEmpty`), dù cột DB cho phép NULL |
| `CreatedBy` | `VARCHAR(50) NULL` | `string?` | Hệ thống | Ghi tự động từ user đăng nhập |
| `CreatedDate` | `DATETIME NULL` | `DateTime` | Hệ thống | Ghi tự động |
| `UpdatedBy` | `VARCHAR(50) NULL` | `string?` | Hệ thống | Ghi tự động khi sửa |
| `UpdatedDate` | `DATETIME NULL` | `DateTime` | Hệ thống | Ghi tự động khi sửa |

## Quy tắc nghiệp vụ (validation)

- `Name` bắt buộc, không được rỗng/chỉ khoảng trắng → chặn ở modal frontend trước khi submit, khớp
  validator backend `EutrReferenceTypesRequestDtoValidator.RuleFor(x => x.Name).NotEmpty()` (FR-005,
  FR-006).
- `Id` không sửa được; khi Edit, gửi kèm `id` trong payload `update` (qua URL `PUT /eutr-reference-types/{id}`).
- **Xóa bị chặn khi đang được tham chiếu** (FR-009): `eutr_references.RefType` có FK tới
  `eutr_reference_types.Id` (khai báo tại `eutr_db.sql` dòng 150,
  `eutr_references_reftype_foreign`). Xóa một reference type đang được ít nhất 1 `eutr_references`
  trỏ tới MUST bị từ chối với thông báo rõ ràng, không phải lỗi hệ thống chung chung (xem research.md
  Quyết định 4 cho cơ chế bắt lỗi FK và dịch thành thông báo).

## Đối tượng truyền (frontend ↔ backend)

- **Tạo/Sửa (request)**: `EutrReferenceTypesRequestDto { name }` (kèm `id` khi sửa, đặt ở URL
  `PUT /eutr-reference-types/{id}`).
- **Phản hồi danh sách (get-all)**: `PagedResult<EutrReferenceTypesResponseDto>` →
  `{ items: [...], totalCount }` (frontend đọc theo `response.data.items` / `response.data.totalCount`).
- **Xóa nhiều**: mảng `ids` (number[]) gửi tới `POST /eutr-reference-types/delete-multi`.
- **Xóa bị từ chối do đang sử dụng**: backend trả `409 Conflict` với
  `ApiResponse<string>.Fail("This reference type is currently in use and cannot be deleted.")`;
  frontend hiển thị thông báo lỗi này qua `CustomSnackbar` thay vì xóa dòng khỏi UI.

## Quan hệ

- **`eutr_references.RefType` → `eutr_reference_types.Id`** (FK `eutr_references_reftype_foreign`):
  quan hệ một-nhiều, chỉ ảnh hưởng tới quy tắc xóa (không hiển thị/sửa `eutr_references` trong
  phạm vi feature này — chỉ đọc gián tiếp qua ràng buộc khóa ngoại khi xóa).

## Giả định về hành vi `DeleteMultiAsync` khi có id đang bị tham chiếu

`BaseService.DeleteMultiAsync` gọi generic `DeleteManyAsync` nếu repository hỗ trợ, nếu không thì
lặp gọi `DeleteAsync` cho từng id (bắt được `InvalidOperationException` theo override ở Quyết định
4). Vì repository generic (`DapperRepository<,>`) có khả năng có `DeleteManyAsync` (cần xác minh
lúc implement — nếu có, nó xóa hàng loạt bằng 1 câu lệnh SQL và KHÔNG đi qua override
`EutrReferenceTypesService.DeleteAsync`, nên KHÔNG bắt được lỗi FK theo từng dòng). Do đó khi
implement, `EutrReferenceTypesService` cũng PHẢI override `DeleteMultiAsync` để đảm bảo lỗi FK ở bất
kỳ id nào trong batch đều được báo rõ ràng (ví dụ: lặp gọi `DeleteAsync` từng id thay vì dùng
`DeleteManyAsync` hàng loạt, đánh đổi hiệu năng nhỏ để đảm bảo đúng FR-009 khi xóa nhiều).

---

## Thực thể: EutrReferenceTypeDetails (bảng `eutr_reference_type_details`, Update 1 — Assign Steps)

Nguồn sự thật (thiết kế, chưa tồn tại — sẽ tạo tại):
`compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrReferenceTypeDetails.cs` (kế thừa
`BaseEntity`, mẫu `EutrTemplateReferences.cs` của `003-eutr-templates`). Định nghĩa bảng:
`docs/design/eutr/eutr_db.sql` dòng 152-164.

| Trường | Kiểu (DB) | Kiểu (C#/entity) | Nguồn | Ghi chú |
|--------|-----------|-------------------|-------|---------|
| `Id` | `BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY` | `long` | DB | Khóa chính, chỉ đọc |
| `StepId` | `BIGINT UNSIGNED NULL` | `long?` | Người dùng chọn (combobox) | **Bắt buộc ở tầng ứng dụng** (FluentValidation `NotNull`), dù cột DB cho phép NULL — FR-015/FR-017. FK → `eutr_steps(Id)` |
| `TypeId` | `BIGINT UNSIGNED NOT NULL` | `long` | Route param (`:id` của reference type đang xem) | Không do người dùng nhập trực tiếp trên form — frontend gán từ route trước khi gửi. FK → `eutr_reference_types(Id)` |
| `CreatedBy` | `VARCHAR(50) NULL` | `string?` | Hệ thống | Ghi tự động |
| `CreatedDate` | `DATETIME NULL` | `DateTime` | Hệ thống | Ghi tự động |
| `UpdatedBy` | `VARCHAR(50) NULL` | `string?` | Hệ thống | Ghi tự động khi sửa |
| `UpdatedDate` | `DATETIME NULL` | `DateTime` | Hệ thống | Ghi tự động khi sửa |

### Quy tắc nghiệp vụ (validation)

- `StepId` bắt buộc phải chọn khi Add/Edit → chặn ở dialog frontend trước khi submit, khớp
  validator backend `EutrReferenceTypeDetailsRequestDtoValidator.RuleFor(x => x.StepId).NotNull()`
  (FR-015, FR-017).
- **Chặn gán trùng step cho cùng reference type** (FR-017/SC-008): nếu `StepId` đã chọn đã tồn tại
  một bản ghi khác có cùng `TypeId` trong `eutr_reference_type_details`, hệ thống MUST từ chối lưu
  với thông báo rõ ràng ("This step is already assigned to this reference type."). Khi Edit, loại
  trừ chính bản ghi đang sửa khỏi phép so sánh (`HasStepAssignedAsync(typeId, stepId, excludeId)`).
  Đây là bản đơn giản hóa của kiểm tra chồng lấn ngày `HasOverlapAsync` bên
  `eutr_template_references` (không có khoảng ngày nên chỉ cần so sánh bằng).
- **Không có quy tắc chặn xóa** (khác `eutr_reference_types`) — không có bảng nào FK tới
  `eutr_reference_type_details`, nên `DELETE` là hard delete thuần túy, không cần bắt lỗi FK 1451.
- `Id` không sửa được; khi Edit, gửi kèm `id` trong payload `update` (qua URL `PUT
  /eutr-reference-type-details/{id}`), chỉ `StepId` được cập nhật (giữ nguyên `TypeId`).

### Đối tượng truyền (frontend ↔ backend)

- **Tạo/Sửa (request)**: `EutrReferenceTypeDetailsRequestDto { typeId, stepId }` (kèm `id` khi sửa,
  đặt ở URL `PUT /eutr-reference-type-details/{id}`).
- **Phản hồi danh sách (theo reference type)**: `IEnumerable<EutrReferenceTypeDetailsResponseDto>`
  (không phân trang — số step gán cho 1 reference type nhỏ), mỗi phần tử thêm `stepName` (string?,
  JOIN cục bộ tới `eutr_steps`, không qua D365).
- **Gán trùng bị từ chối**: backend trả lỗi validate (400, qua `ValidationException`/
  `FluentValidation`, giống cơ chế `EutrReferenceTypeDetailsRequestDtoValidator` — KHÔNG cần mã 409
  riêng như FR-009, vì đây là lỗi input logic chứ không phải ràng buộc khóa ngoại ở tầng DB); frontend
  hiển thị qua `CustomSnackbar`/lỗi form tại field Step.

### Quan hệ

- **`eutr_reference_type_details.TypeId` → `eutr_reference_types.Id`** (FK
  `eutr_reference_type_details_typeid_foreign`): 1 reference type có nhiều step đã gán.
- **`eutr_reference_type_details.StepId` → `eutr_steps.Id`** (FK
  `eutr_reference_type_details_stepid_foreign`): mỗi bản ghi gán trỏ tới đúng 1 step nội bộ; dùng để
  tra cứu `StepName` hiển thị trên bảng Assign Steps.
- Không có bảng nào khác tham chiếu tới `eutr_reference_type_details` (đã xác minh qua
  `docs/design/eutr/eutr_db.sql` — chỉ 2 FK đi RA từ bảng này, không có FK nào đi VÀO).
