# Feature Specification: EUTR Sales Orders Management

**Feature Branch**: `005-eutr-sales-orders`

**Created**: 2026-07-14

**Status**: Draft

**Input**: User description: "chức năng mới eutr-sales-orders. giao diện front end trong eutr-sales-orders. đổ dữ liệu từ ComplianceSys.Api.Controllers, [HttpPost("reference")] với reftype = 11, các cột sales id, customer, customer name. delivery date. cột tempate, progess để cố định dữ liệu demo"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem danh sách EUTR Sales Orders (Priority: P1)

Người dùng vào mục **EUTR > EUTR Sales Orders** từ thanh điều hướng và thấy một bảng liệt kê các
sales order lấy từ hệ thống ERP (D365) thông qua nguồn dữ liệu tham chiếu dùng chung đã có sẵn
trong hệ thống (reference type 11). Bảng hiển thị các cột: **Sales ID**, **Customer**, **Customer
name**, **Delivery date**, cùng hai cột **Template** và **Progress** luôn hiển thị giá trị mẫu cố
định (demo, chưa gắn dữ liệu/logic thật) cho mọi dòng.

**Why this priority**: Đây là giá trị cốt lõi và duy nhất của tính năng ở giai đoạn này — cho phép
người dùng xem được danh sách sales order ngay khi mở màn hình; không có giá trị nào khác nếu thiếu
bước này.

**Independent Test**: Mở màn hình EUTR Sales Orders, xác nhận bảng hiển thị đúng các cột Sales ID,
Customer, Customer name, Delivery date với dữ liệu thật lấy từ nguồn tham chiếu reftype = 11; cột
Template và Progress hiển thị giá trị demo cố định giống nhau ở mọi dòng.

**Acceptance Scenarios**:

1. **Given** đang ở thanh điều hướng, **When** chọn "EUTR Sales Orders", **Then** thấy bảng liệt kê
   sales order với đầy đủ 6 cột (Sales ID, Customer, Customer name, Delivery date, Template,
   Progress).
2. **Given** một sales order có đầy đủ dữ liệu Delivery date từ nguồn tham chiếu, **When** bảng
   hiển thị dòng đó, **Then** cột Delivery date hiển thị đúng ngày giao hàng.
3. **Given** một sales order không có Delivery date, **When** bảng hiển thị dòng đó, **Then** cột
   Delivery date hiển thị trạng thái trống rõ ràng (không lỗi, không để trắng gây hiểu nhầm).
4. **Given** hệ thống chưa từng đăng ký reftype = 11 trong nguồn tham chiếu, **When** Feature này
   được triển khai, **Then** nguồn tham chiếu MUST trả về đúng dữ liệu Sales ID/Customer/Customer
   name/Delivery date cho reftype = 11 (không còn trả về rỗng như trước).

---

### User Story 2 - Tìm kiếm sales order theo Sales ID hoặc Customer (Priority: P2)

Người dùng nhập từ khóa vào ô tìm kiếm phía trên bảng để lọc nhanh sales order theo Sales ID hoặc
theo Customer, theo đúng kiểu tìm kiếm ("chứa") đã dùng ở các ô tìm kiếm tham chiếu khác trong hệ
thống.

**Why this priority**: Giá trị bổ sung — giúp người dùng tìm nhanh một sales order cụ thể khi danh
sách dài, nhưng không phải điều kiện tối thiểu để tính năng có giá trị (User Story 1 vẫn dùng được
độc lập nếu thiếu tìm kiếm).

**Independent Test**: Nhập một Sales ID hoặc mã/tên Customer đã biết vào ô tìm kiếm, xác nhận bảng
chỉ còn hiển thị các dòng khớp; xóa từ khóa, xác nhận bảng quay lại hiển thị toàn bộ danh sách mặc
định.

**Acceptance Scenarios**:

1. **Given** danh sách đang hiển thị đầy đủ, **When** nhập một Sales ID hợp lệ vào ô tìm kiếm,
   **Then** bảng chỉ hiển thị (các) dòng có Sales ID khớp.
2. **Given** từ khóa tìm kiếm không khớp sales order nào, **When** tìm kiếm, **Then** bảng hiển thị
   trạng thái trống ("No data"), không phải lỗi.
3. **Given** đã nhập từ khóa tìm kiếm, **When** xóa hết từ khóa, **Then** bảng tải lại danh sách mặc
   định (không lọc).

---

### User Story 3 - Chuyển trang khi danh sách dài (Priority: P3)

Người dùng chuyển qua các trang khi tổng số sales order vượt quá số dòng hiển thị trên một trang.

**Why this priority**: Cải thiện khả năng sử dụng cho danh sách lớn nhưng không ảnh hưởng tới giá
trị cốt lõi của việc xem/tìm sales order.

**Independent Test**: Với danh sách có nhiều hơn một trang dữ liệu, nhấn chuyển trang và xác nhận
bảng hiển thị đúng nhóm dữ liệu tiếp theo.

**Acceptance Scenarios**:

1. **Given** tổng số sales order vượt quá kích thước một trang, **When** người dùng chuyển sang
   trang kế tiếp, **Then** bảng hiển thị đúng các dòng của trang đó.

---

### Edge Cases

- Nguồn dữ liệu tham chiếu (reftype = 11) tạm thời không phản hồi hoặc trả lỗi: bảng hiển thị trạng
  thái lỗi/tải thất bại rõ ràng, không hiển thị dữ liệu demo Template/Progress đè lên một bảng rỗng
  gây hiểu nhầm là có dữ liệu thật.
- Không có sales order nào trong nguồn dữ liệu: bảng hiển thị trạng thái trống ("No data").
- Customer name quá dài: hiển thị rút gọn (ellipsis/tooltip) theo cùng mẫu đã dùng ở các cột tên dài
  khác trong hệ thống, không làm vỡ bố cục bảng.
- Nhiều sales order có cùng Customer: mỗi sales order vẫn hiển thị là một dòng riêng biệt.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST cung cấp một màn hình mới **EUTR Sales Orders**, truy cập được từ mục
  điều hướng EUTR.
- **FR-002**: Màn hình MUST hiển thị dữ liệu sales order dưới dạng bảng/grid, lấy dữ liệu qua nguồn
  tham chiếu dùng chung hiện có của hệ thống (endpoint reference, reference type = 11) — không xây
  dựng một nguồn dữ liệu/API riêng mới cho tính năng này.
- **FR-003**: Bảng MUST hiển thị cột **Sales ID** — mã định danh của sales order.
- **FR-004**: Bảng MUST hiển thị cột **Customer** — mã/tài khoản khách hàng gắn với sales order đó.
- **FR-005**: Bảng MUST hiển thị cột **Customer name** — tên hiển thị của khách hàng đó.
- **FR-006**: Bảng MUST hiển thị cột **Delivery date** — ngày giao hàng của sales order; nếu sales
  order không có ngày giao hàng, cột MUST hiển thị trạng thái trống rõ ràng (không phải lỗi).
- **FR-007**: Bảng MUST hiển thị cột **Template** với một giá trị demo cố định (dữ liệu mẫu, không
  lấy từ nguồn dữ liệu thật) — hiển thị giống nhau ở mọi dòng, dành cho chức năng sẽ hoàn thiện ở
  một tính năng sau.
- **FR-008**: Bảng MUST hiển thị cột **Progress** với một giá trị demo cố định (dữ liệu mẫu, không
  lấy từ nguồn dữ liệu thật) — hiển thị giống nhau ở mọi dòng, dành cho chức năng sẽ hoàn thiện ở
  một tính năng sau.
- **FR-009**: Nguồn tham chiếu dùng chung (reference type = 11) MUST trả về đủ 4 trường Sales ID,
  Customer, Customer name, Delivery date cho mỗi sales order — hiện tại reference type = 11 chưa
  được đăng ký trong nguồn tham chiếu này (luôn trả về danh sách rỗng) nên đây là điều kiện bắt buộc
  để tính năng có dữ liệu thật.
- **FR-010**: Users MUST có thể chuyển trang khi tổng số sales order vượt quá một trang.
- **FR-011**: Users MUST có thể tìm kiếm/lọc danh sách theo Sales ID hoặc Customer (khớp kiểu
  "chứa", không phân biệt hoa/thường), theo đúng mẫu tìm kiếm tham chiếu đã có trong hệ thống.
- **FR-012**: Khi từ khóa tìm kiếm không khớp sales order nào, hệ thống MUST hiển thị trạng thái
  trống ("No data"), không phải lỗi.
- **FR-013**: Màn hình này là **read-only** trong phạm vi tính năng — KHÔNG cung cấp chức năng thêm
  mới (Create), sửa (Edit) hay xóa (Delete) sales order.

### Key Entities *(include if feature involves data)*

- **Sales Order** (dữ liệu tham chiếu từ ERP/D365, chỉ đọc): Sales ID, Customer (mã khách hàng),
  Customer name (tên khách hàng), Delivery date (ngày giao hàng). Dữ liệu này KHÔNG được tạo/sửa/xóa
  từ hệ thống này, chỉ được hiển thị.
- **Template / Progress** (thuộc tính demo hiển thị trên mỗi dòng): giá trị mẫu cố định, hiện chưa
  gắn với entity hay logic nghiệp vụ thật nào — chỗ dành sẵn (placeholder) cho một tính năng sau.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng mở màn hình EUTR Sales Orders và thấy danh sách hiển thị trong vòng 3
  giây trong điều kiện mạng/tải thông thường.
- **SC-002**: 100% số dòng hiển thị đầy đủ Sales ID, Customer, Customer name lấy từ dữ liệu thật;
  Delivery date hiển thị đúng giá trị hoặc trạng thái trống rõ ràng khi không có dữ liệu — không có
  dòng nào hiển thị lỗi hoặc dữ liệu sai lệch.
- **SC-003**: Người dùng tìm được một sales order cụ thể bằng ô tìm kiếm trong vòng 10 giây với danh
  sách có hàng trăm bản ghi.
- **SC-004**: Cột Template và Progress hiển thị nhất quán giá trị demo trên 100% số dòng, không gây
  lỗi hiển thị hay crash màn hình.

## Assumptions

- Màn hình mới được thêm vào mục điều hướng EUTR hiện có (ví dụ "EUTR > EUTR Sales Orders"), theo
  đúng mô hình phân quyền/menu điều khiển từ backend đã áp dụng cho các màn hình EUTR khác (menu và
  quyền truy cập được tạo/cấp trực tiếp trong DB ở bước vận hành, không phải tạo cứng trong code của
  tính năng này).
- Màn hình chỉ ở chế độ xem (view-only) trong phạm vi tính năng này — không có Add/Edit/Delete cho
  sales order.
- "Customer" và "Customer name" là hai cột riêng biệt: Customer = mã/tài khoản khách hàng, Customer
  name = tên hiển thị của khách hàng — đúng theo cách người dùng liệt kê hai cột tách biệt.
- Template và Progress là hai cột hiển thị dữ liệu demo cố định theo đúng yêu cầu, không kết nối tới
  bất kỳ nguồn dữ liệu hay logic nghiệp vụ thật nào ở phạm vi tính năng này.
- Reference type 11 hiện chưa được đăng ký trong nguồn tham chiếu dùng chung của hệ thống (trả về
  rỗng) và định dạng phản hồi hiện tại của nguồn này chỉ có 3 trường chung (Id/Code/Name); việc bổ
  sung Reference type 11 để trả đủ 4 trường (Sales ID, Customer, Customer name, Delivery date) là mở
  rộng trên đúng cơ chế tham chiếu dùng chung đã có, không xây dựng endpoint/nguồn dữ liệu mới.
- Kích thước trang mặc định và cách sắp xếp mặc định (ví dụ theo Sales ID) áp dụng theo đúng chuẩn
  đã dùng ở các bảng tham chiếu EUTR khác trong hệ thống.
