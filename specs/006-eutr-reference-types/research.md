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

## Quyết định 9 (Update 1) — Assign Steps: clone `EutrTemplateReferences`/`ApplyCustomerPage`, bỏ Vendor/Date/Import-Export

- **Decision**: Backend/frontend cho tính năng **Assign Steps** (bảng `eutr_reference_type_details`)
  được clone từ cặp `EutrTemplateReferences` (backend) + `ApplyCustomerPage.jsx` (frontend) của
  `003-eutr-templates` — cùng hình dạng "bảng chi tiết gán entity phụ cho 1 bản ghi cha, truy cập
  qua icon trên danh sách cha, có màn hình con riêng" — thay vì clone lại `EutrReferenceTypes`
  (dùng cho CRUD cấp cao nhất, không có khái niệm "gán theo record cha").
- **Rationale**: `eutr_reference_type_details` có FK kép (`TypeId`, `StepId`) giống hệt
  `eutr_template_references` có FK kép (`TemplateId`, `VendorCode` — dù VendorCode không phải FK
  cứng, về mặt vai trò nghiệp vụ là tương đương). `ApplyCustomerPage.jsx` đã chứng minh mẫu "trang
  con độc lập + dialog Add/Edit + Delete xác nhận + kiểm tra trùng client-side trước khi gọi API"
  hoạt động đúng trong cùng hệ thống EUTR.
- **Khác biệt so với `EutrTemplateReferences`/`ApplyCustomerPage`** (theo đúng yêu cầu người dùng):
  1. **Không có Vendor** — chỉ 1 trường **Step**, nguồn dữ liệu là bảng nội bộ `eutr_steps` (đã có
     API `GET /api/eutr-steps` từ `001-eutr-steps`), KHÔNG phải tra cứu D365 qua refType=13 như
     Vendor.
  2. **Không có From Date/To Date** — do đó không cần `HasOverlapAsync` kiểu khoảng ngày; thay bằng
     `HasStepAssignedAsync` kiểm tra trùng lặp đơn giản (cùng `TypeId` + cùng `StepId` đã tồn tại
     hay chưa).
  3. **Không có Import/Export** — `eutr_template_references` có Import/Export (Update 14 của
     003-eutr-templates) nhưng yêu cầu người dùng cho Assign Steps xác định rõ KHÔNG cần.
  4. **Không cần chặn xóa kiểu FK 1451** — khác `EutrReferenceTypes.DeleteAsync` (phải bắt lỗi FK vì
     `eutr_references.RefType` trỏ tới nó), không có bảng nào tham chiếu ngược tới
     `eutr_reference_type_details`, nên `DeleteAsync` là hard delete thuần túy, không cần override.
- **Alternatives considered**: Nhúng Assign Steps như một tab/section trong modal Edit hiện có của
  `EutrReferenceTypesModal.jsx` (thay vì trang con riêng) — bị loại vì không khớp yêu cầu "giống
  Apply to Customer" (vốn là trang riêng, truy cập qua icon, không phải tab trong modal Edit), và vì
  một reference type có thể có nhiều step gán (danh sách con), không hợp để nhồi vào modal 1 trường
  hiện tại.

## Quyết định 10 (Update 1) — Tái sử dụng policy `EutrReferenceTypes.*`, không tạo policy family riêng

- **Decision**: Controller `EutrReferenceTypeDetailsController` dùng lại policy
  `EutrReferenceTypes.ReadOne` (GetByTypeId), `EutrReferenceTypes.Update` (Create/Update),
  `EutrReferenceTypes.Delete` (Delete) — KHÔNG tạo policy family `EutrReferenceTypeDetails.*` mới.
- **Rationale**: Đúng tiền lệ đã áp dụng cho `EutrTemplateReferencesController` (tái sử dụng
  `EutrTemplates.*` thay vì tạo `EutrTemplateReferences.*`), với cùng lý do: Assign Steps là hành
  động phụ thuộc phạm vi của 1 reference type (truy cập qua icon trên danh sách, không phải màn
  hình có menu/permission riêng), nên không cần seed thêm quyền mới trên DB Authorization — quyền
  `EutrReferenceTypes.*` đã seed từ Quyết định 7/T021 là đủ.
- **Alternatives considered**: Tạo policy family riêng cho tính rành mạch — bị loại vì tăng chi phí
  vận hành (phải seed thêm permission mới trên DB Authorization) mà không mang lại lợi ích rõ ràng,
  đi ngược tiền lệ đã có của `EutrTemplateReferences`.

## Quyết định 11 (Update 1) — Route con tĩnh trong `MainRoutes.jsx`, không qua `RouteResolver`/menu mới

- **Decision**: Route `/eutr/reference-types/assign-steps/:id` khai báo trực tiếp trong
  `app/routes/groups/MainRoutes.jsx` (route con tĩnh, bọc `PrivateRoute`), KHÔNG đăng ký qua
  `RouteResolver.jsx`/`componentMap` (cơ chế backend-driven routing của ADR 0002 dành cho các mục
  menu cấp cao nhất).
- **Rationale**: Xác nhận qua agent nghiên cứu: `ApplyCustomerPage` (`/eutr/templates/apply/:id`) và
  `TemplateBuilderPage` (`/eutr/templates/edit/:id`) đều dùng đúng cơ chế này —
  `compliance-client/src/app/routes/groups/MainRoutes.jsx` dòng 14-24 (lazy import) và 82-88 (route
  object). Đây là route con truy cập qua icon từ 1 màn hình cha đã có menu/permission
  (`eutr-reference-types`), không phải mục menu độc lập, nên KHÔNG cần seed `userMenu` mới trên DB
  Authorization (khác route gốc `/eutr/reference-types`, xem Quyết định 7).
- **Alternatives considered**: Đăng ký qua `RouteResolver`/`componentMap` như route gốc — bị loại vì
  route con dạng `:id` không phù hợp với cơ chế `componentMap` (map theo `code` menu cố định, không
  hỗ trợ route param), và không khớp tiền lệ `ApplyCustomerPage` đã hoạt động đúng.
