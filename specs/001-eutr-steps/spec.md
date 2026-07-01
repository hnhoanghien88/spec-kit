# Feature Specification: EUTR Steps Management

**Feature Branch**: `001-eutr-steps`

**Created**: 2026-06-30

**Status**: Draft

**Input**: User description: "Màn hình EUTR Steps - CRUD quản lý các bước (steps) trong quy trình EUTR, theo thiết kế design/eutr_steps.md. Backend API đã có sẵn tại api/eutr-steps."

## Clarifications

### Session 2026-07-01

- Q: Phạm vi chuyển sang tiếng Anh — tài liệu spec, giao diện ứng dụng, hay cả hai? → A: Chỉ toàn bộ văn bản hiển thị cho người dùng trên front-end (nhãn cột, nút, breadcrumb, thông báo kiểm tra/lỗi/thành công, trạng thái rỗng, hộp thoại xác nhận) phải bằng tiếng Anh; tài liệu spec giữ nguyên.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem và tìm kiếm danh sách bước (Priority: P1)

Người dùng vào mục **EUTR > Steps** từ thanh điều hướng trái và thấy bảng liệt kê các bước
trong quy trình EUTR. Bảng hiển thị tên bước, người tạo và ngày tạo. Người
dùng có thể gõ từ khóa vào ô tìm kiếm để lọc theo tên bước, và chuyển trang khi danh sách dài.

**Why this priority**: Đây là giá trị cốt lõi của màn hình — nếu chỉ có khả năng xem và tìm
kiếm, người dùng đã có một sản phẩm tối thiểu hữu ích để tra cứu các bước hiện có.

**Independent Test**: Mở màn hình, xác nhận bảng tải đúng dữ liệu từ hệ thống, nhập từ khóa và
thấy danh sách được lọc, chuyển trang và thấy trang kế tiếp.

**Acceptance Scenarios**:

1. **Given** đang ở mục EUTR, **When** chọn "EUTR steps" ở thanh trái, **Then** thấy breadcrumb
   "EUTR > Steps" và bảng các bước với cột Step name, Created by, Created date, Action.
2. **Given** danh sách có nhiều bản ghi, **When** nhập một phần tên vào ô Search, **Then** bảng
   chỉ hiển thị các bước có tên khớp với từ khóa.
3. **Given** danh sách vượt quá một trang, **When** chọn số trang khác, **Then** bảng hiển thị
   các bản ghi của trang đó.

---

### User Story 2 - Thêm bước mới (Priority: P1)

Người dùng nhấn nút **Add**, nhập tên bước trong biểu mẫu, và lưu lại. Bước mới xuất hiện trong
danh sách với người tạo và ngày tạo được ghi nhận tự động.

**Why this priority**: Không có khả năng tạo, danh sách là tĩnh và không phản ánh quy trình thực
tế. Tạo mới là thao tác nghiệp vụ chính cùng với xem.

**Independent Test**: Nhấn Add, nhập tên hợp lệ, lưu, và xác nhận bước mới xuất hiện trong bảng.

**Acceptance Scenarios**:

1. **Given** đang ở màn hình danh sách, **When** nhấn Add và nhập tên hợp lệ rồi lưu, **Then**
   bước mới hiển thị trong bảng kèm người tạo và ngày tạo.
2. **Given** biểu mẫu thêm mới đang mở, **When** để trống tên và lưu, **Then** hệ thống báo lỗi
   yêu cầu nhập tên và không tạo bản ghi.

---

### User Story 3 - Sửa bước (Priority: P2)

Người dùng nhấn **Edit** trên một dòng, chỉnh sửa tên bước trong biểu mẫu, và lưu. Thay đổi được
phản ánh ngay trong bảng.

**Why this priority**: Sửa sai sót tên bước là nhu cầu thường gặp nhưng đứng sau xem và tạo.

**Independent Test**: Nhấn Edit trên một dòng, đổi tên, lưu, và xác nhận tên mới hiển thị.

**Acceptance Scenarios**:

1. **Given** một bước tồn tại, **When** nhấn Edit, đổi tên và lưu, **Then** bảng hiển thị tên đã
   cập nhật.
2. **Given** biểu mẫu sửa đang mở, **When** xóa trống tên và lưu, **Then** hệ thống báo lỗi và
   không lưu.

---

### User Story 4 - Xóa bước (Priority: P2)

Người dùng nhấn **Delete** trên một dòng, xác nhận, và bước bị loại khỏi danh sách. Hệ thống
cũng hỗ trợ xóa nhiều bước cùng lúc.

**Why this priority**: Dọn dẹp các bước không còn dùng là cần thiết nhưng ít rủi ro nếu để sau.

**Independent Test**: Nhấn Delete trên một dòng, xác nhận, và kiểm tra dòng đó biến mất khỏi bảng.

**Acceptance Scenarios**:

1. **Given** một bước tồn tại, **When** nhấn Delete và xác nhận, **Then** bước biến mất khỏi bảng.
2. **Given** đã chọn nhiều bước, **When** thực hiện xóa nhiều, **Then** tất cả bước đã chọn biến
   khỏi bảng.
3. **Given** hộp thoại xác nhận xóa hiện ra, **When** người dùng hủy, **Then** không có bước nào
   bị xóa.

---

### Edge Cases

- Khi danh sách rỗng, bảng hiển thị trạng thái trống thân thiện thay vì lỗi.
- Khi tìm kiếm không có kết quả, bảng hiển thị "không có dữ liệu" và phân trang về 0.
- Khi người dùng không có quyền với một thao tác (theo policy của API), nút tương ứng không khả
  dụng hoặc thao tác bị từ chối với thông báo rõ ràng.
- Khi lưu/xóa thất bại do lỗi mạng hoặc máy chủ, người dùng nhận thông báo lỗi và dữ liệu không
  bị thay đổi sai lệch.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hệ thống MUST hiển thị danh sách các bước EUTR dạng bảng với các cột: Step name,
  Created by, Created date và cột Action (Edit, Delete).
- **FR-002**: Người dùng MUST có thể tìm kiếm các bước theo tên thông qua ô Search.
- **FR-003**: Hệ thống MUST phân trang danh sách khi số bản ghi vượt một trang và cho phép
  chuyển trang.
- **FR-004**: Người dùng MUST có thể tạo bước mới bằng cách nhập tên; hệ thống ghi nhận người
  tạo và ngày tạo tự động.
- **FR-005**: Hệ thống MUST yêu cầu tên bước không được để trống khi tạo hoặc khi sửa.
- **FR-006**: Người dùng MUST có thể sửa tên một bước hiện có.
- **FR-007**: Người dùng MUST có thể xóa một bước, có bước xác nhận trước khi xóa.
- **FR-008**: Hệ thống MUST hỗ trợ xóa nhiều bước cùng lúc.
- **FR-009**: Hệ thống MUST hiển thị màn hình trong mục điều hướng "EUTR steps" với breadcrumb
  "EUTR > Steps".
- **FR-010**: Hệ thống MUST tôn trọng quyền truy cập đã định nghĩa cho từng thao tác (xem, tạo,
  sửa, xóa); thao tác không được phép phải bị ngăn chặn.
- **FR-011**: Toàn bộ văn bản hiển thị cho người dùng trên front-end MUST bằng tiếng Anh, bao
  gồm: nhãn cột (Step name, Created by, Created date, Action), nút (Add, Edit, Delete, Save,
  Cancel), breadcrumb (EUTR > Steps), ô tìm kiếm (Search), thông báo kiểm tra/lỗi (ví dụ tên
  bước để trống), thông báo thành công, trạng thái rỗng ("No data"), và hộp thoại xác nhận xóa.

### Key Entities *(include if feature involves data)*

- **EUTR Step (Bước EUTR)**: Đại diện cho một bước trong quy trình EUTR. Thuộc tính: định danh,
  tên bước, người tạo, ngày tạo, người cập nhật, ngày cập nhật.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng tìm thấy và mở màn hình EUTR Steps trong vòng 10 giây kể từ khi vào hệ
  thống mà không cần hướng dẫn.
- **SC-002**: Người dùng tạo một bước mới hoàn chỉnh trong dưới 30 giây.
- **SC-003**: 100% thao tác tạo/sửa với tên trống bị chặn và hiển thị thông báo lỗi rõ ràng.
- **SC-004**: Người dùng lọc đến đúng bước cần tìm bằng từ khóa trong dưới 5 giây với danh sách
  tối thiểu 100 bản ghi.
- **SC-005**: Mọi thao tác xóa đều yêu cầu xác nhận, không có trường hợp xóa nhầm do một cú nhấp.

## Assumptions

- Backend API cho EUTR Steps đã tồn tại và sẵn sàng tại `api/eutr-steps` (GET danh sách, POST
  `get-all` phân trang/lọc, POST tạo, PUT sửa, DELETE xóa, POST `delete-multi`); feature này
  KHÔNG tạo lại backend.
- Người tạo/ngày tạo do hệ thống ghi tự động dựa trên người dùng đăng nhập; người dùng không
  nhập tay các giá trị này.
- Quyền truy cập từng thao tác đã được định nghĩa sẵn theo policy của API (EutrSteps.ReadAll,
  ReadOne, Create, Update, Delete) và được tái sử dụng.
- Màn hình tuân theo cùng mẫu trải nghiệm của các màn CRUD hiện có trong hệ thống (ví dụ
  document-type).
