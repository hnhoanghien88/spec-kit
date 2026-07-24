# Feature Specification: EUTR Reference Types Management

**Feature Branch**: `006-eutr-reference-types`

**Created**: 2026-07-23

**Status**: Draft

**Input**: User description: "tính năng mới eutr-reference-types, chỉ CRUD, dữ liệu lưu vào bảng eutr_reference_types đã thêm trên DB, tham khảo ở file eutr_db"

## Clarifications

### Session 2026-07-24 (Update 1) — Assign Steps

- Input: "cập nhật 006-eutr-reference-types thêm tính năng assign steps giống với Apply to customer
  trong 003-eutr-templates, nhưng hiển thị step ở eutr_steps, không cần tính năng Import, Export.
  Khi Add chỉ cần chọn step, không cần thông tin From Date, To date, dữ liệu lưu vào bảng
  eutr_reference_type_details".
- Change: Thêm tính năng **Assign Steps** — icon mới trên mỗi dòng của danh sách EUTR Reference
  Types, điều hướng sang màn hình mới quản lý các step đã gán cho reference type đó, theo cùng mô
  hình màn hình con của **Apply to Customer** (`003-eutr-templates`, xem
  `specs/003-eutr-templates/spec.md` Update 13) nhưng đơn giản hơn: KHÔNG có Vendor, KHÔNG có From
  Date/To Date, KHÔNG có Import/Export. Dữ liệu gán lưu vào bảng `eutr_reference_type_details`
  (`docs/design/eutr/eutr_db.sql` dòng 152-164: `Id, StepId, TypeId, CreatedBy, CreatedDate,
  UpdatedBy, UpdatedDate`), `StepId` tham chiếu `eutr_steps(Id)` (feature `001-eutr-steps`), `TypeId`
  tham chiếu `eutr_reference_types(Id)`.
- Change: Dialog **Add**/**Edit** chỉ gồm **1 trường** — combobox chọn **Step** (bắt buộc,
  single-select, nạp danh sách từ `eutr_steps` — dùng chung dữ liệu/API đã có của feature
  `001-eutr-steps`, KHÔNG tạo step mới tự do tại màn hình này). Không có trường From Date/To Date
  như dialog Apply Vendor của Apply to Customer.
- Change: KHÔNG mang tính năng Import/Export sang màn hình Assign Steps — khác với Apply to Customer
  (vốn có Import/Export từ Update 14 của `003-eutr-templates`), theo đúng yêu cầu rõ ràng của người
  dùng.
- Q: Vì không có From Date/To Date, "chồng lấn" không áp dụng được như Apply to Customer — vậy có
  cần chặn gán trùng (cùng một step được gán 2 lần cho cùng một reference type) không? → A: Có —
  chặn gán trùng: nếu step đã chọn đã tồn tại một bản ghi khác gán cho cùng reference type đang xem,
  hệ thống báo lỗi và không cho lưu (loại trừ chính bản ghi đang sửa khi Edit). Đây là ràng buộc
  tương đương ở mức đơn giản hơn của kiểm tra chồng lấn ngày (FR-036) bên Apply to Customer.
- Q: Dialog Edit (đổi step đã gán sang step khác) có cần giữ lại không, hay chỉ cần Add + Delete? →
  A: Giữ lại Edit, đúng theo mẫu Apply to Customer (Add + Edit + Delete) — Edit cập nhật đè `StepId`
  lên bản ghi hiện tại (giữ nguyên `Id/TypeId/CreatedBy/CreatedDate`), không tạo bản ghi mới.
- Q: Quyền truy cập (permission) cho Add/Edit/Delete trên màn hình Assign Steps có cần policy family
  riêng (ví dụ `EutrReferenceTypeDetails.*`) không? → A: Không — tái sử dụng policy đã có của EUTR
  Reference Types (`EutrReferenceTypes.Update` cho Add/Edit, `EutrReferenceTypes.Delete` cho Delete,
  `EutrReferenceTypes.ReadOne`/`ReadAll` cho xem), đúng theo quyết định đã áp dụng cho Apply to
  Customer (tái sử dụng `EutrTemplates.*` thay vì tạo `EutrTemplateReferences.*` riêng).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem và tìm kiếm danh sách reference type (Priority: P1)

Người dùng vào mục **EUTR > Reference Types** từ thanh điều hướng trái và thấy bảng liệt kê các
loại tham chiếu (reference type) dùng trong hệ thống EUTR. Bảng hiển thị tên loại tham chiếu, người
tạo và ngày tạo. Người dùng có thể gõ từ khóa vào ô tìm kiếm để lọc theo tên, và chuyển trang khi
danh sách dài.

**Why this priority**: Đây là giá trị cốt lõi của màn hình — nếu chỉ có khả năng xem và tìm kiếm,
người dùng đã có một sản phẩm tối thiểu hữu ích để tra cứu các loại tham chiếu hiện có.

**Independent Test**: Mở màn hình, xác nhận bảng tải đúng dữ liệu từ hệ thống, nhập từ khóa và thấy
danh sách được lọc, chuyển trang và thấy trang kế tiếp.

**Acceptance Scenarios**:

1. **Given** đang ở mục EUTR, **When** chọn "EUTR reference types" ở thanh trái, **Then** thấy
   breadcrumb "EUTR > Reference Types" và bảng với cột Name, Created by, Created date, Action.
2. **Given** danh sách có nhiều bản ghi, **When** nhập một phần tên vào ô Search, **Then** bảng chỉ
   hiển thị các loại tham chiếu có tên khớp với từ khóa.
3. **Given** danh sách vượt quá một trang, **When** chọn số trang khác, **Then** bảng hiển thị các
   bản ghi của trang đó.

---

### User Story 2 - Thêm reference type mới (Priority: P1)

Người dùng nhấn nút **Add**, nhập tên loại tham chiếu trong biểu mẫu, và lưu lại. Bản ghi mới xuất
hiện trong danh sách với người tạo và ngày tạo được ghi nhận tự động.

**Why this priority**: Không có khả năng tạo, danh sách là tĩnh và không phản ánh cấu hình thực tế.
Tạo mới là thao tác nghiệp vụ chính cùng với xem.

**Independent Test**: Nhấn Add, nhập tên hợp lệ, lưu, và xác nhận bản ghi mới xuất hiện trong bảng.

**Acceptance Scenarios**:

1. **Given** đang ở màn hình danh sách, **When** nhấn Add và nhập tên hợp lệ rồi lưu, **Then** bản
   ghi mới hiển thị trong bảng kèm người tạo và ngày tạo.
2. **Given** biểu mẫu thêm mới đang mở, **When** để trống tên và lưu, **Then** hệ thống báo lỗi yêu
   cầu nhập tên và không tạo bản ghi.

---

### User Story 3 - Sửa reference type (Priority: P2)

Người dùng nhấn **Edit** trên một dòng, chỉnh sửa tên loại tham chiếu trong biểu mẫu, và lưu. Thay
đổi được phản ánh ngay trong bảng.

**Why this priority**: Sửa sai sót tên là nhu cầu thường gặp nhưng đứng sau xem và tạo.

**Independent Test**: Nhấn Edit trên một dòng, đổi tên, lưu, và xác nhận tên mới hiển thị.

**Acceptance Scenarios**:

1. **Given** một reference type tồn tại, **When** nhấn Edit, đổi tên và lưu, **Then** bảng hiển thị
   tên đã cập nhật.
2. **Given** biểu mẫu sửa đang mở, **When** xóa trống tên và lưu, **Then** hệ thống báo lỗi và không
   lưu.

---

### User Story 4 - Xóa reference type (Priority: P2)

Người dùng nhấn **Delete** trên một dòng, xác nhận, và bản ghi bị loại khỏi danh sách. Hệ thống
cũng hỗ trợ xóa nhiều bản ghi cùng lúc. Nếu một reference type đang được một tham chiếu (reference)
khác sử dụng, hệ thống từ chối xóa và thông báo rõ lý do.

**Why this priority**: Dọn dẹp các loại tham chiếu không còn dùng là cần thiết nhưng ít rủi ro nếu
để sau.

**Independent Test**: Nhấn Delete trên một dòng không đang được sử dụng, xác nhận, và kiểm tra dòng
đó biến mất khỏi bảng.

**Acceptance Scenarios**:

1. **Given** một reference type tồn tại và không đang được sử dụng, **When** nhấn Delete và xác
   nhận, **Then** bản ghi biến mất khỏi bảng.
2. **Given** đã chọn nhiều reference type không đang được sử dụng, **When** thực hiện xóa nhiều,
   **Then** tất cả bản ghi đã chọn biến mất khỏi bảng.
3. **Given** hộp thoại xác nhận xóa hiện ra, **When** người dùng hủy, **Then** không có bản ghi nào
   bị xóa.
4. **Given** một reference type đang được một reference khác tham chiếu tới, **When** người dùng cố
   xóa bản ghi đó, **Then** hệ thống từ chối xóa và hiển thị thông báo rõ ràng rằng bản ghi đang
   được sử dụng.

---

### User Story 5 - Gán các bước (step) cho reference type (Priority: P2)

Người dùng nhấn icon **Assign Steps** trên một dòng trong danh sách reference type, được điều hướng
sang một màn hình mới hiển thị danh sách các bước (step, lấy từ `eutr_steps`) đã gán cho reference
type đó. Người dùng nhấn **Add**, chọn một step từ danh sách, và lưu — hệ thống ghi nhận việc gán
vào bảng `eutr_reference_type_details`. Người dùng cũng có thể **Edit** (đổi sang step khác) hoặc
**Delete** một step đã gán.

**Why this priority**: Đây là tính năng mở rộng cấu hình (không thuộc CRUD lõi ban đầu của
reference type) cho phép người dùng xác định các bước áp dụng cho từng loại tham chiếu — tương tự
vai trò của Apply to Customer với template (`003-eutr-templates`), nhưng đơn giản hơn nhiều (không
có khoảng thời gian hiệu lực, không Import/Export).

**Independent Test**: Mở danh sách reference type, nhấn Assign Steps trên một dòng, nhấn Add, chọn
1 step, lưu, xác nhận step xuất hiện trong bảng; sửa step đã gán sang step khác và xác nhận cập
nhật; xóa một step đã gán và xác nhận biến mất.

**Acceptance Scenarios**:

1. **Given** đang ở danh sách reference type, **When** nhấn icon Assign Steps trên một dòng, **Then**
   điều hướng tới màn hình mới với breadcrumb "EUTR > Reference Types > {Name} > Assign Steps" và
   bảng các step đã gán (có thể rỗng).
2. **Given** đang ở màn hình Assign Steps, **When** nhấn Add, chọn một step chưa được gán cho
   reference type này, và lưu, **Then** bảng hiển thị step vừa gán, dữ liệu được lưu vào
   `eutr_reference_type_details`.
3. **Given** dialog Add đang mở, **When** không chọn step nào và nhấn Save, **Then** hệ thống báo lỗi
   yêu cầu chọn step và không tạo bản ghi.
4. **Given** một step đã được gán cho reference type đang xem, **When** chọn lại đúng step đó ở
   dialog Add, **Then** hệ thống báo lỗi step đã được gán và không tạo bản ghi trùng.
5. **Given** một step đã gán tồn tại, **When** nhấn Edit, chọn một step khác chưa được gán, và lưu,
   **Then** bảng hiển thị step mới đã cập nhật, bản ghi cũ không còn hiển thị step trước đó.
6. **Given** một step đã gán tồn tại, **When** nhấn Delete và xác nhận, **Then** step đó biến mất
   khỏi bảng và bản ghi bị xóa khỏi `eutr_reference_type_details`.

---

### Edge Cases

- Khi danh sách rỗng, bảng hiển thị trạng thái trống thân thiện thay vì lỗi.
- Khi tìm kiếm không có kết quả, bảng hiển thị "No data" và phân trang về 0.
- Khi xóa một reference type đang được tham chiếu bởi dữ liệu khác (ví dụ một reference), hệ thống
  từ chối xóa và báo lỗi rõ ràng thay vì gây lỗi hệ thống hoặc để dữ liệu không nhất quán.
- Khi một reference type chưa có step nào được gán, màn hình Assign Steps hiển thị trạng thái rỗng
  thân thiện ("No data") thay vì lỗi.
- Khi danh sách `eutr_steps` rỗng, combobox chọn Step ở dialog Add/Edit của Assign Steps hiển thị
  trống; người dùng không thể lưu vì Step là bắt buộc.
- Khi người dùng không có quyền với một thao tác (theo policy của API), nút tương ứng không khả
  dụng hoặc thao tác bị từ chối với thông báo rõ ràng.
- Khi lưu/xóa thất bại do lỗi mạng hoặc máy chủ, người dùng nhận thông báo lỗi và dữ liệu không bị
  thay đổi sai lệch.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hệ thống MUST hiển thị danh sách các reference type dạng bảng với các cột: Name,
  Created by, Created date và cột Action (Edit, Delete).
- **FR-002**: Người dùng MUST có thể tìm kiếm các reference type theo tên thông qua ô Search.
- **FR-003**: Hệ thống MUST phân trang danh sách khi số bản ghi vượt một trang và cho phép chuyển
  trang.
- **FR-004**: Người dùng MUST có thể tạo reference type mới bằng cách nhập tên; hệ thống ghi nhận
  người tạo và ngày tạo tự động.
- **FR-005**: Hệ thống MUST yêu cầu tên reference type không được để trống khi tạo hoặc khi sửa.
- **FR-006**: Người dùng MUST có thể sửa tên một reference type hiện có.
- **FR-007**: Người dùng MUST có thể xóa một reference type, có bước xác nhận trước khi xóa.
- **FR-008**: Hệ thống MUST hỗ trợ xóa nhiều reference type cùng lúc.
- **FR-009**: Hệ thống MUST từ chối xóa (và hiển thị thông báo rõ ràng) khi reference type đang được
  một bản ghi khác tham chiếu tới.
- **FR-010**: Hệ thống MUST hiển thị màn hình trong mục điều hướng "EUTR reference types" với
  breadcrumb "EUTR > Reference Types".
- **FR-011**: Hệ thống MUST tôn trọng quyền truy cập đã định nghĩa cho từng thao tác (xem, tạo, sửa,
  xóa); thao tác không được phép phải bị ngăn chặn.
- **FR-012**: Toàn bộ văn bản hiển thị cho người dùng trên front-end MUST bằng tiếng Anh, bao gồm:
  nhãn cột (Name, Created by, Created date, Action), nút (Add, Edit, Delete, Save, Cancel),
  breadcrumb (EUTR > Reference Types), ô tìm kiếm (Search), thông báo kiểm tra/lỗi (ví dụ tên để
  trống, hoặc đang được sử dụng), thông báo thành công, trạng thái rỗng ("No data"), và hộp thoại
  xác nhận xóa.
- **FR-013 (Update 1)**: Hệ thống MUST hiển thị icon **Assign Steps** trên mỗi dòng ở danh sách EUTR
  Reference Types (cạnh Edit/Delete), điều hướng sang một màn hình mới quản lý danh sách step đã
  gán cho reference type của dòng đó.
- **FR-014 (Update 1)**: Màn hình **Assign Steps** MUST hiển thị breadcrumb "EUTR > Reference Types >
  {Name} > Assign Steps" và một bảng danh sách các step đã gán cho reference type đang xem, tải từ
  bảng `eutr_reference_type_details` lọc theo `TypeId`, gồm cột **Step** (tên step, tra cứu từ
  `eutr_steps` qua `StepId`) và cột **Action** (Edit, Delete).
- **FR-015 (Update 1)**: Nút **Add** trên toolbar của màn hình Assign Steps MUST mở dialog popup chỉ
  gồm **1 trường**: combobox chọn **Step** (bắt buộc, single-select, nạp danh sách từ `eutr_steps`).
  Dialog này KHÔNG có trường From Date/To Date. Nhấn Save MUST tạo một bản ghi mới trong
  `eutr_reference_type_details` (`TypeId` từ reference type đang xem, `StepId` đã chọn,
  `CreatedBy`/`CreatedDate` ghi tự động).
- **FR-016 (Update 1)**: Icon **Edit** trên một dòng step đã gán MUST mở lại dialog ở FR-015 với Step
  hiện tại được chọn sẵn; nhấn Save MUST cập nhật đè `StepId` lên bản ghi hiện tại (giữ nguyên
  `Id`/`TypeId`/`CreatedBy`/`CreatedDate`, cập nhật `UpdatedBy`/`UpdatedDate`).
- **FR-017 (Update 1)**: Hệ thống MUST validate dialog Add/Edit của Assign Steps: Step bắt buộc phải
  chọn; nếu step đã chọn đã tồn tại một bản ghi khác gán cho CÙNG reference type đang xem (loại trừ
  chính bản ghi đang sửa khi Edit), hệ thống MUST báo lỗi rõ ràng (step đã được gán) và không cho
  lưu.
- **FR-018 (Update 1)**: Icon **Delete** trên một dòng step đã gán MUST hiển thị `ConfirmDialog` xác
  nhận (nêu rõ tên step), khi xác nhận MUST xóa thật (hard delete) bản ghi khỏi
  `eutr_reference_type_details` — bảng này không có cột IsDeleted/soft-delete.
- **FR-019 (Update 1)**: Màn hình Assign Steps KHÔNG có chức năng Import/Export.
- **FR-020 (Update 1)**: Toàn bộ văn bản hiển thị trên màn hình Assign Steps (breadcrumb, nút
  Add/Edit/Delete/Save/Cancel, tiêu đề dialog, label combobox Step, thông báo lỗi/thành công, hộp
  thoại xác nhận xóa, trạng thái rỗng "No data") MUST bằng tiếng Anh, theo cùng quy tắc FR-012.
- **FR-021 (Update 1)**: Quyền truy cập các thao tác Add/Edit/Delete trên màn hình Assign Steps MUST
  tôn trọng policy đã định nghĩa cho EUTR Reference Types (tái sử dụng quyền tạo/sửa/xóa hiện có),
  không tạo policy family riêng cho `eutr_reference_type_details`; thao tác không được phép phải bị
  ngăn chặn giống FR-011.

### Key Entities *(include if feature involves data)*

- **EUTR Reference Type Detail (Chi tiết gán step của loại tham chiếu, Update 1)**: Đại diện cho
  việc gán một step (bảng `eutr_steps`) cho một reference type (bảng `eutr_reference_types`). Thuộc
  tính: định danh, StepId (tham chiếu `eutr_steps`), TypeId (tham chiếu `eutr_reference_types`),
  người tạo, ngày tạo, người cập nhật, ngày cập nhật. KHÔNG có trường hiệu lực theo thời gian (không
  có From Date/To Date), khác với `eutr_template_references` của Apply to Customer.
- **EUTR Reference Type (Loại tham chiếu EUTR)**: Đại diện cho một loại tham chiếu dùng để phân loại
  các reference trong hệ thống EUTR. Thuộc tính: định danh, tên, người tạo, ngày tạo, người cập
  nhật, ngày cập nhật.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng tìm thấy và mở màn hình EUTR Reference Types trong vòng 10 giây kể từ khi
  vào hệ thống mà không cần hướng dẫn.
- **SC-002**: Người dùng tạo một reference type mới hoàn chỉnh trong dưới 30 giây.
- **SC-003**: 100% thao tác tạo/sửa với tên trống bị chặn và hiển thị thông báo lỗi rõ ràng.
- **SC-004**: Người dùng lọc đến đúng bản ghi cần tìm bằng từ khóa trong dưới 5 giây với danh sách
  tối thiểu 100 bản ghi.
- **SC-005**: Mọi thao tác xóa đều yêu cầu xác nhận, không có trường hợp xóa nhầm do một cú nhấp.
- **SC-006**: 100% các lần cố xóa một reference type đang được sử dụng đều bị từ chối kèm thông báo
  rõ ràng, không gây lỗi hệ thống.
- **SC-007 (Update 1)**: Người dùng gán một step cho reference type hoàn chỉnh (từ lúc mở màn hình
  Assign Steps đến khi lưu thành công) trong dưới 15 giây.
- **SC-008 (Update 1)**: 100% các lần cố gán một step đã tồn tại cho cùng reference type đều bị chặn
  với thông báo rõ ràng, không tạo bản ghi trùng.

## Assumptions

- Dữ liệu được lưu vào bảng `eutr_reference_types` (Id, Name, CreatedBy, CreatedDate, UpdatedBy,
  UpdatedDate) theo `docs/design/eutr/eutr_db.sql`; bảng `eutr_references` tham chiếu tới
  `eutr_reference_types(Id)` qua cột `RefType`.
- Feature chỉ giới hạn ở CRUD (xem/tìm kiếm/phân trang, tạo, sửa, xóa) trên `eutr_reference_types`;
  không bao gồm import/export.
- Backend và front-end được xây dựng theo cùng mẫu của **EUTR Steps** (spec `001-eutr-steps`): API
  dạng `api/eutr-reference-types` với các thao tác GET danh sách, POST `get-all` phân trang/lọc,
  POST tạo, PUT sửa, DELETE xóa, POST `delete-multi`.
- Người tạo/ngày tạo do hệ thống ghi tự động dựa trên người dùng đăng nhập; người dùng không nhập
  tay các giá trị này.
- Xóa một reference type đang được tham chiếu bởi `eutr_references.RefType` bị chặn ở tầng API/DB
  (ràng buộc khóa ngoại) và hiển thị thông báo lỗi rõ ràng cho người dùng thay vì lỗi hệ thống chung
  chung.
- Quyền truy cập từng thao tác được định nghĩa theo policy của API theo cùng mẫu EutrSteps (ReadAll,
  ReadOne, Create, Update, Delete), được tái sử dụng.
- Màn hình tuân theo cùng mẫu trải nghiệm của các màn CRUD hiện có trong hệ thống (đặc biệt là EUTR
  Steps).
- **(Update 1)** Dữ liệu gán step được lưu vào bảng `eutr_reference_type_details` (Id, StepId,
  TypeId, CreatedBy, CreatedDate, UpdatedBy, UpdatedDate) theo `docs/design/eutr/eutr_db.sql` dòng
  152-164; `StepId` tham chiếu `eutr_steps(Id)`, `TypeId` tham chiếu `eutr_reference_types(Id)`.
  Bảng này hiện CHƯA có entity/DTO/service/controller nào ở backend hay use case nào ở frontend —
  phải tạo mới toàn bộ (tương tự cách `eutr_reference_types` từng phải tạo mới ở feature này).
- **(Update 1)** Danh sách step để chọn trong dialog Add/Edit của Assign Steps lấy từ API hiện có
  của feature `001-eutr-steps` (`GET /api/eutr-steps`, đã có sẵn `GetEutrStepsUseCase`/
  `repositories.eutrStep` ở frontend) — KHÔNG tạo step mới tự do (free-solo) tại màn hình này, khác
  với cách `003-eutr-templates` tự động tạo step mới khi gõ tự do.
- **(Update 1)** Bảng `eutr_reference_type_details` không có cột IsDeleted; xóa một step đã gán là
  xóa thật (hard delete), giống cơ chế Delete của `eutr_template_references` trong Apply to
  Customer.
- **(Update 1)** Quyền truy cập Add/Edit/Delete trên màn hình Assign Steps tái sử dụng policy đã có
  của EUTR Reference Types (Create/Update/Delete), không tạo policy family riêng cho
  `eutr_reference_type_details` — theo đúng quyết định đã áp dụng cho Apply to Customer (tái sử
  dụng `EutrTemplates.*` thay vì tạo `EutrTemplateReferences.*` riêng).
- **(Update 1)** Không có chức năng Import/Export ở màn hình Assign Steps (khác Apply to Customer
  sau Update 14 của `003-eutr-templates`) — theo đúng yêu cầu rõ ràng của người dùng.
- **(Update 1)** Không có trường From Date/To Date ở dialog Add/Edit — khác với Apply to Customer;
  do đó không cần logic kiểm tra chồng lấn ngày, chỉ cần chặn gán trùng step cho cùng reference
  type (FR-017/SC-008).
- **(Update 1)** Icon **Assign Steps** đặt trên mỗi dòng của danh sách EUTR Reference Types (cạnh
  Edit/Delete), điều hướng sang route mới dạng `/eutr/reference-types/assign-steps/:id`, theo đúng
  mẫu icon Apply to Customer điều hướng sang `/eutr/templates/apply/:id` trong `003-eutr-templates`.
