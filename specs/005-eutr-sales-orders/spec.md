# Feature Specification: EUTR Sales Orders Management

**Feature Branch**: `005-eutr-sales-orders`

**Created**: 2026-07-14

**Status**: Draft

**Input**: User description: "chức năng mới eutr-sales-orders. giao diện front end trong eutr-sales-orders. đổ dữ liệu từ ComplianceSys.Api.Controllers, [HttpPost("reference")] với reftype = 11, các cột sales id, customer, customer name. delivery date. cột tempate, progess để cố định dữ liệu demo"

## Clarifications

### Session 2026-07-20 (Update 4) — Màn hình View Sales Order (ViewSalesOrderPage) lấy dữ liệu thật, chỉ đọc

- Change: Màn hình **View Sales Order** (`ViewSalesOrderPage`, mở từ nút "View" ở Overview, route
  `/eutr/sales-orders/:salesId/view`) hiện đang dùng toàn bộ dữ liệu mock (`MOCK_SALES_ORDERS`,
  `MOCK_SO_POS`, `MOCK_SO_PO_MAPPINGS`, `MOCK_AVAILABLE_FILES`, `MOCK_FILE_MAPPINGS`,
  `EUTR_TEMPLATE_DETAILS_MAP`, `EUTR_TEMPLATES`). Update này chuyển màn hình sang dữ liệu thật, dùng
  lại đúng các nguồn dữ liệu/cơ chế đã áp dụng cho `MapFilePage` ở Update 2/3, nhưng ở chế độ **chỉ
  xem (read-only)** — không có bất kỳ chỉnh sửa nào:
  - Kiểm tra Sales Order có tồn tại hay không (`if (!so)`) MUST dùng cùng nguồn tham chiếu dùng chung
    reference type = 11 theo Sales ID trên URL (giống Map File FR-014), không dùng `MOCK_SALES_ORDERS`.
  - Header (Sales ID, Customer, Customer name) MUST lấy dữ liệu thật từ cùng bản ghi reference type =
    11 vừa tra được.
  - Danh sách **Purchase Orders đã chọn** MUST lấy từ các bản ghi đã lưu trong
    `eutr_purchase_attachments` của Sales ID này (không phải toàn bộ PO khả dụng như Step 1 Map File,
    chỉ những PO đã Save), tra cứu thêm thông tin hiển thị (tên, order account, số lượng...) từ nguồn
    tham chiếu dùng chung reference type = 16 — không dùng `MOCK_SO_POS`/`MOCK_SO_PO_MAPPINGS`. Các
    cột demo cũ (Vendor/Vendor Name/Rate/Material) không còn nguồn dữ liệu thật tương ứng nên được
    thay bằng các trường thật sẵn có (PO, Name, Order account, Qty) — đúng bộ cột đã dùng ở Step 1
    Map File.
  - **Template Checklist** MUST được xây dựng dựa trên (các) `TemplateCode` lấy từ các bản ghi
    `eutr_purchase_attachments` của Sales ID này, theo đúng cơ chế xây cây đã dùng ở Step 2 Map File
    (FR-023/FR-024) — không dùng `EUTR_TEMPLATE_DETAILS_MAP`/`so.templateId` mock.
  - Trạng thái từng step trong Template Checklist (đã có tài liệu / còn thiếu) MUST dựa trên tài liệu
    thật lấy từ `eutr_references` cho (các) PO đã lưu của Sales Order này, theo đúng cơ chế đã dùng ở
    Map File Step 2 (FR-026/FR-027) — không dùng `MOCK_AVAILABLE_FILES`/`MOCK_FILE_MAPPINGS`.
  - Toàn bộ màn hình View MUST ở chế độ **chỉ đọc**: không có chức năng tick chọn PO, map/unmap tài
    liệu, hay upload tài liệu mới (khác với Map File). Người dùng chỉ có thể mở rộng/thu gọn cây để
    xem, không thay đổi dữ liệu.
  - Nút **Edit / Map File** MUST điều hướng người dùng sang màn hình **Map File**
    (`/eutr/sales-orders/:salesId/map-file`) của đúng Sales Order đang xem — đây là nơi duy nhất để
    chỉnh sửa PO/mapping tài liệu.
  - Nút **Download** tiếp tục hiển thị nhưng **tạm thời KHÔNG xử lý tải file thật** — giữ hành vi
    demo/no-op, việc xử lý thật để lại cho một cập nhật sau (ngoài phạm vi Update 4).
  - Phần **Validation Summary** MUST tính toán dựa trên dữ liệu step thật: liệt kê (các) Purchase
    Order đã chọn (từ `eutr_purchase_attachments`), số step Required đã đủ tài liệu, và số/step
    Required còn thiếu tài liệu (kèm tên step thiếu) — không dùng dữ liệu demo. Điều kiện "File không
    hết hạn" ở bản mock trước đây tạm thời không áp dụng được vì dữ liệu tài liệu thật hiện chưa có
    thông tin ngày hết hạn.

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

### Session 2026-07-20 (Update 3) — Step 1: cho phép chọn thêm PO chưa gắn Template; nút Back về Sales Orders

- Change: Ở **Step 1** của Map File, các PO **chưa có bản ghi nào trong `eutr_purchase_attachments`**
  (chưa từng được Save PO Mapping trước đó cho Sales Order này) vẫn PHẢI hiển thị checkbox ở trạng
  thái **có thể tick chọn** (không bị vô hiệu hóa), miễn là PO đó có sẵn giá trị template từ D365
  (trường `eutrTemplate` trả về từ nguồn tham chiếu reference type = 16 dùng để hiển thị danh sách PO
  ở Step 1) — nghĩa là người dùng có thể tick chọn **thêm** các PO này bên cạnh các PO đã được tick
  sẵn từ lần Save trước, không bị giới hạn chỉ được chọn lại đúng các PO cũ.
  - PO chỉ thực sự bị vô hiệu hóa (không cho tick) khi bản thân D365 không trả về giá trị template
    nào cho PO đó (`eutrTemplate` rỗng) — trường hợp này giữ nguyên theo FR-022 hiện có, vì
    `TemplateCode` là trường bắt buộc (`NOT NULL`) của `eutr_purchase_attachments`.
  - Khi nhấn **Save PO Mapping**, các PO mới được tick chọn thêm (trước đó chưa có bản ghi) MUST được
    lưu (ghi thêm bản ghi mới) vào `eutr_purchase_attachments` cùng với các PO đã chọn từ trước, với
    `TemplateCode` lấy đúng từ giá trị `eutrTemplate` trả về bởi nguồn dữ liệu PO ở Step 1 (reference
    type = 16) — người dùng không tự nhập/chọn Template thủ công cho các PO này, giữ đúng cơ chế lấy
    TemplateCode đã áp dụng từ Update 2 (FR-020).
  - Hành vi lưu này vẫn tuân theo nguyên tắc "đồng bộ đúng lựa chọn hiện tại trên UI" đã có ở FR-021:
    sau khi Save, tập bản ghi trong `eutr_purchase_attachments` của Sales ID này phải khớp chính xác
    với toàn bộ các PO đang được tick (bao gồm cả PO cũ đã chọn từ trước và PO mới chọn thêm ở lần
    này); PO nào đang tick nhưng bị bỏ tick thì bản ghi tương ứng bị xóa.
- Change: Nút **Back** ở đầu màn hình Map File hiện chưa có hành vi (không gắn xử lý khi nhấn). Update
  này bổ sung: nhấn nút Back MUST điều hướng người dùng quay lại màn hình **EUTR Sales Orders**
  (Overview, route `/eutr/sales-orders`) — cùng đích đến với liên kết breadcrumb đã có sẵn trên màn
  hình này.

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
lựa chọn; nếu Sales Order đã từng được lưu PO trước đó, các PO đó tự động được tick sẵn khi mở lại, và
người dùng vẫn có thể tick chọn thêm các PO khác chưa từng được lưu (miễn PO đó có sẵn template từ
D365) trước khi Save lại. Người dùng cũng có thể nhấn nút **Back** để quay lại màn hình EUTR Sales
Orders bất cứ lúc nào. Ở
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
lưu và danh sách tài liệu thật lấy từ `eutr_references` cho các PO đó, đúng vị trí step. Sau đó tick
chọn thêm một PO khác chưa từng được lưu (còn có template từ D365) và Save, xác nhận
`eutr_purchase_attachments` được cập nhật để bao gồm cả PO mới chọn thêm lẫn các PO đã chọn trước đó,
và khi tải lại trang, toàn bộ lựa chọn mới vẫn được giữ. Cuối cùng nhấn nút Back, xác nhận điều hướng
về đúng màn hình EUTR Sales Orders.

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
9. **Given** Sales Order đã có sẵn một số PO được tick từ lần Save trước, và còn (các) PO khác chưa
   từng được lưu nhưng có sẵn template từ D365, **When** người dùng mở Step 1, **Then** các PO chưa
   lưu đó vẫn hiển thị checkbox ở trạng thái có thể tick (không bị vô hiệu hóa), cho phép chọn thêm
   bên cạnh các PO đã tick sẵn.
10. **Given** người dùng tick chọn thêm một PO chưa từng được lưu (có template từ D365) bên cạnh các
    PO đã tick sẵn, rồi nhấn Save PO Mapping, **When** lưu thành công, **Then**
    `eutr_purchase_attachments` MUST có thêm bản ghi mới cho PO vừa chọn thêm, với `TemplateCode` lấy
    đúng từ giá trị template của PO đó trả về ở Step 1 (không yêu cầu người dùng chọn Template thủ
    công), đồng thời vẫn giữ nguyên các bản ghi của các PO đã chọn từ trước đó chưa bị bỏ tick.
11. **Given** đang ở màn hình Map File (Step 1 hoặc Step 2), **When** người dùng nhấn nút **Back**,
    **Then** hệ thống điều hướng về màn hình **EUTR Sales Orders** (Overview).

---

### User Story 5 - Xem tổng quan hồ sơ EUTR của Sales Order, chỉ đọc (View Sales Order) (Priority: P2)

Từ màn hình EUTR Sales Orders, người dùng nhấn nút "View" trên một dòng để mở màn hình **View Sales
Order** của Sales Order đó. Màn hình kiểm tra Sales Order có tồn tại hay không (cùng nguồn tham chiếu
dùng chung với Overview/Map File), hiển thị đúng thông tin Sales ID/Customer/Customer name ở header,
danh sách các **Purchase Order đã chọn** (lấy từ `eutr_purchase_attachments`, tra cứu thêm thông tin
PO thật từ D365), và **Template Checklist** — cây các bước của (các) template gắn với Sales Order đó,
mỗi bước hiển thị đúng trạng thái đã có tài liệu hay còn thiếu (dựa trên `eutr_references`). Toàn bộ
màn hình chỉ ở chế độ xem — không có thao tác tick chọn PO, map/unmap tài liệu hay upload nào. Muốn
thay đổi, người dùng nhấn nút **Edit / Map File** để chuyển sang màn hình Map File. Nút **Download**
hiển thị nhưng chưa xử lý tải file thật. Phần **Validation Summary** tổng hợp từ dữ liệu step thật:
liệt kê (các) PO đã chọn, số step đã đủ tài liệu, số step còn thiếu tài liệu.

**Why this priority**: Đây là góc nhìn tổng quan (read-only) song song với Map File — giúp người dùng
kiểm tra nhanh tình trạng hồ sơ EUTR của một Sales Order mà không rủi ro làm thay đổi dữ liệu; phụ
thuộc vào cùng dữ liệu thật đã có ở Map File (User Story 4) nên xếp cùng mức ưu tiên, sau khi xem được
danh sách (User Story 1).

**Independent Test**: Mở View cho một Sales Order đã Save PO Mapping với một số step đã có tài liệu
và một số step còn thiếu, xác nhận header/danh sách PO/Template Checklist/Validation Summary hiển thị
đúng dữ liệu thật, không có control chỉnh sửa nào hoạt động; nhấn Edit/Map File xác nhận điều hướng
đúng sang Map File của Sales Order đó; nhấn Download xác nhận không có xử lý tải file thật nào xảy ra.

**Acceptance Scenarios**:

1. **Given** Sales ID hợp lệ tồn tại ở nguồn tham chiếu type = 11, **When** mở View, **Then** header
   hiển thị đúng Sales ID/Customer/Customer name khớp với dữ liệu ở Overview/Map File.
2. **Given** Sales ID không tồn tại ở nguồn tham chiếu type = 11, **When** mở View, **Then** màn hình
   hiển thị lỗi "Sales Order không tồn tại", không hiển thị danh sách PO/Template Checklist/Validation
   Summary.
3. **Given** Sales Order đã Save PO Mapping với một số PurchId, **When** mở View, **Then** danh sách
   "Purchase Orders đã chọn" hiển thị đúng các PO đó với thông tin thật (PO, Name, Order account, Qty)
   tra cứu từ D365 — không hiển thị các cột demo Vendor/Vendor Name/Rate/Material.
4. **Given** Sales Order chưa Save PO Mapping nào (chưa có bản ghi trong `eutr_purchase_attachments`),
   **When** mở View, **Then** danh sách PO hiển thị trạng thái trống rõ ràng ("Chưa chọn PO nào") và
   Template Checklist hiển thị trạng thái "chưa có cây template".
5. **Given** (các) PO đã lưu gắn với một hoặc nhiều `TemplateCode`, **When** xem Template Checklist,
   **Then** cây hiển thị đúng theo (các) `TemplateCode` đó, mỗi template hiển thị một lần duy nhất.
6. **Given** một step trong cây có tài liệu thật trong `eutr_references`, **When** xem Template
   Checklist, **Then** step đó hiển thị trạng thái "đã map"; step Required chưa có tài liệu hiển thị
   trạng thái "thiếu".
7. **Given** đang ở màn hình View, **When** người dùng click vào node cây hoặc vào file, **Then**
   không có hành vi tick chọn PO/map/unmap/upload nào xảy ra (chỉ cho phép expand/collapse cây để
   xem).
8. **Given** đang ở màn hình View, **When** nhấn nút Edit / Map File, **Then** hệ thống điều hướng
   sang màn hình Map File (route `/eutr/sales-orders/:salesId/map-file`) của đúng Sales Order đang
   xem.
9. **Given** đang ở màn hình View, **When** nhấn nút Download, **Then** không có xử lý tải file thật
   nào xảy ra (giữ hành vi demo/no-op).
10. **Given** Validation Summary đang hiển thị, **When** xem, **Then** thông tin hiển thị đúng: (các)
    PO đã chọn, số step Required đã đủ tài liệu, số step Required còn thiếu tài liệu kèm tên các step
    thiếu.

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
- PO chưa có bản ghi trong `eutr_purchase_attachments` nhưng có sẵn giá trị template từ D365
  (`eutrTemplate` không rỗng): checkbox của PO đó ở Step 1 vẫn ở trạng thái có thể tick chọn (không bị
  vô hiệu hóa) — không được coi là "chưa gắn Template" theo nghĩa bị chặn chọn của FR-022, vì FR-022
  chỉ áp dụng cho trường hợp D365 hoàn toàn không có giá trị template cho PO đó.
- Người dùng bỏ tick một PO đã lưu trước đó và đồng thời tick thêm một PO mới chưa từng lưu, rồi nhấn
  Save PO Mapping một lần: kết quả sau khi lưu MUST khớp chính xác với toàn bộ tập PO đang được tick
  tại thời điểm nhấn Save (PO bị bỏ tick bị xóa bản ghi, PO mới tick có bản ghi mới) — không phân biệt
  xử lý theo thứ tự tick chọn trước/sau.
- Người dùng nhấn nút Back khi đang có thay đổi lựa chọn PO ở Step 1 nhưng **chưa** nhấn Save PO
  Mapping: hệ thống vẫn điều hướng về EUTR Sales Orders ngay khi nhấn Back — không tự động lưu, cũng
  không cần xác nhận rời trang (đúng hành vi read/act đơn giản đã áp dụng cho các thao tác điều hướng
  khác trong hệ thống).
- Sales Order tồn tại (ref type = 11) nhưng chưa từng Save PO Mapping: màn hình View hiển thị danh
  sách Purchase Orders đã chọn ở trạng thái trống, Template Checklist hiển thị "chưa có cây template",
  Validation Summary hiển thị điều kiện "đã chọn PO" ở trạng thái chưa đạt — không hiển thị dữ liệu
  mock đè lên.
- Một PurchId đã lưu trong `eutr_purchase_attachments` nhưng D365 (reference type = 16) không còn trả
  về bản ghi khớp tại thời điểm xem (ví dụ PO đã bị hủy/thay đổi bên D365): màn hình View vẫn hiển thị
  PurchId đó, các trường thông tin bổ sung (tên, order account, qty) hiển thị trống nếu không tra cứu
  được — không gây lỗi toàn màn hình.
- Nhiều PO đã lưu của cùng Sales Order trỏ tới cùng một `TemplateCode`: Template Checklist ở màn hình
  View chỉ hiển thị một cây duy nhất cho template đó, theo đúng nguyên tắc dedup đã áp dụng ở Overview
  và Step 2 Map File.
- Người dùng thử tương tác (click) vào node cây hoặc file ở màn hình View: hệ thống chỉ cho phép
  expand/collapse để xem, không phát sinh bất kỳ thay đổi dữ liệu nào (không có API ghi nào được gọi
  từ màn hình này).

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
- **FR-031**: Tại Step 1, các PO chưa có bản ghi nào trong `eutr_purchase_attachments` (chưa từng
  được Save PO Mapping) MUST tiếp tục hiển thị checkbox ở trạng thái có thể tick chọn (không bị vô
  hiệu hóa), miễn là D365 có trả về giá trị template cho PO đó — cho phép người dùng chọn thêm các PO
  này bên cạnh các PO đã tick sẵn từ lần Save trước, không chỉ giới hạn tick lại đúng các PO cũ. Điều
  kiện vô hiệu hóa checkbox theo FR-022 (PO không có template từ D365) vẫn được giữ nguyên.
- **FR-032**: Khi Save PO Mapping với (các) PO mới được tick chọn thêm ở FR-031, hệ thống MUST lưu
  thêm bản ghi mới vào `eutr_purchase_attachments` cho các PO đó với `TemplateCode` lấy từ giá trị
  template (`eutrTemplate`) do nguồn dữ liệu PO ở Step 1 (reference type = 16) trả về — không yêu cầu
  người dùng tự chọn Template thủ công; hành vi đồng bộ toàn bộ tập bản ghi theo đúng lựa chọn hiện
  tại trên UI (FR-021) vẫn áp dụng cho các PO mới chọn thêm này.
- **FR-033**: Nút **Back** trên màn hình Map File MUST điều hướng người dùng quay lại màn hình **EUTR
  Sales Orders** (Overview, route `/eutr/sales-orders`) khi được nhấn — không để trống không phản
  hồi như hiện tại.
- **FR-034**: Màn hình **View Sales Order** (`ViewSalesOrderPage`) MUST kiểm tra Sales Order có tồn
  tại hay không bằng cách tra cứu cùng nguồn tham chiếu dùng chung reference type = 11 (giống Map File
  FR-014) theo Sales ID trên URL — không dùng dữ liệu mock (`MOCK_SALES_ORDERS`).
- **FR-035**: Nếu Sales ID không tồn tại ở nguồn tham chiếu type = 11, màn hình View MUST hiển thị
  thông báo lỗi rõ ràng ("Sales Order không tồn tại") và không hiển thị danh sách Purchase Orders,
  Template Checklist, hay Validation Summary.
- **FR-036**: Header của màn hình View (Sales ID, Customer, Customer name) MUST lấy dữ liệu thật từ
  cùng bản ghi reference type = 11 đã tra được ở FR-034 — không dùng dữ liệu mock.
- **FR-037**: Danh sách **Purchase Orders đã chọn** ở màn hình View MUST lấy từ các bản ghi đã lưu
  trong `eutr_purchase_attachments` của Sales ID này, tra cứu thêm thông tin hiển thị (tên, order
  account, số lượng) từ nguồn tham chiếu dùng chung reference type = 16 — không dùng
  `MOCK_SO_POS`/`MOCK_SO_PO_MAPPINGS` và không hiển thị các cột demo cũ (Vendor/Vendor Name/Rate/
  Material) không có nguồn dữ liệu thật tương ứng.
- **FR-038**: Nếu Sales ID chưa có bản ghi nào trong `eutr_purchase_attachments`, danh sách Purchase
  Orders đã chọn ở màn hình View MUST hiển thị trạng thái trống rõ ràng ("Chưa chọn PO nào").
- **FR-039**: **Template Checklist** ở màn hình View MUST được xây dựng dựa trên (các) `TemplateCode`
  lấy từ các bản ghi `eutr_purchase_attachments` của Sales ID này, theo đúng cơ chế xây cây đã áp dụng
  ở Step 2 Map File (FR-023/FR-024) — không dùng `EUTR_TEMPLATE_DETAILS_MAP`/`so.templateId` mock.
- **FR-040**: Nếu Sales ID chưa Save PO Mapping nào (chưa có bản ghi trong `eutr_purchase_attachments`),
  Template Checklist ở màn hình View MUST hiển thị trạng thái "chưa có cây template" rõ ràng (giống
  Map File FR-025), không hiển thị cây mock.
- **FR-041**: Mỗi step trong Template Checklist ở màn hình View MUST hiển thị đúng trạng thái "đã có
  tài liệu"/"còn thiếu" dựa trên tài liệu thật lấy từ `eutr_references` cho (các) PO đã lưu của Sales
  Order này, theo đúng cơ chế đã dùng ở Map File Step 2 (FR-026/FR-027) — không dùng
  `MOCK_AVAILABLE_FILES`/`MOCK_FILE_MAPPINGS`.
- **FR-042**: Toàn bộ màn hình View MUST ở chế độ **chỉ đọc** — không cung cấp chức năng tick chọn PO,
  map/unmap tài liệu, hay upload tài liệu mới; chỉ cho phép mở rộng/thu gọn (expand/collapse) cây để
  xem, không làm thay đổi dữ liệu.
- **FR-043**: Nút **Edit / Map File** trên màn hình View MUST điều hướng người dùng sang màn hình
  **Map File** (route `/eutr/sales-orders/:salesId/map-file`) của đúng Sales Order đang xem.
- **FR-044**: Nút **Download** trên màn hình View MUST tiếp tục hiển thị nhưng KHÔNG xử lý tải file
  thật — giữ hành vi demo/no-op tạm thời, việc xử lý thật để lại cho một cập nhật sau.
- **FR-045**: Phần **Validation Summary** ở màn hình View MUST được tính toán từ dữ liệu step thật
  (không dùng dữ liệu mock): liệt kê (các) Purchase Order đã chọn (từ `eutr_purchase_attachments`), số
  step Required đã có tài liệu (đủ file), và số step Required còn thiếu tài liệu (kèm tên các step
  thiếu).
- **FR-046**: Validation Summary ở màn hình View MUST hiển thị trạng thái "chưa đạt" khi Sales Order
  chưa chọn PO nào hoặc còn ít nhất 1 step Required thiếu tài liệu — theo đúng nguyên tắc điều kiện đã
  áp dụng ở phiên bản mock trước đây, nay dựa trên dữ liệu thật; điều kiện "File không hết hạn" của
  bản mock trước đây tạm thời không áp dụng vì dữ liệu tài liệu thật hiện chưa có thông tin ngày hết
  hạn.

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
- **View Sales Order** (màn hình `ViewSalesOrderPage`) — **cập nhật từ Update 4**: dùng lại đúng các
  entity đã mô tả ở trên (Sales Order, Purchase Attachment, Purchase Order, Template, Reference,
  Document) theo chế độ **chỉ đọc** — màn hình này không ghi/sửa/xóa bất kỳ bản ghi nào ở
  `eutr_purchase_attachments`, `eutr_references`, hay các bảng liên quan; mọi thao tác ghi được
  chuyển hướng sang màn hình Map File qua nút Edit / Map File.

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
- **SC-009**: 100% PO có sẵn template từ D365 hiển thị ở Step 1 đều có thể tick chọn được, bất kể PO
  đó đã có bản ghi trong `eutr_purchase_attachments` hay chưa; sau khi Save PO Mapping, tập bản ghi
  trong `eutr_purchase_attachments` luôn khớp chính xác với toàn bộ PO đang được tick tại thời điểm
  Save (không thiếu, không thừa).
- **SC-010**: 100% lượt nhấn nút Back trên màn hình Map File điều hướng đúng về màn hình EUTR Sales
  Orders, không có trường hợp không phản hồi.
- **SC-011**: 100% Sales ID hợp lệ mở màn hình View đều thấy đúng header thật (Sales ID/Customer/
  Customer name) khớp với dữ liệu đã thấy ở Overview/Map File — không có trường hợp hiển thị dữ liệu
  mock.
- **SC-012**: 100% Purchase Order hiển thị ở danh sách "đã chọn" trên màn hình View khớp chính xác với
  các bản ghi đang có trong `eutr_purchase_attachments` tại thời điểm xem — không thiếu, không thừa.
- **SC-013**: 100% step trong Template Checklist ở màn hình View phản ánh đúng trạng thái đã có tài
  liệu/còn thiếu dựa theo tài liệu thật ở `eutr_references` — khớp với trạng thái tương ứng ở Step 2
  Map File của cùng Sales Order.
- **SC-014**: 100% lượt nhấn Edit / Map File từ màn hình View điều hướng đúng sang Map File của đúng
  Sales Order đang xem.
- **SC-015**: 0% thao tác click/tương tác trên màn hình View (ngoài expand/collapse cây) gây ra thay
  đổi dữ liệu (không có bản ghi nào bị ghi/sửa/xóa từ màn hình này trong 100% các phép thử).

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
- "PO chưa gắn vào Template" trong yêu cầu Update 3 được hiểu là PO **chưa có bản ghi** trong
  `eutr_purchase_attachments` (chưa từng được Save PO Mapping cho Sales Order này) — khác với trường
  hợp PO hoàn toàn không có giá trị template từ D365 (trường hợp này vẫn bị chặn chọn theo FR-022).
  Miễn PO có sẵn template từ D365, PO đó luôn có thể được tick chọn dù đã lưu hay chưa.
- TemplateCode lưu cho các PO mới chọn thêm vẫn lấy từ cột `eutrTemplate` của nguồn dữ liệu PO ở
  Step 1 (reference type = 16) — theo đúng xác nhận của người yêu cầu tính năng, không có cơ chế nhập
  Template thủ công nào được bổ sung ở Update 3.
- Nút Back điều hướng thẳng về màn hình EUTR Sales Orders, tương đương hành vi đã có sẵn của liên kết
  breadcrumb trên cùng màn hình Map File — không cần xác nhận rời trang dù có thay đổi chưa lưu.
- Màn hình View chỉ hiển thị các Purchase Order **đã lưu** (đã Save PO Mapping) cho Sales Order đó —
  khác với Step 1 Map File vốn hiển thị toàn bộ PO khả dụng từ D365 để người dùng chọn; View không
  cần hiển thị các PO chưa được chọn/lưu vì đây là màn hình xem tổng quan hồ sơ đã hoàn thiện, không
  phải màn hình chọn PO.
- Các cột hiển thị cho Purchase Orders đã chọn ở màn hình View (PO, Name, Order account, Qty) dùng lại
  đúng bộ trường thật đã có sẵn từ nguồn tham chiếu reference type = 16 (giống Step 1 Map File) — các
  cột demo cũ (Vendor/Vendor Name/Rate/Material) không còn nguồn dữ liệu thật tương ứng nên được thay
  thế, việc ánh xạ cột cụ thể (giữ/đổi tên) là quyết định kỹ thuật ở giai đoạn plan, không thuộc phạm
  vi đặc tả nghiệp vụ ở đây.
- Do dữ liệu tài liệu thật hiện lấy từ `eutr_references`/`eutr_documents` chưa có thông tin ngày hết
  hạn (validFrom/expiredDate), điều kiện "File không hết hạn" trong Validation Summary phiên bản mock
  trước đây tạm thời không áp dụng được với dữ liệu thật; Validation Summary màn hình View chỉ còn 2
  điều kiện chính: đã chọn ít nhất 1 PO, và Required steps đủ file — cho tới khi có nguồn dữ liệu hạn
  sử dụng tài liệu thật ở một cập nhật sau.
- Nút Submit EUTR (nếu còn giữ trên giao diện màn hình View) không thuộc phạm vi Update 4 — tiếp tục ở
  trạng thái demo/disabled, tính theo 2 điều kiện Validation Summary nêu trên; xử lý submit thật để
  lại cho một tính năng sau.
- Việc mở rộng/thu gọn (expand/collapse) node cây ở Template Checklist của màn hình View không được
  coi là hành vi chỉnh sửa dữ liệu — chỉ là tương tác hiển thị cục bộ trên UI, không gọi API ghi nào.
