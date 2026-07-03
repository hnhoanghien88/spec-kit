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

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem danh sách EUTR Templates (Priority: P1)

Người dùng vào mục **EUTR system > EUTR templates** từ thanh điều hướng trái và thấy bảng liệt kê
các template EUTR. Bảng hiển thị Code, Name, Vendor code, Vendor name, Alert for, Is default,
Version, Created by, Created date. Cột Vendor name được tra cứu từ API riêng `GET /api/dynamics/vendors` (query D365 VendorsV3)
dựa trên Vendor code. Người dùng có thể chuyển trang khi danh sách dài.

**Why this priority**: Đây là giá trị cốt lõi — xem và tra cứu danh sách template hiện có là thao
tác đầu tiên người dùng cần trước khi thực hiện bất kỳ hành động nào khác.

**Independent Test**: Mở màn hình, xác nhận bảng tải đúng dữ liệu với vendor name được hiển thị
chính xác từ API vendors, chuyển trang và thấy trang kế tiếp.

**Acceptance Scenarios**:

1. **Given** đang ở mục EUTR system, **When** chọn "EUTR templates" ở thanh trái, **Then** thấy
   breadcrumb "EUTR system > EUTR templates" và bảng với đầy đủ 9 cột.
2. **Given** danh sách có template với Vendor code hợp lệ, **When** bảng hiển thị, **Then** cột
   Vendor name hiển thị đúng VendorOrganizationName tương ứng từ API vendors.
3. **Given** danh sách vượt quá một trang, **When** chọn số trang khác, **Then** bảng hiển thị
   các bản ghi của trang đó.

---

### User Story 2 - Tạo template mới với cây bước đệ quy (Priority: P1)

Người dùng nhấn **Add** trên toolbar, hệ thống chuyển sang màn hình tạo mới (không phải popup)
với breadcrumb "EUTR system > EUTR templates > Add". Màn hình được chia thành **2 cột** với cột
trái được mở rộng và cột phải thu hẹp hơn so với trước: cột trái chứa form thông tin header (Code,
Name, Alert for, Vendor, Default, và nút **Save** đặt ngay dưới checkbox Default), cột phải chứa
cây bước (step tree) và các thao tác trên step. Người dùng nhập thông tin header (Name, Alert for, chọn
Vendor từ API vendors, đánh dấu Default) — trường Code do hệ thống tự sinh theo quy tắc prefix
+ số tăng dần (ví dụ: Templates-001) và hiển thị readonly. Combobox Vendor MUST gọi API riêng
`GET /api/dynamics/vendors` để hiển thị danh sách vendor (VendorAccountNumber +
VendorOrganizationName). Sau đó xây dựng cây
bước bằng cách nhấn **Add step** nhiều lần. Mỗi step được chọn từ danh sách EUTR steps đã có,
gán loại yêu cầu (Required/Optional) và nguồn lấy tài liệu (PO/Upload manual). Nếu tick chọn
một step cha trước khi Add step, step mới sẽ là con của step đó (tạo cấu trúc đệ quy) — ParentId
MUST được lưu chính xác vào bảng eutr_template_details. Người dùng có thể **chỉnh sửa step đã
tạo** bằng cách nhấn icon Edit trên dòng step để đổi step, RequirementType hoặc TakeFrom. Cuối
cùng nhấn **Save** (dưới checkbox Default, cột trái) để lưu template cùng toàn bộ cây bước. Nếu
người dùng nhấn **Back** ở thanh tiêu đề trong khi đã thêm/sửa step mà chưa Save, hệ thống MUST
hiển thị cảnh báo xác nhận trước khi rời trang — nếu xác nhận rời đi, các thay đổi step chưa lưu
sẽ bị mất.

**Why this priority**: Tạo template là nghiệp vụ chính của màn hình — template định nghĩa cấu trúc
các bước EUTR cho từng vendor, là dữ liệu nền tảng cho quy trình EUTR.

**Independent Test**: Nhấn Add, xác nhận Code được tự sinh (readonly), xác nhận layout 2 cột với
cột trái rộng hơn cột phải và nút Save nằm dưới checkbox Default, nhập đầy đủ header với Vendor từ
API vendors, thêm vài step (cả gốc và con), edit một step đã tạo, lưu, và xác nhận template mới
xuất hiện trong danh sách với Code đúng định dạng, cây bước đúng cấu trúc, và ParentId được lưu
chính xác. Thêm step rồi nhấn Back mà chưa Save — xác nhận hệ thống cảnh báo trước khi rời trang.

**Acceptance Scenarios**:

1. **Given** đang ở danh sách template, **When** nhấn Add, **Then** chuyển sang màn hình tạo mới
   với breadcrumb "EUTR system > EUTR templates > Add", giao diện chia 2 cột với cột trái (Code
   readonly + Name + AlertFor + Vendor + Default + nút Save) rộng hơn cột phải (cây bước + thao
   tác step).
2. **Given** đang ở màn hình tạo mới, **When** mở combobox Vendor, **Then** hệ thống gọi API
   `GET /api/dynamics/vendors` và hiển thị danh sách vendor gồm VendorAccountNumber và
   VendorOrganizationName.
2a. **Given** đang ở màn hình tạo mới hoặc chỉnh sửa, **When** quan sát cột trái, **Then** nút
   Save hiển thị ngay bên dưới checkbox "Set as default template", KHÔNG còn ở thanh tiêu đề.
2b. **Given** đã thêm một step mới vào cây bước nhưng CHƯA nhấn Save, **When** nhấn nút Back ở
   thanh tiêu đề, **Then** hệ thống hiển thị hộp thoại cảnh báo xác nhận có thay đổi chưa lưu,
   cho phép chọn "Leave" (rời đi, mất thay đổi) hoặc "Cancel" (ở lại trang).
2c. **Given** đã chỉnh sửa (Edit) một step trong cây nhưng CHƯA nhấn Save, **When** nhấn Back,
   **Then** hệ thống hiển thị cùng cảnh báo như 2b.
2d. **Given** chưa thêm/sửa step nào (hoặc đã Save toàn bộ thay đổi), **When** nhấn Back, **Then**
   hệ thống điều hướng thẳng về danh sách mà KHÔNG hiển thị cảnh báo.
3. **Given** đã nhập header và chưa chọn step nào, **When** nhấn Add step, chọn step, gán
   Required và PO, rồi Save step, **Then** step xuất hiện ở gốc cây (ParentId = 0).
4. **Given** đã có step "Forest" ở gốc và tick chọn nó, **When** nhấn Add step, chọn step khác,
   **Then** step mới xuất hiện là con của "Forest" trong cây (lưu ParentId = Id của Forest).
5. **Given** cây bước có nhiều cấp, **When** người dùng collapse/expand một nhánh, **Then** cây
   ẩn/hiện các step con tương ứng.
5a. **Given** cây bước có nhiều step cùng cấp, **When** người dùng kéo thả (drag-and-drop) một
   step đến vị trí khác trong cùng cấp, **Then** thứ tự step được cập nhật và DisplayOrder thay
   đổi tương ứng.
6. **Given** đã tạo step "Forest" với Required + PO, **When** nhấn icon Edit trên dòng "Forest",
   **Then** dòng step chuyển sang chế độ chỉnh sửa hiển thị combobox Step, combobox
   RequirementType, combobox TakeFrom với giá trị hiện tại được chọn sẵn.
6a. **Given** đang ở chế độ chỉnh sửa step "Forest", **When** đổi RequirementType sang Optional,
   đổi TakeFrom sang Upload manual, và nhấn Save, **Then** step cập nhật giá trị mới trên cây.
6b. **Given** đang ở chế độ chỉnh sửa step, **When** đổi step khác từ combobox (ví dụ đổi từ
   "Forest" sang "Transport"), **Then** step hiển thị tên mới và StepId cập nhật tương ứng.
6c. **Given** đang ở chế độ chỉnh sửa step, **When** nhấn Cancel, **Then** step giữ nguyên giá
   trị cũ và thoát chế độ chỉnh sửa.
7. **Given** đã nhập đầy đủ thông tin, **When** nhấn Save ở footer, **Then** hệ thống lưu header
   vào bảng eutr_templates và các step vào bảng eutr_template_details (bao gồm ParentId chính xác
   cho từng step), rồi quay về danh sách.
8. **Given** đang ở màn hình tạo mới, **When** để trống Name hoặc Alert for và nhấn Save,
   **Then** hệ thống báo lỗi và không lưu (Code do hệ thống tự sinh nên không cần kiểm tra).

---

### User Story 3 - Chỉnh sửa template (Priority: P2)

Người dùng nhấn **Edit** trên một dòng trong grid, hệ thống chuyển sang màn hình chỉnh sửa
(cùng layout 2 cột với màn hình Add) với dữ liệu template hiện tại được tải sẵn. Combobox Vendor
MUST gọi API riêng `GET /api/dynamics/vendors` và hiển thị vendor hiện tại được chọn sẵn. Người dùng có thể chỉnh
sửa header (Name, Alert for, Vendor, Default — Code là readonly), thêm/xóa step trong cây bước,
và **chỉnh sửa step đã có** (đổi step, RequirementType, TakeFrom). Khi nhấn Save, hệ thống áp
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

**Independent Test**: Nhấn Edit trên một template, xác nhận Vendor hiển thị đúng từ API vendors, thay
đổi step (edit step đã có + thêm/xóa), lưu, và xác nhận: nếu template được tạo trên 24h, dòng cũ
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
   `GET /api/dynamics/vendors` và hiển thị danh sách vendor, với vendor hiện tại được chọn sẵn.

---

### User Story 4 - Xóa template (soft delete) (Priority: P2)

Người dùng nhấn **Delete** trên một dòng trong grid, xác nhận, và template biến mất khỏi danh
sách. Hệ thống **không xóa dữ liệu thật** mà chỉ cập nhật cờ IsDeleted = 1. Dữ liệu vẫn tồn
tại trong database để truy vết.

**Why this priority**: Dọn dẹp template không còn dùng là cần thiết nhưng ít rủi ro nếu triển
khai sau tạo và xem. Soft delete đảm bảo không mất dữ liệu.

**Independent Test**: Nhấn Delete trên một dòng, xác nhận, kiểm tra dòng biến mất khỏi grid
nhưng dữ liệu vẫn còn trong database với IsDeleted=1.

**Acceptance Scenarios**:

1. **Given** một template tồn tại, **When** nhấn Delete và xác nhận, **Then** template biến mất
   khỏi grid, dữ liệu trong database được cập nhật IsDeleted=1 (không xóa thật).
2. **Given** hộp thoại xác nhận xóa hiện ra, **When** người dùng hủy, **Then** không có template
   nào bị thay đổi.
3. **Given** template đã bị soft delete (IsDeleted=1), **When** tải danh sách, **Then** template
   đó không xuất hiện trong grid.

---

### User Story 5 - Import templates (Priority: P3)

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

### Edge Cases

- Khi danh sách rỗng, bảng hiển thị trạng thái "No data" thay vì lỗi.
- Khi Vendor code trong template không tìm thấy qua API vendors, cột Vendor name hiển thị trống
  hoặc giá trị mặc định, không gây lỗi cả bảng.
- Khi người dùng cố tạo step con lồng nhiều cấp, cây vẫn hiển thị và hoạt động đúng đệ quy.
- Khi danh sách EUTR steps rỗng (chưa tạo step nào), combobox Add step hiển thị trống và người
  dùng nhận được thông báo cần tạo step trước.
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

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hệ thống MUST hiển thị danh sách EUTR templates dạng bảng với các cột: Code, Name,
  Vendor code, Vendor name, Alert for, Is default, Version, Created by, Created date và cột
  Action (Edit, Delete). Grid chỉ hiển thị các template có IsDeleted = 0 VÀ IsHide = 0.
- **FR-002**: Cột Vendor name MUST được tra cứu từ API riêng `GET /api/dynamics/vendors`
  (dedicated endpoint query D365 VendorsV3) dựa trên VendorAccountNumber = Vendor code của
  template. KHÔNG sử dụng API reference chung (`POST /api/dynamics/reference`).
- **FR-003**: Hệ thống MUST phân trang danh sách khi số bản ghi vượt một trang và cho phép
  chuyển trang.
- **FR-004**: Khi nhấn Add, hệ thống MUST chuyển sang màn hình tạo mới (trang riêng, không popup)
  với breadcrumb "EUTR system > EUTR templates > Add".
- **FR-004a**: Màn hình Add/Edit MUST chia thành **2 cột**: cột trái chứa form thông tin header
  (Code, Name, AlertFor, Vendor, Default, nút Save), cột phải chứa cây bước (step tree) và các
  thao tác trên step (Add step, Edit step, Delete step). Hai cột hiển thị song song trên cùng một
  hàng. Cột trái MUST được mở rộng chiều ngang hơn (so với thiết kế trước) và cột phải MUST được
  thu hẹp lại tương ứng, để trường nhập liệu Code/Name/AlertFor/Vendor có đủ không gian hiển thị.
- **FR-005**: Màn hình tạo mới MUST có form header (cột trái) gồm: Code (textbox, readonly — hệ
  thống tự sinh theo quy tắc prefix + số tăng dần, ví dụ Templates-001; prefix và số chữ số
  được cấu hình từ chức năng riêng phát triển sau), Name (textbox, bắt buộc), Alert for (textbox,
  bắt buộc), Vendor (combobox từ API `GET /api/dynamics/vendors` hiển thị VendorAccountNumber +
  VendorOrganizationName, tùy chọn — có thể bỏ trống), Default (checkbox).
- **FR-005b**: Combobox Vendor MUST gọi API riêng `GET /api/dynamics/vendors` (dedicated
  endpoint) để lấy danh sách vendor, thay vì sử dụng API reference chung
  (`POST /api/dynamics/reference` với refType). Khi mở combobox, hệ thống MUST hiển thị danh
  sách VendorAccountNumber + VendorOrganizationName từ endpoint vendors. Ở chế độ Edit, vendor
  hiện tại của template MUST được chọn sẵn trong combobox. Frontend MUST loại bỏ component
  ReferenceObjectAutocomplete cho trường Vendor và thay bằng component gọi trực tiếp endpoint
  vendors mới (hỗ trợ phân trang, tìm kiếm theo VendorAccountNumber hoặc VendorOrganizationName).
- **FR-005a**: Mỗi VendorCode chỉ MUST có tối đa 1 template với IsDefault = 1 (trong các bản ghi
  IsDeleted=0, IsHide=0). Khi người dùng đánh dấu Default cho một template, hệ thống MUST tự động
  bỏ cờ IsDefault trên template default cũ cùng VendorCode (nếu có).
- **FR-006**: Hệ thống MUST hiển thị cây bước (step tree) đệ quy ở phần body, hỗ trợ
  collapse/expand từng nhánh và drag-and-drop để sắp xếp lại thứ tự step trong cùng cấp.
  DisplayOrder MUST được cập nhật tự động theo vị trí kéo thả.
- **FR-007**: Khi nhấn Add step, hệ thống MUST hiển thị form chọn step gồm: combobox step (từ
  danh sách EUTR steps), combobox RequirementType (Required/Optional), combobox TakeFrom
  (PO/Upload manual), và nút Save.
- **FR-008**: Nếu người dùng tick chọn một step cha trước khi Add step, step mới MUST là con của
  step đó (ParentId = Id của step cha). Nếu không chọn, step mới MUST là gốc (ParentId = 0).
- **FR-008a**: Người dùng MUST có thể xóa step khỏi cây bước bằng hai cách: (1) nhấn icon xóa
  (X) trên dòng step để xóa đơn lẻ, hoặc (2) tick checkbox chọn một hoặc nhiều step rồi nhấn
  nút "Delete step" để xóa hàng loạt. Khi xóa step cha, toàn bộ step con MUST bị xóa theo.
- **FR-008b**: Người dùng MUST có thể chỉnh sửa step đã tạo trong cây bước bằng cách nhấn icon
  Edit (bút chì) trên dòng step. Khi nhấn Edit, dòng step MUST chuyển sang chế độ chỉnh sửa
  hiển thị: combobox Step (cho phép đổi sang step khác), combobox RequirementType
  (Required/Optional) với giá trị hiện tại được chọn sẵn, combobox TakeFrom (PO/Upload manual)
  với giá trị hiện tại được chọn sẵn, nút Save (xác nhận thay đổi) và nút Cancel (hủy, giữ giá
  trị cũ). Sau khi Save, dòng step MUST cập nhật giá trị mới trên cây mà không cần nhấn Save
  template.
- **FR-009**: Khi nhấn Save (đặt ngay dưới checkbox "Set as default template" ở cột trái, tạo
  mới), hệ thống MUST lưu thông tin header vào bảng eutr_templates (Code, Name, VendorCode,
  IsDefault, VersionId=1, AlertFor, IsDeleted=0, IsHide=0) và lưu từng step trong cây vào bảng
  eutr_template_details (TemplateId, StepId, ParentId, RequirementType, TakeFrom, DisplayOrder).
  ParentId MUST được lưu chính xác: step gốc lưu ParentId = 0, step con lưu ParentId = Id tham
  chiếu của step cha trong cây.
- **FR-009a**: Nút Save trên màn hình Add/Edit MUST được đặt ở cột trái, ngay bên dưới checkbox
  "Set as default template" — KHÔNG đặt ở thanh tiêu đề (title bar) cùng hàng với nút Back. Nút
  Back MUST vẫn giữ nguyên vị trí ở thanh tiêu đề.
- **FR-010**: Hệ thống MUST yêu cầu Name và Alert for không được để trống khi tạo hoặc sửa
  template. Code do hệ thống tự sinh nên không cần người dùng nhập hay kiểm tra. VendorCode là
  tùy chọn.
- **FR-011**: Khi nhấn Edit trên một dòng, hệ thống MUST chuyển sang màn hình chỉnh sửa (cùng
  layout 2 cột với Add) với breadcrumb "EUTR system > EUTR templates > Edit", tải sẵn dữ liệu
  header (bao gồm Vendor được chọn sẵn từ API `GET /api/dynamics/vendors`) và cây bước hiện tại của template
  đó. Người dùng có thể chỉnh sửa step đã có (đổi step, RequirementType, TakeFrom) ngoài việc
  thêm/xóa step.
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
- **FR-015**: Nút Back trên màn hình tạo/sửa MUST quay về danh sách template. Nếu người dùng đã
  thêm step mới hoặc chỉnh sửa step đã có trong cây bước mà CHƯA nhấn Save template, hệ thống
  MUST hiển thị hộp thoại cảnh báo xác nhận trước khi điều hướng đi (ví dụ: "Bạn có thay đổi chưa
  lưu. Rời khỏi trang sẽ mất các thay đổi này. Tiếp tục?"), cho phép chọn rời đi (mất thay đổi)
  hoặc ở lại trang. Nếu không có thay đổi step nào chưa lưu (bao gồm trường hợp mới mở trang hoặc
  đã Save toàn bộ), Back MUST điều hướng thẳng về danh sách mà không cảnh báo.
- **FR-016**: Hệ thống MUST hiển thị màn hình trong mục điều hướng "EUTR templates" dưới nhóm
  "EUTR system".
- **FR-017**: Toàn bộ văn bản hiển thị cho người dùng trên front-end MUST bằng tiếng Anh, bao
  gồm: nhãn cột, nút (Add, Edit, Delete, Save, Back, Add step, Import), breadcrumb, thông báo
  kiểm tra/lỗi, thông báo thành công, trạng thái rỗng ("No data"), và hộp thoại xác nhận.
- **FR-018**: Backend MUST cung cấp endpoint riêng `GET /api/dynamics/vendors` trong DynController
  để query danh sách vendors từ D365 VendorsV3. Endpoint MUST hỗ trợ phân trang (skip, top), lọc
  (filter) và sắp xếp (order_by). Logic MUST theo pattern tương tự endpoint `data-area`
  (SetEntity("VendorsV3"), _parser.ParseAndValidate, _dynamicService.QueryAsync). Endpoint MUST
  sử dụng OData `$select` để chỉ lấy 3 cột cần thiết: `dataAreaId`, `VendorAccountNumber`,
  `VendorOrganizationName` — KHÔNG lấy toàn bộ cột từ VendorsV3. Response trả về dữ liệu OData
  chỉ gồm 3 trường trên. Endpoint này thay thế việc sử dụng refType=13 trong API reference chung
  cho mục đích tra cứu vendor.

### Key Entities *(include if feature involves data)*

- **EUTR Template**: Đại diện cho một mẫu template EUTR gắn với vendor. Thuộc tính: định danh,
  Code (hệ thống tự sinh theo quy tắc prefix + số tăng dần, readonly — ví dụ Templates-001),
  Name, Vendor code, Is default, VersionId, Alert for, IsDeleted (cờ xóa mềm, 0=hiện/1=đã xóa),
  IsHide (cờ ẩn version cũ, 0=hiện/1=đã ẩn), người tạo, ngày tạo, người cập nhật, ngày cập nhật.
  Khi tạo mới, VersionId = 1. Khi edit: nếu bản ghi được tạo cách đây TRÊN 24 giờ (so với
  CreatedDate), tạo dòng mới với VersionId tự tăng (VersionId cũ + 1) và đánh dấu dòng cũ
  IsHide=1; nếu DƯỚI 24 giờ, cập nhật đè trực tiếp lên dòng hiện tại (giữ nguyên Id, VersionId,
  CreatedDate).
- **EUTR Template Detail**: Đại diện cho một bước cụ thể trong cây bước của template. Thuộc tính:
  định danh, Template Id (liên kết đến template), Step Id (liên kết đến EUTR step), Parent Id
  (liên kết đến step cha hoặc 0 nếu gốc), RequirementType (Required=1/Optional=0),
  TakeFrom (PO=0/Upload manual=1), thứ tự hiển thị, người tạo, ngày tạo. Khi edit template,
  toàn bộ cây bước hiện tại (bao gồm step đã chỉnh sửa) được lưu vào TemplateId mới. ParentId
  MUST được lưu chính xác để duy trì cấu trúc cây đệ quy.
- **EUTR Step** (đã có sẵn): Danh sách các bước EUTR, được sử dụng làm nguồn dữ liệu cho
  combobox khi Add step.
- **D365 Vendor (VendorsV3)**: Dữ liệu vendor từ hệ thống D365, chỉ sử dụng 3 cột: dataAreaId,
  VendorAccountNumber và VendorOrganizationName (endpoint MUST dùng `$select` để giới hạn).
  Truy cập qua endpoint riêng `GET /api/dynamics/vendors` (DynController, SetEntity("VendorsV3")),
  được sử dụng cho combobox Vendor và hiển thị Vendor name trong grid.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng tìm thấy và mở màn hình EUTR Templates trong vòng 10 giây kể từ khi
  vào hệ thống mà không cần hướng dẫn.
- **SC-002**: Người dùng tạo một template hoàn chỉnh (header + 3 step) trong dưới 2 phút.
- **SC-003**: Cột Vendor name trong grid hiển thị đúng tên vendor từ API vendors cho 100% bản ghi
  có Vendor code hợp lệ.
- **SC-004**: 100% thao tác tạo với Name hoặc Alert for trống bị chặn và hiển thị thông báo lỗi
  rõ ràng. Code luôn được hệ thống tự sinh chính xác.
- **SC-005**: Cây bước hỗ trợ ít nhất 3 cấp lồng nhau mà không bị lỗi hiển thị hay mất dữ liệu.
- **SC-006**: Mọi thao tác xóa đều yêu cầu xác nhận, không có trường hợp xóa nhầm do một cú nhấp.
- **SC-007**: Sau khi edit và save một template được tạo cách đây TRÊN 24 giờ, phiên bản cũ
  (IsHide=1) vẫn tồn tại trong database và phiên bản mới (VersionId tăng) hiển thị đúng trên
  grid. Sau khi edit và save một template được tạo cách đây DƯỚI 24 giờ, KHÔNG có dòng mới nào
  được tạo — dữ liệu được cập nhật đè lên dòng hiện có (VersionId và Id không đổi).
- **SC-008**: Template đã soft delete không bao giờ xuất hiện trên grid, nhưng dữ liệu vẫn có
  thể truy vấn trực tiếp trong database để kiểm tra.
- **SC-009**: Combobox Vendor trên màn hình Add/Edit hiển thị danh sách vendor từ API riêng
  `GET /api/dynamics/vendors` cho 100% lần mở. Ở chế độ Edit, vendor hiện tại được chọn sẵn
  chính xác. KHÔNG sử dụng API reference chung.
- **SC-010**: 100% step được tạo với step cha (tick chọn trước khi Add step) lưu ParentId chính
  xác vào bảng eutr_template_details. Step gốc lưu ParentId = 0.
- **SC-011**: Người dùng chỉnh sửa step đã tạo (đổi step, RequirementType, TakeFrom) trong dưới
  10 giây thông qua icon Edit trên dòng step.
- **SC-012**: Giao diện Add/Edit hiển thị rõ ràng 2 cột tách biệt: thông tin header (trái, đã mở
  rộng) và cây bước (phải, đã thu hẹp), giúp người dùng làm việc đồng thời với cả hai phần mà
  không cần cuộn trang, và các trường Code/Name/AlertFor/Vendor hiển thị đầy đủ không bị cắt.
- **SC-013**: 100% lượt Edit một template được tạo dưới 24 giờ trước đó dẫn đến cập nhật đè lên
  dòng hiện tại (không tăng VersionId, không tạo dòng ẩn mới). 100% lượt Edit một template được
  tạo trên 24 giờ trước đó dẫn đến tạo version mới đúng theo cơ chế versioning hiện hành.
- **SC-014**: Nút Save luôn hiển thị ngay dưới checkbox "Set as default template" ở cột trái cho
  100% lần mở màn hình Add/Edit.
- **SC-015**: 100% lượt nhấn Back khi có step chưa lưu (thêm mới hoặc chỉnh sửa) hiển thị cảnh
  báo xác nhận trước khi điều hướng; 100% lượt nhấn Back khi không có thay đổi chưa lưu điều
  hướng ngay lập tức không cảnh báo.

## Assumptions

- Backend API cho EUTR Templates chưa tồn tại; feature này cần xây dựng cả backend (CRUD cho
  eutr_templates + eutr_template_details) và frontend.
- D365 VendorsV3 API đã có sẵn trên hệ thống D365 và có thể truy cập qua Dynamics service hiện
  tại (tương tự RSVNDataAreas, RSVNCustTableEntities). Endpoint riêng `GET /api/dynamics/vendors`
  được thêm vào DynController theo pattern của `data-area` để query VendorsV3 trực tiếp. Frontend
  sử dụng endpoint này thay vì API reference chung (`POST /api/dynamics/reference` với refType=13).
  Domain entity VendorsV3 đã tồn tại tại ComplianceSys.Domain.Dynamics.VendorsV3 với các trường:
  dataAreaId, VendorAccountNumber, VendorOrganizationName.
- EUTR Steps (feature 001) đã được triển khai và có API sẵn sàng để cung cấp dữ liệu cho
  combobox Add step.
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
