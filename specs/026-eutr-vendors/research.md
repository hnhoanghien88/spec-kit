# Research: EUTR Vendors

## Decision 1: Entity không kế thừa BaseEntity
- **Decision**: `EutrVendors` chỉ có Id, Code, Name, CreatedBy, CreatedDate.
- **Rationale**: Bảng không có UpdatedBy/UpdatedDate; `BaseEntity` sẽ khiến Dapper INSERT/UPDATE tham chiếu cột không tồn tại. `BaseService.SetAuditFields` dùng reflection (`GetProperty`) nên tự bỏ qua trường thiếu.
- **Alternatives**: thêm cột Updated* vào bảng — trái với danh sách cột người dùng yêu cầu.

## Decision 2: Chống trùng Code qua repository riêng
- **Decision**: `IEutrVendorsRepository.ExistsCodeAsync(code, excludeId)` so sánh `LOWER(Code)`; service kiểm tra trước khi Add/Update; thêm UNIQUE index trên `Code` ở DB làm lớp bảo vệ cuối (đua ghi đồng thời).
- **Rationale**: Theo mẫu `EutrMastersService.ExistsPrefixAsync`. Collation MySQL mặc định đã không phân biệt hoa/thường nhưng so sánh tường minh an toàn hơn.
- **Alternatives**: chỉ dựa vào unique index — thông báo lỗi kém thân thiện.

## Decision 3: Giới hạn độ dài và kiểu Id
- **Decision**: `Code VARCHAR(50) NOT NULL`, `Name VARCHAR(255) NOT NULL`, `Id BIGINT UNSIGNED AUTO_INCREMENT`; validator `NotEmpty` + `MaximumLength`.
- **Rationale**: Khớp assumption trong spec; Id `long` khớp `IRepository<T, long>`.

## Decision 4: Xóa
- **Decision**: Xóa cứng, dùng `BaseService.DeleteAsync/DeleteMultiAsync` mặc định.
- **Rationale**: Chưa có bảng nào tham chiếu `eutr_vendors` (spec assumption).

## Decision 5: Menu & quyền
- **Decision**: Không seed menu/permission (đã có trong data). Policy dùng `EutrVendors.{ReadAll,ReadOne,Create,Update,Delete}`; client thêm `'eutr-vendors'` vào `RouteResolver.jsx` (routing theo backend `userMenu`).
