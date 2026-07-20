# Feature Specification: EUTR Templates Management

**Feature Branch**: `003-eutr-templates`

**Created**: 2026-07-02

**Status**: Draft

**Input**: User description: "Chức năng mới dựa theo docs/design/eutr/eutr_templates_overview.md — quản lý EUTR templates với danh sách grid, tạo template mới kèm cây bước (step tree) đệ quy, xóa, và import."

## Clarifications

### Session 2026-07-03

- Q: Khi đánh dấu template là Default, phạm vi ràng buộc là gì? → A: Mỗi VendorCode chỉ có tối đa 1 template IsDefault=1. Khi đánh dấu template mới là default, hệ thống tự bỏ cờ default trên template cũ cùng VendorCode.
- Q: Người dùng sắp xếp thứ tự (DisplayOrder) các step trong cây bước bằng cách nào? → A: Hỗ trợ drag-and-drop để kéo thả sắp xếp step trong cây.
- Q: VendorCode và AlertFor có bắt buộc khi tạo/sửa template không? → A: VendorCode là tùy chọn (có thể null). AlertFor là bắt buộc.
- Q: Người dùng xóa step khỏi cây bước trên màn hình Add/Edit bằng cách nào? → A: Cả hai cách: icon X trên mỗi dòng step (xóa đơn lẻ) và checkbox multi-select rồi nhấn nút Delete step (xóa nhiều).
- Q: Một VendorCode có thể có nhiều template hoạt động cùng lúc không? → A: Có, cho phép nhiều template cùng VendorCode hoạt động đồng thời.

### Session 2026-07-03 (Update)

- Bug: Combobox Vendor trên màn hình Add/Edit chưa gọi API D365 VendorsV3 để lấy danh sách vendor → Cần sửa để combobox Vendor gọi đúng API và hiển thị danh sách VendorAccountNumber + VendorOrganizationName.
- Bug: Khi Save template, cột ParentId không được lưu vào bảng eutr_template_details → Cần sửa để ParentId được truyền đúng từ cây bước và lưu vào bảng.
- Feature: Thêm chức năng chỉnh sửa (Edit) step đã tạo trong cây bước — cho phép đổi step, đổi RequirementType, đổi TakeFrom trực tiếp trên step đã có.
- Feature: Giao diện màn hình Add/Edit chia thành 2 cột — cột trái chứa thông tin header (Code, Name, AlertFor, Vendor, Default), cột phải chứa cây bước (Steps) và các thao tác trên step.

### Session 2026-07-03 (Update 2)

- Change: Backend MUST thêm endpoint riêng `GET /api/dynamics/vendors` trong DynController để query danh sách vendors từ D365 VendorsV3, theo pattern tương tự endpoint `data-area` (SetEntity("VendorsV3"), hỗ trợ skip/top/filter/order_by). Định nghĩa entity từ ComplianceSys.Domain.Dynamics.VendorsV3.
- Change: Frontend cột Vendor (combobox trên Add/Edit và tra cứu vendorName trên grid) MUST chuyển từ sử dụng API reference chung (`POST /api/dynamics/reference` với refType) sang API riêng `GET /api/dynamics/vendors`. Loại bỏ phụ thuộc vào ReferenceObjectAutocomplete cho vendor, thay bằng gọi trực tiếp endpoint vendors mới.

### Session 2026-07-03 (Update 3)

- Change: Endpoint `GET /api/dynamics/vendors` hiện tại đang lấy toàn bộ dữ liệu từ VendorsV3 (tất cả các cột). MUST chỉnh lại để chỉ lấy 3 cột cần thiết: `dataAreaId`, `VendorAccountNumber`, `VendorOrganizationName` bằng cách sử dụng OData `$select` trên URL query. Giảm payload trả về và cải thiện hiệu suất.

### Session 2026-07-03 (Update 4)

- Q: Khi Edit một template được tạo/sửa cách đây dưới 24 giờ, hệ thống nên xử lý version như thế
  nào? → A: Cập nhật đè lên dòng hiện tại — không tạo dòng mới, không tăng VersionId, không set
  IsHide trên dòng cũ. Sửa trực tiếp Name/Vendor/AlertFor/Default và toàn bộ step tree trên cùng
  bản ghi. Sau 24h kể từ CreatedDate của bản ghi hiện tại, lần Edit tiếp theo mới tạo version mới
  (VersionId+1, ẩn dòng cũ) như cơ chế cũ.
- Change: Logic lên version chỉ áp dụng khi template đang sửa đã được tạo (CreatedDate) cách đây
  TRÊN 24 giờ. Nếu dưới 24 giờ, Edit sẽ cập nhật đè lên bản ghi hiện tại (không tạo version mới).
- Change: Di chuyển nút Save trên màn hình Add/Edit — từ thanh tiêu đề (cùng hàng với Back) xuống
  vị trí ngay dưới checkbox "Set as default template" ở cột trái (header form). Nút Back vẫn giữ
  nguyên vị trí ở thanh tiêu đề.
- Change: Mở rộng chiều ngang cột trái (Code, Name, AlertFor, Vendor, Default, Save) và thu hẹp
  cột phải (Step tree) trên màn hình Add/Edit.
- Change: Khi nhấn nút Back trên màn hình Add/Edit, nếu người dùng đã thêm hoặc chỉnh sửa step
  trong cây bước mà CHƯA nhấn Save, hệ thống MUST hiển thị cảnh báo xác nhận trước khi rời trang.
  Nếu người dùng chọn rời đi, các thay đổi chưa lưu sẽ KHÔNG được áp dụng (mất thay đổi).

### Session 2026-07-06 (Update 5)

- Change: Đảo ngược lại quyết định ở Update 2/3 — combobox Vendor trên màn hình Add/Edit
  (`EutrTemplatesAddEdit.jsx`, chỗ `options={vendors}`) MUST đổi logic tải dữ liệu từ endpoint
  riêng `GET /api/dynamics/vendors` sang API reference chung `POST /api/dynamics/reference` với
  `refType = 13`. Loại bỏ phụ thuộc vào hook `useVendors`/endpoint vendors riêng; combobox Vendor
  và tra cứu Vendor name trên grid MUST dùng lại API reference chung (ví dụ qua
  ReferenceObjectAutocomplete hoặc hook `useReferenceObjects` tương đương) với refType=13, theo
  đúng pattern các trường reference khác trong hệ thống.

### Session 2026-07-07 (Update 8)

- Q: StepFormRow.jsx (cùng thư mục components) hiện đang có một bản sao trùng lặp y hệt của
  REQUIREMENT_TYPES và TAKE_FROM_OPTIONS. Khi di chuyển 2 hằng số này sang helpers.js,
  StepFormRow.jsx có nên được cập nhật để import từ helpers.js luôn không? → A: Có — cả
  StepTree.jsx và StepFormRow.jsx đều xóa bản khai báo local, cùng import từ helpers.js.
- Q: StepTree.jsx còn có REQUIREMENT_LABELS và TAKE_FROM_LABELS (map tra cứu label dạng
  {0: 'Optional', 1: 'Required'}) — biểu diễn khác của cùng dữ liệu enum. Có di chuyển luôn 2 map
  này sang helpers.js cùng đợt không? → A: Có — di chuyển luôn cả REQUIREMENT_LABELS và
  TAKE_FROM_LABELS sang helpers.js cùng với REQUIREMENT_TYPES/TAKE_FROM_OPTIONS.
- Change: Di chuyển 4 hằng số dùng chung cho RequirementType/TakeFrom — REQUIREMENT_TYPES,
  TAKE_FROM_OPTIONS (mảng `{value, label}[]` dùng làm `options` cho Autocomplete), REQUIREMENT_LABELS,
  TAKE_FROM_LABELS (map tra cứu label theo value) — từ
  `compliance-client/src/presentation/pages/eutr-templates/components/StepTree.jsx` sang
  `compliance-client/src/utils/helpers.js`, export để tái sử dụng. Xóa bản khai báo local trùng lặp
  ở cả `StepTree.jsx` và `StepFormRow.jsx` (đang có cùng REQUIREMENT_TYPES/TAKE_FROM_OPTIONS trùng
  y hệt); cả hai file MUST import 4 hằng số này từ `utils/helpers.js` thay vì tự khai báo. Giữ
  nguyên tên hằng số và cấu trúc dữ liệu hiện tại (không đổi shape) để không phải sửa logic sử dụng
  tại nơi gọi.

### Session 2026-07-06 (Update 6)

- Feature: Combobox chọn Step trong form Add step / Edit step MUST hỗ trợ vừa chọn step có sẵn
  (nạp từ danh sách EUTR steps — feature 001-eutr-steps) vừa cho phép gõ tự do (free-solo) một tên
  step mới chưa có trong danh sách.
- Change: Khi nhấn Save template (Add hoặc Edit), với mỗi step trong cây có tên được nhập tự do mà
  KHÔNG khớp (không phân biệt hoa/thường, đã trim khoảng trắng) với bất kỳ step nào đang có trong
  danh sách EUTR steps, hệ thống MUST tự động tạo mới bản ghi step đó trong bảng eutr_steps (dùng
  chung API/luồng tạo của feature 001-eutr-steps) TRƯỚC khi lưu eutr_template_details, sau đó dùng
  StepId vừa tạo để tham chiếu cho step đó trong cây.
- Change: Nếu nhiều step trong cùng cây bước của một lần Save dùng chung một tên mới (chưa tồn
  tại), hệ thống chỉ MUST tạo 1 bản ghi step mới duy nhất cho tên đó và dùng chung StepId vừa tạo
  cho tất cả các step trùng tên trong lần Save đó (tránh tạo trùng lặp).
- Change: Step được tự động tạo qua màn hình Add/Edit Template MUST xuất hiện ngay trong danh sách
  màn hình EUTR Steps (001-eutr-steps) sau khi Save thành công, với người tạo/ngày tạo ghi nhận tự
  động như quy trình tạo step thông thường.

### Session 2026-07-07 (Update 7)

- Change: Trường **Alert for** trên màn hình Add/Edit đổi từ textbox nhập tự do sang **combobox**
  chọn một (single-select) danh sách nhóm email lấy từ bảng `compl_group_email` (qua
  `GET /api/group-email`, theo `ComplGroupEmailController`). Combobox hiển thị **Name** của group,
  chỉ nạp các group có `GroupType = Alert (2)` và `IsAddition = false` (loại nhóm bổ sung/không
  hoạt động) — theo đúng pattern combobox "Alert" đã có ở các form khác trong hệ thống (ví dụ
  `ComplianceMasterForm`, `MasterDefaultForm`, dùng `groupEmailType.ALERT`).
- Change: Khi nhấn Save template (Add hoặc Edit), hệ thống MUST lưu **Id** của group đã chọn (KHÔNG
  lưu Name) vào cột `AlertFor` của bảng `eutr_templates`.
- Change: Ở màn hình danh sách chính (grid), cột **Alert for** MUST hiển thị **Name** của group
  tương ứng, tra cứu từ `compl_group_email` dựa trên Id đã lưu trong `AlertFor` — KHÔNG hiển thị
  Id thô.
- Change: Ở màn hình Edit, combobox Alert for MUST tự động chọn sẵn group hiện tại của template
  (tra cứu theo Id đang lưu trong `AlertFor`).

### Session 2026-07-13 (Update 9) — TemplateListPage + 2-bước Create/Edit

- Input: Cập nhật giao diện theo tham chiếu thiết kế `E:\Working\design\eutr` (các file
  `pages/TemplateListPage.jsx`, `pages/TemplateBuilderPage.jsx`).
- Change: Trang danh sách (hiện là `index.jsx`, component `EutrTemplatesPage`) đổi tên/tổ chức
  thành **TemplateListPage**, theo quy ước đặt tên của thiết kế tham chiếu.
- Change: Bộ cột grid GIỮ NGUYÊN như hiện hành — Code, Name, Vendor code, Vendor name, Alert for,
  Is default, Version, Created by, Created date — tức là đã có sẵn cột **Code** và cột
  **Alert for**, và KHÔNG có cột **Status** (khác với bản mockup thiết kế tham chiếu vốn có cột
  Status/Steps). Cột Action GIỮ NGUYÊN chỉ gồm **Edit** và **Delete** — KHÔNG bổ sung Preview
  checklist, Archive, Publish hay Clone (dù bản mockup thiết kế tham chiếu có các thao tác này).
  Đây là xác nhận rõ ràng theo yêu cầu, không phải thay đổi so với hành vi hiện tại.
- Change: Đổi hoàn toàn logic tạo mới template (Add) — tách thành **2 bước** riêng biệt thay vì
  một màn hình duy nhất gồm cả header và cây bước như hiện tại:
  - **Bước 1 — Create (quick create)**: nhấn nút "Create Template" trên thanh công cụ danh sách
    MUST hiển thị một dialog/modal tạo nhanh (không điều hướng sang trang khác), CHỈ chứa 3
    trường: **Name** (bắt buộc), **Alert for** (combobox bắt buộc, nguồn `compl_group_email` như
    cơ chế hiện tại), **Set as default** (checkbox). Trường **Vendor** và **cây bước (step
    tree)** KHÔNG xuất hiện ở dialog này. **Code** vẫn do hệ thống tự sinh nhưng KHÔNG hiển thị
    trong dialog (chưa tồn tại tại thời điểm tạo). Nhấn Save trong dialog MUST tạo một bản ghi
    `eutr_templates` mới (VersionId=1, IsDeleted=0, IsHide=0, VendorCode=null, KHÔNG có step nào
    trong `eutr_template_details`), đóng dialog, và danh sách MUST tự làm mới để hiển thị template
    vừa tạo.
  - **Bước 2 — Edit (xây dựng cây bước)**: nhấn icon **Edit** trên một dòng bất kỳ trong danh sách
    (kể cả template vừa tạo ở Bước 1) MUST chuyển sang màn hình Edit đầy đủ, giữ nguyên layout 2
    cột hiện tại (cột trái: Code readonly, Name, Alert for, **Vendor**, Default, nút Save; cột
    phải: cây bước). Đây là nơi **DUY NHẤT** người dùng thêm/sửa/xóa step trong cây bước — kể cả
    các step **ĐẦU TIÊN** của template (trước đây được thêm ngay trong màn Add gộp chung). Trường
    **Vendor** cũng CHỈ được nhập/sửa ở màn hình Edit này, không còn xuất hiện ở Bước 1.
  - Sau khi Save ở dialog Create (Bước 1), hệ thống KHÔNG tự động điều hướng sang màn hình Edit —
    dialog đóng lại, người dùng quay về danh sách; muốn thêm step (hoặc Vendor), người dùng phải tự
    nhấn Edit trên dòng vừa tạo, đúng theo yêu cầu "lần 2 khi nhấn vào Edit mới thêm sửa steps".
  - Toàn bộ logic đã có ở màn hình Edit (free-solo step combobox, auto-create step trong
    eutr_steps, edit inline step, xóa step đơn lẻ/hàng loạt, cảnh báo Back khi có thay đổi step
    chưa lưu, versioning có điều kiện theo 24 giờ) MUST được giữ nguyên không đổi — chỉ thay đổi
    nơi các thao tác này khả dụng (chỉ ở Edit, không còn ở Create).

### Session 2026-07-13 (Update 10) — Đảo ngược quyết định Update 9 về giao diện danh sách + Edit

- Input: "cập nhật 003-eutr-templates, lấy tính năng đã viết từ TemplateListPageOld sang
  TemplateListPage, ở màn hình index {tmpl.name} hiển thông tin code, {tmpl.description} là name,
  chức năng create template, Delete sẽ hoạt động giống cũ, chức năng Add/Edit sẽ mở form
  TemplateBuilderPage".
- Q: Giữ giao diện DataGrid nhiều cột (như Update 9 đã quyết định) hay đổi sang giao diện Table +
  ô tìm kiếm + chip (Version/Default) + Steps count theo đúng thiết kế tham chiếu
  `TemplateListPage.jsx`? → A: Đổi sang giao diện Table + tìm kiếm + chip của thiết kế tham chiếu.
  Đây là **đảo ngược** quyết định FR-019/FR-020 ở Update 9 (vốn giữ nguyên DataGrid 9 cột).
- Q: Hai hành động mock "Clone" và "Apply to Customer" hiện có trên mỗi dòng của
  `TemplateListPage.jsx` (chưa có backend/yêu cầu tương ứng) xử lý thế nào? → A: Giữ lại 2 icon
  Clone và Apply to Customer trên giao diện nhưng **vô hiệu hóa (disabled)** — chưa gắn chức năng,
  làm placeholder cho tính năng tương lai.
- Change: Component **TemplateListPage** (`compliance-client/src/presentation/pages/eutr-templates/TemplateListPage.jsx`)
  chuyển từ dữ liệu mock (`EUTR_TEMPLATES`, `EUTR_TEMPLATE_DETAILS_MAP`) sang dữ liệu thật, tái sử
  dụng toàn bộ phần "tính năng" (không phải giao diện) đã viết ở **TemplateListPageOld.jsx**: hook
  `useEutrTemplatesData` (fetch/phân trang), `permissionList` theo menu, các use case
  `DeleteEutrTemplatesUseCase`/`DeleteMultiEutrTemplatesUseCase`, và dialog
  `CreateTemplateDialog` (giữ nguyên 3 trường Name/Alert for/Set as default như Update 9 đã quyết
  định — dialog này đã được implement đúng theo Update 9 và KHÔNG đổi).
- Change: Mỗi dòng trong bảng TemplateListPage hiển thị 2 dòng chữ trong ô tên: dòng chữ đậm (vị
  trí trước đây hiển thị `tmpl.name` ở dữ liệu mock) MUST hiển thị **Code** thật của template; dòng
  chữ phụ/caption bên dưới (vị trí trước đây hiển thị `tmpl.description` ở dữ liệu mock) MUST hiển
  thị **Name** thật của template. Đây là ánh xạ dữ liệu thật (Code, Name) vào đúng 2 vị trí hiển thị
  đã có sẵn trong thiết kế tham chiếu.
- Change: Cột **Version** hiển thị `versionId` thật (dạng Chip, ví dụ "V1"). Cột **Default** hiển
  thị Chip "Default" khi `isDefault = 1`, ẩn khi = 0. Cột **Steps** hiển thị số lượng step hiện có
  trong cây bước của template (đếm từ `eutr_template_details` thuộc TemplateId đang hiển thị); nếu
  API danh sách hiện tại chưa trả về số này, giá trị mặc định là 0/để trống cho đến khi backend bổ
  sung — không coi là lỗi chặn tính năng.
- Change: Ô tìm kiếm (search box) trên đầu bảng lọc theo **Code** hoặc **Name** (khớp một phần,
  không phân biệt hoa/thường) — thay thế cho filter/sort per-column của DataGrid cũ (không còn áp
  dụng ở giao diện Table mới).
- Change: **KHÔNG** mang các tính năng sau từ TemplateListPageOld sang giao diện Table mới ở đợt
  này (do giao diện Table không có chỗ tương ứng): nút Import/Export, ẩn/hiện cột
  (column visibility), filter/sort theo từng cột kiểu DataGrid. Các tính năng này coi là hoãn lại
  (deferred), có thể bổ sung sau nếu có yêu cầu riêng.
- Change: Cột Action trên mỗi dòng gồm 4 icon: **Edit** (bút chì, hoạt động — xem chi tiết bên
  dưới), **Clone** (disabled — vô hiệu hóa, chưa gắn chức năng), **Apply to Customer** (disabled —
  vô hiệu hóa, chưa gắn chức năng), **Delete** (hoạt động, xem FR Delete). Nút **Create Template**
  trên toolbar mở `CreateTemplateDialog` giống Update 9 (không đổi).
- Change: Nhấn icon **Delete** trên một dòng MUST hoạt động giống hệt TemplateListPageOld: hiển thị
  `ConfirmDialog` xác nhận nội dung "Are you sure you want to delete the template "{name}"
  ({code})?", nếu xác nhận thì gọi `DeleteEutrTemplatesUseCase`, làm mới danh sách, và hiển thị
  snackbar thành công/lỗi tương ứng.
- Change: TemplateListPage MUST bổ sung checkbox chọn dòng (per-row) để hỗ trợ **xóa hàng loạt**
  giống TemplateListPageOld: chọn nhiều dòng rồi nhấn nút xóa hàng loạt trên toolbar (chỉ hiện khi
  có quyền Delete và có ít nhất 1 dòng được chọn) MUST hiển thị `ConfirmDialog` xác nhận số lượng,
  nếu xác nhận thì gọi `DeleteMultiEutrTemplatesUseCase` với danh sách Id đã chọn, làm mới danh
  sách, xóa lựa chọn, và hiển thị snackbar kết quả — đúng hành vi hiện có ở TemplateListPageOld.
- Change: **Đảo ngược quyết định FR-011/FR-004a ở Update 9** — nhấn icon **Edit** trên một dòng
  (route `/eutr/templates/edit/:id` — route này đã trỏ sẵn tới `TemplateBuilderPage` trong
  `MainRoutes.jsx`) MUST mở **TemplateBuilderPage** (giao diện cây bước dạng `SimpleTreeView` +
  panel cấu hình step bên phải, breadcrumb, toolbar Add Root/Add Child/Move/Delete/Expand/Collapse)
  — KHÔNG còn mở layout 2 cột (form header trái + danh sách step phải) của `EutrTemplatesAddEdit.jsx`
  như Update 9 đã quyết định. `EutrTemplatesAddEdit.jsx` không còn được route nào sử dụng sau thay
  đổi này.
- Change: **TemplateBuilderPage** (hiện đang dùng dữ liệu mock `EUTR_TEMPLATES`,
  `EUTR_TEMPLATE_DETAILS_MAP`, `EUTR_STEPS`) MUST được nối với dữ liệu và luồng nghiệp vụ thật, tái
  sử dụng toàn bộ logic đã có ở `EutrTemplatesAddEdit.jsx` (không viết lại từ đầu): tải template
  theo Id qua `GetEutrTemplatesUseCase`, tải danh sách EUTR steps qua `GetEutrStepsUseCase`, tải
  danh sách group Alert qua `GetAllGroupEmailUseCase` (lọc `GroupType=Alert`, `IsAddition=false`),
  combobox Vendor qua API reference chung (`refType=13`), lưu qua `UpdateEutrTemplatesUseCase` với
  logic versioning có điều kiện 24 giờ (FR-012), tự động tạo step mới khi gõ tự do (FR-007a), cảnh
  báo khi Back mà có thay đổi step chưa lưu (FR-015). Giao diện hiển thị (cây bước dạng tree-view +
  panel cấu hình bên phải, toolbar thao tác) giữ theo đúng bố cục hiện có của
  `TemplateBuilderPage.jsx` — KHÔNG áp dụng lại layout 2 cột form/list của `EutrTemplatesAddEdit.jsx`.
  Panel cấu hình bên phải của TemplateBuilderPage MUST bao gồm đầy đủ các trường header
  (Code readonly, Name, Alert for, Vendor, Set as default) ngoài phần cấu hình step, vì đây là màn
  hình duy nhất người dùng chỉnh sửa các trường này (theo FR-011 cũ).
- Change: Nút **Add Root Group** / **Add Child Step** trên toolbar của TemplateBuilderPage MUST mở
  form thêm step (combobox Step free-solo, RequirementType, TakeFrom) theo đúng logic FR-007/FR-008
  hiện hành — thay cho form chọn `Select` cố định gắn với `EUTR_STEPS` mock hiện tại trong
  `TemplateBuilderPage.jsx`.
- Change: Nút **Create Template** vẫn theo đúng Update 9 (dialog nhanh, không đổi) — không bị ảnh
  hưởng bởi thay đổi ở Update 10 này ngoài việc nó nằm trên giao diện Table mới của TemplateListPage.

### Session 2026-07-13 (Update 11) — Clarify: Search scope

- Q: Ô tìm kiếm Code/Name mới trên TemplateListPage (FR-021a) nên lọc theo dữ liệu nào — server-side
  (gọi lại API danh sách với từ khóa, áp dụng trên toàn bộ dữ liệu, reset về trang 1) hay
  client-side (chỉ lọc trong các dòng đã tải sẵn của trang hiện tại)? → A: Server-side — mở rộng
  API/hook danh sách hiện có (`useEutrTemplatesData`, vốn đã chạy `paginationMode="server"` và
  `filterMode="server"`) với một tham số từ khóa tìm theo Code HOẶC Name; mỗi lần gõ (có debounce)
  gọi lại API và reset về trang đầu tiên, đảm bảo kết quả tìm kiếm đúng trên toàn bộ dữ liệu chứ
  không chỉ trang đang tải.
- Q: Cột **Steps** (FR-021) mâu thuẫn với ghi chú Assumption ở Update 10 (cho phép mặc định
  0/để trống nếu backend chưa hỗ trợ) — số lượng step thật của mỗi template có thuộc phạm vi backend
  của đợt cập nhật này hay có thể để placeholder vô thời hạn? → A: Thuộc phạm vi — API danh sách
  MUST được mở rộng để trả về số lượng step thật (đếm số dòng đang hoạt động trong
  `eutr_template_details` của mỗi TemplateId) cùng với mỗi bản ghi template, không còn là giá trị
  mặc định 0/để trống lâu dài.

### Session 2026-07-13 (Update 12) — Bulk add nhiều step cho Root Group / Child Step

- Input: Cập nhật chức năng Add Root Group và Add Child Step trên **TemplateBuilderPage** để cho
  phép thêm **nhiều step cùng lúc**, theo thiết kế tham chiếu đính kèm — một dialog dạng bảng
  checkbox liệt kê các step master (ví dụ P1..P8) kèm cột Requirement Type và Take From cho từng
  dòng, và footer hiển thị "{N} step available - {M} đã chọn" cùng nút Hủy/Thêm.
- Q: Hiện tại Add Root Group/Add Child Step cho phép gõ tự do (free-solo) để tạo một step hoàn
  toàn mới (tự động tạo bản ghi trong eutr_steps khi Save, theo FR-007a/Update 6-8). Thiết kế mới
  chỉ hiển thị bảng chọn nhiều step có sẵn, không có ô nhập tên mới — vậy khả năng tạo step mới
  bằng free-solo nên xử lý thế nào? → A: Giữ bảng bulk-select làm luồng chính (đúng thiết kế), đồng
  thời bổ sung một khu vực/hàng riêng biệt "Add new step" trong cùng dialog để nhập tự do một tên
  step mới — step mới này được gộp cùng đợt với các step đã tick chọn khi nhấn nút Add ("Thêm")
  chung của dialog, vẫn tự động tạo bản ghi mới trong eutr_steps khi Save template như cơ chế hiện
  hành.
- Change: Dialog **Add Root Group** (mở từ nút "Root Group" trên toolbar, hoặc từ nút "Add Root
  Group" khi cây bước rỗng) và dialog **Add Child Step** (mở từ nút "Child Step" khi đã chọn một
  node cha) đổi từ form thêm-từng-step-một (StepFormRow: 1 combobox free-solo + Requirement Type +
  Take From + 1 nút Add) sang **bảng bulk-select nhiều dòng** — xem FR-027 đến FR-030.
- Change: Chức năng **Edit step** trên một node đã có sẵn trong cây (FR-008b) KHÔNG thay đổi —
  vẫn là form chỉnh sửa từng step một, không áp dụng bulk-select.

### Session 2026-07-13 (Update 13) — Bỏ VendorCode + Apply to Customer + fix Steps count

- Input: "cập nhật 003-eutr-templates bỏ cột VendorCode ở eutr_templates và các logic liên quan.
  Thêm tính năng Apply to customer, khi click vào sẽ mở màn hình mới, giao diện
  `ApplyCustomerPage.jsx`, dữ liệu tải và lưu ở bảng `eutr_template_references` (xem thiết kế ở
  `docs/design/eutr/eutr_db.sql`) dựa theo templateId, vendor name lấy từ API, khi nhấn Add hay
  Edit sẽ hiển thị form popup cho user chọn vendor từ API, nhập From date, to date rồi lưu. Màn
  hình EUTR template, cột Steps vẫn chưa hiển thị count từ eutr_template_details."
- Q: Khi xóa cột VendorCode khỏi bảng eutr_templates, dữ liệu VendorCode hiện có trên các template
  đang active nên xử lý thế nào — backfill sang eutr_template_references hay bỏ qua? → A: Bỏ qua,
  xóa thẳng cột. Dữ liệu VendorCode cũ trên eutr_templates bị mất; người dùng tự apply lại vendor
  cho từng template (nếu cần) qua màn hình Apply to Customer mới.
- Q: Ràng buộc "chỉ 1 template IsDefault=1" trước đây giới hạn theo từng VendorCode (FR-005a). Sau
  khi bỏ VendorCode, ràng buộc Default nên áp dụng thế nào? → A: Default toàn cục — toàn hệ thống
  chỉ tối đa 1 template IsDefault=1 tại một thời điểm (không còn phân biệt theo vendor).
- Q: Khi Apply Template cho Vendor, một Vendor có được map với khoảng thời gian (FromDate-ToDate)
  chồng lấn ở NHIỀU template khác nhau cùng lúc không? → A: Có — chỉ chặn chồng lấn ngày giữa các
  mapping của CÙNG một vendor trong CÙNG một template (giữ đúng logic `hasOverlap` đã có trong
  `ApplyCustomerPage.jsx` hiện tại); KHÔNG chặn một vendor được map chồng lấn ngày ở các template
  khác nhau.
- Change: Loại bỏ hoàn toàn cột `VendorCode` khỏi bảng `eutr_templates` và mọi logic liên quan
  (entity/DTO backend, whitelist sort/filter, tra cứu VendorName qua D365, import/export, combobox
  Vendor trên TemplateBuilderPage/CreateTemplateDialog, cột Vendor code/Vendor name trên bất kỳ
  grid nào) — xem FR-039 đến FR-041.
- Change: Thêm tính năng **Apply to Customer** — icon Apply to Customer trên TemplateListPage
  (trước đây disabled theo FR-026) trở thành hoạt động, điều hướng sang màn hình mới
  **ApplyCustomerPage** (route `/eutr/templates/apply/:id`), quản lý việc gắn template với nhiều
  Vendor theo khoảng thời gian hiệu lực (FromDate-ToDate), lưu ở bảng `eutr_template_references`
  (thiết kế theo `docs/design/eutr/eutr_db.sql`, dựa theo `TemplateId`). Vendor name tra cứu qua
  API reference chung `POST /api/dynamics/reference` với `refType = 13` — cùng nguồn dữ liệu D365
  VendorsV3 đã dùng cho các trường Vendor khác trong feature này. Khi nhấn Add hoặc Edit trên màn
  hình này, hệ thống MUST hiển thị form popup cho phép chọn Vendor (combobox từ API), nhập From
  date, To date rồi lưu — xem FR-032 đến FR-037.
- Bug: Cột **Steps** trên TemplateListPage (FR-021/FR-021c) vẫn chưa hiển thị đúng số lượng step
  thật từ `eutr_template_details`, mặc dù backend (`EutrTemplatesRepository.GetPagedWithVendorNameAsync`)
  đã có subquery `StepsCount` và frontend (`TemplateListPage.jsx`) đã đọc `tmpl.stepsCount`. Cần
  rà soát và sửa toàn bộ đường dẫn dữ liệu (API response thực tế, endpoint đang được gọi, cấu hình
  serialize JSON) để cột Steps hiển thị đúng — xem FR-042.

### Session 2026-07-14 (Update 14) — Import/Export vendor mapping trên ApplyCustomerPage

- Input: "cập nhật 003-eutr-templates chức năng apply to customer, thêm 2 nút Import và Export,
  file template gồm 2 cột là TemplateCode, VendorCode, FromDate, ToDate. Logic giống như Add. Khi
  Export, import sẽ dựa vào liên kết template code để xuất, add dữ liệu, chỉ chấp nhận file excel,
  khi thành công có thông báo dòng nào ok, dòng nào bị lỗi."
- Q: Import trên ApplyCustomerPage (màn hình mở cho 1 template cụ thể qua route
  `/eutr/templates/apply/:id`) chỉ áp dụng cho template đang mở, hay có thể tạo mapping cho nhiều
  template khác nhau cùng lúc (mỗi dòng dùng TemplateCode riêng để xác định template đích, không
  giới hạn theo :id trên URL)? → A: Chỉ áp dụng cho template đang mở. Cột TemplateCode trong file
  dùng để đối chiếu/xác nhận — dòng nào có TemplateCode KHÔNG khớp Code của template đang mở MUST
  bị báo lỗi cho dòng đó, KHÔNG tạo mapping cho template khác.
- Change: Thêm 2 nút **Import** và **Export** trên toolbar của **ApplyCustomerPage**, cạnh nút
  Apply Vendor hiện có — xem FR-043 đến FR-048.
- Change: **Export** MUST tải xuống file Excel (.xlsx) chứa toàn bộ mapping hiện có (đang hiển thị
  trên bảng) của template đang mở, gồm 4 cột: **TemplateCode**, **VendorCode**, **FromDate**,
  **ToDate**. Khi bảng mapping rỗng, Export vẫn MUST trả về file .xlsx chỉ có dòng tiêu đề — file
  này đồng thời đóng vai trò "file template" mẫu cho Import.
- Change: **Import** MUST chỉ chấp nhận file Excel (.xlsx); các định dạng file khác (.csv, .xls,
  .txt, ...) MUST bị từ chối kèm thông báo lỗi rõ ràng, không xử lý bất kỳ dòng nào. Mỗi dòng dữ
  liệu trong file MUST được validate theo đúng logic giống dialog **Add Vendor** hiện hành
  (FR-034/FR-036): TemplateCode phải khớp Code của template đang mở, VendorCode và FromDate bắt
  buộc, ToDate tùy chọn (rỗng = không giới hạn), và không được chồng lấn ngày với mapping khác của
  CÙNG vendor trong CÙNG template (bao gồm cả mapping đã có sẵn trong hệ thống lẫn các dòng khác
  hợp lệ hơn trong CÙNG file Import). Mỗi dòng hợp lệ MUST tạo một bản ghi MỚI trong
  `eutr_template_references` (Import chỉ Add, không Update mapping đã tồn tại).
- Change: Sau khi Import xử lý xong toàn bộ các dòng trong file, hệ thống MUST hiển thị kết quả
  chi tiết theo TỪNG dòng — dòng nào Import thành công (OK) và dòng nào bị lỗi (kèm lý do lỗi cụ
  thể, ví dụ "TemplateCode không khớp", "VendorCode/FromDate trống", "Chồng lấn ngày với mapping
  hiện có") — và bảng danh sách mapping MUST tự làm mới để hiển thị các mapping vừa Import thành
  công.

### Session 2026-07-15 (Update 15) — Clone template + copy eutr_template_references khi lên version

- Input: "cập nhật 003-eutr-templates khi lên version, copy thêm cả dữ liệu eutr_template_references,
  thêm tính năng clone, khi click vào sẽ hiển thị popup clone template từ template đã chọn sang
  template mới, có ô cho user nhập tên template mới, alert for, user đồng ý sẽ copy toàn bộ dữ liệu
  template cũ, tạo ra template mới."
- Change: Khi hệ thống lên version cho một template ở nhánh "trên 24 giờ" của FR-012 (tạo TemplateId
  mới, VersionId+1, ẩn dòng cũ IsHide=1), hệ thống MUST đồng thời sao chép toàn bộ bản ghi hiện có
  trong `eutr_template_references` của template cũ sang TemplateId mới — trước đây chỉ
  `eutr_template_details` (cây bước) được sao chép, khiến các mapping vendor (Apply to Customer) bị
  "mất" khỏi bản ghi đang hiển thị sau khi lên version. Xem FR-049.
- Change: Thêm tính năng **Clone template** — icon Clone trên TemplateListPage (trước đây disabled
  theo FR-026) trở thành hoạt động. Nhấn icon Clone trên một dòng MUST mở dialog popup **Clone
  Template**, lấy template của dòng đó làm nguồn. Dialog gồm: thông tin template nguồn (chỉ đọc),
  ô nhập **New template name** (bắt buộc), combobox **Alert for** (bắt buộc, cùng nguồn dữ liệu
  `compl_group_email` GroupType=Alert/IsAddition=false như dialog Create Template hiện hành).
- Change: Khi người dùng nhập đủ Name + Alert for hợp lệ và nhấn nút xác nhận Clone, hệ thống MUST
  hiển thị một hộp thoại cảnh báo xác nhận (alert) nêu rõ hành động sắp sao chép toàn bộ dữ liệu từ
  template nguồn; chỉ khi người dùng đồng ý ở hộp thoại này, hệ thống mới thực sự tạo template mới
  (Code tự sinh, VersionId=1, IsDefault=0) và sao chép **toàn bộ** cây bước
  (`eutr_template_details`) lẫn mapping vendor (`eutr_template_references`) từ template nguồn sang
  template mới. Xem FR-050 đến FR-054.
- Q: "Toàn bộ dữ liệu template cũ" khi Clone có bao gồm cả mapping vendor
  (`eutr_template_references`) hay chỉ cây bước (`eutr_template_details`)? → A: Bao gồm cả hai —
  vì yêu cầu gốc nhắc đến việc sao chép `eutr_template_references` ngay trong cùng câu mô tả tính
  năng Clone, nên Clone MUST sao chép đầy đủ cả step tree lẫn vendor mapping để template mới hoạt
  động tương đương template nguồn ngay sau khi tạo.
- Q: Template mới tạo ra từ Clone có tự động là Default (IsDefault=1) nếu template nguồn đang là
  Default không? → A: Không — template Clone luôn có IsDefault=0 bất kể template nguồn, để tránh vi
  phạm ràng buộc toàn cục "chỉ tối đa 1 template Default" (FR-040) mà không cần logic bỏ cờ default
  tự động phức tạp. Người dùng tự đánh dấu Default cho template mới sau, nếu cần, qua màn hình Edit.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem danh sách EUTR Templates (Priority: P1)

Người dùng vào mục **EUTR system > EUTR templates** từ thanh điều hướng trái và thấy màn hình
**TemplateListPage** dạng bảng (Table) + ô tìm kiếm, theo đúng thiết kế tham chiếu
`TemplateListPage.jsx` (Update 10 — đảo ngược quyết định giữ DataGrid ở Update 9). Mỗi dòng hiển
thị: **Code** (chữ đậm, dòng trên), **Name** (chữ phụ/caption, dòng dưới), Chip **Version**
(vd "V1"), Chip **Default** (chỉ hiện khi IsDefault=1), số lượng **Steps** trong cây bước, và cột
**Actions** gồm 4 icon: Edit (hoạt động), Clone (disabled), Apply to Customer (disabled), Delete
(hoạt động). Ô tìm kiếm lọc theo Code hoặc Name (khớp một phần, không phân biệt hoa/thường). Người
dùng có thể chuyển trang khi danh sách dài.

**Why this priority**: Đây là giá trị cốt lõi — xem và tra cứu danh sách template hiện có là thao
tác đầu tiên người dùng cần trước khi thực hiện bất kỳ hành động nào khác.

**Independent Test**: Mở màn hình, xác nhận bảng tải đúng dữ liệu thật (không phải mock) với Code
hiển thị ở dòng đậm và Name ở dòng phụ, gõ vào ô tìm kiếm và xác nhận danh sách lọc đúng theo
Code/Name, chuyển trang và thấy trang kế tiếp.

**Acceptance Scenarios**:

1. **Given** đang ở mục EUTR system, **When** chọn "EUTR templates" ở thanh trái, **Then** thấy
   breadcrumb/tiêu đề "EUTR Templates" và bảng dạng Table với ô tìm kiếm phía trên.
2. **Given** danh sách có template với Code="Templates-001" và Name="ABC", **When** bảng hiển
   thị, **Then** dòng chữ đậm của ô tên hiển thị "Templates-001" và dòng chữ phụ bên dưới hiển thị
   "ABC".
3. **Given** đang ở danh sách, **When** gõ một phần Code hoặc Name vào ô tìm kiếm, **Then** hệ
   thống gọi lại API danh sách với từ khóa đó (server-side), reset về trang đầu tiên, và bảng chỉ
   hiển thị các template có Code hoặc Name khớp một phần (không phân biệt hoa/thường) trên **toàn
   bộ dữ liệu** — bao gồm cả các bản ghi nằm ở những trang khác trước khi tìm kiếm.
4. **Given** danh sách vượt quá một trang, **When** chọn số trang khác, **Then** bảng hiển thị
   các bản ghi của trang đó.
5. **Given** một dòng template, **When** xem cột Actions, **Then** thấy 4 icon Edit, Clone, Apply
   to Customer, Delete — trong đó Clone và Apply to Customer ở trạng thái disabled (không nhấn
   được), Edit và Delete hoạt động bình thường.

---

### User Story 2 - Tạo nhanh template mới (quick create) (Priority: P1)

Người dùng nhấn **Create Template** trên thanh công cụ của danh sách (TemplateListPage), hệ thống
hiển thị một **dialog tạo nhanh** (không điều hướng sang trang khác) chỉ gồm 3 trường: **Name**
(bắt buộc), **Alert for** (combobox bắt buộc, chọn một group từ danh sách nhóm email cảnh báo
`compl_group_email`, GroupType=Alert, IsAddition=false — hiển thị Name, lưu Id), và **Set as
default** (checkbox). Dialog này KHÔNG có trường Vendor và KHÔNG có cây bước (step tree) — người
dùng chỉ thiết lập thông tin cơ bản của template. Trường Code KHÔNG hiển thị trong dialog vì do hệ
thống tự sinh (prefix + số tăng dần, ví dụ Templates-001) tại thời điểm Save. Khi nhấn Save trong
dialog, hệ thống tạo một bản ghi template mới (VersionId=1, không có Vendor, không có step nào),
đóng dialog và danh sách tự làm mới để hiển thị template vừa tạo. Việc thêm Vendor và xây dựng cây
bước cho template này được thực hiện riêng, sau đó, thông qua màn hình Edit (xem User Story 3).

**Why this priority**: Tạo nhanh một template là bước khởi tạo cần thiết đầu tiên trước khi có thể
gắn Vendor và xây dựng cây bước — tách biệt bước này giúp người dùng tạo template tối thiểu chỉ
trong vài giây mà không bị chặn bởi việc phải cấu hình cây bước ngay lập tức.

**Independent Test**: Nhấn Create Template, xác nhận dialog chỉ hiện Name/Alert for/Set as default
(không có Vendor, không có cây bước), để trống Name hoặc không chọn Alert for thì không Save được,
nhập đầy đủ và Save, xác nhận dialog đóng lại và template mới xuất hiện ngay trong danh sách với
Code tự sinh đúng định dạng, Vendor trống và 0 step.

**Acceptance Scenarios**:

1. **Given** đang ở danh sách template (TemplateListPage), **When** nhấn **Create Template**,
   **Then** hệ thống hiển thị một dialog/modal (không chuyển trang) chỉ gồm 3 trường: Name, Alert
   for (combobox), Set as default (checkbox) — KHÔNG có trường Vendor, KHÔNG có cây bước.
2. **Given** dialog Create đang mở, **When** mở combobox Alert for, **Then** hệ thống gọi API
   `GET /api/group-email` và hiển thị danh sách Name của các group có GroupType=Alert(2) và
   IsAddition=false.
3. **Given** dialog Create đang mở, **When** để trống Name hoặc không chọn Alert for rồi nhấn Save,
   **Then** hệ thống báo lỗi và không tạo bản ghi nào.
4. **Given** đã nhập Name, chọn Alert for, tick Set as default, **When** nhấn Save, **Then** hệ
   thống tạo một bản ghi template mới với Code tự sinh, VersionId=1, VendorCode=null, không có step
   nào trong eutr_template_details, cột AlertFor lưu Id của group đã chọn, dialog đóng lại và danh
   sách tự làm mới hiển thị template vừa tạo.
5. **Given** template vừa được tạo ở dialog Create, **When** xem lại danh sách ngay sau đó, **Then**
   hệ thống KHÔNG tự động điều hướng sang màn hình Edit — người dùng phải tự nhấn Edit trên dòng đó
   để thêm Vendor hoặc xây dựng cây bước.
6. **Given** dialog Create đang mở với dữ liệu đã nhập một phần, **When** người dùng đóng dialog mà
   không nhấn Save (hủy), **Then** hệ thống KHÔNG tạo bản ghi nào và danh sách giữ nguyên.

---

### User Story 3 - Chỉnh sửa template (Priority: P2)

Người dùng nhấn **Edit** trên một dòng trong danh sách (bao gồm cả template vừa được tạo qua
dialog quick-create ở User Story 2, khi đó cây bước đang rỗng và Vendor đang trống), hệ thống điều
hướng sang route `/eutr/templates/edit/:id`, mở màn hình **TemplateBuilderPage** (Update 10 — đảo
ngược quyết định Update 9 vốn mở layout 2 cột dạng form/list của `EutrTemplatesAddEdit.jsx`):
giao diện cây bước (tree-view) bên trái + panel cấu hình bên phải, panel cấu hình bao gồm cả các
trường header (Code readonly, Name, Alert for, Vendor, Set as default) khi chưa chọn step nào,
cùng breadcrumb/toolbar Add Root/Add Child/Move/Delete/Expand/Collapse. Dữ liệu template hiện tại
được tải sẵn từ hệ thống thật (không còn mock). Đây là màn hình **DUY NHẤT** nơi người dùng thiết
lập/thay đổi Vendor và xây dựng/chỉnh sửa cây bước — kể cả việc thêm các step **ĐẦU TIÊN** cho một
template mới tạo (không còn thực hiện ngay lúc Create như trước đây). Combobox Vendor MUST gọi API
`POST /api/dynamics/reference` với `refType = 13` và hiển thị vendor hiện tại được chọn sẵn (nếu
có). Combobox Alert for MUST gọi API `GET /api/group-email` và hiển thị group hiện tại (tra cứu
theo Id đang lưu trong AlertFor) được chọn sẵn. Người dùng có thể chỉnh sửa header (Name, Alert
for, Vendor, Default — Code là readonly), thêm step vào cây bước theo cơ chế **bulk-select** (Update
12): nhấn nút **Root Group** (hoặc "Add Root Group" khi cây rỗng) hoặc **Child Step** (khi đã chọn
một node cha) MUST mở dialog dạng bảng liệt kê các step master khả dụng kèm checkbox chọn dòng, cột
Requirement Type và Take From có thể chỉnh cho từng dòng đã tick, cùng khu vực "Add new step" để
nhập tự do một tên step hoàn toàn mới chưa có trong danh sách; nhấn nút Add ("Thêm") MUST thêm đồng
thời toàn bộ step đã chọn/đã nhập vào cây cùng một lúc, xem FR-027 đến FR-030. Người dùng cũng có
thể xóa step khỏi cây (FR-008a) và **chỉnh sửa step đã
có** (đổi step, RequirementType, TakeFrom) từng step một qua icon Edit trên dòng step — không đổi
bởi Update 12 (xem FR-008b, FR-031). Khi nhấn Save, hệ thống áp
dụng logic versioning có điều kiện dựa trên tuổi của bản ghi đang sửa (CreatedDate):
- Nếu bản ghi đang sửa được tạo **cách đây TRÊN 24 giờ**: hệ thống **không sửa trực tiếp dòng
  cũ** mà tạo phiên bản mới — tạo dòng mới trong eutr_templates với VersionId tăng 1, lưu toàn bộ
  cây bước hiện tại (bao gồm step đã chỉnh sửa) vào eutr_template_details với ParentId chính xác,
  và đánh dấu dòng cũ là IsHide = 1.
- Nếu bản ghi đang sửa được tạo **cách đây DƯỚI 24 giờ**: hệ thống **cập nhật đè lên dòng hiện
  tại** — không tạo dòng mới, không tăng VersionId, không set IsHide trên dòng cũ. Toàn bộ
  header và step tree được ghi đè trực tiếp lên bản ghi hiện có.
Grid chỉ hiển thị phiên bản mới nhất (IsHide = 0).

**Why this priority**: Chỉnh sửa template là nhu cầu tất yếu khi quy trình EUTR thay đổi, và cơ
chế versioning giúp giữ lại lịch sử thay đổi để truy vết — đồng thời tránh tạo quá nhiều version
rác khi người dùng sửa nhanh liên tiếp trong thời gian ngắn sau khi tạo.

**Independent Test**: Nhấn Edit trên một template, xác nhận Vendor hiển thị đúng từ API reference
(refType=13) và Alert for hiển thị đúng group hiện tại (từ `GET /api/group-email`), thay đổi step
(edit step đã có + thêm/xóa), lưu, và xác nhận: nếu template được tạo trên 24h, dòng cũ
bị ẩn (IsHide=1) và dòng mới hiển thị với VersionId cao hơn; nếu dưới 24h, dòng hiện tại được cập
nhật trực tiếp mà không tạo dòng mới. Cây bước đúng với thay đổi, ParentId đúng trong DB.

**Acceptance Scenarios**:

1. **Given** template "T001" đang ở VersionId=1 và được tạo cách đây TRÊN 24 giờ, **When** nhấn
   Edit, chỉnh sửa rồi Save, **Then** hệ thống tạo dòng mới với cùng Code nhưng VersionId=2, dòng
   cũ cập nhật IsHide=1.
1a. **Given** template "T002" đang ở VersionId=1 và được tạo cách đây DƯỚI 24 giờ, **When** nhấn
   Edit, chỉnh sửa Name và Save, **Then** hệ thống cập nhật đè lên dòng hiện tại: cùng Id, cùng
   VersionId=1, CreatedDate không đổi, Name mới được lưu, không có dòng mới nào được tạo.
1b. **Given** template "T002" vừa được cập nhật đè (VersionId vẫn = 1, dưới 24h kể từ tạo),
   **When** người dùng Edit lần nữa ngay sau đó (vẫn dưới 24h kể từ CreatedDate gốc) và Save,
   **Then** hệ thống tiếp tục cập nhật đè lên cùng dòng đó (không tạo version mới).
2. **Given** đang edit template (trên 24h), **When** thêm một step con mới vào cây, lưu, **Then**
   dòng mới chứa toàn bộ step cũ cộng thêm step mới trong eutr_template_details với ParentId
   chính xác.
3. **Given** đang edit template (trên 24h), **When** xóa một step khỏi cây, lưu, **Then** dòng
   mới chứa cây bước đã bỏ step đó, dòng cũ vẫn giữ nguyên dữ liệu (IsHide=1).
4. **Given** template có nhiều version (1, 2, 3), **When** xem grid, **Then** chỉ hiển thị
   version mới nhất (IsHide=0).
5. **Given** đang edit template có step "Forest" với Required + PO, **When** nhấn icon Edit trên
   step "Forest" và đổi thành Optional + Upload manual rồi Save template, **Then** thay đổi được
   áp dụng theo đúng logic versioning (dòng mới nếu trên 24h, đè lên dòng hiện tại nếu dưới 24h)
   với step "Forest" có RequirementType=0 (Optional) và TakeFrom=1 (Upload manual).
6. **Given** đang edit template, **When** nhấn Edit trên một step và đổi sang step khác từ
   combobox, rồi Save template, **Then** StepId mới thay cho StepId cũ được lưu đúng theo logic
   versioning hiện hành (dòng mới hoặc đè lên dòng hiện tại tùy tuổi bản ghi).
7. **Given** đang mở màn hình Edit, **When** mở combobox Vendor, **Then** hệ thống gọi API
   `POST /api/dynamics/reference` với `refType = 13` và hiển thị danh sách vendor, với vendor
   hiện tại được chọn sẵn.
7a. **Given** đang mở màn hình Edit, **When** mở combobox Alert for, **Then** hệ thống gọi API
   `GET /api/group-email` và hiển thị danh sách group (GroupType=Alert(2), IsAddition=false), với
   group hiện tại của template (theo Id lưu trong AlertFor) được chọn sẵn.
7b. **Given** đang edit template, **When** đổi Alert for sang group khác rồi Save, **Then** Id
   của group mới được lưu vào AlertFor theo đúng logic versioning hiện hành (dòng mới nếu trên
   24h, đè lên dòng hiện tại nếu dưới 24h).
8. **Given** đang edit template, **When** thêm một step mới bằng cách gõ tự do một tên chưa có
   trong danh sách EUTR steps rồi Save step, sau đó Save template, **Then** hệ thống tạo bản ghi
   step mới trong eutr_steps và lưu step đó vào eutr_template_details với StepId vừa tạo, theo
   đúng logic versioning hiện hành (dòng mới nếu trên 24h, đè lên dòng hiện tại nếu dưới 24h).
9. **Given** một template vừa được tạo qua dialog quick-create (0 step, Vendor trống), **When**
   nhấn Edit trên dòng đó, **Then** màn hình TemplateBuilderPage hiển thị cây bước rỗng (trạng
   thái "chưa có step nào") và panel cấu hình có combobox Vendor chưa chọn giá trị nào, cho phép
   người dùng thêm step đầu tiên và chọn Vendor.
10. **Given** đang ở màn hình Edit của một template chưa có Vendor, **When** chọn một vendor từ
    combobox Vendor rồi Save, **Then** cột VendorCode của template được cập nhật theo đúng logic
    versioning hiện hành (dòng mới nếu trên 24h, đè lên dòng hiện tại nếu dưới 24h).
11. **Given** đang ở màn hình Edit, cây bước đang rỗng, **When** nhấn nút **Root Group**, **Then**
    hệ thống mở dialog dạng bảng liệt kê toàn bộ step master khả dụng (mỗi dòng kèm checkbox,
    Requirement Type, Take From) cùng khu vực "Add new step", và footer hiển thị đúng
    "{N} step available - 0 đã chọn" với nút Add ở trạng thái disabled.
12. **Given** dialog bulk-select Root Group đang mở, **When** tick chọn 5 step khác nhau, chỉnh
    Requirement Type/Take From cho 2 trong số đó, rồi nhấn nút **Add** ("Thêm"), **Then** cả 5
    step MUST xuất hiện ngay trong cây bước dưới dạng step gốc (ParentId = 0), mỗi step giữ đúng
    Requirement Type/Take From đã cấu hình cho dòng tương ứng, và dialog đóng lại.
13. **Given** đã chọn một step cha trong cây, **When** nhấn nút **Child Step**, tick chọn 2 step
    master và nhập thêm 1 tên step mới ở khu vực "Add new step", rồi nhấn Add, **Then** cả 3 step
    (2 step có sẵn + 1 step tự nhập) MUST được thêm làm con của step cha đang chọn (ParentId = Id
    step cha), và khi Save template, step tự nhập MUST được tự động tạo bản ghi mới trong
    eutr_steps theo đúng FR-007a.
14. **Given** dialog bulk-select đang mở với một số step đã tick và một step đã nhập ở khu vực
    "Add new step", **When** người dùng nhấn Cancel/đóng dialog mà KHÔNG nhấn Add, **Then** không
    có step nào được thêm vào cây bước, toàn bộ lựa chọn/nhập tạm trong dialog bị hủy.
15. **Given** một step master đã là con trực tiếp của step cha đang chọn, **When** mở dialog Add
    Child Step cho đúng step cha đó, **Then** step đã có mặt đó KHÔNG xuất hiện trong danh sách
    "step available" của bảng bulk-select (tránh thêm trùng lặp vào cùng cấp cha).

---

### User Story 4 - Xóa template (soft delete) (Priority: P2)

Người dùng nhấn icon **Delete** trên một dòng trong TemplateListPage, xác nhận qua `ConfirmDialog`
(nội dung nêu rõ Name và Code của template), và template biến mất khỏi danh sách. Hệ thống **không
xóa dữ liệu thật** mà chỉ cập nhật cờ IsDeleted = 1. Người dùng cũng có thể tick chọn nhiều dòng
(checkbox per-row) rồi nhấn nút xóa hàng loạt trên toolbar để xóa nhiều template cùng lúc, xác nhận
qua `ConfirmDialog` riêng nêu rõ số lượng đã chọn — hành vi giống hệt TemplateListPageOld. Dữ liệu
vẫn tồn tại trong database để truy vết.

**Why this priority**: Dọn dẹp template không còn dùng là cần thiết nhưng ít rủi ro nếu triển
khai sau tạo và xem. Soft delete đảm bảo không mất dữ liệu.

**Independent Test**: Nhấn Delete trên một dòng, xác nhận, kiểm tra dòng biến mất khỏi danh sách
nhưng dữ liệu vẫn còn trong database với IsDeleted=1. Chọn nhiều dòng bằng checkbox, nhấn xóa hàng
loạt, xác nhận, kiểm tra toàn bộ các dòng đã chọn biến mất khỏi danh sách.

**Acceptance Scenarios**:

1. **Given** một template tồn tại, **When** nhấn icon Delete và xác nhận, **Then** template biến
   mất khỏi danh sách, dữ liệu trong database được cập nhật IsDeleted=1 (không xóa thật), và
   snackbar hiển thị thông báo thành công.
2. **Given** hộp thoại xác nhận xóa hiện ra, **When** người dùng hủy, **Then** không có template
   nào bị thay đổi.
3. **Given** template đã bị soft delete (IsDeleted=1), **When** tải danh sách, **Then** template
   đó không xuất hiện trong danh sách.
4. **Given** người dùng tick chọn 2 hoặc nhiều dòng bằng checkbox, **When** nhấn nút xóa hàng loạt
   trên toolbar và xác nhận, **Then** toàn bộ các template đã chọn được cập nhật IsDeleted=1, biến
   mất khỏi danh sách, lựa chọn được xóa, và snackbar hiển thị thông báo thành công.
5. **Given** chưa tick chọn dòng nào, **When** xem toolbar, **Then** nút xóa hàng loạt ở trạng
   thái disabled (không nhấn được).

---

### User Story 5 - Import templates (Priority: P3) — Hoãn lại (Deferred, Update 10)

> **Lưu ý (Update 10)**: Nút Import/Export **KHÔNG** xuất hiện trên giao diện Table mới của
> TemplateListPage (không có vị trí tương ứng trong thiết kế tham chiếu). User Story này giữ lại
> trong tài liệu để tham khảo hành vi đã có ở TemplateListPageOld, nhưng KHÔNG thuộc phạm vi triển
> khai của đợt cập nhật này; có thể bổ sung lại sau nếu có yêu cầu riêng.

Người dùng nhấn **Import** trên toolbar, chọn file, và hệ thống đọc dữ liệu từ file để tạo
các template mới. Sau khi import xong, hệ thống hiển thị kết quả (số bản ghi thành công/thất bại).

**Why this priority**: Import là tiện ích bổ sung cho việc tạo hàng loạt, không ảnh hưởng đến
luồng nghiệp vụ chính (tạo thủ công từng template).

**Independent Test**: Nhấn Import, chọn file Excel hợp lệ, và xác nhận các template mới xuất hiện
trong danh sách.

**Acceptance Scenarios**:

1. **Given** đang ở danh sách, **When** nhấn Import và chọn file hợp lệ, **Then** hệ thống tạo
   các template từ file và hiển thị kết quả import.
2. **Given** file import chứa dữ liệu không hợp lệ (thiếu Name), **When** import, **Then** hệ
   thống báo lỗi chi tiết cho từng dòng và không tạo bản ghi lỗi. Code được hệ thống tự sinh
   cho mỗi bản ghi import.

---

### User Story 6 - Apply template cho Vendor (Apply to Customer) (Priority: P2, Update 13)

Người dùng nhấn icon **Apply to Customer** trên một dòng của TemplateListPage (không còn disabled
— xem FR-032), hệ thống điều hướng sang màn hình mới **ApplyCustomerPage** (route
`/eutr/templates/apply/:id`), hiển thị breadcrumb và bảng danh sách các Vendor đã được apply cho
template đang xem, tải từ bảng `eutr_template_references` lọc theo `TemplateId`. Mỗi dòng hiển thị
Vendor (mã + tên, tên tra cứu qua API reference chung `POST /api/dynamics/reference` refType=13),
From date, To date (hiển thị "∞" nếu không giới hạn), và cột Action (Edit, Delete). Nhấn nút
**Apply Vendor** trên toolbar hoặc icon **Edit** trên một dòng MỞ form popup (dialog) cho phép chọn
Vendor từ combobox (API reference refType=13), nhập From date (bắt buộc), To date (tùy chọn), rồi
Lưu. Icon **Delete** xóa thật (hard delete) bản ghi mapping sau khi xác nhận, vì bảng
`eutr_template_references` không có cờ soft-delete. **(Update 14)** Toolbar còn có 2 nút **Import**
và **Export**: Export tải file Excel (.xlsx, 4 cột TemplateCode/VendorCode/FromDate/ToDate) chứa
toàn bộ mapping hiện có của template đang mở; Import chỉ chấp nhận file .xlsx theo đúng 4 cột này,
mỗi dòng được validate và tạo mapping mới giống hệt logic Add (FR-034/FR-036), sau đó hiển thị kết
quả từng dòng (OK/lỗi) và làm mới bảng.

**Why this priority**: Đây là bước tiếp theo sau khi template đã được xây dựng hoàn chỉnh (cây
bước) — gắn template với vendor cụ thể theo khoảng thời gian hiệu lực là điều kiện để checklist
EUTR áp dụng đúng cho từng vendor, nhưng không chặn các luồng CRUD template cơ bản nên ở priority
P2 giống các tính năng chỉnh sửa/quản lý khác.

**Independent Test**: Nhấn icon Apply to Customer trên một template, xác nhận điều hướng đến
ApplyCustomerPage với dữ liệu mapping hiện có (nếu có) tải đúng theo TemplateId; nhấn Add, chọn
Vendor + nhập From/To date rồi Save, xác nhận mapping mới xuất hiện trong bảng; nhấn Edit trên một
mapping, đổi Vendor hoặc ngày rồi Save, xác nhận cập nhật đúng; nhấn Delete, xác nhận, kiểm tra
mapping biến mất và bị xóa thật khỏi database.

**Acceptance Scenarios**:

1. **Given** đang ở TemplateListPage, **When** nhấn icon **Apply to Customer** trên một dòng,
   **Then** hệ thống điều hướng đến route `/eutr/templates/apply/:id` (id = TemplateId của dòng
   đó), mở màn hình ApplyCustomerPage.
2. **Given** template đang xem đã có 2 mapping vendor có sẵn trong `eutr_template_references`,
   **When** ApplyCustomerPage tải xong, **Then** bảng hiển thị đúng 2 dòng, mỗi dòng hiển thị đúng
   Vendor (tra cứu tên qua refType=13), From date, To date.
3. **Given** đang ở ApplyCustomerPage, **When** nhấn nút **Apply Vendor**, **Then** hệ thống mở
   dialog popup gồm combobox Vendor (bắt buộc, nạp qua API reference refType=13), From date (bắt
   buộc), To date (tùy chọn).
4. **Given** dialog Apply Vendor đang mở, **When** để trống Vendor hoặc From date rồi nhấn Save,
   **Then** hệ thống báo lỗi và không tạo bản ghi nào.
5. **Given** đã chọn Vendor, nhập From date hợp lệ, **When** nhấn Save, **Then** hệ thống tạo một
   bản ghi mới trong `eutr_template_references` (TemplateId từ route, VendorCode đã chọn, FromDate,
   ToDate), dialog đóng lại và bảng tự làm mới hiển thị mapping vừa tạo.
6. **Given** một mapping đã tồn tại cho Vendor "V001" từ 01/01/2026 đến 30/06/2026 trong template
   đang xem, **When** thêm mapping mới cho CÙNG Vendor "V001" với khoảng ngày chồng lấn (ví dụ
   01/05/2026 - 01/08/2026), **Then** hệ thống báo lỗi chồng lấn và không cho Save.
7. **Given** Vendor "V001" đã có mapping active ở template A, **When** apply Vendor "V001" cho một
   template B khác với khoảng ngày chồng lấn, **Then** hệ thống MUST cho phép Save bình thường
   (không chặn chồng lấn giữa các template khác nhau).
8. **Given** một mapping đã có, **When** nhấn icon Edit trên dòng đó, **Then** dialog popup mở lại
   với Vendor/From date/To date hiện tại được nạp sẵn; sửa và Save cập nhật đúng bản ghi đó
   (UpdatedBy/UpdatedDate thay đổi).
9. **Given** một mapping đã có, **When** nhấn icon Delete và xác nhận, **Then** bản ghi bị xóa thật
   (hard delete) khỏi `eutr_template_references` và biến mất khỏi bảng.
10. **Given** hộp thoại xác nhận xóa mapping hiện ra, **When** người dùng hủy, **Then** không có
    mapping nào bị xóa.
11. **Given** template đang xem có 3 mapping, **When** nhấn nút **Export**, **Then** hệ thống tải
    xuống một file .xlsx gồm đúng 4 cột TemplateCode, VendorCode, FromDate, ToDate với 3 dòng dữ
    liệu khớp chính xác 3 mapping đang hiển thị.
12. **Given** template đang xem chưa có mapping nào, **When** nhấn **Export**, **Then** hệ thống
    vẫn tải xuống file .xlsx chỉ có dòng tiêu đề (không có dòng dữ liệu).
13. **Given** đang ở ApplyCustomerPage, **When** nhấn **Import** và chọn một file KHÔNG phải .xlsx
    (ví dụ .csv, .txt), **Then** hệ thống báo lỗi định dạng file không hợp lệ và KHÔNG xử lý bất kỳ
    dòng dữ liệu nào.
14. **Given** file Import .xlsx hợp lệ có 5 dòng: 3 dòng đúng TemplateCode của template đang mở với
    VendorCode/FromDate hợp lệ và không chồng lấn, 1 dòng có TemplateCode của template KHÁC, 1 dòng
    thiếu VendorCode, **When** Import, **Then** hệ thống tạo đúng 3 mapping mới từ 3 dòng hợp lệ,
    hiển thị kết quả rõ ràng cho từng dòng (3 dòng OK, 1 dòng lỗi "TemplateCode không khớp", 1 dòng
    lỗi "thiếu VendorCode"), và bảng mapping tự làm mới hiển thị 3 mapping vừa thêm.
15. **Given** file Import chứa 2 dòng cùng VendorCode với khoảng FromDate-ToDate chồng lấn nhau
    (trong cùng file, cùng template đang mở), **When** Import, **Then** dòng đầu tiên hợp lệ được
    tạo thành công (OK), dòng thứ hai bị báo lỗi chồng lấn ngày (so với mapping vừa tạo từ dòng đầu
    hoặc mapping đã có sẵn) và không được tạo.
16. **Given** file Import .xlsx hợp lệ về định dạng nhưng không có dòng dữ liệu nào (chỉ có dòng
    tiêu đề), **When** Import, **Then** hệ thống hiển thị thông báo không có dòng nào để xử lý,
    không tạo mapping nào và không báo lỗi hệ thống.

---

### User Story 7 - Clone template (Priority: P2, Update 15)

Người dùng nhấn icon **Clone** trên một dòng của TemplateListPage (không còn disabled — xem
FR-050), hệ thống mở dialog popup **Clone Template** hiển thị thông tin template nguồn (Code/Name,
chỉ đọc), kèm ô nhập **New template name** (bắt buộc) và combobox **Alert for** (bắt buộc, cùng
nguồn `compl_group_email` như dialog Create Template). Sau khi nhập đủ và nhấn nút Clone/Confirm,
hệ thống hiển thị hộp thoại xác nhận cảnh báo sắp sao chép toàn bộ dữ liệu; khi người dùng đồng ý,
hệ thống tạo một template hoàn toàn mới (Code tự sinh, VersionId=1, IsDefault=0) và sao chép toàn
bộ cây bước (`eutr_template_details`) cùng toàn bộ mapping vendor (`eutr_template_references`) từ
template nguồn sang template mới. Dialog đóng lại, danh sách tự làm mới hiển thị template vừa
clone.

**Why this priority**: Clone giúp người dùng tạo nhanh một template tương tự một template đã có
sẵn (giữ nguyên cây bước phức tạp và các mapping vendor) mà không phải xây dựng lại từ đầu — tăng
tốc độ tạo template mới đáng kể so với việc tạo thủ công qua dialog Create Template rồi thêm lại
từng step/vendor.

**Independent Test**: Nhấn Clone trên một template đã có sẵn step và vendor mapping, nhập tên mới +
Alert for, xác nhận ở hộp thoại cảnh báo, kiểm tra template mới xuất hiện trong danh sách với Code
riêng, cây bước và mapping vendor giống hệt template nguồn.

**Acceptance Scenarios**:

1. **Given** đang ở TemplateListPage, **When** nhấn icon **Clone** trên một dòng, **Then** hệ
   thống mở dialog popup Clone Template hiển thị thông tin template nguồn (chỉ đọc) cùng ô New
   template name và combobox Alert for (đều để trống ban đầu).
2. **Given** dialog Clone đang mở, **When** để trống New template name hoặc không chọn Alert for
   rồi nhấn Clone/Confirm, **Then** hệ thống báo lỗi validate và KHÔNG hiển thị hộp thoại xác nhận,
   KHÔNG tạo bản ghi nào.
3. **Given** đã nhập New template name và chọn Alert for hợp lệ, **When** nhấn Clone/Confirm,
   **Then** hệ thống hiển thị hộp thoại cảnh báo xác nhận nêu rõ sắp sao chép toàn bộ dữ liệu từ
   template nguồn sang template mới.
4. **Given** hộp thoại cảnh báo xác nhận đang hiện, **When** người dùng hủy, **Then** KHÔNG có
   template mới nào được tạo, dialog Clone vẫn giữ nguyên dữ liệu đã nhập (hoặc đóng lại tùy hành vi
   ConfirmDialog chuẩn của hệ thống), không có dữ liệu nào bị thay đổi.
5. **Given** hộp thoại cảnh báo xác nhận đang hiện, **When** người dùng đồng ý, **Then** hệ thống
   tạo một bản ghi mới trong eutr_templates (Code tự sinh, Name/AlertFor theo nhập liệu, VersionId=1,
   IsDefault=0, IsDeleted=0, IsHide=0), sao chép toàn bộ step trong eutr_template_details của template
   nguồn sang TemplateId mới (giữ nguyên StepId, RequirementType, TakeFrom, DisplayOrder, cấu trúc
   ParentId), sao chép toàn bộ mapping trong eutr_template_references của template nguồn sang
   TemplateId mới (giữ nguyên VendorCode/FromDate/ToDate), đóng dialog, danh sách tự làm mới hiển
   thị template mới, và snackbar thông báo thành công.
6. **Given** template nguồn có 5 step (3 cấp lồng nhau) và 2 mapping vendor, **When** Clone thành
   công, **Then** template mới có đúng 5 step với cấu trúc cha-con giống hệt và đúng 2 mapping
   vendor giống hệt (VendorCode/FromDate/ToDate) template nguồn.
7. **Given** template nguồn không có step nào và không có mapping vendor nào, **When** Clone thành
   công, **Then** template mới được tạo với cây bước rỗng và không có mapping vendor nào — không
   phải là lỗi.
8. **Given** template nguồn đang là Default (IsDefault=1), **When** Clone thành công, **Then**
   template mới luôn có IsDefault=0, template nguồn vẫn giữ nguyên IsDefault=1 (không bị ảnh hưởng).

---

### Edge Cases

- Khi danh sách rỗng, bảng hiển thị trạng thái "No data" thay vì lỗi.
- Khi Vendor code trong template không tìm thấy qua API reference (refType=13), cột Vendor name hiển thị trống
  hoặc giá trị mặc định, không gây lỗi cả bảng.
- Khi Id lưu trong AlertFor không còn tồn tại trong `compl_group_email` (ví dụ group đã bị xóa),
  cột Alert for trên grid hiển thị trống, không gây lỗi cả bảng.
- Khi danh sách group (`GET /api/group-email`, GroupType=Alert) rỗng, combobox Alert for (ở dialog
  Create Template hoặc màn hình Edit) hiển thị trạng thái không có lựa chọn và người dùng không thể
  Save cho đến khi có ít nhất một group Alert được tạo trong màn hình quản lý group email.
- Khi người dùng cố tạo step con lồng nhiều cấp, cây vẫn hiển thị và hoạt động đúng đệ quy.
- Khi danh sách EUTR steps rỗng (chưa tạo step nào), combobox Add step vẫn cho phép người dùng
  gõ tự do (free-solo) để nhập tên step mới — không còn bắt buộc phải tạo step trước ở màn hình
  001-eutr-steps.
- Khi tên step người dùng gõ tự do trùng (không phân biệt hoa/thường, đã trim khoảng trắng) với
  một step đã có trong danh sách EUTR steps, hệ thống MUST dùng lại StepId của step đã có, KHÔNG
  tạo bản ghi trùng lặp trong eutr_steps.
- Khi người dùng gõ tên step chỉ chứa khoảng trắng hoặc để trống rồi Save step, hệ thống MUST báo
  lỗi yêu cầu chọn hoặc nhập tên step hợp lệ, không cho phép thêm step rỗng vào cây.
- Khi lưu/xóa thất bại do lỗi mạng hoặc máy chủ, người dùng nhận thông báo lỗi và dữ liệu không
  bị thay đổi sai lệch.
- Khi nhấn Back trên màn hình tạo/sửa mà KHÔNG có thay đổi step nào (chưa add/edit step gì), hệ
  thống quay về danh sách ngay lập tức không cảnh báo.
- Khi nhấn Back trên màn hình tạo/sửa mà đã add/edit step nhưng chưa Save, hệ thống hiển thị cảnh
  báo xác nhận; nếu người dùng xác nhận rời đi, dữ liệu chưa lưu (bao gồm cả thay đổi trên form
  header) sẽ bị mất.
- Khi Edit một template được tạo cách đây đúng 24 giờ (biên giới), hệ thống áp dụng logic dựa trên
  so sánh (now - CreatedDate) — nếu ≥ 24 giờ thì tạo version mới, nếu < 24 giờ thì cập nhật đè.
- Khi một template được cập nhật đè nhiều lần liên tiếp trong cùng khung 24 giờ kể từ CreatedDate
  gốc, VersionId và Id không đổi qua các lần Save đó; chỉ khi vượt mốc 24 giờ mới tạo version mới.
- Khi đang chỉnh sửa step (chế độ edit inline) và nhấn Edit trên step khác, step đang edit MUST
  tự động hủy chỉnh sửa (cancel) trước khi mở edit cho step mới.
- Khi đang chỉnh sửa step và đổi sang step trùng với step khác đã có cùng cấp, hệ thống vẫn cho
  phép (không ràng buộc unique StepId trong cùng template).
- Khi một template có nhiều phiên bản (version 1, 2, 3...), grid chỉ hiển thị phiên bản mới nhất
  (IsHide=0, IsDeleted=0). Các phiên bản cũ (IsHide=1) vẫn tồn tại trong database.
- Khi soft delete một template đã có nhiều version, chỉ version đang hiển thị (IsHide=0) bị cập
  nhật IsDeleted=1; các version cũ (đã IsHide=1) không bị ảnh hưởng.
- Khi đánh dấu Default cho template mà cùng VendorCode đã có template default khác, hệ thống tự
  bỏ cờ default trên template cũ mà không cần xác nhận thêm.
- Khi người dùng đóng dialog Create Template mà không nhấn Save (nhấn Cancel/đóng dialog), hệ
  thống KHÔNG tạo bản ghi nào; danh sách giữ nguyên không thay đổi.
- Khi mở màn hình Edit cho một template vừa được tạo qua dialog Create Template (0 step, Vendor
  trống), cây bước hiển thị trạng thái rỗng (tương tự trạng thái "chưa có step") và combobox Vendor
  hiển thị chưa chọn — không coi đây là lỗi hay dữ liệu thiếu.
- Sau khi Save dialog Create Template, hệ thống KHÔNG tự động điều hướng sang màn hình Edit; người
  dùng phải tự nhấn Edit trên dòng vừa tạo trong danh sách để tiếp tục thêm Vendor hoặc step.
- Khi tick checkbox "chọn tất cả" trên header bảng bulk-select rồi bỏ tick một vài dòng riêng lẻ,
  bộ đếm "{N} step available - {M} đã chọn" MUST cập nhật chính xác theo số dòng đang tick (cộng cả
  step đã nhập ở khu vực Add new step).
- Khi danh sách "step available" của dialog bulk-select rỗng (toàn bộ step master đã là con trực
  tiếp của node đích), bảng MUST hiển thị trạng thái rỗng nhưng khu vực "Add new step" vẫn khả dụng
  để nhập step hoàn toàn mới.
- Khi tên step nhập tự do ở khu vực "Add new step" trùng (không phân biệt hoa/thường, đã trim
  khoảng trắng) với một step đã tick chọn từ bảng master hoặc một step tự do khác đã nhập trong
  cùng lượt mở dialog, hệ thống MUST áp dụng quy tắc gộp step trùng tên hiện hành (FR-007a) khi
  Save template — chỉ tạo 1 bản ghi step mới nếu tên chưa tồn tại, dùng chung StepId.
- Khi đóng dialog bulk-select bằng Cancel (hoặc đóng dialog) mà đã tick chọn một số step hoặc đã
  nhập step mới ở khu vực Add new step nhưng CHƯA nhấn Add, toàn bộ lựa chọn/nhập tạm bị hủy —
  không có step nào được thêm vào cây bước.
- Khi nhấn nút **Root Group** trong lúc đang có một node được chọn trong cây (selectedId khác
  null), dialog bulk-select MUST vẫn thêm các step đã chọn làm step **gốc** (ParentId = 0), không
  bị ảnh hưởng bởi node đang được chọn trong cây (chỉ nút **Child Step** mới dùng node đang chọn
  làm cha).
- **(Update 13)** Khi ApplyCustomerPage tải danh sách mapping cho một template không tồn tại hoặc
  đã bị xóa (IsDeleted=1), hệ thống hiển thị thông báo lỗi/trạng thái phù hợp thay vì màn hình
  trống không rõ nguyên nhân.
- **(Update 13)** Khi danh sách mapping của một template rỗng (chưa apply vendor nào), bảng hiển
  thị trạng thái "No data" và nút Apply Vendor vẫn khả dụng để thêm mapping đầu tiên.
- **(Update 13)** Khi nhập To date nhỏ hơn From date trong dialog Apply Vendor, hệ thống báo lỗi
  và không cho Save.
- **(Update 13)** Khi để trống To date, hệ thống hiểu là không giới hạn thời gian (tương đương
  ToDate = 9999-12-31), theo đúng hành vi hiện có của `ApplyCustomerPage.jsx` (mock).
- **(Update 13)** Khi Edit một mapping, việc kiểm tra chồng lấn ngày (cùng vendor, cùng template)
  MUST loại trừ chính bản ghi đang sửa khỏi tập so sánh.
- **(Update 13)** Sau khi xóa cột VendorCode khỏi `eutr_templates`, các template đang có VendorCode
  trước đó mất hoàn toàn liên kết vendor cũ (theo quyết định đã xác nhận — không migrate dữ liệu);
  đây không phải lỗi, là hành vi đã được xác nhận.
- **(Update 13)** Khi đánh dấu Default cho một template trong khi một template KHÁC (bất kỳ, kể cả
  khác vendor/không còn khái niệm vendor trên template) đang là default, hệ thống tự động bỏ cờ
  default trên template cũ đó theo ràng buộc default toàn cục mới (không cần xác nhận thêm).
- **(Update 14)** Khi file Import không phải định dạng .xlsx (đuôi file hoặc nội dung không phải
  Excel hợp lệ), hệ thống MUST từ chối ngay từ bước chọn file/upload, hiển thị lỗi rõ ràng và KHÔNG
  đọc/xử lý nội dung file.
- **(Update 14)** Khi file Import thiếu một hoặc nhiều cột bắt buộc (TemplateCode, VendorCode,
  FromDate, ToDate không đúng tên cột tiêu đề), hệ thống MUST báo lỗi định dạng file ngay từ đầu
  (trước khi xử lý dòng dữ liệu), không cố xử lý một phần.
- **(Update 14)** Khi file Import chỉ có dòng tiêu đề, không có dòng dữ liệu nào, hệ thống MUST
  hiển thị thông báo "không có dữ liệu để import" thay vì báo lỗi hệ thống hoặc coi là thành công
  im lặng.
- **(Update 14)** Khi một dòng trong file Import có TemplateCode KHÔNG khớp Code của template đang
  mở trên ApplyCustomerPage, dòng đó MUST bị đánh dấu lỗi riêng và bị bỏ qua — KHÔNG tạo mapping
  cho template đang mở lẫn template khác, các dòng hợp lệ khác trong cùng file vẫn được xử lý bình
  thường.
- **(Update 14)** Khi nhiều dòng trong cùng file Import có cùng VendorCode với khoảng FromDate-ToDate
  chồng lấn nhau, hệ thống MUST xử lý tuần tự theo thứ tự dòng trong file: dòng hợp lệ đầu tiên
  được tạo, các dòng sau chồng lấn với dòng đã tạo (hoặc mapping có sẵn) bị báo lỗi chồng lấn.
- **(Update 14)** Khi ToDate trong một dòng Import nhỏ hơn FromDate của cùng dòng đó, dòng đó MUST
  bị báo lỗi và không được tạo, các dòng khác trong file không bị ảnh hưởng.
- **(Update 14)** Khi để trống ToDate trong file Import, hệ thống MUST hiểu là không giới hạn thời
  gian (tương đương ToDate = 9999-12-31), giống hành vi của dialog Add Vendor thủ công.
- **(Update 14)** Import KHÔNG cập nhật mapping đã tồn tại — nếu một dòng Import trùng hoàn toàn dữ
  liệu (cùng Vendor, cùng khoảng ngày) với một mapping đã có, dòng đó MUST bị báo lỗi chồng lấn
  giống mọi trường hợp chồng lấn khác, không âm thầm bỏ qua hay cập nhật đè.
- **(Update 15)** Khi lên version (nhánh trên 24 giờ của FR-012) cho một template không có mapping
  vendor nào (`eutr_template_references` rỗng), bước sao chép mapping không tạo bản ghi nào cho
  TemplateId mới — không phải là lỗi.
- **(Update 15)** Sau khi lên version và sao chép `eutr_template_references` sang TemplateId mới,
  các bản ghi mapping cũ vẫn giữ nguyên gắn với TemplateId cũ (đã IsHide=1) để phục vụ truy vết lịch
  sử — hệ thống KHÔNG xóa hay di chuyển (move) các mapping cũ đó.
- **(Update 15)** Khi Clone một template mà một số step trong cây đã tham chiếu StepId thật (đã tồn
  tại trong `eutr_steps`), Clone MUST dùng lại đúng StepId đó cho template mới — KHÔNG tạo lại bản
  ghi step mới trong `eutr_steps`.
- **(Update 15)** Khi Clone nhiều lần liên tiếp từ cùng một template nguồn, mỗi lần Clone MUST tạo
  ra một template mới độc lập (Code riêng biệt theo quy tắc tự sinh hiện hành) — không giới hạn số
  lần Clone từ một nguồn.
- **(Update 15)** Việc sao chép mapping vendor khi Clone (sang TemplateId hoàn toàn mới) KHÔNG bị
  chặn bởi kiểm tra chồng lấn ngày (FR-036) vì ràng buộc chồng lấn chỉ áp dụng cho mapping của CÙNG
  một TemplateId — template mới và template nguồn là hai TemplateId khác nhau.
- **(Update 15)** Sau khi Clone hoàn tất, template mới hoàn toàn độc lập với template nguồn — chỉnh
  sửa (Edit), xóa (Delete), hoặc lên version một trong hai template KHÔNG ảnh hưởng đến template
  còn lại.
- **(Update 15)** Khi người dùng đóng dialog Clone Template (Cancel/đóng) mà chưa nhấn nút
  Clone/Confirm, hoặc hủy ở hộp thoại cảnh báo xác nhận, hệ thống KHÔNG tạo template mới, KHÔNG sao
  chép bất kỳ dữ liệu nào.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001 (Superseded by Update 10 — xem FR-021)**: Hệ thống MUST hiển thị danh sách EUTR
  templates dạng bảng với các cột: Code, Name, Vendor code, Vendor name, Alert for, Is default,
  Version, Created by, Created date và cột Action (Edit, Delete). Grid chỉ hiển thị các template
  có IsDeleted = 0 VÀ IsHide = 0. Cột Alert for MUST hiển thị Name của group email tương ứng
  (không hiển thị Id). *(Update 10 thay layout DataGrid 9 cột này bằng giao diện Table + chip theo
  FR-021 — không còn hiển thị cột Vendor code/Vendor name/Alert for/Created by/Created date trên
  màn hình danh sách; các trường này vẫn xem/sửa được ở TemplateBuilderPage.)*
- **FR-002 (Superseded by Update 10)**: Cột Vendor name MUST được tra cứu từ API reference chung
  `POST /api/dynamics/reference` với `refType = 13` dựa trên VendorAccountNumber = Vendor code
  của template. KHÔNG sử dụng endpoint riêng `GET /api/dynamics/vendors`. *(Logic tra cứu vendor
  qua refType=13 vẫn áp dụng cho combobox Vendor ở TemplateBuilderPage theo FR-005b; chỉ không còn
  là một cột hiển thị trên danh sách.)*
- **FR-002a (Superseded by Update 10)**: Cột Alert for trên grid MUST được tra cứu Name từ bảng
  `compl_group_email` (qua `GET /api/group-email`) dựa trên Id đang lưu trong cột `AlertFor` của
  template. Nếu Id không tìm thấy (group đã bị xóa), cột Alert for hiển thị trống. *(Không còn là
  cột trên danh sách; logic tra cứu/chọn Alert for vẫn áp dụng ở dialog Create và TemplateBuilderPage
  theo FR-005c.)*
- **FR-003**: Hệ thống MUST phân trang danh sách khi số bản ghi vượt một trang và cho phép
  chuyển trang.
- **FR-004**: Khi nhấn **Create Template** trên thanh công cụ của danh sách (TemplateListPage), hệ
  thống MUST hiển thị một **dialog/modal tạo nhanh** (KHÔNG điều hướng sang trang khác), chỉ gồm 3
  trường theo FR-005. Trường Vendor và cây bước (step tree) KHÔNG xuất hiện trong dialog này (xem
  FR-011 cho nơi các trường/cây bước còn lại được thiết lập).
- **FR-004a (Superseded by Update 10 — xem FR-023/FR-024)**: Màn hình **Edit** MUST chia thành **2
  cột**: cột trái chứa form thông tin header (Code readonly, Name, AlertFor, Vendor, Default, nút
  Save), cột phải chứa cây bước (step tree) và các thao tác trên step (Add step, Edit step, Delete
  step). Hai cột hiển thị song song trên cùng một hàng. Cột trái MUST được mở rộng chiều ngang hơn
  (so với thiết kế trước) và cột phải MUST được thu hẹp lại tương ứng, để trường nhập liệu
  Code/Name/AlertFor/Vendor có đủ không gian hiển thị. Layout này là nơi **DUY NHẤT** người dùng
  xây dựng/chỉnh sửa cây bước và thiết lập Vendor — kể cả khi Edit một template vừa được tạo qua
  dialog Create (cây bước đang rỗng, Vendor đang trống). Dialog Create Template (FR-004/FR-005)
  KHÔNG dùng layout 2 cột này. *(Update 10 thay layout 2 cột form/list này bằng giao diện
  TemplateBuilderPage — cây bước dạng tree-view + panel cấu hình, xem FR-023/FR-024. Các trường
  header Code/Name/AlertFor/Vendor/Default vẫn MUST hiển thị đầy đủ, chỉ đổi sang panel cấu hình
  bên phải của TemplateBuilderPage thay vì cột trái dạng form độc lập.)*
- **FR-005**: Dialog **Create Template** MUST chỉ có các trường: Name (textbox, bắt buộc), Alert
  for (combobox chọn một, bắt buộc — xem FR-005c), Set as default (checkbox). Code do hệ thống tự
  sinh (prefix + số tăng dần, ví dụ Templates-001; prefix và số chữ số được cấu hình từ chức năng
  riêng phát triển sau) tại thời điểm Save và KHÔNG hiển thị trong dialog (chưa tồn tại trước khi
  Save). Trường **Vendor KHÔNG xuất hiện** trong dialog Create — Vendor chỉ khả dụng ở màn hình
  Edit (xem FR-005b, FR-011).
- **FR-005c**: Combobox Alert for MUST gọi API `GET /api/group-email` (theo
  `ComplGroupEmailController`) để lấy danh sách group từ bảng `compl_group_email`, chỉ hiển thị
  các group có `GroupType = Alert (2)` và `IsAddition = false`, hiển thị **Name** của group cho
  người dùng chọn (chọn một — single-select). Khi Save, hệ thống MUST lưu **Id** của group đã
  chọn vào cột `AlertFor` của bảng eutr_templates (KHÔNG lưu Name). Combobox này MUST xuất hiện ở
  cả dialog Create (FR-005) và màn hình Edit; ở chế độ Edit, group hiện tại của template (tra cứu
  theo Id lưu trong AlertFor) MUST được chọn sẵn trong combobox.
- **FR-005b (Superseded by Update 13 — xem FR-039, FR-041)**: Combobox Vendor (`options={vendors}`
  trong màn hình Edit) MUST gọi API reference chung `POST /api/dynamics/reference` với
  `refType = 13` để lấy danh sách vendor, thay vì sử dụng endpoint riêng `GET /api/dynamics/vendors`.
  Khi mở combobox, hệ thống MUST hiển thị danh sách VendorAccountNumber + VendorOrganizationName
  trả về từ API reference (refType=13). Ở chế độ Edit, vendor hiện tại của template (nếu có) MUST
  được chọn sẵn trong combobox; nếu template chưa có Vendor (ví dụ vừa tạo qua dialog Create),
  combobox hiển thị trống. Frontend MUST dùng lại component/hook reference chung (ví dụ
  ReferenceObjectAutocomplete hoặc `useReferenceObjects`) cho trường Vendor, thay cho hook
  `useVendors` gọi endpoint riêng trước đây (hỗ trợ tìm kiếm theo VendorAccountNumber hoặc
  VendorOrganizationName qua tham số reference). Combobox Vendor CHỈ xuất hiện ở màn hình Edit,
  KHÔNG xuất hiện ở dialog Create (FR-005). *(Update 13 loại bỏ hoàn toàn Vendor khỏi
  `eutr_templates`/TemplateBuilderPage — combobox này biến mất khỏi panel cấu hình; logic gọi API
  reference refType=13 vẫn tái sử dụng nhưng chuyển sang màn hình ApplyCustomerPage mới, xem
  FR-034.)*
- **FR-005a (Superseded by Update 13 — xem FR-040)**: Mỗi VendorCode chỉ MUST có tối đa 1 template
  với IsDefault = 1 (trong các bản ghi IsDeleted=0, IsHide=0). Khi người dùng đánh dấu Default cho
  một template (ở dialog Create hoặc màn hình Edit), hệ thống MUST tự động bỏ cờ IsDefault trên
  template default cũ cùng VendorCode (nếu có và nếu VendorCode đã được thiết lập). *(Update 13 bỏ
  cột VendorCode khỏi eutr_templates — ràng buộc default chuyển thành toàn cục, xem FR-040.)*
- **FR-006**: Màn hình Edit MUST hiển thị cây bước (step tree) đệ quy ở cột phải, hỗ trợ
  collapse/expand từng nhánh và drag-and-drop để sắp xếp lại thứ tự step trong cùng cấp.
  DisplayOrder MUST được cập nhật tự động theo vị trí kéo thả. Chức năng này CHỈ khả dụng ở màn
  hình Edit, không có ở dialog Create Template.
- **FR-007**: Khi nhấn Add step (chỉ khả dụng ở màn hình Edit), hệ thống MUST hiển thị form chọn
  step gồm: combobox step (free-solo — nạp danh sách từ EUTR steps hiện có, cho phép chọn 1 step
  có sẵn HOẶC gõ trực tiếp một tên step mới chưa có trong danh sách), combobox RequirementType
  (Required/Optional), combobox TakeFrom (PO/Upload manual), và nút Save.
- **FR-007a**: Khi nhấn Save ở màn hình Edit, với mỗi step trong cây bước có tên được nhập tự do
  (không khớp — không phân biệt hoa/thường, đã trim khoảng trắng — với step nào đang có trong danh
  sách EUTR steps), hệ thống MUST tự động tạo bản ghi step mới trong bảng eutr_steps TRƯỚC khi lưu
  eutr_template_details, rồi dùng StepId vừa tạo để tham chiếu. Nếu nhiều step trong cùng lần Save
  dùng chung một tên mới, hệ thống chỉ MUST tạo 1 bản ghi step mới và dùng chung StepId cho các
  step đó.
- **FR-008**: Nếu người dùng tick chọn một step cha trước khi Add step (ở màn hình Edit), step mới
  MUST là con của step đó (ParentId = Id của step cha). Nếu không chọn, step mới MUST là gốc
  (ParentId = 0).
- **FR-008a**: Người dùng MUST có thể xóa step khỏi cây bước (ở màn hình Edit) bằng hai cách: (1)
  nhấn icon xóa (X) trên dòng step để xóa đơn lẻ, hoặc (2) tick checkbox chọn một hoặc nhiều step
  rồi nhấn nút "Delete step" để xóa hàng loạt. Khi xóa step cha, toàn bộ step con MUST bị xóa theo.
- **FR-008b**: Người dùng MUST có thể chỉnh sửa step đã tạo trong cây bước (ở màn hình Edit) bằng
  cách nhấn icon Edit (bút chì) trên dòng step. Khi nhấn Edit, dòng step MUST chuyển sang chế độ
  chỉnh sửa hiển thị: combobox Step (free-solo — cho phép đổi sang step khác có sẵn trong danh sách
  HOẶC gõ trực tiếp một tên step mới chưa có trong danh sách), combobox RequirementType
  (Required/Optional) với giá trị hiện tại được chọn sẵn, combobox TakeFrom (PO/Upload manual)
  với giá trị hiện tại được chọn sẵn, nút Save (xác nhận thay đổi) và nút Cancel (hủy, giữ giá
  trị cũ). Sau khi Save, dòng step MUST cập nhật giá trị mới trên cây mà không cần nhấn Save
  template; nếu tên được gõ là tên mới chưa tồn tại, việc tạo bản ghi step mới trong eutr_steps
  chỉ MUST xảy ra khi nhấn Save template (theo FR-007a), không xảy ra ngay khi Save step trên cây.
- **FR-009**: Khi nhấn Save trong dialog **Create Template**, hệ thống MUST tạo một bản ghi mới
  trong eutr_templates (Code tự sinh, Name, IsDefault, AlertFor, VersionId=1, VendorCode=null,
  IsDeleted=0, IsHide=0) và KHÔNG tạo step nào trong eutr_template_details (cây bước rỗng ban
  đầu). Việc lưu cây bước (bao gồm ParentId chính xác cho từng step) chỉ MUST xảy ra khi Save ở
  màn hình **Edit**, theo cơ chế versioning tại FR-012 (lần Edit đầu tiên của một template mới tạo
  thường rơi vào nhánh "dưới 24 giờ" — cập nhật đè lên cùng dòng vừa tạo).
- **FR-009a**: Nút Save trên màn hình **Edit** MUST được đặt ở cột trái, ngay bên dưới checkbox
  "Set as default template" — KHÔNG đặt ở thanh tiêu đề (title bar) cùng hàng với nút Back. Nút
  Back MUST vẫn giữ nguyên vị trí ở thanh tiêu đề. Trong dialog **Create Template**, nút Save MUST
  nằm ở khu vực hành động tiêu chuẩn của dialog (cùng hàng với nút Cancel/Hủy).
- **FR-010**: Hệ thống MUST yêu cầu Name không được để trống và Alert for phải được chọn (một
  group hợp lệ) — áp dụng cho cả dialog Create Template và màn hình Edit. Code do hệ thống tự sinh
  nên không cần người dùng nhập hay kiểm tra. *(Update 13: bỏ mệnh đề "VendorCode là tùy chọn" —
  trường Vendor không còn tồn tại trên eutr_templates/TemplateBuilderPage, xem FR-039/FR-041.)*
- **FR-011 (Superseded by Update 10 — xem FR-023)**: Khi nhấn Edit trên một dòng (bao gồm cả
  template vừa tạo qua dialog Create Template, 0 step, Vendor trống), hệ thống MUST chuyển sang màn
  hình chỉnh sửa đầy đủ (layout 2 cột theo FR-004a) với breadcrumb "EUTR system > EUTR templates >
  Edit", tải sẵn dữ liệu header (bao gồm
  Vendor được chọn sẵn từ API `POST /api/dynamics/reference` với `refType = 13` nếu đã có, và
  Alert for được chọn sẵn từ API `GET /api/group-email` dựa trên Id lưu trong AlertFor) và cây bước
  hiện tại của template đó (có thể rỗng). Đây là màn hình **DUY NHẤT** người dùng có thể thêm step
  đầu tiên, thêm/sửa/xóa step tiếp theo (đổi step, RequirementType, TakeFrom), và thiết lập/thay
  đổi Vendor.
- **FR-012**: Khi Save ở màn hình Edit, hệ thống MUST áp dụng logic versioning có điều kiện dựa
  trên CreatedDate của bản ghi đang sửa so với thời điểm hiện tại:
  - Nếu bản ghi được tạo **cách đây TRÊN 24 giờ**: hệ thống MUST tạo dòng mới trong eutr_templates
    với cùng dữ liệu header (áp dụng thay đổi) và VersionId = VersionId cũ + 1, IsHide = 0,
    IsDeleted = 0. Dòng cũ MUST được cập nhật IsHide = 1. Toàn bộ cây bước hiện tại (bao gồm step
    đã chỉnh sửa, thêm, xóa) MUST được lưu vào eutr_template_details với TemplateId mới và
    ParentId chính xác cho từng step.
  - Nếu bản ghi được tạo **cách đây DƯỚI 24 giờ**: hệ thống MUST cập nhật đè trực tiếp lên dòng
    hiện tại (cùng Id, cùng VersionId, CreatedDate giữ nguyên) — KHÔNG tạo dòng mới, KHÔNG set
    IsHide. Toàn bộ step trong eutr_template_details thuộc TemplateId hiện tại MUST được thay thế
    bằng cây bước mới nhất từ màn hình Edit (xóa step cũ không còn trong cây, thêm step mới, cập
    nhật step đã sửa) với ParentId chính xác.
- **FR-013**: Người dùng MUST có thể xóa template (soft delete), có bước xác nhận trước khi xóa.
  Xóa MUST chỉ cập nhật IsDeleted = 1 trên dòng đang hiển thị (IsHide=0), KHÔNG xóa dữ liệu
  thật trong database.
- **FR-014**: Hệ thống MUST hỗ trợ import template từ file, hiển thị kết quả import
  (thành công/thất bại).
- **FR-015**: Nút Back trên màn hình **Edit** MUST quay về danh sách template. Nếu người dùng đã
  thêm step mới hoặc chỉnh sửa step đã có trong cây bước mà CHƯA nhấn Save template, hệ thống
  MUST hiển thị hộp thoại cảnh báo xác nhận trước khi điều hướng đi (ví dụ: "Bạn có thay đổi chưa
  lưu. Rời khỏi trang sẽ mất các thay đổi này. Tiếp tục?"), cho phép chọn rời đi (mất thay đổi)
  hoặc ở lại trang. Nếu không có thay đổi step nào chưa lưu (bao gồm trường hợp mới mở trang hoặc
  đã Save toàn bộ), Back MUST điều hướng thẳng về danh sách mà không cảnh báo. Dialog **Create
  Template** không có nút Back — người dùng đóng dialog bằng nút Cancel/Hủy hoặc nút đóng dialog
  tiêu chuẩn, không cần cảnh báo dữ liệu chưa lưu vì dialog chỉ có 3 trường đơn giản chưa Save
  cũng không mất mát dữ liệu phức tạp (không có cây bước).
- **FR-016**: Hệ thống MUST hiển thị màn hình trong mục điều hướng "EUTR templates" dưới nhóm
  "EUTR system".
- **FR-017**: Toàn bộ văn bản hiển thị cho người dùng trên front-end MUST bằng tiếng Anh, bao
  gồm: nhãn cột, nút (Add, Edit, Delete, Save, Back, Add step, Import), breadcrumb, thông báo
  kiểm tra/lỗi, thông báo thành công, trạng thái rỗng ("No data"), và hộp thoại xác nhận.
- **FR-018 (Superseded by Update 5)**: Endpoint riêng `GET /api/dynamics/vendors` (được thêm ở
  Update 2/3) KHÔNG còn được combobox Vendor hoặc tra cứu Vendor name trên grid sử dụng. Vendor
  data MUST được tải lại qua API reference chung `POST /api/dynamics/reference` với
  `refType = 13` (đã ánh xạ sẵn tới D365 VendorsV3 trong cấu hình reference type của hệ thống).
  Endpoint `GET /api/dynamics/vendors` có thể vẫn tồn tại trong DynController nhưng không còn là
  nguồn dữ liệu cho tính năng EUTR Templates.
- **FR-019**: Trang danh sách EUTR Templates MUST được tổ chức/đặt tên theo quy ước
  **TemplateListPage**, theo tham chiếu thiết kế `E:\Working\design\eutr\pages\TemplateListPage.jsx`
  (đổi tên/tổ chức từ component `EutrTemplatesPage`/`index.jsx` hiện tại). *(Không đổi ở Update 10.)*
- **FR-020 (Superseded by Update 10 — xem FR-021)**: Bộ cột grid và cột Action trên TemplateListPage
  MUST khớp chính xác với FR-001 (Code, Name, Vendor code, Vendor name, Alert for, Is default,
  Version, Created by, Created date; Action = Edit + Delete). Grid KHÔNG được thêm cột Status và cột
  Action KHÔNG được thêm chức năng Preview checklist, Archive, Publish hay Clone — dù các phần tử
  này có xuất hiện trong bản mockup thiết kế tham chiếu (`TemplateListPage.jsx`). *(Update 10 đảo
  ngược quyết định này: TemplateListPage đổi sang giao diện Table + chip của thiết kế tham chiếu,
  và cột Action bổ sung icon Clone/Apply to Customer ở trạng thái disabled — xem FR-021, FR-026.)*
- **FR-021**: Giao diện danh sách **TemplateListPage** MUST hiển thị dạng Table (không phải
  DataGrid nhiều cột) kèm ô tìm kiếm phía trên, theo đúng bố cục của thiết kế tham chiếu
  `TemplateListPage.jsx`. Mỗi dòng MUST hiển thị: ô tên gồm 2 dòng chữ — dòng đậm hiển thị **Code**
  thật của template, dòng phụ/caption bên dưới hiển thị **Name** thật; Chip **Version** (giá trị
  versionId); Chip **Default** (chỉ hiện khi IsDefault=1); số lượng **Steps** hiện có trong cây
  bước của template (số thật, xem FR-021c); và cột **Actions**. Danh sách chỉ hiển thị các template
  có IsDeleted=0 VÀ IsHide=0, và hỗ trợ phân trang (theo FR-003).
- **FR-021a**: Ô tìm kiếm trên TemplateListPage MUST lọc danh sách theo **Code** hoặc **Name** khớp
  một phần, không phân biệt hoa/thường, thực hiện **server-side**: mỗi lần người dùng gõ (có
  debounce hợp lý, ví dụ 300-500ms) hệ thống MUST gọi lại API danh sách với từ khóa tìm kiếm và
  MUST reset về trang đầu tiên, áp dụng trên toàn bộ dữ liệu (không chỉ các dòng của trang đang
  hiển thị). Tái sử dụng cơ chế server-side pagination/filter đã có ở `useEutrTemplatesData`
  (`paginationMode="server"`, `filterMode="server"`), mở rộng với tham số từ khóa Code-hoặc-Name.
- **FR-021b**: Các tính năng sau của TemplateListPageOld KHÔNG được mang sang giao diện Table mới ở
  đợt cập nhật này (hoãn lại — deferred): nút Import/Export trên toolbar, ẩn/hiện cột (column
  visibility), và filter/sort theo từng cột kiểu DataGrid. Cột Vendor code, Vendor name, Alert for,
  Created by, Created date KHÔNG còn hiển thị trực tiếp trên danh sách (vẫn xem/sửa được ở
  TemplateBuilderPage theo FR-024).
- **FR-021c**: API danh sách EUTR templates (backend, dùng bởi `useEutrTemplatesData`/
  `GetEutrTemplatesUseCase`) MUST được mở rộng để trả về số lượng step thật của mỗi template —
  đếm số dòng `eutr_template_details` đang hoạt động (thuộc TemplateId đó) — kèm theo mỗi bản ghi
  trong kết quả danh sách. Đây là thay đổi backend thuộc phạm vi của đợt cập nhật này (KHÔNG còn là
  giá trị mặc định 0/để trống vô thời hạn), để cột **Steps** ở FR-021 luôn hiển thị số liệu chính
  xác.
- **FR-022**: Icon **Delete** trên mỗi dòng của TemplateListPage MUST hoạt động giống hệt
  TemplateListPageOld: hiển thị `ConfirmDialog` xác nhận (nêu rõ Name và Code), gọi
  `DeleteEutrTemplatesUseCase` khi xác nhận, làm mới danh sách, và hiển thị snackbar kết quả.
  TemplateListPage MUST bổ sung checkbox chọn dòng (per-row) để hỗ trợ xóa hàng loạt: nút xóa hàng
  loạt trên toolbar (chỉ hiện/khả dụng khi có quyền Delete và có ít nhất 1 dòng được chọn) MUST mở
  `ConfirmDialog` riêng nêu rõ số lượng đã chọn, gọi `DeleteMultiEutrTemplatesUseCase` với danh sách
  Id khi xác nhận, làm mới danh sách, xóa lựa chọn, và hiển thị snackbar kết quả.
- **FR-023**: Icon **Edit** trên mỗi dòng của TemplateListPage MUST điều hướng tới route
  `/eutr/templates/edit/:id`, mở màn hình **TemplateBuilderPage** — KHÔNG mở layout 2 cột form/list
  của `EutrTemplatesAddEdit.jsx` (đảo ngược FR-004a/FR-011 của Update 9). Route này áp dụng cho cả
  Edit một template đã có step lẫn Edit một template vừa tạo qua dialog Create Template (0 step,
  Vendor trống).
- **FR-024 (Cập nhật ở Update 13 — xem FR-041)**: **TemplateBuilderPage** MUST được nối với dữ liệu
  và luồng nghiệp vụ thật, tái sử dụng toàn bộ logic nghiệp vụ đã có ở `EutrTemplatesAddEdit.jsx`
  (không viết lại từ đầu): tải template theo Id (`GetEutrTemplatesUseCase`), tải danh sách EUTR
  steps (`GetEutrStepsUseCase`), tải danh sách group Alert (`GetAllGroupEmailUseCase`, lọc
  GroupType=Alert/IsAddition=false), lưu qua `UpdateEutrTemplatesUseCase` áp dụng logic versioning
  có điều kiện 24 giờ (FR-012), tự động tạo step mới khi gõ tự do (FR-007a), và cảnh báo khi Back
  mà có thay đổi step chưa lưu (FR-015). Giao diện hiển thị (cây bước dạng tree-view bên trái +
  panel cấu hình bên phải, toolbar Add Root/Add Child/Move/Delete/Expand/Collapse) MUST giữ theo
  đúng bố cục hiện có của `TemplateBuilderPage.jsx` — KHÔNG áp dụng lại layout 2 cột form/list của
  `EutrTemplatesAddEdit.jsx`. Panel cấu hình bên phải MUST hiển thị các trường header **Code
  (readonly), Name, Alert for, Set as default** — KHÔNG còn combobox **Vendor** (loại bỏ theo
  FR-041, Update 13); đây là màn hình duy nhất người dùng chỉnh sửa các trường này.
- **FR-025 (Superseded một phần bởi Update 12 — xem FR-027 đến FR-030)**: Form Add step (Add Root
  Group / Add Child Step) và Edit step trên TemplateBuilderPage MUST dùng combobox Step free-solo
  nạp từ danh sách EUTR steps thật (không còn dùng `Select` cố định gắn với dữ liệu mock
  `EUTR_STEPS`), theo đúng logic FR-007/FR-007a/FR-008/FR-008a/FR-008b hiện hành. *(Update 12 thay
  form thêm-từng-step-một cho thao tác Add Root Group/Add Child Step bằng dialog bulk-select nhiều
  dòng — xem FR-027 đến FR-030. Thao tác Edit step trên một node đã có KHÔNG đổi, vẫn theo FR-008b/
  FR-031.)*
- **FR-026 (Cập nhật một phần ở Update 13 và Update 15)**: Cột Action trên TemplateListPage MUST
  hiển thị thêm 2 icon **Clone** và **Apply to Customer**. Icon **Apply to Customer** KHÔNG còn
  disabled kể từ Update 13 — xem FR-032 cho hành vi mới (điều hướng sang ApplyCustomerPage). Icon
  **Clone** KHÔNG còn disabled kể từ Update 15 — xem FR-050 cho hành vi mới (mở dialog Clone
  Template). *(Trước Update 15, icon Clone giữ trạng thái disabled làm placeholder cho tính năng
  tương lai.)*
- **FR-027**: Dialog **Add Root Group** và **Add Child Step** trên TemplateBuilderPage MUST hiển
  thị dạng **bảng bulk-select** (thay cho form thêm 1 step) liệt kê toàn bộ EUTR steps master khả
  dụng (theo FR-029), mỗi dòng gồm: checkbox chọn dòng, cột **Step Master** (mã step nếu có + tên
  step), cột **Requirement Type** (dropdown Required/Optional, chỉ chỉnh được khi dòng đã tick,
  mặc định Optional khi vừa tick), cột **Take From** (dropdown PO/Upload manual, chỉ chỉnh được khi
  dòng đã tick, mặc định PO khi vừa tick). Bảng MUST có checkbox ở header để chọn/bỏ chọn tất cả
  các dòng. Footer của dialog MUST hiển thị bộ đếm "{N} step available - {M} đã chọn" (N = tổng số
  step khả dụng, M = số dòng đang tick cộng số step đã nhập ở khu vực Add new step theo FR-030),
  cùng nút Cancel (đóng dialog, không thêm gì) và nút Add ("Thêm") — nút Add MUST disabled khi
  M = 0.
- **FR-028**: Khi nhấn nút Add ("Thêm") trong dialog bulk-select, hệ thống MUST thêm đồng thời tất
  cả step đang ở trạng thái "đã chọn" (M ở FR-027, gồm cả step tick từ bảng master và step nhập tự
  do theo FR-030) vào cây bước trong cùng một thao tác: mỗi step MUST nhận ParentId = 0 nếu dialog
  mở từ nút **Root Group**, hoặc ParentId = Id của step cha đang chọn nếu dialog mở từ nút **Child
  Step** (theo FR-008 hiện hành), với RequirementType/TakeFrom lấy đúng theo cấu hình của từng dòng
  tại thời điểm nhấn Add. DisplayOrder của các step mới MUST nối tiếp sau các step con hiện có cùng
  cấp, theo đúng thứ tự xuất hiện của các dòng trong bảng bulk-select.
- **FR-029**: Danh sách "step available" trong dialog bulk-select (dùng chung cho cả Add Root Group
  và Add Child Step) MUST loại trừ các step đã tồn tại như step con trực tiếp (cùng ParentId) của
  node đích (gốc hoặc step cha đang chọn) trong cây bước hiện tại của template đang sửa, để tránh
  thêm trùng lặp một step vào cùng một cấp cha. Một step MUST vẫn xuất hiện lại trong danh sách khả
  dụng khi mở dialog cho một node cha khác (không ràng buộc unique StepId trong toàn bộ template).
- **FR-030**: Dialog bulk-select (Add Root Group / Add Child Step) MUST có một khu vực/hàng riêng
  biệt **"Add new step"** cho phép người dùng gõ tự do (free-solo) một tên step hoàn toàn mới chưa
  có trong danh sách EUTR steps, kèm cấu hình Requirement Type/Take From cho step đó. Sau khi nhập,
  step mới này MUST được gộp vào danh sách "đang chờ thêm" cùng với các step đã tick từ bảng master
  (tính vào M ở FR-027) và cùng được thêm vào cây bước khi nhấn nút Add chung của dialog — KHÔNG có
  nút Save/Add riêng cho step tự do này. Khi Save template, step nhập tự do này MUST được tự động
  tạo bản ghi mới trong eutr_steps theo đúng cơ chế FR-007a hiện hành (gộp theo tên trùng, không
  phân biệt hoa/thường, đã trim khoảng trắng).
- **FR-031**: Chức năng **Edit step** trên một node ĐÃ CÓ trong cây bước (FR-008b) KHÔNG thay đổi
  bởi Update 12 — vẫn là form chỉnh sửa 1 step tại một thời điểm (combobox Step free-solo,
  Requirement Type, Take From, nút Save/Cancel), không áp dụng bulk-select. Bulk-select (FR-027 đến
  FR-030) CHỈ áp dụng cho thao tác thêm mới qua Add Root Group / Add Child Step.
- **FR-032 (Update 13)**: Icon **Apply to Customer** trên mỗi dòng của TemplateListPage MUST trở
  thành hoạt động (không còn disabled — thay thế phần tương ứng của FR-026) và điều hướng tới route
  mới `/eutr/templates/apply/:id` (id = TemplateId của dòng đó), mở màn hình **ApplyCustomerPage**.
  Hành động này khả dụng cho bất kỳ template đang hiển thị nào trên danh sách (IsDeleted=0,
  IsHide=0), không yêu cầu điều kiện trạng thái nào khác.
- **FR-033 (Update 13)**: Màn hình **ApplyCustomerPage** MUST hiển thị breadcrumb (EUTR system >
  EUTR templates > {Code của template} > Apply to Customer) và một bảng danh sách các mapping
  Vendor đã apply cho template đang xem, tải từ bảng `eutr_template_references` lọc theo
  `TemplateId` (route param). Mỗi dòng MUST hiển thị: Vendor (VendorCode kèm VendorName tra cứu qua
  API reference chung `POST /api/dynamics/reference` với `refType = 13`), From date, To date (hiển
  thị "∞"/không giới hạn nếu ToDate rỗng hoặc bằng 9999-12-31), và cột Action (Edit, Delete).
- **FR-034 (Update 13)**: Nút **Apply Vendor** trên toolbar của ApplyCustomerPage MUST mở dialog
  popup Add gồm: combobox Vendor (bắt buộc, single-select, nạp qua API reference chung
  `POST /api/dynamics/reference` với `refType = 13`, hiển thị VendorAccountNumber +
  VendorOrganizationName), From date (bắt buộc), To date (tùy chọn — để trống nghĩa là không giới
  hạn/tương đương 9999-12-31). Nhấn Save MUST tạo một bản ghi mới trong `eutr_template_references`
  (TemplateId từ route, VendorCode đã chọn, FromDate, ToDate, CreatedBy/CreatedDate).
- **FR-035 (Update 13)**: Icon **Edit** trên một dòng mapping MUST mở lại dialog popup ở FR-034 với
  dữ liệu hiện tại được nạp sẵn (Vendor, From date, To date). Nhấn Save MUST cập nhật đè lên bản ghi
  `eutr_template_references` hiện tại (giữ nguyên Id/TemplateId/CreatedBy/CreatedDate, cập nhật
  VendorCode/FromDate/ToDate/UpdatedBy/UpdatedDate).
- **FR-036 (Update 13)**: Hệ thống MUST validate dialog Apply Vendor: Vendor và From date bắt buộc;
  nếu nhập To date, To date phải >= From date; và nếu Vendor đã chọn có một mapping khác (trong
  CÙNG template đang xem, loại trừ chính bản ghi đang sửa khi Edit) có khoảng FromDate-ToDate chồng
  lấn, hệ thống MUST báo lỗi và không cho Save. Chồng lấn giữa các mapping của CÙNG vendor ở các
  template KHÁC nhau KHÔNG bị chặn (theo phạm vi đã xác nhận ở Update 13).
- **FR-037 (Update 13)**: Icon **Delete** trên một dòng mapping MUST hiển thị `ConfirmDialog` xác
  nhận (nêu rõ Vendor), khi xác nhận MUST xóa THẬT (hard delete) bản ghi khỏi
  `eutr_template_references` — bảng này không có cột IsDeleted/soft-delete flag theo thiết kế DB
  (`docs/design/eutr/eutr_db.sql`).
- **FR-038 (Update 13)**: Trường **Vendor** (VendorAccountNumber + VendorOrganizationName) hiển thị
  trên bảng mapping và combobox của ApplyCustomerPage MUST được tra cứu qua cùng API reference
  chung `POST /api/dynamics/reference` với `refType = 13` đã dùng cho các trường Vendor khác trong
  feature này (không phải endpoint riêng `GET /api/dynamics/vendors`).
- **FR-039 (Update 13)**: Hệ thống MUST loại bỏ hoàn toàn cột `VendorCode` khỏi bảng
  `eutr_templates` và mọi logic liên quan trên eutr_templates: entity/DTO backend (`EutrTemplates`
  entity, `EutrTemplatesRequestDto`, `EutrTemplatesResponseDto`), whitelist sort/filter
  (`SortMap`/`FilterMap` trong `EutrTemplatesRepository`), logic tra cứu `VendorName` qua D365
  trong `EutrTemplatesService`, import/export cột Vendor code (`EutrTemplatesImportService`/
  `EutrTemplatesExportService`), validator liên quan VendorCode, combobox Vendor trên
  TemplateBuilderPage/CreateTemplateDialog, và cột "Vendor code"/"Vendor name" trên bất kỳ grid nào
  (bao gồm `useEutrTemplatesColumns.jsx`). Dữ liệu VendorCode hiện có trên các bản ghi
  `eutr_templates` bị xóa hoàn toàn cùng cột — KHÔNG migrate sang `eutr_template_references` (theo
  quyết định đã xác nhận ở Update 13).
- **FR-040 (Update 13 — thay thế FR-005a)**: Ràng buộc "chỉ tối đa 1 template IsDefault=1" MUST đổi
  từ phạm vi theo VendorCode sang phạm vi **TOÀN CỤC**: trong các bản ghi IsDeleted=0, IsHide=0,
  toàn hệ thống chỉ MUST có tối đa 1 template với IsDefault=1 tại một thời điểm. Khi người dùng
  đánh dấu Default cho một template (ở dialog Create hoặc TemplateBuilderPage), hệ thống MUST tự
  động bỏ cờ IsDefault trên template default cũ (bất kỳ template nào khác đang là default, không
  còn giới hạn theo vendor).
- **FR-041 (Update 13 — thay thế phần Vendor của FR-024)**: Panel cấu hình bên phải của
  **TemplateBuilderPage** MUST loại bỏ hoàn toàn combobox **Vendor** — panel chỉ còn các trường
  header: Code (readonly), Name, Alert for, Set as default. Vendor không còn là một trường của EUTR
  Template; việc gắn Vendor cho template được thực hiện riêng qua màn hình ApplyCustomerPage
  (FR-032 đến FR-038).
- **FR-042 (Update 13 — bug fix)**: Cột **Steps** trên TemplateListPage (FR-021, FR-021c) MUST hiển
  thị đúng số lượng step thật của mỗi template (đếm từ `eutr_template_details` đang hoạt động thuộc
  TemplateId đó) cho 100% bản ghi. Việc này cần rà soát và sửa toàn bộ đường dẫn dữ liệu từ backend
  đến hiển thị — bao gồm xác nhận endpoint danh sách đang dùng thực sự trả về trường `stepsCount`
  (từ subquery `StepsCount` trong `GetPagedWithVendorNameAsync`), cấu hình serialize JSON không làm
  mất/đổi tên trường này, và `TemplateListPage.jsx` đọc đúng `tmpl.stepsCount` — hiện tượng cột
  Steps hiển thị sai/trống dù cả backend lẫn frontend đã có phần code liên quan là một lỗi tồn tại
  cần được khắc phục dứt điểm, không chỉ dừng ở việc rà lại code hiện có.
- **FR-043 (Update 14)**: Toolbar của **ApplyCustomerPage** MUST bổ sung 2 nút **Import** và
  **Export**, cạnh nút Apply Vendor hiện có (FR-034).
- **FR-044 (Update 14)**: Nhấn nút **Export** MUST tải xuống một file Excel (.xlsx) chứa toàn bộ
  mapping hiện có (`eutr_template_references`) của template đang mở (theo TemplateId từ route),
  gồm đúng 4 cột theo thứ tự: **TemplateCode** (Code của template đang mở, lặp lại cho mọi dòng),
  **VendorCode**, **FromDate**, **ToDate**. Khi danh sách mapping rỗng, Export vẫn MUST trả về file
  .xlsx chỉ có dòng tiêu đề 4 cột trên (không có dòng dữ liệu) — file này dùng làm file mẫu
  ("file template") cho chức năng Import.
- **FR-045 (Update 14)**: Nhấn nút **Import** MUST mở hộp thoại chọn file, MUST chỉ chấp nhận file
  có định dạng Excel (.xlsx). Nếu người dùng chọn file không đúng định dạng .xlsx hoặc file không
  đủ 4 cột tiêu đề đúng tên (TemplateCode, VendorCode, FromDate, ToDate), hệ thống MUST từ chối
  ngay, hiển thị thông báo lỗi định dạng file, và KHÔNG xử lý bất kỳ dòng dữ liệu nào.
- **FR-046 (Update 14)**: Với mỗi dòng dữ liệu hợp lệ về định dạng trong file Import, hệ thống MUST
  validate theo đúng logic của dialog **Add Vendor** hiện hành (giống FR-034/FR-036): (1)
  TemplateCode của dòng phải khớp chính xác Code của template đang mở trên ApplyCustomerPage —
  không khớp thì dòng đó bị lỗi và bị bỏ qua; (2) VendorCode và FromDate không được để trống; (3)
  nếu có ToDate, ToDate phải >= FromDate; (4) khoảng FromDate-ToDate không được chồng lấn với mapping
  khác của CÙNG VendorCode trong CÙNG template — bao gồm cả mapping đã có sẵn trong
  `eutr_template_references` lẫn các dòng khác đã được tạo thành công từ CÙNG file Import (xử lý
  tuần tự theo thứ tự dòng). Mỗi dòng vượt qua toàn bộ validate MUST tạo một bản ghi MỚI trong
  `eutr_template_references` (TemplateId từ route, VendorCode/FromDate/ToDate từ dòng,
  CreatedBy/CreatedDate) — Import chỉ Add, KHÔNG cập nhật (update) mapping đã tồn tại kể cả khi
  trùng dữ liệu.
- **FR-047 (Update 14)**: Sau khi xử lý xong toàn bộ các dòng dữ liệu trong file Import, hệ thống
  MUST hiển thị kết quả chi tiết theo TỪNG dòng: dòng nào Import thành công (OK) và dòng nào bị lỗi
  kèm lý do cụ thể (ví dụ "TemplateCode không khớp", "VendorCode/FromDate trống", "ToDate nhỏ hơn
  FromDate", "Chồng lấn ngày với mapping hiện có"). Nếu file không có dòng dữ liệu nào (chỉ có dòng
  tiêu đề), hệ thống MUST hiển thị thông báo không có dữ liệu để import, không coi là lỗi hệ thống.
  Sau khi Import (có ít nhất 1 dòng thành công), bảng danh sách mapping trên ApplyCustomerPage MUST
  tự làm mới để hiển thị các mapping vừa Import thành công.
- **FR-048 (Update 14)**: Import và Export trên ApplyCustomerPage MUST chỉ thao tác trong phạm vi
  template đang mở (TemplateId từ route `/eutr/templates/apply/:id`) — không đọc hay ghi mapping
  của bất kỳ template nào khác, kể cả khi file Import có cột TemplateCode ghi mã của template khác
  (các dòng đó bị coi là lỗi theo FR-046, không được xử lý sang template tương ứng).
- **FR-049 (Update 15)**: Khi hệ thống lên version cho một template ở nhánh "trên 24 giờ" của
  FR-012 (tạo dòng mới trong eutr_templates với VersionId+1 và TemplateId mới, dòng cũ IsHide=1),
  hệ thống MUST đồng thời sao chép toàn bộ bản ghi hiện có trong `eutr_template_references` của
  TemplateId cũ sang TemplateId mới, giữ nguyên VendorCode/FromDate/ToDate/CreatedBy/CreatedDate
  của từng mapping. Nhánh "dưới 24 giờ" của FR-012 (cập nhật đè, TemplateId không đổi) KHÔNG cần
  thay đổi vì `eutr_template_references` vẫn đang liên kết đúng TemplateId hiện tại. Các bản ghi
  mapping cũ (gắn với TemplateId cũ, đã IsHide=1) MUST được giữ nguyên, không xóa hay di chuyển.
- **FR-050 (Update 15)**: Icon **Clone** trên mỗi dòng của TemplateListPage MUST trở thành hoạt
  động (không còn disabled — thay thế phần tương ứng của FR-026). Nhấn icon Clone MUST mở dialog
  popup **Clone Template**, sử dụng template của dòng đó làm nguồn (source template).
- **FR-051 (Update 15)**: Dialog **Clone Template** MUST hiển thị: thông tin định danh template
  nguồn (Code và/hoặc Name, chỉ đọc) để người dùng xác nhận đang clone đúng template, ô nhập **New
  template name** (textbox, bắt buộc), combobox **Alert for** (bắt buộc, single-select, cùng nguồn
  dữ liệu `GET /api/group-email` lọc GroupType=Alert(2)/IsAddition=false như dialog Create Template
  — FR-005c), cùng nút Cancel và nút xác nhận Clone.
- **FR-052 (Update 15)**: Khi người dùng đã nhập New template name (không trống) và chọn Alert for
  hợp lệ rồi nhấn nút xác nhận Clone, hệ thống MUST hiển thị một hộp thoại cảnh báo xác nhận riêng
  (ví dụ ConfirmDialog chuẩn của hệ thống) nêu rõ hành động sắp sao chép toàn bộ dữ liệu (step tree
  và vendor mapping) từ template nguồn sang template mới sắp tạo. Chỉ khi người dùng đồng ý ở hộp
  thoại này, hệ thống mới MUST thực hiện việc tạo template mới và sao chép dữ liệu theo FR-053. Nếu
  người dùng hủy ở hộp thoại xác nhận này, hệ thống KHÔNG tạo template mới, KHÔNG sao chép dữ liệu.
- **FR-053 (Update 15)**: Sau khi người dùng đồng ý ở hộp thoại xác nhận (FR-052), hệ thống MUST
  thực hiện đồng thời: (1) tạo một bản ghi mới trong eutr_templates với Code tự sinh mới (theo quy
  tắc hiện hành), Name = giá trị người dùng nhập, AlertFor = Id group đã chọn, VersionId=1,
  IsDefault=0 (luôn = 0 bất kể template nguồn), IsDeleted=0, IsHide=0; (2) sao chép toàn bộ cây bước
  từ `eutr_template_details` của template nguồn sang TemplateId mới, giữ nguyên StepId,
  RequirementType, TakeFrom, DisplayOrder cho từng step và ánh xạ đúng cấu trúc phân cấp ParentId
  sang các bản ghi mới; (3) sao chép toàn bộ mapping vendor từ `eutr_template_references` của
  template nguồn sang TemplateId mới, giữ nguyên VendorCode/FromDate/ToDate. Sau khi hoàn tất,
  dialog Clone MUST đóng lại, danh sách TemplateListPage MUST tự làm mới để hiển thị template mới,
  và hệ thống MUST hiển thị snackbar thông báo thành công.
- **FR-054 (Update 15)**: Nếu New template name để trống hoặc Alert for chưa chọn khi nhấn nút xác
  nhận Clone (FR-051), hệ thống MUST báo lỗi validate ngay tại dialog Clone và KHÔNG hiển thị hộp
  thoại xác nhận (FR-052), KHÔNG tạo bản ghi nào.

### Key Entities *(include if feature involves data)*

- **EUTR Template** *(Update 13: không còn gắn trực tiếp với vendor — xem EUTR Template
  Reference)*. Thuộc tính: định danh, Code (hệ thống tự sinh theo quy tắc prefix + số tăng dần,
  readonly — ví dụ Templates-001), Name, Is default, VersionId, AlertFor (Id tham chiếu đến
  `compl_group_email.Id` — KHÔNG còn là văn bản tự do; Name của group được hiển thị ở grid qua tra
  cứu), IsDeleted (cờ xóa mềm, 0=hiện/1=đã xóa), IsHide (cờ ẩn version cũ, 0=hiện/1=đã ẩn), người
  tạo, ngày tạo, người cập nhật, ngày cập nhật. **KHÔNG còn thuộc tính Vendor code** (loại bỏ theo
  FR-039, Update 13) — dữ liệu VendorCode cũ trên các bản ghi hiện có bị xóa hoàn toàn cùng cột,
  không migrate.
  Khi tạo mới, VersionId = 1. Khi edit: nếu bản ghi được tạo cách đây TRÊN 24 giờ (so với
  CreatedDate), tạo dòng mới với VersionId tự tăng (VersionId cũ + 1) và đánh dấu dòng cũ
  IsHide=1; nếu DƯỚI 24 giờ, cập nhật đè trực tiếp lên dòng hiện tại (giữ nguyên Id, VersionId,
  CreatedDate). Ràng buộc Is default (Update 13, FR-040): TOÀN CỤC chỉ tối đa 1 template
  IsDefault=1 tại một thời điểm (không còn giới hạn theo vendor). **(Update 15)** Khi tạo dòng
  version mới (nhánh trên 24 giờ), ngoài cây bước, hệ thống MUST đồng thời sao chép toàn bộ mapping
  `eutr_template_references` của TemplateId cũ sang TemplateId mới (xem FR-049). **(Update 15)**
  Template có thể được tạo mới thông qua **Clone** từ một template khác — template Clone luôn có
  VersionId=1, IsDefault=0, Code tự sinh riêng, hoàn toàn độc lập với template nguồn sau khi tạo
  (xem FR-050 đến FR-054).
- **EUTR Template Detail**: Đại diện cho một bước cụ thể trong cây bước của template. Thuộc tính:
  định danh, Template Id (liên kết đến template), Step Id (liên kết đến EUTR step), Parent Id
  (liên kết đến step cha hoặc 0 nếu gốc), RequirementType (Required=1/Optional=0),
  TakeFrom (PO=0/Upload manual=1), thứ tự hiển thị, người tạo, ngày tạo. Khi edit template,
  toàn bộ cây bước hiện tại (bao gồm step đã chỉnh sửa) được lưu vào TemplateId mới. ParentId
  MUST được lưu chính xác để duy trì cấu trúc cây đệ quy. Trên frontend, các hằng số biểu diễn
  RequirementType/TakeFrom (mảng options `{value, label}[]` cho combobox và map tra cứu label
  theo value) MUST được khai báo dùng chung tại `compliance-client/src/utils/helpers.js` (không
  khai báo cục bộ, trùng lặp trong từng component) để `StepTree.jsx`, `StepFormRow.jsx` và các
  chức năng khác trong hệ thống có thể tái sử dụng. **(Update 15)** Khi Clone một template, toàn bộ
  bản ghi `eutr_template_details` của template nguồn MUST được sao chép sang TemplateId mới, giữ
  nguyên StepId/RequirementType/TakeFrom/DisplayOrder và ánh xạ đúng cấu trúc ParentId sang các bản
  ghi mới (không tái sử dụng chung Id với bản ghi nguồn).
- **EUTR Step** (đã có sẵn — feature 001-eutr-steps): Danh sách các bước EUTR, được sử dụng làm
  nguồn dữ liệu cho combobox khi Add step/Edit step (free-solo). Khi người dùng nhập một tên step
  mới chưa tồn tại trong danh sách này và Save template, hệ thống MUST tự động tạo bản ghi mới
  trong bảng eutr_steps (người tạo/ngày tạo ghi nhận tự động như luồng tạo step thông thường của
  feature 001-eutr-steps), rồi dùng StepId mới cho eutr_template_details.
- **D365 Vendor (VendorsV3)**: Dữ liệu vendor từ hệ thống D365, sử dụng các cột dataAreaId,
  VendorAccountNumber và VendorOrganizationName. Truy cập qua API reference chung
  `POST /api/dynamics/reference` với `refType = 13` (ánh xạ tới D365 VendorsV3 trong cấu hình
  reference type có sẵn của hệ thống). *(Update 13: không còn dùng cho combobox Vendor trên
  TemplateBuilderPage — trường này bị loại bỏ — mà dùng cho combobox Vendor và tra cứu Vendor name
  trên màn hình **ApplyCustomerPage** mới, xem FR-034/FR-038.)*
- **EUTR Template Reference** *(mới — Update 13, bảng `eutr_template_references`)*: Đại diện cho
  một lần "apply" một template EUTR cho một Vendor cụ thể, có hiệu lực trong một khoảng thời gian.
  Thuộc tính: `id`, `TemplateId` (khóa ngoại tới `eutr_templates.Id`), `VendorCode`, `FromDate`,
  `ToDate`, `CreatedBy`, `CreatedDate`, `UpdatedBy`, `UpdatedDate` — tất cả các cột này đều NOT NULL
  theo thiết kế DB (`docs/design/eutr/eutr_db.sql`), khác với các bảng khác trong feature vốn cho
  phép NULL. Bảng KHÔNG có cột IsDeleted/cờ soft-delete — xóa một mapping là xóa thật (hard delete,
  FR-037). Một Template có thể có nhiều mapping tới nhiều Vendor khác nhau, và một Vendor có thể
  được map tới nhiều Template khác nhau (kể cả với khoảng thời gian chồng lấn — chỉ chồng lấn cùng
  vendor TRONG CÙNG một Template mới bị chặn, xem FR-036). VendorName hiển thị qua tra cứu API
  reference chung refType=13 dựa trên VendorCode (không lưu VendorName trực tiếp trong bảng này).
  **(Update 14)** Có thể Export hàng loạt các bản ghi này (thuộc một TemplateId) ra file Excel
  (.xlsx, 4 cột TemplateCode/VendorCode/FromDate/ToDate) và Import hàng loạt bản ghi mới từ cùng
  định dạng file này (chỉ Add, không Update), áp dụng đúng ràng buộc chồng lấn/bắt buộc như khi tạo
  thủ công qua dialog Add Vendor — xem FR-043 đến FR-048. **(Update 15)** Toàn bộ bản ghi thuộc một
  TemplateId MUST được sao chép tự động (không cần thao tác Export/Import thủ công) sang TemplateId
  mới trong 2 trường hợp: (1) khi template lên version ở nhánh trên 24 giờ (FR-049), và (2) khi
  Clone một template sang template mới (FR-053) — cả hai trường hợp đều giữ nguyên
  VendorCode/FromDate/ToDate của từng mapping, không kiểm tra chồng lấn giữa TemplateId nguồn và
  TemplateId mới (khác TemplateId nên không thuộc phạm vi kiểm tra chồng lấn của FR-036).
- **Compl Group Email** (đã có sẵn — bảng `compl_group_email`, quản lý qua
  `ComplGroupEmailController`): Đại diện cho một nhóm email. Thuộc tính liên quan: Id, Name,
  GroupType (Responsible=1/Alert=2), IsAddition (nhóm bổ sung/không hoạt động khi true). Combobox
  Alert for trên dialog Create Template và màn hình Edit Template MUST lấy dữ liệu từ `GET /api/group-email`, lọc
  GroupType=Alert(2) và IsAddition=false, hiển thị Name để chọn và lưu Id đã chọn vào cột AlertFor
  của EUTR Template. Grid EUTR Templates tra cứu Name của group này để hiển thị cột Alert for.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng tìm thấy và mở màn hình EUTR Templates trong vòng 10 giây kể từ khi
  vào hệ thống mà không cần hướng dẫn.
- **SC-002**: Người dùng tạo một template cơ bản (Name + Alert for + Set as default) qua dialog
  Create Template trong dưới 15 giây, không bị chặn bởi yêu cầu cấu hình Vendor hay cây bước ngay
  lúc tạo.
- **SC-003 (Superseded by Update 10 — cột Vendor name không còn trên danh sách, xem SC-009)**: Cột
  Vendor name trong grid hiển thị đúng tên vendor từ API reference chung
  (`POST /api/dynamics/reference`, refType=13) cho 100% bản ghi có Vendor code hợp lệ.
- **SC-004**: 100% thao tác tạo với Name hoặc Alert for trống bị chặn và hiển thị thông báo lỗi
  rõ ràng. Code luôn được hệ thống tự sinh chính xác.
- **SC-005**: Cây bước hỗ trợ ít nhất 3 cấp lồng nhau mà không bị lỗi hiển thị hay mất dữ liệu.
- **SC-006**: Mọi thao tác xóa đều yêu cầu xác nhận, không có trường hợp xóa nhầm do một cú nhấp.
- **SC-007**: Sau khi edit và save một template được tạo cách đây TRÊN 24 giờ, phiên bản cũ
  (IsHide=1) vẫn tồn tại trong database và phiên bản mới (VersionId tăng) hiển thị đúng trên
  grid. Sau khi edit và save một template được tạo cách đây DƯỚI 24 giờ, KHÔNG có dòng mới nào
  được tạo — dữ liệu được cập nhật đè lên dòng hiện có (VersionId và Id không đổi).
- **SC-008**: Template đã soft delete không bao giờ xuất hiện trên danh sách TemplateListPage,
  nhưng dữ liệu vẫn có thể truy vấn trực tiếp trong database để kiểm tra.
- **SC-009**: Combobox Vendor trên màn hình Edit (không xuất hiện ở dialog Create) hiển thị danh
  sách vendor từ API reference chung `POST /api/dynamics/reference` (refType=13) cho 100% lần mở.
  Vendor hiện tại được chọn sẵn chính xác nếu đã có, hoặc để trống nếu template chưa có Vendor.
  KHÔNG còn sử dụng endpoint riêng `GET /api/dynamics/vendors`.
- **SC-010**: 100% step được tạo với step cha (tick chọn trước khi Add step) lưu ParentId chính
  xác vào bảng eutr_template_details. Step gốc lưu ParentId = 0.
- **SC-011**: Người dùng chỉnh sửa step đã tạo (đổi step, RequirementType, TakeFrom) trong dưới
  10 giây thông qua icon Edit trên dòng step.
- **SC-012 (Cập nhật ở Update 10)**: Giao diện màn hình Edit (**TemplateBuilderPage**) hiển thị rõ
  ràng cây bước (tree-view) và panel cấu hình (bao gồm đầy đủ Code/Name/AlertFor/Vendor/Default)
  cùng lúc trên một màn hình, giúp người dùng làm việc với cả hai phần mà không cần điều hướng
  sang trang khác, và các trường header hiển thị đầy đủ không bị cắt. Dialog Create Template không
  dùng layout này (chỉ 3 trường đơn giản).
- **SC-013**: 100% lượt Edit một template được tạo dưới 24 giờ trước đó dẫn đến cập nhật đè lên
  dòng hiện tại (không tăng VersionId, không tạo dòng ẩn mới). 100% lượt Edit một template được
  tạo trên 24 giờ trước đó dẫn đến tạo version mới đúng theo cơ chế versioning hiện hành.
- **SC-014**: Nút Save luôn hiển thị ngay dưới checkbox "Set as default template" ở cột trái cho
  100% lần mở màn hình Edit.
- **SC-015**: 100% lượt nhấn Back khi có step chưa lưu (thêm mới hoặc chỉnh sửa) hiển thị cảnh
  báo xác nhận trước khi điều hướng; 100% lượt nhấn Back khi không có thay đổi chưa lưu điều
  hướng ngay lập tức không cảnh báo.
- **SC-016**: 100% step được nhập tự do (tên chưa có trong danh sách EUTR steps) khi Save ở màn
  hình Edit được tự động tạo thành bản ghi mới trong eutr_steps và xuất hiện ngay trong danh sách
  màn hình EUTR Steps, không yêu cầu người dùng rời khỏi màn hình Edit Template để tạo step trước.
- **SC-017**: 100% lần mở combobox Alert for (ở dialog Create Template hoặc màn hình Edit) hiển
  thị đúng danh sách Name của các group Alert (`GroupType=2`, `IsAddition=false`) từ
  `compl_group_email`; ở chế độ Edit, group hiện tại được chọn sẵn chính xác 100% số lần.
- **SC-018**: 100% template sau khi Save lưu đúng Id của group Alert for đã chọn vào cột
  `AlertFor`; 100% bản ghi hiển thị trên grid tra cứu và hiển thị đúng Name của group tương ứng
  (không hiển thị Id thô).
- **SC-019**: 100% dialog Create Template chỉ hiển thị 3 trường Name/Alert for/Set as default —
  không có Vendor, không có cây bước — và không tự động điều hướng sang màn hình Edit sau khi Save.
- **SC-020**: 100% template vừa được tạo qua dialog Create Template (0 step) khi mở màn hình Edit
  lần đầu cho phép thêm step đầu tiên và chọn Vendor thành công, không có lỗi hay hành vi khác biệt
  so với việc edit một template đã có sẵn step.
- **SC-021 (Update 10, làm rõ ở Update 11)**: 100% lượt gõ Code hoặc Name (khớp một phần, không
  phân biệt hoa/thường) vào ô tìm kiếm của TemplateListPage gọi lại API danh sách (server-side),
  reset về trang đầu tiên, và trả về đúng kết quả trên toàn bộ dữ liệu — kể cả bản ghi khớp nằm ở
  trang khác trước khi tìm kiếm.
- **SC-022 (Update 10)**: 100% dòng trong TemplateListPage hiển thị đúng Code ở vị trí chữ đậm và
  Name ở vị trí chữ phụ/caption — không có trường hợp hiển thị ngược hoặc thiếu.
- **SC-023 (Update 10)**: 100% lượt xóa hàng loạt (chọn nhiều dòng bằng checkbox rồi nhấn nút xóa
  hàng loạt) trên TemplateListPage yêu cầu xác nhận trước khi thực hiện, và cập nhật đúng
  IsDeleted=1 cho toàn bộ các template đã chọn.
- **SC-024 (Update 10)**: 100% lượt nhấn icon Edit trên TemplateListPage điều hướng đến
  TemplateBuilderPage với dữ liệu thật (không phải mock) được tải đúng cho template tương ứng.
- **SC-025 (Update 10)**: 100% icon Clone và Apply to Customer trên TemplateListPage hiển thị ở
  trạng thái disabled, không kích hoạt được hành động nào khi nhấn.
- **SC-026 (Update 11)**: 100% dòng trong TemplateListPage hiển thị đúng số lượng step thật (đếm từ
  `eutr_template_details` đang hoạt động của template đó) ở cột Steps — không có trường hợp hiển
  thị 0/để trống cho một template thực sự có step.
- **SC-027 (Update 12)**: Người dùng chọn và thêm ít nhất 5 step khác nhau vào cây bước (Root hoặc
  Child) chỉ trong 1 lần nhấn Add, thay vì phải mở lại dialog và nhấn Add 5 lần riêng biệt như cơ
  chế thêm-từng-step-một trước đây.
- **SC-028 (Update 12)**: 100% step được thêm qua dialog bulk-select nhận đúng ParentId (0 cho Root
  Group, Id step cha cho Child Step) và đúng Requirement Type/Take From đã cấu hình theo từng dòng
  tại thời điểm nhấn Add.
- **SC-029 (Update 12)**: 100% lượt mở dialog bulk-select mà chưa tick step nào và chưa nhập step
  tự do nào có nút Add ở trạng thái disabled; nút Add chỉ khả dụng khi có ít nhất 1 step đang chờ
  thêm (từ bảng master hoặc từ khu vực "Add new step").
- **SC-030 (Update 12)**: 100% step nhập tự do qua khu vực "Add new step" trong dialog bulk-select,
  sau khi Save template, được tự động tạo bản ghi mới trong eutr_steps (nếu tên chưa tồn tại) theo
  đúng cơ chế FR-007a hiện hành — không có trường hợp step tự do bị bỏ sót khi Save.
- **SC-031 (Update 13)**: 100% mapping vendor-template được tạo qua ApplyCustomerPage lưu đúng
  TemplateId, VendorCode, FromDate, ToDate vào `eutr_template_references` và hiển thị lại chính
  xác trên bảng danh sách của màn hình đó sau khi tải lại trang.
- **SC-032 (Update 13)**: 100% lượt tạo/sửa mapping với khoảng FromDate-ToDate chồng lấn với một
  mapping khác của CÙNG vendor trong CÙNG template bị chặn và báo lỗi rõ ràng; mapping chồng lấn
  giữa các template khác nhau cho cùng vendor không bị chặn.
- **SC-033 (Update 13)**: Sau khi loại bỏ VendorCode, không còn bất kỳ trường/cột/logic nào tham
  chiếu VendorCode trên `eutr_templates` trong toàn bộ mã nguồn backend/frontend của tính năng —
  ngoại trừ `eutr_template_references`, nơi VendorCode vẫn tồn tại theo đúng thiết kế mới.
- **SC-034 (Update 13)**: 100% lượt đánh dấu Default cho một template tự động bỏ cờ Default của
  bất kỳ template nào khác đang là default trên toàn hệ thống (không còn theo phạm vi vendor).
- **SC-035 (Update 13)**: 100% dòng trên TemplateListPage hiển thị đúng số lượng step thật (đếm từ
  `eutr_template_details` đang hoạt động) tại cột Steps sau khi fix — không còn tình trạng hiển thị
  sai/0 cho một template thực sự có step.
- **SC-036 (Update 14)**: 100% lượt Export trên ApplyCustomerPage tải xuống file .xlsx đúng 4 cột
  (TemplateCode, VendorCode, FromDate, ToDate) khớp chính xác với dữ liệu mapping đang hiển thị của
  template đang mở, kể cả khi danh sách mapping rỗng (file chỉ có dòng tiêu đề).
- **SC-037 (Update 14)**: 100% lượt Import chọn file không đúng định dạng .xlsx hoặc sai cấu trúc
  cột bị từ chối ngay với thông báo lỗi rõ ràng, không có dòng dữ liệu nào được xử lý.
- **SC-038 (Update 14)**: 100% lượt Import thành công hiển thị kết quả rõ ràng cho TỪNG dòng trong
  file (OK hoặc lỗi kèm lý do cụ thể), không có dòng nào bị xử lý âm thầm mà không có phản hồi.
- **SC-039 (Update 14)**: 100% dòng Import có TemplateCode không khớp template đang mở bị báo lỗi
  và không tạo mapping nào (cho cả template đang mở lẫn template khác); các dòng hợp lệ khác trong
  cùng file vẫn được Import thành công độc lập.
- **SC-040 (Update 15)**: 100% lượt lên version (nhánh trên 24 giờ của FR-012) sao chép đầy đủ và
  chính xác toàn bộ mapping vendor (`eutr_template_references`) từ TemplateId cũ sang TemplateId
  mới — không có mapping nào bị thiếu hoặc sai lệch sau khi Save.
- **SC-041 (Update 15)**: Icon Clone trên TemplateListPage không còn ở trạng thái disabled cho bất
  kỳ template nào hiển thị trên danh sách.
- **SC-042 (Update 15)**: 100% lượt Clone thành công tạo ra một template mới với Code riêng biệt,
  Name/Alert for đúng theo dữ liệu người dùng nhập, và sao chép chính xác 100% số step (kèm cấu
  trúc cha-con, RequirementType, TakeFrom) cùng 100% mapping vendor (VendorCode, FromDate, ToDate)
  từ template nguồn.
- **SC-043 (Update 15)**: 100% lượt Clone với New template name trống hoặc Alert for chưa chọn bị
  chặn ngay tại dialog, không hiển thị hộp thoại xác nhận và không tạo bản ghi nào.
- **SC-044 (Update 15)**: 100% lượt nhấn nút xác nhận Clone (sau khi nhập hợp lệ) hiển thị hộp
  thoại cảnh báo xác nhận trước khi thực sự sao chép dữ liệu; 100% lượt hủy ở hộp thoại xác nhận
  không tạo ra template mới hay thay đổi dữ liệu nào.

## Assumptions

- Backend API cho EUTR Templates chưa tồn tại; feature này cần xây dựng cả backend (CRUD cho
  eutr_templates + eutr_template_details) và frontend.
- D365 VendorsV3 đã được cấu hình sẵn dưới `refType = 13` trong API reference chung
  (`POST /api/dynamics/reference`), theo cùng cách các trường reference khác trong hệ thống sử
  dụng ReferenceObjectAutocomplete / `useReferenceObjects`. Frontend sử dụng lại API reference
  chung này cho combobox Vendor và tra cứu Vendor name, thay vì endpoint riêng
  `GET /api/dynamics/vendors` (đã thêm ở giai đoạn trước — Update 2/3 — nhưng nay không còn dùng
  cho mục đích này).
- EUTR Steps (feature 001) đã được triển khai và có API sẵn sàng để cung cấp dữ liệu cho
  combobox Add step/Edit step, cũng như API tạo step mới (được tái sử dụng để tự động tạo step khi
  người dùng nhập tên mới trên màn hình Edit Template — thao tác step chỉ khả dụng ở Edit).
- Quy tắc khớp tên step khi kiểm tra tồn tại: so khớp không phân biệt hoa/thường, đã trim khoảng
  trắng đầu/cuối. Nếu khớp với step đã có, dùng lại StepId đó; nếu không khớp, tạo step mới. Trong
  cùng một lần Save, các step trùng tên mới (chưa tồn tại) chỉ tạo 1 bản ghi step và dùng chung
  StepId để tránh trùng lặp dữ liệu trong eutr_steps.
- Người tạo/ngày tạo do hệ thống ghi tự động dựa trên người dùng đăng nhập.
- Edit template sử dụng cơ chế versioning có điều kiện theo tuổi bản ghi: nếu bản ghi được tạo
  cách đây TRÊN 24 giờ (so với CreatedDate), không sửa trực tiếp dòng cũ mà tạo dòng mới với
  VersionId+1, ẩn dòng cũ (IsHide=1), lưu template_details sang Id mới; nếu DƯỚI 24 giờ, cập nhật
  đè trực tiếp lên dòng hiện tại (không tạo dòng mới). Mốc 24 giờ được tính bằng
  `(thời điểm hiện tại - CreatedDate) so sánh với 24 giờ`, dùng giờ server (UTC hoặc giờ hệ thống
  nhất quán với các trường audit khác). Cơ chế này cân bằng giữa nhu cầu truy vết lịch sử thay
  đổi và tránh tạo quá nhiều version khi người dùng sửa nhanh liên tiếp ngay sau khi tạo.
- Dirty-tracking cho cảnh báo Back: trạng thái "có thay đổi chưa lưu" được xác định dựa trên việc
  cây bước (step tree) đã bị thay đổi so với lúc tải trang (thêm step mới, xóa step, hoặc chỉnh
  sửa step qua icon Edit) mà chưa nhấn Save template. Thay đổi trên các trường header
  (Name/AlertFor/Vendor/Default) mà không kèm thay đổi step thì theo yêu cầu hiện tại KHÔNG bắt
  buộc kích hoạt cảnh báo — phạm vi cảnh báo tập trung vào step tree vì đây là dữ liệu phức tạp,
  dễ mất công sức nhất khi rời trang.
- Delete template sử dụng soft delete (IsDeleted=1), không xóa dữ liệu thật.
- Grid chỉ hiển thị template có IsDeleted=0 VÀ IsHide=0 (phiên bản mới nhất chưa bị xóa).
- Một VendorCode có thể có nhiều template hoạt động đồng thời (không ràng buộc unique trên
  VendorCode). Ràng buộc IsDefault chỉ giới hạn tối đa 1 template default per VendorCode.
- Import sử dụng file Excel (.xlsx), theo cùng mẫu import đã có trong hệ thống (tương tự
  eutr-masters import). Format file và mapping cụ thể sẽ theo pattern của feature eutr-masters.
- Version (VersionId) là giá trị do hệ thống tự quản lý, mặc định bắt đầu từ 1.
- Code là giá trị do hệ thống tự sinh (readonly), theo quy tắc: prefix text + dấu phân cách +
  số tăng dần có padding (ví dụ: Templates-001, Templates-002). Prefix text và số chữ số
  (padding) sẽ được cấu hình từ một chức năng quản lý riêng phát triển sau. Ví dụ: nếu cấu hình
  padding = 3 thì số sẽ là 001, 002...; padding = 4 thì 0001, 0002... Trong giai đoạn chưa có
  chức năng cấu hình, hệ thống sử dụng giá trị mặc định (prefix = "Templates", padding = 3).
- Màn hình tuân theo cùng mẫu trải nghiệm của các màn CRUD hiện có trong hệ thống.
- Quyền truy cập từng thao tác sẽ được định nghĩa theo cùng pattern policy của các feature khác.
- Edit step là thao tác trên client-side (sửa giá trị trong state cây bước); thay đổi chỉ được
  persist khi nhấn Save template ở footer.
- Layout 2 cột sử dụng MUI Grid system (Grid container + Grid item) để chia đều hoặc theo tỷ lệ
  phù hợp, responsive trên màn hình desktop. Tỷ lệ cụ thể giữa cột trái (header) và cột phải
  (step tree) sẽ được xác định ở bước plan — yêu cầu là cột trái phải rộng hơn tỷ lệ hiện tại và
  cột phải hẹp hơn tương ứng.
- Combobox Alert for tái sử dụng API/backend đã có sẵn: `GET /api/group-email` (all) từ
  `ComplGroupEmailController` (bảng `compl_group_email`), và tái sử dụng pattern frontend đã tồn
  tại cho việc chọn nhóm "Alert" (ví dụ `GetAllGroupEmailUseCase` qua `repositories.groupEmail`,
  lọc theo `groupEmailType.ALERT` (=2) và `isAddition === false`) tương tự các form khác trong hệ
  thống (`ComplianceMasterForm`, `MasterDefaultForm`). Khác với các form đó (cho phép chọn nhiều
  group Alert vào một bảng liên kết), Alert for của EUTR Template là single-select và lưu trực
  tiếp một Id vào cột `AlertFor` (không dùng bảng liên kết nhiều-nhiều).
- Cột `AlertFor` trong bảng `eutr_templates` đổi ý nghĩa từ văn bản tự do (free text) thành khóa
  tham chiếu (Id, kiểu số) đến `compl_group_email.Id`. Cần migration/điều chỉnh kiểu dữ liệu cột
  này ở bước plan nếu cột hiện tại đang là kiểu văn bản (nvarchar) trong schema đã triển khai.
- Nếu group đang được chọn làm AlertFor của một template sau đó bị xóa (soft delete) khỏi
  `compl_group_email`, template vẫn giữ nguyên Id cũ trong AlertFor (không tự động cập nhật);
  grid hiển thị trống ở cột Alert for cho các bản ghi này cho đến khi người dùng Edit và chọn lại
  group khác còn hoạt động.
- Dialog **Create Template** (Bước 1) dùng component Dialog/Modal tiêu chuẩn của hệ thống (tương tự
  các dialog xác nhận/tạo nhanh khác đã có), không phải một trang điều hướng riêng — lựa chọn này
  theo đúng tham chiếu thiết kế `TemplateListPage.jsx` (dùng MUI Dialog cho thao tác tạo nhanh) và
  khớp với mô tả "chỉ cần hiện thông tin Name, alert for, set as default" trong yêu cầu gốc.
- Trường **Vendor** bị loại khỏi dialog Create Template hoàn toàn (không phải optional-nhưng-ẩn) vì
  yêu cầu gốc chỉ liệt kê 3 trường (Name, Alert for, Set as default) cho bước tạo nhanh; Vendor chỉ
  được thêm/sửa ở màn hình Edit — đây là suy luận hợp lý từ yêu cầu, không phải xác nhận tường minh
  từ người dùng.
- Sau khi Save dialog Create Template thành công, hệ thống KHÔNG tự động điều hướng sang màn hình
  Edit; người dùng phải tự nhấn Edit trên danh sách để tiếp tục thêm Vendor/step — khớp đúng với mô
  tả "lần 2 khi nhấn vào Edit mới thêm sửa steps" trong yêu cầu gốc.
- Việc đổi tên trang danh sách thành **TemplateListPage** là thay đổi tổ chức/đặt tên component
  theo tham chiếu thiết kế, giữ nguyên 2-bước Create/Edit đã nêu ở Update 9. *(Update 10 — 2026-07-13
  — đảo ngược phần quyết định về giao diện: bộ cột grid/Action ở Update 9 KHÔNG còn áp dụng; xem
  FR-021/FR-021a/FR-021b/FR-026 cho quyết định giao diện Table + chip + Clone/Apply disabled mới.)*
- **(Update 10)** TemplateListPage.jsx và TemplateBuilderPage.jsx là 2 file giao diện tham khảo có
  sẵn trong mã nguồn hiện tại (`compliance-client/src/presentation/pages/eutr-templates/`), hiện
  đang dùng dữ liệu mock (`mock/eutrTemplates.js`, `mock/eutrTemplateDetails.js`, `mock/eutrSteps.js`).
  Route `eutr-templates` và `/eutr/templates/edit/:id` trong `RouteResolver.jsx`/`MainRoutes.jsx` đã
  trỏ sẵn tới 2 component này. Phạm vi của Update 10 là thay dữ liệu/luồng nghiệp vụ mock trong 2
  file này bằng dữ liệu/luồng thật, tái sử dụng lại các use case, hook và component đã viết ở
  `TemplateListPageOld.jsx` và `EutrTemplatesAddEdit.jsx` — KHÔNG viết lại giao diện tree-view/table
  từ đầu.
- **(Update 10, làm rõ ở Update 11)** Số lượng step (cột Steps trên TemplateListPage) MUST là số
  liệu thật, thuộc phạm vi backend của đợt cập nhật này (xem FR-021c) — API danh sách MUST được mở
  rộng để trả về số này kèm mỗi template. Đây KHÔNG còn là giá trị mặc định 0/để trống vô thời hạn
  như ghi chú ban đầu ở Update 10 (đã được làm rõ và thay thế ở Update 11).
- **(Update 11)** Ô tìm kiếm Code/Name trên TemplateListPage là server-side: mở rộng API/hook danh
  sách hiện có (`useEutrTemplatesData`, `GetEutrTemplatesUseCase`) với một tham số từ khóa (khớp
  một phần Code HOẶC Name, không phân biệt hoa/thường), tương tự cách `filterModel` hiện tại được
  gửi lên server, nhưng là một trường tìm kiếm tự do duy nhất thay vì filter theo từng cột riêng
  lẻ của DataGrid.
- **(Update 12)** Component `StepFormRow.jsx` (form free-solo add-1-step hiện tại) có thể được tái
  sử dụng làm khu vực "Add new step" trong dialog bulk-select mới (chi tiết triển khai cụ thể được
  quyết định ở bước `/speckit-plan`), thay vì viết lại từ đầu — miễn là hành vi cuối cùng khớp với
  FR-030 (nhập tên tự do, cấu hình Requirement Type/Take From, gộp vào danh sách "đang chờ thêm"
  cùng với các step đã tick từ bảng master).
- **(Update 10)** Icon Clone và Apply to Customer trên TemplateListPage chỉ cần hiển thị ở trạng
  thái disabled (ví dụ `disabled` prop trên IconButton), không cần xử lý onClick hay gọi API nào —
  đúng theo lựa chọn "giữ lại nhưng vô hiệu hóa" đã xác nhận.
- **(Update 12)** Danh sách "step available" trong dialog bulk-select lấy từ cùng nguồn dữ liệu
  EUTR steps master đã dùng cho combobox free-solo trước đây (`GetEutrStepsUseCase`, feature
  001-eutr-steps) — không phải một API/bảng mới. Giá trị mặc định khi một dòng vừa được tick chọn:
  Requirement Type = Optional (0), Take From = PO (0) — giữ đúng giá trị mặc định hiện hành của
  `stepForm` (`requirementType ?? 0`, `takeFrom ?? 0`), người dùng có thể đổi lại trước khi nhấn Add.
  Cột "Step Master" hiển thị mã step (nếu EUTR step có trường mã, ví dụ P1/P2...) kèm tên step; nếu
  dữ liệu step hiện tại chưa có trường mã riêng, cột này hiển thị tên step (không chặn tính năng vì
  thiếu mã).
- **(Update 13)** Dữ liệu VendorCode hiện có trên các bản ghi `eutr_templates` bị xóa hoàn toàn khi
  bỏ cột — không backfill sang `eutr_template_references` — theo quyết định đã xác nhận. Người
  dùng cần tự apply lại vendor cho từng template (nếu cần thiết lập lại liên kết) qua màn hình
  Apply to Customer mới sau khi triển khai.
- **(Update 13)** Ràng buộc "duy nhất 1 template Default" chuyển từ phạm vi theo VendorCode sang
  phạm vi toàn cục — vì Vendor không còn là thuộc tính của EUTR Template.
- **(Update 13)** Route cho màn hình ApplyCustomerPage đề xuất là `/eutr/templates/apply/:id`, theo
  cùng pattern route hiện có `/eutr/templates/edit/:id` (TemplateBuilderPage) trong
  `MainRoutes.jsx`; giá trị route chính xác sẽ được chốt ở bước `/speckit-plan`.
  `compliance-client/src/presentation/pages/eutr-templates/ApplyCustomerPage.jsx` hiện đã tồn tại
  như một giao diện tham khảo dùng dữ liệu mock (khái niệm "Customer"/`MOCK_CUSTOMERS`/
  `MOCK_TEMPLATE_CUSTOMERS` từ `mock/eutrTemplates.js`, và cờ `template.status !== 'Published'` để
  khóa nút Apply) — phạm vi Update 13 là thay dữ liệu mock này bằng dữ liệu/luồng thật: đổi khái
  niệm "Customer" sang "Vendor" (nạp qua API reference refType=13 thay vì `MOCK_CUSTOMERS`), bỏ điều
  kiện khóa theo `status`/`Published` (EUTR Template thật không có khái niệm Status), và lưu/tải
  qua backend CRUD mới cho `eutr_template_references` thay vì state cục bộ trong component. Logic
  kiểm tra chồng lấn ngày (`hasOverlap`) đã có trong file này được tái sử dụng gần như nguyên vẹn,
  chỉ đổi phạm vi so sánh từ "cùng customerId" sang "cùng VendorCode trong cùng TemplateId".
- **(Update 13)** Bảng `eutr_template_references` hoàn toàn chưa có backend (entity, DTO,
  repository, service, controller) — cần xây dựng mới từ đầu (CRUD: get-by-template, create,
  update, delete), theo cùng pattern Dapper/MySQL đã dùng cho `eutr_templates`/
  `eutr_template_details` trong feature này (ví dụ `EutrTemplatesRepository`/
  `EutrTemplatesController`).
- **(Update 13)** Bug cột Steps (FR-042): nguyên nhân gốc chưa được xác định chắc chắn tại bước
  đặc tả này (backend `StepsCount` subquery và frontend `tmpl.stepsCount` đều đã có mặt trong mã
  nguồn hiện tại) — việc xác định nguyên nhân chính xác (ví dụ: endpoint controller có gọi đúng
  `GetPagedWithVendorNameAsync` hay không, cấu hình serialize JSON, dữ liệu build/deploy chưa cập
  nhật) thuộc phạm vi điều tra ở bước `/speckit-plan`/`/speckit-implement`.
- **(Update 14)** File Import/Export mapping vendor MUST dùng cùng cơ chế đọc/ghi file Excel
  (.xlsx) đã có sẵn trong hệ thống cho các chức năng import/export khác (ví dụ pattern tương tự
  eutr-masters import đã nêu ở Assumption trước đó) — không cần thêm thư viện mới. Export khi
  danh sách mapping đang rỗng vẫn MUST trả về file .xlsx chỉ có dòng tiêu đề (header), qua đó file
  Export cũng đóng vai trò là "file template" mẫu cho người dùng tải về, điền dữ liệu rồi Import
  lại — giải quyết đúng ý "file template" nêu trong yêu cầu gốc mà không cần một endpoint tải
  template riêng biệt.
- **(Update 14)** Yêu cầu gốc ghi "file template gồm 2 cột" nhưng liệt kê 4 tên cột (TemplateCode,
  VendorCode, FromDate, ToDate) — xử lý theo 4 cột đã liệt kê tên cụ thể (số "2" trong câu gốc được
  hiểu là nhầm lẫn diễn đạt, không phải giới hạn số cột thực tế).
- **(Update 14)** Import KHÔNG hỗ trợ cập nhật (update) mapping đã tồn tại — mọi dòng hợp lệ trong
  file Import đều tạo bản ghi MỚI trong `eutr_template_references` ("Logic giống như Add" theo yêu
  cầu gốc, tức là tái sử dụng validate của FR-034/FR-036, không tái sử dụng nhánh Edit/FR-035).
  Nếu người dùng Import cùng một cặp Vendor/khoảng ngày nhiều lần, các lần sau sẽ bị chặn bởi kiểm
  tra chồng lấn (overlap) như một dòng lỗi, không tự động cập nhật đè.
- **(Update 15)** Dialog Clone Template chỉ gồm 2 trường nhập liệu — **New template name** và
  **Alert for** — theo đúng yêu cầu gốc ("có ô cho user nhập tên template mới, alert for"). Trường
  **Set as default** (có ở dialog Create Template) KHÔNG xuất hiện ở dialog Clone vì yêu cầu gốc
  không đề cập; template Clone luôn IsDefault=0 mặc định (xem SC-042).
  Vendor/step tree KHÔNG hiển thị trực tiếp trong dialog Clone — người dùng chỉ xác nhận Name/Alert
  for rồi hệ thống tự sao chép toàn bộ dữ liệu còn lại (step tree, vendor mapping) từ template
  nguồn ở backend, không cho phép chỉnh sửa/xem trước dữ liệu sẽ sao chép ngay trong dialog này.
- **(Update 15)** "Toàn bộ dữ liệu template cũ" khi Clone được hiểu là bao gồm cả
  `eutr_template_details` (cây bước) lẫn `eutr_template_references` (mapping vendor) — suy luận từ
  việc yêu cầu gốc nhắc đến `eutr_template_references` ngay trong cùng câu mô tả tính năng Clone.
  KHÔNG bao gồm việc sao chép Code (Code luôn tự sinh mới, không copy từ nguồn) hay VersionId (luôn
  = 1 cho template Clone, không kế thừa VersionId của nguồn).
  StepId của các step trong cây bước được sao chép nguyên trạng (dùng lại StepId đã có trong
  `eutr_steps`, không tạo bản ghi step mới trong quá trình Clone).
- **(Update 15)** Hộp thoại cảnh báo xác nhận trước khi Clone (FR-052) sử dụng component
  `ConfirmDialog` chuẩn đã có sẵn trong hệ thống (cùng loại dùng cho xác nhận Delete), không cần
  xây dựng component cảnh báo mới riêng cho tính năng này.
- **(Update 15)** Việc sao chép `eutr_template_references` khi lên version (FR-049) và khi Clone
  (FR-053) đều là thao tác backend thực hiện trong cùng transaction với việc tạo TemplateId
  mới/eutr_template_details mới, đảm bảo tính nhất quán dữ liệu (không có trường hợp tạo template
  mới thành công nhưng thiếu step hoặc thiếu mapping do lỗi giữa chừng).
