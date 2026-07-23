# Research: EUTR Reference Types

Phase 0 — giải quyết các điểm chưa rõ. Khác với `001-eutr-steps` (backend đã có sẵn), feature này
**backend CHƯA tồn tại** — bảng `eutr_reference_types` mới được thêm vào DB nhưng chưa có Domain
entity/Application/Api layer nào tham chiếu tới nó (đã xác minh: không có file `EutrReferenceTypes*`
nào trong `compliance-sys-api` hay `compliance-client`). Vì vậy phạm vi thực chất là **full-stack**,
không chỉ frontend.

## Quyết định 1 — Clone mẫu `EutrStep` (thay vì `document-type`)

- **Decision**: Dùng feature `001-eutr-steps` (entity `EutrStep`, bảng `eutr_steps`) làm mẫu tham
  chiếu chính cho MỌI tầng (Domain, Application, Api, và frontend), thay vì `document-type`.
- **Rationale**: `eutr_reference_types` có đúng cùng hình dạng bảng với `eutr_steps`: chỉ 1 cột
  nghiệp vụ `Name` + 4 cột audit (`CreatedBy/CreatedDate/UpdatedBy/UpdatedDate`) + `Id` tự tăng.
  `EutrStep` đã là một cặp backend+frontend hoạt động đúng hình dạng này trong cùng hệ thống EUTR,
  nên là mẫu tham chiếu sát nhất theo Nguyên tắc II (Reference-Pattern Reuse). `document-type` vẫn
  là mẫu chuẩn cho frontend nhưng `EutrStep` bám sát hơn ở tầng backend (không có cột `location`/
  `prefix` phải loại bỏ).
- **Alternatives considered**: Clone `document-type` (mẫu chuẩn theo constitution) — bị loại vì
  `document-type` có thêm cột `Prefix`/`location` không tồn tại ở `eutr_reference_types`, gây dư
  thừa phải lược bỏ; `EutrStep` khớp 1-1.

## Quyết định 2 — Backend PHẢI được tạo mới (không áp dụng Nguyên tắc III)

- **Decision**: Tạo đầy đủ Domain entity, DTOs, validator, service, controller mới cho
  `EutrReferenceTypes`, đăng ký DI — không có backend hiện hữu để tái sử dụng.
- **Rationale**: Nguyên tắc III ("Reuse Existing Backend") chỉ áp dụng khi backend đã tồn tại.
  Agent nghiên cứu xác nhận không có `EutrReferenceTypes`/`api/eutr-reference-types` nào trong
  codebase. Repository tầng Infrastructure dùng **generic** `IRepository<TEntity, TKey>` qua
  `DapperRepository<,>` (đã đăng ký `services.AddScoped(typeof(IRepository<,>), typeof(DapperRepository<,>))`
  trong `ComplianceSys.Infrastructure/DependencyInjection.cs`), nên KHÔNG cần viết repository riêng
  — chỉ cần entity có `[Table("eutr_reference_types")]` đúng.
- **Alternatives considered**: Không có — bắt buộc phải tạo backend vì không tồn tại.

## Quyết định 3 — Kiểu dữ liệu Id: dùng `long` (không dùng `byte`/`TINYINT`)

- **Decision**: Domain entity `EutrReferenceTypes.Id` khai báo kiểu `long`, dù cột DB là
  `TINYINT UNSIGNED`.
- **Rationale**: Toàn bộ entity hiện có trong codebase (kể cả `ComplReferenceTypes.Id` — một bảng
  reference-type khác, không liên quan — cũng có cột `Id` không phải BIGINT) đều dùng quy ước
  `long Id` bất kể kiểu cột DB thực tế; Dapper + MySql.Data tự convert. Việc dùng `byte` sẽ lệch
  quy ước, tăng rủi ro tràn kiểu khi `TKey` truyền qua các API generic (`IBaseService<,,>`,
  `Convert.ChangeType` trong `BaseService.SetEntityId`) mà không có lợi ích thực tế (giới hạn 255
  bản ghi reference type là đủ dùng và không cần ép kiểu chặt ở tầng ứng dụng).
- **Alternatives considered**: `byte`/`short` khớp đúng `TINYINT UNSIGNED` — bị loại vì lệch quy ước
  toàn codebase và không mang lại lợi ích.

## Quyết định 4 — Chặn xóa khi đang được tham chiếu (FR-009/SC-006)

- **Decision**: Override `DeleteAsync` trong `EutrReferenceTypesService` để bắt lỗi khóa ngoại từ
  MySQL (`MySql.Data.MySqlClient.MySqlException` với `Number == 1451`, phát sinh khi
  `eutr_references.RefType` đang trỏ tới bản ghi bị xóa) và ném lại thành
  `InvalidOperationException("This reference type is currently in use and cannot be deleted.")`.
  Mở rộng `ValidationExceptionMiddleware` (Api layer) thêm một nhánh `catch (InvalidOperationException ex)`
  trả về `409 Conflict` kèm `ApiResponse<string>.Fail(ex.Message)`. `DeleteMultiAsync` (kế thừa từ
  `BaseService`) gọi `DeleteAsync` cho từng id khi repository không có `DeleteManyAsync` — cần xác
  minh hành vi khi 1 trong nhiều id bị chặn (xem Assumptions ở `data-model.md`).
- **Rationale**: Đây là ràng buộc dữ liệu thực tế duy nhất khác biệt so với `EutrStep` (do
  `eutr_references.RefType` FK tới `eutr_reference_types.Id`, trong khi `eutr_steps` không có FK
  tương tự trong phạm vi spec 001). Không có middleware nào hiện bắt lỗi DB constraint chung — nếu
  không xử lý, người dùng sẽ nhận lỗi 500 chung chung, vi phạm FR-009/SC-006. Dùng exception có sẵn
  (`InvalidOperationException`) thay vì tạo class exception mới, khớp quy ước tối giản hiện tại của
  middleware (chỉ có 2 catch clause: `ValidationException`, `KeyNotFoundException`).
- **Alternatives considered**: (a) Không xử lý, để lỗi 500 mặc định — bị loại vì vi phạm yêu cầu
  spec; (b) Tạo custom exception class riêng (`ReferentialIntegrityException`) — bị loại vì codebase
  chưa có custom exception nào, thêm 1 exception loại mới cho 1 trường hợp là over-engineering so
  với tái sử dụng `InvalidOperationException` sẵn có của .NET.

## Quyết định 5 — Chỉ CRUD, không Import/Export

- **Decision**: Không xây dựng chức năng import/export Excel (khác với `002-eutr-masters`).
- **Rationale**: Spec (`006-eutr-reference-types/spec.md`) xác định rõ phạm vi "chỉ CRUD" theo yêu
  cầu người dùng; không có FR nào về import/export.

## Quyết định 6 — Quyền theo menu + policy (giống `EutrStep`)

- **Decision**: Policy string dạng `EutrReferenceTypes.ReadOne/ReadAll/Create/Update/Delete`, áp
  dụng `[Authorize(Policy = "...")]` trên từng endpoint controller, giống hệt mẫu
  `EutrStepsController`. Không có class hằng số cho policy string trong codebase (xác nhận qua
  nghiên cứu) — literal string dùng trực tiếp trong attribute là quy ước hiện tại.
- **Rationale**: Đồng nhất Nguyên tắc V; các policy này được resolve động qua
  `IAuthorizationPolicyProvider` dựa trên quyền seed sẵn trong DB (không cần đăng ký `AddPolicy`
  trong `Program.cs`).

## Quyết định 7 — Seed menu/quyền để màn hình hiển thị được (ADR 0002)

- **Decision**: Tạo file seed mẫu `docs/design/eutr/seed_eutr_reference_types_menu.sql` (dạng
  comment-out như `seed_eutr_templates_menu.sql`) với `code = "eutr-reference-types"`,
  `url = "/eutr/reference-types"`, và các permission `ReadAll/Read/Create/Update/Delete`.
- **Rationale**: Theo ADR 0002 (routing/quyền do backend điều khiển), route mới **chỉ hiển thị**
  khi `userMenu` (DB) có bản ghi `code`/`url` tương ứng và role được cấp quyền
  `canAccessMenu('eutr-reference-types')`. Quên bước này là "nguyên nhân số 1" khiến màn mới ra
  NotFound (theo chính ADR). Đây là việc vận hành DB (ngoài phạm vi code sinh tự động), nên chỉ
  cung cấp file seed mẫu, không tự chạy.

## Quyết định 8 — Sắp xếp/lọc/phân trang server-side (giống `EutrStep`)

- **Decision**: Dùng `DataGrid` server mode + hook `useEutrReferenceTypesData` gọi
  `GetPagingEutrReferenceTypesUseCase`, payload lọc qua `useFilterPayload`, giống
  `useEutrStepData`.
- **Rationale**: Endpoint `POST get-all` nhận `page/pageSize/sortColumn/sortOrder` + `FilterRequest[]`
  — mẫu đã chứng minh hoạt động đúng ở `EutrStep`.
