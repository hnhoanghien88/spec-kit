# Implementation Plan: EUTR Documents Management

**Branch**: `004-eutr-documents` | **Date**: 2026-07-07 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-eutr-documents/spec.md`

## Summary

Xây dựng màn hình **EUTR Documents** — CRUD cơ bản lưu vào bảng `eutr_documents`. Grid hiển thị
File name, Valid from, Valid to, Created by, Created date, cùng ba cột ban đầu **luôn để trống**
(Step name, Conditions, Type) vì `eutr_documents` không có cột nguồn cho chúng — *(Step name/Type
được nạp dữ liệu thật kể từ Update 8 dưới đây; Conditions vẫn không đổi)*. **Add** là một **trang
riêng** (`/eutr/documents/add`, không popup) chỉ thu thập thông tin (File name, Valid from, Valid
to) — **chưa có bước chọn/upload file thật** ở phạm vi này. **Edit** vẫn dùng **popup** (giống
`eutr-masters`) để sửa File name/Valid from/Valid to. **Delete** hỗ trợ đơn lẻ + nhiều dòng (hard
delete, không có cờ soft-delete trong schema) — *(Update 9 dưới đây: xóa MUST kèm dọn toàn bộ
`eutr_references` liên quan theo `DocumentId`)*. Cột Action có thêm icon **View** — hiển thị active
bình thường như Edit/Delete nhưng **chưa gắn hành vi xử lý** (placeholder, silent no-op).

Backend cho `eutr-documents` **chưa tồn tại** → tạo mới toàn bộ, clone mẫu **EutrStep** (feature
đơn giản nhất: entity phẳng, không JOIN, không kiểm tra trùng, dùng thẳng repository generic
`IRepository<T,long>` đã đăng ký open-generic — **không cần tạo file repository riêng**). Cột
`Name` của `eutr_documents` hiện là `BIGINT` trong schema thật (`docs/design/eutr/eutr_db.sql` và
`ComplianceSys.Infrastructure/Sqls/Tables/eutr_db.sql`) nhưng cần lưu văn bản (File name) → thêm
một migration SQL đổi kiểu sang `VARCHAR(255)` (theo đúng convention thư mục
`Sqls/Migration/NN_migrate_*.sql` đã dùng ở feature 003).

Frontend clone mẫu **eutr-masters** cho phần list + popup Edit (modal 2 trường → đổi thành File
name/Valid from/Valid to), và mượn cách **đăng ký route trang riêng** của **eutr-templates**
(`RouteResolver.jsx` + `MainRoutes.jsx`) cho trang Add — nhưng đơn giản hoá tối đa: không có cây
bước, không cần dirty-check confirm dialog khi Back (form chỉ 3 trường, theo Edge Case đã chốt ở
clarify).

**Cập nhật (spec Session Update 3 — chỉnh giao diện trang Add theo `eutr_documents_overview.md`,
chỉ giao diện, chưa chức năng)**: `EutrDocumentsAdd.jsx` (đã tồn tại — toàn bộ backend + CRUD ở
trên **đã triển khai xong**, xem `tasks.md`) được **sửa thêm** một trường **Type**
(`<Autocomplete>` tái sử dụng hằng số có sẵn `TAKE_FROM_OPTIONS` — "PO"/"Upload manual", mặc định
"PO") và 2 layout tĩnh theo thiết kế: Screen1 (Type=PO — bảng **List PO** + khu "Drag and drop
files to upload") và Screen2 (Type=Upload manual — khu upload + nút "Assign condition" + bảng
file). Toàn bộ phần này là **UI-only**: dữ liệu List PO/file là hằng số hard-code trong component,
không gọi API nào; kéo-thả/Assign condition/View/Delete/checkbox trong bảng demo đều **no-op**
(research Quyết định 8 — đã cập nhật sau khi phát hiện `TAKE_FROM_OPTIONS` là hằng số dùng chung
có sẵn, không phải chuỗi cần hard-code mới). File name/Valid from/Valid to/Save/Back hiện có
**không đổi** (FR-020) — Save vẫn chỉ tạo document dựa trên 3 trường này. Không có thay đổi
backend/DB/contract nào cho phần cập nhật này. **Đã triển khai và xác minh tĩnh**: `npx eslint` (0
lỗi), `npx vite build` (thành công).

**Cập nhật (spec Session Update 4 — List PO nối dữ liệu PO thật, FR-021/FR-022)**: Thay `DEMO_PO_LIST`
ở cột **PO name** (Screen1) bằng dữ liệu thật lấy qua **endpoint tham chiếu dùng chung sẵn có**
`POST /api/dynamics/reference` (KHÔNG tạo endpoint GET/POST mới). Backend: đăng ký 2 D365 entity đã
có sẵn domain model (`RSVNEutrPurchOrders.cs` = `ModelType 15`, `RSVNEutrSalesOrderPurchases.cs` =
`ModelType 16`, đã tồn tại trong repo) vào `EntityMappings`/`MapDynamicsResponse` của
`ComplDynamicsService.cs` — `refType 15` dùng cho List PO, `refType 16` chỉ đăng ký cho một tính
năng sau, KHÔNG có UI nào trong feature này gọi tới. Frontend: `EutrDocumentsAdd.jsx` tái sử dụng
hook generic có sẵn `useReferenceObjects` (`GetReferenceDataUseCase`, đã dùng ở
`ReferenceObjectAutocomplete.jsx`) với `referenceType = 15` để nạp cột PO name, tận dụng sẵn
`loading`/`error`/rỗng của hook cho FR-017/SC-010. Cột File name và Action View/Delete trên List PO
không đổi (vẫn trống/no-op, Update 3). Không có migration DB mới, không đổi
`EutrDocumentsRequestDto`/`ResponseDto`/route `api/eutr-documents` (xem research Quyết định 9).

**Cập nhật (spec Session Update 5 — ô tìm kiếm PO lọc qua API, FR-023)**: Đổi ô tìm kiếm PO (thêm
khi implement Update 4) từ lọc cục bộ trên dữ liệu đã tải sang gọi lại
`fetchReferenceObjects(15, query)` của hook `useReferenceObjects` (đã dùng ở Update 4), debounce
500ms bằng `lodash.debounce` theo đúng mẫu `ReferenceObjectAutocomplete.jsx`. **Không cần thay đổi
backend** — `ComplDynamicsService.BuildFilterString` đã tự ánh xạ filter generic "Code"/"Name" sang
đúng cột thật (`PurchId`/`Name`) qua `EntityMappings` đã đăng ký từ Update 4 (xem research Quyết
định 10). Chỉ sửa 1 file frontend hiện có (`EutrDocumentsAdd.jsx`) — bỏ state lọc cục bộ
`filteredPoList`/`poSearchTerms` (không còn hỗ trợ đa từ khóa cách nhau dấu phẩy), danh sách hiển
thị trực tiếp từ `poList` (kết quả đã lọc ở server).

**Cập nhật (spec Session Update 6 — khu "Drag and drop files to upload" ở Screen1 trở thành upload
nhiều file thật lên SharePoint, FR-024 đến FR-030)**: Thay khu kéo-thả no-op ở Screen1 (Type = PO)
bằng nút **Upload** thật. Backend: **tạo mới** `IEutrUploadService`/`EutrUploadService`
(`ComplianceSys.Application`), **không tái sử dụng** `IComplUploadService`/`ComplUploadService` —
tự thao tác trực tiếp `IRepository<EutrDocuments, long>` + `IUnitOfWork` để ghi `eutr_documents`
(bao gồm `FileId`, field mà `EutrDocumentsRequestDto` hiện không có — xem research Quyết định 11).
Thêm action mới `[HttpPost("eutr-upload-multi")]` vào **cùng** `SharePointController.cs` hiện có
(route `api/sharepoint`, không phải `api/eutr-documents`), dùng
`_configuration["SharePointEutrPath"]` (khóa cấu hình mới) làm gốc, tự tìm/tạo thư mục con theo mã
PO (`GetFolders`/`CreateFolder` của `ISharepointService` có sẵn — không có method "ensure folder"
dựng sẵn, xem research Quyết định 13), validate file (PDF/DOC/DOCX/XLS/XLSX/JPG/PNG, tối đa 10MB —
tái áp dụng ràng buộc đã hoãn ở Update 1), và ghi 1 dòng `eutr_documents` cho mỗi file upload thành
công (`Name` = tên file gốc, `ValidFrom` = ngày hiện tại, `ValidTo` = `9999-12-31`, `FileId` = id từ
SharePoint) trong **transaction riêng từng file** để đạt ngữ nghĩa best-effort khi một phần batch
lỗi (research Quyết định 14). **Không migration DB mới** — cột `FileId`/`Name`/`ValidFrom`/`ValidTo`
đã tồn tại đủ trên `eutr_documents` từ trước; bảng **không có thêm cột lưu PO** (PO chỉ dùng để suy
ra thư mục SharePoint, xác nhận ở clarify Update 6). Frontend: **mở rộng** hạ tầng SharePoint đã có
sẵn cho tính năng khác — thêm method `uploadEutrFilesMulti(files, poCode)` vào
`ISharePointRepository`/`RestSharePointRepository` và `executeEutrMulti(files, poCode)` vào
`UploadToSharePointUseCase` (KHÔNG tạo domain/infrastructure/application mới), sửa
`EutrDocumentsAdd.jsx` để thêm chọn PO đơn (click 1 dòng List PO, không checkbox) và nút Upload
(input file ẩn, `multiple`) thay khu kéo-thả — xem research Quyết định 12/15.

**Cập nhật (spec Session Update 7 — thiết kế lại khu Upload theo hình + validate prefix file theo
`eutr_master_documents` + ghi `eutr_references`, FR-031 đến FR-033)**: Khu vực Upload ở Screen1
được **thiết kế lại** theo mẫu `upload.png` (tiêu đề "Upload File", khung kéo-thả lớn với
`CloudUploadIcon`, chữ "Drop file here or click to browse", hàng chip định dạng/kích thước **thật**
— vẫn PDF/DOC/DOCX/XLS/XLSX/JPG/PNG, 10MB, KHÔNG đổi theo số liệu trong ảnh mẫu) và **thêm kéo-thả
file thật** (ngoài click chọn file đã có từ Update 6) — cả hai đường dùng chung 1 hàm xử lý
(research Quyết định 19). Backend: trước khi upload lên SharePoint, mỗi file MUST qua thêm bước
validate **prefix tên file** — gọi method mới `GetMatchingPrefixesAsync(fileName)` bổ sung vào
`IEutrMastersRepository`/`EutrMastersRepository` **đã có sẵn** (feature `002-eutr-masters`, KHÔNG
tạo repository mới) để tìm mọi bản ghi `eutr_master_documents` có `Prefix` là tiền tố của tên file
(SQL "đảo chiều LIKE", research Quyết định 17); file không khớp bản ghi nào bị loại (giống cơ chế
per-file đã có ở FR-026), file khớp N `StepId` phân biệt thì sau khi upload SharePoint thành công sẽ
ghi 1 dòng `eutr_documents` **và N dòng `eutr_references`** (mỗi `StepId` một dòng, cùng
`DocumentId`) trong **một transaction chung** cho cả file đó (mở rộng Quyết định 14 của Update 6 —
research Quyết định 18) — nếu bất kỳ bước ghi nào trong nhóm này lỗi, toàn bộ transaction của file
đó rollback (không để lại document mồ côi), file báo thất bại. **Migration DB mới**: bảng
`eutr_references` (hiện chưa có entity backend nào) cần entity mới `EutrReferences.cs` (dùng thẳng
`IRepository<EutrReferences,long>` generic, không tạo repository riêng) **và** một cột **mới**
`StepId` (BIGINT UNSIGNED NULL, FK riêng tới `eutr_steps.Id`) — **KHÔNG đụng tới cột `RefId` hiện
có** hay ràng buộc khóa ngoại của nó tới `eutr_template_details` (research Quyết định 16, đã sửa
theo phản hồi trực tiếp của người dùng — bản nháp đầu tiên định ghi vào `RefId` nhưng bị loại).

**Cập nhật (spec Session Update 8 — nạp Step name/Type ở danh sách + File name/Step name ở List
PO, FR-034 đến FR-038)**: Cột **Step name**/**Type** trong danh sách EUTR documents và cột **File
name**/**Step name** trong bảng List PO (trang Add, Screen1) KHÔNG còn luôn trống — cả hai được nạp
bằng cách **đọc** (read-only) bảng `eutr_references` đã có từ Update 7, KHÔNG cần migration DB mới.
Backend: tạo mới `IEutrReferencesRepository`/`EutrReferencesRepository`
(`DapperRepository<EutrReferences,long>`, clone mẫu `EutrMastersRepository` — Quyết định 17) với 2
method JOIN mới: `GetStepInfoByDocumentIdsAsync` (JOIN `eutr_references`+`eutr_steps`,
`WHERE DocumentId IN (...)`, dùng cho danh sách) và `GetDocumentsByPoCodesAsync` (JOIN
`eutr_references`+`eutr_documents`+`eutr_steps`, `WHERE RefType=0 AND RefValue IN (...)`, dùng cho
List PO). `EutrDocumentsService.GetPagedAsync` mở rộng để gọi method thứ nhất rồi gán
`StepNames`/`RefType` vào `EutrDocumentsResponseDto` (2 field mới) — clone đúng mẫu "1 query cha +
1 query con WHERE IN + gộp trong bộ nhớ" đã có ở `ComplCountryGroupService.AttachMembersAsync`
(research Quyết định 20). Thêm 1 endpoint mới `POST /api/eutr-documents/list-po-references` (cùng
`EutrDocumentsController`, policy `EutrDocuments.ReadAll` dùng chung) gọi method thứ hai, trả về
`List<EutrDocumentsPoReferenceDto>` (research Quyết định 21). Frontend: `useEutrDocumentsColumns.jsx`
đổi cột Step name sang `renderCell` hiển thị `row.stepNames` qua component dùng chung **mới**
`MultiValueChips.jsx` (chip + "+N more" + tooltip, clone logic đang inline ở cột "Country Codes"
của `useCountryGroupColumns.jsx` — research Quyết định 23), cột Type map `row.refType` qua hằng số
có sẵn `TAKE_FROM_OPTIONS`. `EutrDocumentsAdd.jsx`: khi `selectedPoId` đổi, gọi use case mới
`GetEutrDocumentsPoReferencesUseCase` với mã PO đang chọn (research Quyết định 22 — chỉ PO đang
chọn, không phải toàn trang), thay bảng chi tiết (Grid size=5) từ 1 row placeholder tĩnh sang
`.map()` qua danh sách document trả về (File name = tên file thật, Step name qua `MultiValueChips`).

**Cập nhật (spec Session Update 9 — Delete xóa kèm toàn bộ `eutr_references` liên quan, FR-039/
FR-040)**: `EutrDocumentsService` hiện là CRUD thuần qua `BaseService` (không override
Delete/DeleteMulti) — `BaseService.DeleteAsync` chỉ xóa 1 dòng `eutr_documents`, để lại các dòng
`eutr_references` mồ côi đã ghi bởi `EutrUploadService` (Update 7). Backend: **override**
`DeleteAsync`/`DeleteMultiAsync` trực tiếp trong `EutrDocumentsService` (không sửa
`IBaseService`/`IEutrDocumentsService` — interface dùng chung cho mọi feature CRUD khác, ngoài
phạm vi feature này). `DeleteAsync` override thêm 1 bước `_referencesRepository
.DeleteByDocumentIdAsync(id, ct)` **trong cùng transaction** với `_repository.DeleteAsync(id, ct)`
(mẫu override `ComplJobScheduleConfigService.DeleteAsync` — research Quyết định 24) — nếu bước xóa
`eutr_references` lỗi, `RollbackAsync()` khiến document đó KHÔNG bị xóa (FR-040). `DeleteMultiAsync`
override **không dùng lại** 1 transaction chung cho cả batch như `BaseService.DeleteMultiAsync`
hiện tại (all-or-nothing) — thay bằng **1 transaction riêng cho mỗi document** trong vòng lặp (mẫu
per-item try/catch của `EutrUploadService.UploadMultipleToSharePointAndSaveDataAsync`, Quyết định
14/18), document lỗi được gom vào danh sách lỗi và **không chặn** vòng lặp tiếp tục xóa các document
khác (FR-012/FR-040); sau vòng lặp, nếu có lỗi thì throw 1 exception tổng hợp liệt kê id/lý do (các
document đã xóa thành công **vẫn giữ nguyên trạng thái đã xóa** vì mỗi transaction đã commit độc
lập trước đó). Thêm 1 method mới `DeleteByDocumentIdAsync(long documentId, ct)` vào
`IEutrReferencesRepository`/`EutrReferencesRepository` (raw SQL `DELETE FROM eutr_references WHERE
DocumentId = @DocumentId`, cùng style `Connection.ExecuteAsync` + `Transaction` đã dùng ở 2 method
đọc hiện có, Update 8) — đây là đường **ghi thứ hai** trên bảng `eutr_references` (đường đầu là
`AddAsync` qua `IRepository<EutrReferences,long>` generic trong `EutrUploadService`, Update 7).
**Không migration DB mới** (không đổi schema `eutr_references`/`eutr_documents`), **không đổi
route/request/response** của `DELETE /api/eutr-documents/{id}` hay `POST /api/eutr-documents/
delete-multi` (chỉ đổi hành vi nội bộ) — `EutrDocumentsController` không cần sửa.

**Cập nhật (spec Session Update 10 — icon View mở xem file thật + Delete từng file ở List PO,
FR-041 đến FR-045)**: Icon **View** trên cột Action của danh sách chính (trước đây placeholder
silent no-op, FR-013 cũ) và trên mỗi dòng của bảng chi tiết List PO (trang Add, Screen1) nay mở một
**popup xem trước file thật** — tham khảo đúng hàm `[HttpGet("get-file-by-idref")] GetFileByIds`
trong `ComplCompliancesController.cs` và giao diện `compliance-detail`
(`FilePreviewer.jsx`/`DialogFilePreviewer.jsx`). Backend: thêm 1 endpoint **mới**
`GET /api/eutr-documents/get-file-by-idref` **trong `EutrDocumentsController` hiện có** (KHÔNG
controller mới), inject thẳng `ISharepointService` vào controller (đúng tiền lệ
`ComplCompliancesController`/`SharePointController`), gọi `ReadFileWithMetaAsync(idRef)`. Document
không có `FileId` (tạo qua form Save nhập tay) → icon View bị vô hiệu hóa (tooltip "No file to
view"), không gọi endpoint này. Frontend: **tổng quát hoá tối thiểu** `FilePreviewer.jsx` (thêm 2
prop tùy chọn `fetchFile`/`onLoaded`, KHÔNG nhân bản logic render PDF/DOCX/XLSX/ảnh, không ảnh
hưởng `compliance-detail`), thêm component mới `EutrFileViewerDialog.jsx` (phạm vi riêng
`eutr-documents`, Download dựng Blob từ dữ liệu đã tải cho preview — không tái dùng luồng zip/
progress-dialog của `DialogFilePreviewer.jsx`). Trên List PO, bảng chi tiết (Grid size=5) **đã có
sẵn cấu trúc "1 dòng = 1 document"** từ Update 8 — chỉ cần nạp thêm `FileId` (mở rộng
`EutrReferencePoDocumentInfo`/`EutrDocumentsPoReferenceItemDto`/SQL JOIN, không migration DB mới)
và gắn hành vi thật cho 2 icon đã có sẵn: View mở popup xem trước (như trên); Delete gọi lại API
xóa đơn hiện có (`DELETE /api/eutr-documents/{id}`, đã dọn `eutr_references` từ Update 9) — KHÔNG
gọi API xóa file SharePoint nào, file thật được giữ lại. Cột Action cấp-dòng cũ của List PO (View/
Delete silent no-op, FR-017/FR-019 cũ) bị gỡ bỏ, thay bằng 2 icon theo từng file này.

## Technical Context

**Language/Version**: .NET 8 (backend); JavaScript (ES modules), React 18 + Vite (frontend)

**Primary Dependencies**: Backend — Dapper (`Shared.Dapper`: `IRepository<,>`, `DapperRepository<,>`
open-generic, `BaseService<,,>`, `BaseValidator<>`), FluentValidation, AutoMapper,
`Shared.AuthN`/`AuthZ`. Frontend — React, MUI (`@mui/material`, `@mui/x-data-grid`,
`@mui/icons-material`), axios, React Router v6.

**Storage**: MySQL qua Dapper; bảng `eutr_documents` (đã định nghĩa trong
`docs/design/eutr/eutr_db.sql`), không FK tới bảng khác. Cột `Name` **MUST migrate** BIGINT →
VARCHAR(255). **Update 7**: bảng `eutr_references` MUST được thêm cột mới `StepId` (BIGINT UNSIGNED
NULL, FK riêng tới `eutr_steps.Id`) — KHÔNG đụng cột `RefId`/FK hiện có của nó tới
`eutr_template_details`. **Update 8**: KHÔNG migration DB mới — chỉ thêm 2 truy vấn JOIN read-only
mới (`eutr_references`+`eutr_steps`, và `eutr_references`+`eutr_documents`+`eutr_steps`) qua
repository mới `EutrReferencesRepository`.

**Testing**: Kiểm thử thủ công theo `quickstart.md` (dự án chưa có test tự động cho các trang CRUD).

**Target Platform**: Web (SPA phục vụ qua nginx) + API .NET 8.

**Project Type**: Web application (frontend + backend tách biệt trong monorepo).

**Performance Goals**: Tương đương các màn CRUD hiện có; phân trang server-side.

**Constraints**: Comment code **tiếng Việt**, nhưng **toàn bộ văn bản UI hiển thị bằng tiếng Anh**
(FR-015); không có ràng buộc duy nhất trên File name (FR-007b); Add page hiện KHÔNG có control
chọn/upload file (FR-006, deferred). **Update 4**: List PO (cột PO name) MUST lấy dữ liệu qua
endpoint tham chiếu dùng chung `POST /api/dynamics/reference` với `refType = 15`, KHÔNG tạo
endpoint riêng (FR-021); `refType = 16` chỉ đăng ký backend, không có UI gọi tới (FR-022). **Update
5**: ô tìm kiếm PO MUST lọc qua API (`refType = 15` kèm từ khóa), KHÔNG lọc cục bộ trên dữ liệu đã
tải (FR-023) — không cần thay đổi backend vì filter Code/Name generic đã hoạt động sẵn. **Update
6**: nút Upload (Screen1) chỉ khả dụng khi đã chọn 1 PO (FR-024); chỉ chấp nhận PDF/DOC/DOCX/XLS/
XLSX/JPG/PNG tối đa 10MB/file (FR-026); PO đã chọn CHỈ dùng để suy ra thư mục SharePoint đích, MUST
KHÔNG lưu liên kết PO vào `eutr_documents` (clarify Update 6); một phần file lỗi trong batch KHÔNG
được làm mất các file đã upload/lưu thành công (FR-030, best-effort — không all-or-nothing). **Update
7**: tên file MUST có prefix khớp `eutr_master_documents.Prefix` mới được upload (FR-032); khớp
nhiều `StepId` phân biệt thì ghi nhiều dòng `eutr_references` cùng `DocumentId` (FR-033); khu Upload
MUST hỗ trợ cả kéo-thả thật lẫn click (FR-031), hiển thị đúng định dạng/kích thước thật (không theo
số liệu trong ảnh mẫu `upload.png`). **Update 8**: cột Step name/Type (danh sách) MUST nạp qua JOIN
`eutr_references`/`eutr_steps` theo `DocumentId`, hiển thị nhiều Step name nếu có nhiều `StepId`
phân biệt (FR-034/FR-035); cột File name/Step name (List PO) MUST nạp qua JOIN
`eutr_references`+`eutr_documents`+`eutr_steps` theo `RefType=0`/`RefValue`=mã PO (FR-037/FR-038);
cột Conditions KHÔNG đổi, vẫn luôn trống (FR-036); không có migration DB mới. **Update 9**: xóa 1
hoặc nhiều document (`DELETE /{id}`, `POST /delete-multi`) MUST xóa kèm mọi dòng `eutr_references`
có `DocumentId` tương ứng, mỗi document 1 transaction độc lập — lỗi ở 1 document (đơn hoặc trong
lượt xóa nhiều) KHÔNG được để lại `eutr_documents` đã xóa còn sót `eutr_references`, và KHÔNG được
chặn việc xóa các document khác trong cùng lượt xóa nhiều (FR-039/FR-040); không migration DB mới.
**Update 10**: icon View (danh sách + List PO) MUST mở popup xem trước file thật khi document có
`FileId`, MUST vô hiệu hóa (tooltip "No file to view") khi không có `FileId` (FR-042); endpoint mới
`GET /api/eutr-documents/get-file-by-idref` clone nguyên vẹn
`ComplCompliancesController.GetFileByIds` (FR-041); mỗi file trên List PO MUST có icon View/Delete
riêng (không còn Action cấp-dòng, FR-043 đến FR-045); Delete từng file MUST dùng lại API xóa đơn
hiện có (`DELETE /api/eutr-documents/{id}`), MUST KHÔNG gọi API xóa file SharePoint nào; không
migration DB mới (chỉ thêm `FileId` vào 1 SQL JOIN đã có).

**Testing bổ sung (Update 10)**: kiểm thử thủ công theo `quickstart.md` kịch bản 6/6a/9r/9s — bao
gồm xác nhận popup xem trước hiển thị đúng nội dung và xác nhận file KHÔNG bị xóa khỏi SharePoint
sau khi Delete (kiểm tra qua log backend/Graph Explorer nếu có quyền truy cập).

**Scale/Scope**: 1 màn hình (list) + 1 trang riêng (Add) + 1 modal (Edit). Backend ~7 file mới +
1 migration + sửa 2 file DI/mapping. Frontend ~11 file mới + sửa 4 file wiring. **Update 3**: chỉ
sửa 1 file hiện có (`EutrDocumentsAdd.jsx`) — thêm Select Type + 2 block layout tĩnh + 2 mảng dữ
liệu demo hard-code; không thêm dependency, không thêm file domain/infrastructure/application mới,
không đổi backend/DB/contract. **Update 4**: sửa 1 file backend hiện có (`ComplDynamicsService.cs`
— thêm 2 dòng `EntityMappings` + 2 `case` trong `MapDynamicsResponse`), tùy chọn sửa `ComplEnum.cs`
(thêm 2 giá trị enum `ObjectType`), và sửa 1 file frontend hiện có (`EutrDocumentsAdd.jsx` — gọi
hook `useReferenceObjects` có sẵn thay vì mảng demo cho cột PO name); không thêm entity/DTO/
controller/route mới, không thêm dependency mới. **Update 5**: chỉ sửa 1 file frontend hiện có
(`EutrDocumentsAdd.jsx` — đổi cách gọi `fetchReferenceObjects` khi `poSearch` thay đổi, thêm
`lodash.debounce` đã có sẵn trong `package.json`); **không sửa backend, không thêm file mới**.
**Update 6**: Backend — 4 file mới (`IEutrUploadService.cs`, `EutrUploadService.cs`,
`EutrMultiUploadFileRequest.cs`, `EutrUploadFileResultDto.cs`) + sửa 3 file hiện có
(`SharePointController.cs` thêm action + constructor param; `DependencyInjection.cs` thêm 1 dòng
đăng ký; `appsettings.json`/`appsettings.Development.json` thêm khóa `SharePointEutrPath`) —
**không migration DB mới**, không đổi `EutrDocumentsController`/`EutrDocumentsService`/
`EutrDocumentsRequestDto` (controller `api/eutr-documents` giữ nguyên). Frontend — sửa 3 file hiện
có (`ISharePointRepository.js`, `RestSharePointRepository.js`, `UploadToSharePointUseCase.js` — mỗi
file thêm 1 method mới) + sửa `EutrDocumentsAdd.jsx` (chọn PO đơn + nút Upload thay khu kéo-thả);
không thêm domain/infrastructure/application file mới, không thêm dependency mới.
**Update 7**: Backend — 1 file mới (`EutrReferences.cs` entity) + 1 migration mới
(`10_add_stepid_to_eutr_references.sql`) + sửa 4 file hiện có (`IEutrMastersRepository.cs`/
`EutrMastersRepository.cs` thêm 1 method; `EutrUploadService.cs` thêm constructor param +
logic prefix/reference; `docs/design/eutr/eutr_db.sql` và `Sqls/Tables/eutr_db.sql` thêm cột
`StepId`) — không thêm entity/DTO/controller/route nào khác, không đổi endpoint
`eutr-upload-multi` (vẫn cùng path/contract, chỉ đổi hành vi nội bộ). Frontend — sửa 1 file
(`EutrDocumentsAdd.jsx` — thiết kế lại card Upload + gộp logic click/kéo-thả); không thêm
domain/infrastructure/application file mới, không thêm dependency mới (dùng `CloudUploadIcon`
có sẵn trong `@mui/icons-material`).
**Update 8**: Backend — 4 file mới (`IEutrReferencesRepository.cs`, `EutrReferencesRepository.cs`,
`EutrDocumentsListPoReferencesRequestDto.cs`, `EutrDocumentsPoReferenceDto.cs` — có thể gộp thêm 1
file nhỏ `EutrDocumentsPoReferenceItemDto.cs`/2 projection DTO nội bộ, xem `data-model.md`) + sửa
4 file hiện có (`EutrDocumentsResponseDto.cs` thêm 2 field; `IEutrDocumentsService.cs`/
`EutrDocumentsService.cs` thêm method + mở rộng `GetPagedAsync`; `EutrDocumentsController.cs` thêm
1 action; `ComplianceSys.Infrastructure/DependencyInjection.cs` thêm 1 dòng đăng ký DI) — **không
migration DB mới**, không đổi 6 endpoint hiện có của `api/eutr-documents` (chỉ thêm field response ở
endpoint `get-all` + 1 action mới). Frontend — 2 file mới (`MultiValueChips.jsx`,
`GetEutrDocumentsPoReferencesUseCase.js`) + sửa 5 file hiện có (`EutrDocuments.js` domain entity
thêm field; `IEutrDocumentsRepository.js`/`RestEutrDocumentsRepository.js`/`eutrDocumentsApi.js`
thêm method `getPoReferences`; `useEutrDocumentsColumns.jsx` đổi renderCell cột Step name/Type;
`EutrDocumentsAdd.jsx` gọi use case mới + đổi bảng chi tiết List PO sang dữ liệu thật) — không thêm
dependency mới.
**Update 10**: Backend — sửa 5 file hiện có (`EutrDocumentsController.cs` thêm constructor param +
1 action; `EutrReferencePoDocumentInfo.cs`/`EutrDocumentsPoReferenceItemDto.cs` thêm field `FileId`;
`EutrReferencesRepository.cs` thêm 1 dòng SQL; `EutrDocumentsService.cs` thêm 1 dòng gán `FileId`) —
không thêm file mới, không migration DB mới, không thêm dependency mới (`ISharepointService` đã có
sẵn trong package `Res.Shared.ExternalServices` đã cài). Frontend — 2 file mới
(`EutrFileViewerDialog.jsx`, `GetEutrDocumentsFileByIdRefUseCase.js`) + sửa 6 file hiện có
(`FilePreviewer.jsx` thêm 2 prop tùy chọn; `eutrDocumentsApi.js`/`IEutrDocumentsRepository.js`/
`RestEutrDocumentsRepository.js` thêm method `getFileByIdRef`; `EutrDocumentsActionCell.jsx` +
`useEutrDocumentsColumns.jsx` đổi icon View thành control thật; `EutrDocumentsAdd.jsx` gắn View/
Delete thật cho mỗi dòng List PO; `index.jsx` quản lý state popup xem trước) — không thêm
dependency mới (dùng lại `docx-preview`/LuckyExcel đã cài từ trước cho `FilePreviewer.jsx`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Nguyên tắc                                   | Trạng thái               | Ghi chú                                                                                                                                                                                                                                                                                                                                               |
| ---------------------------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| I. Layered Clean Architecture                  | ✅ PASS                    | Backend Api→Application→Domain + Infrastructure (chỉ 1 migration SQL, không có Infrastructure repository riêng); frontend domain/infrastructure/application/presentation + DI                                                                                                                                                                    |
| II. Reference-Pattern Reuse                    | ✅ PASS                    | Backend clone`EutrStep` (mẫu đơn giản nhất, không JOIN/không chống trùng). Frontend: list + popup Edit clone `eutr-masters`; routing trang Add riêng mượn cách wiring của `eutr-templates` (`RouteResolver` + `MainRoutes`), đơn giản hoá bỏ cây bước/dirty-check                                                      |
| III. Reuse Existing Backend                    | ✅ PASS (không áp dụng) | Backend`eutr-documents` **chưa tồn tại** → tạo mới theo mẫu `EutrStep`. Tái sử dụng hạ tầng sẵn có: repository generic `IRepository<EutrDocuments,long>` (open-generic, KHÔNG tạo repository riêng), `BaseService`, `BaseValidator`                                                                                    |
| IV. Vietnamese Comments; Localizable UI Labels | ✅ PASS                    | Comment code tiếng Việt; UI label/thông báo**tiếng Anh** theo FR-015 (được phép bởi Principle IV, constitution v2.0.0)                                                                                                                                                                                                                 |
| V. Routing & Menu Registration                 | ✅ PASS                    | Thêm componentMap`eutr-documents` trong `RouteResolver.jsx`; route riêng `/eutr/documents/add` trong `MainRoutes.jsx`; mỗi thao tác gắn policy `EutrDocuments.*`. **Menu + quyền được tạo động & phân quyền trong DB** (không seed bằng code) → là tiền đề vận hành/DB, không phải task code (giống 002/003) |

Không có vi phạm hiến pháp → không cần Complexity Tracking.

**Post-design re-check**: Sau khi hoàn tất Phase 1 (research.md, data-model.md, contracts/,
quickstart.md), cả 5 nguyên tắc vẫn PASS. Quyết định đơn giản hoá backend (không repository riêng,
không JOIN) và mẫu lai frontend (Add trang riêng + Edit popup) không phát sinh vi phạm mới — vẫn
nằm trong ranh giới layer đã định (Nguyên tắc I) và tái sử dụng đúng các mẫu tham chiếu hiện có
(Nguyên tắc II).

**Re-check sau Update 3** (thêm Type/List PO/Manual chỉ giao diện): vẫn PASS cả 5 nguyên tắc —
thay đổi giới hạn trong `presentation/` (Nguyên tắc I, không đụng domain/infrastructure/
application), ghép 2 mẫu nguyên tử sẵn có (`Select` của `eutr-templates` + cặp handler kéo-thả
no-op của `MapDataDialog.jsx`, research Quyết định 8) thay vì phát minh mới (Nguyên tắc II); không
có endpoint/DTO mới nên Nguyên tắc III không áp dụng; nhãn "PO"/"Upload manual"/"Assign condition" vẫn
tiếng Anh theo FR-015 (Nguyên tắc IV); không có route/menu mới (Nguyên tắc V không đổi).

**Re-check sau Update 4** (List PO nối `refType 15`/`16`): vẫn PASS cả 5 nguyên tắc — thay đổi
backend giới hạn trong `Application/Services/ComplDynamicsService.cs` (mở rộng bảng ánh xạ có sẵn,
không thêm layer/entity mới → Nguyên tắc I); tái dùng nguyên vẹn endpoint `POST
/api/dynamics/reference` và hook frontend `useReferenceObjects` đã có (Nguyên tắc II + III — đúng
tinh thần "Reuse Existing Backend", không tạo controller/route/DTO mới); không đổi UI label nào
(Nguyên tắc IV không đổi); không có route/menu mới (Nguyên tắc V không đổi, `refType = 16` không
có UI nên không phát sinh yêu cầu policy/route nào).

**Re-check sau Update 5** (ô tìm kiếm PO gọi API, không sửa backend): vẫn PASS cả 5 nguyên tắc —
thay đổi giới hạn trong `EutrDocumentsAdd.jsx` (`presentation/`, Nguyên tắc I không đổi); tái dùng
nguyên vẹn `useReferenceObjects` + `lodash.debounce` theo đúng mẫu `ReferenceObjectAutocomplete.jsx`
(Nguyên tắc II) và filter Code/Name generic đã có sẵn ở backend từ Update 4 — **không sửa backend**
(Nguyên tắc III, mức độ "reuse" cao nhất trong các Update); không đổi UI label nào (Nguyên tắc IV
không đổi); không có route/menu/policy mới (Nguyên tắc V không đổi).

**Re-check sau Update 6** (nút Upload thật lên SharePoint ở Screen1): vẫn PASS cả 5 nguyên tắc —
backend `EutrUploadService` mới nằm đúng layer `Application` (gọi `ISharepointService`/
`IRepository<,>`/`IUnitOfWork` đã có, không có business logic nào lọt vào `SharePointController`
ngoài validate request tối thiểu — Nguyên tắc I); action mới trong `SharePointController` clone
đúng mẫu `upload-multi` đã có (Nguyên tắc II), tự thao tác `IRepository<EutrDocuments,long>` trực
tiếp theo đúng mẫu `ComplUploadService`→`IComplSharepointFileService.AddAsync(entity,...)` khi DTO
CRUD chuẩn không đủ field (Nguyên tắc II); tái dùng `ISharepointService` có sẵn cho mọi thao tác
SharePoint (Nguyên tắc III — không tạo tích hợp Graph API mới), frontend tái dùng
`ISharePointRepository`/`RestSharePointRepository`/`UploadToSharePointUseCase` có sẵn thay vì tạo
domain/infrastructure/application mới (Nguyên tắc III); không có UI label tiếng Việt phát sinh, chữ
"Upload" theo đúng FR-015 (Nguyên tắc IV không đổi); không có route/menu/policy mới — action mới
dùng chung `[Authorize]` của `SharePointController` (không thêm policy riêng theo action, đúng mẫu
`upload`/`upload-multi` hiện có, Nguyên tắc V không đổi).

**Re-check sau Update 7** (thiết kế lại khu Upload + validate prefix + ghi `eutr_references`): vẫn
PASS cả 5 nguyên tắc — entity mới `EutrReferences.cs` nằm đúng `Domain/Entities` (Nguyên tắc I),
dùng `IRepository<,>` generic thay vì tạo layer/repository riêng khi không cần SQL tùy biến (đúng
mẫu `EutrDocuments`, Nguyên tắc II); method tra cứu prefix mới được **thêm vào**
`IEutrMastersRepository` đã tồn tại (Nguyên tắc II + III — mở rộng abstraction có sẵn của
`002-eutr-masters` thay vì viết SQL thô trong `EutrUploadService` hay tạo repository trùng lặp);
migration chỉ **thêm cột mới** `StepId` (không sửa/xóa ràng buộc `RefId` hiện có) nên không phá vỡ
thiết kế cũ của `eutr_references`/`eutr_template_details`; frontend dùng `CloudUploadIcon` có sẵn
trong `@mui/icons-material` (không thêm dependency), gộp logic click/kéo-thả thay vì trùng lặp
(Nguyên tắc II); không có UI label tiếng Việt phát sinh (Nguyên tắc IV không đổi); không có
route/menu/policy mới — vẫn dùng chung `[Authorize]` của `SharePointController`, endpoint
`eutr-upload-multi` giữ nguyên path/contract (Nguyên tắc V không đổi).

**Re-check sau Update 8** (nạp Step name/Type + File name/Step name qua `eutr_references`): vẫn
PASS cả 5 nguyên tắc — `EutrReferencesRepository` mới nằm đúng `Infrastructure/Repositories`, chỉ
được gọi qua interface `IEutrReferencesRepository` từ `Application/Services/EutrDocumentsService.cs`
(Nguyên tắc I, không có SQL nào lọt lên Controller); repository mới clone đúng cấu trúc
`DapperRepository<,>` subclass của `EutrMastersRepository` (Nguyên tắc II), và cách gộp dữ liệu
"1 query cha + 1 query con WHERE IN + gộp bộ nhớ" clone đúng
`ComplCountryGroupService.AttachMembersAsync` đã có sẵn (Nguyên tắc II + III — tái dùng mẫu, không
phát minh cách gộp mới); endpoint mới `list-po-references` đặt trong `EutrDocumentsController` hiện
có, dùng chung policy `EutrDocuments.ReadAll` (Nguyên tắc III + V, không thêm policy/route/menu
nào); không có UI label tiếng Việt phát sinh (Nguyên tắc IV không đổi); component `MultiValueChips`
mới không thêm dependency (chỉ dùng `Chip`/`Tooltip` của `@mui/material` đã có), tái dùng logic đã
có ở `useCountryGroupColumns.jsx` (Nguyên tắc II).

**Re-check sau Update 9** (Delete xóa kèm `eutr_references`): vẫn PASS cả 5 nguyên tắc — override
`DeleteAsync`/`DeleteMultiAsync` nằm đúng `Application/Services/EutrDocumentsService.cs`, gọi
`IEutrReferencesRepository` (Infrastructure) qua interface, không có SQL nào lọt lên Controller
(Nguyên tắc I); method mới `DeleteByDocumentIdAsync` **thêm vào** `IEutrReferencesRepository` đã
tồn tại từ Update 8 thay vì tạo repository mới, và cấu trúc override clone đúng mẫu
`ComplJobScheduleConfigService.DeleteAsync` (override base, cleanup resource liên quan, wrap
transaction, rollback khi lỗi) — tái dùng pattern đã có trong codebase thay vì phát minh mới
(Nguyên tắc II); không sửa `IBaseService`/`IEutrDocumentsService` (interface dùng chung cho mọi
feature CRUD khác) — chỉ override trong service cụ thể của feature này (Nguyên tắc III, đúng tinh
thần "Reuse Existing Backend" — không phá vỡ hợp đồng chung); không có UI label tiếng Việt phát
sinh, không đổi text hiển thị nào (Nguyên tắc IV không đổi); không có route/DTO/policy/menu mới —
`DELETE /{id}` và `POST /delete-multi` giữ nguyên path/contract, chỉ đổi hành vi nội bộ (Nguyên tắc
V không đổi).

**Re-check sau Update 10** (icon View mở xem file thật + Delete từng file ở List PO): vẫn PASS cả 5
nguyên tắc — endpoint mới `get-file-by-idref` đặt trong `EutrDocumentsController` hiện có (đúng
domain "eutr-documents", Nguyên tắc I); việc controller inject `ISharepointService` trực tiếp (bỏ
qua Application service) clone đúng tiền lệ đã tồn tại 2 lần trong codebase
(`ComplCompliancesController`, `SharePointController` — cùng loại thao tác "proxy đọc file
SharePoint mỏng"), không phải ngoại lệ mới riêng của feature này (Nguyên tắc II); logic đọc file
tái dùng nguyên vẹn `ISharepointService.ReadFileWithMetaAsync` đã có, không tạo tích hợp SharePoint
mới (Nguyên tắc III); `FilePreviewer.jsx` được tổng quát hoá bằng 2 prop tùy chọn có giá trị mặc
định giữ đúng hành vi cũ cho `compliance-detail` — không nhân bản ~500 dòng logic render, không phá
vỡ caller hiện có (Nguyên tắc II + III); Delete từng file ở List PO dùng lại nguyên vẹn
`DELETE /api/eutr-documents/{id}` đã có (không có endpoint xóa mới, không có logic xóa mới ở
backend — Nguyên tắc III); không có UI label tiếng Việt phát sinh, tooltip "No file to view" theo
đúng FR-015 (Nguyên tắc IV không đổi); không có route/DTO/policy/menu mới — endpoint mới dùng chung
policy `EutrDocuments.ReadOne` đã có (Nguyên tắc V không đổi).

## Project Structure

### Documentation (this feature)

```text
specs/004-eutr-documents/
├── plan.md              # File này
├── spec.md              # Đặc tả
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── eutr-documents-api.md   # Hợp đồng API MỚI (cần tạo)
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

Backend — **TẠO MỚI** (clone mẫu `EutrStep`; đặt tên `EutrDocuments` / `eutr-documents`):

```text
compliance-sys-api/src/
├── ComplianceSys.Domain/Entities/
│   └── EutrDocuments.cs                               # Table("eutr_documents"): Id, Name, FileId, ValidFrom, ValidTo (+ BaseEntity audit)
├── ComplianceSys.Application/
│   ├── Dtos/Request/EutrDocumentsRequestDto.cs        # { Name, ValidFrom, ValidTo } — KHÔNG có FileId (chưa upload file)
│   ├── Dtos/Response/EutrDocumentsResponseDto.cs      # : EutrDocuments {} (subclass trống, không JOIN — mẫu EutrStepResponseDto)
│   ├── Interfaces/Services/IEutrDocumentsService.cs   # : IBaseService<EutrDocuments,long,EutrDocumentsRequestDto> + GetPagedAsync
│   ├── Services/EutrDocumentsService.cs               # : BaseService<...> — GetPagedAsync gọi base + map sang ResponseDto (mẫu EutrStepService, KHÔNG override AddAsync/UpdateAsync)
│   ├── Validators/EutrDocumentsRequestDtoValidator.cs # Name NotEmpty(); ValidFrom/ValidTo không bắt buộc
│   └── Mappings/EutrMappingProfile.cs                 # (SỬA) thêm 3 CreateMap cho EutrDocuments (mẫu khối EutrStep)
├── ComplianceSys.Api/Controllers/
│   └── EutrDocumentsController.cs                     # Route "api/eutr-documents": get-by-id, get-all (paged), create, update, delete, delete-multi
├── ComplianceSys.Infrastructure/Sqls/Migration/
│   └── 09_migrate_eutr_documents_name.sql             # ALTER TABLE eutr_documents MODIFY COLUMN Name VARCHAR(255) NULL;
└── (SỬA) ComplianceSys.Application/DependencyInjection.cs  # đăng ký IEutrDocumentsService, validator (KHÔNG cần sửa Infrastructure DI — repository generic open-generic đã đăng ký sẵn cho mọi entity)
```

Backend — **Update 4** (List PO nối `refType 15`/`16`, KHÔNG thuộc controller `eutr-documents`):

```text
compliance-sys-api/src/
├── ComplianceSys.Domain/Dynamics/
│   ├── RSVNEutrPurchOrders.cs                         # ĐÃ TỒN TẠI SẴN (ModelType = 15) — không sửa
│   └── RSVNEutrSalesOrderPurchases.cs                 # ĐÃ TỒN TẠI SẴN (ModelType = 16) — không sửa
├── ComplianceSys.Application/Services/
│   └── ComplDynamicsService.cs                        # (SỬA) thêm 2 dòng EntityMappings (15, 16) + 2 case trong MapDynamicsResponse
└── (Tùy chọn, SỬA) ComplianceSys.Application/Constants/ComplEnum.cs  # thêm ObjectType.EUTR_PURCH_ORDER = 15, EUTR_SALES_ORDER_PURCHASE = 16 (không bắt buộc — chỉ để đọc code dễ hơn, không có nhánh xử lý riêng nào cần enum này)
```

Frontend — **Update 4** (sửa 1 file hiện có, KHÔNG thêm domain/infrastructure/application mới —
tái dùng nguyên vẹn `GetReferenceDataUseCase`/`useReferenceObjects` đã có sẵn từ trước):

```text
compliance-client/src/presentation/pages/eutr-documents/
└── EutrDocumentsAdd.jsx   # (SỬA — Update 4) Screen1: thay DEMO_PO_LIST bằng useReferenceObjects().fetchReferenceObjects(15) cho cột PO name; dùng loading/error có sẵn của hook cho trạng thái trống/lỗi (FR-017, SC-010); cột File name + Action View/Delete trên List PO giữ nguyên (trống/no-op, Update 3)
```

Frontend — **Update 5** (sửa cùng 1 file, KHÔNG sửa backend — filter Code/Name generic đã hoạt
động sẵn từ Update 4):

```text
compliance-client/src/presentation/pages/eutr-documents/
└── EutrDocumentsAdd.jsx   # (SỬA — Update 5) Ô tìm kiếm PO: bỏ filteredPoList/poSearchTerms (lọc cục bộ); gọi fetchReferenceObjects(15, poSearch) qua lodash.debounce (500ms, mẫu ReferenceObjectAutocomplete.jsx) mỗi khi poSearch đổi; danh sách hiển thị trực tiếp poList (đã lọc ở server) (FR-023)
```

Backend — **Update 6** (nút Upload thật lên SharePoint ở Screen1 — **TẠO MỚI** `EutrUploadService`,
KHÔNG sửa `EutrDocumentsController`/`EutrDocumentsService`/`ComplUploadService`):

```text
compliance-sys-api/src/
├── ComplianceSys.Application/
│   ├── Dtos/Request/EutrMultiUploadFileRequest.cs      # MỚI: { List<IFormFile> Files, string PoCode } — [FromForm], mẫu MultiUploadFileRequest nhưng PoCode thay cho FolderPath
│   ├── Dtos/Response/EutrUploadFileResultDto.cs        # MỚI: { FileName, Success, ErrorMessage?, DocumentId?, FileId? } — kết quả per-file (FR-030)
│   ├── Interfaces/Services/IEutrUploadService.cs       # MỚI: UploadMultipleToSharePointAndSaveDataAsync(EutrMultiUploadFileRequest, string email, CancellationToken) -> Task<List<EutrUploadFileResultDto>>
│   └── Services/EutrUploadService.cs                   # MỚI: ISharepointService + IRepository<EutrDocuments,long> + IUnitOfWork + IConfiguration — validate file (đuôi/10MB), GetFolders/CreateFolder theo PoCode dưới SharePointEutrPath, upload từng file, ghi eutr_documents per-file trong transaction riêng (research Quyết định 11/13/14)
├── ComplianceSys.Api/Controllers/
│   └── SharepointController.cs                         # (SỬA) + constructor param IEutrUploadService _eutrUploadService; + action [HttpPost("eutr-upload-multi")] [Consumes("multipart/form-data")] (mẫu UploadMultiToSharePointAndSaveData hiện có, dùng _configuration["SharePointEutrPath"])
├── ComplianceSys.Application/DependencyInjection.cs    # (SỬA) + services.AddScoped<IEutrUploadService, EutrUploadService>();
└── ComplianceSys.Api/
    ├── appsettings.json                                # (SỬA) + "SharePointEutrPath": "Sandbox/Eutr" (khóa mới, cạnh SharePointCompPath hiện có)
    └── appsettings.Development.json                    # (SỬA) + "SharePointEutrPath": "Dev/Eutr"
```

Frontend — **Update 6** (mở rộng hạ tầng SharePoint đã có, KHÔNG tạo domain/infrastructure/
application mới):

```text
compliance-client/src/
├── domain/interfaces/ISharePointRepository.js          # (SỬA) + uploadEutrFilesMulti(_files, _poCode) { throw new Error('Method not implemented'); }
├── infrastructure/repositories/RestSharePointRepository.js  # (SỬA) + uploadEutrFilesMulti(files, poCode): FormData { files[], poCode } -> POST /sharepoint/eutr-upload-multi (mẫu uploadFileMulti hiện có)
├── application/usecases/sharepoint/UploadToSharePointUseCase.js  # (SỬA) + executeEutrMulti(files, poCode) { return this.sharePointRepository.uploadEutrFilesMulti(files, poCode); }
└── presentation/pages/eutr-documents/
    └── EutrDocumentsAdd.jsx   # (SỬA — Update 6) Screen1: bỏ khu "Drag and drop files to upload" no-op; + state selectedPoCode (click 1 dòng List PO qua onRowClick, tô nổi dòng đang chọn); + nút "Upload" (disabled khi !selectedPoCode) + <input type="file" multiple hidden> trigger qua ref; validate đuôi/kích thước phía client trước khi gọi executeEutrMulti(files, selectedPoCode); hiển thị kết quả qua snackbar (số file thành công/thất bại, liệt kê lỗi per-file) — FR-024 đến FR-030
```

Backend — **Update 7** (validate prefix + ghi `eutr_references`, migration thêm cột `StepId` —
KHÔNG sửa endpoint/contract của `eutr-upload-multi`, chỉ đổi logic bên trong `EutrUploadService`):

```text
compliance-sys-api/src/
├── ComplianceSys.Domain/Entities/
│   └── EutrReferences.cs                               # MỚI: Table("eutr_references"): Id, RefId (long?, không dùng ở feature này), DocumentId (long?), StepId (long?, cột MỚI), RefType (byte?), RefValue (string?) + BaseEntity audit — dùng thẳng IRepository<EutrReferences,long> generic, không tạo repository riêng (research Quyết định 16)
├── ComplianceSys.Application/Interfaces/Repositories/
│   └── IEutrMastersRepository.cs                       # (SỬA) + Task<List<EutrMastersDocument>> GetMatchingPrefixesAsync(string fileName, CancellationToken ct)
├── ComplianceSys.Infrastructure/Repositories/
│   └── EutrMastersRepository.cs                        # (SỬA) + implement GetMatchingPrefixesAsync: SQL "đảo chiều LIKE" (@fileName LIKE CONCAT(escape(Prefix), '%')), escape \\/%/_ trong Prefix (research Quyết định 17)
├── ComplianceSys.Application/Services/
│   └── EutrUploadService.cs                            # (SỬA) + constructor param IEutrMastersRepository + IRepository<EutrReferences,long>; trước khi upload SharePoint: gọi GetMatchingPrefixesAsync(file.FileName), loại file nếu 0 kết quả (FR-032); sau khi upload SharePoint thành công: 1 transaction ghi eutr_documents + N dòng eutr_references (1 dòng/StepId phân biệt, DocumentId chung, RefType=0, RefValue=poCode) — rollback cả nhóm nếu bất kỳ bước nào lỗi (research Quyết định 18)
└── ComplianceSys.Infrastructure/Sqls/Migration/
    └── 10_add_stepid_to_eutr_references.sql            # MỚI: ALTER TABLE eutr_references ADD COLUMN StepId BIGINT UNSIGNED NULL AFTER RefId; + FK eutr_references_stepid_foreign → eutr_steps(Id) — KHÔNG đụng cột/FK RefId hiện có
```

Đồng thời cập nhật `docs/design/eutr/eutr_db.sql` và
`ComplianceSys.Infrastructure/Sqls/Tables/eutr_db.sql` (DDL build) để khớp cột `StepId` mới trên
`eutr_references`.

Frontend — **Update 7** (thiết kế lại card Upload theo `upload.png` + kéo-thả thật, sửa 1 file):

```text
compliance-client/src/presentation/pages/eutr-documents/
└── EutrDocumentsAdd.jsx   # (SỬA — Update 7) Tách logic xử lý File[] (validate + executeEutrMulti) ra khỏi nguồn sự kiện — dùng chung cho input onChange VÀ onDrop (đọc e.dataTransfer.files); đổi UI khu Upload (Screen1) sang card theo upload.png: Typography "Upload File", Box viền nét đứt + CloudUploadIcon (@mui/icons-material) + text "Drop file here or click to browse" (vừa là nút click vừa là vùng thả file), dòng phụ + hàng Chip liệt kê định dạng/kích thước thật (PDF, DOC/DOCX, XLS/XLSX, JPG/PNG, Max 10MB — không theo số liệu trong ảnh mẫu); card bị làm mờ (opacity + pointerEvents none) khi chưa chọn PO (FR-024, FR-031)
```

Backend — **Update 8** (nạp Step name/Type + File name/Step name qua `eutr_references`, KHÔNG
migration DB mới — chỉ thêm truy vấn đọc):

```text
compliance-sys-api/src/
├── ComplianceSys.Application/
│   ├── Interfaces/Repositories/IEutrReferencesRepository.cs   # MỚI: GetStepInfoByDocumentIdsAsync(IEnumerable<long>), GetDocumentsByPoCodesAsync(IEnumerable<string>)
│   ├── Dtos/Response/EutrReferenceStepInfo.cs                 # MỚI: projection { DocumentId, StepName, RefType } — kết quả thô của GetStepInfoByDocumentIdsAsync
│   ├── Dtos/Response/EutrReferencePoDocumentInfo.cs           # MỚI: projection { PoCode, DocumentId, FileName, StepName } — kết quả thô của GetDocumentsByPoCodesAsync
│   ├── Dtos/Request/EutrDocumentsListPoReferencesRequestDto.cs # MỚI: { List<string> PoCodes }
│   ├── Dtos/Response/EutrDocumentsPoReferenceDto.cs            # MỚI: { string PoCode, List<EutrDocumentsPoReferenceItemDto> Documents }
│   ├── Dtos/Response/EutrDocumentsPoReferenceItemDto.cs        # MỚI: { long DocumentId, string FileName, List<string> StepNames }
│   ├── Dtos/Response/EutrDocumentsResponseDto.cs               # (SỬA) + List<string> StepNames = []; + byte? RefType
│   ├── Interfaces/Services/IEutrDocumentsService.cs            # (SỬA) + Task<List<EutrDocumentsPoReferenceDto>> GetPoReferencesAsync(List<string> poCodes, CancellationToken ct)
│   └── Services/EutrDocumentsService.cs                        # (SỬA) + inject IEutrReferencesRepository; GetPagedAsync gọi GetStepInfoByDocumentIdsAsync(ids trong trang) rồi group theo DocumentId để gán StepNames/RefType (clone AttachMembersAsync); + implement GetPoReferencesAsync (group GetDocumentsByPoCodesAsync theo PoCode → DocumentId)
├── ComplianceSys.Infrastructure/
│   ├── Repositories/EutrReferencesRepository.cs                # MỚI: DapperRepository<EutrReferences,long>, IEutrReferencesRepository — clone mẫu EutrMastersRepository (chỉ nhận IUnitOfWork), 2 method JOIN SQL (xem data-model.md)
│   └── DependencyInjection.cs                                  # (SỬA) + services.AddScoped<IEutrReferencesRepository, EutrReferencesRepository>();
└── ComplianceSys.Api/Controllers/
    └── EutrDocumentsController.cs                               # (SỬA) + [HttpPost("list-po-references")] [Authorize(Policy = "EutrDocuments.ReadAll")] GetPoReferences(EutrDocumentsListPoReferencesRequestDto request, CancellationToken ct) → gọi _service.GetPoReferencesAsync
```

Frontend — **Update 8** (nạp dữ liệu thật cho Step name/Type/File name, thêm component chia sẻ
`MultiValueChips`):

```text
compliance-client/src/
├── presentation/components/common/MultiValueChips.jsx          # MỚI: { values: string[], previewLimit = 2 } — clone logic chip + "+N more" + Tooltip đang inline ở cột "Country Codes" (useCountryGroupColumns.jsx); dùng ở 2 nơi dưới
├── application/usecases/eutr-documents/
│   └── GetEutrDocumentsPoReferencesUseCase.js                  # MỚI: execute(poCodes) { return this.repository.getPoReferences(poCodes); }
├── domain/
│   ├── entities/EutrDocuments.js                               # (SỬA) + stepNames: [], refType: null
│   └── interfaces/IEutrDocumentsRepository.js                  # (SỬA) + getPoReferences(_poCodes) { throw new Error('Method not implemented'); }
├── infrastructure/
│   ├── api/eutrDocumentsApi.js                                 # (SỬA) + listPoReferences(payload) -> POST /eutr-documents/list-po-references
│   └── repositories/RestEutrDocumentsRepository.js             # (SỬA) + getPoReferences(poCodes): gọi eutrDocumentsApi.listPoReferences({ poCodes }), trả thẳng data (không cần map entity riêng — đã đúng hình dạng { poCode, documents }); getAllPaging mapping đảm bảo truyền qua stepNames/refType từ response vào entity EutrDocuments
└── presentation/pages/eutr-documents/
    ├── hooks/useEutrDocumentsColumns.jsx                        # (SỬA) cột "stepName": renderCell dùng <MultiValueChips values={row.stepNames} /> (bỏ comment "luôn trống" cũ); cột "type": renderCell map row.refType qua TAKE_FROM_OPTIONS lấy label; cột "conditions" không đổi (vẫn trống)
    └── EutrDocumentsAdd.jsx                                     # (SỬA) + state poReferenceDocuments; useEffect gọi getEutrDocumentsPoReferencesUseCase.execute([selectedPo.code]) khi selectedPoId đổi; bảng chi tiết (Grid size=5) đổi từ 1 TableRow placeholder tĩnh sang .map() qua poReferenceDocuments (File name = doc.fileName, Step name = <MultiValueChips values={doc.stepNames} />), "No data" khi rỗng
```

Backend — **Update 9** (Delete xóa kèm `eutr_references`, KHÔNG migration DB mới, KHÔNG đổi
route/DTO/controller — chỉ sửa 3 file hiện có):

```text
compliance-sys-api/src/
├── ComplianceSys.Application/
│   ├── Interfaces/Repositories/IEutrReferencesRepository.cs   # (SỬA) + Task DeleteByDocumentIdAsync(long documentId, CancellationToken ct = default)
│   └── Services/EutrDocumentsService.cs                       # (SỬA) + field riêng _unitOfWork (đã nhận qua constructor, trước đây chỉ truyền cho base); + override DeleteAsync (thêm bước _referencesRepository.DeleteByDocumentIdAsync trong cùng transaction, mẫu ComplJobScheduleConfigService.DeleteAsync); + override DeleteMultiAsync (1 transaction riêng/document trong vòng lặp, gom lỗi vào 1 exception tổng hợp sau vòng lặp, KHÔNG dùng 1 transaction chung cho cả batch như base — mẫu per-item try/catch của EutrUploadService, research Quyết định 24)
└── ComplianceSys.Infrastructure/Repositories/
    └── EutrReferencesRepository.cs                             # (SỬA) + implement DeleteByDocumentIdAsync: Connection.ExecuteAsync("DELETE FROM eutr_references WHERE DocumentId = @DocumentId", transaction: Transaction) — cùng style CommandDefinition đã dùng ở 2 method đọc hiện có
```

Frontend — **Update 9**: không có thay đổi nào — luồng Delete/DeleteMulti hiện có
(`DeleteEutrDocumentsUseCase`/`DeleteMultiEutrDocumentsUseCase` → `DELETE /eutr-documents/{id}` /
`POST /eutr-documents/delete-multi`) giữ nguyên; chỉ backend thay đổi hành vi nội bộ.

Backend — **Update 10** (endpoint mới `get-file-by-idref` trong `EutrDocumentsController` hiện có,
KHÔNG migration DB mới — chỉ thêm 1 field vào 1 SQL JOIN đã có):

```text
compliance-sys-api/src/
├── ComplianceSys.Api/Controllers/
│   └── EutrDocumentsController.cs                          # (SỬA) + constructor param ISharepointService _sharepointService (Shared.ExternalServices.Interfaces, đã đăng ký DI sẵn); + [Authorize(Policy = "EutrDocuments.ReadOne")] [HttpGet("get-file-by-idref")] GetFileByIdRef([FromQuery] string idRef) — clone nguyên vẹn ComplCompliancesController.GetFileByIds (cùng retry/500/503)
├── ComplianceSys.Application/Dtos/Response/
│   ├── EutrReferencePoDocumentInfo.cs                       # (SỬA) + public string? FileId { get; set; }
│   └── EutrDocumentsPoReferenceItemDto.cs                   # (SỬA) + public string? FileId { get; set; }
├── ComplianceSys.Infrastructure/Repositories/
│   └── EutrReferencesRepository.cs                          # (SỬA) GetDocumentsByPoCodesAsync: SQL SELECT thêm "d.FileId AS FileId"
└── ComplianceSys.Application/Services/
    └── EutrDocumentsService.cs                              # (SỬA) GetPoReferencesAsync: gán FileId = g.First().FileId khi dựng EutrDocumentsPoReferenceItemDto
```

Frontend — **Update 10** (icon View mở xem file thật + Delete từng file ở List PO — tổng quát hoá
`FilePreviewer.jsx` bằng 2 prop tùy chọn, KHÔNG nhân bản logic render; component mới scoped riêng
cho feature này):

```text
compliance-client/src/
├── presentation/components/
│   └── FilePreviewer.jsx                                    # (SỬA) + prop tùy chọn fetchFile = (idRef) => getFileByIdRefUseCase.execute(idRef) (giữ đúng default cho compliance-detail); + prop tùy chọn onLoaded = () => {} (gọi kèm {content, contentType, fileName} sau khi tải xong); loadFileData đổi sang gọi fetchFile(idFile) thay vì gọi cứng use case cũ — KHÔNG đổi logic render PDF/DOCX/XLSX/ảnh
├── infrastructure/
│   ├── api/eutrDocumentsApi.js                              # (SỬA) + getFileByIdRef: (fileId) => axiosInstance.get('/eutr-documents/get-file-by-idref', { params: { idRef: fileId } })
│   └── repositories/RestEutrDocumentsRepository.js          # (SỬA) + async getFileByIdRef(fileId) { const res = await eutrDocumentsApi.getFileByIdRef(fileId); return res.data; }
├── domain/interfaces/IEutrDocumentsRepository.js            # (SỬA) + async getFileByIdRef(_fileId) { throw new Error('Not implemented') }
├── application/usecases/eutr-documents/
│   └── GetEutrDocumentsFileByIdRefUseCase.js                 # MỚI: execute(fileId) { return this.repository.getFileByIdRef(fileId); } — mẫu GetFileByIdRefUseCase của compliances
└── presentation/pages/eutr-documents/
    ├── components/
    │   ├── EutrFileViewerDialog.jsx                          # MỚI: Dialog MUI bọc <FilePreviewer idFile={fileId} fetchFile={getEutrDocumentsFileByIdRefUseCase.execute} onLoaded={setLoadedFile} />; nút Download dựng Blob từ loadedFile.content (base64 → Uint8Array → Blob → <a download> tạm, không gọi API thứ 2); nút Close — KHÔNG tái dùng luồng zip/progress-dialog của DialogFilePreviewer.jsx (research Quyết định 27)
    │   └── EutrDocumentsActionCell.jsx                       # (SỬA) icon View: bỏ onClick={() => {}}; nhận thêm prop onView + disabled={!row.fileId}; title={row.fileId ? 'View' : 'No file to view'}
    ├── hooks/useEutrDocumentsColumns.jsx                     # (SỬA) nhận thêm prop onView, truyền xuống EutrDocumentsActionCell
    ├── index.jsx                                             # (SỬA) + state viewerFile ({open, fileId, fileName}); onView: (row) => setViewerFile({ open: true, fileId: row.fileId, fileName: row.name }); render <EutrFileViewerDialog ... />
    └── EutrDocumentsAdd.jsx                                  # (SỬA) trong bảng chi tiết List PO (đã có sẵn cấu trúc "1 dòng = 1 document" từ Update 8): icon View trên mỗi dòng đổi onClick={() => {}} → mở EutrFileViewerDialog với {fileId: doc.fileId, fileName: doc.fileName}; icon Delete đổi onClick={() => {}} → mở ConfirmDialog, xác nhận thì gọi deleteEutrDocumentsUseCase.execute(doc.documentId) (dùng lại DeleteEutrDocumentsUseCase có sẵn) rồi refetch poReferenceDocuments của PO đang chọn — KHÔNG gọi API xóa file SharePoint nào
```

`EutrDocumentsModal.jsx`/`EutrDocumentsData.js`/`di/repositories.js`/routing: không đổi.

Frontend — **CÁC FILE MỚI** (clone `eutr-masters` cho list/Edit-popup; clone routing `eutr-templates` cho Add):

```text
compliance-client/src/
├── domain/
│   ├── entities/EutrDocuments.js                      # { id, name, fileId, validFrom, validTo, createdBy, createdDate, updatedBy, updatedDate }
│   └── interfaces/IEutrDocumentsRepository.js         # getAllPaging/getById/create/update/delete/deleteMulti
├── infrastructure/
│   ├── api/eutrDocumentsApi.js                        # base "/eutr-documents" (mẫu eutrMastersApi.js, bỏ import/export)
│   └── repositories/RestEutrDocumentsRepository.js
├── application/usecases/eutr-documents/
│   ├── CreateEutrDocumentsUseCase.js
│   ├── UpdateEutrDocumentsUseCase.js
│   ├── DeleteEutrDocumentsUseCase.js
│   ├── DeleteMultiEutrDocumentsUseCase.js
│   └── GetPagingEutrDocumentsUseCase.js
├── presentation/pages/eutr-documents/
│   ├── index.jsx                                      # DataGrid + toolbar (nút Add → navigate('/eutr/documents/add'), Delete nhiều) + EutrDocumentsModal (Edit) + ConfirmDialog (mẫu eutr-masters/index.jsx, bỏ Import/Export)
│   ├── EutrDocumentsAdd.jsx                            # Trang riêng: TextField File name + 2 date field Valid from/to + nút Save + nút Back (mẫu wiring EutrTemplatesAddEdit.jsx, KHÔNG có cây bước/dirty-check — Back điều hướng thẳng theo Edge Case đã chốt)
│   │                                                    # (SỬA — Update 3) + Select "Type" (PO/Manual, mặc định PO, mẫu Select của EutrTemplatesAddEdit.jsx) + block Screen1 (List PO tĩnh + khu "Drag and drop files to upload" no-op) khi Type=PO + block Screen2 (khu upload no-op + nút "Assign condition" no-op + bảng file tĩnh) khi Type=Manual — toàn bộ chỉ giao diện, không gọi API (research Quyết định 8, FR-016 đến FR-020)
│   ├── components/
│   │   ├── EutrDocumentsModal.jsx                     # Popup Edit: TextField File name + 2 date field Valid from/to (mẫu EutrMastersModal.jsx, thay Autocomplete+TextField bằng 3 field này)
│   │   └── EutrDocumentsActionCell.jsx                # Edit / Delete / View (icon thứ 3, active, onClick no-op — mẫu EutrMastersActionCell.jsx + IconButton VisibilityIcon)
│   └── hooks/
│       ├── useEutrDocumentsColumns.jsx                # cột: fileName(Name), stepName/conditions/type (luôn trống — không map field nào), validFrom, validTo, createdBy, createdDate, actions
│       └── useEutrDocumentsData.js
├── (SỬA) di/repositories.js                            # eutrDocuments: new RestEutrDocumentsRepository()
├── (SỬA) app/routes/RouteResolver.jsx                  # lazy import + componentMap["eutr-documents"] (trang list)
├── (SỬA) app/routes/groups/MainRoutes.jsx              # thêm route "/eutr/documents/add" → EutrDocumentsAdd (KHÔNG có route edit — Edit là popup)
└── (SỬA) presentation/menu-items/ComplianceSystem.jsx  # menu item code "eutr-documents", url "/eutr/documents" (theo đúng thực tế đã làm ở eutr-masters/eutr-templates; hiển thị/quyền thực tế vẫn do backend userMenu quyết định — xem research Quyết định 7)
```

**Structure Decision**: Web application. Feature triển khai **cả backend lẫn frontend**. Mẫu tham
chiếu chuẩn: **EutrStep** (backend CRUD, không JOIN/không repository riêng) + **eutr-masters**
(frontend list + popup Edit) + **eutr-templates** (routing trang riêng cho Add).

### Key Differences from Reference Features

| Aspect              | eutr-steps / eutr-masters (reference)             | eutr-documents (this feature)                                                                                                                  |
| ------------------- | ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Add UI              | Modal (cả add + edit)                            | **Trang riêng** cho Add (`/eutr/documents/add`); Edit vẫn là **popup**                                                        |
| Backend repository  | Steps: generic; Masters: repository riêng (JOIN) | **Generic thuần** `IRepository<EutrDocuments,long>` — không JOIN, không repository riêng (giống Steps)                            |
| Chống trùng       | Masters: có (StepId+Prefix)                      | **Không** — File name không cần duy nhất (FR-007b)                                                                                  |
| Cột Action         | Edit / Delete                                     | Edit / Delete /**View** (placeholder, active bình thường, click không làm gì)                                                      |
| Trường file       | N/A                                               | `FileId` tồn tại trong entity/DB nhưng **KHÔNG được set** bởi feature này (Add chưa có upload)                              |
| Cột grid           | Map trực tiếp dữ liệu                         | Ban đầu 3 cột (**Step name, Conditions, Type**) khai báo trên grid nhưng không map field nào → luôn trống (FR-003). **Update 8**: Step name/Type đã nạp dữ liệu thật qua JOIN `eutr_references`/`eutr_steps` (FR-034/FR-035); **Conditions vẫn luôn trống** (FR-036, không đổi) |
| Migration DB        | N/A                                               | Cột`Name`: BIGINT → VARCHAR(255) (migration mới)                                                                                          |
| Nút Back trang Add | N/A (Masters dùng popup Cancel)                  | Điều hướng thẳng về danh sách,**không cảnh báo mất dữ liệu** (form đơn giản — khác `eutr-templates` có dirty-check) |
| Type + List PO/Manual (Update 3) | N/A                                    | Chỉ có ở trang Add, **thuần giao diện**: `Select` 2 lựa chọn + 2 layout tĩnh với dữ liệu hard-code, không entity/DTO/API nào; mọi tương tác trong khu vực này là no-op (kéo-thả, Assign condition, View/Delete/checkbox demo) |
| List PO — cột PO name (Update 4) | N/A                                    | Duy nhất trong feature này có gọi API thật: `POST /api/dynamics/reference?refType=15` (D365 `RSVNEutrPurchOrders`) qua hook `useReferenceObjects` có sẵn — KHÔNG qua route `api/eutr-documents`. Cột File name/Action trên cùng bảng vẫn demo/no-op |
| Ô tìm kiếm PO (Update 5) | N/A                                    | Duy nhất trong feature này có ô tìm kiếm gọi lại API theo từ khóa (debounce 500ms) thay vì lọc cục bộ — tái dùng nguyên vẹn filter Code/Name generic đã có ở backend từ Update 4, **không sửa backend** |
| Nút Upload thật (Update 6) | N/A                                    | Duy nhất trong feature này có upload file thật lên SharePoint — **KHÔNG qua** controller/service `api/eutr-documents` mà qua endpoint mới `POST /api/sharepoint/eutr-upload-multi` (service `EutrUploadService` mới, tách biệt `ComplUploadService`); ghi `eutr_documents` trực tiếp qua `IRepository<,>` (bỏ qua `IEutrDocumentsService.AddAsync` vì DTO đó thiếu `FileId`); PO chỉ dùng để suy ra thư mục SharePoint, không lưu liên kết vào DB |
| Validate prefix + ghi `eutr_references` (Update 7) | N/A                                    | Duy nhất trong feature này ghi vào bảng `eutr_references` (entity mới, cột mới `StepId`) — mỗi file upload phải khớp `Prefix` trong `eutr_master_documents` (bảng của feature `002-eutr-masters`, chỉ đọc) mới được upload; khớp nhiều Step thì ghi nhiều dòng `eutr_references` cùng `DocumentId`, gộp chung 1 transaction với `eutr_documents` của file đó |
| Đọc `eutr_references` cho Step name/Type/File name (Update 8) | Masters: `GetPagedWithXAsync` JOIN 1 lần | Duy nhất trong feature này có **repository read-only mới** (`EutrReferencesRepository`) + **2 truy vấn JOIN riêng biệt** cho 2 màn hình khác nhau (danh sách: theo `DocumentId`; List PO: theo `RefType=0`/`RefValue`) — clone mẫu "query cha + query con WHERE IN + gộp bộ nhớ" của `ComplCountryGroupService` (chưa từng dùng ở 3 feature EUTR trước) thay vì JOIN 1 lần trong 1 câu SQL như `eutr-masters` |
| Delete xóa kèm `eutr_references` (Update 9) | Masters/Steps: `BaseService.DeleteAsync`/`DeleteMultiAsync` thuần, không override | Duy nhất trong feature này **override** Delete/DeleteMulti để dọn bảng con — `DeleteMultiAsync` override đổi hẳn ngữ nghĩa transaction so với `BaseService` (1 transaction/document thay vì 1 transaction chung cho cả batch) để đạt isolation per-item mà FR-040 yêu cầu |
| Icon View mở xem file thật + Delete từng file ở List PO (Update 10) | Masters/Templates: không có khái niệm "xem trước file" | Duy nhất trong feature này có endpoint đọc lại nội dung file qua SharePoint (`get-file-by-idref`, clone `ComplCompliancesController.GetFileByIds`) và popup xem trước (tái dùng `FilePreviewer.jsx` của `compliance-detail` qua 2 prop tùy chọn mới); Delete từng file trên List PO tái dùng nguyên vẹn API xóa đơn hiện có (`DELETE /{id}`) — không gọi API xóa file SharePoint, khác hẳn khái niệm "xóa" ở các feature khác (luôn xóa cả dữ liệu gắn kèm nếu có) |

## Complexity Tracking

> Không có vi phạm hiến pháp → bảng này để trống.
