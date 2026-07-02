# Feature Specification: EUTR Masters Management

**Feature Branch**: `002-eutr-masters`

**Created**: 2026-07-02

**Status**: Draft

**Input**: User description: "feature mới: EUTR master, chức năng CRUD và Import theo giao diện docs/design/eutr/eutr_masters, và dữ liệu lưu vào bảng eutr_master_documents theo file docs/design/eutr/eutr_db.sql. Dữ liệu sẽ lưu bằng Id bảng eutr_steps và hiển thị trên Grid sẽ là name của steps. Khi Add, box step name là select box lấy dữ liệu từ eutr_steps và user sẽ chọn, sau đó nhập Prefix. Phần import file sẽ đưa lên file excel với 2 cột step name, prefix. Khi add, update kiểm tra nếu tồn tại step id, prefix thì cảnh báo. Lấy mẫu back end, front end từ EutrSteps ở spec 001-eutr-steps"

## Clarifications

### Session 2026-07-02

- Q: Khi thao tác tạo/sửa/import dẫn tới trùng cặp (Step, Prefix), hệ thống nên xử lý thế nào? → A: Chặn lưu hoàn toàn (từ chối tạo/sửa/import dòng trùng) kèm hiển thị cảnh báo.
- Q: Khi file Excel import lẫn dòng hợp lệ và dòng lỗi, hệ thống nên xử lý thế nào? → A: Import một phần — tạo mọi dòng hợp lệ, bỏ qua dòng lỗi và báo cáo lý do.
- Q: Trong file Excel import, dòng đầu tiên là tiêu đề hay đã là dữ liệu? → A: Dòng 1 là tiêu đề (Step name, Prefix) và được bỏ qua; dữ liệu bắt đầu từ dòng 2.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem và tìm kiếm danh sách master document (Priority: P1)

Người dùng vào mục **EUTR > Masters** từ thanh điều hướng trái và thấy bảng liệt kê các master
document. Mỗi dòng hiển thị **tên bước (Step name)** — được suy ra từ bước đã liên kết —, **Prefix**,
người tạo và ngày tạo. Người dùng có thể gõ từ khóa vào ô tìm kiếm để lọc theo tên bước, và
chuyển trang khi danh sách dài.

**Why this priority**: Đây là giá trị cốt lõi của màn hình — nếu chỉ có khả năng xem và tìm kiếm,
người dùng đã có một sản phẩm tối thiểu hữu ích để tra cứu các master document hiện có.

**Independent Test**: Mở màn hình, xác nhận bảng tải đúng dữ liệu và cột Step name hiển thị TÊN
bước (không phải mã), nhập từ khóa và thấy danh sách được lọc, chuyển trang và thấy trang kế tiếp.

**Acceptance Scenarios**:

1. **Given** đang ở mục EUTR, **When** chọn "EUTR masters" ở thanh trái, **Then** thấy breadcrumb
   "EUTR > Masters" và bảng với các cột Step name, Prefix, Created by, Created date, Action.
2. **Given** một master document liên kết tới một bước, **When** bảng hiển thị dòng đó, **Then**
   cột Step name hiển thị TÊN của bước tương ứng (lấy từ danh mục bước) chứ không phải mã định danh.
3. **Given** danh sách có nhiều bản ghi, **When** nhập một phần tên bước vào ô Search, **Then**
   bảng chỉ hiển thị các dòng có tên bước khớp với từ khóa.
4. **Given** danh sách vượt quá một trang, **When** chọn số trang khác, **Then** bảng hiển thị các
   bản ghi của trang đó.

---

### User Story 2 - Thêm master document mới (Priority: P1)

Người dùng nhấn nút **Add**. Trong biểu mẫu, ô **Step name** là một **hộp chọn (select box)** liệt
kê các bước lấy từ danh mục bước; người dùng chọn một bước, sau đó nhập **Prefix**, và lưu lại.
Bản ghi mới xuất hiện trong danh sách với người tạo và ngày tạo được ghi nhận tự động.

**Why this priority**: Không có khả năng tạo, danh sách là tĩnh và không phản ánh cấu hình thực
tế. Tạo mới là thao tác nghiệp vụ chính cùng với xem.

**Independent Test**: Nhấn Add, chọn một bước trong hộp chọn, nhập Prefix hợp lệ, lưu, và xác nhận
bản ghi mới xuất hiện trong bảng với đúng tên bước và prefix.

**Acceptance Scenarios**:

1. **Given** biểu mẫu thêm mới đang mở, **When** mở hộp chọn Step name, **Then** hộp chọn liệt kê
   các bước hiện có từ danh mục bước để người dùng chọn.
2. **Given** đã chọn một bước và nhập Prefix hợp lệ, **When** nhấn Save, **Then** bản ghi mới hiển
   thị trong bảng kèm tên bước, prefix, người tạo và ngày tạo.
3. **Given** biểu mẫu thêm mới đang mở, **When** không chọn bước (hoặc để trống Prefix) rồi lưu,
   **Then** hệ thống báo lỗi yêu cầu nhập đủ và không tạo bản ghi.
4. **Given** đã tồn tại một bản ghi với cùng bước và cùng Prefix, **When** người dùng cố tạo bản
   ghi mới trùng cả bước và Prefix, **Then** hệ thống cảnh báo trùng và không tạo bản ghi.

---

### User Story 3 - Sửa master document (Priority: P2)

Người dùng nhấn **Edit** trên một dòng, thay đổi bước và/hoặc Prefix trong biểu mẫu, và lưu. Thay
đổi được phản ánh ngay trong bảng.

**Why this priority**: Sửa sai sót bước hoặc prefix là nhu cầu thường gặp nhưng đứng sau xem và tạo.

**Independent Test**: Nhấn Edit trên một dòng, đổi bước hoặc prefix, lưu, và xác nhận giá trị mới
hiển thị.

**Acceptance Scenarios**:

1. **Given** một master document tồn tại, **When** nhấn Edit, đổi bước hoặc prefix rồi lưu, **Then**
   bảng hiển thị giá trị đã cập nhật.
2. **Given** biểu mẫu sửa đang mở, **When** để trống bước hoặc prefix rồi lưu, **Then** hệ thống
   báo lỗi và không lưu.
3. **Given** đã tồn tại một bản ghi KHÁC có cùng bước và cùng Prefix, **When** người dùng cập nhật
   một bản ghi thành trùng cả bước và Prefix với bản ghi khác đó, **Then** hệ thống cảnh báo trùng
   và không lưu.

---

### User Story 4 - Xóa master document (Priority: P2)

Người dùng nhấn **Delete** trên một dòng, xác nhận, và bản ghi bị loại khỏi danh sách. Hệ thống
cũng hỗ trợ xóa nhiều bản ghi cùng lúc.

**Why this priority**: Dọn dẹp các bản ghi không còn dùng là cần thiết nhưng ít rủi ro nếu để sau.

**Independent Test**: Nhấn Delete trên một dòng, xác nhận, và kiểm tra dòng đó biến mất khỏi bảng.

**Acceptance Scenarios**:

1. **Given** một master document tồn tại, **When** nhấn Delete và xác nhận, **Then** bản ghi biến
   mất khỏi bảng.
2. **Given** đã chọn nhiều bản ghi, **When** thực hiện xóa nhiều, **Then** tất cả bản ghi đã chọn
   biến mất khỏi bảng.
3. **Given** hộp thoại xác nhận xóa hiện ra, **When** người dùng hủy, **Then** không có bản ghi
   nào bị xóa.

---

### User Story 5 - Import từ file Excel (Priority: P2)

Người dùng nhấn nút **Import** trên thanh công cụ và tải lên một file Excel gồm **2 cột: step name
và prefix**. Hệ thống đọc từng dòng, ánh xạ *step name* sang bước tương ứng trong danh mục bước,
và tạo các master document mới. Với các dòng lỗi (không tìm thấy bước, thiếu prefix, hoặc trùng
bước + prefix), hệ thống cảnh báo và bỏ qua dòng đó.

**Why this priority**: Import giúp nhập số lượng lớn nhanh chóng thay vì thêm từng dòng, nhưng
phụ thuộc vào việc tạo/xem đã hoạt động.

**Independent Test**: Chuẩn bị file Excel 2 cột hợp lệ, nhấn Import, chọn file, và xác nhận các
bản ghi tương ứng xuất hiện trong bảng với đúng bước và prefix; file có dòng lỗi thì nhận cảnh báo.

**Acceptance Scenarios**:

1. **Given** một file Excel với 2 cột (step name, prefix) toàn dòng hợp lệ, **When** người dùng
   Import, **Then** hệ thống tạo bản ghi cho mọi dòng và hiển thị trong bảng với đúng tên bước.
2. **Given** một dòng trong file có step name không khớp bước nào trong danh mục, **When** Import,
   **Then** hệ thống cảnh báo dòng đó và không tạo bản ghi cho nó.
3. **Given** một dòng trong file trùng bước + prefix với bản ghi đã có (hoặc trùng với dòng khác
   trong cùng file), **When** Import, **Then** hệ thống cảnh báo trùng và không tạo bản ghi trùng.
4. **Given** file sai định dạng hoặc không đúng 2 cột yêu cầu, **When** Import, **Then** hệ thống
   báo lỗi định dạng và không import.

---

### User Story 6 - Export ra file Excel (Priority: P2)

Người dùng nhấn nút **Export** trên thanh công cụ để tải về một file Excel chứa danh sách master.
File luôn có **dòng tiêu đề gồm 2 cột: Step name, Prefix**. Nếu có dữ liệu, các dòng dữ liệu (tên
bước + prefix) nằm dưới dòng tiêu đề; nếu không có dữ liệu, file chỉ có dòng tiêu đề. Định dạng file
xuất trùng khớp với định dạng import để có thể dùng lại (round-trip).

**Why this priority**: Export giúp sao lưu/chia sẻ và chỉnh sửa hàng loạt ngoài hệ thống rồi import
lại, nhưng đứng sau các thao tác cốt lõi xem/tạo.

**Independent Test**: Nhấn Export, mở file tải về, xác nhận có dòng tiêu đề "Step name", "Prefix" và
các dòng dữ liệu khớp danh sách; khi danh sách rỗng, file chỉ có dòng tiêu đề.

**Acceptance Scenarios**:

1. **Given** có ít nhất một master, **When** người dùng nhấn Export, **Then** hệ thống tải về file
   Excel có dòng tiêu đề (Step name, Prefix) và một dòng cho mỗi master với tên bước + prefix đúng.
2. **Given** danh sách master rỗng, **When** người dùng nhấn Export, **Then** hệ thống tải về file
   Excel chỉ có dòng tiêu đề (Step name, Prefix), không có dòng dữ liệu.
3. **Given** file vừa xuất, **When** người dùng dùng chính file đó để Import, **Then** định dạng
   khớp (đúng 2 cột, dòng 1 là tiêu đề) và import xử lý được.

---

### Edge Cases

- Khi danh sách rỗng, bảng hiển thị trạng thái trống thân thiện thay vì lỗi.
- Khi tìm kiếm không có kết quả, bảng hiển thị "No data" và phân trang về 0.
- Khi danh mục bước rỗng, hộp chọn Step name hiển thị trạng thái trống và không cho tạo bản ghi
  cho tới khi có bước.
- Khi một bản ghi tham chiếu tới bước đã bị xóa khỏi danh mục, cột Step name hiển thị giá trị dự
  phòng rõ ràng (ví dụ để trống hoặc "Unknown") thay vì lỗi.
- Khi file Excel import lẫn dòng hợp lệ và dòng lỗi, hệ thống import các dòng hợp lệ và báo cáo
  các dòng bị bỏ qua kèm lý do.
- Khi Export lúc danh sách rỗng, file tải về vẫn hợp lệ và chỉ chứa dòng tiêu đề (Step name,
  Prefix), không có dòng dữ liệu.
- Khi người dùng không có quyền với một thao tác (theo policy của API), nút tương ứng không khả
  dụng hoặc thao tác bị từ chối với thông báo rõ ràng.
- Khi lưu/xóa/import thất bại do lỗi mạng hoặc máy chủ, người dùng nhận thông báo lỗi và dữ liệu
  không bị thay đổi sai lệch.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hệ thống MUST hiển thị danh sách các master document dạng bảng với các cột: Step
  name, Prefix, Created by, Created date và cột Action (Edit, Delete).
- **FR-002**: Hệ thống MUST hiển thị ở cột Step name TÊN của bước liên kết (lấy từ danh mục bước),
  trong khi dữ liệu được lưu bằng định danh của bước.
- **FR-003**: Người dùng MUST có thể tìm kiếm các master document theo tên bước thông qua ô Search.
- **FR-004**: Hệ thống MUST phân trang danh sách khi số bản ghi vượt một trang và cho phép chuyển
  trang.
- **FR-005**: Người dùng MUST có thể tạo master document mới bằng cách chọn một bước từ hộp chọn
  (select box) — được nạp từ danh mục bước — và nhập Prefix; hệ thống ghi nhận người tạo và ngày
  tạo tự động.
- **FR-006**: Hệ thống MUST yêu cầu chọn một bước và nhập Prefix (không được để trống) khi tạo
  hoặc khi sửa.
- **FR-007**: Hệ thống MUST cảnh báo và ngăn lưu khi thao tác tạo hoặc sửa dẫn tới trùng lặp cặp
  (bước, Prefix) với một bản ghi đã tồn tại.
- **FR-008**: Người dùng MUST có thể sửa bước và/hoặc Prefix của một master document hiện có.
- **FR-009**: Người dùng MUST có thể xóa một master document, có bước xác nhận trước khi xóa.
- **FR-010**: Hệ thống MUST hỗ trợ xóa nhiều master document cùng lúc.
- **FR-011**: Người dùng MUST có thể import master document từ file Excel gồm 2 cột: step name và
  prefix. Dòng đầu tiên là dòng tiêu đề (Step name, Prefix) và MUST bị bỏ qua; dữ liệu bắt đầu từ
  dòng thứ hai.
- **FR-012**: Khi import, hệ thống MUST ánh xạ mỗi step name trong file sang bước tương ứng trong
  danh mục bước; dòng không khớp bước nào MUST bị bỏ qua kèm cảnh báo.
- **FR-013**: Khi import, hệ thống MUST áp dụng cùng quy tắc chống trùng cặp (bước, Prefix) như
  khi tạo thủ công (so với dữ liệu hiện có và với các dòng khác trong cùng file); dòng trùng MUST
  bị bỏ qua kèm cảnh báo.
- **FR-014**: Khi import, hệ thống MUST import các dòng hợp lệ và báo cáo cho người dùng các dòng
  bị bỏ qua kèm lý do (không tìm thấy bước, thiếu prefix, trùng lặp, hoặc sai định dạng).
- **FR-015**: Hệ thống MUST hiển thị màn hình trong mục điều hướng "EUTR masters" với breadcrumb
  "EUTR > Masters".
- **FR-016**: Hệ thống MUST tôn trọng quyền truy cập đã định nghĩa cho từng thao tác (xem, tạo,
  sửa, xóa, import, export); thao tác không được phép phải bị ngăn chặn.
- **FR-017**: Toàn bộ văn bản hiển thị cho người dùng trên front-end MUST bằng tiếng Anh, bao gồm:
  nhãn cột (Step name, Prefix, Created by, Created date, Action), nút (Import, Export, Add, Edit,
  Delete, Save, Cancel), breadcrumb (EUTR > Masters), ô tìm kiếm (Search), nhãn biểu mẫu (Step
  name, Prefix), thông báo kiểm tra/lỗi (bao gồm cảnh báo trùng lặp và lỗi import), thông báo thành
  công, trạng thái rỗng ("No data"), và hộp thoại xác nhận xóa.
- **FR-018**: Người dùng MUST có thể export danh sách master ra file Excel bằng nút Export trên
  thanh công cụ.
- **FR-019**: File Excel export MUST luôn có dòng tiêu đề gồm đúng 2 cột theo thứ tự: Step name,
  Prefix; mỗi master là một dòng dữ liệu bên dưới (Step name = tên bước, Prefix = prefix).
- **FR-020**: Khi không có master nào, file export MUST vẫn hợp lệ và chỉ chứa dòng tiêu đề (không
  có dòng dữ liệu).
- **FR-021**: Định dạng file export MUST khớp với định dạng file import (đúng 2 cột, dòng 1 là tiêu
  đề) để cùng một file có thể dùng lại cho chức năng Import.

### Key Entities *(include if feature involves data)*

- **EUTR Master Document (Master document EUTR)**: Đại diện cho cấu hình gắn một bước với một
  Prefix. Thuộc tính: định danh, tham chiếu tới bước (lưu bằng định danh bước, hiển thị bằng tên
  bước), Prefix, người tạo, ngày tạo, người cập nhật, ngày cập nhật. Ràng buộc: cặp (bước, Prefix)
  là duy nhất.
- **EUTR Step (Bước EUTR)**: Danh mục bước dùng để nạp hộp chọn và để hiển thị tên bước. Thuộc
  tính liên quan: định danh, tên bước. Feature này CHỈ đọc danh mục bước, không tạo/sửa bước.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng tìm thấy và mở màn hình EUTR Masters trong vòng 10 giây kể từ khi vào hệ
  thống mà không cần hướng dẫn.
- **SC-002**: Người dùng tạo một master document mới hoàn chỉnh (chọn bước + nhập prefix) trong
  dưới 30 giây.
- **SC-003**: 100% thao tác tạo/sửa dẫn tới trùng cặp (bước, Prefix) bị chặn và hiển thị cảnh báo
  rõ ràng.
- **SC-004**: Người dùng lọc đến đúng bản ghi cần tìm bằng từ khóa tên bước trong dưới 5 giây với
  danh sách tối thiểu 100 bản ghi.
- **SC-005**: Mọi thao tác xóa đều yêu cầu xác nhận, không có trường hợp xóa nhầm do một cú nhấp.
- **SC-006**: Với file Excel 2 cột hợp lệ tối thiểu 50 dòng, người dùng import thành công và thấy
  kết quả (bản ghi tạo được + báo cáo dòng bị bỏ qua) trong dưới 30 giây.
- **SC-007**: Người dùng nhấn Export và nhận được file Excel hợp lệ (có dòng tiêu đề Step name,
  Prefix) trong dưới 10 giây; file mở được và có thể dùng lại cho Import.

## Assumptions

- Backend và front-end được xây dựng theo cùng mẫu của **EUTR Steps** (spec `001-eutr-steps`):
  API dạng `api/eutr-masters` với các thao tác GET danh sách, POST `get-all` phân
  trang/lọc, POST tạo, PUT sửa, DELETE xóa, POST `delete-multi`, một endpoint import và một
  endpoint export (tải file Excel).
- Export xuất toàn bộ danh sách master (không chỉ trang hiện tại). File export không kèm cột audit
  (chỉ Step name, Prefix) để khớp định dạng import.
- Dữ liệu được lưu vào bảng `eutr_master_documents` (Id, StepId, Prefix, CreatedBy, CreatedDate,
  UpdatedBy, UpdatedDate) theo `docs/design/eutr/eutr_db.sql`; StepId tham chiếu `eutr_steps(Id)`.
- Hộp chọn Step name được nạp từ danh mục bước hiện có (`eutr_steps`); feature này không tạo/sửa
  bước.
- "Cảnh báo trùng" được hiểu là CHẶN lưu (từ chối) khi cặp (StepId, Prefix) đã tồn tại, kèm thông
  báo cho người dùng.
- Import Excel yêu cầu đúng 2 cột theo thứ tự step name, prefix, với dòng đầu là tiêu đề (bị bỏ
  qua) và dữ liệu bắt đầu từ dòng thứ hai; ánh xạ step name theo tên bước (khớp chính xác, không
  phân biệt hoa thường). Dòng lỗi bị bỏ qua và báo cáo; dòng hợp lệ vẫn được import (import một
  phần).
- Người tạo/ngày tạo do hệ thống ghi tự động dựa trên người dùng đăng nhập; người dùng không nhập
  tay các giá trị này.
- Quyền truy cập từng thao tác được định nghĩa theo policy của API theo cùng mẫu EutrSteps
  (ReadAll, ReadOne, Create, Update, Delete và quyền Import), được tái sử dụng.
- Màn hình tuân theo cùng mẫu trải nghiệm của các màn CRUD hiện có trong hệ thống (đặc biệt là
  EUTR Steps).
