# Feature Specification: EUTR Reference Types Management

**Feature Branch**: `006-eutr-reference-types`

**Created**: 2026-07-23

**Status**: Draft

**Input**: User description: "tính năng mới eutr-reference-types, chỉ CRUD, dữ liệu lưu vào bảng eutr_reference_types đã thêm trên DB, tham khảo ở file eutr_db"

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

### Edge Cases

- Khi danh sách rỗng, bảng hiển thị trạng thái trống thân thiện thay vì lỗi.
- Khi tìm kiếm không có kết quả, bảng hiển thị "No data" và phân trang về 0.
- Khi xóa một reference type đang được tham chiếu bởi dữ liệu khác (ví dụ một reference), hệ thống
  từ chối xóa và báo lỗi rõ ràng thay vì gây lỗi hệ thống hoặc để dữ liệu không nhất quán.
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

### Key Entities *(include if feature involves data)*

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
