# Research: EUTR Documents Management

Phase 0 — chốt các quyết định kỹ thuật. Các điểm nghiệp vụ chưa rõ đã được giải quyết ở
`/speckit-clarify` (2 phiên ngày 2026-07-07). Không còn NEEDS CLARIFICATION tồn đọng.

## Quyết định 1 — Backend tạo mới theo mẫu `EutrStep` (không phải `EutrMasters`)

- **Decision**: Clone cấu trúc **`EutrStep`** (Domain/Application/Api), KHÔNG clone `EutrMasters`.
  Route `api/eutr-documents`.
- **Rationale**: `eutr_documents` là entity phẳng, không cần JOIN sang bảng khác (Step
  name/Conditions/Type luôn trống theo spec — không tra cứu bảng nào), và không có ràng buộc
  chống trùng (FR-007b). `EutrStep` là mẫu tối giản nhất trong 3 feature EUTR đã có (không
  repository riêng, không override AddAsync/UpdateAsync) — khớp chính xác với nhu cầu, tránh
  clone thừa logic JOIN/chống trùng của `EutrMasters`.
- **Alternatives considered**: (a) Clone `EutrMasters` — bị loại vì mang theo `GetPagedWithXAsync`
  JOIN và `ExistsXAsync` không cần thiết, sẽ phải xóa bớt code thay vì thêm; (b) Tự thiết kế từ
  đầu — bị loại, lệch Nguyên tắc II (Reference-Pattern Reuse).

## Quyết định 2 — Không tạo repository riêng, dùng thẳng `IRepository<EutrDocuments, long>` generic

- **Decision**: KHÔNG tạo `IEutrDocumentsRepository`/`EutrDocumentsRepository`. `EutrDocumentsService`
  nhận `IRepository<EutrDocuments, long>` (đã đăng ký open-generic
  `services.AddScoped(typeof(IRepository<,>), typeof(DapperRepository<,>))` trong
  `ComplianceSys.Infrastructure/DependencyInjection.cs`), gọi `base.GetPagedAsync` (BaseService)
  rồi map sang `EutrDocumentsResponseDto` bằng AutoMapper — đúng mẫu `EutrStepService`.
- **Rationale**: Không cần SQL tùy biến (không JOIN, không lọc theo cột dẫn xuất) → repository
  generic đã đủ CRUD + phân trang/lọc/sắp xếp theo whitelist cột thật của bảng. Giảm số file mới,
  tránh trùng lặp logic đã có trong `DapperRepository<,>`.
- **Alternatives considered**: Tạo repository riêng như `EutrMasters` "phòng khi cần mở rộng sau"
  — bị loại vì vi phạm nguyên tắc tránh trừu tượng hoá sớm (yagni); có thể thêm sau nếu một tính
  năng tương lai (vd. hiển thị Step name/Conditions/Type thật) cần JOIN.

## Quyết định 3 — Migration cột `Name`: BIGINT → VARCHAR(255)

- **Decision**: Thêm `ComplianceSys.Infrastructure/Sqls/Migration/09_migrate_eutr_documents_name.sql`:
  ```sql
  ALTER TABLE eutr_documents MODIFY COLUMN Name VARCHAR(255) NULL;
  ```
  Không cần bước dọn dữ liệu trước (khác migration AlertFor ở feature 003) vì cột `Name` hiện
  chưa có dữ liệu quan trọng nào phụ thuộc kiểu số (bảng mới, chưa có tính năng ghi dữ liệu).
  Đồng thời cập nhật `docs/design/eutr/eutr_db.sql` (nguồn thiết kế) và
  `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/eutr_db.sql` (bản build DDL)
  để khớp kiểu VARCHAR(255) mới — hai file này hiện đều ghi `Name BIGINT NULL`.
- **Rationale**: Clarify đã chốt: `Name` lưu File name dạng văn bản (Session 2026-07-07). Theo
  convention migration đã dùng ở feature 003 (`08_migrate_eutr_templates_alertfor.sql`), file
  migration mới đánh số tuần tự tiếp theo (09).
- **Alternatives considered**: Giữ nguyên BIGINT và ép kiểu ở tầng ứng dụng — bị loại vì không thể
  lưu văn bản (tên file) vào cột số nguyên; (b) Đổi tên cột thay vì đổi kiểu — bị loại, không cần
  thiết và phá vỡ tương thích với thiết kế đã có.

## Quyết định 4 — Frontend: Add là trang riêng, Edit vẫn là popup (mẫu lai)

- **Decision**: Trang **Add** (`EutrDocumentsAdd.jsx`) mượn cách wiring routing của
  `eutr-templates` (`RouteResolver.jsx` cho trang list + `MainRoutes.jsx` cho route
  `/eutr/documents/add`), nhưng đơn giản hoá tối đa: chỉ 3 trường (File name, Valid from, Valid
  to) + nút Save + nút Back, KHÔNG có cây bước, KHÔNG có `isDirty`/`ConfirmDialog` khi Back (Back
  điều hướng thẳng về `/eutr/documents`). **Edit** vẫn dùng **popup** `EutrDocumentsModal.jsx`,
  clone `EutrMastersModal.jsx` (thay Autocomplete Step + TextField Prefix bằng TextField File
  name + 2 trường ngày Valid from/Valid to).
- **Rationale**: Spec (FR-005, FR-009, User Story 2/3) yêu cầu chính xác tổ hợp này — Add mở trang
  mới (không popup), Edit mở popup. Đây là mẫu lai chưa từng có (steps/masters: cả hai đều popup;
  templates: cả hai đều trang riêng), nên phải ghép 2 mẫu tham chiếu thay vì clone một mẫu duy
  nhất — được ghi rõ ở Constitution Check/Key Differences để không gây nhầm lẫn khi review.
  Bỏ dirty-check vì Edge Case đã chốt: "form chỉ có 3 trường đơn giản, không cần cảnh báo mất dữ
  liệu" (khác `eutr-templates` có cây bước phức tạp cần bảo vệ).
- **Alternatives considered**: (a) Cả Add và Edit đều trang riêng (như templates) — bị loại, trái
  spec (Edit MUST là popup theo FR-009); (b) Cả hai đều popup (như masters) — bị loại, trái spec
  (Add MUST điều hướng sang trang riêng theo FR-005).

## Quyết định 5 — Cột grid Step name/Conditions/Type: khai báo nhưng không map dữ liệu

- **Decision**: `useEutrDocumentsColumns.jsx` khai báo 3 cột `stepName`, `conditions`, `type`
  nhưng KHÔNG gán `valueGetter`/field tương ứng nào tồn tại trên `EutrDocuments`
  entity/ResponseDto — MUI DataGrid tự hiển thị ô trống khi `row[field]` là `undefined`. Không cần
  backend trả field giả, không cần logic ẩn/hiện đặc biệt.
- **Rationale**: FR-003 yêu cầu các cột này "luôn ở trạng thái trống" vì `eutr_documents` không có
  cột nguồn — đây là cách đơn giản nhất đạt đúng yêu cầu mà không cần code thừa (không JOIN giả,
  không hard-code chuỗi rỗng).
- **Alternatives considered**: Backend trả `StepName: null, Conditions: null, Type: null` tường
  minh trong ResponseDto — bị loại vì thêm field không dùng vào DTO chỉ để tái tạo hành vi đã có
  sẵn khi field không tồn tại.

## Quyết định 6 — Icon View: placeholder active, không disable, không hành vi

- **Decision**: `EutrDocumentsActionCell.jsx` thêm `IconButton` thứ 3 dùng `VisibilityIcon` (mẫu
  Edit/Delete cùng `size="small"`, cùng cách hiển thị theo layout — không thêm điều kiện quyền
  riêng vì đây là placeholder không thao tác thật), `onClick={() => {}}` (no-op tuyệt đối, không
  gọi API/điều hướng/mở popup/hiện thông báo).
- **Rationale**: Clarify (Session 2026-07-07 Update 2) chốt: hiển thị **active bình thường** giống
  Edit/Delete (không mờ/disable), click **silent no-op**. Đây là cách hiện thực đơn giản và trung
  thực nhất với quyết định đó.
- **Alternatives considered**: Disable/làm mờ icon kèm tooltip "Not available yet" — bị loại theo
  clarify (phương án được chọn là active, không tooltip đặc biệt).

## Quyết định 7 — Quyền theo policy `EutrDocuments.*` + seed menu (routing backend-driven)

- **Decision**: Controller dùng `[Authorize(Policy = "EutrDocuments.ReadOne/ReadAll/Create/
  Update/Delete")]`. Frontend lấy `permissionList` từ menu (code `eutr-documents`) như mẫu
  `eutr-masters`/`eutr-templates`. Đồng thời thêm entry tĩnh vào
  `presentation/menu-items/ComplianceSystem.jsx` (code `eutr-documents`, url `/eutr/documents`)
  theo đúng những gì đã thực hiện cho `eutr-masters` và `eutr-templates` trong repo hiện tại.
- **Rationale**: Bộ nhớ dự án ghi rõ **routing là backend-driven** — `RouteResolver.jsx` khớp
  `location.pathname` với `mi.url` lấy từ **userMenu do backend trả về** (không phải file menu
  tĩnh), và `RouteGuard` chặn thêm bằng `roleProfile.canAccessMenu(mi.code)`. File
  `menu-items/ComplianceSystem.jsx` KHÔNG phải nguồn thật cho route/breadcrumb hiển thị cho
  người dùng cuối, nhưng cả 2 feature tham chiếu (`eutr-masters`, `eutr-templates`) đều có entry
  tương ứng trong file này trên thực tế — nên vẫn thêm entry cho nhất quán, dù đây không phải
  bước bắt buộc để route hoạt động.
- **Ghi chú triển khai (đã xác nhận theo tiền lệ 002/003)**: Menu + permission **thực tế truy cập
  được** phải được tạo động và phân quyền trực tiếp trong DB (không có code seed trong repo). Vì
  vậy KHÔNG có task code cho việc "cấp quyền" — đó là **tiền đề vận hành/DB**: tạo bản ghi menu
  code `eutr-documents` (url `/eutr/documents`) và các quyền
  `EutrDocuments.ReadAll/ReadOne/Create/Update/Delete`, gán cho role/user trước khi kiểm thử màn
  hình (xem quickstart). Breadcrumb hiển thị "EUTR > EUTR documents" (FR-002) phụ thuộc vào tên
  parent/item được cấu hình trong DB menu đó — không phải giá trị cứng trong code frontend.
- **Alternatives considered**: Bỏ kiểm tra quyền ở UI — bị loại vì vi phạm Nguyên tắc V.

## Quyết định 8 — Trang Add: thêm Type + layout List PO/Manual chỉ giao diện (spec Update 3)

- **Decision**: Trong `EutrDocumentsAdd.jsx`, thêm state cục bộ `takeFrom`
  (`useState(TAKE_FROM_OPTIONS[0].value)`) và một `<Autocomplete disableClearable>` MUI "Type" —
  **tái sử dụng nguyên hằng số có sẵn `TAKE_FROM_OPTIONS`** từ `compliance-client/src/utils/helpers.js`
  (`[{ value: 0, label: 'PO' }, { value: 1, label: 'Upload manual' }]`), đúng mẫu đã dùng ở
  `eutr-templates/components/StepFormRow.jsx`/`StepTree.jsx` cho các picker "Requirement"/"Take
  from". Khi `takeFrom === TAKE_FROM_OPTIONS[0].value` (PO) render block Screen1 (bảng List PO +
  khu upload); ngược lại (Manual/"Upload manual") render block Screen2 (khu upload + nút Assign
  condition + bảng file). Dữ liệu List PO/danh sách file là **hằng số tĩnh khai báo trong
  component** (không phải state từ API) — ví dụ `const DEMO_PO_LIST = [{ poName: "PO1", fileName:
  "File PO1-1" }, ...]`.
- **Phát hiện trong lúc implement (khác dự kiến ban đầu)**: Chuỗi placeholder "TAKE_FROM_OPTIONS -
  PO"/"TAKE_FROM_OPTIONS - Manual" trong `eutr_documents_overview.md` hoá ra tham chiếu **chính
  xác** tới hằng số `TAKE_FROM_OPTIONS` đã tồn tại trong codebase (dùng ở `eutr-templates` cho cột
  "Take from" của `eutr_template_details`) — không phải placeholder kỹ thuật chung chung như giả
  định lúc viết spec/plan ban đầu (khi đó dự kiến hard-code chuỗi "PO"/"Manual" qua `<Select>`
  thuần). Vì vậy đã đổi sang tái sử dụng đúng hằng số này (Nguyên tắc II) thay vì tạo chuỗi mới;
  nhãn lựa chọn thứ 2 hiển thị đúng theo hằng số có sẵn là **"Upload manual"** (không phải "Manual"
  như bản nháp thiết kế) — `spec.md`/`data-model.md`/`plan.md` đã cập nhật theo giá trị thật này.
- **Rationale**: Không có màn hình nào trong repo hiện kết hợp table với một dropdown "Type"
  chuyển đổi 2 layout trên cùng trang → không có mẫu tham chiếu trực tiếp cho tổ hợp này, nhưng
  bản thân danh sách lựa chọn "Type" (PO/Upload manual) đã có sẵn làm hằng số dùng chung, nên tái
  sử dụng thẳng thay vì tạo hằng số trùng lặp. Vì đây chỉ là giao diện demo (spec FR-017/FR-018),
  dữ liệu List PO/file hard-code là đủ và tránh việc phải tạo API/DTO/use case chỉ để phục vụ một
  tính năng chưa tồn tại.
- **Khu vực "Drag and drop files to upload"**: Không có thư viện `react-dropzone` hay component
  dropzone dùng chung nào trong repo. Mẫu kéo-thả gần nhất là
  `compliance-management/components/MapDataDialog.jsx` (dùng HTML5 native
  `onDragOver`/`onDrop` để map file kéo vào một dòng — không phải input nhận file thật). Áp dụng
  lại đúng cặp handler này ở dạng **no-op**: `onDragOver={(e) => e.preventDefault()}` (bắt buộc để
  trình duyệt không tự mở/điều hướng file khi người dùng thả vào) và `onDrop={(e) =>
  e.preventDefault()}` (không đọc `e.dataTransfer`, không set state nào) — hiển thị khung viền nét
  đứt (`Box` với `border: dashed`) chứa text "Drag and drop files to upload", không có `<input
  type="file">` ẩn nào (khác `ComplianceUploadForm.jsx`/`ComplianceUploadFormMulti.jsx` vốn dùng
  input file thật cho luồng upload đã có ở tính năng khác).
- **Nút "Assign condition" và View/Delete/checkbox trong bảng demo**: `onClick={() => {}}` /
  không gắn handler — cùng mẫu no-op đã áp dụng cho icon View (Quyết định 6).
- **Alternatives considered**: (a) Dùng `react-dropzone` — bị loại, thêm dependency mới chỉ để
  hiển thị khung tĩnh không xử lý file, trái Nguyên tắc II (tái dùng mẫu sẵn có) và không cần thiết
  ở phạm vi chỉ giao diện; (b) Gọi API thật để nạp List PO (nếu có) — bị loại **tại thời điểm đó**,
  hệ thống hiện không có bảng/API PO nào, và spec (Update 3) đã chốt dùng dữ liệu mẫu tĩnh (xem
  Quyết định 9 — quyết định này bị **thay thế một phần** ở Update 4); (c) Dùng `<Select>`/
  `<MenuItem>` thuần hoặc hard-code mảng "PO"/"Manual" mới cho Type — bị loại sau khi phát hiện
  hằng số `TAKE_FROM_OPTIONS` đã có sẵn và đang dùng đúng ngữ cảnh "take from" ở `eutr-templates`;
  tái sử dụng hằng số này khớp Nguyên tắc II tốt hơn là tạo dữ liệu trùng lặp.

## Quyết định 9 — List PO nối dữ liệu PO thật qua API reference dùng chung, refType 15/16 (spec Update 4)

- **Decision**: KHÔNG tạo endpoint GET/POST riêng cho `RSVNEutrPurchOrders`/`RSVNEutrSalesOrderPurchases`.
  Thay vào đó, đăng ký 2 entity D365 này vào **endpoint tham chiếu dùng chung đã có sẵn**
  `POST /api/dynamics/reference` (action `ReferenceData` trong `DynController`, service
  `ComplDynamicsService.GetDynRefePagedAsync`) — đúng cơ chế đã dùng cho `VendorsV3` (refType 14),
  `RSVNCustTableEntities` (refType 2), v.v.:
  - Domain model `RSVNEutrPurchOrders.cs`/`RSVNEutrSalesOrderPurchases.cs` (kế thừa `RSVNModelBase`)
    **đã tồn tại sẵn trong codebase** với `ModelType = 15`/`16` — chỉ cần đăng ký vào
    `EntityMappings` (KHÔNG cần tạo file domain model mới).
  - Thêm 2 dòng vào `EntityMappings` trong `ComplDynamicsService.cs`:
    `{ 15, ("RSVNEutrPurchOrders", "PurchId", "Name") }` và
    `{ 16, ("RSVNEutrSalesOrderPurchases", "RSVNRefPurchId", "Name") }`.
  - Thêm 2 `case` (15, 16) vào `MapDynamicsResponse`, map sang `ComplDynReferenceResponseDto`:
    refType 15 → `Id = Code = x.PurchId`, `Name = x.Name`; refType 16 → `Id = Code =
    x.RSVNRefPurchId`, `Name = x.Name` (theo đúng mẫu các case khác, vd. case 14/VendorsV3).
  - (Khuyến nghị, không bắt buộc) Thêm 2 giá trị vào enum `ObjectType`
    (`ComplEnum.cs`): `EUTR_PURCH_ORDER = 15`, `EUTR_SALES_ORDER_PURCHASE = 16`, theo đúng mẫu các
    refType khác đều có enum tương ứng — không cần nhánh xử lý riêng (custom filter) như
    `CUSTOMER`/`VENDOR` vì không có yêu cầu lọc đặc biệt nào cho 2 entity mới.
  - Frontend: bảng **List PO** (Screen1) gọi lại đúng hạ tầng generic đã có
    (`GetReferenceDataUseCase` / hook `useReferenceObjects` — đã dùng ở
    `ReferenceObjectAutocomplete.jsx`, `CountryCodesField.jsx`) với `referenceType = 15` để nạp
    danh sách PO thật, thay `DEMO_PO_LIST` cho cột **PO name** (map từ `name` trong
    `ComplDynReferenceResponseDto`). Cột **File name** không có nguồn dữ liệu tương ứng nên MUST
    tiếp tục hiển thị trống cho mỗi dòng; Action View/Delete trên mỗi dòng vẫn là no-op (Quyết định
    8). Hook `useReferenceObjects` đã có sẵn `loading`/`error`/danh sách rỗng → dùng trực tiếp để
    đáp ứng FR-017/SC-010 (trạng thái trống/lỗi) mà không cần viết lại state fetching.
  - `refType = 16` (`RSVNEutrSalesOrderPurchases`) chỉ đăng ký ở backend (`EntityMappings` +
    `MapDynamicsResponse`) — KHÔNG có hook/component frontend nào gọi tới trong phạm vi feature
    này (FR-022).
- **Rationale**: Người dùng yêu cầu rõ tích hợp theo đúng cơ chế `refType` của endpoint
  `POST /api/dynamics/reference` (giống `VendorsV3`), không phải tạo endpoint GET mới — khớp
  Nguyên tắc II (Reference-Pattern Reuse) và Nguyên tắc III (Reuse Existing Backend: endpoint
  reference dùng chung, hook `useReferenceObjects` ở frontend đã tồn tại và hoạt động đúng, chỉ cần
  mở rộng bảng ánh xạ thay vì viết lại hạ tầng gọi API).
- **Alternatives considered**: (a) Tạo 2 endpoint GET riêng theo mẫu `GET api/dynamics/vendors` —
  đây là phương án ban đầu của Update 4 nhưng bị **loại bỏ** sau phản hồi của người dùng, vì hệ
  thống đã có sẵn cơ chế `refType` dùng chung, tạo endpoint riêng sẽ trùng lặp logic phân trang/lọc
  đã có trong `GetDynRefePagedAsync`; (b) Viết hook fetch riêng cho List PO thay vì tái dùng
  `useReferenceObjects` — bị loại, vi phạm Nguyên tắc II khi đã có hook generic đúng hình dạng dữ
  liệu cần dùng (`{ id, code, name }`, có `loading`/`error`/phân trang).

## Quyết định 10 — Ô tìm kiếm PO gọi API server-side, tái dùng debounce pattern có sẵn (spec Update 5)

- **Decision**: Đổi ô tìm kiếm PO (đã thêm khi implement Update 4, `poSearch` state) từ lọc cục bộ
  trên `poList` đã tải sang gọi lại `fetchPoList(EUTR_PURCH_ORDER_REF_TYPE, query)` — **KHÔNG cần
  sửa backend**, vì lý do sau: `useReferenceObjects.fetchReferenceObjects` đã tự xây filter
  `[{ column: "Name", ... }, { column: "Code", ... }]` khi có `query`; ở backend,
  `ComplDynamicsService.BuildFilterString` đã nhóm filter theo `column.ToLower()` ("code"/"id" →
  dùng `mapping.CodeColumn`, "name" → dùng `mapping.NameColumn`) — với refType 15 đã đăng ký ở
  Update 4 (`CodeColumn = "PurchId"`, `NameColumn = "Name"`), 2 filter "Code"/"Name" generic này tự
  động ánh xạ đúng sang cột thật của `RSVNEutrPurchOrders` mà không cần thêm bất kỳ dòng code backend
  nào. Đây là lý do cơ chế `EntityMappings` (Quyết định 9) được thiết kế theo dạng
  `(Entity, CodeColumn, NameColumn)` ngay từ đầu.
  - Debounce 500ms bằng `lodash.debounce` (đã cài sẵn trong `package.json`, đã dùng ở
    `ReferenceObjectAutocomplete.jsx`) bọc quanh lệnh gọi `fetchPoList`, tạo qua `useMemo` để giữ
    cùng một instance debounce giữa các lần render — đúng mẫu `debouncedFetchReferenceObjects` của
    `ReferenceObjectAutocomplete.jsx`.
  - Bỏ biến cục bộ `filteredPoList`/`poSearchTerms` (lọc client-side, hỗ trợ đa từ khóa cách nhau
    bằng dấu phẩy) — danh sách hiển thị giờ là `poList` trả thẳng từ hook (server đã lọc đúng theo
    từ khóa hiện tại), đơn giản hoá đúng theo quyết định "không giữ tìm kiếm đa từ khóa" đã chốt ở
    spec Update 5.
  - Khi `poSearch` rỗng, gọi `fetchPoList(EUTR_PURCH_ORDER_REF_TYPE, '')` (tương đương lần tải mặc
    định ban đầu) để khôi phục danh sách không lọc (FR-023).
  - Trạng thái loading/error/rỗng của `useReferenceObjects` (đã dùng từ Update 4) tiếp tục áp dụng
    cho cả lượt tải mặc định lẫn lượt tìm kiếm — không cần thêm state loading/error riêng cho tìm
    kiếm.
- **Rationale**: Nguyên tắc III (Reuse Existing Backend) — endpoint reference + `BuildFilterString`
  đã có sẵn khả năng lọc theo Code/Name tổng quát cho MỌI refType đã đăng ký, không riêng gì
  `RSVNEutrPurchOrders`; tận dụng đúng thiết kế có sẵn thay vì thêm tham số/logic lọc mới ở backend.
  Nguyên tắc II — debounce theo đúng pattern `lodash.debounce` đã dùng ở
  `ReferenceObjectAutocomplete.jsx`, tránh mỗi phím gõ gọi 1 request.
- **Alternatives considered**: (a) Thêm endpoint/tham số lọc riêng ở backend cho PO — bị loại, thừa
  vì filter Code/Name generic đã hoạt động đúng nhờ `EntityMappings`; (b) Giữ lọc cục bộ như cũ,
  chỉ mở rộng số lượng item tải ban đầu (pageSize lớn hơn) — bị loại, không đáp ứng yêu cầu "lọc từ
  API" của spec (dữ liệu PO thật trên D365 có thể nhiều hơn một trang, lọc cục bộ sẽ bỏ sót kết
  quả); (c) Không debounce, gọi API mỗi phím gõ — bị loại, gây spam request không cần thiết, khác
  pattern đã thiết lập trong codebase.

## Quyết định 11 — Backend: `EutrUploadService` mới, KHÔNG tái sử dụng `ComplUploadService` (spec Update 6)

- **Decision**: Tạo mới `IEutrUploadService`/`EutrUploadService`
  (`ComplianceSys.Application/Interfaces/Services/IEutrUploadService.cs` +
  `ComplianceSys.Application/Services/EutrUploadService.cs`), đăng ký DI riêng
  (`services.AddScoped<IEutrUploadService, EutrUploadService>();` cạnh dòng `IComplUploadService`
  hiện có trong `ComplianceSys.Application/DependencyInjection.cs`). Service này **không gọi**
  `IComplUploadService`/`ComplUploadService` — chỉ dùng chung `ISharepointService` (interface có
  sẵn từ package `Res.Shared.ExternalServices`) để thao tác SharePoint.
- **Rationale**: Yêu cầu người dùng nêu rõ "không sử dụng lại `_complUploadService` mà tạo mới
  `_eutrUploadService`". Về mặt kỹ thuật, `ComplUploadService.UploadMultipleToSharePointAndSaveDataAsync`
  ghi vào bảng `compl_sharepoint_file` (qua `IComplSharepointFileService`) — sai bảng đích cho
  feature này (cần ghi `eutr_documents` với `FileId`, `ValidFrom`, `ValidTo` khác hẳn cấu trúc
  `ComplSharepointFile`) — nên tách service là lựa chọn đúng cả về nghiệp vụ lẫn kỹ thuật, không chỉ
  để làm theo yêu cầu.
- **Ghi chú quan trọng phát hiện khi research**: `EutrDocumentsRequestDto` (dùng bởi
  `IEutrDocumentsService.AddAsync` của controller `api/eutr-documents` hiện có) **không có field
  `FileId`** và `EutrMappingProfile` chỉ map `{ Name, ValidFrom, ValidTo }` — nên **không thể** tái
  sử dụng `IEutrDocumentsService.AddAsync(dto, ...)` để tạo document có `FileId` mà không sửa DTO đó
  (sẽ ảnh hưởng ngược lại luồng Add/Edit hiện có, ngoài phạm vi mong muốn). `EutrUploadService` vì
  vậy **tự thao tác trực tiếp** `IRepository<EutrDocuments, long>` + `IUnitOfWork` (bơm thẳng vào
  constructor, không qua `IEutrDocumentsService`) để set đủ `Name`, `FileId`, `ValidFrom`, `ValidTo`,
  `CreatedBy`, `CreatedDate` — đúng theo cách `ComplUploadService` tự thao tác
  `IComplSharepointFileService.AddAsync(complFileEntity, ...)` với DTO = chính entity (không qua
  lớp CRUD DTO hẹp hơn). Đây là cách nhất quán nhất với pattern đã có trong codebase cho "service
  upload ghi thẳng entity có field ngoài phạm vi DTO CRUD chuẩn".
- **Alternatives considered**: (a) Thêm `FileId` vào `EutrDocumentsRequestDto` rồi gọi lại
  `IEutrDocumentsService.AddAsync` — bị loại vì mở rộng phạm vi DTO của luồng Add/Edit thủ công chỉ
  để phục vụ luồng upload khác hẳn, và có nguy cơ cho phép người dùng tự truyền `FileId` tuỳ ý qua
  form Add/Edit (không đúng ranh giới nghiệp vụ); (b) Gọi lại `_complUploadService` rồi tự thêm bước
  ghi `eutr_documents` — bị loại, trái yêu cầu rõ ràng "không dùng lại `_complUploadService`" và vẫn
  phải ghi thêm bảng `compl_sharepoint_file` không cần thiết cho feature này.

## Quyết định 12 — Endpoint mới trong `SharePointController` hiện có, DTO/response riêng (spec Update 6)

- **Decision**: Thêm action `[HttpPost("eutr-upload-multi")]` (`Consumes("multipart/form-data")`)
  vào **cùng** `SharePointController.cs` hiện có (route gốc `api/sharepoint`) — không tạo controller
  riêng. Request DTO mới `EutrMultiUploadFileRequest` (`ComplianceSys.Application/Dtos/Request/`):
  `{ List<IFormFile> Files, string PoCode }` — khác `MultiUploadFileRequest` ở chỗ nhận `PoCode`
  thay vì `FolderPath` (thư mục được `EutrUploadService` tự suy ra từ `PoCode` + cấu hình, front-end
  không tự truyền đường dẫn SharePoint). Response DTO mới `EutrUploadFileResultDto`
  (`ComplianceSys.Application/Dtos/Response/`): `{ FileName, Success, ErrorMessage?, DocumentId?,
  FileId? }` — controller trả về `ApiResponse<List<EutrUploadFileResultDto>>` để phản ánh đúng kết
  quả từng file (một số thành công, một số thất bại — xem Quyết định 13).
- **Rationale**: Người dùng tham chiếu trực tiếp `SharePointController.cs` +
  `[HttpPost("upload-multi")]` làm mẫu — giữ đúng vị trí controller theo yêu cầu (Nguyên tắc II).
  Endpoint không tái dùng `MultiUploadFileRequest`/response `List<string>` hiện có của
  `upload-multi` vì hình dạng dữ liệu khác (cần `PoCode` đầu vào, cần trả trạng thái per-file ở đầu
  ra để front-end hiển thị đúng file nào lỗi/thành công theo FR-030).
- **Alternatives considered**: (a) Tái dùng `MultiUploadFileRequest`, truyền `FolderPath` đã tính
  sẵn từ front-end — bị loại, để front-end tự quyết định đường dẫn SharePoint là rò rỉ chi tiết hạ
  tầng ra client và không khớp yêu cầu "PO dùng để chọn thư mục" (thư mục PHẢI do backend suy ra);
  (b) Trả về `List<string>` (chỉ FileId) như `upload-multi` — bị loại, không đủ thông tin để hiển
  thị lỗi per-file khi một phần batch thất bại (FR-030).

## Quyết định 13 — Suy ra/tạo thư mục SharePoint theo PO + validate file (spec Update 6, FR-026, FR-028)

- **Decision**: Trong `EutrUploadService`:
  1. Đọc `basePath = _configuration["SharePointEutrPath"]` (throw `InvalidOperationException` nếu
     thiếu cấu hình, cùng mẫu `SharePointCompPath` trong `SharePointController.UploadToSharePointAndSaveData`).
  2. Gọi `_sharepointService.GetFolders(basePath)` để lấy danh sách thư mục con hiện có; nếu đã tồn
     tại thư mục tên đúng `request.PoCode`, dùng lại (`targetFolder = $"{basePath}/{PoCode}"`);
     nếu chưa có, gọi `_sharepointService.CreateFolder(targetFolder)` trước khi upload. **Không có
     method "ensure-folder" dựng sẵn** trong `ISharepointService` (package
     `Res.Shared.ExternalServices`, xác nhận qua khảo sát toàn bộ call site hiện có) — đây là logic
     **mới**, viết trong `EutrUploadService`, không sửa package ngoài.
  3. Với mỗi file trong `request.Files`: validate đuôi file (`.pdf, .doc, .docx, .xls, .xlsx, .jpg,
     .jpeg, .png`, so sánh không phân biệt hoa/thường) và kích thước (`<= 10 * 1024 * 1024` byte —
     hằng số cục bộ trong `EutrUploadService`, không có hằng số dùng chung nào cho việc này trong
     codebase hiện tại nên đây là hằng số **mới**, tối giản, không tạo class dùng chung vì chưa có
     nơi thứ 2 cần). File không hợp lệ bị loại, thêm vào kết quả trả về với `Success = false` và
     `ErrorMessage` mô tả lý do — KHÔNG chặn các file hợp lệ khác trong cùng request (FR-026).
  4. Với file hợp lệ: sinh tên file duy nhất trên SharePoint theo đúng helper
     `GetUniqueFileName` mà `ComplUploadService` đã dùng (`{tên không đuôi}_{guid 6 ký tự}{đuôi}`) để
     tránh ghi đè file trùng tên trên cùng thư mục PO — nhưng **lưu `Name` trong `eutr_documents`
     là tên file gốc người dùng chọn** (`IFormFile.FileName`), không phải tên đã làm duy nhất, đúng
     yêu cầu "File name = tên file gốc".
- **Rationale**: Không có sẵn kết hợp "tìm thư mục cũ hoặc tạo mới" trong hạ tầng hiện có — phải
  viết mới, nhưng tận dụng đúng 2 method nguyên tử đã có (`GetFolders`, `CreateFolder`) thay vì gọi
  Graph API trực tiếp (Nguyên tắc III — dùng lại interface `ISharepointService` sẵn có). Việc dùng
  lại đúng helper tạo tên duy nhất của `ComplUploadService` (dù copy 1 hàm nhỏ, không refactor thành
  shared util vì đây là lần dùng thứ 2 duy nhất — YAGNI) tránh phát minh lại logic tương tự.
- **Alternatives considered**: (a) Không tạo thư mục, upload thẳng vào `basePath` chung cho mọi PO —
  bị loại, trái yêu cầu "PO dùng để chọn thư mục cũ hoặc tạo mới trên SharePoint" đã xác nhận ở
  clarify; (b) Luôn gọi `CreateFolder` mà không kiểm tra tồn tại trước — rủi ro phụ thuộc hành vi
  không rõ ràng của Graph API khi tạo trùng tên thư mục (có thể lỗi hoặc tạo thư mục trùng tên có
  hậu tố) — chọn kiểm tra tồn tại trước để hành vi rõ ràng, chủ động; (c) Không giới hạn định dạng/
  kích thước file — bị loại, trái quyết định tái áp dụng ràng buộc cũ đã chốt ở clarify Update 6.

## Quyết định 14 — Ghi `eutr_documents` per-file, không rollback toàn batch khi một file lỗi (spec Update 6, FR-029/FR-030)

- **Decision**: Với mỗi file hợp lệ đã upload thành công lên SharePoint, `EutrUploadService` mở một
  transaction **riêng** (`_unitOfWork.BeginTransactionAsync` → `_repository.AddAsync(entity, ct)` →
  `_unitOfWork.CommitAsync()`) để ghi 1 dòng `eutr_documents` (`Name` = tên file gốc, `FileId` = id
  SharePoint trả về, `ValidFrom` = `DateTime.Today`, `ValidTo` = `new DateTime(9999, 12, 31)`,
  `CreatedBy` = email người dùng hiện tại, `CreatedDate` = `DateTime.UtcNow`). Nếu upload hoặc ghi
  DB của một file thất bại (`try/catch` quanh từng file), hệ thống rollback transaction **của riêng
  file đó** (nếu đã mở), ghi nhận lỗi vào `EutrUploadFileResultDto` tương ứng, và **tiếp tục vòng
  lặp** sang file kế tiếp — không dừng toàn bộ batch, không rollback các file đã commit thành công
  trước đó.
- **Rationale**: Spec FR-030 yêu cầu rõ "best-effort" — file thành công vẫn được lưu dù file khác
  trong cùng lượt thất bại. Transaction theo từng file (thay vì 1 transaction bao toàn bộ batch) là
  cách duy nhất đạt đúng ngữ nghĩa này với `IUnitOfWork` hiện có (không hỗ trợ savepoint từng phần
  trong 1 transaction).
- **Alternatives considered**: (a) Một transaction bao toàn bộ batch, rollback tất cả nếu bất kỳ
  file nào lỗi — bị loại, trái FR-030 (all-or-nothing không phải hành vi đã chốt); (b) Không dùng
  transaction, chèn thẳng qua repository không qua `IUnitOfWork` — bị loại, không nhất quán với
  pattern `BaseService.AddAsync` đã dùng cho các entity khác (transaction là convention chuẩn của
  tầng ghi dữ liệu trong codebase này).

## Quyết định 15 — Frontend: chọn PO đơn (không checkbox), nút Upload thay khu kéo-thả (spec Update 6)

- **Decision**: Trong `EutrDocumentsAdd.jsx` (Screen1), thêm state `selectedPoCode` (giá trị `code`
  của dòng PO đang chọn trong bảng List PO, lấy từ `ComplDynReferenceResponseDto.code` — tức
  `PurchId`). Bảng List PO (MUI `DataGrid`) dùng `onRowClick` để set `selectedPoCode` (không thêm
  cột checkbox — click một dòng bất kỳ sẽ thay thế lựa chọn trước đó, hành vi single-select kiểu
  radio); tô nổi bật dòng đang chọn qua `getRowClassName`/`sx` dựa trên so sánh `row.id ===
  selectedPoCode`. Thay khu vực "Drag and drop files to upload" (Screen1) bằng một `<Button>` "Upload"
  (`disabled={!selectedPoCode}`) kèm `<input type="file" multiple hidden>` được trigger qua `ref`
  khi nhấn nút. Khi người dùng chọn file: lọc trước ở client theo cùng danh sách đuôi/kích thước
  (FR-026) để phản hồi nhanh, rồi gọi use case upload (xem dưới) với các file còn lại (kể cả khi
  không còn file hợp lệ nào, vẫn hiển thị thông báo lỗi liệt kê file bị loại — không gọi API nếu
  danh sách hợp lệ rỗng, theo Edge Case đã thêm ở spec).
- **Tầng frontend tái sử dụng**: Phát hiện repo đã có sẵn đúng hạ tầng cho luồng "upload nhiều file
  lên SharePoint" ở tính năng khác — `ISharePointRepository`/`RestSharePointRepository`
  (`domain/interfaces/ISharePointRepository.js`,
  `infrastructure/repositories/RestSharePointRepository.js`) đã có method `uploadFileMulti(files,
  folderPath)` gọi `POST /sharepoint/upload-multi` bằng `FormData` + header
  `multipart/form-data`, và use case `UploadToSharePointUseCase`
  (`application/usecases/sharepoint/UploadToSharePointUseCase.js`) với `executeMulti(files,
  folderPath)`. **Thêm method mới cạnh các method này** (không sửa method cũ):
  `uploadEutrFilesMulti(files, poCode)` trên `ISharePointRepository`/`RestSharePointRepository` (gọi
  `POST /sharepoint/eutr-upload-multi`, field `poCode` thay vì `folderPath`) và
  `executeEutrMulti(files, poCode)` trên `UploadToSharePointUseCase` — đúng Nguyên tắc II (mở rộng
  repository/use case đã có theo đúng hình dạng, thay vì tạo domain/infrastructure/application mới
  hoàn toàn cho một hành động vẫn thuộc nhóm "thao tác SharePoint").
- **Rationale**: Yêu cầu "PO sẽ dựa vào User click chọn ở list PO" chỉ rõ tương tác click-chọn đơn
  giản, không cần checkbox multi-select (List PO hiện tại còn không có cột checkbox nào). Tái dùng
  `ISharePointRepository`/`UploadToSharePointUseCase` hiện có tránh tạo thêm 1 bộ
  domain/infrastructure/application riêng chỉ để gọi 1 endpoint multipart tương tự endpoint đã có
  use case xử lý.
- **Alternatives considered**: (a) Checkbox chọn nhiều PO, upload hàng loạt cho nhiều PO cùng lúc —
  bị loại, vượt phạm vi yêu cầu ("User click chọn" số ít) và làm phức tạp response per-file (phải
  gắn thêm PO nào cho file nào); (b) Tạo hẳn `IEutrUploadRepository`/`RestEutrUploadRepository`/
  `EutrUploadUseCase` riêng biệt — bị loại, trùng lặp không cần thiết với
  `ISharePointRepository`/`UploadToSharePointUseCase` đã tồn tại đúng vai trò "thao tác SharePoint
  từ frontend".

## Quyết định 16 — Bảng `eutr_references` cần entity mới + migration thêm cột `StepId` (spec Update 7)

- **Decision**: `eutr_references` (Id, RefId, DocumentId, RefType, RefValue + audit) hiện **chưa có
  entity backend nào** (khảo sát toàn bộ `ComplianceSys.Domain/Entities/` xác nhận không có file
  nào map bảng này) — tạo mới `ComplianceSys.Domain/Entities/EutrReferences.cs`
  (`[Table("eutr_references")]`, kế thừa `BaseEntity`): `Id (long)`, `RefId (long?)`, `DocumentId
  (long?)`, `StepId (long?, cột MỚI)`, `RefType (byte?)`, `RefValue (string?)`. KHÔNG tạo repository
  riêng — dùng thẳng `IRepository<EutrReferences, long>` generic (đã đăng ký open-generic sẵn,
  đúng mẫu `EutrDocuments` ở Quyết định 2/11) vì chỉ cần `AddAsync` đơn giản, không cần JOIN/lọc
  tùy biến nào trên bảng này. Thêm migration
  `ComplianceSys.Infrastructure/Sqls/Migration/10_add_stepid_to_eutr_references.sql`:
  ```sql
  ALTER TABLE eutr_references ADD COLUMN StepId BIGINT UNSIGNED NULL AFTER RefId;
  ALTER TABLE eutr_references ADD CONSTRAINT eutr_references_stepid_foreign
    FOREIGN KEY (StepId) REFERENCES eutr_steps(Id);
  ```
  Đồng thời cập nhật `docs/design/eutr/eutr_db.sql` và
  `ComplianceSys.Infrastructure/Sqls/Tables/eutr_db.sql` (DDL build) để khớp cột mới.
- **Rationale**: Người dùng đã chốt rõ (sau 2 lần sửa spec Update 7): **KHÔNG ghi vào cột `RefId`
  hiện có** (cột này đang có FK trỏ `eutr_template_details(Id)`, ghi `StepId` vào đó sẽ vi phạm ràng
  buộc) — thay vào đó dùng cột `StepId` **mới**, tách biệt hoàn toàn, có FK riêng trỏ đúng
  `eutr_steps(Id)` để đảm bảo toàn vẹn dữ liệu (khác với cách tiếp cận ban đầu định "nới lỏng FK của
  RefId", nay không cần đụng tới ràng buộc cũ nào). Dùng `IRepository<,>` generic thay vì repository
  riêng vì thao tác duy nhất cần là insert — đúng tinh thần YAGNI đã áp dụng ở Quyết định 2/11.
- **Alternatives considered**: (a) Ghi `StepId` vào cột `RefId` sẵn có, kèm migration nới lỏng/xóa
  FK `eutr_references_refid_foreign` — đây là phương án ban đầu của Update 7 nhưng bị **loại bỏ**
  sau phản hồi trực tiếp của người dùng; (b) Tạo repository riêng
  `IEutrReferencesRepository`/`EutrReferencesRepository` — bị loại, không cần thiết vì không có
  truy vấn tùy biến nào trên bảng này trong phạm vi feature (chỉ ghi, không đọc/lọc).

## Quyết định 17 — Tra cứu Prefix: mở rộng `IEutrMastersRepository` có sẵn, KHÔNG tạo repository mới (spec Update 7, FR-032)

- **Decision**: Thêm method mới `Task<List<EutrMastersDocument>> GetMatchingPrefixesAsync(string
  fileName, CancellationToken ct)` vào `IEutrMastersRepository`/`EutrMastersRepository` (đã tồn tại
  sẵn cho feature `002-eutr-masters`, đã đăng ký DI ở `ComplianceSys.Infrastructure/
  DependencyInjection.cs`: `services.AddScoped<IEutrMastersRepository, EutrMastersRepository>();`).
  Query dùng SQL "đảo chiều LIKE" (giá trị cột `Prefix` làm pattern, `fileName` làm chuỗi cần khớp):
  ```sql
  SELECT Id, StepId, Prefix FROM eutr_master_documents
  WHERE Prefix IS NOT NULL AND Prefix <> ''
    AND @fileName LIKE CONCAT(
      REPLACE(REPLACE(REPLACE(Prefix, '\\', '\\\\'), '%', '\\%'), '_', '\\_'), '%');
  ```
  (escape `\`, `%`, `_` trong giá trị `Prefix` trước khi dùng làm pattern LIKE, vì `Prefix` là chuỗi
  tự do người dùng nhập ở `002-eutr-masters`, có thể vô tình chứa ký tự đại diện LIKE). `EutrUploadService`
  (Application layer) nhận thêm `IEutrMastersRepository` qua constructor injection (interface đã có
  sẵn trong `ComplianceSys.Application.Interfaces.Repositories`, đúng layering — Application phụ
  thuộc abstraction, Infrastructure cung cấp implementation, đã wire sẵn) để gọi method mới này,
  KHÔNG đọc trực tiếp DB/SQL trong `EutrUploadService`.
- **Rationale**: `IEutrMastersRepository` đã là abstraction đúng vai trò "truy cập
  `eutr_master_documents`" cho toàn hệ thống (Nguyên tắc II — mở rộng interface có sẵn thay vì tạo
  mới); tránh vi phạm layering bằng cách không viết SQL thô trong `EutrUploadService`. Việc so khớp
  "prefix của DB là tiền tố của tên file" (ngược với LIKE tìm kiếm thông thường "tên file chứa từ
  khóa") không có sẵn trong bất kỳ repository/generic filter nào của codebase — bắt buộc phải viết
  method mới, nhưng đặt đúng chỗ (`EutrMastersRepository`, nơi đã sở hữu quyền truy cập bảng này).
- **Alternatives considered**: (a) Gọi `_repository.GetAllAsync()` (generic `IRepository<EutrMastersDocument,long>`)
  rồi lọc bằng C# (`fileName.StartsWith(m.Prefix, StringComparison.OrdinalIgnoreCase)`) — cân nhắc
  vì đơn giản hơn (không cần SQL "đảo chiều"), nhưng tải toàn bộ bảng `eutr_master_documents` về mỗi
  lượt validate file có thể không tối ưu khi bảng lớn dần; tuy nhiên bảng này về bản chất là master
  data nhỏ (tương tự `eutr_steps`) nên **được chấp nhận như phương án dự phòng** nếu SQL "đảo
  chiều LIKE" gặp vấn đề tương thích MySQL — quyết định cuối cùng vẫn ưu tiên SQL filter phía DB để
  nhất quán với các repository khác trong codebase (đều lọc ở SQL, không lọc ở tầng ứng dụng); (b)
  Tạo repository/interface mới riêng cho việc tra cứu này — bị loại, trùng lặp với
  `IEutrMastersRepository` đã tồn tại đúng vai trò.

## Quyết định 18 — Một transaction cho cả `eutr_documents` + toàn bộ `eutr_references` của một file (spec Update 7, FR-033)

- **Decision**: Mở rộng transaction per-file đã có ở Quyết định 14 (Update 6) để bao gồm **cả** bước
  ghi `eutr_documents` **và** N bước ghi `eutr_references` (N = số `StepId` phân biệt khớp prefix)
  trong **cùng một transaction** (`BeginTransactionAsync` → `AddAsync` document → `AddAsync` từng
  reference → `CommitAsync`). Nếu bất kỳ bước nào trong nhóm này thất bại (bao gồm một trong các
  lượt ghi `eutr_references`), toàn bộ transaction của **file đó** rollback — `eutr_documents` của
  file đó KHÔNG còn tồn tại nữa (không để lại document mồ côi không có `eutr_references`), file được
  báo thất bại trong kết quả trả về. File đã upload lên SharePoint trước đó (nằm ngoài DB
  transaction) vẫn giữ nguyên trên SharePoint — chấp nhận được, cùng rủi ro đã có từ Update 6 khi
  ghi `eutr_documents` thất bại sau khi upload SharePoint thành công.
- **Rationale**: Spec (FR-033) chỉ yêu cầu quan sát được "file báo thất bại nếu bước ghi
  `eutr_references` lỗi" — không bắt buộc phải giữ lại document mồ côi. Gộp thành 1 transaction cho
  cả file là lựa chọn kỹ thuật sạch hơn (tránh trạng thái dữ liệu không nhất quán: document tồn tại
  trong `eutr_documents`/hiển thị ở danh sách chung nhưng không có `eutr_references` nào, dù kết quả
  API báo "thất bại") — vẫn thỏa mãn đầy đủ hành vi quan sát được mà spec yêu cầu (file thất bại
  không tạo ra dữ liệu "thành công" nào), đơn giản hóa việc reasoning về trạng thái DB.
- **Alternatives considered**: (a) Giữ transaction `eutr_documents` tách biệt (đúng y hệt Update 6),
  rồi mở transaction/insert riêng cho từng `eutr_references` sau đó — bị loại vì có thể để lại
  document "mồ côi" (tồn tại trong danh sách EUTR documents nhưng API báo file đó thất bại) — gây
  khó hiểu khi vận hành/debug, dù về mặt câu chữ vẫn khớp FR-033 (báo thất bại); (b) Transaction
  chung cho TOÀN BỘ request (mọi file trong lượt upload) — bị loại, vi phạm ngữ nghĩa best-effort
  per-file đã chốt từ Update 6/FR-030 (một file lỗi làm rollback cả các file khác đã thành công).

## Quyết định 19 — Frontend: thiết kế lại khu Upload theo `upload.png`, thêm kéo-thả thật (spec Update 7, FR-031)

- **Decision**: Trong `EutrDocumentsAdd.jsx` (đã có state `uploading`, `fileInputRef`, handler
  `handleUploadFilesSelected` từ Update 6), tách phần xử lý danh sách file thô
  (`FileList`/`File[]`) ra khỏi nguồn sự kiện (input `onChange` hay `onDrop`) — cả hai đường đều gọi
  chung một hàm xử lý duy nhất (validate + gọi `executeEutrMulti`), tránh trùng lặp logic giữa
  click-chọn và kéo-thả. Giao diện đổi từ nút "Upload" đơn giản (Update 6) sang một "card" theo mẫu
  `upload.png`: `Typography` "Upload File" (đậm), `Box` viền nét đứt lớn (`border: 2px dashed`) chứa
  `CloudUploadIcon` (từ `@mui/icons-material`, chưa dùng ở đâu khác trong repo — icon chuẩn MUI, không
  cần thư viện mới) + `Typography` "Drop file here or click to browse" (chính hộp này vừa là nút
  click vừa là vùng thả file: `onClick` mở `fileInputRef`, `onDragOver`/`onDrop` xử lý file thả vào
  bằng `e.dataTransfer.files`), một dòng phụ liệt kê định dạng/kích thước **thật** (không phải số
  liệu trong ảnh mẫu), và một hàng `Chip` nhỏ bên dưới (`"PDF"`, `"DOC/DOCX"`, `"XLS/XLSX"`,
  `"JPG/PNG"`, `"Max 10MB"` — mỗi chip `size="small"` `variant="outlined"`). Toàn bộ card bị làm mờ
  (`opacity`, `pointerEvents: 'none'`) khi chưa chọn PO, đúng hành vi disabled đã có ở Update 6
  (FR-024).
- **Rationale**: Yêu cầu người dùng đưa ảnh cụ thể (`upload.png`) làm chuẩn giao diện — clone đúng
  bố cục thị giác (Nguyên tắc II, giống cách các Update trước bám sát `eutr_documents_overview.md`).
  `CloudUploadIcon` là icon chuẩn có sẵn trong `@mui/icons-material` (dependency đã cài) — không cần
  thêm gói mới. Việc gộp logic xử lý file (click và kéo-thả dùng chung 1 hàm) tránh lặp code, đúng
  tinh thần giữ nguyên pipeline validate (định dạng/kích thước ở client, prefix ở server) đã xây từ
  Update 6.
- **Alternatives considered**: (a) Dùng thư viện `react-dropzone` cho phần kéo-thả — bị loại, thêm
  dependency mới không cần thiết khi HTML5 native `onDragOver`/`onDrop` (đã dùng ở dạng no-op từ
  Update 3, nay chỉ cần đọc `e.dataTransfer.files` thay vì bỏ qua) là đủ, đúng Nguyên tắc II; (b)
  Giữ 2 hàm xử lý riêng cho click và kéo-thả — bị loại, trùng lặp logic validate không cần thiết.

## Quyết định 20 — Backend: tạo `IEutrReferencesRepository` mới, JOIN `eutr_references`+`eutr_steps` để nạp Step name/Type cho danh sách (spec Update 8, FR-034/FR-035)

- **Decision**: Tạo mới `ComplianceSys.Application/Interfaces/Repositories/IEutrReferencesRepository.cs`
  + `ComplianceSys.Infrastructure/Repositories/EutrReferencesRepository.cs`
  (`DapperRepository<EutrReferences, long>`, clone đúng mẫu `EutrMastersRepository` ở Quyết định
  17 — chỉ nhận `IUnitOfWork` qua constructor). Thêm method
  `GetStepInfoByDocumentIdsAsync(IEnumerable<long> documentIds, ct)`:
  ```sql
  SELECT r.DocumentId, s.Name AS StepName, r.RefType
  FROM eutr_references r
  LEFT JOIN eutr_steps s ON s.Id = r.StepId
  WHERE r.DocumentId IN @DocumentIds;
  ```
  `EutrDocumentsService.GetPagedAsync` (sau khi có trang `EutrDocuments` từ
  `IRepository<EutrDocuments,long>.GetPagedAsync`, Quyết định 2) gọi thêm method trên với danh sách
  `Id` của trang đó, rồi **group theo `DocumentId`** trong bộ nhớ (`GroupBy` → `Dictionary<long,
  (List<string> StepNames, byte? RefType)>`) để gán `dto.StepNames`/`dto.RefType` cho từng
  `EutrDocumentsResponseDto` — clone chính xác mẫu `ComplCountryGroupService.AttachMembersAsync`
  (`ComplCountryGroupMemberRepository.GetByGroupIdsAsync` + `GroupBy`/`ToDictionary` trong service).
  Document không có dòng nào khớp → `StepNames = []`, `RefType = null` (DataGrid/renderCell frontend
  tự hiển thị trống).
- **Rationale**: Đây là truy vấn tra cứu **read-only đầu tiên** trên `eutr_references` (Update 7 chỉ
  ghi qua `IRepository<,>` generic, Quyết định 16) — generic repository không hỗ trợ JOIN hay `WHERE
  IN` không phân trang (Technical Context đã xác nhận `IRepository<TEntity,TKey>` chỉ có 8 method cơ
  bản), nên bắt buộc phải có repository tuỳ biến, đúng như cách `IEutrMastersRepository` đã được mở
  rộng ở Quyết định 17 khi phát sinh nhu cầu tương tự. `ComplCountryGroupService.AttachMembersAsync`
  là mẫu "1 query cha (phân trang) + 1 query con `WHERE IN (ids)` + gộp trong bộ nhớ" **đã có sẵn và
  đang hoạt động đúng** trong codebase cho đúng hình dạng bài toán này ("nhiều con cho một cha") —
  tái dùng thẳng thay vì N+1 query hoặc query JOIN phức tạp trong generic repository.
- **Alternatives considered**: (a) Gọi `GetByIdAsync`/query riêng cho từng document trong trang (N+1)
  — bị loại, không hiệu quả với trang 10-50 dòng; (b) Nhồi thẳng JOIN vào
  `IRepository<EutrDocuments,long>.GetPagedAsync` (sửa generic repository) — bị loại, phá vỡ tính
  tổng quát của repository generic dùng chung cho mọi entity khác trong hệ thống; (c) Trả về `byte[]
  RefTypes` (nhiều RefType) thay vì 1 giá trị — bị loại, business rule (FR-033/Update 7) đảm bảo mọi
  bản ghi cùng `DocumentId` luôn cùng `RefType`, không cần mô hình hoá trường hợp nhiều giá trị cho
  Type.

## Quyết định 21 — Backend: endpoint mới `POST /api/eutr-documents/list-po-references` cho File name/Step name ở List PO (spec Update 8, FR-037/FR-038)

- **Decision**: Thêm method thứ 2 vào `EutrReferencesRepository`:
  `GetDocumentsByPoCodesAsync(IEnumerable<string> poCodes, ct)`:
  ```sql
  SELECT r.RefValue AS PoCode, r.DocumentId, d.Name AS FileName, s.Name AS StepName
  FROM eutr_references r
  LEFT JOIN eutr_documents d ON d.Id = r.DocumentId
  LEFT JOIN eutr_steps s ON s.Id = r.StepId
  WHERE r.RefType = 0 AND r.RefValue IN @PoCodes;
  ```
  Thêm action mới **trong `EutrDocumentsController.cs` hiện có** (route `api/eutr-documents`, KHÔNG
  phải `DynController`/`SharePointController`): `[HttpPost("list-po-references")]`, nhận
  `EutrDocumentsListPoReferencesRequestDto { List<string> PoCodes }`, trả về
  `ApiResponse<List<EutrDocumentsPoReferenceDto>>` (`{ poCode, documents: [{ documentId, fileName,
  stepNames }] }` — group theo `PoCode` rồi theo `DocumentId`, giống cách nhóm ở Quyết định 20).
  Dùng chung policy `EutrDocuments.ReadAll` đã có (đọc dữ liệu, không sửa) — không thêm policy mới.
- **Rationale**: PO list (cột PO name) đến từ D365 qua `POST /api/dynamics/reference` (Quyết định
  9) — hoàn toàn tách biệt hạ tầng với `eutr_references`/`eutr_documents`/`eutr_steps` (dữ liệu nội
  bộ MySQL). Không thể gộp 2 nguồn này vào 1 lời gọi API. Đặt action mới trong
  `EutrDocumentsController` (không phải `DynController` hay `SharePointController`) vì dữ liệu truy
  vấn (File name/Step name của document) thuộc đúng domain "eutr-documents" (Nguyên tắc I — ranh
  giới layer/domain), tái dùng route gốc đã có `api/eutr-documents` (Nguyên tắc III) thay vì tạo
  controller mới.
- **Alternatives considered**: (a) Trả về toàn bộ `eutr_references` (`RefType=0`) không lọc theo
  `poCodes`, để frontend tự lọc cục bộ — bị loại, tải dư dữ liệu không cần thiết và có thể phình to
  theo thời gian; (b) Nhúng `fileNames`/`stepNames` thẳng vào response của
  `POST /api/dynamics/reference` (refType=15) — bị loại, đó là endpoint D365 dùng chung cho nhiều
  entity khác (`VendorsV3`, `RSVNCustTableEntities`, ...), không nên nhúng logic đọc riêng của
  `eutr_references` vào; (c) Đặt action trong `SharePointController` (cạnh `eutr-upload-multi`) vì
  cùng liên quan tới PO/document đã upload — bị loại, đây là truy vấn đọc dữ liệu nội bộ, không liên
  quan gì tới SharePoint I/O, đặt sai domain sẽ gây nhầm lẫn khi review/maintain.

## Quyết định 22 — Frontend: chỉ tra cứu File name/Step name cho PO đang được chọn, không cho toàn trang (spec Update 8, FR-037/FR-038)

- **Decision**: Trong `EutrDocumentsAdd.jsx`, thêm `useEffect` theo dõi `selectedPoId` — khi đổi
  (và khác `null`), gọi use case mới `GetEutrDocumentsPoReferencesUseCase.execute([selectedPo.code])`
  và lưu kết quả (`documents: [{ documentId, fileName, stepNames }]`) vào state cục bộ mới (ví dụ
  `poReferenceDocuments`). Bảng chi tiết (Grid size=5, hiện chỉ render 1 row tĩnh khi có `selectedPo`
  — xem code hiện tại) đổi sang `.map()` qua `poReferenceDocuments` thành nhiều `TableRow` (File name
  = `doc.fileName`, Step name = `<MultiValueChips values={doc.stepNames} />`), hiển thị "No data" khi
  rỗng.
- **Rationale**: Cấu trúc UI hiện tại (từ Update 6, FR-024) chỉ cho chọn **đúng một** PO tại một thời
  điểm và bảng chi tiết chỉ render cho PO đó — nên chỉ cần 1 lời gọi API mỗi lần đổi lựa chọn, không
  cần tải trước File name/Step name cho mọi PO đang hiển thị trên trang (hầu hết sẽ không được chọn
  tới). Giữ đúng ranh giới UI đã chốt, tránh N lời gọi API không cần thiết mỗi khi trang PO list tải
  lại.
- **Alternatives considered**: (a) Gọi 1 lần cho toàn bộ `poList` hiển thị (mọi PO trên trang hiện
  tại) ngay khi `poList` đổi — bị loại, tăng tải API không cần thiết cho các PO người dùng không
  chọn tới, đặc biệt khi debounce tìm kiếm (Update 5) đổi `poList` liên tục; (b) Tải toàn bộ mapping
  PO → document một lần khi mở trang Add (không phân trang) — bị loại, có thể phình to không kiểm
  soát khi số PO/document tăng theo thời gian.

## Quyết định 23 — Frontend: tạo component dùng chung `MultiValueChips` (chip + "+N more" + tooltip) (spec Update 8)

- **Decision**: Tạo mới `compliance-client/src/presentation/components/common/MultiValueChips.jsx`
  (`props: { values: string[], previewLimit = 2 }`) — clone đúng logic hiện đang **inline** trong
  `useCountryGroupColumns.jsx` (cột "Country Codes": `Chip` cho `previewLimit` giá trị đầu +
  `Tooltip`/`Chip "+N more"` cho phần còn lại). Dùng component này ở 2 chỗ **mới** của feature này:
  cột "Step name" trong `useEutrDocumentsColumns.jsx` (danh sách EUTR documents) và cột "Step name"
  trong bảng chi tiết List PO của `EutrDocumentsAdd.jsx`. **KHÔNG sửa** `useCountryGroupColumns.jsx`
  để dùng lại component này — giữ nguyên file đó, tránh mở rộng phạm vi thay đổi ra ngoài feature
  `004-eutr-documents`.
- **Rationale**: Component được dùng ngay **2 lần** trong phạm vi chính Update 8 này (không phải suy
  đoán nhu cầu tương lai — YAGNI vẫn được tôn trọng vì nhu cầu dùng lại là hiện tại, không phải giả
  định), nên trích xuất thành 1 component dùng chung hợp lý hơn là copy-paste JSX chip/tooltip 2 lần
  trong cùng 1 PR.
- **Alternatives considered**: (a) Copy-paste logic chip/tooltip riêng ở mỗi nơi — bị loại, trùng
  lặp không cần thiết trong cùng phạm vi thay đổi; (b) Sửa luôn `useCountryGroupColumns.jsx` để dùng
  `MultiValueChips` — bị loại (phạm vi), là một cải tiến hợp lý nhưng thuộc feature `country-groups`,
  không nên gộp vào diff của `004-eutr-documents`.

## Quyết định 24 — Backend: override `DeleteAsync`/`DeleteMultiAsync` trong `EutrDocumentsService` để dọn `eutr_references`, không sửa `IBaseService` (spec Update 9, FR-039/FR-040)

- **Decision**: `EutrDocumentsService` hiện thừa hưởng `DeleteAsync`/`DeleteMultiAsync` thuần từ
  `BaseService<EutrDocuments,long,EutrDocumentsRequestDto>` (không override — xem
  `BaseService.cs` dòng 229-345). Để dọn `eutr_references` khi xóa document, **override** cả hai
  method này trực tiếp trong `EutrDocumentsService`, KHÔNG sửa `IBaseService`/`BaseService` (dùng
  chung cho mọi service CRUD khác trong hệ thống — `EutrStep`, `EutrMasters`, `EutrTemplates`, v.v.,
  ngoài phạm vi feature này) và KHÔNG sửa `IEutrDocumentsService` (chữ ký `DeleteAsync`/
  `DeleteMultiAsync` vẫn kế thừa nguyên vẹn từ `IBaseService`, chỉ đổi phần **implementation**).
  - `DeleteAsync(long id, string userEmail, ct)`: giữ nguyên bước kiểm tra tồn tại
    (`_repository.GetByIdAsync`) như base, nhưng trong khối transaction, thêm 1 dòng
    `await _referencesRepository.DeleteByDocumentIdAsync(id, ct);` **trước** dòng
    `await _repository.DeleteAsync(id, ct);`, cùng `BeginTransactionAsync`/`CommitAsync`/
    `RollbackAsync` — clone đúng cấu trúc override đã có ở
    `ComplJobScheduleConfigService.DeleteAsync` (dòng 82-112: override base, dọn 1 resource liên
    quan trước khi ghi DB, wrap `_unitOfWork`, rollback cả 2 khi lỗi).
  - `DeleteMultiAsync(IEnumerable<long> ids, ct)`: **không** gọi `base.DeleteMultiAsync` (vì
    `BaseService.DeleteMultiAsync` mở 1 transaction DUY NHẤT cho cả batch — 1 id lỗi làm rollback
    toàn bộ batch, xem `BaseService.cs` dòng 283-345) — override hoàn toàn bằng vòng lặp
    `foreach (var id in ids)`, mỗi vòng lặp có `BeginTransactionAsync`/`CommitAsync`/`RollbackAsync`
    **riêng** (mẫu per-item try/catch của `EutrUploadService.UploadMultipleToSharePointAndSaveDataAsync`,
    Quyết định 14/18 — 1 file/item lỗi không rollback các item khác đã commit). Lỗi của mỗi id được
    gom vào 1 danh sách; sau vòng lặp, nếu danh sách lỗi không rỗng thì `throw` 1
    `InvalidOperationException` liệt kê id + lý do của mọi id lỗi — các id đã xóa thành công trước
    đó **vẫn giữ trạng thái đã xóa** (transaction của chúng đã `CommitAsync` độc lập, không bị ảnh
    hưởng bởi exception ném ra sau đó cho các id khác).
  - Thêm method mới `Task DeleteByDocumentIdAsync(long documentId, CancellationToken ct = default)`
    vào `IEutrReferencesRepository`, implement trong `EutrReferencesRepository` bằng raw SQL
    (`DELETE FROM eutr_references WHERE DocumentId = @DocumentId`, qua `Connection.ExecuteAsync(new
    CommandDefinition(...))` — cùng style 2 method đọc hiện có, xem `EutrReferencesRepository.cs`
    dòng 19-58); vì `EutrReferencesRepository` đã inject cùng `IUnitOfWork` với `EutrDocumentsService`
    (đăng ký scoped), câu `DELETE` này tự động tham gia đúng transaction mà `EutrDocumentsService`
    vừa mở qua `_unitOfWork.BeginTransactionAsync` — không cần truyền transaction qua tham số nào
    khác, đúng cơ chế `Connection`/`Transaction` protected sẵn có của `DapperRepository<,>`.
- **Rationale**: `IBaseService<,,>`/`BaseService<,,>` là interface/class dùng chung cho **toàn bộ**
  service CRUD trong hệ thống (không chỉ `004-eutr-documents`) — sửa chữ ký hoặc hành vi mặc định
  của nó để phục vụ riêng 1 feature vi phạm trực tiếp Nguyên tắc III (Reuse Existing Backend) và có
  thể phá vỡ hành vi Delete/DeleteMulti của mọi feature khác đang dùng `BaseService` nguyên trạng.
  Override tại chỗ (`EutrDocumentsService`) là cách nhỏ nhất, cách ly đúng đủ để đạt yêu cầu
  FR-039/FR-040 mà không ảnh hưởng service nào khác — đúng tinh thần đã áp dụng nhất quán ở các
  Update trước (chỉ mở rộng/override tại điểm cần, không sửa hạ tầng dùng chung). Việc đổi ngữ nghĩa
  transaction của `DeleteMultiAsync` (per-item thay vì per-batch) là bắt buộc về mặt kỹ thuật để
  thỏa FR-040 ("lỗi ở 1 document không được chặn xóa các document khác trong cùng lượt") — ngữ
  nghĩa per-batch hiện tại của `BaseService` (all-or-nothing) không thể đáp ứng yêu cầu này dù có
  hay không có bước dọn `eutr_references`.
- **Alternatives considered**: (a) Sửa `BaseService.DeleteMultiAsync` để hỗ trợ tham số callback
  "cleanup trước khi xóa mỗi entity" dùng chung cho mọi feature — bị loại, mở rộng phạm vi thay đổi
  ra ngoài feature `004-eutr-documents` và thêm độ phức tạp cho 1 class dùng chung chỉ để phục vụ 1
  nhu cầu hiện tại của 1 feature (vi phạm YAGNI, đi ngược tinh thần đơn giản hóa đã chọn từ Quyết
  định 1/2); (b) Đổi chữ ký `IBaseService.DeleteMultiAsync` để trả về danh sách kết quả per-item
  (giống `EutrUploadFileResultDto`) thay vì `Task` — bị loại vì đây là interface dùng chung, đổi chữ
  ký ảnh hưởng mọi implementation khác (`EutrStepService`, `EutrMastersService`,
  `EutrTemplatesService`, ...), không cần thiết khi throw 1 exception tổng hợp đã đủ để controller/
  middleware hiện có (exception → `ApiResponse.Fail`, cùng cơ chế đang dùng cho `KeyNotFoundException`
  ở `Delete` đơn) surface lỗi rõ ràng cho client mà không đổi contract; (c) Dùng
  `IRepository<EutrReferences,long>` generic (như `EutrUploadService`) thay vì thêm method vào
  `IEutrReferencesRepository` — bị loại vì repository generic không có "delete theo cột không phải
  khóa chính" (`DocumentId` ≠ `Id` của `EutrReferences`), cần SQL tùy biến; thêm vào
  `IEutrReferencesRepository` (đã tồn tại từ Update 8, cùng mục đích "truy vấn tùy biến trên
  `eutr_references`") hợp lý hơn tạo thêm 1 repository/interface mới.

## Quyết định 25 — Backend: endpoint `get-file-by-idref` clone trực tiếp `ComplCompliancesController.GetFileByIds`, controller inject `ISharepointService` (spec Update 10, FR-041/FR-042)

- **Decision**: Thêm `[HttpGet("get-file-by-idref")]` vào **`EutrDocumentsController.cs` hiện có**
  (route gốc `api/eutr-documents`, KHÔNG tạo controller mới), nhận `idRef` (query string) = `FileId`
  của một `eutr_documents`, trả về `ApiResponse<SharepointFileContent>` — sao chép **nguyên vẹn**
  logic của `ComplCompliancesController.GetFileByIds` (`_sharepointService.ReadFileWithMetaAsync(idRef)`,
  cùng retry 1 lần khi gặp `HttpRequestException` với `HttpStatusCode.ServiceUnavailable`, cùng
  `try/catch` trả `500`/`503`). Để gọi được `_sharepointService`, `EutrDocumentsController` MUST
  nhận thêm `ISharepointService sharepointService` (namespace `Shared.ExternalServices.Interfaces`,
  package đã cài sẵn) qua constructor — **giống đúng cách** `ComplCompliancesController` và
  `SharePointController` đã inject interface này **trực tiếp vào controller** (không qua một
  Application service trung gian). Không cần đăng ký DI mới — `ISharepointService` đã được đăng ký
  sẵn (dùng chung bởi 2 controller kia).
- **Rationale**: Người dùng chỉ rõ tham chiếu chính xác hàm `[HttpGet("get-file-by-idref")]
  GetFileByIds` trong `ComplCompliancesController.cs` làm mẫu — sao chép đúng logic đảm bảo hành vi
  nhất quán (cùng cơ chế retry/lỗi) với endpoint đã có, tránh phát minh lại (Nguyên tắc II). Việc
  controller inject `ISharepointService` trực tiếp (bỏ qua tầng Application service) là một tiền lệ
  **đã tồn tại 2 lần** trong codebase (`ComplCompliancesController`, `SharePointController`) cho
  đúng loại thao tác "proxy đọc/ghi file SharePoint mỏng, không có business logic" — tuân theo tiền
  lệ này (Nguyên tắc II) hợp lý hơn là tạo một Application service mới chỉ để bọc 1 lời gọi
  `ReadFileWithMetaAsync` duy nhất (Nguyên tắc I không bị vi phạm mới, vì đây là mẫu proxy mỏng đã
  được chấp nhận từ trước trong 2 controller khác, không phải ngoại lệ riêng của feature này).
- **Alternatives considered**: (a) Tạo `IEutrDocumentsService.GetFileByIdRefAsync` bọc quanh
  `ISharepointService` rồi gọi qua service — bị loại, thêm 1 lớp gián tiếp không cần thiết cho 1 lời
  gọi pass-through duy nhất, không nhất quán với 2 tiền lệ đã có (cả hai đều inject thẳng vào
  controller); (b) Đặt endpoint trong `SharePointController` (cạnh `eutr-upload-multi`) — bị loại,
  dữ liệu trả về (nội dung file của một `eutr_documents` cụ thể) thuộc đúng domain "eutr-documents",
  và người dùng yêu cầu rõ tham chiếu theo tên hàm ở `ComplCompliancesController` (đặt trong
  controller CRUD của resource, không đặt trong `SharePointController` chung); (c) Tạo endpoint mới
  cho từng entity khác nhau — không áp dụng, chỉ có 1 entity (`eutr_documents`) cần xem file trong
  phạm vi feature này.

## Quyết định 26 — Frontend: tổng quát hoá `FilePreviewer.jsx` bằng 2 prop tùy chọn, KHÔNG nhân bản logic render (spec Update 10, FR-042/FR-043)

- **Decision**: `FilePreviewer.jsx` (`compliance-client/src/presentation/components/`, đang dùng
  riêng cho `compliance-detail`) được sửa **tối thiểu**: thêm 2 prop tùy chọn —
  `fetchFile = (idRef) => getFileByIdRefUseCase.execute(idRef)` (giữ đúng hành vi mặc định hiện tại
  khi không truyền prop) và `onLoaded = () => {}` (gọi kèm `{ content, contentType, fileName }` ngay
  sau khi tải thành công). `loadFileData` đổi từ gọi cứng `getFileByIdRefUseCase.execute(idFile)`
  sang gọi `fetchFile(idFile)`; mọi logic render PDF/DOCX/XLSX/ảnh (LuckyExcel, docx-preview,
  sanitizeFormatString, v.v.) **giữ nguyên 100%, không sao chép sang file khác**. `compliance-detail`
  (caller hiện tại) không đổi — không truyền 2 prop mới nên hành vi y hệt trước Update 10.
  `compliance-client/src/presentation/pages/eutr-documents/components/EutrFileViewerDialog.jsx`
  (component **mới**, phạm vi riêng của feature này — không đặt trong `presentation/components/`
  dùng chung) render `<FilePreviewer idFile={fileId} fetchFile={getEutrDocumentsFileByIdRefUseCase.execute}
  onLoaded={setLoadedFile} />` trong một `Dialog` MUI riêng (tiêu đề = fileName, nút Close + Download).
- **Rationale**: `FilePreviewer.jsx` đã có sẵn toàn bộ logic render 4 loại file (PDF/DOCX/XLSX/ảnh)
  hoạt động đúng cho `compliance-detail` — nhân bản ~500 dòng logic này sang một file mới chỉ để đổi
  nguồn fetch là vi phạm trực tiếp Nguyên tắc II (tái dùng, không phát minh lại) và tạo rủi ro lệch
  hành vi giữa 2 bản sao theo thời gian. Thêm 2 prop tùy chọn với giá trị mặc định giữ nguyên hành vi
  cũ là cách tổng quát hoá nhỏ nhất, an toàn nhất (không ảnh hưởng `compliance-detail`). Endpoint mới
  của Update 10 nằm ở `EutrDocumentsController` (`api/eutr-documents/get-file-by-idref`, Quyết định
  25), khác hẳn `api/compliances/get-file-by-idref` mà `FilePreviewer.jsx` gọi mặc định — nên bắt
  buộc phải tham số hoá nguồn fetch, không thể dùng thẳng use case cũ.
- **Alternatives considered**: (a) Clone `FilePreviewer.jsx`/`DialogFilePreviewer.jsx` thành cặp file
  mới trong `presentation/pages/eutr-documents/` — bị loại, nhân bản lớn không cần thiết (vi phạm
  Nguyên tắc II) khi chỉ cần đổi 1 lời gọi fetch; (b) Sửa `FilePreviewer.jsx` để nhận thẳng
  `IEutrDocumentsRepository`/`ICompliancesRepository` qua prop rồi tự chọn use case theo `type` — bị
  loại, phức tạp hơn cần thiết so với việc chỉ cần 1 hàm fetch chung hình dạng `(idRef) => Promise`;
  (c) Tái dùng `DialogFilePreviewer.jsx` nguyên vẹn cho cả Download — bị loại (xem Quyết định 27).

## Quyết định 27 — Frontend: Download trong `EutrFileViewerDialog` dựng Blob từ dữ liệu đã tải cho preview, KHÔNG tái dùng luồng zip/progress-dialog của `DialogFilePreviewer.jsx` (spec Update 10)

- **Decision**: `EutrFileViewerDialog.jsx` **không** tái dùng `DialogFilePreviewer.jsx` (dù giao diện
  tương tự) vì nút Download của `DialogFilePreviewer.jsx` gọi `DownloadCompliancesUseCase` — một
  luồng xuất/nén file bất đồng bộ có `ExportProgressDialog`/polling riêng cho `all-compliances`,
  không tồn tại tương đương cho `eutr-documents` và không cần thiết cho việc tải xuống **một file
  đã có sẵn trong tay** (dữ liệu base64 đã được `FilePreviewer` tải xong cho phần xem trước). Thay
  vào đó, `EutrFileViewerDialog` giữ lại `{ content, contentType, fileName }` nhận được qua callback
  `onLoaded` (Quyết định 26), và nút Download chỉ decode base64 → `Uint8Array` → `new Blob([...],
  { type: contentType })` → `URL.createObjectURL` → click một `<a download>` tạm rồi
  `URL.revokeObjectURL` — không gọi thêm API nào.
- **Rationale**: Tránh phát minh/tái dùng sai một luồng vốn được thiết kế cho xuất **nhiều** file
  dạng zip có tiến trình dài (Nguyên tắc II áp dụng đúng hướng — không ép một tình huống đơn giản
  vào một cơ chế phức tạp hơn cần thiết). Việc decode base64 thành Blob là đúng 4 dòng logic đã tồn
  tại sẵn trong `FilePreviewer.renderPdf` (dùng để tạo object URL cho `<object>`) — sao chép lại đúng
  đoạn nhỏ này ở nơi thứ 2 (Download) là chấp nhận được theo tinh thần YAGNI đã áp dụng nhất quán ở
  các Update trước (ví dụ Quyết định 13 với `GetUniqueFileName`) — không tách thành 1 hàm dùng chung
  vì chỉ 2 lần dùng, mỗi lần mục đích khác nhau (object URL để hiển thị vs. tải xuống).
- **Alternatives considered**: (a) Gọi lại `fetchFile(idRef)` một lần nữa khi nhấn Download (không
  lưu `onLoaded`) — bị loại, gọi API 2 lần cho cùng 1 file không cần thiết khi dữ liệu đã có sẵn từ
  lượt tải cho preview; (b) Thêm endpoint `GET /api/sharepoint/download/{fileId}` (đã tồn tại sẵn,
  trả về file stream trực tiếp) làm nguồn cho nút Download — cân nhắc nhưng bị loại vì thêm 1 lệnh
  gọi mạng thứ 2 không cần thiết khi nội dung đã có trong bộ nhớ trình duyệt; (c) Sao chép nguyên
  `DialogFilePreviewer.jsx` + `ExportProgressDialog`/`useDownloadProgress` — bị loại theo Decision
  chính ở trên.

## Quyết định 28 — Backend/Frontend: View/Delete theo từng file ở List PO tái dùng đúng cấu trúc "1 dòng = 1 document" đã có sẵn, chỉ thêm `FileId` vào response (spec Update 10, FR-043/FR-044/FR-045)

- **Decision**: Khảo sát `EutrDocumentsAdd.jsx` hiện tại (triển khai Update 8) cho thấy bảng chi
  tiết List PO (Grid size=5) đã render **1 `TableRow` cho mỗi document** trong
  `poReferenceDocuments` (`.map(doc => <TableRow key={doc.documentId}>...)`) — nghĩa là kiến trúc
  "mỗi file một dòng, có Action riêng" mà clarify Update 10 chọn (theo từng file, không theo từng
  dòng PO) **đã tồn tại sẵn từ Update 8**, chỉ có icon View/Delete trên mỗi dòng đang là silent
  no-op (`onClick={() => {}}`). Do đó Update 10 **không cần dựng lại UI** — chỉ cần: (1) thêm
  `FileId` vào chuỗi dữ liệu trả về cho mỗi `doc` (backend: thêm `d.FileId AS FileId` vào SQL
  `GetDocumentsByPoCodesAsync`, thêm field `FileId` vào `EutrReferencePoDocumentInfo` và
  `EutrDocumentsPoReferenceItemDto`, gán trong `EutrDocumentsService.GetPoReferencesAsync`); (2) đổi
  `onClick` của icon View trên mỗi dòng thành mở `EutrFileViewerDialog` với `doc.fileId`/`doc.fileName`
  (disabled khi `!doc.fileId` — nhất quán với FR-042 cho danh sách chính); (3) đổi `onClick` của icon
  Delete thành gọi lại `DeleteEutrDocumentsUseCase.execute(doc.documentId)` (dùng lại nguyên vẹn use
  case đã có từ CÁC file mới, không tạo mới) sau khi xác nhận qua `ConfirmDialog`, rồi refetch lại
  `poReferenceDocuments` của PO đang chọn (gọi lại đúng effect đã có ở Quyết định 22).
- **Rationale**: Vì cấu trúc dữ liệu/UI cần cho "per-file" đã tồn tại sẵn (một hệ quả tự nhiên của
  quyết định thiết kế Update 8 — mỗi document là 1 hàng riêng), việc chọn "theo từng file" ở
  clarify Update 10 không phát sinh thay đổi cấu trúc bảng nào — chỉ cần nạp thêm 1 field
  (`FileId`) và gắn hành vi thật cho 2 icon đã có vị trí sẵn. Dùng lại
  `DeleteEutrDocumentsUseCase`/`DELETE /api/eutr-documents/{id}` hiện có (đã xử lý dọn
  `eutr_references` từ Update 9) cho Delete — không cần endpoint xóa mới, không cần thay đổi hành vi
  backend nào cho việc xóa (đúng theo quyết định "chỉ xóa bản ghi DB, giữ file trên SharePoint" đã
  chốt ở clarify Update 10 — hành vi đó đã đúng sẵn với API xóa hiện tại, không gọi bất kỳ API xóa
  file SharePoint nào).
- **Alternatives considered**: (a) Thiết kế lại cột File name thành nhiều `Chip` trong 1 dòng PO duy
  nhất (giống cột Step name ở danh sách chính) rồi gắn icon View/Delete vào từng chip — bị loại sau
  khi khảo sát code thực tế cho thấy List PO KHÔNG dùng cấu trúc chip-trong-1-dòng cho File name (chỉ
  Step name mới dùng `MultiValueChips`, và chỉ trong phạm vi 1 document/1 dòng) — áp đặt lại kiến
  trúc chip sẽ là thay đổi không cần thiết, đi ngược Nguyên tắc II (đổi cấu trúc đã hoạt động đúng
  chỉ vì mô tả spec dùng từ "chip" mang tính minh họa, không phải yêu cầu kỹ thuật bắt buộc); (b) Tạo
  endpoint xóa file mới riêng cho luồng List PO — bị loại, trùng lặp hoàn toàn với
  `DELETE /api/eutr-documents/{id}` đã xử lý đúng yêu cầu (xóa document + `eutr_references`, giữ
  file SharePoint).
