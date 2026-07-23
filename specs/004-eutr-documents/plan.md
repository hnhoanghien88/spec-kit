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

**Cập nhật (spec Session Update 11 — Screen2 "Upload manual" trở thành upload file thật + popup
"Assign condition" gán Step/Conditions, FR-046 đến FR-054)**: Khu "Drag and drop files to upload" ở
Screen2 (trước đây silent no-op từ Update 3) trở thành khu **Upload File** thật (clone giao diện
Screen1/Update 7 nhưng luôn khả dụng, không cần chọn PO trước) — upload lên thư mục **cố định**
`{SharePointEutrPath}/UploadManual` (tự tạo nếu chưa có), qua endpoint mới
`POST /api/sharepoint/eutr-upload-manual-multi` (`SharePointController`, gọi thêm 1 method mới trên
`IEutrUploadService` đã có — KHÔNG validate prefix, KHÔNG ghi `eutr_references`, chỉ tạo
`eutr_documents`). Bảng danh sách file bên dưới đổi từ dữ liệu mẫu (`DEMO_FILE_LIST`) sang danh sách
"chưa gán" thật — mọi `eutr_documents` **chưa có** `eutr_references` nào — qua endpoint mới
`POST /api/eutr-documents/get-unassigned` (SQL `NOT EXISTS` tùy biến, vì repository generic không
hỗ trợ — xem research Quyết định 33); mỗi dòng có icon View/Delete thật, dùng lại nguyên vẹn cơ chế
đã có ở List PO (Update 10). Nút "Assign condition" (trước đây no-op) mở popup **mới**
`AssignConditionDialog.jsx`: dòng "Step" cố định (bắt buộc chọn) + các dòng "Conditions type" (PO/
Vendor, thêm qua "Add condition", loại trừ trùng lặp) với "Condition value" multi-select (tái dùng
component có sẵn `ReferenceObjectMultiAutocomplete.jsx`, `refType=15` cho PO/`14` cho Vendor). Save
gọi endpoint mới `POST /api/eutr-documents/assign-conditions` — ghi 1 dòng `eutr_references`
(`RefType=1`) + N dòng `eutr_reference_details` **cho mỗi** document đã chọn (bảng con **đã tồn tại
sẵn** trong `eutr_db.sql`, entity/repository mới ở backend, KHÔNG migration DB — research Quyết
định 29). Cột **Conditions** trên danh sách chính (trước đây luôn trống) nay hiển thị dữ liệu thật
cho document Type="Upload manual" (nhóm theo Conditions type, ví dụ "PO: PO1, PO2"). **Phát hiện kỹ
thuật quan trọng khi lập kế hoạch**: `DeleteByDocumentIdAsync` (Update 9) phải sửa để dọn kèm
`eutr_reference_details` trước khi xóa `eutr_references` (tránh vi phạm khóa ngoại — research Quyết
định 30).

**Cập nhật (spec Session Update 12 — Edit (User Story 3) rẽ nhánh theo Type, FR-055 đến FR-058)**:
Chức năng Edit trên danh sách chính không còn dùng 1 popup duy nhất cho mọi document — rẽ nhánh
theo `refType`: Type="PO" vẫn mở popup đơn giản hiện có nhưng **thêm trường Step** (single-select,
qua endpoint mới `PUT /api/eutr-documents/{id}/step` — thay thế toàn bộ tập `eutr_references` cũ
bằng 1 dòng mới); Type="Upload manual" mở lại **chính popup Assign condition** (Update 11) ở chế độ
sửa (2 endpoint mới `GET`/`PUT /api/eutr-documents/{id}/condition-assignment` — tải trước rồi
`UpdateAsync` `StepId` + replace toàn bộ `eutr_reference_details`); Type trống tiếp tục dùng popup
đơn giản không đổi. Backend: service Application mới `IEutrConditionAssignmentService` (tách khỏi
`EutrDocumentsService`/`EutrUploadService`, clone mẫu `ComplMasterConditionPersistenceService.
AddAsync`/`ReplaceAsync` đã có sẵn trong hệ thống cho compliance-master — research Quyết định 34)
gom toàn bộ 4 method của Update 11/12 (`AssignConditionsAsync`, `GetConditionAssignmentAsync`,
`UpdateConditionAssignmentAsync`, `UpdatePoStepAsync`).

**Cập nhật (spec Session Update 13 — `/speckit-clarify`, 2 câu hỏi resolved)**: (1) Khi document
Type="PO" liên kết nhiều Step, dropdown Step ở popup Edit hiển thị đúng Step ứng với bản ghi
`eutr_references` có `Id` nhỏ nhất (deterministic) — thêm field `StepId` vào
`EutrDocumentsResponseDto`, tính cùng lô với `StepNames`/`RefType` đã có (không round-trip mới). (2)
Popup Assign condition (cả 2 chế độ) KHÔNG cho phép 2 dòng cùng Conditions type — dropdown "Conditions
type" của dòng mới tự loại bỏ (disable) type đã dùng ở dòng khác (clone đúng kỹ thuật
`disabled={rows.some(...)}` đã có sẵn ở `ComplianceMasterForm.jsx`), kèm validator backend chặn
trùng lặp trong 1 request (FluentValidation `Distinct().Count()`, KHÔNG clone
`ComplMasterDuplicateConditionService`'s full-table scan — bài toán khác).

**Cập nhật (spec Session Update 14 — cột Type lấy dữ liệu thật từ `eutr_reference_types`, FR-034)**:
Cột **Type** trên danh sách EUTR documents chính (User Story 1) đổi nguồn nhãn hiển thị — từ hằng số
front-end `TAKE_FROM_OPTIONS` sang JOIN thật `RefType` với `eutr_reference_types.Id` (bảng mới, CRUD
bởi feature `006-eutr-reference-types`, đã có FK `eutr_references_reftype_foreign` trong
`docs/design/eutr/eutr_db.sql`). **Phát hiện khi lập kế hoạch**: `TAKE_FROM_OPTIONS` thực tế trong
codebase (`compliance-client/src/utils/helpers.js`) có `value` = `1..5` (dùng chung cho trường "Take
from" ở `eutr-templates` — PO/Vendor/Invoice/Delivery note/General agreement), KHÔNG có phần tử nào
mang `value = 0`; trong khi `RefType` ghi thật trên `eutr_references` là `0` (PO, Update 7) hoặc `1`
(Upload manual, Update 11) — nghĩa là *trước Update 14*, cột Type đã hiển thị sai/rỗng cho phần lớn
dữ liệu thật (`RefType=0` → nhãn rỗng; `RefType=1` → hiển thị nhầm "PO"). Đây chính là lỗi nền mà
Update 14 sửa (xem research Quyết định 41). Backend: mở rộng JOIN đã có sẵn ở
`EutrReferencesRepository.GetStepInfoByDocumentIdsAsync` (Update 8, Quyết định 20) — thêm
`LEFT JOIN eutr_reference_types` để lấy `Name`, đặt vào field mới `TypeName` trên
`EutrReferenceStepInfo`/`EutrDocumentsResponseDto`, gán trong `AttachStepAndConditionInfoAsync` đã
có (không đổi cấu trúc hàm). Frontend: `useEutrDocumentsColumns.jsx` đổi cột "Type" sang đọc trực
tiếp `row.typeName`, bỏ tra cứu `TAKE_FROM_OPTIONS` cho cột này. **1 migration DB mới** (seed 2 dòng
cố định `Id=0`→"PO"/`Id=1`→"Upload manual" khớp `RefType` đã ghi sẵn — xem Technical Context/Storage
và research Quyết định 41 cho chi tiết kỹ thuật `NO_AUTO_VALUE_ON_ZERO`). **Ngoài phạm vi**: dropdown
Type trên trang Add (FR-016, quyết định layout Screen1/Screen2 và giá trị `RefType` ghi xuống) và
logic rẽ nhánh Edit theo `refType` số (FR-055/FR-056) — cả hai giữ nguyên, không đổi.

**Cập nhật (spec Session Update 15/16 — popup Add hợp nhất Type/Step/Value/Upload thay cho trang Add
cũ, FR-059 đến FR-070)**: Nút **Add** trên toolbar (`index.jsx`) đổi từ
`navigate('/eutr/documents/add')` sang **mở một Dialog mới** `EutrDocumentsAddDialog.jsx` — route
`/eutr/documents/add` và `EutrDocumentsAdd.jsx` (Screen1/Screen2, toàn bộ Update 3-11) **giữ nguyên
trong codebase, không xóa**, chỉ không còn được liên kết từ toolbar Add (research Quyết định 45 —
Edit (User Story 3) không đổi, tiếp tục dùng `EutrDocumentsModal.jsx`/`AssignConditionDialog.jsx` độc
lập với trang này). Dialog mới gồm: **Type** (Autocomplete đơn, dữ liệu `GetEutrReferenceTypesUseCase`
— `GET /api/eutr-reference-types`, đã có sẵn từ feature `006-eutr-reference-types`, KHÔNG cần backend
mới); **Step** (Autocomplete đơn, `GetEutrStepsUseCase` đã có sẵn — `GET /api/eutr-steps`); **Value**
(component mới `EutrAddValueAutocomplete.jsx`, xem dưới); vùng chip; nút **Upload**. Value: nếu
`Type.Name` (so khớp không phân biệt hoa/thường) là "PO"/"Invoice"/"Delivery note" → tải gợi ý qua
`useReferenceObjects` với `referenceType=15`; nếu "Vendor" → `referenceType=14`; Type khác → ô nhập
tự do (freeSolo thuần, không gọi API). Dán nhiều giá trị (tách theo `/[\n,]+/`) — với Type có nguồn
gợi ý, mỗi token được xác thực bằng cách gọi lại `fetchReferenceObjects(refType, token)` và giữ token
khớp chính xác (so theo `code`, không phân biệt hoa/thường, xem research Quyết định 46); Type = "PO"/
"Vendor" giới hạn đúng 1 chip (chặn thêm khi đã có 1 — research Quyết định 48); đổi Type reset toàn
bộ chip. Nút Upload chỉ khả dụng khi đủ Type + Step + ≥1 chip, mở `<input type="file" multiple
hidden>`, validate định dạng/kích thước client-side (copy logic đã có ở `EutrDocumentsAdd.jsx`, không
refactor dùng chung để tránh hồi quy Screen1/Screen2 vẫn đang chạy — Quyết định 45). Backend: method
**mới** `UploadMultipleForReferenceTypeAsync` trên `IEutrUploadService`/`EutrUploadService` — tổng
quát hóa `ResolveOrCreatePoFolderAsync` đã có (không đổi hàm, chỉ truyền `folderName` khác) theo tên
thư mục suy từ `TypeName` (case-insensitive: "PO"/"Vendor" → `RefValues[0]`; "Invoice"→"Invoice";
"Delivery note"→"DeliveryNote"; "General agreement"→"GeneralAgreement"; Type khác → tên Type đã loại
khoảng trắng — FR-067), ghi 1 `eutr_documents` + N `eutr_references` (N = số `RefValues`, mỗi dòng
`RefType=(byte)TypeId`, `StepId=request.StepId`) mỗi file trong 1 transaction — clone cấu trúc
transaction per-file đã có ở `UploadMultipleToSharePointAndSaveDataAsync` (Update 6/7), **KHÔNG**
validate prefix `eutr_master_documents` (khác luồng PO Screen1 — Type không còn giới hạn "PO", FR-068).
Endpoint **mới** `[HttpPost("eutr-upload-multi-by-type")]` trong `SharePointController` hiện có, DTO
**mới** `EutrTypeMultiUploadFileRequest` (`{ List<IFormFile> Files, long TypeId, string TypeName,
long StepId, List<string> RefValues }`). **Không migration DB mới** (`RefType` đã là cột `TINYINT`
linh hoạt + FK `eutr_references_reftype_foreign` từ Update 14; `StepId` đã có từ Update 7). Popup
**tự đóng** ngay sau khi Upload hoàn tất (FR-070) — gọi `onClose()` sau khi hiển thị snackbar kết quả,
không có luồng "upload nhiều lượt trong 1 lần mở".

**Cập nhật (spec Session Update 17 — ô Value tự xóa trống sau khi thêm chip; Type = "PO" trong popup
Add bỏ chọn Step thủ công, xác định tự động theo prefix file, FR-071 đến FR-075)**: Hai tinh chỉnh
trên popup Add (Update 15/16), **KHÔNG cần sửa backend nào**. (1) `EutrAddValueAutocomplete.jsx`
(Update 15) reset input về rỗng ngay sau mỗi lần thêm chip thành công (mọi đường: gợi ý/gõ tay/dán) —
làm rõ tường minh hành vi đã ngụ ý từ Update 15 (research Quyết định 50). (2) Khi `Type.Name` = "PO"
(không phân biệt hoa/thường), `EutrDocumentsAddDialog.jsx` **ẩn hẳn** control Step (không gọi
`GetEutrStepsUseCase`) và nút Upload chỉ yêu cầu Type + ≥1 chip; khi nhấn Upload, dialog gọi lại
**nguyên vẹn** use case đã có từ Update 6 `UploadToSharePointUseCase.executeEutrMulti(files, poCode)`
(→ `POST /api/sharepoint/eutr-upload-multi`, `EutrUploadService.
UploadMultipleToSharePointAndSaveDataAsync` — đã tự validate prefix `eutr_master_documents` và ghi N
`eutr_references`/`StepId` khớp Prefix từ Update 7) **thay vì** `executeEutrMultiByType` (Update
15/16) — vì endpoint PO gốc đã làm đúng toàn bộ những gì Update 17 yêu cầu (research Quyết định 51).
Với mọi Type khác "PO" (Vendor/Invoice/Delivery note/General agreement/Type mới), hành vi Step bắt
buộc + gọi `executeEutrMultiByType` giữ nguyên như Update 15/16, không đổi.

**Cập nhật (spec Session Update 18 — popup Add gửi kèm `TypeId` khi Type = "PO", ghi đúng `RefType`
vào `eutr_references` thay cho hằng số cố định, FR-076/FR-077)**: Sửa lỗi/khoảng trống giữa ý định đã
nêu ở FR-075 (Update 17: `RefType` phải là `Id` thật của bản ghi `eutr_reference_types` có `Name` =
"PO") và luồng ghi thực tế của Type = "PO" — hiện đang ghi cứng một giá trị hằng số
(`EutrUploadService.PoRefType = 0`), không phụ thuộc `Id` thật đang được chọn ở dropdown Type. Thêm 1
field mới nullable `TypeId` vào `EutrMultiUploadFileRequest` (DTO của endpoint `eutr-upload-multi`,
Update 6); `EutrDocumentsAddDialog.jsx` (nhánh `isPoType`, Update 17) MUST truyền thêm `type.id` khi
gọi `executeEutrMulti`; `EutrUploadService.UploadMultipleToSharePointAndSaveDataAsync` MUST dùng
`TypeId` nhận được (nếu có) làm `RefType` cho mọi bản ghi `eutr_references` ghi ở luồng này, thay cho
hằng số cũ. `TypeId` để **nullable** (không bắt buộc) nhằm không phá vỡ trang Add cũ độc lập
`EutrDocumentsAdd.jsx` (Update 6, vẫn còn route `/eutr/documents/add` dù không còn mở từ nút Add trên
toolbar kể từ Update 15) — trang này không có control Type nên không gửi field mới này, hành vi ghi
`RefType` của nó giữ nguyên như cũ (hằng số `PoRefType`), không thuộc phạm vi Update 18. Không
migration DB mới (`RefType` đã là `TINYINT NULL` linh hoạt từ Update 7/14); không endpoint/route mới.

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
repository mới `EutrReferencesRepository`. **Update 11**: bảng `eutr_reference_details` **đã tồn
tại sẵn** trong `eutr_db.sql` (Id, RefId → `eutr_references.Id`, ConditionType, ConditionValue) —
KHÔNG migration DB mới, chỉ tạo entity/repository backend mới (`EutrReferenceDetails`,
`IEutrReferenceDetailsRepository`). Cần sửa SQL nội bộ của `EutrReferencesRepository.
DeleteByDocumentIdAsync` (dọn `eutr_reference_details` trước, tránh vi phạm FK — research Quyết
định 30). **Update 14**: bảng `eutr_reference_types` **đã tồn tại** trong
`docs/design/eutr/eutr_db.sql` (feature `006-eutr-reference-types`, FK
`eutr_references_reftype_foreign` từ `eutr_references.RefType`) nhưng KHÔNG có trong DDL build
(`ComplianceSys.Infrastructure/Sqls/Tables/eutr_db.sql`) hay bất kỳ migration nào — **1 migration DB
mới** (`14_seed_eutr_reference_types.sql`) tự phòng vệ bằng `CREATE TABLE IF NOT EXISTS` rồi seed 2
dòng cố định `Id=0`→"PO"/`Id=1`→"Upload manual" (khớp `RefType` đã ghi sẵn từ Update 7/11); cần bật
tạm `NO_AUTO_VALUE_ON_ZERO` trong `sql_mode` phiên hiện tại để `INSERT` giữ đúng `Id=0` (mặc định
MySQL coi `0` trên cột `AUTO_INCREMENT` như `NULL`) — xem research Quyết định 41. Không tự thêm FK
(giả định đã có từ rollout feature `006`, tránh trùng lặp/xung đột phạm vi). **Update 15/16**: KHÔNG
migration DB mới — `eutr_references.RefType` (`TINYINT NULL`) đã đủ linh hoạt để lưu bất kỳ `Id`
nào của `eutr_reference_types` (không chỉ `0`/`1`), FK `eutr_references_reftype_foreign` đã tồn tại
từ Update 14; `StepId` đã có từ Update 7. Lưu ý kỹ thuật: `eutr_reference_types.Id` là `long` ở tầng
C# (dù cột DB `TINYINT UNSIGNED`) nhưng `eutr_references.RefType` là `byte?` — ghi giá trị MUST cast
tường minh `(byte)typeId` (an toàn vì cột DB giới hạn 0-255, khớp phạm vi `TINYINT UNSIGNED`).
**Update 17**: KHÔNG migration DB mới, KHÔNG thay đổi schema/entity/repository backend nào — Type =
"PO" trong popup Add tái sử dụng nguyên vẹn hạ tầng dữ liệu đã có từ Update 6/7 (endpoint
`eutr-upload-multi`, entity `EutrReferences`, cột `StepId`, method `GetMatchingPrefixesAsync`);
Type khác "PO" tiếp tục dùng hạ tầng Update 15/16 không đổi (research Quyết định 51).
**Update 18**: KHÔNG migration DB mới — `eutr_references.RefType` đã đủ linh hoạt từ Update 15/16
(Quyết định 41) để lưu đúng `Id` thật nhận từ `TypeId`; chỉ thêm 1 field nullable `TypeId` (`long?`)
vào DTO `EutrMultiUploadFileRequest` đã có (Update 6) và sửa 1 dòng gán giá trị trong
`EutrUploadService.UploadMultipleToSharePointAndSaveDataAsync` (research Quyết định 52) — không đổi
entity/repository/FK nào.

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
migration DB mới (chỉ thêm `FileId` vào 1 SQL JOIN đã có). **Update 11**: khu Upload File Screen2
MUST luôn khả dụng, KHÔNG validate prefix (FR-046); upload vào thư mục cố định `UploadManual`,
KHÔNG ghi `eutr_references` ở bước upload (FR-047); danh sách "chưa gán" MUST lọc bằng `NOT EXISTS`
(FR-048); popup Assign condition MUST chặn Save khi thiếu Step HOẶC thiếu ≥1 Conditions type/value
hợp lệ (FR-052, sửa lại ở Update 13); mỗi file được chọn tạo 1 bản ghi `eutr_references` riêng +
N bản ghi `eutr_reference_details` (FR-052); cột Conditions MUST hiển thị dữ liệu thật cho Type=
"Upload manual" (FR-054). **Update 12**: Edit MUST rẽ nhánh theo `refType` — Type="PO" thêm trường
Step single-select, thay thế toàn bộ tập `eutr_references` cũ (FR-055); Type="Upload manual" mở
popup Assign condition ở chế độ sửa, cập nhật `StepId` trực tiếp + replace toàn bộ
`eutr_reference_details` (FR-057/FR-058); Type trống không đổi. **Update 13**: dropdown Step ở Edit
MUST hiển thị Step ứng với `eutr_references.Id` nhỏ nhất khi có nhiều Step (FR-055); popup Assign
condition MUST chặn 2 dòng cùng Conditions type trong cùng lượt (FR-051). **Update 14**: cột Type
(danh sách) MUST nạp nhãn qua JOIN `eutr_references.RefType` với `eutr_reference_types.Id`, trả
`Name` (FR-034) — thay hoàn toàn cho nhãn hằng số `TAKE_FROM_OPTIONS` dùng trước đó; dropdown Type ở
trang Add (FR-016) và rẽ nhánh Edit theo `refType` (FR-055/FR-056) KHÔNG đổi. **Update 15/16**: nút
Add MUST mở popup, KHÔNG điều hướng trang (FR-059); Type dropdown trong popup này lấy TOÀN BỘ bản ghi
`eutr_reference_types` (khác FR-016, 2 lựa chọn hard-coded — KHÔNG đổi bởi Update 15), rẽ nhánh theo
`Name` không theo `Id` (FR-060); Step bắt buộc (FR-061); Value chỉ hiển thị gợi ý cho Type khớp "PO"/
"Invoice"/"Delivery note" (`refType=15`) hoặc "Vendor" (`refType=14`), Type khác là nhập tự do
(FR-062); chip hợp lệ khi khớp chính xác dữ liệu tham chiếu, kể cả qua dán nhiều giá trị tách bằng
dấu phẩy/xuống dòng (FR-063/FR-065); Type="PO"/"Vendor" giới hạn đúng 1 chip (FR-064); Upload chỉ
khả dụng khi đủ Type+Step+≥1 chip (FR-066); thư mục SharePoint suy theo `Name` của Type (FR-067);
mỗi file thành công ghi 1 `eutr_documents` + N `eutr_references` (N=số chip, FR-068); MẤT khả năng tạo
document chỉ bằng nhập tay không upload (FR-069, xác nhận có chủ đích ở Update 16); popup MUST tự
đóng sau mỗi lượt Upload (FR-070, Update 16). **Update 17**: ô Value MUST tự xóa trống ngay sau khi
thêm 1 chip (FR-071); khi Type = "PO", combobox Step KHÔNG hiển thị và KHÔNG bắt buộc (FR-072), file
MUST validate prefix `eutr_master_documents` (FR-073, tái dùng Update 7), Upload chỉ cần Type+≥1 chip
(FR-074), và mỗi file ghi `eutr_references` theo từng `StepId` khớp Prefix — KHÔNG dùng 1 Step chọn
thủ công (FR-075); với Type khác "PO", toàn bộ hành vi Update 15/16 giữ nguyên không đổi.

**Testing bổ sung (Update 10)**: kiểm thử thủ công theo `quickstart.md` kịch bản 6/6a/9r/9s — bao
gồm xác nhận popup xem trước hiển thị đúng nội dung và xác nhận file KHÔNG bị xóa khỏi SharePoint
sau khi Delete (kiểm tra qua log backend/Graph Explorer nếu có quyền truy cập).

**Testing bổ sung (Update 11/12/13)**: kiểm thử thủ công theo `quickstart.md` kịch bản 10 đến 13
(bao gồm 10a, 11a, 11b) — upload thật ở Screen2, danh sách "chưa gán", popup Assign condition (tạo
mới + sửa) với validate 2 điều kiện bắt buộc và chặn trùng Conditions type, Edit rẽ nhánh theo
Type, kiểm tra trực tiếp DB cho `eutr_references`/`eutr_reference_details` sau mỗi lượt Save.

**Testing bổ sung (Update 14)**: kiểm thử thủ công theo `quickstart.md` kịch bản 14 — chạy migration
seed, xác nhận response `get-all` có `typeName`, cột Type trên grid hiển thị đúng "PO"/"Upload
manual"/trống theo đúng dữ liệu thật (không còn map qua `TAKE_FROM_OPTIONS` ở client), và dropdown
Type ở trang Add không đổi hành vi.

**Testing bổ sung (Update 15/16)**: kiểm thử thủ công theo `quickstart.md` kịch bản 15 — nhấn Add mở
popup (không điều hướng trang); chọn Type="PO"/"Invoice"/"Delivery note" xác nhận gợi ý gọi
`refType=15`, Type="Vendor" xác nhận gọi `refType=14`, Type khác (vd. "General agreement") xác nhận ô
Value không gọi API nào; dán chuỗi nhiều giá trị (phẩy và xuống dòng) xác nhận đúng số chip hợp lệ
được thêm, giá trị không khớp bị bỏ kèm cảnh báo; xác nhận Type="PO"/"Vendor" chặn thêm chip thứ 2;
Upload với nhiều file, kiểm tra trực tiếp DB: đúng N `eutr_references` (N=số chip) cho mỗi document,
`RefType` = đúng `Id` của Type đã chọn (không phải 0/1 cứng), thư mục SharePoint đúng theo quy tắc
per-Type; xác nhận popup tự đóng ngay sau khi Upload xong; xác nhận Edit trên danh sách chính không
đổi hành vi so với Update 12/13.

**Testing bổ sung (Update 17)**: kiểm thử thủ công theo `quickstart.md` kịch bản 16 — xác nhận mỗi
lần thêm chip (chọn gợi ý/gõ tay/dán) ô Value trở về trống ngay lập tức; chọn Type = "PO" xác nhận
combobox Step không hiển thị và nút Upload khả dụng chỉ với 1 chip PO; upload 2 file có tên khớp
prefix của 2 `StepId` khác nhau trong `eutr_master_documents`, kiểm tra trực tiếp DB xác nhận mỗi
document có đúng bản ghi `eutr_references` theo `StepId` khớp Prefix (không phải Step chọn thủ công)
và kiểm tra Network xác nhận request gọi `POST /api/sharepoint/eutr-upload-multi` (không phải
`eutr-upload-multi-by-type`); upload 1 file không khớp prefix nào, xác nhận bị loại kèm cảnh báo,
không tạo document; lặp lại với Type = "Vendor" hoặc "Invoice", xác nhận combobox Step vẫn hiển thị/
bắt buộc và request gọi đúng `eutr-upload-multi-by-type` như Update 15/16 (không đổi).

**Testing bổ sung (Update 18)**: kiểm thử thủ công theo `quickstart.md` kịch bản 17 — chọn Type =
"PO" trong popup Add, upload 1 file hợp lệ, kiểm tra tab Network xác nhận request
`POST /api/sharepoint/eutr-upload-multi` có field `typeId` = đúng `Id` của Type "PO" đang chọn (lấy
từ dropdown Type, không phải suy diễn); kiểm tra trực tiếp DB xác nhận bản ghi `eutr_references` mới
có `RefType` = đúng giá trị `typeId` đó; quay lại danh sách chính xác nhận document hiển thị đúng
nhãn Type "PO". Không có hồi quy ở Type khác "PO" (vẫn gọi `eutr-upload-multi-by-type` như Update
15/16/17, không đổi).

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
**Update 11**: Backend — 8 file mới (`EutrReferenceDetails.cs`, `IEutrReferenceDetailsRepository.cs`,
`EutrReferenceDetailsRepository.cs`, `EutrManualMultiUploadFileRequest.cs`,
`EutrAssignConditionsRequestDto.cs`, `EutrConditionRowDto.cs`, `IEutrConditionAssignmentService.cs`,
`EutrConditionAssignmentService.cs`) + sửa 6 file hiện có (`IEutrUploadService.cs`/
`EutrUploadService.cs` thêm method; `SharepointController.cs` thêm action;
`EutrReferencesRepository.cs` thêm method `GetUnassignedDocumentsPagedAsync` + sửa SQL
`DeleteByDocumentIdAsync`; `EutrDocumentsController.cs` thêm 2 action + constructor param;
`EutrDocumentsService.cs` thêm method `GetUnassignedPagedAsync` + mở rộng `AttachStepInfoAsync`;
`EutrDocumentsResponseDto.cs` thêm field `Conditions`) — **không migration DB mới** (bảng
`eutr_reference_details` đã tồn tại sẵn). Frontend — 1 file mới (`AssignConditionDialog.jsx`) + sửa
7 file hiện có (`helpers.js` thêm `CONDITION_TYPE_OPTIONS`; `ISharePointRepository.js`/
`RestSharePointRepository.js`/`UploadToSharePointUseCase.js` thêm method manual-multi;
`IEutrDocumentsRepository.js`/`eutrDocumentsApi.js`/`RestEutrDocumentsRepository.js` thêm 2 method
(`getUnassigned`, `assignConditions`); `EutrDocumentsAdd.jsx` Screen2 đổi từ demo sang thật;
`useEutrDocumentsColumns.jsx` cột Conditions đổi renderCell) + 2 use case mới
(`GetEutrDocumentsUnassignedUseCase.js`, `AssignEutrConditionsUseCase.js`); tái dùng nguyên vẹn
`ReferenceObjectMultiAutocomplete.jsx`/`GetEutrStepsUseCase.js` đã có sẵn — không thêm dependency
mới.
**Update 12**: Backend — sửa 2 file hiện có (`IEutrConditionAssignmentService.cs`/
`EutrConditionAssignmentService.cs` thêm 3 method `GetConditionAssignmentAsync`/
`UpdateConditionAssignmentAsync`/`UpdatePoStepAsync`; `EutrDocumentsController.cs` thêm 3 action) +
2 DTO mới (`EutrUpdateConditionAssignmentRequestDto.cs`, `EutrUpdatePoStepRequestDto.cs`,
`EutrDocumentConditionAssignmentDto.cs`) — không migration DB mới. Frontend — 3 use case mới
(`GetEutrDocumentConditionAssignmentUseCase.js`, `UpdateEutrConditionAssignmentUseCase.js`,
`UpdateEutrDocumentPoStepUseCase.js`) + sửa 3 file hiện có (`EutrDocumentsModal.jsx` thêm trường
Step có điều kiện; `index.jsx` `onEdit` rẽ nhánh theo `refType`; `IEutrDocumentsRepository.js`/
`eutrDocumentsApi.js`/`RestEutrDocumentsRepository.js` thêm 3 method) — tái dùng
`AssignConditionDialog.jsx` (Update 11) ở `mode="edit"`, không component mới.
**Update 13**: Backend — sửa 3 file hiện có (`EutrReferenceStepInfo.cs` thêm field `ReferenceId`;
`EutrDocumentsService.cs` đổi cách tính `StepId` theo `Id` nhỏ nhất; `EutrAssignConditionsRequestDto
Validator.cs`/`EutrUpdateConditionAssignmentRequestDtoValidator.cs` thêm rule chặn trùng
`ConditionType`) — không file mới, không migration DB mới. Frontend — sửa 1 file
(`AssignConditionDialog.jsx` — dropdown Conditions type disable option đã dùng ở dòng khác).
**Update 14**: Backend — sửa 3 file hiện có (`EutrReferenceStepInfo.cs`/`EutrDocumentsResponseDto.cs`
thêm field `TypeName`; `EutrReferencesRepository.cs` thêm JOIN vào SQL đã có) + **1 migration mới**
(`14_seed_eutr_reference_types.sql`) — không entity/repository/endpoint mới. Frontend — sửa 1 file
(`useEutrDocumentsColumns.jsx` — cột Type đọc `row.typeName` thay vì tra `TAKE_FROM_OPTIONS`).
**Update 15/16**: Backend — 1 DTO mới (`EutrTypeMultiUploadFileRequest.cs`) + sửa 2 file hiện có
(`IEutrUploadService.cs`/`EutrUploadService.cs` thêm method `UploadMultipleForReferenceTypeAsync`;
`SharePointController.cs` thêm 1 action `eutr-upload-multi-by-type`) — không migration DB mới, không
entity/repository mới (tái dùng `EutrReferences`/`IRepository<EutrReferences,long>` đã có). Frontend
— 2 file mới (`EutrDocumentsAddDialog.jsx`, `EutrAddValueAutocomplete.jsx`) + sửa 4 file hiện có
(`index.jsx` đổi Add sang mở dialog; `ISharePointRepository.js`/`RestSharePointRepository.js`/
`UploadToSharePointUseCase.js` thêm method `uploadEutrFilesMultiByType`) — tái dùng nguyên vẹn
`GetEutrReferenceTypesUseCase.js`/`GetEutrStepsUseCase.js`/`useReferenceObjects` đã có sẵn, KHÔNG sửa
`ReferenceObjectMultiAutocomplete.jsx` dùng chung (tránh hồi quy `AssignConditionDialog.jsx`); route
`/eutr/documents/add` và `EutrDocumentsAdd.jsx` giữ nguyên, không xóa, không sửa.
**Update 17**: **KHÔNG file backend nào thay đổi** (research Quyết định 51). Frontend — sửa 2 file
hiện có: `EutrAddValueAutocomplete.jsx` (Update 15 — thêm reset input text về rỗng ngay sau mỗi lần
thêm chip thành công, FR-071) và `EutrDocumentsAddDialog.jsx` (Update 15 — rẽ nhánh theo `Type.Name`:
ẩn control Step + đổi điều kiện enable Upload + gọi `executeEutrMulti` thay vì
`executeEutrMultiByType` khi Type = "PO"; giữ nguyên hành vi cho Type khác).

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

**Re-check sau Update 11** (Screen2 upload thật + Assign condition tạo mới): vẫn PASS cả 5 nguyên
tắc — entity mới `EutrReferenceDetails.cs` nằm đúng `Domain/Entities`, repository tùy biến mới
`EutrReferenceDetailsRepository` chỉ được gọi qua interface từ service Application (Nguyên tắc I,
không SQL nào lọt lên Controller); bảng `eutr_reference_details` **đã tồn tại sẵn** trong DDL —
không migration mới, giảm rủi ro triển khai (Nguyên tắc III, không tạo lại hạ tầng DB đã chuẩn bị
sẵn); service mới `IEutrConditionAssignmentService` **clone trực tiếp** mẫu
`ComplMasterConditionPersistenceService.AddAsync`/`ReplaceAsync` đã có sẵn trong hệ thống cho
compliance-master — đúng tinh thần Nguyên tắc II (mô hình theo tính năng tương tự đã hoạt động,
không phát minh cách mới), bỏ đúng phần baggage domain-specific (AND/OR block, versioning) không
cần cho tính năng này; action mới `eutr-upload-manual-multi` đặt trong `SharePointController` hiện
có (đúng ranh giới route theo hành động đã chốt từ Update 6, Nguyên tắc II); frontend tái dùng
nguyên vẹn `ReferenceObjectMultiAutocomplete.jsx`/`GetEutrStepsUseCase.js` đã có sẵn, không viết lại
logic multi-select/tải Step (Nguyên tắc II + III); không có UI label tiếng Việt phát sinh (Nguyên
tắc IV không đổi); không route/menu/policy mới — 5 action mới dùng chung 3 policy
`ReadAll`/`ReadOne`/`Update` đã có (Nguyên tắc V không đổi).

**Re-check sau Update 12** (Edit rẽ nhánh theo Type): vẫn PASS cả 5 nguyên tắc — 3 action mới nằm
trong `EutrDocumentsController` hiện có, logic nghiệp vụ nằm trong `IEutrConditionAssignmentService`
(Application), không có SQL nào lọt lên Controller (Nguyên tắc I); tái dùng nguyên vẹn popup
`AssignConditionDialog.jsx` (Update 11) cho cả 2 chế độ tạo mới/sửa qua 1 prop `mode`, không nhân
bản Dialog (Nguyên tắc II); `EutrDocumentsModal.jsx` chỉ thêm 1 trường có điều kiện, không viết lại
popup Edit đơn giản đã hoạt động ổn định (Nguyên tắc II); dùng chung policy `EutrDocuments.Update`
đã có cho cả 3 action mới, không policy riêng (Nguyên tắc V không đổi); không có UI label tiếng
Việt phát sinh (Nguyên tắc IV không đổi).

**Re-check sau Update 13** (`/speckit-clarify`): vẫn PASS cả 5 nguyên tắc — cả 2 thay đổi (quy tắc
xác định Step hiện tại; chặn trùng Conditions type) đều là logic nội bộ trong service/validator đã
có (Application), không ảnh hưởng layer boundary (Nguyên tắc I); validate chặn trùng dùng
`Distinct().Count()` đơn giản, **không** clone `ComplMasterDuplicateConditionService`'s full-table
scan (bài toán khác — tránh over-engineering, đúng tinh thần "chọn mẫu tham chiếu đúng phạm vi",
Nguyên tắc II); dropdown disable-trùng ở frontend clone đúng 1 dòng logic đã có sẵn ở
`ComplianceMasterForm.jsx` (Nguyên tắc II); không route/DTO/policy/menu mới (Nguyên tắc III/V
không đổi); không có UI label tiếng Việt phát sinh (Nguyên tắc IV không đổi).

**Re-check sau Update 14** (cột Type lấy nhãn thật từ `eutr_reference_types`): vẫn PASS cả 5 nguyên
tắc — mở rộng JOIN nằm đúng trong `EutrReferencesRepository` (Infrastructure), chỉ gọi qua interface
`IEutrReferencesRepository` từ `Application/Services/EutrDocumentsService.cs`, không có SQL nào lọt
lên Controller (Nguyên tắc I); JOIN thêm `eutr_reference_types` mở rộng đúng câu SQL đã có sẵn từ
Update 8 (`GetStepInfoByDocumentIdsAsync`) thay vì viết truy vấn mới hay tạo repository riêng
(Nguyên tắc II); tái dùng nguyên vẹn bảng `eutr_reference_types` + FK đã được feature
`006-eutr-reference-types` chuẩn bị sẵn (Nguyên tắc III — không tạo lại hạ tầng CRUD reference type,
migration của feature này chỉ seed dữ liệu, không tạo entity/repository/service mới cho bảng đó);
không có UI label tiếng Việt phát sinh, nhãn Type hiển thị nguyên văn `Name` đã lưu trong
`eutr_reference_types` (Nguyên tắc IV không đổi); không route/DTO/policy/menu mới — endpoint
`get-all`/`get-by-id` giữ nguyên path/policy, chỉ thêm field response (Nguyên tắc V không đổi).

**Re-check sau Update 15/16** (popup Add hợp nhất Type/Step/Value/Upload): vẫn PASS cả 5 nguyên tắc —
method mới `UploadMultipleForReferenceTypeAsync` nằm đúng `Application/Services/EutrUploadService.cs`,
action mới chỉ ủy quyền cho service qua interface, không có business logic nào lọt lên
`SharePointController` (Nguyên tắc I); method mới **clone cấu trúc transaction per-file** đã có ở
`UploadMultipleToSharePointAndSaveDataAsync` (Update 6/7) và **tái dùng nguyên vẹn**
`ResolveOrCreatePoFolderAsync` đã có (chỉ khác `folderName` truyền vào) thay vì viết lại logic
tìm/tạo thư mục (Nguyên tắc II); Type/Step lấy dữ liệu qua 2 endpoint **đã tồn tại sẵn**
(`GET /api/eutr-reference-types` của feature `006`, `GET /api/eutr-steps`) và Value tái dùng nguyên
vẹn `useReferenceObjects`/`GetReferenceDataUseCase` (refType 15/14 đã đăng ký từ Update 4/11) — không
tạo endpoint/hook trùng lặp (Nguyên tắc III, đúng tinh thần "Reuse Existing Backend"); không có UI
label tiếng Việt phát sinh (Nguyên tắc IV không đổi); không route/DTO/policy/menu mới ở
`EutrDocumentsController` — action mới trong `SharePointController` dùng chung `[Authorize]` đã có,
đúng ranh giới route-theo-hành-động đã chốt từ Update 6 (Nguyên tắc V không đổi). Quyết định giữ
nguyên `EutrDocumentsAdd.jsx`/route `/eutr/documents/add` thay vì xóa (`EutrDocumentsModal.jsx`/
`AssignConditionDialog.jsx` dùng bởi Edit là các component độc lập, không nằm trong/phụ thuộc vào
trang này — nên việc giữ lại chỉ đơn thuần là dead code có chủ đích, giảm rủi ro thao tác xóa nhầm)
được ghi nhận nhưng không vi phạm nguyên tắc nào — không có yêu cầu "không được có code không dùng"
trong constitution.

**Re-check sau Update 17** (ô Value tự xóa sau khi thêm chip; Type = "PO" bỏ chọn Step thủ công): vẫn
PASS cả 5 nguyên tắc — cả hai thay đổi chỉ nằm trong `presentation/` (2 component frontend hiện có
của Update 15, không đụng domain/infrastructure/application nào — Nguyên tắc I); thay vì mở rộng
`UploadMultipleForReferenceTypeAsync` (Update 15) để tự viết lại logic prefix-match/multi-StepId cho
riêng Type="PO", quyết định tái sử dụng **nguyên vẹn** endpoint/service `eutr-upload-multi` đã có từ
Update 6/7 — đây là mức độ áp dụng cao nhất của Nguyên tắc II (Reference-Pattern Reuse) và Nguyên tắc
III (Reuse Existing Backend) trong toàn bộ lịch sử feature này: **0 dòng backend mới**, không entity/
repository/migration/endpoint nào phát sinh; không có UI label tiếng Việt phát sinh (Nguyên tắc IV
không đổi); không route/DTO/policy/menu mới — endpoint được gọi lại (`eutr-upload-multi`) đã dùng
chung `[Authorize]` có sẵn từ Update 6 (Nguyên tắc V không đổi).

**Re-check sau Update 18** (popup Add gửi kèm `TypeId` khi Type = "PO"; `EutrUploadService` ghi
`RefType` từ giá trị nhận được thay vì hằng số cố định): vẫn PASS cả 5 nguyên tắc — thay đổi backend
chỉ là 1 field nullable mới trên DTO đã có (`EutrMultiUploadFileRequest`, Update 6) và 1 dòng điều
kiện (ternary) tại đúng nơi đang gán cứng `RefType` trong `EutrUploadService.
UploadMultipleToSharePointAndSaveDataAsync` — không thêm entity/repository/endpoint/migration nào
(Nguyên tắc I không đổi); thay đổi tái sử dụng đúng field đã tồn tại từ Update 15
(`type.id`/`typeId`) mà nhánh Type khác đã gửi thành công qua `executeEutrMultiByType`, chỉ mang giá
trị đó sang nhánh PO thay vì phát minh cơ chế truyền dữ liệu mới (Nguyên tắc II); không tạo tích hợp
SharePoint/DB mới nào — vẫn dùng chung entity `EutrReferences`, cột `RefType` (`TINYINT NULL`) đã có
từ Update 7/14 (Nguyên tắc III); không có UI label tiếng Việt phát sinh (Nguyên tắc IV không đổi);
không route/DTO mới (chỉ thêm field), không đổi policy/menu — endpoint `eutr-upload-multi` giữ
nguyên path/`[Authorize]` (Nguyên tắc V không đổi). Quyết định giữ `TypeId` là **nullable** (không
`[Required]`) để không phá vỡ trang Add cũ `EutrDocumentsAdd.jsx`/route `/eutr/documents/add` (Update
6, vẫn tồn tại như dead-code-có-chủ-đích từ Update 15) không được coi là vi phạm nguyên tắc nào —
cùng quyết định giữ nguyên trang cũ đã ghi nhận ở Update 15 phía trên.

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

Backend — **Update 11** (Screen2 upload thật + bảng "chưa gán" + Assign condition tạo mới; entity/
repository mới cho `eutr_reference_details` đã tồn tại sẵn trong DDL — KHÔNG migration DB mới):

```text
compliance-sys-api/src/
├── ComplianceSys.Domain/Entities/
│   └── EutrReferenceDetails.cs                          # MỚI: Table("eutr_reference_details"): Id, RefId (long?, FK → eutr_references.Id), ConditionType (byte?), ConditionValue (string?) + BaseEntity audit — clone hình dạng EutrReferences.cs (research Quyết định 29)
├── ComplianceSys.Application/
│   ├── Interfaces/Repositories/IEutrReferenceDetailsRepository.cs   # MỚI: GetGroupedConditionsByDocumentIdsAsync(IEnumerable<long>), DeleteByRefIdAsync(long)
│   ├── Dtos/Response/EutrConditionGroupRow.cs           # MỚI: projection { DocumentId, ConditionType, ConditionValue } — kết quả thô của GetGroupedConditionsByDocumentIdsAsync
│   ├── Dtos/Response/ConditionGroupDto.cs               # MỚI: { byte ConditionType, List<string> Values } — dùng trong EutrDocumentsResponseDto.Conditions
│   ├── Dtos/Request/EutrManualMultiUploadFileRequest.cs # MỚI: { List<IFormFile> Files } — KHÔNG có PoCode (khác EutrMultiUploadFileRequest)
│   ├── Dtos/Request/EutrAssignConditionsRequestDto.cs   # MỚI: { List<long> DocumentIds, long StepId, List<EutrConditionRowDto> Conditions }
│   ├── Dtos/Request/EutrConditionRowDto.cs              # MỚI: { byte ConditionType, List<string> Values }
│   ├── Validators/EutrAssignConditionsRequestDtoValidator.cs  # MỚI: DocumentIds NotEmpty, StepId>0, Conditions NotEmpty + mỗi dòng Values NotEmpty (FR-052) + (Update 13) không trùng ConditionType
│   ├── Interfaces/Services/IEutrConditionAssignmentService.cs # MỚI: AssignConditionsAsync(EutrAssignConditionsRequestDto, string email, ct)
│   ├── Services/EutrConditionAssignmentService.cs       # MỚI: AssignConditionsAsync — per-document transaction (mẫu per-item Quyết định 24/34): insert 1 eutr_references (RefType=1, RefValue=null) + N eutr_reference_details (1/giá trị)
│   ├── Interfaces/Services/IEutrUploadService.cs        # (SỬA) + Task<List<EutrUploadFileResultDto>> UploadManualMultipleToSharePointAndSaveDataAsync(EutrManualMultiUploadFileRequest, string, ct)
│   ├── Services/EutrUploadService.cs                    # (SỬA) + implement method trên: ResolveOrCreatePoFolderAsync(basePath, "UploadManual") (tên hàm giữ nguyên), bỏ GetMatchingPrefixesAsync, chỉ AddAsync 1 dòng eutr_documents/file — KHÔNG ghi eutr_references (research Quyết định 31)
│   ├── Interfaces/Services/IEutrDocumentsService.cs      # (SỬA) + Task<PagedResult<EutrDocumentsResponseDto>> GetUnassignedPagedAsync(PagedRequest, ct)
│   ├── Services/EutrDocumentsService.cs                  # (SỬA) + implement GetUnassignedPagedAsync (gọi repository dưới, map sang ResponseDto); AttachStepInfoAsync đổi tên AttachStepAndConditionInfoAsync, + gọi GetGroupedConditionsByDocumentIdsAsync gán Conditions (research Quyết định 39)
│   └── Dtos/Response/EutrDocumentsResponseDto.cs          # (SỬA) + List<ConditionGroupDto> Conditions = []
├── ComplianceSys.Infrastructure/
│   ├── Repositories/EutrReferenceDetailsRepository.cs    # MỚI: DapperRepository<EutrReferenceDetails,long>, IEutrReferenceDetailsRepository — clone EutrReferencesRepository (2 method SQL, xem data-model.md)
│   ├── Repositories/EutrReferencesRepository.cs          # (SỬA) + GetUnassignedDocumentsPagedAsync(PagedRequest, ct) (SQL NOT EXISTS, clone khung paging Masters/Templates — research Quyết định 33); SỬA SQL DeleteByDocumentIdAsync (dọn eutr_reference_details trước — research Quyết định 30)
│   └── DependencyInjection.cs                            # (SỬA) + services.AddScoped<IEutrReferenceDetailsRepository, EutrReferenceDetailsRepository>();
├── ComplianceSys.Api/Controllers/
│   ├── SharepointController.cs                          # (SỬA) + action [HttpPost("eutr-upload-manual-multi")] [Consumes("multipart/form-data")] (research Quyết định 32)
│   └── EutrDocumentsController.cs                        # (SỬA) + constructor param IEutrConditionAssignmentService; + [HttpPost("get-unassigned")] GetUnassigned(...); + [HttpPost("assign-conditions")] AssignConditions([FromBody] EutrAssignConditionsRequestDto dto, ct)
└── ComplianceSys.Application/DependencyInjection.cs       # (SỬA) + services.AddScoped<IEutrConditionAssignmentService, EutrConditionAssignmentService>(); + AddScoped validator mới
```

Frontend — **Update 11** (Screen2 thật + `AssignConditionDialog` chế độ tạo mới):

```text
compliance-client/src/
├── utils/helpers.js                                       # (SỬA) + export const CONDITION_TYPE_OPTIONS = [{ value: 15, label: 'PO' }, { value: 14, label: 'Vendor' }]; (cạnh TAKE_FROM_OPTIONS)
├── domain/interfaces/
│   ├── ISharePointRepository.js                          # (SỬA) + uploadEutrManualFilesMulti(_files) { throw new Error('Method not implemented'); }
│   └── IEutrDocumentsRepository.js                        # (SỬA) + getUnassigned(_payload), assignConditions(_payload) { throw new Error('Method not implemented'); }
├── infrastructure/
│   ├── repositories/RestSharePointRepository.js           # (SỬA) + uploadEutrManualFilesMulti(files): FormData { files[] } -> POST /sharepoint/eutr-upload-manual-multi
│   ├── api/eutrDocumentsApi.js                            # (SỬA) + getUnassigned(page,pageSize,sortColumn,sortOrder,payload) -> POST /eutr-documents/get-unassigned; assignConditions(payload) -> POST /eutr-documents/assign-conditions
│   └── repositories/RestEutrDocumentsRepository.js        # (SỬA) + implement 2 method trên
├── application/usecases/
│   ├── sharepoint/UploadToSharePointUseCase.js            # (SỬA) + executeManualMulti(files) { return this.sharePointRepository.uploadEutrManualFilesMulti(files); }
│   └── eutr-documents/
│       ├── GetEutrDocumentsUnassignedUseCase.js           # MỚI: execute(page,pageSize,sortColumn,sortOrder,payload) { return this.repository.getUnassigned(...); }
│       └── AssignEutrConditionsUseCase.js                 # MỚI: execute(payload) { return this.repository.assignConditions(payload); }
└── presentation/pages/eutr-documents/
    ├── components/
    │   └── AssignConditionDialog.jsx                      # MỚI: Dialog {open, mode:'create'|'edit', documents, initialStepId, initialConditions, onClose, onSaved} — dòng Step cố định (GetEutrStepsUseCase), conditionRows[] (Select Conditions type + disable-trùng, ReferenceObjectMultiAutocomplete cho Condition value), nút Add/Delete row (clone state machine ComplianceMasterForm.jsx — research Quyết định 37); Save gọi assignEutrConditionsUseCase (mode=create) — mode=edit dùng ở Update 12
    ├── hooks/useEutrDocumentsColumns.jsx                   # (SỬA) cột "conditions": renderCell mới, .map() qua row.conditions, mỗi nhóm "{label}: {values.join(', ')}" (label tra CONDITION_TYPE_OPTIONS) — research Quyết định 39
    └── EutrDocumentsAdd.jsx                                # (SỬA — Update 11) Screen2: bỏ DEMO_FILE_LIST + handler no-op; + state unassignedFiles/selectedUnassignedIds; useEffect gọi getEutrDocumentsUnassignedUseCase khi Type="Upload manual"; khu Upload File clone Screen1 (KHÔNG điều kiện disabled theo PO) gọi executeManualMulti; bảng file .map() qua unassignedFiles, View/Delete dùng lại EutrFileViewerDialog/ConfirmDialog/deleteEutrDocumentsUseCase; nút Assign condition disabled khi rỗng selection, mở AssignConditionDialog mode="create" — research Quyết định 40
```

Backend — **Update 12** (Edit rẽ nhánh theo Type — mở rộng `IEutrConditionAssignmentService`,
3 action mới trong `EutrDocumentsController`):

```text
compliance-sys-api/src/
├── ComplianceSys.Application/
│   ├── Dtos/Request/EutrUpdateConditionAssignmentRequestDto.cs  # MỚI: { long StepId, List<EutrConditionRowDto> Conditions }
│   ├── Dtos/Request/EutrUpdatePoStepRequestDto.cs               # MỚI: { long StepId }
│   ├── Dtos/Response/EutrDocumentConditionAssignmentDto.cs      # MỚI: { long? StepId, List<EutrConditionRowDto> Conditions }
│   ├── Validators/EutrUpdateConditionAssignmentRequestDtoValidator.cs  # MỚI: cùng rule EutrAssignConditionsRequestDtoValidator (Step bắt buộc, ≥1 Conditions type hợp lệ, không trùng ConditionType)
│   ├── Interfaces/Services/IEutrConditionAssignmentService.cs  # (SỬA) + GetConditionAssignmentAsync(long documentId, ct); UpdateConditionAssignmentAsync(long documentId, EutrUpdateConditionAssignmentRequestDto, string email, ct); UpdatePoStepAsync(long documentId, long stepId, string email, ct)
│   └── Services/EutrConditionAssignmentService.cs               # (SỬA) + implement 3 method trên — GetConditionAssignmentAsync đọc 1 eutr_references (RefType=1) + GetGroupedConditionsByDocumentIdsAsync; UpdateConditionAssignmentAsync: UpdateAsync StepId + DeleteByRefIdAsync + insert lại (replace, research Quyết định 34); UpdatePoStepAsync: xóa toàn bộ eutr_references (RefType=0) của document, insert 1 dòng mới (StepId mới, RefValue giữ nguyên từ dòng Id nhỏ nhất)
└── ComplianceSys.Api/Controllers/
    └── EutrDocumentsController.cs                                # (SỬA) + [HttpGet("{id:long}/condition-assignment")] GetConditionAssignment; + [HttpPut("{id:long}/condition-assignment")] UpdateConditionAssignment; + [HttpPut("{id:long}/step")] UpdatePoStep
```

Frontend — **Update 12** (Edit rẽ nhánh theo Type — tái dùng `AssignConditionDialog` ở `mode="edit"`):

```text
compliance-client/src/
├── domain/interfaces/IEutrDocumentsRepository.js          # (SỬA) + getConditionAssignment(_id), updateConditionAssignment(_id,_payload), updatePoStep(_id,_stepId)
├── infrastructure/
│   ├── api/eutrDocumentsApi.js                            # (SỬA) + getConditionAssignment(id) -> GET /eutr-documents/{id}/condition-assignment; updateConditionAssignment(id,payload) -> PUT .../condition-assignment; updatePoStep(id,stepId) -> PUT /eutr-documents/{id}/step
│   └── repositories/RestEutrDocumentsRepository.js        # (SỬA) + implement 3 method trên
├── application/usecases/eutr-documents/
│   ├── GetEutrDocumentConditionAssignmentUseCase.js       # MỚI: execute(id) { return this.repository.getConditionAssignment(id); }
│   ├── UpdateEutrConditionAssignmentUseCase.js            # MỚI: execute(id,payload) { return this.repository.updateConditionAssignment(id,payload); }
│   └── UpdateEutrDocumentPoStepUseCase.js                 # MỚI: execute(id,stepId) { return this.repository.updatePoStep(id,stepId); }
└── presentation/pages/eutr-documents/
    ├── components/
    │   ├── AssignConditionDialog.jsx                       # (SỬA — Update 12) mode="edit": nạp initialStepId/initialConditions khi open; Save gọi updateEutrConditionAssignmentUseCase.execute(documentId, payload) thay vì assignEutrConditionsUseCase; phần danh sách file trên cùng hiển thị đúng 1 file (read-only, không checkbox)
    │   └── EutrDocumentsModal.jsx                          # (SỬA) + khi open và initialData?.refType === TAKE_FROM_OPTIONS[0].value: render thêm Select/Autocomplete Step (options GetEutrStepsUseCase, value initialData.stepId); Save gọi thêm updateEutrDocumentPoStepUseCase.execute(id, stepId) sau khi updateEutrDocumentsUseCase thành công
    └── index.jsx                                            # (SỬA) onEdit rẽ nhánh theo row.refType: 0 → setModalOpen (như cũ); 1 → gọi getEutrDocumentConditionAssignmentUseCase rồi mở AssignConditionDialog mode="edit"; null/undefined → setModalOpen (không đổi)
```

Backend/Frontend — **Update 13** (`/speckit-clarify` — quy tắc xác định Step + chặn trùng Conditions
type, KHÔNG file mới):

```text
compliance-sys-api/src/ComplianceSys.Application/
├── Dtos/Response/EutrReferenceStepInfo.cs                  # (SỬA) + long ReferenceId (= eutr_references.Id, dùng để suy StepId theo Id nhỏ nhất)
├── Services/EutrDocumentsService.cs                        # (SỬA) AttachStepAndConditionInfoAsync: gán StepId = info OrderBy(ReferenceId).First().StepId (thay vì bỏ qua/undefined)
├── Validators/EutrAssignConditionsRequestDtoValidator.cs   # (SỬA) + .Must(c => c.Select(x => x.ConditionType).Distinct().Count() == c.Count).WithMessage("Duplicate Conditions type")
└── Validators/EutrUpdateConditionAssignmentRequestDtoValidator.cs  # (SỬA) + cùng rule trên

compliance-client/src/presentation/pages/eutr-documents/components/
└── AssignConditionDialog.jsx                                # (SỬA) mỗi <MenuItem> của dropdown Conditions type: + disabled={conditionRows.some(r => r.rowId !== row.rowId && r.conditionType === option.value)} (clone ComplianceMasterForm.jsx)
```

Backend/Frontend — **Update 14** (cột Type lấy nhãn thật từ `eutr_reference_types`, spec FR-034 —
**1 migration mới**, KHÔNG entity/repository/endpoint mới):

```text
compliance-sys-api/src/
├── ComplianceSys.Application/
│   ├── Dtos/Response/EutrReferenceStepInfo.cs              # (SỬA) + string? TypeName (JOIN eutr_reference_types.Name)
│   ├── Dtos/Response/EutrDocumentsResponseDto.cs           # (SỬA) + string? TypeName
│   └── Services/EutrDocumentsService.cs                    # (SỬA) AttachStepAndConditionInfoAsync: + TypeName trong tuple group-theo-DocumentId (Quyết định 20/39) + item.TypeName = info.TypeName
├── ComplianceSys.Infrastructure/Repositories/
│   └── EutrReferencesRepository.cs                         # (SỬA) GetStepInfoByDocumentIdsAsync: + LEFT JOIN eutr_reference_types t ON t.Id = r.RefType, + t.Name AS TypeName trong SELECT (research Quyết định 41)
└── ComplianceSys.Infrastructure/Sqls/Migration/
    └── 14_seed_eutr_reference_types.sql                    # MỚI: CREATE TABLE IF NOT EXISTS eutr_reference_types (phòng vệ, khớp docs/design/eutr/eutr_db.sql) + INSERT ... ON DUPLICATE KEY UPDATE cho Id=0("PO")/Id=1("Upload manual"), bật/tắt NO_AUTO_VALUE_ON_ZERO quanh 2 câu INSERT (research Quyết định 41) — KHÔNG tự thêm FK eutr_references_reftype_foreign (giả định đã có từ rollout feature 006)

compliance-client/src/presentation/pages/eutr-documents/hooks/
└── useEutrDocumentsColumns.jsx                             # (SỬA) cột "type": valueGetter đổi từ TAKE_FROM_OPTIONS.find(opt => opt.value === row.refType)?.label sang row.typeName || "" — bỏ phụ thuộc TAKE_FROM_OPTIONS cho cột này (import TAKE_FROM_OPTIONS xóa nếu không còn dùng ở cột nào khác trong file)
```

Không đổi: `EutrDocumentsController` (không thêm/sửa action nào), `EutrDocumentsRequestDto`,
`EutrDocumentsAdd.jsx` (Type dropdown FR-016 giữ nguyên `TAKE_FROM_OPTIONS`, ngoài phạm vi Update
14), `EutrDocumentsModal.jsx` (rẽ nhánh Edit theo `refType` số, không theo `typeName`).

Backend/Frontend — **Update 15/16** (popup Add hợp nhất Type/Step/Value/Upload thay cho trang Add cũ,
spec FR-059 đến FR-070 — **KHÔNG migration DB mới**, không entity/repository mới):

```text
compliance-sys-api/src/
├── ComplianceSys.Application/
│   ├── Dtos/Request/EutrTypeMultiUploadFileRequest.cs        # MỚI: { List<IFormFile> Files, long TypeId, string TypeName, long StepId, List<string> RefValues } — [FromForm]
│   ├── Interfaces/Services/IEutrUploadService.cs             # (SỬA) + Task<List<EutrUploadFileResultDto>> UploadMultipleForReferenceTypeAsync(EutrTypeMultiUploadFileRequest, string email, CancellationToken)
│   └── Services/EutrUploadService.cs                          # (SỬA) + implement UploadMultipleForReferenceTypeAsync: ResolveFolderName(TypeName, RefValues) (case-insensitive: "po"/"vendor" → RefValues[0]; "invoice"→"Invoice"; "delivery note"→"DeliveryNote"; "general agreement"→"GeneralAgreement"; else → TypeName không khoảng trắng) → gọi lại ResolveOrCreatePoFolderAsync(basePath, folderName) đã có; validate file (ValidateFile đã có, KHÔNG gọi GetMatchingPrefixesAsync); mỗi file: 1 transaction ghi 1 eutr_documents + N eutr_references (N=RefValues.Count, mỗi dòng DocumentId/StepId=request.StepId/RefType=(byte)request.TypeId/RefValue=từng giá trị) — clone cấu trúc try/BeginTransaction/Commit/Rollback đã có ở UploadMultipleToSharePointAndSaveDataAsync
└── ComplianceSys.Api/Controllers/
    └── SharepointController.cs                                # (SỬA) + [HttpPost("eutr-upload-multi-by-type")] [Consumes("multipart/form-data")] EutrUploadMultiByTypeToSharePointAndSaveData([FromForm] EutrTypeMultiUploadFileRequest request, CancellationToken ct) — cùng [Authorize] mức controller đã có, không policy riêng

compliance-client/src/
├── domain/interfaces/ISharePointRepository.js                 # (SỬA) + uploadEutrFilesMultiByType(_files, _typeId, _typeName, _stepId, _refValues) { throw new Error('Method not implemented'); }
├── infrastructure/repositories/RestSharePointRepository.js     # (SỬA) + uploadEutrFilesMultiByType(...): FormData { files[], typeId, typeName, stepId, refValues[] } -> POST /sharepoint/eutr-upload-multi-by-type
├── application/usecases/sharepoint/UploadToSharePointUseCase.js # (SỬA) + executeEutrMultiByType(files, typeId, typeName, stepId, refValues)
└── presentation/pages/eutr-documents/
    ├── index.jsx                                               # (SỬA) nút Add: bỏ navigate('/eutr/documents/add'), + state addDialogOpen, mở <EutrDocumentsAddDialog open={addDialogOpen} onClose={...} onUploaded={refetch danh sách} />
    └── components/
        ├── EutrDocumentsAddDialog.jsx                          # MỚI: Dialog "Add EUTR documents" — Type (Autocomplete đơn, GetEutrReferenceTypesUseCase), Step (Autocomplete đơn, GetEutrStepsUseCase), EutrAddValueAutocomplete, nút Upload (input file ẩn multiple, disabled tới khi đủ Type+Step+≥1 chip); onUpload gọi executeEutrMultiByType rồi hiển thị snackbar kết quả + tự đóng (onClose) theo FR-070
        └── EutrAddValueAutocomplete.jsx                        # MỚI: nếu type.name (lowercase) thuộc {"po","invoice","delivery note"} → useReferenceObjects(refType=15); thuộc {"vendor"} → refType=14; else → Autocomplete multiple freeSolo thuần (không gọi API). onPaste: preventDefault, split clipboard text theo /[\n,]+/, với nguồn gợi ý thì await fetchReferenceObjects(refType, token) rồi giữ match code chính xác (case-insensitive), else thêm token thô làm chip; giới hạn 1 chip khi type.name thuộc {"po","vendor"} (chặn thêm, không tự thay thế — FR-064); đổi prop `type` → reset value về []
```

Không đổi: `EutrDocumentsController`/`EutrDocumentsRequestDto`/`EutrDocumentsService` (dữ liệu ghi qua
`SharePointController` như các Update 6/7/11 trước đó, không qua route `api/eutr-documents`);
`EutrDocumentsAdd.jsx`/route `/eutr/documents/add` (giữ nguyên, không xóa, không còn liên kết từ
toolbar); `EutrDocumentsModal.jsx`/`AssignConditionDialog.jsx` (Edit không đổi);
`ReferenceObjectMultiAutocomplete.jsx` (không sửa component dùng chung, tránh hồi quy Assign
condition).

Frontend — **Update 17** (ô Value tự xóa sau khi thêm chip; Type = "PO" bỏ Step thủ công, tái dùng
endpoint PO gốc — spec FR-071 đến FR-075 — **KHÔNG file backend nào thay đổi**, chỉ sửa 2 file
frontend hiện có của Update 15):

```text
compliance-client/src/presentation/pages/eutr-documents/components/
├── EutrAddValueAutocomplete.jsx    # (SỬA — Update 17) sau khi thêm 1 chip thành công (mọi đường: chọn gợi ý/gõ tay xác nhận/mỗi token hợp lệ khi dán), gọi setInputValue('') (hoặc tương đương của Autocomplete) ngay lập tức — FR-071 (research Quyết định 50)
└── EutrDocumentsAddDialog.jsx      # (SỬA — Update 17) thêm biến isPoType = (type?.name ?? '').trim().toLowerCase() === 'po'; khi isPoType: KHÔNG render/gọi GetEutrStepsUseCase, điều kiện disabled của nút Upload đổi thành !(type && chips.length > 0) (bỏ điều kiện step); onUpload gọi lại executeEutrMulti(files, chips[0]) (use case đã có từ Update 6, POST /api/sharepoint/eutr-upload-multi) thay vì executeEutrMultiByType — FR-072 đến FR-075 (research Quyết định 51); khi !isPoType, toàn bộ logic Update 15/16 (Step bắt buộc, executeEutrMultiByType) giữ nguyên
```

Backend + Frontend — **Update 18** (popup Add gửi kèm `TypeId` khi Type = "PO"; `EutrUploadService`
ghi `RefType` từ `TypeId` nhận được thay cho hằng số cố định — spec FR-076/FR-077, research Quyết
định 52 — **KHÔNG entity/repository/endpoint/migration mới**, chỉ 1 field DTO nullable + sửa 1 dòng
gán giá trị + truyền thêm 1 tham số qua 3 file frontend hiện có):

```text
compliance-sys-api/src/ComplianceSys.Application/
├── Dtos/Request/EutrMultiUploadFileRequest.cs          # (SỬA — Update 18) + public long? TypeId { get; set; } (nullable, KHÔNG [Required] — không phá vỡ caller cũ EutrDocumentsAdd.jsx)
└── Services/EutrUploadService.cs                       # (SỬA — Update 18) dòng gán RefType = PoRefType đổi thành RefType = request.TypeId.HasValue ? (byte)request.TypeId.Value : PoRefType — FR-077 (research Quyết định 52)

compliance-client/src/
├── infrastructure/repositories/RestSharePointRepository.js      # (SỬA — Update 18) uploadEutrFilesMulti(files, poCode, typeId) — thêm formData.append('typeId', typeId) khi có giá trị
├── application/usecases/sharepoint/UploadToSharePointUseCase.js # (SỬA — Update 18) executeEutrMulti(files, poCode, typeId) { return this.sharePointRepository.uploadEutrFilesMulti(files, poCode, typeId); }
└── presentation/pages/eutr-documents/components/EutrDocumentsAddDialog.jsx  # (SỬA — Update 18) nhánh isPoType: onUpload gọi executeEutrMulti(files, chips[0], type.id) — truyền thêm type.id (Id thật của Type "PO" đang chọn) — FR-076
```

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
| Screen2 "Upload manual" thật + bảng con `eutr_reference_details` (Update 11) | Masters/Templates: không có khái niệm "gán nhiều Conditions type/value cho 1 bản ghi" | Duy nhất trong feature này ghi vào **2 tầng** bảng con (`eutr_references` cha + `eutr_reference_details` cháu) cho cùng 1 document — mô hình clone từ 1 feature khác hẳn domain (`ComplMasterCondition`/`ComplMasterConditionValue` của compliance-master), không phải từ Masters/Templates/Steps như mọi mẫu tham chiếu trước đó của feature này |
| "Chưa gán" — truy vấn `NOT EXISTS` (Update 11) | Masters/Templates: mọi query paged đều JOIN theo khóa ngoại có sẵn | Duy nhất trong feature này cần lọc theo **sự vắng mặt** của bản ghi liên kết (không phải JOIN thêm dữ liệu) — bắt buộc viết SQL tùy biến vì `BaseRepository.GetPagedAsync` generic không hỗ trợ `NOT EXISTS`/JOIN |
| Edit rẽ nhánh theo Type, không còn 1 popup duy nhất (Update 12) | Masters/Templates/Steps: Edit luôn mở đúng 1 popup cố định | Duy nhất trong feature này Edit mở **1 trong 3 UI khác nhau** tùy `refType` của dòng — 2 UI trong số đó (popup Assign condition sửa, Step field trong popup đơn giản) đều là chức năng mới của chính feature này (Update 11), không có ở bất kỳ feature EUTR nào khác |
| Popup Add hợp nhất Type/Step/Value/Upload (Update 15/16) | Masters/Templates/Steps: Add luôn 1 form cố định (modal hoặc trang), Type không tồn tại | Duy nhất trong feature này Add mở popup có **Type động** (toàn bộ `eutr_reference_types`, không giới hạn 2 lựa chọn) quyết định nguồn gợi ý Value (PO/Vendor/tự do) và tên thư mục SharePoint — `RefType` ghi vào `eutr_references` không còn cố định `0`/`1` như Update 7/11 mà là `Id` bất kỳ do người dùng chọn; trang Add cũ (`EutrDocumentsAdd.jsx`) bị bỏ liên kết nhưng KHÔNG bị xóa (dead code có chủ đích) |
| Type = "PO" trong popup Add bỏ Step thủ công (Update 17) | Mọi Type khác trong cùng popup (Vendor/Invoice/Delivery note/...) đều bắt buộc chọn Step thủ công qua combobox (Update 15) | Duy nhất Type = "PO" trong popup Add này KHÔNG có combobox Step — Step suy tự động theo prefix tên file (tái sử dụng nguyên vẹn cơ chế/endpoint `eutr-upload-multi` của Update 6/7); đây cũng là trường hợp **duy nhất trong toàn bộ Update 15/16/17** mà một nhánh Type gọi endpoint khác (`eutr-upload-multi` thay vì `eutr-upload-multi-by-type`) — 0 thay đổi backend |

## Complexity Tracking

> Không có vi phạm hiến pháp → bảng này để trống.
