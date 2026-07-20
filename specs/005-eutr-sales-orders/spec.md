# Feature Specification: EUTR Sales Orders Management

**Feature Branch**: `005-eutr-sales-orders`

**Created**: 2026-07-14

**Status**: Draft

**Input**: User description: "chức năng mới eutr-sales-orders. giao diện front end trong eutr-sales-orders. đổ dữ liệu từ ComplianceSys.Api.Controllers, [HttpPost("reference")] với reftype = 11, các cột sales id, customer, customer name. delivery date. cột tempate, progess để cố định dữ liệu demo"

## Clarifications

### Session 2026-07-16 (Update 1) — Cột Template lấy dữ liệu thật

- Change: Cột **Template** trên màn hình **EUTR Sales Orders** (SalesOrderOverviewPage) KHÔNG còn
  hiển thị giá trị demo cố định (bỏ FR-007 phiên bản cũ). Cột này MUST lấy dữ liệu thật từ bảng
  `eutr_purchase_attachments`, tra cứu các bản ghi có `SalesId` khớp với Sales ID của dòng đang
  hiển thị, sau đó hiển thị tên template tương ứng (tra cứu qua `TemplateCode` → bảng `eutr_templates`).
- Change: Một Sales ID có thể gắn với nhiều bản ghi trong `eutr_purchase_attachments` (mỗi bản ghi
  ứng với một `PurchId`/dòng mua hàng khác nhau), và các bản ghi đó có thể tham chiếu tới các
  `TemplateCode` khác nhau. Khi đó, cột Template MUST hiển thị **đầy đủ tất cả** các template gắn
  với Sales ID đó (mỗi template duy nhất chỉ hiển thị 1 lần, không lặp lại dù có nhiều `PurchId`
  cùng dùng chung 1 template).
- Cột **Progress** không thuộc phạm vi thay đổi này — vẫn tiếp tục hiển thị giá trị demo cố định
  như hiện tại (FR-008 giữ nguyên).

### Session 2026-07-16 (Update 2) — Màn hình Map File (MapFilePage) lấy dữ liệu thật

- Change: Màn hình **Map File** (`MapFilePage`, mở từ nút "Map File" ở Overview) hiện đang dùng toàn
  bộ dữ liệu mock (`MOCK_SALES_ORDERS`, `MOCK_SO_POS`, `MOCK_SO_PO_MAPPINGS`, `MOCK_AVAILABLE_FILES`,
  `MOCK_FILE_MAPPINGS`, `EUTR_TEMPLATE_DETAILS_MAP`). Update này chuyển các phần sau sang dữ liệu
  thật, các phần còn lại (Upload file mới, Save mapping file ở Step 2) tạm thời vẫn chỉ hiển thị,
  chưa xử lý:
  - Kiểm tra Sales Order có tồn tại hay không (`if (!so)`) và thông tin ở **Header card** (Sales ID,
    Customer, Customer name) MUST lấy từ cùng nguồn tham chiếu dùng chung mà **SalesOrderOverviewPage**
    (Overview) đang dùng (reference type = 11) — tra theo Sales ID trên URL, không dùng mảng mock
    `MOCK_SALES_ORDERS` nữa.
  - Danh sách PO ở **Step 1** MUST lấy từ nguồn tham chiếu dùng chung với reference type = 16, lọc
    theo điều kiện `InterCompanyOriginalSalesId` = Sales ID hiện tại — không dùng `MOCK_SO_POS`.
  - Việc chọn PO ở Step 1 ("PO mapping") do người dùng quyết định (tick chọn PO nào áp dụng), khi
    nhấn **Save PO Mapping** MUST lưu (ghi mới/cập nhật) vào bảng `eutr_purchase_attachments`
    (`SalesId`, `PurchId`, `TemplateCode`) — đây là hành động **ghi** đầu tiên vào bảng này; trước
    Update 2, bảng `eutr_purchase_attachments` chỉ được đọc (xem Update 1), chưa có luồng ghi nào.
  - Nếu Sales ID đã có sẵn bản ghi trong `eutr_purchase_attachments` (đã Save PO Mapping từ trước),
    Step 1 MUST tự động tick chọn sẵn (default-checked) đúng các PO đó khi mở lại màn hình — không
    dùng `MOCK_SO_PO_MAPPINGS`.
  - Cây thư mục ở **Step 2** MUST được xây dựng dựa trên (các) `TemplateCode` lấy ra từ
    `eutr_purchase_attachments` của Sales ID này (sau khi đã Save ở Step 1) — không dùng
    `so.templateId`/`EUTR_TEMPLATE_DETAILS_MAP` cố định theo Sales Order mock.
  - Danh sách **AVAILABLE FILES** ở Step 2 MUST lấy dữ liệu tài liệu thật từ bảng `eutr_references`
    (lọc theo PO mà người dùng đã chọn/lưu ở Step 1), hiển thị đúng Step mà tài liệu đó đã được gắn
    trong cây — không dùng `MOCK_AVAILABLE_FILES`/`MOCK_FILE_MAPPINGS`.
  - Chức năng **Upload** (upload file mới) và **Save** (lưu mapping file↔step) ở Step 2 tạm thời
    KHÔNG xử lý — vẫn giữ nguyên giao diện hiển thị hiện tại (demo/no-op), việc xử lý thật để lại cho
    một cập nhật sau.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem danh sách EUTR Sales Orders (Priority: P1)

Người dùng vào mục **EUTR > EUTR Sales Orders** từ thanh điều hướng và thấy một bảng liệt kê các
sales order lấy từ hệ thống ERP (D365) thông qua nguồn dữ liệu tham chiếu dùng chung đã có sẵn
trong hệ thống (reference type 11). Bảng hiển thị các cột: **Sales ID**, **Customer**, **Customer
name**, **Delivery date**, cột **Template** hiển thị (các) template thật gắn với Sales ID đó (tra
cứu từ bảng `eutr_purchase_attachments`), và cột **Progress** vẫn hiển thị giá trị mẫu cố định
(demo, chưa gắn dữ liệu/logic thật) cho mọi dòng.

**Why this priority**: Đây là giá trị cốt lõi và duy nhất của tính năng ở giai đoạn này — cho phép
người dùng xem được danh sách sales order ngay khi mở màn hình; không có giá trị nào khác nếu thiếu
bước này.

**Independent Test**: Mở màn hình EUTR Sales Orders, xác nhận bảng hiển thị đúng các cột Sales ID,
Customer, Customer name, Delivery date với dữ liệu thật lấy từ nguồn tham chiếu reftype = 11; cột
Template hiển thị đúng (các) template thật tra cứu từ `eutr_purchase_attachments` theo Sales ID
(bao gồm trường hợp một Sales ID có nhiều template); cột Progress vẫn hiển thị giá trị demo cố định
giống nhau ở mọi dòng.

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
5. **Given** một Sales ID chỉ có đúng 1 bản ghi trong `eutr_purchase_attachments`, **When** bảng
   hiển thị dòng đó, **Then** cột Template hiển thị đúng 1 tên template tương ứng.
6. **Given** một Sales ID có nhiều bản ghi trong `eutr_purchase_attachments` với nhiều `TemplateCode`
   khác nhau (nhiều `PurchId` khác nhau), **When** bảng hiển thị dòng đó, **Then** cột Template
   MUST hiển thị đầy đủ tất cả các template khác nhau đó cho cùng 1 dòng (không chỉ 1 giá trị).
7. **Given** một Sales ID chưa có bản ghi nào trong `eutr_purchase_attachments`, **When** bảng hiển
   thị dòng đó, **Then** cột Template hiển thị trạng thái trống rõ ràng (không lỗi, không hiển thị
   dữ liệu demo/giả).

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

### User Story 4 - Chọn Purchase Order và xem hồ sơ tài liệu cho Sales Order (Map File) (Priority: P2)

Từ màn hình EUTR Sales Orders, người dùng nhấn "Map File" trên một dòng để mở màn hình Map File của
Sales Order đó. Màn hình hiển thị đúng thông tin Sales Order (Sales ID, Customer, Customer name)
khớp với dữ liệu đã thấy ở Overview. Ở **Step 1**, người dùng thấy danh sách Purchase Order (PO)
thật liên quan tới Sales Order đó (lấy từ D365 theo điều kiện PO có `InterCompanyOriginalSalesId`
khớp Sales ID này), tick chọn (các) PO áp dụng cho hồ sơ EUTR rồi nhấn **Save PO Mapping** để lưu lại
lựa chọn; nếu Sales Order đã từng được lưu PO trước đó, các PO đó tự động được tick sẵn khi mở lại. Ở
**Step 2**, người dùng thấy cây thư mục của (các) template gắn với PO đã lưu, cùng danh sách tài
liệu (AVAILABLE FILES) đã có sẵn cho các PO đó, mỗi tài liệu hiển thị đúng vị trí (step) trong cây mà
nó thuộc về. Chức năng Upload tài liệu mới và Save mapping tài liệu ở Step 2 vẫn chỉ ở dạng hiển thị,
chưa xử lý thật ở phạm vi cập nhật này.

**Why this priority**: Đây là hành động nghiệp vụ tiếp theo, ngay sau khi xem được danh sách sales
order (User Story 1) — cho phép người dùng thực sự gắn PO và xem hồ sơ tài liệu áp dụng cho từng
Sales Order; phụ thuộc vào việc điều hướng từ Overview (User Story 1) nên xếp ưu tiên ngay sau đó,
trước các cải tiến khả dụng như tìm kiếm/phân trang (User Story 2/3).

**Independent Test**: Mở Map File cho một Sales Order hợp lệ đã có sẵn PO/template trong
`eutr_purchase_attachments`, xác nhận header hiển thị đúng dữ liệu thật, Step 1 hiển thị đúng các PO
lấy từ D365 với (các) PO đã lưu trước được tick sẵn, Step 2 hiển thị đúng cây theo `TemplateCode` đã
lưu và danh sách tài liệu thật lấy từ `eutr_references` cho các PO đó, đúng vị trí step. Sau đó đổi
lựa chọn PO ở Step 1 và Save, xác nhận `eutr_purchase_attachments` được cập nhật và khi tải lại
trang, lựa chọn mới vẫn được giữ.

**Acceptance Scenarios**:

1. **Given** Sales ID hợp lệ tồn tại ở nguồn tham chiếu type = 11, **When** mở Map File, **Then**
   header hiển thị đúng Sales ID/Customer/Customer name khớp với dữ liệu ở Overview.
2. **Given** Sales ID không tồn tại ở nguồn tham chiếu type = 11, **When** mở Map File, **Then**
   màn hình hiển thị lỗi "Sales Order không tồn tại", không hiển thị Step 1/Step 2.
3. **Given** Sales Order có PO liên kết qua `InterCompanyOriginalSalesId` ở nguồn tham chiếu type =
   16, **When** mở Step 1, **Then** bảng PO hiển thị đúng các PO đó lấy từ D365 (không phải PO mock).
4. **Given** Sales Order đã có bản ghi trong `eutr_purchase_attachments` cho một số PurchId, **When**
   mở Step 1, **Then** đúng các PO đó được tick chọn sẵn theo mặc định.
5. **Given** người dùng thay đổi lựa chọn PO và nhấn Save PO Mapping, **When** lưu thành công,
   **Then** bảng `eutr_purchase_attachments` phản ánh đúng lựa chọn mới nhất cho Sales ID này (PO bị
   bỏ chọn không còn bản ghi, PO mới chọn có bản ghi mới).
6. **Given** (các) PO đã lưu gắn với một `TemplateCode` cụ thể, **When** mở Step 2, **Then** cây
   thư mục hiển thị đúng theo `TemplateCode` đó (không dùng template mock cố định theo Sales Order).
7. **Given** (các) PO đã chọn có tài liệu trong `eutr_references`, **When** xem AVAILABLE FILES,
   **Then** danh sách tài liệu hiển thị đúng file thật, mỗi file gắn đúng step tương ứng trong cây.
8. **Given** nút Upload hoặc Save ở Step 2 được nhấn, **When** xử lý, **Then** giao diện chỉ phản
   hồi ở mức hiển thị (demo), không có dữ liệu thật nào được lưu hoặc tải lên.

---

### Edge Cases

- Nguồn dữ liệu tham chiếu (reftype = 11) tạm thời không phản hồi hoặc trả lỗi: bảng hiển thị trạng
  thái lỗi/tải thất bại rõ ràng, không hiển thị dữ liệu demo Template/Progress đè lên một bảng rỗng
  gây hiểu nhầm là có dữ liệu thật.
- Không có sales order nào trong nguồn dữ liệu: bảng hiển thị trạng thái trống ("No data").
- Customer name quá dài: hiển thị rút gọn (ellipsis/tooltip) theo cùng mẫu đã dùng ở các cột tên dài
  khác trong hệ thống, không làm vỡ bố cục bảng.
- Nhiều sales order có cùng Customer: mỗi sales order vẫn hiển thị là một dòng riêng biệt.
- Một Sales ID có nhiều bản ghi trong `eutr_purchase_attachments` cùng trỏ tới **cùng một**
  `TemplateCode` (nhiều `PurchId` dùng chung 1 template): cột Template chỉ hiển thị template đó
  **một lần duy nhất**, không lặp lại theo số lượng `PurchId`.
- `TemplateCode` trong `eutr_purchase_attachments` không còn khớp với bản ghi nào trong
  `eutr_templates` (template đã bị xóa/đổi code): dòng đó bỏ qua template không tra cứu được, không
  làm lỗi toàn bộ dòng hiển thị.
- Sales ID hợp lệ (tồn tại ở reference type = 11) nhưng D365 chưa có PO nào có
  `InterCompanyOriginalSalesId` khớp Sales ID đó (reference type = 16 trả về rỗng): Step 1 của Map
  File hiển thị trạng thái trống ("Không có PO nào"), không phải lỗi, không hiển thị PO mock.
- Một PO ở reference type = 16 không có template gắn kèm (giá trị template rỗng trên D365): PO đó
  KHÔNG lưu được vào `eutr_purchase_attachments` (cột `TemplateCode` là bắt buộc, `NOT NULL`) — Map
  File MUST cho biết rõ PO đó thiếu template (ví dụ vô hiệu hóa checkbox hoặc cảnh báo), không được
  lưu một bản ghi thiếu `TemplateCode`.
- Nhiều PO đã lưu của cùng Sales ID trỏ tới cùng một `TemplateCode`: Step 2 chỉ hiển thị một cây thư
  mục duy nhất cho template đó (không lặp lại theo số PO), theo đúng nguyên tắc dedup đã áp dụng cho
  cột Template ở Overview.
- Sales Order chưa từng Save PO Mapping ở Step 1 (chưa có bản ghi nào trong `eutr_purchase_attachments`
  cho Sales ID này): Step 2 hiển thị trạng thái "chưa có cây template" rõ ràng, không hiển thị cây
  mock/demo đè lên.
- Một bản ghi `eutr_references` của tài liệu thuộc PO đã chọn có `StepId` không khớp bất kỳ node nào
  trong cây template hiện tại (ví dụ tài liệu được gắn từ một luồng/step khác): AVAILABLE FILES vẫn
  hiển thị tài liệu đó trong danh sách, nhưng không gán nhãn "đã map" cho một node cây không tồn tại
  — không gây lỗi hiển thị.
- Một PO đã chọn ở Step 1 chưa có bản ghi nào trong `eutr_references`: AVAILABLE FILES hiển thị trạng
  thái trống rõ ràng cho phần tài liệu của PO đó, không hiển thị file mock.

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
- **FR-007**: Bảng MUST hiển thị cột **Template** với dữ liệu thật, tra cứu từ bảng
  `eutr_purchase_attachments` theo `SalesId` khớp với Sales ID của dòng đó, hiển thị tên template
  (tra cứu qua `TemplateCode` → bảng `eutr_templates`) gắn với sales order đó.
- **FR-007a**: Nếu một Sales ID có nhiều bản ghi trong `eutr_purchase_attachments` (nhiều `PurchId`
  khác nhau) tham chiếu tới nhiều `TemplateCode` khác nhau, cột Template MUST hiển thị đầy đủ tất cả
  các template khác nhau đó cho dòng sales order tương ứng (mỗi template duy nhất chỉ hiển thị một
  lần, không lặp lại theo số `PurchId`).
- **FR-007b**: Nếu một Sales ID chưa có bản ghi nào trong `eutr_purchase_attachments`, cột Template
  MUST hiển thị trạng thái trống rõ ràng (không lỗi, không hiển thị dữ liệu demo/giả).
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
- **FR-014**: Màn hình **Map File** MUST kiểm tra Sales Order có tồn tại hay không bằng cách tra cứu
  cùng nguồn tham chiếu dùng chung reference type = 11 (giống Overview) theo Sales ID trên URL —
  không dùng dữ liệu mock riêng cho màn hình này.
- **FR-015**: Nếu Sales ID không tồn tại ở nguồn tham chiếu type = 11, Map File MUST hiển thị thông
  báo lỗi rõ ràng ("Sales Order không tồn tại") và không hiển thị Step 1/Step 2.
- **FR-016**: Header card của Map File (Sales ID, Customer, Customer name) MUST lấy dữ liệu thật từ
  cùng bản ghi reference type = 11 đã tra được ở FR-014 — không dùng dữ liệu mock.
- **FR-017**: Step 1 ("Chọn Purchase Order") MUST hiển thị danh sách PO lấy từ nguồn tham chiếu dùng
  chung reference type = 16, lọc theo điều kiện `InterCompanyOriginalSalesId` = Sales ID hiện tại —
  không dùng danh sách PO mock.
- **FR-018**: Nếu Sales ID chưa có bản ghi nào trong `eutr_purchase_attachments`, mọi PO ở Step 1
  MUST hiển thị checkbox ở trạng thái chưa chọn theo mặc định.
- **FR-019**: Nếu Sales ID đã có bản ghi trong `eutr_purchase_attachments` (một hoặc nhiều `PurchId`),
  Step 1 MUST tự động tick chọn sẵn (default-checked) đúng các PO tương ứng khi tải trang.
- **FR-020**: Khi người dùng nhấn **Save PO Mapping** ở Step 1, hệ thống MUST lưu các PO đang được
  chọn vào bảng `eutr_purchase_attachments` (`SalesId`, `PurchId`, và `TemplateCode` lấy từ template
  đã gắn sẵn trên từng PO ở D365) — người dùng chọn PO nào áp dụng, không tự chọn template thủ công.
- **FR-021**: Khi Save PO Mapping, hệ thống MUST cập nhật `eutr_purchase_attachments` để khớp đúng
  với lựa chọn hiện tại trên UI — bản ghi của PO đã bị bỏ chọn MUST không còn tồn tại sau khi lưu, PO
  mới được chọn MUST có bản ghi mới; không tích lũy bản ghi của các lần Save trước đó.
- **FR-022**: Nếu một PO ở Step 1 không có template gắn kèm từ D365, hệ thống MUST không cho lưu PO
  đó vào `eutr_purchase_attachments` (do `TemplateCode` là trường bắt buộc) và MUST cho người dùng
  biết rõ lý do (ví dụ vô hiệu hóa lựa chọn hoặc hiển thị cảnh báo).
- **FR-023**: Cây thư mục ở Step 2 ("Map Files vào Template") MUST được xây dựng dựa trên (các)
  `TemplateCode` lấy ra từ các bản ghi `eutr_purchase_attachments` của Sales ID này — không dùng
  template cố định gắn theo Sales Order mock.
- **FR-024**: Nếu các PO đã lưu của Sales ID gắn với nhiều `TemplateCode` khác nhau, Step 2 MUST
  hiển thị đầy đủ cây thư mục cho từng `TemplateCode` khác nhau đó (mỗi template hiển thị một lần
  duy nhất, không lặp lại theo số PO).
- **FR-025**: Nếu Sales ID chưa Save PO Mapping nào (chưa có bản ghi trong `eutr_purchase_attachments`),
  Step 2 MUST hiển thị trạng thái "chưa có cây template" rõ ràng, không hiển thị cây mock.
- **FR-026**: Khu vực **AVAILABLE FILES** ở Step 2 MUST hiển thị các tài liệu thật lấy từ bảng
  `eutr_references` (điều kiện tương ứng loại tham chiếu PO, giá trị tham chiếu = `PurchId`) theo
  (các) PO mà người dùng đã chọn/lưu ở Step 1 — không dùng danh sách file mock.
- **FR-027**: Mỗi tài liệu hiển thị ở AVAILABLE FILES MUST hiển thị đúng Step trong cây template mà
  nó đã được gắn (tra theo `StepId` trên bản ghi `eutr_references` tương ứng), dùng để phản ánh đúng
  trạng thái "đã map" cho đúng node trong cây ở Step 2.
- **FR-028**: Nếu một PO đã chọn ở Step 1 chưa có bản ghi nào trong `eutr_references`, AVAILABLE
  FILES MUST hiển thị trạng thái trống rõ ràng cho phần tài liệu của PO đó, không lỗi, không hiển thị
  file mock.
- **FR-029**: Chức năng **Upload** file mới ở Step 2 MUST tiếp tục hiển thị giao diện như hiện tại
  nhưng KHÔNG lưu file thật hoặc gọi API — giữ hành vi demo/no-op tạm thời, ngoài phạm vi cập nhật này.
- **FR-030**: Chức năng **Save** ở footer Step 2 (lưu mapping tài liệu↔step) MUST tiếp tục hiển thị
  nhưng KHÔNG lưu mapping thật — khác với Save PO Mapping ở Step 1 (đã lưu thật theo FR-020/FR-021),
  giữ hành vi demo/no-op tạm thời.

### Key Entities *(include if feature involves data)*

- **Sales Order** (dữ liệu tham chiếu từ ERP/D365, chỉ đọc): Sales ID, Customer (mã khách hàng),
  Customer name (tên khách hàng), Delivery date (ngày giao hàng). Dữ liệu này KHÔNG được tạo/sửa/xóa
  từ hệ thống này, chỉ được hiển thị.
- **Purchase Attachment** (bảng `eutr_purchase_attachments`, nguồn dữ liệu thật cho cột Template):
  mỗi bản ghi gắn một `SalesId` với một `PurchId` và một `TemplateCode`. Một `SalesId` có thể có
  nhiều bản ghi (nhiều `PurchId`), do đó có thể gắn với nhiều template khác nhau. Màn hình này chỉ
  đọc dữ liệu từ bảng này để hiển thị cột Template, không tạo/sửa/xóa bản ghi.
- **Template** (bảng `eutr_templates`, tra cứu theo `TemplateCode`): cung cấp tên hiển thị cho mỗi
  template được hiển thị ở cột Template.
- **Progress** (thuộc tính demo hiển thị trên mỗi dòng): giá trị mẫu cố định, hiện chưa gắn với
  entity hay logic nghiệp vụ thật nào — chỗ dành sẵn (placeholder) cho một tính năng sau.
- **Purchase Order** (dữ liệu tham chiếu từ D365, reference type = 16, chỉ đọc): PO thuộc về một
  Sales Order xác định qua trường `InterCompanyOriginalSalesId` = Sales ID; mỗi PO có sẵn (các)
  thông tin định danh và một template gắn kèm từ D365. Dữ liệu này KHÔNG được tạo/sửa/xóa từ hệ
  thống này, chỉ được hiển thị và dùng làm nguồn để người dùng chọn lưu vào `eutr_purchase_attachments`.
- **Purchase Attachment** (bảng `eutr_purchase_attachments`) — **cập nhật từ Update 2**: ngoài vai
  trò nguồn đọc cho cột Template ở Overview (Update 1), bảng này nay còn là nơi Map File **ghi**
  lựa chọn PO của người dùng ở Step 1 (`SalesId`, `PurchId`, `TemplateCode`); Save PO Mapping thay
  thế toàn bộ tập bản ghi hiện có của Sales ID đó theo đúng lựa chọn mới nhất trên UI.
- **Reference** (bảng `eutr_references`, nguồn dữ liệu thật cho AVAILABLE FILES ở Step 2, chỉ đọc
  trong phạm vi tính năng này): mỗi bản ghi gắn một tài liệu (`DocumentId`) với một PO (giá trị
  tham chiếu = `PurchId`) và một Step (`StepId`) trong cây template. Dùng để xác định tài liệu nào
  đã có sẵn cho (các) PO đã chọn ở Step 1, và tài liệu đó thuộc step nào trong cây ở Step 2.
- **Document** (bảng `eutr_documents`, tham chiếu qua `eutr_references.DocumentId`): cung cấp thông
  tin hiển thị (tên file...) cho mỗi tài liệu liệt kê ở AVAILABLE FILES.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng mở màn hình EUTR Sales Orders và thấy danh sách hiển thị trong vòng 3
  giây trong điều kiện mạng/tải thông thường.
- **SC-002**: 100% số dòng hiển thị đầy đủ Sales ID, Customer, Customer name lấy từ dữ liệu thật;
  Delivery date hiển thị đúng giá trị hoặc trạng thái trống rõ ràng khi không có dữ liệu — không có
  dòng nào hiển thị lỗi hoặc dữ liệu sai lệch.
- **SC-003**: Người dùng tìm được một sales order cụ thể bằng ô tìm kiếm trong vòng 10 giây với danh
  sách có hàng trăm bản ghi.
- **SC-004**: 100% số dòng hiển thị đúng (các) template thật gắn với Sales ID đó (tra cứu từ
  `eutr_purchase_attachments`), bao gồm đúng các trường hợp có nhiều template trên cùng 1 dòng và
  trường hợp chưa có template nào; cột Progress vẫn hiển thị nhất quán giá trị demo trên 100% số
  dòng — không có dòng nào gây lỗi hiển thị hay crash màn hình.
- **SC-005**: 100% Sales ID hợp lệ mở màn hình Map File đều thấy đúng header thật (Sales ID/Customer/
  Customer name) khớp với dữ liệu đã thấy ở Overview — không có trường hợp hiển thị dữ liệu mock.
- **SC-006**: 100% PO hiển thị ở Step 1 đến từ D365 (reference type = 16, lọc theo
  `InterCompanyOriginalSalesId`), và các PO đã có sẵn trong `eutr_purchase_attachments` được tick
  chọn đúng ngay khi mở trang — không có PO nào bị thiếu hoặc tick nhầm.
- **SC-007**: Sau khi nhấn Save PO Mapping, lựa chọn PO của Sales ID đó được lưu lại và hiển thị
  đúng (tick sẵn) khi người dùng quay lại màn hình này ở một lần mở khác — không mất lựa chọn.
- **SC-008**: 100% tài liệu hiển thị ở AVAILABLE FILES gắn đúng Step trong cây template, dựa trên dữ
  liệu thật ở `eutr_references` cho (các) PO đã chọn — không có tài liệu nào gắn sai step hoặc bị
  bỏ sót.

## Assumptions

- Màn hình mới được thêm vào mục điều hướng EUTR hiện có (ví dụ "EUTR > EUTR Sales Orders"), theo
  đúng mô hình phân quyền/menu điều khiển từ backend đã áp dụng cho các màn hình EUTR khác (menu và
  quyền truy cập được tạo/cấp trực tiếp trong DB ở bước vận hành, không phải tạo cứng trong code của
  tính năng này).
- Màn hình chỉ ở chế độ xem (view-only) trong phạm vi tính năng này — không có Add/Edit/Delete cho
  sales order.
- "Customer" và "Customer name" là hai cột riêng biệt: Customer = mã/tài khoản khách hàng, Customer
  name = tên hiển thị của khách hàng — đúng theo cách người dùng liệt kê hai cột tách biệt.
- Progress vẫn là cột hiển thị dữ liệu demo cố định theo đúng yêu cầu ban đầu, không kết nối tới bất
  kỳ nguồn dữ liệu hay logic nghiệp vụ thật nào ở phạm vi tính năng này.
- Cột Template hiển thị **tên** template (tra cứu qua `eutr_templates.Name` theo `TemplateCode`),
  không hiển thị `TemplateCode` thô — theo đúng mẫu tra cứu tên hiển thị từ mã/id đã dùng ở các cột
  khác trong hệ thống (ví dụ cột Alert for của 003-eutr-templates).
- Khi một Sales ID có nhiều template, các template được hiển thị dưới dạng danh sách trong cùng một
  ô của cột Template (ví dụ nhiều chip/tag trong cùng ô), theo đúng kiểu hiển thị chip đã dùng cho
  cột Template hiện tại — không cần thêm dòng phụ hay mở rộng chiều cao hàng một cách không kiểm
  soát.
- Reference type 11 hiện chưa được đăng ký trong nguồn tham chiếu dùng chung của hệ thống (trả về
  rỗng) và định dạng phản hồi hiện tại của nguồn này chỉ có 3 trường chung (Id/Code/Name); việc bổ
  sung Reference type 11 để trả đủ 4 trường (Sales ID, Customer, Customer name, Delivery date) là mở
  rộng trên đúng cơ chế tham chiếu dùng chung đã có, không xây dựng endpoint/nguồn dữ liệu mới.
- Kích thước trang mặc định và cách sắp xếp mặc định (ví dụ theo Sales ID) áp dụng theo đúng chuẩn
  đã dùng ở các bảng tham chiếu EUTR khác trong hệ thống.
- Việc lọc PO theo `InterCompanyOriginalSalesId` ở reference type = 16 sẽ được bổ sung theo đúng cơ
  chế filter dùng chung hiện có (tương tự cách reference type = 11 đã được mở rộng ở Update 1) —
  không xây dựng endpoint tham chiếu riêng cho Map File.
- Các cột cụ thể hiển thị ở bảng PO Step 1 (hiện đang là Vendor/Vendor Name/Rate/Material dạng demo)
  có thể cần điều chỉnh lại để khớp với các trường thật có sẵn từ D365 ở reference type = 16 — việc
  ánh xạ cột cụ thể (giữ, đổi tên, hoặc bỏ cột nào) sẽ được quyết định ở giai đoạn thiết kế kỹ thuật
  (data-model/plan), không thuộc phạm vi đặc tả nghiệp vụ ở đây.
- `TemplateCode` dùng để lưu vào `eutr_purchase_attachments` khi Save PO Mapping lấy từ giá trị
  template đã gắn sẵn trên từng PO ở D365 (reference type = 16) — người dùng KHÔNG tự chọn template
  thủ công ở Step 1, chỉ chọn PO nào áp dụng cho hồ sơ EUTR.
- "Save PO Mapping" ghi đè toàn bộ tập `PurchId` hiện có của Sales ID đó trong
  `eutr_purchase_attachments` theo đúng lựa chọn hiện tại trên UI (PO bị bỏ chọn bị xóa khỏi bảng,
  PO mới chọn được thêm mới) — không tích lũy lịch sử các lần Save trước đó.
- Nút Upload và Save ở Step 2 (Map Files vào Template) tiếp tục ở trạng thái hiển thị/demo, chưa gọi
  API thật trong phạm vi cập nhật này — để lại cho một tính năng sau xử lý.
