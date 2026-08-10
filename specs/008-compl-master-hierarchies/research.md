# Phase 0 Research: Compliance Master Hierarchies

## 1. Reference pattern lựa chọn (Nguyên tắc II)

**Quyết định**: Backend clone **`EutrReferenceTypeDetails`** (`006-eutr-reference-types`, Update 1) làm
mẫu tham chiếu chính — bảng nhỏ (Id + vài cột nghiệp vụ + audit), dùng generic
`DapperRepository<T, long>`/`BaseService<T, long, TDto>` (package `Res.Shared.Dapper`) cho CRUD cơ
bản, cộng thêm vài method tuỳ biến (`GetByTypeIdAsync`, `HasStepAssignedAsync`) cho nghiệp vụ riêng.
Frontend UI (tree + toolbar) clone **`TemplateBuilderPage.jsx`** (`003-eutr-templates`); picker popup
clone **`BulkAddStepsDialog.jsx`** nhưng nguồn dữ liệu là **compliance-master** đã có sẵn, không phải
danh sách step.

**Vì sao KHÔNG dùng `ComplMaster`/`ComplMasterController` làm mẫu**: `ComplMaster` dùng Dapper thủ
công gọi stored procedure MySQL phức tạp (nhiều JOIN, JSON_ARRAYAGG, full-text search) vì bảng
`compl_masters` có rất nhiều cột nghiệp vụ và logic tính `Status`/group email. Bảng mới
`compl_master_hierarchies` chỉ có `MasterCode`/`ParentCode`/`DisplayOrder` + audit — cùng hình dạng
với `eutr_reference_type_details`, không phải `compl_masters`. Dùng generic repository giúp tránh
viết stored procedure không cần thiết.

**Vì sao KHÔNG dùng `document-type` làm mẫu chính**: `document-type` là CRUD phẳng (list + form),
không có khái niệm cây/parent-child hay bulk-add. `EutrReferenceTypeDetails` sát hơn vì nó là "bảng
chi tiết gán theo một khoá nghiệp vụ" (dù ở đó là `TypeId` số, còn ở đây là `ParentCode` dạng chuỗi).

**Alternatives considered**: Dùng recursive CTE (MySQL 8 hỗ trợ `WITH RECURSIVE`) để kiểm tra vòng
lặp tổ tiên ngay trong SQL — bị loại vì (a) đặt business rule vào SQL vi phạm tinh thần Nguyên tắc I
(logic nghiệp vụ nên ở Application layer, không phải Infrastructure), (b) dữ liệu hierarchy dự kiến
nhỏ (master data, tối đa vài nghìn dòng) nên tải toàn bộ bảng vào bộ nhớ và duyệt bằng C# đơn giản,
dễ test hơn nhiều so với CTE đệ quy.

## 2. Mô hình dữ liệu: khoá tự nhiên (natural key) tạo thành DAG, không phải cây thuần

**Quyết định**: `ParentCode` trỏ tới `MasterCode` của node cha (theo đúng yêu cầu), KHÔNG dùng
surrogate `ParentId`. Ràng buộc UNIQUE trên `(MasterCode, ParentCode)` xử lý đồng thời 2 quy tắc đã
làm rõ ở `/speckit-clarify`:
- FR-011 (không trùng Root): vì mọi Root đều có `ParentCode = ''`, nên 2 dòng Root cùng `MasterCode`
  sẽ vi phạm chính UNIQUE này (`(A, '')` không thể xuất hiện 2 lần).
- FR-013 (không trùng sibling): 2 dòng cùng `MasterCode` + cùng `ParentCode` cũng vi phạm UNIQUE này.

**Hệ quả cần lưu ý (không phải lỗi, là hệ quả tất yếu của thiết kế khoá tự nhiên đã được xác nhận ở
Clarify)**: vì một `MasterCode` có thể xuất hiện ở nhiều nhánh khác nhau (nhiều dòng, khác
`ParentCode`), và các con của nó được tra theo `ParentCode = MasterCode đó` (không phải theo dòng cụ
thể), nên **mọi lần xuất hiện của cùng một `MasterCode` sẽ hiển thị chung một tập con** (shared
subtree — giống một DAG hơn là cây thuần). Xoá 1 lần xuất hiện sẽ xoá luôn tập con dùng chung đó,
ảnh hưởng tới các lần xuất hiện khác của cùng mã. Đây là hệ quả trực tiếp của yêu cầu gốc ("Chill thì
lấy cột MasterCode của Root lưu làm ParentCode" + cho phép tái sử dụng 1 master ở nhiều nhánh, đã xác
nhận ở Clarify) — không cần quay lại `/speckit-clarify`, chỉ cần ghi nhận rõ trong `data-model.md` và
cảnh báo khi xoá (đếm & liệt kê descendants trước khi xoá, theo FR-014/User Story 3).

**Thuật toán kiểm tra vòng lặp tổ tiên (FR-012)**: định nghĩa "ancestors(C)" = hợp của `ParentCode`
của MỌI dòng có `MasterCode = C` (bỏ qua `''`), cộng đệ quy ancestors của từng parent code đó. Khi
thêm `Z` làm con của `P`: từ chối nếu `Z == P` hoặc `Z ∈ ancestors(P)`. Cài đặt: tải toàn bộ bảng 1
lần (`GetAllWithMasterInfoAsync`), dựng đồ thị `code → set<parentCode>` trong bộ nhớ, BFS/DFS từ `P`.
Không cần gọi DB nhiều lần hay CTE đệ quy.

## 3. Xác định "MasterCode" khi lưu — dùng đúng giá trị `Code` mà picker hiển thị

`compl_masters` có `UNIQUE (Code, VersionNo)` — `Code` KHÔNG tự nó là duy nhất toàn bảng (do
versioning). Đã xác minh `compl_sp_get_compl_master_paging` dùng CTE `LatestVersions` (`MAX(VersionNo)
GROUP BY Code`) nên danh sách phân trang hiện tại (dùng lại y nguyên cho popup theo FR-005) đã chỉ
trả về **đúng 1 dòng cho mỗi Code** (phiên bản mới nhất). **Quyết định**: `compl_master_hierarchies`
lưu đúng giá trị `Code` mà picker trả về, không quan tâm `VersionNo`/`Id` — không cần join phức tạp
hay xử lý version trong feature này.

## 4. Xác thực/quyền truy cập (FR-020)

Đã xác nhận `ComplMasterController` dùng `[Authorize(Policy = "ComplianceMaster.ReadAll")]` cho các
endpoint chỉ-đọc, và các policy `.Create/.Update/.Delete` riêng cho ghi. Theo Clarify (không hạn chế
— bất kỳ ai xem được danh sách Compliance Master đều sửa được hierarchy), **quyết định**: MỌI
endpoint mới (xem cây, add root, add child, move, delete) đều gate bằng **cùng 1 policy
`ComplianceMaster.ReadAll`** — không tạo policy family `ComplMasterHierarchy.*` riêng, và KHÔNG dùng
`.Create/.Update/.Delete` cho các hành động ghi (khác quy ước thông thường của các feature CRUD khác
trong repo). Đây là điểm khác biệt CÓ CHỦ ĐÍCH, xuất phát trực tiếp từ FR-020, không phải thiếu sót.

## 5. Điểm vào màn hình (routing) — không tạo menu top-level mới

Vì hierarchy là **1 forest toàn hệ thống duy nhất** (đã xác nhận ở Clarify — không có nhiều bản ghi
cha để liệt kê), tạo hẳn 1 menu-item cấp cao (kiểu `document-type`) là thừa và tốn thêm 1 tác vụ seed
`userMenu`/quyền trên DB (ADR 0002). **Quyết định**: theo đúng tiền lệ `ApplyCustomerPage.jsx`
(`003-eutr-templates`)/`AssignStepsPage.jsx` (`006-eutr-reference-types`) — thêm 1 route con TĨNH
trong `app/routes/groups/MainRoutes.jsx` (`/compliance-master/hierarchies`), truy cập qua 1 nút mới
trên `presentation/pages/compliance-master/index.jsx` (màn hình danh sách Compliance Master hiện có),
tái sử dụng quyền của menu cha `compliance-master`. KHÔNG cần sửa `RouteResolver.jsx`/
`menu-items/ComplianceSystem.jsx`, KHÔNG cần seed menu/quyền mới trên DB.

## 6. Tái sử dụng 100% phần "chọn master" & "xem condition" (Nguyên tắc III)

Xác nhận các phần sau ĐÃ TỒN TẠI và sẽ được tái sử dụng nguyên trạng, không sửa:
- `GetPagingComplianceMasterUseCase` (`application/usecases/compliance-master/index.js`) — gọi
  `repositories.complianceMaster.getAllPaging(page, pageSize, sortColumn, sortOrder,
  onlyMyCompliances, payload)` → `POST /compliance-master/get-all`. Popup gọi lại y nguyên use case
  này (page=1, pageSize=50, không filter) — KHÔNG cần API/use case mới cho việc load danh sách master.
- `GetConditionsByMasterIdUseCase` → `GET /compliance-master/{id}/conditions`, cộng component có sẵn
  `@presentation/components/common/ConditionsView.jsx` (dialog đọc-only, đã dùng ở
  `compliance-master/index.jsx` dòng ~145/941) — nút "View condition" trong popup tái sử dụng nguyên
  cặp use case + component này, KHÔNG viết lại UI xem condition.

Việc duy nhất cần code mới ở phía "chọn master" là component popup (`MasterPickerDialog.jsx`) —
bảng checkbox + phân trang + nút Add, còn toàn bộ nguồn dữ liệu/hiển thị condition đã có sẵn.

## 7. Vị trí file SQL & cách áp dụng cho môi trường đã tồn tại

`DatabaseInitializer.InitTables()`/`InitProcedures()` chỉ tự chạy TOÀN BỘ `Sqls/Tables/*.sql` và
`Sqls/Procedures/*.sql` khi database **chưa tồn tại** (fresh install). Với môi trường dev/prod đã có
sẵn database (trường hợp thực tế luôn xảy ra), các file này KHÔNG tự chạy — phải áp dụng thủ công qua
`Sqls/Migration/NN_*.sql` (đánh số tiếp theo, hiện tại tới `15_add_alerttype_to_compl_masters_procs.sql`).
**Quyết định**: thêm bảng mới vào CẢ HAI nơi — `Sqls/Tables/compl_master_hierarchies.sql` (cho fresh
install) VÀ `Sqls/Migration/16_create_compl_master_hierarchies.sql` (script `CREATE TABLE IF NOT
EXISTS` để áp dụng thủ công cho môi trường hiện có) — đúng tiền lệ Update 13 của `003-eutr-templates`
(`eutr_template_references`). Vì dùng generic `DapperRepository<T,long>`, KHÔNG cần viết stored
procedure nào — chỉ cần 1 câu `SELECT ... JOIN compl_masters` cho `GetAllWithMasterInfoAsync`, được
viết trực tiếp trong Repository class (Dapper inline SQL), không cần file `.sql` riêng trong
`Sqls/Procedures/`.

## 8. Ngôn ngữ UI (Nguyên tắc IV)

Hình tham khảo của người dùng và các FR trong spec (`FR-002`, `FR-006`) đặt tên trực tiếp các nhãn
nút/cột bằng tiếng Anh ("Add root", "Add child", "Back", "Code"/"Name"/"Description"/"View
condition") — đúng như hình chụp màn hình gốc. **Quyết định**: toàn bộ UI của màn hình mới này (nhãn
nút, tiêu đề cột, tiêu đề popup, thông báo lỗi) dùng **tiếng Anh**, được cho phép bởi Nguyên tắc IV
bản 2.0.0 (spec yêu cầu rõ qua việc đặt tên nhãn cụ thể, tương tự cách `006-eutr-reference-types`
(FR-012) đã làm) — không áp dụng mặc định tiếng Việt cho riêng màn hình này. Comment code vẫn tiếng
Việt như thường lệ.

## 9. Kéo-thả trong cây (User Story 5 / FR-022-024) - sap xep lai trong cung cap, KHONG reparent

**Cap nhat 2026-07-30 (follow-up)**: pham vi da duoc THU HEP lai theo phan hoi cua nguoi dung - bo
hoan toan tinh nang "Drop here to make root" va reparent qua node khac; keo-tha CHI con lam 1 viec
duy nhat: sap xep lai vi tri trong cung nhom anh em (cung `ParentCode`). Cac quyet dinh reparent/root
drop zone ghi ben duoi (endpoint `/reparent`, `RootDropZone.jsx`, `ExistsExcludingIdAsync`, ...) o
phien lam viec truoc DA BI GO BO khoi code - phan lich su nay chi con gia tri tham khao "da can nhac
va tai sao khong dung nua", KHONG con phan anh code hien tai.

**Xac nhan ha tang co san**: `package.json` cua `compliance-client` da co `@dnd-kit/core`,
`@dnd-kit/sortable`, `@dnd-kit/utilities` (dung boi dung 1 file duy nhat trong repo:
`TemplateBuilderPage.jsx`). `react-beautiful-dnd` cung co trong `package.json` nhung **khong duoc
import o bat ky dau** - dependency chet, khong dung cho feature nay de tranh tron 2 thu vien DnD.

**Quyet dinh (sau khi thu hep pham vi)**: pattern DnD cua tinh nang nay gio **giong het**
`TemplateBuilderPage.jsx` ve mat cau truc - tai su dung nguyen sensors (`PointerSensor` +
`KeyboardSensor`) va `SortableContext`-theo-tung-nhom-anh-em, `handleDragEnd` so
`activeNode.parentCode !== overNode.parentCode` roi **bo qua** (no-op) neu khac cha, giong het
guard clause goc cua `TemplateBuilderPage.jsx`. Diem khac duy nhat con lai so voi
`TemplateBuilderPage.jsx`: persist NGAY qua API `PUT api/compl-master-hierarchies/{id}/reorder`
(`{ targetIndex }`) khi tha hop le trong cung cha, thay vi don vao 1 nut "Save" rieng - van giu dung
FR-017/024 (khong co buoc Save cho hierarchy). Khong con endpoint `/reparent`, khong con
`RootDropZone.jsx`, khong con nhu cau tai su dung rule validate vong lap/trung lap cho drag-and-drop
(reorder trong cung cha khong doi `ParentCode` nen khong co rui ro vong lap/trung lap).

**Xu ly loi/UI**: neu `/reorder` tra loi (vi du 404 id khong ton tai), page KHONG ap dung thay doi
vao state cay (giu nguyen vi tri cu tren UI) va hien thong bao loi.

**(Lich su - da go bo, chi de tham khao)** O phien truoc, tinh nang nay tung ho tro ca reparent (tha
len 1 node khac hoac vao vung "root drop zone"), tai su dung nguyen ven 3 rule validate cua Add
root/Add child (FR-011/012/013) va can them 1 repository method `ExistsExcludingIdAsync` de loai tru
chinh dong dang keo khi kiem tra trung lap. Quyet dinh nay bi dao nguoc truc tiep boi phan hoi cua
nguoi dung ("bo phan Drop here to make root, chi keo tha o cung level") - khong con ly do nghiep vu
nao de giu lai reparent-qua-drag trong pham vi feature nay.

**Alternatives considered**: Goi lai nhieu lan API `/move` (up/down) hien co de mo phong nhay toi vi
tri bat ky - bi loai vi ton nhieu round-trip, va response cua `/move` chi tra 2 dong (khong du de
client dong bo toan bo nhom anh em sau khi nhay nhieu buoc). Dung `react-beautiful-dnd` thay vi
`@dnd-kit` - bi loai vi day la dependency chet, khong co tien le dung trong repo, va se vi pham
Nguyen tac II (Reference-Pattern Reuse) so voi `TemplateBuilderPage.jsx` da co san.

## 10. Search theo Code/Name trong popup chon master (FR-025-027) - tai su dung 100% ha tang loc co san

**Quyet dinh**: KHONG can API/DTO/stored-procedure moi cho o search. Da xac minh (xem
`compliance-client/src/presentation/pages/compliance-master/index.jsx` ham `handleSearch`, va
`ComplMasterController.GetPaged`/`ComplMasterQueryService.GetComplMasterPagedAsync`/
`compl_sp_get_compl_master_paging.sql`) rang API phan trang hien co
(`GetPagingComplianceMasterUseCase` -> `POST /compliance-master/get-all`) DA ho tro san 1 co che loc
tu do qua tham so `payload` (mang `FilterRequest { column, operator, value }`): gui
`[{ column: "searchText", operator: "like", value: "<text nguoi dung nhap>" }]` se cho stored
procedure loc theo `cd.Code LIKE`, `cd.Name LIKE` VA `cd.Description LIKE` (ket hop OR, cong ca
full-text MATCH) - dung dung nhu FR-025 yeu cau (loc theo Code HOAC Name; Description bi loc kem
theo cung 1 tham so nhung khong vi pham FR-025 vi la tap ket qua sieu-tap dung, khong thieu ket qua
hop le).

**Ly do dung nguyen `searchText` (khong tach 2 tham so Code/Name rieng)**: khong co san tham so
loc rieng-Code hay rieng-Name trong stored procedure hien co (chi co 1 tham so gop
`p_search_text`); tach ra tham so moi doi hoi sua `compl_sp_get_compl_master_paging.sql` (anh huong
ca man hinh `compliance-master` hien co, ngoai pham vi feature nay - vi pham Nguyen tac III/Reuse
Existing Backend neu tu y sua). FR-025 (spec) da duoc viet voi gia dinh 1 o search gop, khop chinh
xac voi ha tang co san nay.

**Cach `MasterPickerDialog.jsx` goi**: gui lai y nguyen `GetPagingComplianceMasterUseCase.execute(1,
50, sortColumn, sortOrder, false, [{ column: "searchText", operator: "like", value: searchText }])`
- LUON reset ve `page = 1` (FR-025). Khi o search rong, goi lai voi `payload = []` de tra ve danh
sach day du (FR-027). Component da co san 1 state rieng (`Map<code, master>`, dung ngay tu ban
implement dau tien cua US1) luu cac master da check qua NHIEU trang/nhieu lan search (khong phu
thuoc vao ket qua dang hien thi) de dam bao FR-026 (giu lua chon khi bi loc khoi ket qua).

**Cap nhat luc implement (2026-07-30, follow-up 2)**: thay vi debounce-tu-dong-khi-go (du kien ban
dau o tren), da chon dung LAI CHINH XAC pattern search da co san trong repo -
`ComplianceFilterBar.jsx`/`compliance-master/index.jsx` (`handleSearch`/`handleClearSearch`, kich
hoat qua nut Search/Clear ro rang HOAC phim Enter, KHONG tu dong goi API moi lan go phim). Ly do
doi: (a) dung dung Nguyen tac II (Reference-Pattern Reuse) - khong can them logic debounce/timer
moi trong khi pattern nay da co san va da duoc dung o chinh man hinh nguon du lieu
(`compliance-master`); (b) tranh goi API lien tuc khi nguoi dung dang go (giam tai server, dong
nhat UX voi cac o search khac trong he thong). Khong anh huong FR-025/026/027 - hanh vi cuoi cung
(loc theo Code/Name, reset trang 1, giu lua chon, xoa search phuc hoi danh sach day du) van dung
nguyen yeu cau spec, chi khac ve thoi diem kich hoat truy van.

**Alternatives considered**: Loc client-side tren danh sach 50 dong da tai (khong goi lai API) - bi
loai vi popup chi tai 1 trang 50 dong tai 1 thoi diem (FR-005), loc client-side se BO SOT cac master
o cac trang chua tai (vi pham FR-025 "search phai la truy van trang-dau moi, khong chi loc trang da
tai"). Them 2 tham so `p_search_code`/`p_search_name` rieng vao stored procedure - bi loai vi khong
can thiet (tham so gop da du dung yeu cau spec) va se phai sua file dung chung voi man hinh
`compliance-master` hien co, ngoai pham vi toi thieu can cho feature nay.

## 11. "View condition" tren tung dong cua cay (User Story 6 / FR-028-030) - chi frontend, khong API moi

**Boi canh**: US4 (da xong) chi dua "View condition" vao popup chon master (`MasterPickerDialog.jsx`).
Yeu cau moi (2026-08-10) la them cung hanh dong do vao MOI DONG cua chinh cay hierarchy tren man hinh
index (`ComplMasterHierarchiesPage.jsx`), doc lap voi viec dong/mo popup hay chon node.

**Xac nhan hien trang** (code hien tai, truoc update nay): moi node tren cay chi render qua
`SortableMasterLabel` (component rieng trong `ComplMasterHierarchiesPage.jsx`) - gom drag-handle
(`DragIndicatorIcon`) + text "Code - Name", `onClick` goi `onSelect(node.id)`. KHONG co icon/action
nao khac tren dong. Component nay khac hoan toan voi row cua `MasterPickerDialog.jsx` (bang MUI
`Table`/`TableRow`), nhung ca hai deu co the goi chung 1 cap use case + component da dung o US4.

**Quyet dinh**: Them 1 `IconButton` "View condition" (`ViewIcon`, `Tooltip`) vao trong
`SortableMasterLabel`, canh ben text "Code - Name", `onClick` phai goi `event.stopPropagation()`
truoc khi goi `GetConditionsByMasterIdUseCase.execute(node.id)` (dung LAI NGUYEN VEN use case da co,
KHONG viet lai) roi mo `ConditionsView` (dung LAI NGUYEN VEN component da co, cung 1 dialog nhu
`MasterPickerDialog.jsx` dang dung) - de tranh vo tinh trigger `onSelect(node.id)` cua the cha khi
bam vao icon (2 hanh vi phai doc lap theo FR-029). State `conditionsOpen`/`conditions`/
`loadingConditions` duoc quan ly ngay trong `ComplMasterHierarchiesPage.jsx` (hoac hook
`useComplMasterHierarchyTree.js` neu can chia se), KHONG anh huong `selectedId`/`expanded` state hien
co cua trang.

**Vi sao KHONG can API/DTO/backend moi**: `GetConditionsByMasterIdUseCase` da goi
`GET /compliance-master/{id}/conditions` - endpoint nay thuoc `ComplMasterController` (da co san,
dung boi US4), khong thuoc `ComplMasterHierarchyController`
(`api/compl-master-hierarchies`) cua feature nay. Moi node tren cay da co san `id` (tra ve tu
`GetAllWithMasterInfoAsync`, dung de move/delete) - dung truc tiep `node.id` de goi use case nay,
giong het cach `MasterPickerDialog.jsx` dung `row.id`. Khong co thay doi nao o
`ComplMasterHierarchyController`/Service/Repository/DTO/bang du lieu cho update nay.

**Alternatives considered**: Tach rieng 1 component `TreeNodeLabel` moi thay vi sua
`SortableMasterLabel` hien co - bi loai vi khong can thiet, `SortableMasterLabel` da la noi dung
render moi node roi, them 1 icon vao trong cung component nay don gian hon va giu nguyen cau truc
drag-handle+text da co (Nguyen tac II - khong tao component song song lam cung 1 viec).

**Sua loi (2026-08-10, sau khi implement)**: Ban dau da dung nham `node.id` (khoa cua chinh dong
`compl_master_hierarchies`) lam tham so cho `GET /compliance-master/{id}/conditions` - endpoint nay
can `compl_masters.Id`, khong phai khoa hierarchy. Hau qua: "View condition" tren cay luon hien
"No conditions defined" (rong hoac sai du lieu) du master do co dieu kien. **Sua**: them cot
`MasterId` (join `m.Id`) vao `ComplMasterHierarchyResponseDto`/SQL cua
`GetAllWithMasterInfoAsync`/`GetByIdsWithMasterInfoAsync` (dung 1 nguon SQL chung
`SelectWithMasterInfoSql` nen tat ca luong - GetTree/AddRoots/AddChildren/Move/Reorder - deu tu
dong co field nay), doi frontend (`handleViewCondition` trong `ComplMasterHierarchiesPage.jsx`)
sang dung `node.masterId` thay vi `node.id`; neu `masterId` null (Compliance Master goc da bi xoa)
thi bo qua goi API va hien empty state ngay (khong goi API voi id rong) - xem data-model.md muc
"Sua loi".
