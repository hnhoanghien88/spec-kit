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
