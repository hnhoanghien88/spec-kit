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

## Quyết định 29 — Entity/repository mới `EutrReferenceDetails`/`eutr_reference_details`; bảng đã tồn tại sẵn trong `eutr_db.sql`, KHÔNG migration mới (spec Update 11, FR-052/FR-054)

- **Decision**: Khảo sát `docs/design/eutr/eutr_db.sql` xác nhận bảng `eutr_reference_details` (Id,
  RefId, ConditionType, ConditionValue + audit) **đã tồn tại sẵn** cùng khóa ngoại
  `eutr_reference_details_refid_foreign` (`RefId` → `eutr_references.Id` — **khác** cột
  `eutr_references.RefId` trỏ `eutr_template_details`, hai cột trùng tên nhưng ở hai bảng khác nhau,
  không liên quan) — **không cần migration DB mới** cho tính năng Assign condition. Backend cần tạo
  mới: entity `ComplianceSys.Domain/Entities/EutrReferenceDetails.cs` (`Id`, `RefId` (long?),
  `ConditionType` (byte?), `ConditionValue` (string?) + `BaseEntity` audit — clone hình dạng
  `EutrReferences.cs`), và repository đọc/xóa tùy biến `IEutrReferenceDetailsRepository`/
  `EutrReferenceDetailsRepository` (`DapperRepository<EutrReferenceDetails,long>` subclass, clone
  cấu trúc `EutrReferencesRepository` — chỉ nhận `IUnitOfWork` qua constructor), với 2 method:
  - `Task<List<EutrConditionGroupRow>> GetGroupedConditionsByDocumentIdsAsync(IEnumerable<long> documentIds, ct)`
    — SQL JOIN `eutr_reference_details`+`eutr_references` (`WHERE eutr_references.DocumentId IN
    @DocumentIds`), trả projection phẳng `{ DocumentId, ConditionType, ConditionValue }` — dùng cho
    cột Conditions ở danh sách chính (FR-054).
  - `Task DeleteByRefIdAsync(long refId, CancellationToken ct = default)` — raw SQL
    `DELETE FROM eutr_reference_details WHERE RefId = @RefId` (cùng style `Connection.ExecuteAsync`
    của `EutrReferencesRepository.DeleteByDocumentIdAsync`, tự tham gia transaction hiện tại của
    `IUnitOfWork`) — dùng cho chế độ sửa (FR-058, xem Quyết định 34).
  Đường **ghi thêm** (`AddAsync` mỗi giá trị Condition value) dùng thẳng
  `IRepository<EutrReferenceDetails,long>` generic (giống cách `EutrReferences` được ghi thêm ở
  `EutrUploadService`, Quyết định 16) — không cần method riêng cho insert.
- **Rationale**: Bảng con đã tồn tại sẵn trong DDL từ trước (một phần chuẩn bị trước cho tính năng
  này) nên không phát sinh rủi ro migration; tạo repository tùy biến (không dùng generic
  `IRepository<,>` cho phần đọc/xóa) vì cần JOIN 2 bảng (không phải khóa chính) và xóa theo cột
  không phải khóa chính (`RefId` ≠ `Id` của `EutrReferenceDetails`) — đúng lý do đã áp dụng nhất
  quán cho `EutrReferencesRepository` ở Quyết định 20/24. Gộp 2 method mới vào một repository MỚI
  riêng cho bảng con (không nhồi vào `IEutrReferencesRepository` đã có) vì đây là bảng riêng biệt có
  vòng đời/khóa ngoại độc lập — giữ ranh giới "1 repository/1 bảng chính" nhất quán với toàn bộ
  feature (mỗi bảng EUTR mới đều có repository tùy biến riêng: Masters, References, và giờ
  ReferenceDetails).
- **Alternatives considered**: (a) Thêm 2 method này vào `IEutrReferencesRepository` hiện có — bị
  loại, trộn logic của 2 bảng khác nhau vào 1 interface làm giảm rõ ràng ranh giới, khác quy ước đã
  dùng ở mọi Update trước (mỗi bảng mới luôn có interface riêng khi cần SQL tùy biến); (b) Dùng
  Entity Framework thay Dapper cho bảng mới — bị loại, toàn bộ backend dùng Dapper qua
  `Shared.Dapper` (Nguyên tắc I), không có EF trong stack.

## Quyết định 30 — Sửa `EutrReferencesRepository.DeleteByDocumentIdAsync` để dọn kèm `eutr_reference_details` mồ côi, tránh vi phạm khóa ngoại (spec Update 11, phát hiện khi lập kế hoạch)

- **Decision**: `eutr_reference_details_refid_foreign` (`RefId` → `eutr_references.Id`) là khóa
  ngoại **không có `ON DELETE CASCADE`** (xác nhận qua `docs/design/eutr/eutr_db.sql` — cùng kiểu
  ràng buộc RESTRICT/NO ACTION mặc định như `eutr_references_documentid_foreign` đã ghi nhận ở
  Quyết định 24/Update 9). Một khi Update 11 bắt đầu ghi dữ liệu thật vào `eutr_reference_details`
  (liên kết `RefId` tới các bản ghi `eutr_references` có `RefType=1`), `DeleteByDocumentIdAsync`
  hiện có (`DELETE FROM eutr_references WHERE DocumentId = @DocumentId`, dùng bởi
  `EutrDocumentsService.DeleteAsync`/`DeleteMultiAsync` cho FR-039/FR-040) **sẽ thất bại với lỗi vi
  phạm khóa ngoại** nếu document đó có bất kỳ bản ghi `eutr_reference_details` con nào — vì MySQL sẽ
  chặn xóa `eutr_references` khi vẫn còn `eutr_reference_details` tham chiếu tới nó. MUST sửa SQL
  của `DeleteByDocumentIdAsync` (giữ nguyên chữ ký method, không đổi interface) thành 2 câu lệnh
  trong cùng transaction: xóa `eutr_reference_details` trước (qua subquery `RefId IN (SELECT Id FROM
  eutr_references WHERE DocumentId = @DocumentId)`), rồi xóa `eutr_references`:
  ```sql
  DELETE FROM eutr_reference_details
  WHERE RefId IN (SELECT Id FROM eutr_references WHERE DocumentId = @DocumentId);
  DELETE FROM eutr_references WHERE DocumentId = @DocumentId;
  ```
- **Rationale**: Đây là hệ quả kỹ thuật bắt buộc để FR-039/FR-040 ("xóa document MUST xóa kèm toàn
  bộ `eutr_references` liên quan, không để lại bản ghi mồ côi") tiếp tục đúng sau khi
  `eutr_reference_details` có dữ liệu thật — tinh thần "không để lại bản ghi mồ côi" của FR-039 áp
  dụng tự nhiên xuống cả bảng cháu (`eutr_reference_details`) dù spec gốc viết trước khi bảng này có
  luồng ghi thật. Sửa tại đúng 1 điểm (`EutrReferencesRepository.DeleteByDocumentIdAsync`) — nơi duy
  nhất hiện xóa `eutr_references` theo `DocumentId` — thay vì rải logic dọn dẹp ra nhiều nơi gọi nó
  (`EutrDocumentsService.DeleteAsync`/`DeleteMultiAsync`), giữ đúng nguyên tắc "một điểm chịu trách
  nhiệm" đã áp dụng từ Update 9.
- **Alternatives considered**: (a) Thêm `ON DELETE CASCADE` vào ràng buộc khóa ngoại
  `eutr_reference_details_refid_foreign` trong `eutr_db.sql` — cân nhắc nhưng bị loại để nhất quán
  với quyết định Update 9 (Quyết định 24) đã chọn xử lý ở tầng ứng dụng thay vì cascade DB cho
  `eutr_references_documentid_foreign`, tránh 2 tiêu chuẩn khác nhau (1 cascade DB, 1 cascade app)
  cho 2 quan hệ cha-con tương tự trong cùng feature; (b) Không sửa gì, để lỗi FK surfaces tự nhiên
  khi test — bị loại, đây là lỗi chắc chắn xảy ra (không phải edge case hiếm) một khi
  `eutr_reference_details` có dữ liệu, phải sửa trong phạm vi Update 11 trước khi tính năng có thể
  hoạt động đúng với chức năng Delete đã có từ Update 9.

## Quyết định 31 — Backend: `EutrUploadService` thêm method mới `UploadManualMultipleToSharePointAndSaveDataAsync` — KHÔNG PoCode, thư mục cố định, KHÔNG validate prefix, KHÔNG ghi `eutr_references` (spec Update 11, FR-046/FR-047)

- **Decision**: Thêm 1 method mới vào `IEutrUploadService`/`EutrUploadService` hiện có (KHÔNG tạo
  service mới — cùng service đã sở hữu logic upload SharePoint + tạo `eutr_documents` từ Update 6):
  `Task<List<EutrUploadFileResultDto>> UploadManualMultipleToSharePointAndSaveDataAsync(
  EutrManualMultiUploadFileRequest request, string email, CancellationToken ct)` với
  `EutrManualMultiUploadFileRequest { List<IFormFile> Files }` (DTO mới, giống
  `EutrMultiUploadFileRequest` nhưng **không có** `PoCode`). Logic clone
  `UploadMultipleToSharePointAndSaveDataAsync` hiện có nhưng: (a) thư mục đích luôn là
  `{SharePointEutrPath}/UploadManual` (hằng số cố định, không tham số hóa theo PoCode — tái dùng
  đúng `ResolveOrCreatePoFolderAsync(basePath, folderName)` hiện có, chỉ đổi `folderName` truyền
  vào từ `request.PoCode` sang chuỗi hằng `"UploadManual"`); (b) **bỏ hoàn toàn** bước
  `GetMatchingPrefixesAsync`/validate prefix — file hợp lệ định dạng/kích thước (dùng lại
  `ValidateFile` private method hiện có, không nhân bản) là đủ để upload; (c) mỗi file thành công
  chỉ ghi **1 dòng `eutr_documents`** (`Name`, `FileId`, `ValidFrom`=hôm nay, `ValidTo`=sentinel,
  không cần transaction nào khác vì không có bước ghi `eutr_references` nào đi kèm ở bước upload
  này — Step/Conditions được gán sau, riêng biệt, qua Assign condition, xem Quyết định 34) — đơn
  giản hơn nhánh PO (không cần `IUnitOfWork.BeginTransactionAsync` bọc quanh 1 insert đơn, dùng
  thẳng `_repository.AddAsync`).
- **Rationale**: Cùng service vì cùng domain nghiệp vụ ("upload file EUTR lên SharePoint + tạo
  `eutr_documents`"), chỉ khác ở 2 điểm rẽ nhánh (thư mục cố định, không prefix) — tách thành
  service mới sẽ nhân bản gần như toàn bộ logic upload/validate file đã có (đi ngược Nguyên tắc II);
  đổi tên thư mục qua tham số thay vì hard-code lại `ResolveOrCreatePoFolderAsync` giữ đúng chữ ký
  hàm private hiện có, không cần viết lại logic tìm/tạo thư mục GetFolders/CreateFolder.
- **Alternatives considered**: (a) Tham số hóa `UploadMultipleToSharePointAndSaveDataAsync` hiện có
  bằng 1 flag `bool isManual` để rẽ nhánh nội bộ — bị loại, làm method hiện có phức tạp hơn (nhiều
  nhánh if/else cho 2 luồng nghiệp vụ khác biệt rõ — PO có prefix+eutr_references, Manual thì
  không) trong khi tách method mới rõ ràng hơn và không đổi hành vi/chữ ký của method PO đang hoạt
  động ổn định (giảm rủi ro regression); (b) Ghi `RefType=1` + `eutr_references` ngay tại bước
  upload (giống nhánh PO ghi `RefType=0` ngay khi upload) — bị loại, vì Step của luồng Manual do
  người dùng chọn SAU qua popup Assign condition (không suy ra tự động từ prefix như PO), ghi
  `eutr_references` ở bước upload sẽ cần 1 `StepId` chưa xác định — đúng theo spec (FR-047: "KHÔNG
  ghi eutr_references nào ở bước upload này").

## Quyết định 32 — Backend: action mới `[HttpPost("eutr-upload-manual-multi")]` trong `SharePointController` hiện có, cùng route `api/sharepoint` (spec Update 11, FR-046/FR-047)

- **Decision**: Thêm action mới vào `SharepointController.cs` hiện có (KHÔNG controller mới, giống
  cách `eutr-upload-multi` được thêm ở Update 6 — Quyết định 12): `[HttpPost("eutr-upload-manual-multi")]
  [Consumes("multipart/form-data")]` nhận `[FromForm] EutrManualMultiUploadFileRequest request`, gọi
  `_eutrUploadService.UploadManualMultipleToSharePointAndSaveDataAsync(request, email, ct)`. Dùng
  chung `[Authorize]` cấp controller hiện có (không thêm policy riêng theo action — đúng mẫu
  `upload`/`upload-multi`/`eutr-upload-multi` hiện tại, Nguyên tắc V không đổi).
- **Rationale**: Cùng lý do đã chọn ở Update 6 (Quyết định 12) — action mới cho 1 luồng upload khác
  biệt vẫn thuộc đúng domain "SharePoint upload", route `api/sharepoint` là nơi hợp lý nhất, tránh
  tạo controller mới chỉ vì khác tham số request.
- **Alternatives considered**: Đặt action này trong `EutrDocumentsController` (route
  `api/eutr-documents`) vì nó tạo `eutr_documents` — bị loại để nhất quán với quyết định đã chốt ở
  Update 6 rằng **mọi hành vi upload file thật lên SharePoint** (bất kể có ghi `eutr_documents` hay
  không) thuộc route `api/sharepoint`, giữ ranh giới "route theo hành động (upload file) không theo
  bảng DB bị ảnh hưởng" nhất quán trong toàn feature.

## Quyết định 33 — Backend: danh sách "chưa gán" dùng repository mới `IEutrReferencesRepository.GetUnassignedDocumentsPagedAsync`, viết SQL NOT EXISTS tùy biến (spec Update 11, FR-048)

- **Decision**: Khảo sát `Shared.Dapper` (decompile `Res.Shared.Dapper` v1.0.5) xác nhận
  `BaseRepository<TEntity,TKey>.GetPagedAsync` (đường generic `IRepository<EutrDocuments,long>` mà
  `EutrDocumentsService` đang dùng) hard-code `SELECT * FROM {1 bảng}` theo reflection trên
  `EutrDocuments` — **không có cách nào chèn `NOT EXISTS`/JOIN qua đường generic này**. Do đó MUST
  viết 1 method paged tùy biến hoàn toàn bằng raw SQL: thêm
  `Task<PagedResult<EutrDocuments>> GetUnassignedDocumentsPagedAsync(PagedRequest request, ct)` vào
  `IEutrReferencesRepository`/`EutrReferencesRepository` (không phải repository mới — đặt cạnh 2
  method JOIN hiện có, vì đây cũng là 1 truy vấn cross-table trên `eutr_references`, đúng ranh giới
  "repository sở hữu mọi truy vấn liên quan tới bảng `eutr_references`" đã có từ Update 8). Clone
  khung "paged grid tùy biến" đã có ở `EutrMastersRepository.GetPagedWithStepNameAsync`/
  `EutrTemplatesRepository.GetPagedWithVendorNameAsync` (`SortMap`/`FilterMap` whitelist theo cột +
  `LIMIT`/`OFFSET` + câu `COUNT` riêng), với mệnh đề `WHERE` **cố định luôn áp dụng** (không thuộc
  whitelist filter do người dùng gõ):
  ```sql
  SELECT d.* FROM eutr_documents d
  WHERE NOT EXISTS (SELECT 1 FROM eutr_references r WHERE r.DocumentId = d.Id)
    {AND ...whitelist filters...}
  ORDER BY {sortCol} {sortDir}
  LIMIT @limit OFFSET @offset;
  ```
  (kèm câu `COUNT(1)` tương ứng cùng `WHERE`). Trả về `PagedResult<EutrDocuments>` (dùng thẳng entity
  `EutrDocuments` — không cần DTO projection riêng vì các cột cần đều có sẵn trên entity, không JOIN
  thêm bảng nào). `EutrDocumentsService` thêm method `GetUnassignedPagedAsync(PagedRequest, ct)` gọi
  repository trên rồi map sang `List<EutrDocumentsResponseDto>` (tái dùng `_mapper` hiện có) —
  `StepNames`/`RefType`/`Conditions` (xem Quyết định 34) luôn `[]`/`null` cho các dòng này (đúng bản
  chất "chưa gán", không cần gọi thêm truy vấn Step/Conditions nào cho danh sách này).
- **Rationale**: Không có sẵn cơ chế generic nào hỗ trợ `NOT EXISTS`; viết raw SQL tùy biến là cách
  duy nhất, và đặt nó cạnh 2 method JOIN hiện có của `EutrReferencesRepository` giữ đúng quy ước
  "1 repository/1 bảng trung tâm, chứa mọi truy vấn cross-table liên quan" đã dùng nhất quán từ
  Update 8 — tránh tạo thêm 1 repository thứ 3 chỉ cho 1 query. Copy khung paging có sẵn (Masters/
  Templates) đảm bảo nhất quán về whitelist chống SQL injection, thay vì viết lại từ đầu.
- **Alternatives considered**: (a) Lọc "chưa gán" ở tầng ứng dụng (C#) — tải toàn bộ `eutr_documents`
  qua generic rồi loại các Id đã có `eutr_references` trong bộ nhớ — bị loại, không phân trang được
  đúng ở tầng DB (phải tải toàn bảng mỗi lần, không chịu tải khi dữ liệu lớn — vi phạm mục tiêu hiệu
  năng "phân trang server-side" đã ghi trong Technical Context); (b) Thêm cột đánh dấu
  (`IsAssigned BOOLEAN`) trực tiếp trên `eutr_documents`, cập nhật mỗi khi ghi/xóa `eutr_references`
  — bị loại, thêm 1 nguồn sự thật thứ 2 dễ lệch đồng bộ (denormalization không cần thiết) khi truy
  vấn `NOT EXISTS` trực tiếp đã đủ nhanh và luôn chính xác theo dữ liệu thật.

## Quyết định 34 — Backend: service mới `IEutrConditionAssignmentService`/`EutrConditionAssignmentService` — clone mẫu `ComplMasterConditionPersistenceService` (Add/Replace), KHÔNG mẫu `ComplMasterDuplicateConditionService` (spec Update 11/12, FR-052/FR-057/FR-058)

- **Decision**: Khảo sát hệ thống "Conditions type/value" đã có sẵn cho compliance-master
  (`ComplMasterCondition`/`ComplMasterConditionValue`, `ComplMasterConditionPersistenceService.cs`)
  cho thấy đây là mẫu tham chiếu đúng hình dạng "cha(Step) → con(ConditionType) → cháu
  (ConditionValue)" — ánh xạ trực tiếp `eutr_references`(cha, mang `StepId`) →
  `eutr_reference_details`(con, mang `ConditionType`/`ConditionValue`, KHÔNG có cấp thứ 3 vì mỗi
  dòng con đã là 1 giá trị đơn, khác `ComplMasterConditionValue` là cấp thứ 3 riêng). Tạo service
  Application mới `IEutrConditionAssignmentService`/`EutrConditionAssignmentService` (KHÔNG nhồi vào
  `EutrDocumentsService`/`EutrUploadService` — đây là 1 domain nghiệp vụ riêng "gán Step/Conditions",
  khác "CRUD document" và "upload file", đúng tinh thần đã tách `EutrUploadService` riêng ở Update
  6/Quyết định 11), với 4 method:
  - `AssignConditionsAsync(EutrAssignConditionsRequestDto request, string email, ct)` — **chế độ tạo
    mới** (FR-052): với mỗi `DocumentId` trong `request.DocumentIds`, 1 transaction riêng/document
    (mẫu per-item của Quyết định 24 — 1 document lỗi không chặn các document khác trong cùng lượt,
    clone `AddAsync` của `ComplMasterConditionPersistenceService`): insert 1 dòng `eutr_references`
    (`DocumentId`, `StepId=request.StepId`, `RefType=1`, `RefValue=null`), rồi với mỗi
    `EutrConditionRowDto` trong `request.Conditions` và mỗi giá trị trong `Values`, insert 1 dòng
    `eutr_reference_details` (`RefId`=Id vừa tạo, `ConditionType`, `ConditionValue`).
  - `GetConditionAssignmentAsync(long documentId, ct)` — **chế độ sửa, tải trước** (FR-057): đọc 1
    dòng `eutr_references` (`WHERE DocumentId=@id AND RefType=1`, kỳ vọng đúng 1 dòng theo FR-052) +
    mọi dòng `eutr_reference_details` khớp `RefId` đó (qua
    `IEutrReferenceDetailsRepository.GetGroupedConditionsByDocumentIdsAsync([documentId], ct)`, dùng
    lại đúng method của Quyết định 29 dù chỉ truyền 1 id), nhóm theo `ConditionType` thành
    `List<EutrConditionRowDto>`; trả `EutrDocumentConditionAssignmentDto { long? StepId,
    List<EutrConditionRowDto> Conditions }`.
  - `UpdateConditionAssignmentAsync(long documentId, EutrUpdateConditionAssignmentRequestDto
    request, string email, ct)` — **chế độ sửa, lưu** (FR-058): trong 1 transaction — (a) lấy Id của
    dòng `eutr_references` hiện có của document đó (`RefType=1`), `UpdateAsync` đổi `StepId` (giữ
    nguyên `RefValue=null`, `DocumentId`, `RefType`); (b) gọi
    `IEutrReferenceDetailsRepository.DeleteByRefIdAsync(refId, ct)` (Quyết định 29) rồi insert lại từ
    đầu đúng bộ `Conditions` mới trong `request` — **xóa hết rồi ghi lại toàn bộ** (clone
    `ComplMasterConditionPersistenceService.ReplaceAsync`, KHÔNG mang theo `HasChanged`/versioning —
    baggage riêng của compliance-master, không cần cho tính năng đơn giản này).
  - `UpdatePoStepAsync(long documentId, long stepId, string email, ct)` — **Edit cho Type="PO"**
    (FR-055): trong 1 transaction — xóa **toàn bộ** dòng `eutr_references` hiện có của document đó
    (`WHERE DocumentId=@id AND RefType=0`, có thể nhiều dòng do khớp nhiều prefix ở Update 7), lấy
    `RefValue` (mã PO) từ dòng có `Id` nhỏ nhất trong số đó trước khi xóa (đúng quy tắc xác định của
    Update 13/FR-055), rồi insert **đúng 1** dòng mới (`DocumentId`, `StepId` mới, `RefType=0`,
    `RefValue` giữ nguyên). KHÔNG đụng `eutr_reference_details` (Type="PO" không có bảng con).
- **Validate trùng Conditions type trong 1 request** (Update 13, FR-051): thêm 1
  `FluentValidation` rule đơn giản trong validator của `EutrAssignConditionsRequestDto`/
  `EutrUpdateConditionAssignmentRequestDto` — `.Must(conditions =>
  conditions.Select(c => c.ConditionType).Distinct().Count() == conditions.Count)` (kiểm tra không
  có 2 dòng cùng `ConditionType` trong `Conditions`) — dùng `HashSet`/`Distinct().Count()` đơn giản,
  **KHÔNG** clone `ComplMasterDuplicateConditionService` (dịch vụ đó giải quyết bài toán khác — phát
  hiện 2 bản ghi cha trùng lặp toàn hệ thống qua quét toàn bảng theo trang, không phải validate
  trong-1-request — xem nghiên cứu, mang theo sẽ là over-engineering gây hiểu nhầm).
- **Rationale**: `ComplMasterConditionPersistenceService.AddAsync`/`ReplaceAsync` là mẫu tham chiếu
  gần khớp nhất về hình dạng dữ liệu VÀ ngữ nghĩa (tạo mới = insert cả cây; sửa = xóa hết rồi ghi
  lại) cho đúng quyết định đã chốt ở clarify (Update 11 correction + Update 12 câu hỏi 2) — tái sử
  dụng ý tưởng thay vì phát minh cách khác. Bỏ `Logical`/`DisplayType`/`ComplType`/`HasChanged`
  vì đó là độ phức tạp riêng của domain "AND/OR rule + versioning" của compliance-master, không có
  trong yêu cầu nghiệp vụ của tính năng này (mỗi document chỉ có 1 tập Conditions phẳng, không có
  khái niệm AND/OR block hay version cũ/mới).
- **Alternatives considered**: (a) Nhồi 4 method trên vào `EutrDocumentsService` — bị loại, làm
  service CRUD cơ bản phình to với 1 domain nghiệp vụ khác (giống lý do đã tách `EutrUploadService`
  ở Update 6); (b) Diff/merge `eutr_reference_details` theo Id khi sửa (giữ `Id` cũ cho dòng không
  đổi) thay vì xóa hết ghi lại — bị loại, đã chốt ở clarify Update 12 (câu hỏi 2, "Replace toàn bộ")
  vì đơn giản hơn và không có bảng nào khác tham chiếu tới `Id` của `eutr_reference_details` (không
  mất gì khi đổi Id qua các lần sửa); (c) Dùng `ON DELETE CASCADE` để tự dọn `eutr_reference_details`
  khi `UpdateAsync` đổi... (N/A — update không xóa dòng cha, chỉ đổi cột, cascade không áp dụng cho
  trường hợp này, chỉ áp dụng cho Quyết định 30).

## Quyết định 35 — Backend: 5 action mới trong `EutrDocumentsController` hiện có, tái dùng policy `EutrDocuments.ReadAll`/`ReadOne`/`Update` sẵn có (spec Update 11/12, FR-048/FR-052/FR-055/FR-057/FR-058)

- **Decision**: Thêm 5 action mới vào `EutrDocumentsController.cs` hiện có (KHÔNG controller mới —
  cùng domain "eutr-documents", đúng mẫu đã áp dụng cho `list-po-references`/`get-file-by-idref` ở
  Update 8/10), inject thêm `IEutrConditionAssignmentService _conditionAssignmentService` qua
  constructor:
  | Route | Method | Policy | Gọi |
  |---|---|---|---|
  | `POST get-unassigned` | `GetUnassigned(page, pageSize, sortColumn, sortOrder [query], filters [body])` | `EutrDocuments.ReadAll` | `_eutrDocumentsService.GetUnassignedPagedAsync` (Quyết định 33) |
  | `POST assign-conditions` | `AssignConditions([FromBody] EutrAssignConditionsRequestDto dto, ct)` | `EutrDocuments.Update` | `_conditionAssignmentService.AssignConditionsAsync` (Quyết định 34) |
  | `GET {id:long}/condition-assignment` | `GetConditionAssignment(long id, ct)` | `EutrDocuments.ReadOne` | `_conditionAssignmentService.GetConditionAssignmentAsync` |
  | `PUT {id:long}/condition-assignment` | `UpdateConditionAssignment(long id, [FromBody] EutrUpdateConditionAssignmentRequestDto dto, ct)` | `EutrDocuments.Update` | `_conditionAssignmentService.UpdateConditionAssignmentAsync` |
  | `PUT {id:long}/step` | `UpdatePoStep(long id, [FromBody] EutrUpdatePoStepRequestDto dto, ct)` | `EutrDocuments.Update` | `_conditionAssignmentService.UpdatePoStepAsync` |
  Cả 5 action đều dùng chung 4 policy đã đăng ký sẵn cho `EutrDocuments.*` (không thêm policy mới —
  `assign-conditions`/`condition-assignment`/`step` đều là hành vi "sửa phân loại của document đã
  có", ánh xạ tự nhiên vào policy `Update` đã tồn tại, cùng cách `list-po-references` dùng lại
  `ReadAll` ở Update 8).
- **Rationale**: Giữ đúng quy ước đã áp dụng suốt feature — mọi endpoint liên quan tới
  `eutr_documents`/`eutr_references`/`eutr_reference_details` phục vụ trực tiếp trang EUTR Documents
  đều nằm trong `EutrDocumentsController` (route `api/eutr-documents`), chỉ riêng hành vi "upload
  file thật lên SharePoint" mới thuộc `SharePointController` (Quyết định 12/32) — ranh giới này nhất
  quán từ Update 6 tới nay. Tái dùng 4 policy sẵn có tránh phải tạo/seed thêm policy mới trong DB
  (Nguyên tắc V, "menu/quyền tạo động ở DB, không seed bằng code" — mọi feature EUTR trước đều tuân
  thủ điều này).
- **Alternatives considered**: (a) Policy riêng `EutrDocuments.AssignCondition` cho 3 action mới —
  bị loại, không có yêu cầu nghiệp vụ nào cần tách quyền "gán Step/Conditions" khỏi quyền "Update"
  chung của document, thêm policy mới đòi hỏi seed/migrate quyền trong DB ngoài phạm vi code (đi
  ngược nguyên tắc tối giản đã áp dụng nhất quán); (b) Gộp `get-unassigned` vào `get-all` hiện có
  qua 1 filter đặc biệt (ví dụ `filters: [{column: "Unassigned", operator: "eq", value: true}]`) —
  bị loại, `BaseRepository.GetPagedAsync` generic chỉ nhận filter theo cột thật của entity (Quyết
  định 33), không hỗ trợ cột "ảo" — phải là endpoint/method riêng với SQL riêng.

## Quyết định 36 — Frontend: tái dùng nguyên vẹn `ReferenceObjectMultiAutocomplete.jsx` cho "Condition value", KHÔNG tạo component multi-select mới (spec Update 11, FR-051)

- **Decision**: Khảo sát codebase xác nhận đã có sẵn `presentation/components/common/
  ReferenceObjectMultiAutocomplete.jsx` — biến thể multi-select hoàn chỉnh của
  `ReferenceObjectAutocomplete.jsx`, cùng dùng `useReferenceObjects()` (hook đã dùng trong
  `EutrDocumentsAdd.jsx` từ Update 4 cho cột PO name), hỗ trợ sẵn debounce tìm kiếm, phân trang cuộn
  vô hạn, chip cắt bớt "+N more", so khớp theo `option.id`. Dùng trực tiếp component này cho ô
  "Condition value" trong popup Assign condition: `<ReferenceObjectMultiAutocomplete
  referenceType={row.conditionType} value={row.values} onChange={(e, v) => ...} label="Condition
  value" placeholder="Select multiple..." showAllOption={false} />` — `row.conditionType` chính là
  giá trị `refType` số (`15` cho "PO", `14` cho "Vendor", xem Quyết định 39) nên truyền thẳng không
  cần bảng ánh xạ trung gian.
- **Rationale**: Component đã tồn tại, đã được kiểm chứng qua các consumer khác
  (`ComplianceMasterForm.jsx`, `MasterDefaultForm.jsx`, `CountryCodesField.jsx`) — dùng lại triệt để
  tuân thủ Nguyên tắc II/III, tránh viết lại logic debounce/phân trang/chip đã có sẵn và đã chạy ổn
  định.
- **Alternatives considered**: (a) Tự viết Autocomplete multi-select riêng cho `eutr-documents` —
  bị loại, nhân bản hoàn toàn logic đã có, không có lý do khác biệt nào giữa nhu cầu của
  `eutr-documents` và các consumer hiện tại của component chung; (b) Dùng mẫu "chọn 1 giá trị rồi
  bấm thêm vào danh sách" của `MasterDefaultForm.jsx` (Autocomplete đơn + nút "add value") — bị loại,
  yêu cầu rõ ràng là "chọn nhiều giá trị" (multi-select thật), mẫu đó có UX rườm rà hơn không cần
  thiết khi đã có multi-select thật sẵn.

## Quyết định 37 — Frontend: component mới `AssignConditionDialog.jsx` — state dạng mảng dòng clone `ComplianceMasterForm.jsx`, KHÔNG clone `ConditionsView.jsx` (chỉ đọc) (spec Update 11/12, FR-051/FR-057)

- **Decision**: Không có Dialog nào có sẵn đúng hình "danh sách file read-only phía trên + bảng
  Conditions type/value có thể thêm/xóa dòng phía dưới" — tạo mới
  `presentation/pages/eutr-documents/components/AssignConditionDialog.jsx`, nhận props `open, mode
  ('create'|'edit'), documents (mảng {id, fileName}), initialStepId, initialConditions, onClose,
  onSaved`. State nội bộ: `stepId`, `conditionRows` (mảng `{ rowId, conditionType, values }`). Clone
  trực tiếp state machine của `ComplianceMasterForm.jsx` cho phần bảng Conditions:
  `handleAddConditionRow` (append `{ rowId: crypto.randomUUID(), conditionType: '', values: [] }`,
  nút `<Button startIcon={<AddIcon />}>Add condition</Button>`), `handleRemoveConditionRow` (filter
  theo `rowId`), `handleConditionRowChange` (map theo `rowId`, đổi 1 field). Dropdown "Conditions
  type" dùng `<Select>`/`<MenuItem>` (không `Autocomplete`, khớp mẫu đã dùng ở
  `ComplianceMasterForm.jsx`), mỗi `MenuItem` có `disabled={conditionRows.some(r => r.rowId !==
  row.rowId && r.conditionType === option.value)}` (clone chính xác dòng logic disable-trùng đã có ở
  `ComplianceMasterForm.jsx` — xem Quyết định 39 cho hằng số `CONDITION_TYPE_OPTIONS`). Dòng "Step"
  cố định (không nằm trong `conditionRows`, không thể xóa) render riêng ở đầu bảng, dùng
  `<Select>`/`<MenuItem>` nạp từ `GetEutrStepsUseCase` (gọi 1 lần khi popup mở). Bố cục Dialog (danh
  sách file cố định phía trên + bảng cuộn phía dưới) tham khảo cách chia `PaperProps`/`DialogContent`
  flex-column có sẵn ở `MapDataDialog.jsx` (không sao chép logic 2-panel trái/phải của nó, chỉ mượn
  kỹ thuật `minHeight`/`maxHeight`/`overflow` để tạo layout trên/dưới).
- **Rationale**: `ConditionsView.jsx`/`ConditionsViewForSo.jsx` (Dialog gần nhất về "hiển thị
  Conditions") xác nhận là **read-only tuyệt đối** (README ghi rõ "no editing capability") — không
  thể chỉnh sửa để thêm khả năng edit mà không viết lại gần như toàn bộ, nên không phải điểm khởi đầu
  phù hợp. `ComplianceMasterForm.jsx` dù không phải Dialog (là section trong trang full-page) có
  đúng state machine thêm/xóa/sửa dòng + cơ chế disable-trùng-loại cần dùng — bọc state machine đó
  trong 1 `Dialog` mới là cách tận dụng đúng phần lõi logic đã kiểm chứng mà không cố ép 1 component
  read-only thành editable.
- **Alternatives considered**: (a) Chỉnh sửa `ConditionsView.jsx` thêm mode editable — bị loại,
  thay đổi 1 component dùng chung ở nhiều nơi khác (`compliance-master`, `compliance-management`) chỉ
  để phục vụ 1 nhu cầu riêng của `eutr-documents` là rủi ro regression không cần thiết (đi ngược
  Nguyên tắc II — không phá vỡ caller hiện có); (b) Nhân bản toàn bộ `ComplianceMasterForm.jsx` (kể
  cả phần AND/OR block, `DisplayType`, `ComplType`) — bị loại, feature này không có khái niệm AND/OR
  block hay các cờ domain-specific đó, sao chép nguyên vẹn sẽ mang theo độ phức tạp không cần thiết,
  chỉ nên clone đúng phần "mảng dòng + add/remove/disable-trùng".

## Quyết định 38 — Frontend: `EutrDocumentsModal.jsx` thêm trường Step (chỉ khi Type="PO"), Edit rẽ nhánh ở `index.jsx` theo `row.refType` (spec Update 12, FR-055/FR-056)

- **Decision**: `index.jsx`'s `onEdit` handler (hiện luôn `setModalData(row); setModalOpen(true)`)
  đổi thành rẽ nhánh theo `row.refType` (field đã có từ Update 8, `TAKE_FROM_OPTIONS[0].value = 0`
  cho "PO", `[1].value = 1` cho "Upload manual", `null`/`undefined` khi chưa có `eutr_references`
  nào):
  - `refType === 0` ("PO"): vẫn `setModalData(row); setModalOpen(true)` (popup đơn giản hiện có),
    nhưng `EutrDocumentsModal.jsx` được sửa thêm: khi `open` và `initialData?.refType === 0`, gọi 1
    use case mới `GetEutrDocumentCurrentStepUseCase.execute(initialData.id)` (endpoint mới nhẹ, xem
    dưới) để lấy `stepId` hiện tại (theo quy tắc `Id` nhỏ nhất của Update 13), nạp `<Select>`/
    `<Autocomplete>` Step (options từ `GetEutrStepsUseCase`, gọi 1 lần); Save gọi thêm 1 use case mới
    `UpdateEutrDocumentPoStepUseCase.execute(id, stepId)` (→ `PUT /eutr-documents/{id}/step`) **sau
    khi** `UpdateEutrDocumentsUseCase` (File name/Valid from/Valid to) thành công — 2 lời gọi API độc
    lập, cùng 1 lượt Save trên UI.
  - `refType === 1` ("Upload manual"): **không** mở `EutrDocumentsModal` — gọi
    `GetEutrDocumentConditionAssignmentUseCase.execute(row.id)` (→ `GET
    /eutr-documents/{id}/condition-assignment`) rồi mở `AssignConditionDialog` (Quyết định 37) ở
    `mode="edit"` với `documents=[{id: row.id, fileName: row.name}]`, `initialStepId`/
    `initialConditions` từ kết quả. Save gọi `UpdateEutrConditionAssignmentUseCase.execute(row.id,
    payload)` (→ `PUT /eutr-documents/{id}/condition-assignment`).
  - `refType` trống/null: không đổi, mở `EutrDocumentsModal` như hiện tại, không có trường Step (vì
    `EutrDocumentsModal` chỉ render Step khi `initialData?.refType === 0`).
  Cần 1 endpoint/use case nhẹ mới `GET /eutr-documents/{id}/current-step` (hoặc gộp luôn vào 1
  response field có sẵn — xem Alternatives) để lấy `stepId` hiện tại của document Type="PO" — quyết
  định: **thêm 1 field `stepId` (long?, khác `stepNames`/`refType` đã có) vào response của chính
  `GET get-by-id/{id}`** hiện có (dùng để nạp `EutrDocumentsModal` khi mở, đã có sẵn lời gọi này ở
  `index.jsx`? — thực tế hiện tại `onEdit` KHÔNG gọi `get-by-id`, dùng thẳng `row` từ grid đã có sẵn
  trong bộ nhớ; để tránh gọi lại `get-by-id`, quyết định cuối: **thêm `stepId` vào chính
  `EutrDocumentsResponseDto`** (field mới, cùng lô với `stepNames`/`refType` đã tính ở
  `AttachStepInfoAsync`, xem Quyết định 39) — `row.stepId` đã có sẵn trong dữ liệu grid khi mở Edit,
  KHÔNG cần gọi API riêng nào để lấy Step hiện tại.
- **Rationale**: Rẽ nhánh tại `index.jsx` (nơi duy nhất khởi tạo hành vi Edit) giữ đúng phạm vi thay
  đổi tối thiểu — `EutrDocumentsModal.jsx` chỉ cần biết "có render Step hay không" qua field đã có
  sẵn trên `initialData` (`refType`), không cần logic rẽ nhánh phức tạp bên trong nó. Việc thêm
  `stepId` thẳng vào `EutrDocumentsResponseDto` (thay vì gọi API riêng khi mở popup) tận dụng đúng
  lô dữ liệu Step/Type đã tính sẵn cho mỗi trang (Update 8's `AttachStepInfoAsync`), tránh 1 round-trip
  network không cần thiết mỗi lần mở Edit.
- **Alternatives considered**: (a) Gọi `GET get-by-id/{id}` mới khi mở Edit để lấy `stepId` — bị
  loại, dữ liệu Step/Type của mọi document trong trang **đã có sẵn** trong bộ nhớ (`row` từ
  DataGrid) nhờ `AttachStepInfoAsync` chạy cho cả trang cùng lúc — gọi thêm API riêng cho 1 field là
  round-trip dư thừa; (b) Đặt logic rẽ nhánh Type bên trong `EutrDocumentsModal.jsx` (nhận `row` đầy
  đủ, tự quyết định render gì) — bị loại, với `refType=1` không mở modal đơn giản này chút nào (mở
  hẳn 1 Dialog khác `AssignConditionDialog`) — rẽ nhánh ở tầng gọi (`index.jsx`, quyết định mở
  Dialog nào) rõ ràng hơn nhồi logic "không render gì, mở Dialog khác" vào trong chính Modal đó.

## Quyết định 39 — Backend: mở rộng `AttachStepInfoAsync` (đổi tên `AttachStepAndConditionInfoAsync`) để gán thêm `StepId` (Update 13) và `Conditions` (Update 11) vào `EutrDocumentsResponseDto`; Frontend: hằng số mới `CONDITION_TYPE_OPTIONS` cạnh `TAKE_FROM_OPTIONS` (spec Update 11/13, FR-054/FR-055)

- **Decision**: Mở rộng `EutrDocumentsResponseDto` thêm 2 field: `long? StepId` (Update 13 — Step
  ứng với bản ghi `eutr_references` có `Id` nhỏ nhất trong nhóm cùng `DocumentId`, dùng cho dropdown
  Step ở Edit popup Type="PO", Quyết định 38) và `List<ConditionGroupDto> Conditions` (Update 11 —
  `ConditionGroupDto { byte ConditionType, List<string> Values }`, dùng cho cột Conditions ở danh
  sách chính, FR-054). Đổi `EutrReferenceStepInfo` (projection JOIN hiện có của
  `GetStepInfoByDocumentIdsAsync`) thêm field `long ReferenceId` (chính là `eutr_references.Id`) để
  `EutrDocumentsService` có thể suy ra `StepId` theo `Id` nhỏ nhất trong bước gộp bộ nhớ hiện có
  (`AttachStepInfoAsync` → đổi tên phản ánh đúng phạm vi mới rộng hơn, giữ nguyên chữ ký gọi từ
  `GetPagedAsync`). `Conditions` được gán qua 1 lời gọi mới tới
  `IEutrReferenceDetailsRepository.GetGroupedConditionsByDocumentIdsAsync(documentIds)` (Quyết định
  29) — cùng khối `foreach` gộp theo `DocumentId` đã có, chỉ thêm 1 dictionary gộp nữa (đúng mẫu
  "query cha + N query con WHERE IN + gộp bộ nhớ" của `ComplCountryGroupService`, Quyết định 20).
  Frontend: thêm hằng số mới `CONDITION_TYPE_OPTIONS = [{ value: 15, label: 'PO' }, { value: 14,
  label: 'Vendor' }]` vào `compliance-client/src/utils/helpers.js` (cạnh `TAKE_FROM_OPTIONS` đã có)
  — `ConditionType` số nguyên trả từ backend chính là giá trị `refType` dùng để tải Condition value
  (không có bảng ánh xạ trung gian nào khác, đúng quyết định đã chốt ở Clarifications Update 11).
  `useEutrDocumentsColumns.jsx` cột "conditions": `renderCell` mới, `.map()` qua `row.conditions`,
  mỗi nhóm hiển thị 1 dòng `"{label}: {values.join(', ')}"` (label tra từ `CONDITION_TYPE_OPTIONS`)
  — component nhỏ mới (không tái dùng `ConditionsCell.jsx` vì component đó nhóm theo AND/OR block,
  cấu trúc dữ liệu không khớp với nhóm phẳng theo `ConditionType` của tính năng này).
- **Rationale**: Tái dùng đúng vị trí/cơ chế gộp dữ liệu đã có (`AttachStepInfoAsync`) cho cả 2 field
  mới, tránh thêm 1 round-trip HTTP hoặc 1 method service riêng cho mỗi field — nhất quán với cách
  `StepNames`/`RefType` đã được thêm ở Update 8. Đặt `ConditionType` số trực tiếp (không dịch nhãn ở
  backend) giữ đúng quy ước "backend trả mã, frontend map nhãn" đã áp dụng cho `RefType`/
  `TAKE_FROM_OPTIONS` từ Update 8.
- **Alternatives considered**: (a) Tạo endpoint riêng `GET /eutr-documents/{id}/step` gọi khi mở
  Edit — bị loại ở Quyết định 38 (round-trip dư thừa); (b) Tái dùng `ConditionsCell.jsx` bằng cách
  "giả" mỗi nhóm thành 1 block AND riêng (`logical=1`) để khớp input của nó — bị loại, biến dạng dữ
  liệu chỉ để ép khớp 1 component không thiết kế cho trường hợp này là phức tạp hơn viết 1 renderCell
  nhỏ trực tiếp (~10 dòng).

## Quyết định 40 — Frontend: `EutrDocumentsAdd.jsx` Screen2 — thay `DEMO_FILE_LIST` bằng danh sách thật + khu Upload File clone Screen1 + `AssignConditionDialog` chế độ tạo mới (spec Update 11, FR-046 đến FR-053)

- **Decision**: Sửa `EutrDocumentsAdd.jsx` (Screen2, nhánh `takeFrom === TAKE_FROM_OPTIONS[1].value`):
  bỏ hằng số `DEMO_FILE_LIST` và các handler no-op (`handleDragOver`/`handleDrop`/nút "Assign
  condition" `onClick={() => {}}`); thêm state `unassignedFiles`/`selectedUnassignedIds`, gọi
  `GetEutrDocumentsUnassignedUseCase.execute()` khi `takeFrom` đổi sang "Upload manual" (mẫu
  `useEffect` đã có cho `fetchPoList` ở Screen1); clone khối JSX khu "Upload File" của Screen1 (card
  viền nét đứt + `CloudUploadIcon` + input file ẩn, Quyết định 19) nhưng **bỏ điều kiện
  `opacity/pointerEvents` theo PO đã chọn** (khu này luôn khả dụng ở Screen2, không cần chọn gì
  trước — FR-046) và đổi hàm xử lý file sang gọi
  `uploadToSharePointUseCase.executeManualMulti(files)` (Quyết định 31) thay vì `executeEutrMulti`;
  bảng danh sách file giữ nguyên cấu trúc `Table`/`Checkbox` đã có (Quyết định research frontend #3)
  nhưng `.map()` qua `unassignedFiles` thật, icon View/Delete mỗi dòng dùng lại đúng cơ chế đã có ở
  List PO (`EutrFileViewerDialog`/`ConfirmDialog`/`deleteEutrDocumentsUseCase`, Quyết định 26/28) thay
  vì no-op; nút "Assign condition" `disabled={selectedUnassignedIds.length === 0}`, `onClick` mở
  `AssignConditionDialog` (Quyết định 37) ở `mode="create"` với `documents = unassignedFiles.filter(f
  => selectedUnassignedIds.includes(f.id))`; `onSaved` của Dialog gọi lại
  `GetEutrDocumentsUnassignedUseCase` để refetch (file vừa gán biến mất khỏi danh sách, FR-053).
- **Rationale**: Clone tối đa cấu trúc/khu vực đã hoạt động đúng ở Screen1 (khu Upload File, bảng
  Table+Checkbox, View/Delete per-file) — tất cả các phần đó đã được thiết kế/triển khai đúng ở các
  Update trước cho đúng chính hình dạng UI mà Screen2 cần, chỉ khác nguồn dữ liệu (danh sách "chưa
  gán" thay vì "theo PO đang chọn") và không có điều kiện "phải chọn PO trước" — giảm tối đa code
  mới, tăng tính nhất quán trải nghiệm giữa 2 Screen.
- **Alternatives considered**: Tạo component con riêng `UnassignedFilesTable.jsx` tách khỏi
  `EutrDocumentsAdd.jsx` — cân nhắc nhưng để nguyên trong cùng file (giữ đúng cấu trúc hiện tại của
  file này, đã chứa cả Screen1 và Screen2 từ Update 3) để tránh 1 lần refactor tách file không được
  yêu cầu, ngoài phạm vi các Update đã chốt.

## Quyết định 41 — Backend: JOIN thêm `eutr_reference_types` vào `GetStepInfoByDocumentIdsAsync`, trả `TypeName` thay vì để frontend map qua `TAKE_FROM_OPTIONS`; migration seed 2 dòng cố định (spec Update 14, FR-034)

- **Decision**: Sửa `EutrReferencesRepository.GetStepInfoByDocumentIdsAsync` (Quyết định 20) — thêm
  `LEFT JOIN eutr_reference_types t ON t.Id = r.RefType` và `t.Name AS TypeName` vào SELECT hiện có:
  ```sql
  SELECT r.DocumentId, s.Name AS StepName, r.RefType, r.Id AS ReferenceId, r.StepId AS StepId,
         t.Name AS TypeName
  FROM eutr_references r
  LEFT JOIN eutr_steps s ON s.Id = r.StepId
  LEFT JOIN eutr_reference_types t ON t.Id = r.RefType
  WHERE r.DocumentId IN @DocumentIds;
  ```
  Thêm `public string? TypeName { get; set; }` vào `EutrReferenceStepInfo` (Dtos/Response) và vào
  `EutrDocumentsResponseDto`. `EutrDocumentsService.AttachStepAndConditionInfoAsync` mở rộng tuple
  group-theo-`DocumentId` hiện có (Quyết định 20/39) để lấy thêm `TypeName:
  x.Select(y => y.TypeName).FirstOrDefault()` và gán `item.TypeName = info.TypeName;` — không đổi
  cấu trúc hàm, chỉ thêm 1 field, đúng mẫu đã dùng cho `StepId` ở Quyết định 39. Frontend
  (`useEutrDocumentsColumns.jsx`, cột `type`): đổi `valueGetter` từ
  `TAKE_FROM_OPTIONS.find(opt => opt.value === row.refType)?.label || ""` sang `row.typeName || ""` —
  bỏ hẳn phụ thuộc `TAKE_FROM_OPTIONS` cho cột này (import `TAKE_FROM_OPTIONS` trong file này vẫn giữ
  lại nếu còn dùng cho cột khác — kiểm tra lại khi implement).
  Thêm migration mới `14_seed_eutr_reference_types.sql`: seed đúng 2 dòng cố định trong
  `eutr_reference_types` khớp giá trị `RefType` đã ghi sẵn trên `eutr_references` — `Id=0` → "PO"
  (Update 7), `Id=1` → "Upload manual" (Update 11). Vì cột `Id` là `TINYINT UNSIGNED AUTO_INCREMENT`,
  MySQL mặc định coi giá trị `0` như `NULL` (tự sinh số kế tiếp) trừ khi bật `NO_AUTO_VALUE_ON_ZERO`
  trong `sql_mode` của phiên hiện tại — migration MUST bật cờ này tạm thời quanh 2 câu `INSERT` rồi
  khôi phục `sql_mode` cũ ngay sau đó, dùng `INSERT ... ON DUPLICATE KEY UPDATE` để idempotent (mẫu
  `INSERT IGNORE` đã dùng ở `03_migrate_master_default.sql`, nhưng ở đây cần `ON DUPLICATE KEY UPDATE
  Name = VALUES(Name)` thay vì `IGNORE`, để lần chạy lại vẫn cập nhật `Name` nếu người quản trị đã
  sửa nó qua feature `006` — xem thêm ghi chú phòng vệ `CREATE TABLE IF NOT EXISTS` bên dưới).
- **Rationale**: Yêu cầu người dùng ("dữ liệu cột Type sẽ lấy từ bảng `eutr_reference_types`") đúng
  nghĩa đen là đổi NGUỒN dữ liệu nhãn hiển thị, không phải thêm một bảng tra cứu song song ở
  frontend. Backend đã có sẵn đúng 1 điểm tính `RefType`→nhãn cho cột Type (`GetStepInfoByDocumentIdsAsync`
  + `AttachStepAndConditionInfoAsync`) — mở rộng JOIN tại đây là thay đổi nhỏ nhất, nhất quán với
  cách "Step name" đã lấy nhãn thật qua JOIN từ Update 8 (khác với việc bịa ra một cơ chế cache/lookup
  mới ở tầng khác). Việc kiểm tra thực tế `TAKE_FROM_OPTIONS` (trong `compliance-client/src/utils/helpers.js`)
  cho thấy mảng này có `value` = `1..5` (PO/Vendor/Invoice/Delivery note/General agreement — dùng
  chung cho trường "Take from" ở `eutr-templates`), KHÔNG có phần tử nào mang `value = 0`; trong khi
  `RefType` ghi thật trên `eutr_references` là `0` (PO, Update 7) hoặc `1` (Upload manual, Update 11).
  Điều này nghĩa là *trước Update 14*, cột Type trên danh sách đã hiển thị **sai/rỗng theo đúng nghĩa
  đen** cho phần lớn dữ liệu thật: `RefType=0` → không khớp phần tử nào trong `TAKE_FROM_OPTIONS` →
  nhãn rỗng; `RefType=1` → khớp nhầm phần tử `{value:1, label:'PO'}` → hiển thị "PO" ngay cả khi
  document thực ra thuộc luồng "Upload manual". Đây chính là lỗi nền (root cause) mà yêu cầu của
  người dùng nhắm tới sửa — không phải một sở thích trình bày. JOIN thật với `eutr_reference_types`
  (được feature `006` quản lý, có thể seed đúng `Id=0`/`Id=1` khớp ngữ nghĩa RefType thật) loại bỏ
  hoàn toàn lớp mapping sai này.
- **Alternatives considered**: (a) Sửa `TAKE_FROM_OPTIONS` để thêm `{value:0, label:'PO'}` và sửa
  `{value:1}` thành "Upload manual" — bị loại, vì `TAKE_FROM_OPTIONS` được dùng chung bởi nhiều màn
  hình khác (`eutr-templates` — `StepFormRow.jsx`, `BulkAddStepsDialog.jsx`, `StepTree.jsx`,
  `TemplateBuilderPage.jsx`) cho đúng ngữ nghĩa gốc "Take from" (PO/Vendor/Invoice/...); đổi giá trị
  chung này sẽ phá vỡ các màn hình đó, và cũng không phải điều người dùng yêu cầu (yêu cầu rõ ràng
  nói tới bảng `eutr_reference_types`, không nói tới sửa hằng số front-end). (b) Tạo hằng số front-end
  **mới** riêng cho Type (ví dụ `EUTR_DOCUMENT_TYPE_OPTIONS = [{value:0,label:'PO'},{value:1,label:'Upload manual'}]`)
  — bị loại, vì đây vẫn là hard-code, đúng vấn đề mà yêu cầu muốn thay thế bằng dữ liệu quản lý được
  qua CRUD (`eutr_reference_types`); không tận dụng được việc feature `006` đã tồn tại. (c) Gọi thêm 1
  API riêng ở frontend (`GET /api/eutr-reference-types`) để tự dựng bảng tra cứu Id→Name rồi map ở
  client — bị loại, thêm 1 round-trip + logic map trùng lặp với đúng việc backend đã làm cho Step
  name (JOIN sẵn, trả nhãn đã tính) ở cùng câu SQL; vi phạm tinh thần "backend trả nhãn khi nhãn đến
  từ 1 bảng quản lý được, chỉ để frontend map khi nhãn là hằng số cố định trong code" (xem
  `data-model.md`, đối chiếu với cách "PO name" ở List PO vẫn map ở frontend vì nguồn của nó là D365
  qua API tham chiếu dùng chung, không phải bảng CRUD nội bộ). (d) Thêm cột `RefType` là **generated/
  computed** ở tầng DB thay vì JOIN ở tầng ứng dụng — bị loại, over-engineering cho 1 JOIN đơn giản đã
  có sẵn hạ tầng repository phù hợp.
- **Rủi ro/giả định cần lưu ý khi implement**: bảng `eutr_reference_types` **đã có** trong
  `docs/design/eutr/eutr_db.sql` (kèm FK `eutr_references_reftype_foreign`) do feature `006` thêm vào,
  nhưng KHÔNG tìm thấy trong `ComplianceSys.Infrastructure/Sqls/Tables/eutr_db.sql` (bản DDL build) hay
  bất kỳ migration nào trong `Sqls/Migration/` — nghĩa là việc tạo bảng/FK này ở môi trường thật (nếu
  có) nằm ngoài quy trình migration đã theo dõi của feature `006`, không thuộc phạm vi sửa ở đây.
  Migration `14_seed_eutr_reference_types.sql` của Update 14 MUST tự phòng vệ bằng
  `CREATE TABLE IF NOT EXISTS eutr_reference_types (...)` (khớp đúng định nghĩa trong
  `docs/design/eutr/eutr_db.sql`) trước khi `INSERT`, để không phụ thuộc vào việc bảng đã được tạo ở
  môi trường đích hay chưa; migration này **KHÔNG** tự thêm FK `eutr_references_reftype_foreign` (giả
  định FK đó là trách nhiệm của quy trình rollout feature `006`, tránh lỗi "duplicate FK" nếu đã tồn
  tại và tránh mở rộng phạm vi migration này sang việc của feature khác).

## Quyết định 42 — Backend: tổng quát hóa upload theo Type bất kỳ, method mới `UploadMultipleForReferenceTypeAsync` (spec Update 15, FR-066 đến FR-069)

- **Decision**: Thêm method mới `UploadMultipleForReferenceTypeAsync(EutrTypeMultiUploadFileRequest
  request, string email, CancellationToken ct)` vào `IEutrUploadService`/`EutrUploadService` — request
  mới `{ List<IFormFile> Files, long TypeId, string TypeName, long StepId, List<string> RefValues }`.
  Với mỗi file hợp lệ (qua `ValidateFile` đã có, KHÔNG gọi `GetMatchingPrefixesAsync` — luồng này
  không còn giới hạn ở "PO" nên không áp dụng validate prefix của Update 7): 1 transaction ghi 1
  `eutr_documents` (giống hệt `UploadMultipleToSharePointAndSaveDataAsync`) và N bản ghi
  `eutr_references` (N = `request.RefValues.Count`, mỗi dòng `DocumentId` giống nhau, `StepId =
  request.StepId`, `RefType = (byte)request.TypeId`, `RefValue` = từng giá trị trong `RefValues`) —
  clone đúng cấu trúc try/BeginTransaction/Commit/Rollback đã có (Quyết định 14/18), chỉ khác số dòng
  `eutr_references` ghi ra (theo `RefValues` thay vì theo `StepId` khớp prefix).
- **Rationale**: Spec Update 15 yêu cầu một Type bất kỳ (không giới hạn "PO") có thể gắn nhiều giá trị
  tham chiếu (chip) cho cùng một lượt Upload — cấu trúc "1 file, N `eutr_references`" đã tồn tại từ
  Update 7 (ở đó N là số Step khớp prefix); Update 15 chỉ đổi nguồn của N từ "số Step khớp prefix"
  sang "số chip người dùng chọn", tái dùng đúng thiết kế bảng/transaction đã có, không cần đổi schema.
- **Alternatives considered**: (a) Tái sử dụng thẳng `UploadMultipleToSharePointAndSaveDataAsync` hiện
  có, thêm tham số optional cho `TypeId`/`RefValues` — bị loại, vì method đó gắn chặt với giả định
  `RefType=0` (PO) và có bước validate prefix bắt buộc (FR-032), không áp dụng cho Type khác; tách
  method mới có tên rõ ràng theo đúng phạm vi phù hợp hơn (Nguyên tắc II — giống cách Update 11 đã tách
  `UploadManualMultipleToSharePointAndSaveDataAsync` thay vì nhồi vào method PO). (b) Tạo
  `IEutrUploadService` mới hoàn toàn cho luồng này — bị loại, over-engineering khi service hiện có đã
  đủ dependency cần thiết.

## Quyết định 43 — Backend: suy thư mục SharePoint theo `Name` của Type, tái dùng `ResolveOrCreatePoFolderAsync` (spec Update 15, FR-067)

- **Decision**: Thêm 1 hàm private `ResolveFolderName(string typeName, List<string> refValues)` trong
  `EutrUploadService`: so khớp `typeName` không phân biệt hoa/thường — "po"/"vendor" → trả
  `refValues[0]` (đã đảm bảo đúng 1 giá trị ở tầng frontend, FR-064, nhưng backend vẫn lấy phần tử đầu
  tiên một cách phòng vệ); "invoice" → "Invoice"; "delivery note" → "DeliveryNote"; "general
  agreement" → "GeneralAgreement"; còn lại → tên Type đã loại bỏ khoảng trắng
  (`typeName.Replace(" ", "")`). Kết quả gọi thẳng `ResolveOrCreatePoFolderAsync(basePath,
  folderName)` **đã có sẵn** (Quyết định 13) — hàm này vốn đã tổng quát (nhận `folderName` bất kỳ,
  không riêng gì PO), chỉ cần gọi lại, không sửa.
- **Rationale**: `ResolveOrCreatePoFolderAsync` (dù tên hàm mang tiền tố "Po") thực chất chỉ nhận một
  chuỗi `folderName` và tìm/tạo thư mục con tương ứng — logic này đã đúng 100% với nhu cầu của Update
  15, nên tái dùng nguyên vẹn thay vì viết lại. Đặt bảng ánh xạ tên trong 1 hàm private nhỏ giữ business
  rule này ở đúng 1 chỗ, dễ mở rộng khi feature `006` thêm Type mới.
- **Alternatives considered**: Đổi tên `ResolveOrCreatePoFolderAsync` thành tên tổng quát hơn (ví dụ
  `ResolveOrCreateFolderAsync`) — cân nhắc nhưng KHÔNG bắt buộc cho phạm vi spec (đổi tên là refactor
  thuần túy, không ảnh hưởng hành vi); để tùy chọn khi implement, không phải quyết định thiết kế.

## Quyết định 44 — Backend: endpoint mới `eutr-upload-multi-by-type` trong `SharePointController` hiện có (spec Update 15, FR-066)

- **Decision**: Thêm `[HttpPost("eutr-upload-multi-by-type")] [Consumes("multipart/form-data")]` vào
  `SharePointController` hiện có — cùng route gốc `api/sharepoint` với `eutr-upload-multi` (Update 6)
  và `eutr-upload-manual-multi` (Update 11), dùng chung `[Authorize]` mức controller, không thêm
  policy riêng.
- **Rationale**: Nhất quán với ranh giới "route theo hành động, không theo entity" đã chốt từ Update 6
  — mọi hành vi "upload file EUTR thật lên SharePoint" nằm trong `SharePointController`, tách biệt
  hoàn toàn với `EutrDocumentsController` (CRUD `eutr_documents` thuần). Type/Step lấy qua 2 endpoint
  đã có sẵn của các feature khác (Quyết định 45), không cần endpoint GET/PUT nào thêm cho luồng này.
- **Alternatives considered**: Đặt endpoint mới vào `EutrDocumentsController` (giống
  `list-po-references` ở Update 8) — bị loại, vì hành động này là upload file thật lên SharePoint +
  tạo document, cùng bản chất với 2 action `eutr-upload-multi`/`eutr-upload-manual-multi` đã có, không
  phải một truy vấn đọc dữ liệu như `list-po-references`.

## Quyết định 45 — Frontend: nút Add mở Dialog mới thay vì điều hướng trang; `EutrDocumentsAdd.jsx` giữ nguyên, không xóa (spec Update 15/16, FR-059)

- **Decision**: `index.jsx` (danh sách chính) đổi nút Add từ `navigate('/eutr/documents/add')` sang mở
  state `addDialogOpen`, render `EutrDocumentsAddDialog` với `open`/`onClose`/`onUploaded` (đóng dialog
  + refetch danh sách). Route `/eutr/documents/add` (đăng ký ở `MainRoutes.jsx`) và component
  `EutrDocumentsAdd.jsx` (toàn bộ Screen1/Screen2, Update 3-11) **giữ nguyên trong codebase, không
  xóa, không sửa** — chỉ không còn được liên kết từ toolbar Add của danh sách chính.
- **Rationale**: Clarify Update 16 (Q1) xác nhận Edit (User Story 3) không đổi — `EutrDocumentsModal.jsx`/
  `AssignConditionDialog.jsx` là các component độc lập, không nằm trong/phụ thuộc `EutrDocumentsAdd.jsx`,
  nên việc gỡ liên kết Add không ảnh hưởng gì tới Edit. Xóa hẳn `EutrDocumentsAdd.jsx` (đã hoạt động
  qua 11 update liên tiếp) là một thao tác rủi ro cao, không mang lại lợi ích chức năng nào so với chỉ
  đơn giản không liên kết nó nữa — giữ lại làm dead code có chủ đích là lựa chọn an toàn hơn.
- **Alternatives considered**: (a) Xóa hẳn `EutrDocumentsAdd.jsx`, route, và mọi file con chỉ dùng bởi
  nó — cân nhắc nhưng bị loại cho phạm vi update này vì rủi ro/lợi ích không cân xứng, và spec không
  yêu cầu tường minh việc xóa. (b) Giữ route nhưng đổi nó thành redirect về danh sách — bị loại, không
  cần thiết vì không có yêu cầu nào trong spec về việc xử lý bookmark cũ.

## Quyết định 46 — Frontend: component mới `EutrAddValueAutocomplete.jsx`, KHÔNG sửa `ReferenceObjectMultiAutocomplete.jsx` dùng chung (spec Update 15, FR-062/FR-063/FR-065)

- **Decision**: Tạo component mới `EutrAddValueAutocomplete.jsx` (đặt trong
  `presentation/pages/eutr-documents/components/`, phạm vi riêng feature này) thay vì sửa
  `ReferenceObjectMultiAutocomplete.jsx` đã có. Component mới gọi trực tiếp `useReferenceObjects`
  (giống cách `ReferenceObjectMultiAutocomplete.jsx` đã làm) khi Type có nguồn gợi ý; validate token
  dán/gõ tay bằng cách gọi `fetchReferenceObjects(refType, token)` rồi tìm phần tử có `code` khớp
  chính xác (so sánh chữ thường, đã trim) trong kết quả trả về — nếu tìm thấy, thêm object đó làm chip
  (hiển thị nhất quán "code - name" như các nơi khác dùng chung dữ liệu tham chiếu); nếu không tìm
  thấy, bỏ qua token đó kèm cảnh báo.
- **Rationale**: `ReferenceObjectMultiAutocomplete.jsx` đang được `AssignConditionDialog.jsx` dùng cho
  "Condition value" — sửa trực tiếp component này để thêm hành vi paste-split/cap-1-giá-trị/free-text
  thuần cho Type không có nguồn sẽ làm tăng độ phức tạp props/nhánh rẽ của 1 component đang hoạt động
  ổn định, có rủi ro hồi quy cho luồng Assign condition (Update 11/12) vốn không nằm trong yêu cầu lần
  này. Tạo component mới, nhỏ, chỉ phục vụ đúng nhu cầu của popup Add giữ đúng ranh giới thay đổi
  (Nguyên tắc I) mà không đụng tới shared component.
- **Alternatives considered**: (a) Thêm prop điều kiện vào `ReferenceObjectMultiAutocomplete.jsx` dùng
  chung — bị loại vì lý do rủi ro hồi quy nêu trên, và 2 component có logic kiểm tra token khớp dữ
  liệu khác nhau đáng kể (component chung không cần paste-split vì Condition value luôn chọn qua
  dropdown, không có yêu cầu dán). (b) Validate token dán bằng cách tải toàn bộ danh sách PO/Vendor về
  client rồi so khớp cục bộ — bị loại, danh sách PO/Vendor từ D365 có thể rất lớn (API vốn thiết kế
  phân trang + tìm kiếm theo từ khóa phía server, xem Update 4/5), gọi lại API tìm chính xác từng token
  nhẹ hơn và nhất quán với mẫu tìm kiếm đã dùng ở Update 5.

## Quyết định 47 — Frontend: giới hạn 1 chip cho Type = "PO"/"Vendor" bằng cách chặn thêm, không tự thay thế (spec Update 15, FR-064)

- **Decision**: Trong handler thêm giá trị của `EutrAddValueAutocomplete.jsx`, khi tên Type (chữ
  thường) thuộc {"po", "vendor"} và đã có 1 chip, mọi thao tác thêm giá trị mới (chọn gợi ý, gõ tay xác
  nhận, dán) bị chặn — hiển thị thông báo yêu cầu xóa chip hiện có trước; input không bị disable hoàn
  toàn (người dùng vẫn gõ được để tìm kiếm) nhưng hành động "xác nhận thêm" bị vô hiệu hóa cho tới khi
  chip hiện có bị xóa.
- **Rationale**: Khớp đúng câu chữ FR-064 ("vô hiệu hóa việc thêm chip mới ... kèm thông báo yêu cầu
  xóa chip hiện có trước") — hành vi "chặn + báo" thay vì "tự động thay thế chip cũ" tránh mất dữ liệu
  người dùng đã chọn một cách âm thầm.
- **Alternatives considered**: Tự động thay thế chip cũ bằng giá trị mới khi Type là PO/Vendor — bị
  loại vì không khớp câu chữ spec ("vô hiệu hóa việc thêm", không phải "thay thế").

## Quyết định 48 — Frontend: dán nhiều giá trị tách theo dấu phẩy và/hoặc xuống dòng (spec Update 15, FR-065)

- **Decision**: Xử lý sự kiện paste: ngăn hành vi dán mặc định, đọc nội dung clipboard dạng văn bản,
  tách theo cả dấu phẩy lẫn ký tự xuống dòng trong cùng một lượt xử lý (khớp cả chuỗi trộn lẫn hai kiểu
  phân tách), loại khoảng trắng thừa và chuỗi rỗng. Với Type có nguồn gợi ý, validate từng token qua
  Quyết định 46; với Type không có nguồn, thêm thẳng từng token làm chip (không khử trùng lặp — khớp
  hình mẫu thiết kế cho phép 2 chip cùng nội dung).
- **Rationale**: Khớp đúng 2 ví dụ trong yêu cầu gốc ("po1, po2" và "po1 xuống dòng po2") — xử lý cả
  hai dạng cùng lúc mà không cần 2 nhánh code riêng biệt.
- **Alternatives considered**: Chỉ tách theo xuống dòng, yêu cầu người dùng tự xóa dấu phẩy — bị loại,
  không khớp ví dụ "po1, po2" nêu tường minh trong yêu cầu gốc.

## Quyết định 49 — Frontend: popup Add tự đóng ngay sau khi Upload hoàn tất (spec Update 16, FR-070)

- **Decision**: `EutrDocumentsAddDialog.jsx` — sau khi lượt Upload trả về kết quả: hiển thị snackbar
  (số file thành công/thất bại, giống mẫu đã có ở Update 6/11), sau đó gọi callback đóng dialog + báo
  danh sách chính tải lại — không có nút "Upload thêm" hay cơ chế giữ dialog mở để lặp lại nhiều lượt
  trong cùng một lần mở.
- **Rationale**: Khớp đúng quyết định đã xác nhận ở `/speckit-clarify` Update 16 (Q2) — mỗi lần mở
  popup Add chỉ thực hiện đúng 1 lượt Upload, đơn giản hóa việc quản lý trạng thái (không cần giữ lại
  Type/Step/chip sau khi đã upload xong).
- **Alternatives considered**: Giữ dialog mở, chỉ reset riêng Value/chip nhưng giữ Type/Step để cho
  phép Upload tiếp — bị loại theo đúng lựa chọn tường minh của người dùng ở Update 16 (single-shot).

## Quyết định 50 — Frontend: làm rõ tường minh việc ô Value tự xóa trống ngay sau khi thêm chip (spec Update 17, FR-071)

- **Decision**: Trong `EutrAddValueAutocomplete.jsx` (Quyết định 46), sau mỗi lần một giá trị được
  thêm thành công vào vùng chọn (qua chọn gợi ý, gõ tay xác nhận, hoặc mỗi token hợp lệ trong một
  lượt dán), gọi ngay hàm reset input text/`Autocomplete` value về rỗng trước khi xử lý token tiếp
  theo (nếu có, trong trường hợp dán nhiều giá trị) — hành vi này vốn đã ngụ ý trong cách một
  `Autocomplete` "thêm chip rồi clear input" thường hoạt động, nay được xác nhận là yêu cầu tường
  minh, không phải chi tiết triển khai tùy chọn.
- **Rationale**: FR-071 (Update 17) nêu rõ yêu cầu này trực tiếp — ghi nhận thành quyết định tường
  minh để tránh trường hợp triển khai giữ lại giá trị đã gõ trong input sau khi thêm chip (một biến
  thể UX phổ biến khác của combobox nhiều giá trị, nhưng không đúng yêu cầu ở đây).
- **Alternatives considered**: Giữ nguyên giá trị đã gõ/chọn trong ô Value sau khi thêm chip (để
  người dùng có thể "thêm lại gần giống") — bị loại, không khớp yêu cầu tường minh "value sẽ trống"
  của người dùng.

## Quyết định 51 — Frontend: khi Type = "PO", popup Add ẩn Step và tái sử dụng nguyên vẹn endpoint/use case `eutr-upload-multi` (Update 6/7) thay vì `eutr-upload-multi-by-type` (Update 15) — KHÔNG sửa backend (spec Update 17, FR-072 đến FR-075)

- **Decision**: `EutrDocumentsAddDialog.jsx` (Update 15) rẽ nhánh theo `Type.Name` khi nhấn Upload:
  nếu `Type.Name` (không phân biệt hoa/thường) = "PO" → ẩn control Step (không render, không gọi
  `GetEutrStepsUseCase`), và gọi lại use case đã có từ Update 6
  `UploadToSharePointUseCase.executeEutrMulti(files, poCode)` (POST
  `/api/sharepoint/eutr-upload-multi`, `EutrUploadService.UploadMultipleToSharePointAndSaveDataAsync`
  — đã validate prefix `eutr_master_documents` và ghi N `eutr_references`/`StepId` khớp Prefix từ
  Update 7) — thay vì `executeEutrMultiByType` (Update 15, `eutr-upload-multi-by-type`); với mọi
  Type khác, giữ nguyên hành vi Update 15/16 (Step bắt buộc, gọi `executeEutrMultiByType`).
- **Rationale**: Endpoint `eutr-upload-multi` (Update 6/7) **đã** triển khai chính xác toàn bộ hành
  vi Update 17 yêu cầu cho Type="PO" — validate prefix, tự xác định StepId (có thể nhiều dòng) theo
  `eutr_master_documents`, ghi `eutr_references` với `RefType = 0` (giá trị "PO" cứng, khớp đúng bản
  ghi `eutr_reference_types.Id = 0`/`Name = "PO"` đã seed từ Update 14) — tái sử dụng nguyên vẹn
  endpoint/service/migration đã có, **không cần sửa một dòng backend nào**, đúng tinh thần cao nhất
  của Nguyên tắc III (Reuse Existing Backend). Việc chọn PoCode qua chip Value (thay vì click 1 dòng
  List PO như luồng cũ) không ảnh hưởng hợp đồng API — `EutrMultiUploadFileRequest.PoCode` chỉ là
  một chuỗi mã PO, nguồn lấy giá trị đó (List PO cũ hay chip Value mới) là chi tiết UI, không phải
  hợp đồng backend.
- **Alternatives considered**: (a) Mở rộng `UploadMultipleForReferenceTypeAsync` (Update 15) để thêm
  nhánh validate-prefix-theo-nhiều-StepId riêng cho `TypeName == "PO"` — bị loại vì trùng lặp gần như
  toàn bộ logic đã có sẵn ở `UploadMultipleToSharePointAndSaveDataAsync`/`GetMatchingPrefixesAsync`
  (Update 7), vi phạm DRY và Nguyên tắc III; (b) Viết lại toàn bộ luồng PO trong popup Add bằng một
  method mới hoàn toàn — bị loại vì không có lý do nghiệp vụ nào khác với luồng PO gốc (Update 6/7),
  chỉ khác nguồn UI chọn giá trị.

## Quyết định 52 — Thêm `TypeId` (nullable) vào `EutrMultiUploadFileRequest`; `EutrUploadService` dùng giá trị này làm `RefType` khi có, giữ nguyên hằng số cũ làm fallback cho trang Add cũ (spec Update 18, FR-076/FR-077)

- **Decision**: Thêm 1 field mới `public long? TypeId { get; set; }` (không `[Required]`, để không phá
  vỡ caller cũ) vào `EutrMultiUploadFileRequest` (`compliance-sys-api/.../Dtos/Request/
  EutrMultiUploadFileRequest.cs`, Quyết định 12/Update 6). Trong `EutrUploadService.
  UploadMultipleToSharePointAndSaveDataAsync` (dòng ghi `EutrReferences` mới, hiện đang gán cứng
  `RefType = PoRefType`), đổi thành: `RefType = request.TypeId.HasValue ? (byte)request.TypeId.Value :
  PoRefType` — khi caller gửi kèm `TypeId`, dùng trực tiếp giá trị đó (đúng `Id` thật của Type "PO"
  đang được chọn ở popup Add, khớp cách các Type khác đã làm từ Update 15/Quyết định 42); khi không gửi
  (caller cũ), giữ nguyên hành vi hiện tại (hằng số `PoRefType = 0`) — không thay đổi hành vi của bất
  kỳ caller nào chưa được cập nhật. Frontend: `EutrDocumentsAddDialog.jsx` (nhánh `isPoType`, Update
  17/T228) truyền thêm `type.id` khi gọi `uploadToSharePointUseCase.executeEutrMulti(files, chips[0],
  type.id)`; `UploadToSharePointUseCase.executeEutrMulti` và `RestSharePointRepository.
  uploadEutrFilesMulti` (Update 6, Quyết định 12) nhận thêm tham số `typeId` và thêm vào `FormData`
  (`formData.append('typeId', typeId)`) khi có giá trị.
- **Rationale**: FR-076/FR-077 (Update 18) yêu cầu popup Add gửi kèm `TypeId` thật khi Type = "PO", và
  backend phải ghi đúng giá trị đó thay cho hằng số cố định — hằng số `PoRefType = 0` hiện tại **chỉ
  đúng vì Update 14 từng seed cưỡng bức `eutr_reference_types.Id = 0` cho "PO"** (Quyết định 41); từ
  khi feature `006-eutr-reference-types` cho phép CRUD tự do trên bảng này, giả định "PO" luôn có
  `Id = 0` không còn được đảm bảo. Nhận `TypeId` trực tiếp từ giá trị người dùng đã chọn ở dropdown Type
  (thay vì suy diễn/hard-code phía backend) loại bỏ hoàn toàn giả định này, khớp đúng cách các Type
  khác đã hoạt động ổn định từ Update 15. Giữ field `TypeId` là **nullable, không bắt buộc** — và giữ
  nguyên `PoRefType` làm fallback — để KHÔNG phá vỡ trang Add cũ độc lập `EutrDocumentsAdd.jsx`/route
  `/eutr/documents/add` (Update 6, vẫn còn tồn tại trong routing dù không còn được mở từ nút Add trên
  toolbar kể từ Update 15) — trang này không có control chọn Type nên không có `TypeId` nào để gửi;
  hành vi ghi `RefType` của nó giữ nguyên y hệt trước Update 18, không thuộc phạm vi FR-076/FR-077.
  Đây là thay đổi tối thiểu (1 field DTO nullable + 1 dòng ternary trong service + truyền thêm 1 tham
  số ở 3 file frontend), không cần migration DB (`eutr_references.RefType` đã là `TINYINT NULL` linh
  hoạt từ trước, Quyết định 41).
- **Alternatives considered**: (a) Đặt `TypeId` là `[Required]` trên DTO — bị loại vì sẽ làm hỏng lượt
  upload của trang Add cũ (`EutrDocumentsAdd.jsx`) nếu nó vẫn còn được truy cập trực tiếp qua URL,
  không có lợi ích nghiệp vụ tương xứng với rủi ro hồi quy; (b) Backend tự tra cứu động
  `eutr_reference_types` theo `Name = "PO"` (case-insensitive) làm fallback thay vì giữ hằng số cứng —
  cân nhắc nhưng bị loại vì thêm 1 truy vấn DB cho một nhánh chỉ phục vụ trang cũ đã bị thay thế hoàn
  toàn về mặt điều hướng (Update 15), không tương xứng độ phức tạp thêm vào so với lợi ích (Nguyên tắc
  IV — đơn giản); có thể cân nhắc lại nếu trang cũ bị xóa hẳn ở một dọn dẹp sau này; (c) Xóa hẳn hằng số
  `PoRefType` và trang Add cũ trong cùng lượt sửa này — bị loại vì nằm ngoài phạm vi yêu cầu của Update
  18 (chỉ yêu cầu sửa đúng `RefType` cho luồng popup Add, không yêu cầu dọn dẹp trang cũ).

## Quyết định 53 — Hợp nhất Add/Edit vào một component `EutrDocumentsFormDialog.jsx` qua prop `mode`; xóa hẳn trang Add cũ, popup Edit cũ, popup Assign condition (spec Update 19, FR-008/FR-026 đến FR-031/FR-059)

- **Decision**: Đổi tên `EutrDocumentsAddDialog.jsx` (Update 15-18) thành
  `EutrDocumentsFormDialog.jsx`, thêm 2 prop mới `mode: 'add' | 'edit'` và `initialData` (dữ liệu của
  đúng `row` grid đang sửa, xem Quyết định 59). Component hiển thị **cùng một layout** Type/Step/
  Value-chip/Valid from/Valid to cho cả 2 mode, chỉ khác: mode `add` hiển thị nút Upload + input file
  ẩn (không đổi hành vi Update 15-18, chỉ thêm 2 trường Valid from/to, xem Quyết định 55); mode `edit`
  khóa Type, chip Value chỉ đọc, ẩn `EutrAddValueAutocomplete`, thay nút Upload bằng Save. Xóa hoàn
  toàn (không giữ dead code): trang riêng `EutrDocumentsAdd.jsx` + route `/eutr/documents/add`
  (`RouteResolver.jsx`/`MainRoutes.jsx`), `EutrDocumentsModal.jsx` (popup Edit đơn giản cũ),
  `AssignConditionDialog.jsx` (popup Assign condition cũ, cả 2 mode create/edit).
- **Rationale**: Spec Update 19 nêu rõ bằng từ ngữ mạnh hơn hẳn các Update trước — "loại bỏ **hoàn
  toàn** khỏi phạm vi feature" — khác hẳn quyết định ở Update 15 (Quyết định 45) là **cố ý giữ lại**
  `EutrDocumentsAdd.jsx` làm dead code sau khi ngừng liên kết từ toolbar. Đây là một đảo ngược có chủ
  đích của quyết định đó (chính Quyết định 52 phía trên đã dự liệu khả năng này ở mục "Alternatives
  considered (c)"): 3 luồng Edit khác nhau theo Type (Update 12/13: popup đơn giản cho PO/trống, popup
  Assign condition cho Upload manual) không còn lý do tồn tại vì Edit giờ luôn là **một** popup duy
  nhất bất kể Type — giữ lại các file này sẽ là code chết không còn khả năng được kích hoạt lại bởi bất
  kỳ đường dẫn UI nào (khác Update 15, khi trang cũ vẫn còn truy cập được qua URL trực tiếp). Đổi tên
  file phản ánh đúng vai trò mới (không còn chỉ là "Add"), tránh để lại tên gây hiểu nhầm cho người đọc
  code sau này.
- **Alternatives considered**: (a) Giữ nguyên tên `EutrDocumentsAddDialog.jsx`, chỉ thêm prop `mode` —
  cân nhắc để giảm số dòng diff, nhưng bị loại vì tên file không còn mô tả đúng vai trò (component giờ
  xử lý cả Add lẫn Edit), gây nhầm lẫn lâu dài hơn giá trị tiết kiệm được từ việc không đổi tên; (b)
  Tiếp tục giữ `EutrDocumentsAdd.jsx`/`AssignConditionDialog.jsx`/`EutrDocumentsModal.jsx` như dead code
  (đúng tiền lệ Update 15) — bị loại vì spec lần này dùng từ ngữ khác hẳn ("loại bỏ hoàn toàn" thay vì
  im lặng không đề cập), và không giống Update 15 (khi route cũ vẫn có thể truy cập trực tiếp), ở đây
  **không còn state/API nào** mà 3 file này còn có thể gọi đúng (popup Assign condition phụ thuộc các
  endpoint sẽ bị xóa ở Quyết định 57) — giữ lại sẽ là code không biên dịch/không chạy được, không phải
  dead-code-nhưng-vẫn-hoạt-động như Update 15.

## Quyết định 54 — Cột Conditions đổi nguồn: `RefValue` phẳng từ `eutr_references`, bỏ hẳn `eutr_reference_details`/`ConditionGroupDto` (spec Update 19, FR-005)

- **Decision**: Mở rộng SQL có sẵn của `EutrReferencesRepository.GetStepInfoByDocumentIdsAsync`
  (Quyết định 20/41) thêm `r.RefValue` vào `SELECT`. `EutrDocumentsService.
  AttachStepAndConditionInfoAsync` đổi cách dựng `Conditions`: nhóm theo `DocumentId`, lấy
  `Distinct()` các `RefValue` khác `null`/rỗng (giữ thứ tự xuất hiện), gán vào field kiểu **mới**
  `List<string> Conditions` (thay `List<ConditionGroupDto>` của Update 11). Loại bỏ hoàn toàn khỏi
  service: lời gọi `IEutrReferenceDetailsRepository.GetGroupedConditionsByDocumentIdsAsync`, và (xem
  Quyết định 57) toàn bộ entity/repository/DTO liên quan tới `eutr_reference_details`.
- **Rationale**: FR-005 yêu cầu Conditions = mọi `RefValue` khác null của `eutr_references` thuộc
  document, hiển thị mỗi giá trị 1 chip — không còn phân biệt theo `ConditionType`/nhóm theo bảng con
  `eutr_reference_details` (bảng đó chỉ được ghi bởi popup Assign condition cũ, nay đã xóa ở Quyết
  định 53/57). Dùng `Distinct()` thay vì liệt kê nguyên văn mọi dòng để tránh chip trùng lặp khi Type
  = "PO" khớp nhiều `StepId` cho cùng 1 mã PO (N dòng `eutr_references` cùng `RefValue`, xem Quyết
  định 18/42) — spec không yêu cầu tường minh việc dedupe, nhưng hiển thị N chip giống hệt nhau cho
  cùng 1 giá trị không mang lại thông tin gì thêm cho người dùng và không khớp tinh thần "mỗi giá trị
  một chip" của FR-005 (ngụ ý các giá trị *phân biệt*).
- **Alternatives considered**: (a) Giữ nguyên `List<ConditionGroupDto>` (nhóm theo `ConditionType`) và
  chỉ đổi nguồn dữ liệu bên trong — bị loại vì `eutr_reference_details` không còn được ghi bởi bất kỳ
  luồng nào sau Update 19 (document Type="Upload manual" giờ cũng tạo qua popup Add hợp nhất, ghi
  `eutr_references.RefValue` trực tiếp, không qua Assign condition) — giữ shape nhóm theo Type cũ sẽ
  luôn trả về rỗng cho dữ liệu mới, sai lệch với ý định spec; (b) Không dedupe, trả nguyên văn mọi
  `RefValue` (kể cả trùng) — cân nhắc vì đơn giản hơn 1 dòng code, nhưng bị loại vì tạo trải nghiệm
  hiển thị gây hiểu nhầm (nhiều chip giống hệt nhau) cho đúng trường hợp phổ biến nhất của Type="PO"
  khớp nhiều Step.

## Quyết định 55 — Thêm Valid from/Valid to vào popup Add + 2 request upload hiện có; `EutrUploadService` dùng giá trị nhận được thay hằng số Today/`9999-12-31` cố định (spec Update 19, FR-014/FR-015/FR-021)

- **Decision**: Thêm 2 trường ngày mới vào `EutrDocumentsFormDialog.jsx` (mode `add`): `validFrom`
  (mặc định `DateTime.Today`), `validTo` (mặc định `9999-12-31`), cả hai dùng MUI `DatePicker` sẵn có
  trong repo (cùng loại control đã dùng ở `EutrDocumentsModal.jsx` cũ), editable trước khi nhấn Upload.
  Validate `validFrom <= validTo` phía client (chặn Upload + hiển thị lỗi inline khi vi phạm, FR-016).
  Thêm 2 field nullable `ValidFrom (DateTime?)`, `ValidTo (DateTime?)` vào **cả 2** request DTO đang
  dùng cho Upload: `EutrMultiUploadFileRequest` (nhánh Type="PO", Quyết định 12/52) và
  `EutrTypeMultiUploadFileRequest` (nhánh Type khác, Quyết định 44). Trong `EutrUploadService`, tại 2
  nơi hiện đang gán cứng `ValidFrom = DateTime.Today` / `ValidTo = MaxValidTo` (hằng số
  `9999-12-31`), đổi thành `request.ValidFrom ?? DateTime.Today` / `request.ValidTo ?? MaxValidTo` —
  giữ đúng 2 hằng số cũ làm giá trị mặc định khi request không gửi (an toàn, không phá vỡ hợp đồng cũ
  nếu có caller nào khác trong tương lai không gửi field này).
- **Rationale**: FR-014/FR-015/FR-021 yêu cầu Valid from/Valid to hiển thị sẵn giá trị mặc định nhưng
  MUST cho phép sửa trước khi Upload, và document tạo ra MUST dùng đúng giá trị đang hiển thị tại thời
  điểm Upload — 2 giá trị này trước đây bị hard-code hoàn toàn trong `EutrUploadService` (Update 6),
  không có đường truyền nào từ client. Mẫu ternary `request.X ?? default` giống hệt cách `TypeId`
  (Quyết định 52) đã được thêm an toàn vào cùng request DTO này — tái dùng đúng pattern vừa áp dụng.
- **Alternatives considered**: (a) Bắt buộc (`[Required]`) 2 field mới trên request DTO — bị loại vì
  không cần thiết (client luôn có giá trị mặc định sẵn để gửi, không có kịch bản "thiếu giá trị" hợp
  lệ) và làm phức tạp hoá contract không cần thiết; (b) Validate `ValidFrom <= ValidTo` thêm ở
  backend (FluentValidation) — cân nhắc như một lớp phòng vệ kép, nhưng bị loại ở phạm vi tối thiểu vì
  đây là luồng nội bộ 1 popup duy nhất đã validate chặt ở client trước khi cho phép nhấn Upload/Save,
  không có API nào khác gọi trực tiếp 2 endpoint upload này — có thể bổ sung sau nếu phát sinh caller
  thứ 2.

## Quyết định 56 — Đơn giản hóa `PUT /api/eutr-documents/{id}/step`: bỏ logic PO-only xóa/tạo lại, thay bằng UPDATE `StepId` hàng loạt cho mọi `eutr_references` của document, dùng chung cho mọi Type; đổi tên DTO cho đúng vai trò mới (spec Update 19, FR-029/FR-033)

- **Decision**: Thêm method mới `Task UpdateStepIdByDocumentIdAsync(long documentId, long stepId,
  string updatedBy, CancellationToken ct)` vào `IEutrReferencesRepository`/`EutrReferencesRepository`
  (raw SQL, cùng style 2 method ghi/xóa hiện có): `UPDATE eutr_references SET StepId = @StepId,
  UpdatedBy = @UpdatedBy, UpdatedDate = @UpdatedDate WHERE DocumentId = @DocumentId;`. Thêm method mới
  `UpdateReferenceStepAsync(long documentId, long stepId, string userEmail, CancellationToken ct)`
  **trực tiếp trong `EutrDocumentsService`** (không qua `IEutrConditionAssignmentService` — service đó
  bị xóa hoàn toàn, xem Quyết định 57) gọi thẳng method trên. Action controller `[HttpPut("{id:long}/
  step")]` (giữ nguyên route) đổi từ gọi `_conditionAssignmentService.UpdatePoStepAsync(...)` sang
  `_eutrDocumentsService.UpdateReferenceStepAsync(...)`. Đổi tên `EutrUpdatePoStepRequestDto` →
  `EutrUpdateReferenceStepRequestDto` (cùng shape `{ long StepId }`) để phản ánh đúng việc endpoint
  không còn riêng cho Type="PO".
- **Rationale**: FR-029/FR-033 (Save trong popup Edit) yêu cầu một hành vi **đơn giản hơn hẳn** hành vi
  cũ của Update 12/13: cập nhật `StepId` của **mọi** bản ghi `eutr_references` hiện có của document
  thành Step mới, **giữ nguyên** `RefValue`/`RefType`/số lượng bản ghi — không xóa/tạo lại bản ghi nào,
  áp dụng đồng nhất cho **mọi** Type (không còn phân biệt PO/Upload manual/Type khác). Đây thực ra là
  phép `UPDATE` một cột duy nhất theo điều kiện `DocumentId` — đơn giản hơn cả 2 cơ chế cũ nó thay thế
  (Update 12: xóa-toàn-bộ-tạo-lại-1-dòng cho PO; Update 12b tương tự cho Upload manual qua
  `UpdateConditionAssignmentAsync`), và không cần biết trước `RefValue`/`RefType` hiện tại (khác quy
  tắc cũ phải đọc trước "dòng có `Id` nhỏ nhất" để giữ lại `RefValue`). Đặt method mới trong
  `EutrDocumentsService` (không tạo lại service riêng) vì `IEutrConditionAssignmentService` không còn
  lý do tồn tại sau khi xóa toàn bộ luồng Assign condition (Quyết định 57) — chỉ còn đúng 1 hành vi
  "sửa Step" cần giữ lại, đặt cạnh `DeleteAsync`/`DeleteMultiAsync` override đã có sẵn trong cùng file
  là đủ (Nguyên tắc II — không giữ một service Application chỉ để chứa 1 method).
- **Alternatives considered**: (a) Giữ `IEutrConditionAssignmentService` chỉ với đúng 1 method
  `UpdateReferenceStepAsync` còn lại — bị loại, một service Application chỉ bọc 1 lệnh `UPDATE` đơn
  giản không mang lại giá trị tách lớp nào, thêm 1 file/interface không cần thiết (yagni); (b) Gộp
  logic sửa Step vào ngay `EutrDocumentsService.UpdateAsync` (override) để chỉ cần 1 lệnh gọi API thay
  vì 2 — bị loại vì `EutrDocumentsRequestDto`/`UpdateAsync` là CRUD chuẩn dùng chung, không có chỗ cho
  `StepId` (tương tự lý do Quyết định 11 tách `EutrUploadService` khỏi `IEutrDocumentsService.
  AddAsync`); giữ 2 lời gọi API riêng biệt (đã là pattern có sẵn từ Update 12, Quyết định 38 — frontend
  `index.jsx`/nay `EutrDocumentsFormDialog.jsx` gọi tuần tự Update rồi step) tránh mở rộng phạm vi DTO
  CRUD chung.

## Quyết định 57 — Xóa hoàn toàn luồng Assign condition: service, entity/repository `eutr_reference_details`, 5 endpoint liên quan, cùng mọi DTO/use case/component chỉ phục vụ luồng đó (spec Update 19, "loại bỏ hoàn toàn khỏi phạm vi feature")

- **Decision**: Xóa: `IEutrConditionAssignmentService.cs`/`EutrConditionAssignmentService.cs`,
  `EutrReferenceDetails.cs` (entity), `IEutrReferenceDetailsRepository.cs`/
  `EutrReferenceDetailsRepository.cs`, `EutrManualMultiUploadFileRequest.cs`,
  `EutrAssignConditionsRequestDto.cs` (+ validator), `EutrConditionRowDto.cs`,
  `EutrUpdateConditionAssignmentRequestDto.cs` (+ validator), `EutrDocumentConditionAssignmentDto.cs`,
  `ConditionGroupDto.cs`, `EutrConditionGroupRow.cs`. Xóa 4 action khỏi `EutrDocumentsController`:
  `POST get-unassigned`, `POST assign-conditions`, `GET`/`PUT {id}/condition-assignment`; xóa
  `EutrDocumentsService.GetUnassignedPagedAsync`; xóa
  `IEutrReferencesRepository.GetUnassignedDocumentsPagedAsync`; xóa action
  `[HttpPost("eutr-upload-manual-multi")]` khỏi `SharePointController` cùng
  `EutrUploadService.UploadManualMultipleToSharePointAndSaveDataAsync`. Xóa DI registration tương ứng.
  Frontend: xóa use case `AssignEutrConditionsUseCase`, `GetEutrDocumentConditionAssignmentUseCase`,
  `UpdateEutrConditionAssignmentUseCase`, `GetEutrDocumentsUnassignedUseCase`; xóa method tương ứng
  khỏi `IEutrDocumentsRepository.js`/`RestEutrDocumentsRepository.js`/`eutrDocumentsApi.js`
  (`getUnassigned`, `assignConditions`, `getConditionAssignment`, `updateConditionAssignment`) và khỏi
  `ISharePointRepository.js`/`RestSharePointRepository.js`/`UploadToSharePointUseCase.js`
  (`uploadEutrManualFilesMulti`/`executeManualMulti`); xóa hằng số `CONDITION_TYPE_OPTIONS`
  (`utils/helpers.js`) nếu không còn nơi nào khác dùng tới (xác nhận lại khi implement — task-level
  concern, không phải quyết định thiết kế). Đổi tên `UpdateEutrDocumentPoStepUseCase.js` →
  `UpdateEutrDocumentReferenceStepUseCase.js` (khớp Quyết định 56, dùng bởi `EutrDocumentsFormDialog.jsx`
  ở mode edit thay vì `index.jsx`).
- **Rationale**: Toàn bộ các endpoint/DTO/component này chỉ tồn tại để phục vụ 2 luồng mà spec Update
  19 xác nhận đã bị loại bỏ hoàn toàn khỏi phạm vi feature: trang Add cũ (List PO/bảng "chưa gán") và
  popup Assign condition (cả 2 mode create/edit). Khảo sát toàn bộ call site (xem báo cáo khảo sát khi
  lập kế hoạch) xác nhận không còn điểm gọi nào khác ngoài các file/luồng vừa liệt kê — an toàn để xóa
  hẳn thay vì giữ làm dead code (khác quyết định ở Update 15/Quyết định 45, nơi trang cũ **vẫn còn
  đường dẫn URL trực tiếp** có thể kích hoạt lại được). Bảng `eutr_reference_details` **không bị xóa/
  migrate** — chỉ không còn entity/repository backend nào đọc/ghi nó nữa, đúng theo Assumptions đã
  chốt ở spec ("dữ liệu cũ giữ nguyên trong schema nhưng không còn được hiển thị/chỉnh sửa qua màn
  hình này").
- **Alternatives considered**: (a) Chỉ ngừng liên kết (giữ file như dead code, đúng tiền lệ Update 15)
  — bị loại, xem lý do đối chiếu ở Quyết định 53 (từ ngữ spec khác hẳn, và các file này phụ thuộc lẫn
  nhau + phụ thuộc endpoint sắp xóa nên giữ lại sẽ không còn biên dịch/chạy được, khác hẳn trường hợp
  Update 15 nơi trang cũ độc lập, tự đủ, vẫn chạy được qua URL trực tiếp); (b) Xóa file nhưng giữ lại
  route/endpoint rỗng (trả lỗi 410 Gone) để không phá vỡ client cũ nào còn gọi — bị loại, không có bất
  kỳ client nào khác ngoài chính SPA này gọi các endpoint đó (không phải API công khai cho bên thứ 3),
  không cần thiết duy trì tương thích ngược.
- **⚠️ Điều chỉnh khi implement (`/speckit-implement`)**: Khảo sát call site ban đầu (thực hiện khi
  lập kế hoạch) **bỏ sót** một điểm gọi ngoài phạm vi feature `004-eutr-documents`: trang
  `ViewSalesOrderPage.jsx` của feature khác **`eutr-sales-orders`** gọi
  `GetEutrDocumentsPoReferencesUseCase` (→ `getPoReferences` → `POST /api/eutr-documents/
  list-po-references` → `EutrDocumentsService.GetPoReferencesAsync` →
  `IEutrReferencesRepository.GetDocumentsByPoCodesAsync`) để suy diễn trạng thái "đã map" ở mục
  Template Checklist (JOIN theo mã PO đã lưu trong `eutr_purchase_attachments`). Phát hiện qua
  `npx vite build` thất bại (`ENOENT ... GetEutrDocumentsPoReferencesUseCase`) ngay sau khi xóa file
  này theo kế hoạch ban đầu. **Đã khôi phục nguyên vẹn** (không đổi shape/hành vi) toàn bộ chuỗi
  `EutrDocumentsListPoReferencesRequestDto.cs`/`EutrDocumentsPoReferenceDto.cs`/
  `EutrDocumentsPoReferenceItemDto.cs`/`EutrReferencePoDocumentInfo.cs`/
  `GetDocumentsByPoCodesAsync`/`GetPoReferencesAsync`/action `list-po-references`/
  `GetEutrDocumentsPoReferencesUseCase.js`/`getPoReferences`/`listPoReferences` — bảng trong Decision
  ở trên đã được cập nhật để phản ánh đúng danh sách xóa cuối cùng (không còn liệt kê nhóm List-PO).
  Bài học: khảo sát call site cho quyết định xóa code phải quét **toàn bộ monorepo** (cả các feature
  khác dùng chung `application/usecases/eutr-documents/*`), không chỉ trong thư mục
  `presentation/pages/eutr-documents/` — endpoint/use case CRUD của 1 feature hoàn toàn có thể bị
  feature khác tái sử dụng làm nguồn tra cứu read-only.

## Quyết định 58 — Giữ nguyên SQL 2 bước của `DeleteByDocumentIdAsync` (dọn `eutr_reference_details` mồ côi trước khi xóa `eutr_references`) dù feature không còn ghi bảng đó (spec Update 19)

- **Decision**: KHÔNG rút gọn lại `EutrReferencesRepository.DeleteByDocumentIdAsync` (Quyết định 30,
  Update 11) về lại 1 câu `DELETE FROM eutr_references WHERE DocumentId = @DocumentId` như trước
  Update 11 — giữ nguyên 2 câu `DELETE` (xóa `eutr_reference_details` con trước qua subquery `RefId IN
  (SELECT Id FROM eutr_references WHERE DocumentId = @DocumentId)`, rồi mới xóa `eutr_references`).
- **Rationale**: Khóa ngoại `eutr_reference_details_refid_foreign` (KHÔNG có `ON DELETE CASCADE`) vẫn
  tồn tại trong schema, và dữ liệu lịch sử tạo bởi popup Assign condition cũ (Update 11-13, trước khi
  tính năng đó bị xóa ở Update 19) vẫn còn nguyên trong `eutr_reference_details` theo đúng Assumptions
  đã chốt ("dữ liệu cũ giữ nguyên trong schema"). Nếu rút gọn lại còn 1 câu `DELETE`, xóa một document
  Type="Upload manual" cũ (tạo trước Update 19, còn `eutr_reference_details` liên kết) sẽ vi phạm khóa
  ngoại và làm hỏng chức năng Delete (User Story 4) cho đúng nhóm dữ liệu lịch sử này — một hồi quy
  nghiêm trọng hơn nhiều so với lợi ích đơn giản hóa 1 câu SQL không còn đường ghi mới nào tạo ra dữ
  liệu ở bảng đó.
- **Alternatives considered**: (a) Rút gọn về 1 câu DELETE vì "feature không còn dùng bảng đó" — bị
  loại vì lý do trên (phá vỡ Delete cho dữ liệu lịch sử); (b) Thêm `ON DELETE CASCADE` vào khóa ngoại
  qua 1 migration mới rồi rút gọn SQL — bị loại, vượt phạm vi yêu cầu Update 19 (không yêu cầu sửa
  schema `eutr_reference_details`), và thay đổi ràng buộc DB có thể ảnh hưởng phạm vi rộng hơn phạm vi
  feature này (bảng đó vẫn được thiết kế tổng thể coi là thuộc sở hữu chung, không riêng feature này).

## Quyết định 59 — Frontend: Edit nạp dữ liệu trực tiếp từ `row` grid đã có (không gọi API round-trip mới) (spec Update 19, FR-026)

- **Decision**: `EutrDocumentsFormDialog.jsx` (mode `edit`) nhận `initialData = row` (chính dòng
  DataGrid đang hiển thị, đã có sẵn `refType`, `typeName`, `stepId`, `conditions` (nay là
  `string[]` phẳng, Quyết định 54), `validFrom`, `validTo` từ response `get-all` hiện có) — KHÔNG gọi
  thêm API nào để tải lại dữ liệu document khi mở popup Edit. Type field: tìm phần tử khớp `id ===
  initialData.refType` trong danh sách `referenceTypes` đã tải sẵn (giống Add, qua
  `GetEutrReferenceTypesUseCase`) để hiển thị (disabled). Step field: tìm phần tử khớp `id ===
  initialData.stepId` trong danh sách `steps` đã tải sẵn (giống Add, qua `GetEutrStepsUseCase`) làm
  giá trị ban đầu (editable). Chip: hiển thị trực tiếp `initialData.conditions` (đọc-only, không qua
  `EutrAddValueAutocomplete`).
- **Rationale**: Tiếp nối tinh thần "0 round-trip HTTP mới" đã áp dụng nhất quán từ Update 13 (Quyết
  định 38, `EutrDocumentsResponseDto.StepId`) và Update 8 (Quyết định 22) — mọi dữ liệu cần cho popup
  Edit **đã có sẵn** trên `row` vì chính `get-all` (Update 8/11/13/14) đã tính đủ `refType`/`typeName`/
  `stepId`/`conditions` cho mục đích hiển thị cột grid; tái dùng luôn cho popup Edit tránh thêm 1 GET
  endpoint chỉ để lấy lại dữ liệu đã có trong tay (khác hẳn Update 11/12 cũ, nơi
  `GET {id}/condition-assignment` là cần thiết vì `Conditions` grouped-by-type khi đó KHÔNG có trên
  response `get-all` chuẩn cho mọi Type — nay không còn đúng vì Conditions đã đơn giản hoá thành
  `RefValue` phẳng, sẵn có trên mọi dòng).
- **Alternatives considered**: (a) Giữ 1 endpoint `GET {id}` chuyên dụng để tải lại dữ liệu Edit (như
  `condition-assignment` cũ) — bị loại, không cần thiết vì dữ liệu đã có đủ trên `row`, thêm round-trip
  không có lợi ích (Nguyên tắc III/YAGNI); (b) Gọi lại `GET get-by-id/{id}` (endpoint CRUD chuẩn, trả
  raw entity `EutrDocuments`, không có `refType`/`stepId`/`conditions`) — bị loại, thiếu đúng những
  field popup Edit cần, sẽ phải mở rộng response của endpoint này chỉ để phục vụ 1 popup trong khi
  `get-all` đã tính sẵn.

## Quyết định 60 — Quy tắc ẩn/hiện Step khác nhau giữa mode Add và mode Edit của cùng 1 dialog (spec Update 19, FR-010/FR-029/FR-034)

- **Decision**: `EutrDocumentsFormDialog.jsx` tính điều kiện hiển thị Step **khác nhau theo mode**:
  mode `add` → `showStep = !isPoType` (không đổi so với Update 17, Quyết định 51 — PO ẩn Step, Type
  khác hiện); mode `edit` → `showStep = initialData.refType != null` (hiện Step bất kể Type là gì, kể
  cả Type="PO" — chỉ ẩn khi document hoàn toàn không có bản ghi `eutr_references` nào, tức Type/chip
  cũng trống). Khi Step hiển thị ở mode `edit`, MUST chọn sẵn giá trị hiện tại (Quyết định 59) và vẫn
  bắt buộc phải có giá trị trước khi Save khả dụng.
- **Rationale**: FR-010 (Add) và FR-029/FR-034 (Edit) mô tả 2 quy tắc **khác nhau có chủ đích**: Add ẩn
  Step cho Type="PO" vì Step được suy tự động theo Prefix tên file (Quyết định 51 — không có Step đơn
  để hiển thị trước khi biết file nào được chọn); Edit luôn cho sửa Step (kể cả Type="PO") vì tại thời
  điểm Edit, document đã tồn tại với 1 giá trị Step cụ thể (dòng `Id` nhỏ nhất, Update 13) cần hiển thị
  và cho phép đổi — không còn tình huống "chưa biết file nào". Đây là lý do chính khiến dialog cần
  tham số hóa điều kiện này theo `mode` thay vì dùng chung 1 biểu thức `isPoType` cho cả 2 mode.
- **Alternatives considered**: Dùng chung đúng 1 quy tắc `showStep = !isPoType` cho cả 2 mode — bị
  loại, trái trực tiếp FR-029 ("Step MUST vẫn khả dụng để sửa" không có ngoại lệ theo Type) — sẽ khiến
  Edit một document Type="PO" không thể sửa Step, vi phạm User Story 3 hoàn toàn cho nhóm Type phổ
  biến nhất.

## Quyết định 61 — Combobox Step lọc theo `eutr_reference_type_details`: tái sử dụng nguyên vẹn hạ tầng đã có sẵn của feature `006-eutr-reference-types`, 0 dòng backend mới (spec Update 20, FR-043 đến FR-045)

- **Decision**: `EutrDocumentsFormDialog.jsx` gọi lại use case **đã tồn tại sẵn**
  `GetByTypeIdEutrReferenceTypeDetailsUseCase` (`compliance-client/src/application/usecases/
  eutr-reference-type-details/GetByTypeIdEutrReferenceTypeDetailsUseCase.js`, instantiate với
  `repositories.eutrReferenceTypeDetails` đã đăng ký sẵn trong `di/repositories.js`) — use case này gọi
  `GET /api/eutr-reference-type-details/by-type/{typeId}` (`EutrReferenceTypeDetailsController`, policy
  `EutrReferenceTypes.ReadOne`), toàn bộ entity/repository/service/controller/policy cho endpoint này
  **đã được xây dựng đầy đủ** bởi feature `006` (Assign Steps) — feature `004` chỉ **tiêu thụ read-only**,
  không thêm bất kỳ file/dòng backend nào. Kết quả trả về (`{ id, typeId, stepId, stepName, ... }[]`,
  sắp xếp `ORDER BY d.CreatedDate DESC` do repository quyết định — không có tham số sắp xếp nào khác)
  được map sang hình dạng `{ id: stepId, name: stepName }` mà `Autocomplete` Step hiện có đang kỳ vọng;
  ưu tiên đối chiếu `stepId` với mảng `steps` đầy đủ đã tải sẵn bởi `getEutrStepsUseCase` (Update 15) để
  giữ đúng object reference hiện dùng trong `isOptionEqualToValue`, dùng thẳng `stepName` của response
  làm fallback nếu không khớp (trường hợp Step đã bị xóa khỏi `eutr_steps` sau khi được gán — hiếm,
  không chặn hiển thị). Gọi lại use case này mỗi khi `type` đổi ở mode `add`, và một lần khi mở popup ở
  mode `edit` (dùng `initialData`'s Type, vì Type đã khóa — không đổi trong suốt vòng đời popup Edit).
  Mode `add`: sau khi danh sách lọc tải xong, `setStep(filteredSteps[0] ?? null)` (FR-044). Mode `edit`:
  nếu Step hiện tại của document (từ `initialData`, xác định theo Quyết định 59 — bản ghi `Id` nhỏ
  nhất) không có mặt trong danh sách đã lọc (đã bị gỡ khỏi Assign Steps sau khi document được tạo),
  chèn thêm chính Step đó vào đầu mảng hiển thị thay vì loại bỏ, và **không** đổi giá trị `step` đang
  chọn sang mặc định khác (FR-045). Type = "PO" không đổi — `isPoType` tiếp tục ẩn hẳn Step, không gọi
  use case này (Quyết định 51/60 không đổi).
- **Rationale**: Khảo sát codebase trước khi lập kế hoạch xác nhận **toàn bộ** hạ tầng cần thiết đã tồn
  tại sẵn từ feature `006`: entity `EutrReferenceTypeDetails`, repository
  `IEutrReferenceTypeDetailsRepository`/`EutrReferenceTypeDetailsRepository.GetByTypeIdAsync` (SQL JOIN
  `eutr_reference_type_details`+`eutr_steps`, lọc `WHERE d.TypeId = @typeId`), controller action
  `GetByTypeId` (`GET .../by-type/{typeId}`), và toàn bộ tầng frontend tương ứng (domain entity, infra
  repository, API client, use case, đăng ký DI) — được dùng bởi màn `AssignStepsPage.jsx` của feature
  `006` nhưng không có gì đặc thù riêng cho feature đó, hoàn toàn tái sử dụng được read-only từ feature
  `004`. Đây là mức áp dụng cao nhất của Nguyên tắc II (Reference-Pattern Reuse)/III (Reuse Existing
  Backend) trong lịch sử feature này kể từ Update 17 (0 dòng backend mới) — viết lại 1 endpoint/repository
  tương đương ở `004` sẽ là trùng lặp thuần túy, vi phạm trực tiếp Nguyên tắc III.
- **Alternatives considered**: (a) Tạo endpoint/repository JOIN mới riêng cho `004` (ví dụ mở rộng
  `IEutrReferencesRepository`) — bị loại, trùng lặp hoàn toàn logic đã có ở `006`, không có lý do
  nghiệp vụ nào cần tách biệt; (b) Đổi `GetEutrStepsUseCase` hiện có (tải toàn bộ `eutr_steps`) để nhận
  thêm tham số lọc theo Type — bị loại, use case này được nhiều nơi khác trong hệ thống dùng để tải
  *toàn bộ* Step (không có khái niệm Type), thêm tham số lọc sẽ phá vỡ hợp đồng dùng chung của nó; (c)
  Bỏ qua việc đối chiếu với `steps` đầy đủ, dựng thẳng `{id, name}` từ mỗi response item — được cân nhắc
  nhưng giữ bước đối chiếu để tránh 2 object khác instance cùng biểu diễn 1 Step gây lệch
  `isOptionEqualToValue` nếu `Autocomplete` so sánh theo reference ở đâu đó khác trong component (phòng
  vệ rẻ, không tốn thêm round-trip HTTP).
- **Cân nhắc permission (không phải rào cản mới)**: Endpoint `by-type/{typeId}` dùng policy
  `EutrReferenceTypes.ReadOne` — khác nhóm policy `EutrDocuments.*` của feature này. Đây **không phải
  vấn đề mới phát sinh** từ Update 20: dialog này đã gọi không điều kiện 2 endpoint thuộc 2 feature khác
  từ Update 15/16 (`GET /api/eutr-reference-types` cho dropdown Type, `GET /api/eutr-steps` cho Step
  không lọc) mà không cần policy `EutrDocuments.*` bao trùm chúng — người dùng có quyền mở popup Add/
  Edit của `004` được giả định (qua cấu hình role/menu ở DB, ngoài phạm vi code — Nguyên tắc V, Quyết
  định 7) đã có sẵn quyền đọc dữ liệu tham chiếu của `eutr_steps`/`eutr_reference_types`/nay thêm
  `eutr_reference_type_details`. Không cần thay đổi/thêm policy nào ở phạm vi feature `004-eutr-documents`.

## Quyết định 62 — Search box lọc qua "cột filter ảo" trên endpoint `get-all` hiện có, KHÔNG endpoint mới (spec Update 21, FR-046/FR-047)

- **Decision**: KHÔNG tạo endpoint/DTO request mới cho search box. `EutrDocumentsController`'s
  `POST /api/eutr-documents/get-all` (đã nhận `[FromQuery] page,pageSize,sortColumn,sortOrder` +
  `[FromBody] List<FilterRequest>? filters`, xem `EutrDocumentsController.GetPaged`) giữ nguyên chữ
  ký — search box chỉ gửi thêm, bên trong `filters` đã có, tối đa 3 phần tử với `Column` ∈
  `{"TypeId", "StepId", "Conditions"}` (ví dụ `{ column: "TypeId", operator: "=", value: 3 }`).
  `EutrDocumentsService.GetPagedAsync` (đã override `base.GetPagedAsync` từ trước để gọi
  `AttachStepAndConditionInfoAsync`) MỚI thêm 1 bước **trước** khi gọi `base.GetPagedAsync`: rút 3
  filter này ra khỏi `request.Filters` (so khớp `Column` không phân biệt hoa/thường, loại khỏi list
  gửi xuống repository generic), đọc `typeId`/`stepId`/`conditionsQuery` từ chúng.
- **Rationale**: Khảo sát xác nhận generic repository (`Shared.Dapper.Repositories.BaseRepository.
  GetPagedAsync`, decompiled qua ilspycmd — package `Res.Shared.Dapper` chỉ có sẵn dưới dạng NuGet,
  không có source trong repo) build WHERE clause bằng cách tra `Column` (không phân biệt hoa/thường)
  vào **whitelist property** của chính `TEntity` (`EutrDocuments`) qua reflection — cột không tồn tại
  trên entity bị **âm thầm bỏ qua** (không lỗi, không cảnh báo). Nghĩa là gửi thẳng `TypeId`/`StepId`/
  `Conditions` vào `filters` mà không rút ra trước sẽ không có tác dụng gì (silently ignored) — bắt
  buộc phải xử lý ở tầng `EutrDocumentsService` (Application), nơi duy nhất biết về mối quan hệ
  `eutr_documents` ↔ `eutr_references`. Không tạo endpoint mới giữ đúng path/contract công khai
  (`get-all`) mà mọi client hiện có (bao gồm cả các nơi khác trong SPA có thể gọi endpoint này) không
  bị ảnh hưởng — đúng tinh thần Nguyên tắc III (Reuse Existing Backend).
- **Alternatives considered**: (a) Tạo endpoint mới riêng (ví dụ `POST /api/eutr-documents/search`)
  với DTO request tường minh `{ typeId, stepId, conditions, page, pageSize, ... }` — bị loại, trùng
  lặp gần như toàn bộ logic phân trang/sắp xếp đã có ở `get-all`, và tách 2 nguồn dữ liệu cho cùng 1
  bảng làm tăng rủi ro lệch hành vi giữa "xem danh sách" và "tìm kiếm"; (b) Thêm field tường minh mới
  vào 1 DTO request riêng cho `get-all` (thay vì tái dùng `FilterRequest` sẵn có) — bị loại, endpoint
  hiện tại không có DTO request riêng nào (dùng thẳng `PagedRequest`/`FilterRequest` generic của
  `Shared.Dapper`), thêm DTO mới sẽ phá vỡ đúng cơ chế "mọi lọc đi qua `List<FilterRequest>`" đã nhất
  quán trên toàn bộ các endpoint `get-all` của hệ thống.

## Quyết định 63 — `GetMatchingDocumentIdsAsync`: 3 `EXISTS` độc lập, không cùng 1 dòng `eutr_references` (spec Update 21, FR-048)

- **Decision**: Thêm method mới vào `IEutrReferencesRepository`/`EutrReferencesRepository` (đã tồn
  tại từ Update 8, cạnh 4 method hiện có):
  ```csharp
  Task<List<long>> GetMatchingDocumentIdsAsync(
      long? typeId, long? stepId, string? conditionsQuery, CancellationToken ct = default);
  ```
  SQL (raw, cùng style `Connection.QueryAsync`/`CommandDefinition` đã dùng ở 4 method hiện có của
  repository này):
  ```sql
  SELECT d.Id
  FROM eutr_documents d
  WHERE (@typeId IS NULL OR EXISTS (
          SELECT 1 FROM eutr_references r WHERE r.DocumentId = d.Id AND r.RefType = @typeId))
    AND (@stepId IS NULL OR EXISTS (
          SELECT 1 FROM eutr_references r WHERE r.DocumentId = d.Id AND r.StepId = @stepId))
    AND (@conditionsQuery IS NULL OR EXISTS (
          SELECT 1 FROM eutr_references r WHERE r.DocumentId = d.Id
            AND r.RefValue LIKE CONCAT('%', @conditionsQuery, '%')));
  ```
  Tham số nào không được cung cấp (`null`) thì điều kiện `EXISTS` tương ứng bị bỏ qua hoàn toàn (luôn
  đúng) — chỉ những điều kiện có giá trị mới thực sự lọc. `typeId` truyền xuống dưới dạng giá trị số
  nguyên khớp kiểu cột `RefType` (`TINYINT`, ép kiểu ở tầng gọi — cùng quy ước `(byte)typeId` đã dùng
  từ Update 15/18); `conditionsQuery` là chuỗi thô người dùng nhập (không cần escape ký tự đại diện
  LIKE — khác trường hợp "đảo chiều LIKE" của Quyết định 17, ở đây tham số là chuỗi tìm kiếm, không
  phải pattern).
- **Rationale**: Spec Update 21 (Clarifications, Q&A) chốt rõ: 3 điều kiện lọc (Type/Step name/
  Conditions) **không bắt buộc khớp cùng một bản ghi** `eutr_references` của document — một document
  có thể khớp Type qua dòng A và khớp Conditions qua dòng B. Một câu SQL "1 dòng JOIN thỏa cả 3 điều
  kiện AND trên cùng dòng" (ví dụ `WHERE r.RefType=@t AND r.StepId=@s AND r.RefValue LIKE ...`) sẽ SAI
  ngữ nghĩa cho trường hợp Type="PO" khớp nhiều `StepId` (Update 7) — mỗi `StepId` một dòng riêng,
  cùng `RefType`/`RefValue`. Dùng 3 `EXISTS` độc lập (mỗi điều kiện tự JOIN lại `eutr_references`) là
  cách duy nhất đạt đúng ngữ nghĩa "độc lập theo điều kiện, cùng document" mà không cần `GROUP BY`/
  `HAVING` phức tạp. Mẫu `EXISTS`/`NOT EXISTS` correlated trên `eutr_documents`↔`eutr_references` đã có
  tiền lệ trực tiếp trong chính feature này — endpoint `get-unassigned` (Update 11, đã xóa ở Update 19
  nhưng logic `NOT EXISTS` gốc vẫn là tiền lệ hợp lệ, research Quyết định 33) dùng đúng cấu trúc
  `WHERE NOT EXISTS (SELECT 1 FROM eutr_references r WHERE r.DocumentId = eutr_documents.Id)`.
- **Alternatives considered**: (a) 1 câu JOIN với `WHERE RefType=@t AND StepId=@s AND RefValue LIKE
  ...` trên cùng 1 dòng — bị loại, sai ngữ nghĩa theo quyết định đã chốt ở spec (xem trên); (b)
  `GROUP BY DocumentId HAVING SUM(CASE WHEN RefType=@t THEN 1 ELSE 0 END) > 0 AND ...` — cân nhắc,
  cho cùng kết quả đúng nhưng khó đọc hơn 3 `EXISTS` độc lập và không có tiền lệ nào trong codebase
  dùng `HAVING` kiểu này; 3 `EXISTS` rõ ràng hơn và khớp đúng mẫu `NOT EXISTS` đã dùng ở Update 11;
  (c) Gọi riêng 3 truy vấn (1 cho mỗi điều kiện) rồi giao (intersect) tập kết quả ở tầng C# — bị loại,
  tốn 3 round-trip DB thay vì 1, không cần thiết khi SQL đã biểu diễn đúng logic AND/EXISTS trong 1
  câu.

## Quyết định 64 — Frontend: clone `ComplianceFilterBar.jsx` + wiring `handleSearch`/`searchFilters` của `compliance-master`, KHÔNG dùng lại nguyên component (spec Update 21)

- **Decision**: Không tái sử dụng trực tiếp `ComplianceFilterBar.jsx` (component này có sẵn các
  control cụ thể cho `compliance-master` — compliance type `Select`, reference type `Select`,
  `ReferenceObjectAutocomplete`, search text, expiry days — không khớp 3 control Type/Step name/
  Conditions mà spec yêu cầu). Thay vào đó, tạo component **mới, nhỏ**
  `EutrDocumentsFilterBar.jsx` (`presentation/pages/eutr-documents/components/`) **clone cấu trúc**
  của `ComplianceFilterBar.jsx` (`Box` hàng ngang chứa các control tùy chọn hiển thị theo prop, nút
  Search `contained` + `startIcon={<SearchIcon/>}` ở cuối) nhưng chỉ giữ 3 control spec yêu cầu.
  Wiring ở `index.jsx` clone đúng pattern `handleSearch`/`searchFilters`/reset-page-về-0 đã dùng ở
  `compliance-master/index.jsx`; `useEutrDocumentsData.js` đổi chữ ký nhận thêm `defaultFilters = []`
  (mẫu `useComplianceMasterData(defaultFilters = [])`), gộp vào `filterPayload` trước khi gọi
  `getPagingEutrDocumentsUseCase.execute(...)` — cùng cách `useComplianceMasterData` gộp
  `filterPayload` (DataGrid column filter) + `defaultFilters` (search bar) + `additionalFilters`.
- **Rationale**: Nguyên tắc II (Reference-Pattern Reuse) yêu cầu clone mẫu tham chiếu **cùng hình
  dạng** thay vì phát minh mới — `ComplianceFilterBar.jsx` + wiring của `compliance-master/index.jsx`
  là tiền lệ trực tiếp duy nhất trong repo cho đúng nhu cầu "filter bar phía trên DataGrid với nút
  Search tách biệt khỏi filter cột của chính DataGrid". Không dùng lại nguyên `ComplianceFilterBar.jsx`
  vì component đó không tổng quát hóa theo kiểu "generic filter bar nhận danh sách control tùy ý" —
  các control của nó gắn cứng với domain compliance-master (2 `Select` cụ thể, 1 `Autocomplete` tham
  chiếu D365, 1 số ngày hết hạn); ép dùng lại sẽ phải sửa nó thành generic hoặc truyền xuống nhiều
  prop không liên quan — tạo component nhỏ riêng, cùng *hình dạng* nhưng đúng *nội dung*, là lựa chọn
  nhất quán hơn với cách các dialog/form khác trong chính feature này đã làm (ví dụ
  `EutrDocumentsFormDialog.jsx` không tái sử dụng `EutrMastersModal.jsx`, mà clone cấu trúc của nó).
  Step name dropdown trong search box tải **toàn bộ** `eutr_steps` (dùng lại `GetEutrStepsUseCase` —
  cùng use case đã tải toàn bộ Step trước Update 20) — không lọc theo Type đang chọn trong cùng search
  box, đúng quyết định đã chốt ở spec Update 21 (search box là bộ lọc độc lập trên dữ liệu đã có, khác
  hẳn ngữ cảnh "nhập liệu tạo mới" của combobox Step trong popup Add/Edit vốn lọc theo Assign Steps từ
  Update 20).
- **Alternatives considered**: (a) Tổng quát hóa `ComplianceFilterBar.jsx` thành 1 component nhận
  `fields: Array<{type, props}>` tùy ý — bị loại, over-engineering cho nhu cầu hiện tại (chỉ 1 feature
  dùng hình dạng 3-control này), vi phạm YAGNI; có thể cân nhắc lại nếu một feature thứ ba cần đúng
  hình dạng tương tự trong tương lai; (b) Đặt 3 control trực tiếp inline trong `index.jsx` (không tách
  component riêng) — cân nhắc vì đơn giản hơn, nhưng tách riêng `EutrDocumentsFilterBar.jsx` giữ
  `index.jsx` gọn (đã có nhiều state dialog/selection khác) và khớp đúng mẫu tách file đã dùng ở
  `compliance-master` (`ComplianceFilterBar.jsx` là file riêng, không inline trong `index.jsx` của nó);
  (c) Lọc Step name theo Type đang chọn trong cùng search box (giống Assign Steps, Update 20) — bị
  loại theo quyết định đã chốt ở spec (Q&A "Session 2026-07-24 (Update 21)"), giữ search box là 3 bộ
  lọc độc lập, đơn giản hơn cho người dùng khi tìm kiếm trên dữ liệu đã tồn tại.

## Quyết định 65 — Backend: đối chiếu (diff) insert/delete theo `RefValue`, KHÔNG "xóa toàn bộ rồi tạo lại toàn bộ" (spec Update 22, FR-052)

- **Decision**: Khi Save ở popup Edit với Type khác "PO", `EutrDocumentsService.
  UpdateReferenceStepAsync` đọc lại tập `RefValue` hiện có của document (qua
  `GetStepInfoByDocumentIdsAsync` đã có sẵn — không thêm method đọc mới), tính hai tập chênh lệch bằng
  LINQ `Except` (so sánh không phân biệt hoa/thường, `StringComparer.OrdinalIgnoreCase`): `toAdd` (có ở
  `RefValues` gửi lên, chưa có trong DB) và `toRemove` (có trong DB, không còn ở `RefValues` gửi lên).
  Chỉ `INSERT` đúng các dòng thuộc `toAdd` và `DELETE` đúng các dòng thuộc `toRemove` — mọi dòng không
  đổi (`RefValue` có mặt ở cả hai tập) được giữ nguyên `Id`/`CreatedBy`/`CreatedDate`, chỉ `StepId` của
  chúng được cập nhật ở bước cuối (`UpdateStepIdByDocumentIdAsync`, không đổi).
- **Rationale**: Spec (Update 22, FR-052) mô tả rõ 3 bước tuần tự "tạo bản ghi mới cho chip mới thêm;
  xóa bản ghi cho chip đã xóa; cập nhật `StepId` của mọi bản ghi còn lại" — đây là ngữ nghĩa **diff
  từng phần tử**, không phải "thay thế toàn bộ tập hợp". Giữ nguyên `Id`/audit gốc của các dòng không
  đổi cũng đúng tinh thần chung của feature này (Update 19/FR-033 đã nhấn mạnh "không xóa/tạo lại bản
  ghi nào" cho trường hợp chỉ đổi Step — Update 22 mở rộng nguyên tắc "tối thiểu hóa write" đó sang cả
  trường hợp có thêm/bớt chip).
- **Alternatives considered**: **Xóa toàn bộ rồi tạo lại toàn bộ** theo đúng mẫu
  `ComplMasterConditionPersistenceService.ReplaceAsync` (đã dùng ở Update 12 cho luồng Assign condition
  cũ — `GetPagedAsync` theo `masterId` rồi `DeleteAsync` từng dòng, sau đó `AddAsync` lại toàn bộ danh
  sách mới) — bị loại vì: (a) làm mất `Id`/`CreatedBy`/`CreatedDate` gốc của các chip không hề thay đổi
  giữa 2 lần Save liên tiếp (vi phạm ngầm định "không thêm/xóa bản ghi nào" nếu người dùng không đổi
  chip nào — Save khi đó vẫn sẽ xóa+tạo lại toàn bộ, nhiều hơn cần thiết); (b) không có lý do nghiệp vụ
  nào yêu cầu "làm mới" toàn bộ danh tính bản ghi — khác luồng Assign condition cũ (nơi
  `eutr_reference_details` là bảng con phụ thuộc, không có ràng buộc "giữ Id" nào từ nghiệp vụ khác);
  (c) chi phí không nhỏ hơn cách diff (vẫn cần ít nhất 1 round-trip đọc + N round-trip ghi ở cả hai
  cách) nên không có lợi thế hiệu năng bù lại cho việc mất tính minh bạch/toàn vẹn dữ liệu.

## Quyết định 66 — Backend: mở rộng `EutrUpdateReferenceStepRequestDto`/`PUT {id}/step` hiện có thay vì tạo endpoint reconcile riêng (spec Update 22, FR-051/FR-052)

- **Decision**: Thêm 1 field nullable `List<string>? RefValues` vào `EutrUpdateReferenceStepRequestDto`
  đã có (Update 19) thay vì tạo route/DTO/controller action mới cho việc "đối chiếu chip". `null` (Type
  = "PO", hoặc Client không gửi — ví dụ code cũ) giữ nguyên hành vi trước Update 22 (chỉ `UPDATE
  StepId`, không transaction); có giá trị (Type khác "PO") kích hoạt nhánh reconcile mới trong cùng
  method `UpdateReferenceStepAsync`, cùng lời gọi HTTP `PUT {id}/step` đã có, cùng 1 lượt Save (sau
  bước cập nhật `ValidFrom`/`ValidTo` ở `PUT {id}`, không đổi thứ tự đã có từ Update 19).
- **Rationale**: Save ở popup Edit vốn đã gọi tuần tự 2 endpoint (`PUT {id}` rồi `PUT {id}/step`, nếu
  Step hiển thị) — thêm khả năng reconcile chip vào **cùng đúng** endpoint step-update là thay đổi tối
  thiểu, giữ nguyên số lượng round-trip HTTP của 1 lượt Save (không tăng từ 2 lên 3), và tận dụng đúng
  transaction/policy (`EutrDocuments.Update`) đã có — khớp Nguyên tắc III (Reuse Existing Backend, ưu
  tiên mở rộng endpoint hiện có hơn tạo endpoint mới cho nhu cầu có thể gộp chung).
- **Alternatives considered**: Endpoint riêng, ví dụ `PUT /api/eutr-documents/{id}/references`
  (reconcile only, tách khỏi Step) — bị loại vì Save vẫn phải gọi cả 2 (Step lẫn reconcile chip) trong
  cùng 1 lượt (Step mới luôn được áp dụng cho toàn bộ bản ghi kể cả bản ghi vừa reconcile, theo spec),
  tách riêng chỉ tăng round-trip mà không tách bạch được trách nhiệm nghiệp vụ (2 endpoint vẫn phải
  chạy tuần tự, phụ thuộc lẫn nhau trong cùng 1 request Save).

## Quyết định 67 — Frontend: tái sử dụng nguyên vẹn `EutrAddValueAutocomplete.jsx` cho Edit (Type khác "PO"), không nhân bản logic gợi ý/giới hạn chip (spec Update 22, FR-051)

- **Decision**: Hiển thị lại đúng component `EutrAddValueAutocomplete.jsx` (đã tồn tại từ Update 15,
  hiện chỉ dùng ở mode `add`) trong mode `edit` khi `showEditableChips` (Type khác "PO" và document có
  Type) là `true`, với cùng props `type`/`value={chips}`/`onChange={setChips}`/`disabled={submitting}`
  đã dùng ở Add — không sửa bất kỳ dòng nào bên trong component này. Chip `Stack`/`Chip` hiện có (dùng
  chung cho cả 2 mode từ Update 19) chỉ đổi điều kiện `onDelete` từ `!isEdit && !submitting` sang
  `(!isEdit || showEditableChips) && !submitting`.
- **Rationale**: `EutrAddValueAutocomplete.jsx` vốn tự suy `referenceType`/`isSingleValueType` thuần
  từ `type.name` (không phụ thuộc `isEdit`/mode nào) — nó *vốn đã* tổng quát đúng mức cần thiết cho cả
  2 mode, chỉ chưa được render trong mode edit. Tái dùng nguyên vẹn kế thừa miễn phí toàn bộ quy tắc đã
  implement đúng ở Update 15-18 (gợi ý theo Type FR-011, giới hạn 1 chip cho PO/Vendor FR-013, dán
  nhiều giá trị, chống trùng) mà không cần viết/test lại — khớp Nguyên tắc II (Reference-Pattern Reuse)
  ở mức cao nhất (0 dòng logic mới, chỉ đổi 2 biểu thức điều kiện hiển thị).
- **Alternatives considered**: Viết lại một control chip-editor riêng cho Edit (ví dụ giới hạn phạm vi
  rõ ràng hơn "input chỉ dùng khi sửa") — bị loại, trùng lặp không cần thiết logic đã đúng và đã qua
  thực tế sử dụng ở Add; rủi ro 2 nơi lệch quy tắc (ví dụ sửa giới hạn 1 chip ở một nơi mà quên nơi
  kia) trong tương lai.
