# Feature Specification: EUTR Purchase Orders

**Feature Branch**: `012-eutr-purchase-orders`

**Created**: 2026-08-14

**Status**: Draft

**Input**: User description: "chức năng mới eutr-purchase-orders. màn hình hiển thị dữ liệu từ API reference với type = 15, các cột hiển thị. Purch id, Vendor code, Vendor name, Template, Progress, Action [View]. Progress dựa vào Template (003-eutr-templates) để lấy ra các step rồi kiểm tra với 004-eutr-documents để biết step nào có tài liệu, missing. Bấm vào View thì vào màn hình PurchId/View. màn hình giống link eutr/sales-orders/SO004813/map-file ở 005-eutr-sales-orders. nhưng bỏ phần Step 1 choose Purchase order, rồi chỗ hiển thị thông tin Sales ID, Customer thì đổi thành thông tin Purch id, bỏ thông tin seelcted POs"

## Clarifications

### Session 2026-09-07 (Update 1)

- Input: Cập nhật 012-eutr-purchase-orders. Trong màn hình chi tiết (`PurchId/View`), khi người dùng
  nhấn nút Upload, popup Add tài liệu (dùng chung với 004-eutr-documents) hiện đang mở với trường
  **Type** trống (`null`) và trường **Value** trống (`[]`) — giống hệt cách popup mở ở màn hình Map
  File của 005-eutr-sales-orders (không tự điền, theo đúng quyết định Decision 26 của spec đó).
- Change: Riêng ở màn hình `PurchId/View` của 012-eutr-purchase-orders, khi nhấn Upload, popup Add
  tài liệu MUST tự điền sẵn: trường **Type** = `PO`, trường **Value** = chính Purch Id đang xem
  (dòng Purchase Order tương ứng lấy từ nguồn tham chiếu type = 15). Người dùng vẫn có thể đổi Type
  và/hoặc Value sang giá trị khác sau khi popup mở (không khóa/disable hai trường này) — tự điền chỉ
  nhằm giảm thao tác lặp lại cho tình huống phổ biến nhất (đính tài liệu cho đúng PO đang xem).
- Change: Việc tự điền chỉ áp dụng khi nhấn Upload từ màn hình `PurchId/View` (012-eutr-purchase-orders).
  Hành vi Upload ở màn hình Map File (005-eutr-sales-orders) giữ nguyên như cũ — KHÔNG tự điền Type/Value
  — vì Decision 26 của 005-eutr-sales-orders coi đây là quyết định riêng của luồng đó, không bị thay đổi
  bởi cập nhật này.

### Session 2026-09-10 (Update 2)

- Input: Cập nhật 012-eutr-purchase-orders. Ở màn hình chi tiết (`PurchId/View`), khi úp tài liệu, popup
  Add tài liệu có trường **Type** gồm các giá trị **PO**, **Vendor**, **Invoice**, **Delivery note** (các
  loại tham chiếu đã có sẵn trong hệ thống, dùng chung với 004-eutr-documents). Khi người dùng đổi giá
  trị Type, hệ thống MUST tự động điền lại dữ liệu vào trường **Value**: nếu Type là **PO**, **Invoice**,
  hoặc **Delivery note** thì Value tự điền Purch Id của Purchase Order đang xem (dòng đang active trên
  màn hình); nếu Type là **Vendor** thì Value tự điền Vendor Code của Purchase Order đang xem.
- Change: Mở rộng hành vi tự điền của Update 1 (FR-024/025/026, vốn chỉ tự điền một lần khi popup mở với
  Type mặc định = PO) thành tự điền lại Value **mỗi khi Type thay đổi** trong lúc popup đang mở, không
  chỉ ở lần mở đầu tiên — xem FR-027/028/029 mới bổ sung bên dưới.
- Decision: "Purch Id của dòng active" được hiểu là Purch Id của chính Purchase Order đang xem trên màn
  hình `PurchId/View` (đã cố định theo `PurchId` trên URL — màn hình này không có bảng nhiều dòng/nhiều
  Purchase Order để chọn "dòng active" khác, xem Assumptions), thống nhất với cách FR-024 đã dùng "Purch
  Id đang xem" ở Update 1. Tương tự, "Vendor Code" là Vendor code của chính Purchase Order đang xem.
- Decision: Nếu người dùng chọn một Type khác ngoài 4 giá trị trên (ví dụ "General agreement"), Value
  KHÔNG bị tự điền/ghi đè — giữ nguyên hành vi nhập tay hiện có của popup dùng chung (004-eutr-documents)
  cho các Type không thuộc nhóm PO-like/Vendor.
- Decision: Việc tự điền lại Value theo Type mới sẽ **ghi đè** giá trị Value hiện tại (kể cả khi người
  dùng đã tự nhập/đổi Value trước đó) — vì mục tiêu là luôn khớp đúng Type vừa chọn, tránh trường hợp
  Value cũ (thuộc Type trước) bị hiểu nhầm là hợp lệ với Type mới. Value sau khi tự điền lại vẫn KHÔNG bị
  khóa, người dùng vẫn có thể sửa tiếp trước khi lưu (giữ nguyên nguyên tắc "không khóa trường" của
  FR-025).
- Change: Phạm vi áp dụng vẫn giữ nguyên như Update 1 — CHỈ áp dụng cho popup Add tài liệu mở từ nút
  Upload tại `PurchId/View` (012-eutr-purchase-orders). Màn hình Map File (005-eutr-sales-orders) không
  bị ảnh hưởng bởi thay đổi này.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem danh sách EUTR Purchase Orders (Priority: P1)

Người dùng vào mục **EUTR > EUTR Purchase Orders** từ thanh điều hướng và thấy một bảng liệt kê các
purchase order lấy từ hệ thống ERP (D365) thông qua nguồn dữ liệu tham chiếu dùng chung đã có sẵn
trong hệ thống (reference type = 15 — cùng nguồn dữ liệu Purchase Order đã dùng ở 004-eutr-documents
và 011-eutr-synchronize-data). Bảng hiển thị các cột: **Purch id**, **Vendor code**, **Vendor name**,
**Template**, **Progress**, và cột **Action** với nút **View**. Cột Template hiển thị đúng template
compliance thật đang gắn với chính Purchase Order đó. Cột Progress hiển thị tiến độ tài liệu thật của
Purchase Order đó — số step bắt buộc (Required) đã có tài liệu/tổng số step bắt buộc của Template đó
và tỷ lệ %, tính bằng cách lấy danh sách step của Template (003-eutr-templates) rồi đối chiếu với tài
liệu đã ghi nhận cho Purchase Order đó (004-eutr-documents) để xác định step nào đã có tài liệu, step
nào còn thiếu (missing).

**Why this priority**: Đây là giá trị cốt lõi và duy nhất của tính năng ở giai đoạn xem danh sách —
cho phép người dùng thấy ngay tình trạng tài liệu compliance của toàn bộ purchase order mà không phải
mở từng đơn một.

**Independent Test**: Mở màn hình EUTR Purchase Orders, xác nhận bảng hiển thị đúng 6 cột (Purch id,
Vendor code, Vendor name, Template, Progress, Action); với một Purchase Order có Template gắn sẵn và
một số step Required đã có tài liệu trong khi số khác thì chưa, cột Progress hiển thị đúng số liệu
completed/total/% khớp với dữ liệu Template thật (003-eutr-templates) và tài liệu thật
(004-eutr-documents) của đúng Purchase Order đó.

**Acceptance Scenarios**:

1. **Given** đang ở thanh điều hướng, **When** chọn "EUTR Purchase Orders", **Then** thấy bảng liệt
   kê purchase order với đầy đủ 6 cột (Purch id, Vendor code, Vendor name, Template, Progress,
   Action).
2. **Given** một purchase order có Vendor code và Vendor name lấy được từ nguồn dữ liệu, **When**
   bảng hiển thị dòng đó, **Then** cột Vendor code và Vendor name hiển thị đúng giá trị thật.
3. **Given** một purchase order không có Vendor name khả dụng từ nguồn dữ liệu, **When** bảng hiển
   thị dòng đó, **Then** cột Vendor name hiển thị trạng thái trống rõ ràng, không lỗi, không chặn
   hiển thị các cột còn lại của dòng đó.
4. **Given** một purchase order đã có Template gắn sẵn, **When** bảng hiển thị dòng đó, **Then** cột
   Template hiển thị đúng tên/mã template đó.
5. **Given** một purchase order chưa có Template nào gắn, **When** bảng hiển thị dòng đó, **Then**
   cột Template hiển thị trạng thái trống rõ ràng và cột Progress hiển thị trạng thái riêng cho biết
   chưa có Template (không suy diễn thành 0%).
6. **Given** một purchase order có Template với một số step Required chưa có tài liệu, **When** bảng
   hiển thị dòng đó, **Then** cột Progress hiển thị đúng `completed`/`total`/`%` tính theo step
   Required của Template đó, đối chiếu đúng tài liệu thật đã ghi nhận cho Purchase Order đó.
7. **Given** một purchase order có Template nhưng Template đó không có step Required nào, **When**
   bảng hiển thị dòng đó, **Then** cột Progress hiển thị trạng thái riêng cho biết không có step bắt
   buộc, không suy diễn thành 0% "chưa hoàn thành".
8. **Given** một purchase order có Template và mọi step Required của Template đó đã có tài liệu,
   **When** bảng hiển thị dòng đó, **Then** cột Progress hiển thị 100% hoàn thành.

---

### User Story 2 - Xem và quản lý tài liệu compliance của một Purchase Order (Priority: P1)

Từ bảng danh sách, người dùng nhấn nút **View** trên một dòng để điều hướng sang màn hình chi tiết
của đúng Purchase Order đó (`PurchId/View`). Màn hình này có bố cục và hành vi giống màn hình **Map
File** của 005-eutr-sales-orders (`eutr/sales-orders/{SalesId}/map-file`), nhưng:

- **Không có** phần "Step 1 — Choose Purchase Order" (không có bước chọn/tick Purchase Order nào cả,
  vì Purchase Order đang xem đã cố định theo `PurchId` trên URL).
- **Không có** bảng "Selected POs" (không còn khái niệm chọn nhiều PO để tổng hợp).
- Phần thông tin đầu trang (trước đây là Sales ID/Customer/Customer name) được thay bằng thông tin
  của chính Purchase Order đang xem: **Purch id**, **Vendor code**, **Vendor name**.
- Phần còn lại — cây thư mục theo step của Template đã gắn cho Purchase Order này, khu vực
  **AVAILABLE FILES** liệt kê tài liệu thật đã ghi nhận cho Purchase Order này (kèm trạng thái đã có
  tài liệu/còn thiếu cho từng step), và các thao tác **Upload** (thêm tài liệu mới) và **Edit** (sửa
  tài liệu đã có) — giữ nguyên hành vi như Step 2 của màn hình Map File, tái sử dụng đúng các popup
  Add/Edit tài liệu đã có ở 004-eutr-documents.

**Why this priority**: Đây là hành động chính người dùng thực hiện sau khi phát hiện một Purchase
Order còn thiếu tài liệu ở danh sách — không có giá trị nào nếu người dùng không thể mở và bổ sung
tài liệu cho đúng Purchase Order đó.

**Independent Test**: Từ danh sách, nhấn View trên một Purchase Order đã có Template; xác nhận màn
hình chi tiết mở ra hiển thị đúng thông tin Purch id/Vendor code/Vendor name ở đầu trang (không phải
Sales ID/Customer), không có phần chọn Purchase Order và không có bảng Selected POs, có cây thư mục
theo đúng step của Template đó và khu vực AVAILABLE FILES hiển thị tài liệu thật; nhấn Upload thêm
một tài liệu mới cho một step còn thiếu, xác nhận sau khi lưu thành công, khu vực AVAILABLE FILES và
trạng thái của step đó trong cây được cập nhật ngay mà không cần tải lại trang.

**Acceptance Scenarios**:

1. **Given** đang ở danh sách Purchase Orders, **When** nhấn nút View trên một dòng, **Then** hệ
   thống điều hướng sang màn hình chi tiết của đúng Purchase Order đó theo địa chỉ dạng
   `.../purchase-orders/{PurchId}/view`.
2. **Given** đã mở màn hình chi tiết của một Purchase Order tồn tại, **When** trang tải xong, **Then**
   phần đầu trang hiển thị đúng Purch id, Vendor code, Vendor name của Purchase Order đó — không hiển
   thị Sales ID/Customer.
3. **Given** đã mở màn hình chi tiết, **When** người dùng quan sát bố cục màn hình, **Then** không có
   phần "Step 1 — Choose Purchase Order" và không có bảng "Selected POs" ở bất kỳ đâu trên màn hình.
4. **Given** Purchase Order đang xem có Template gắn sẵn, **When** trang tải xong, **Then** cây thư
   mục hiển thị đúng các step của Template đó, và khu vực AVAILABLE FILES hiển thị đúng tài liệu thật
   đã ghi nhận cho Purchase Order này, mỗi tài liệu gắn đúng step tương ứng.
5. **Given** một step trong cây chưa có tài liệu nào, **When** trang tải xong, **Then** step đó hiển
   thị trạng thái "còn thiếu" (missing) rõ ràng.
6. **Given** đang ở màn hình chi tiết, **When** nhấn Upload và tải lên một tài liệu hợp lệ cho một
   step, **Then** tài liệu mới được lưu thật, khu vực AVAILABLE FILES và trạng thái step đó trong cây
   được làm mới ngay, không cần tải lại toàn bộ trang.
7. **Given** đang ở màn hình chi tiết, **When** nhấn Edit trên một tài liệu đã có, **Then** popup Edit
   tài liệu (tái sử dụng từ 004-eutr-documents) mở ra cho đúng tài liệu đó và lưu thành công sẽ cập
   nhật đúng dữ liệu thật.
8. **Given** Purchase Order được truy cập qua `PurchId` trên URL không tồn tại trong nguồn dữ liệu
   tham chiếu, **When** mở màn hình chi tiết, **Then** hệ thống hiển thị thông báo lỗi rõ ràng
   ("Purchase Order không tồn tại") và không hiển thị phần còn lại của màn hình.
9. **Given** Purchase Order đang xem chưa có Template nào gắn, **When** mở màn hình chi tiết, **Then**
   hệ thống hiển thị trạng thái rõ ràng cho biết chưa có Template (không hiển thị cây thư mục rỗng gây
   hiểu nhầm là đã đầy đủ).
10. **Given** đang ở màn hình chi tiết của một Purchase Order (`PurchId/View`), **When** nhấn nút
    **Upload**, **Then** popup Add tài liệu mở ra với trường Type đã tự điền sẵn giá trị **PO** và
    trường Value đã tự điền sẵn chính Purch Id đang xem — người dùng không cần tự chọn lại hai trường
    này để đính tài liệu cho đúng PO đang xem.
11. **Given** popup Add tài liệu đã mở với Type = PO và Value = Purch Id đang xem (đã tự điền), **When**
    người dùng đổi Type và/hoặc Value sang giá trị khác trước khi lưu, **Then** hệ thống chấp nhận giá
    trị mới do người dùng chọn (hai trường không bị khóa).
12. **Given** popup Add tài liệu đang mở tại `PurchId/View`, **When** người dùng đổi Type sang **Invoice**
    hoặc **Delivery note**, **Then** trường Value tự động điền lại thành Purch Id của Purchase Order
    đang xem.
13. **Given** popup Add tài liệu đang mở tại `PurchId/View`, **When** người dùng đổi Type sang **Vendor**,
    **Then** trường Value tự động điền lại thành Vendor Code của Purchase Order đang xem.
14. **Given** popup Add tài liệu đang mở tại `PurchId/View` với Value đã tự điền theo một Type trước đó,
    **When** người dùng tiếp tục đổi sang một Type khác trong nhóm PO/Vendor/Invoice/Delivery note,
    **Then** Value được ghi đè bằng giá trị mặc định tương ứng Type mới (không giữ lại Value cũ), và
    người dùng vẫn có thể sửa tiếp Value sau khi tự điền lại.

---

### User Story 3 - Tìm kiếm Purchase Order theo Purch Id hoặc Vendor (Priority: P2)

Người dùng dùng ô tìm kiếm ở màn hình danh sách để lọc nhanh theo **Purch id**, **Vendor code**, hoặc
**Vendor name**, theo kiểu khớp "chứa" (không phân biệt hoa/thường) — theo đúng mẫu tìm kiếm tham
chiếu đã có trong các màn hình danh sách EUTR khác.

**Why this priority**: Hữu ích khi danh sách có số lượng lớn (dữ liệu Purchase Order thực tế có thể
lên tới hàng nghìn dòng), nhưng không phải điều kiện tiên quyết để tính năng có giá trị — người dùng
vẫn có thể phân trang thủ công để tìm nếu chưa có tìm kiếm.

**Independent Test**: Nhập một Purch Id hoặc một phần Vendor code/Vendor name đã biết vào ô tìm kiếm,
xác nhận danh sách kết quả chỉ còn các dòng khớp từ khóa đó.

**Acceptance Scenarios**:

1. **Given** đang ở danh sách Purchase Orders, **When** nhập một Purch Id hợp lệ vào ô tìm kiếm,
   **Then** danh sách chỉ hiển thị đúng Purchase Order khớp Purch Id đó.
2. **Given** đang ở danh sách Purchase Orders, **When** nhập một phần Vendor code hoặc Vendor name
   vào ô tìm kiếm, **Then** danh sách hiển thị mọi Purchase Order có Vendor code/Vendor name chứa từ
   khóa đó.
3. **Given** từ khóa tìm kiếm không khớp Purchase Order nào, **When** kết quả trả về rỗng, **Then**
   hệ thống hiển thị trạng thái trống ("No data"), không phải lỗi.

### Edge Cases

- Khi tổng số Purchase Order vượt quá một trang, người dùng MUST có thể chuyển trang.
- Khi nguồn dữ liệu tham chiếu type = 15 tạm thời không phản hồi (lỗi mạng/ERP), danh sách MUST hiển
  thị thông báo lỗi rõ ràng, không làm trắng trang hay crash.
- Khi một Purchase Order có Template nhưng mã Template đó không khớp với template nào đang cấu hình
  trong hệ thống, Purchase Order đó được xử lý như trường hợp chưa có Template hợp lệ (Progress hiển
  thị trạng thái chưa có Template, không tính toán step).
- Khi việc tải danh sách step của Template hoặc tài liệu của Purchase Order (để tính Progress) bị lỗi
  cho một dòng cụ thể, dòng đó hiển thị trạng thái lỗi riêng cho cột Progress, không chặn các dòng
  khác trong bảng hiển thị bình thường.
- Khi màn hình chi tiết (`PurchId/View`) đang tải cây thư mục/tài liệu mà việc tải bị lỗi, hệ thống
  hiển thị thông báo lỗi rõ ràng thay vì cây rỗng gây hiểu nhầm.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hệ thống MUST hiển thị màn hình danh sách "EUTR Purchase Orders" dạng bảng với đúng 6
  cột: Purch id, Vendor code, Vendor name, Template, Progress, Action.
- **FR-002**: Dữ liệu Purch id, Vendor code, Template (nếu có) của mỗi dòng MUST lấy từ nguồn dữ liệu
  tham chiếu dùng chung đã có sẵn trong hệ thống, reference type = 15 — cùng nguồn dữ liệu Purchase
  Order đã dùng ở 004-eutr-documents (danh sách PO) và 011-eutr-synchronize-data (báo cáo thiếu tài
  liệu), không dùng dữ liệu mock.
- **FR-003**: Khi nguồn dữ liệu type = 15 không có sẵn giá trị Vendor name trực tiếp, hệ thống MUST
  tra cứu bổ sung Vendor name qua nguồn dữ liệu Vendor tương ứng (theo Vendor code), theo đúng cách
  011-eutr-synchronize-data đang tra cứu Vendor name cho báo cáo của nó; nếu vẫn không tìm thấy, cột
  Vendor name hiển thị trạng thái trống rõ ràng.
- **FR-004**: Cột Template MUST hiển thị đúng giá trị template compliance đang gắn trực tiếp trên
  chính Purchase Order đó (lấy từ nguồn type = 15); nếu Purchase Order chưa có Template, cột Template
  hiển thị trạng thái trống rõ ràng.
- **FR-005**: Cột Progress MUST tính bằng cách: (a) lấy danh sách step của Template đang gắn cho
  Purchase Order đó từ 003-eutr-templates, (b) đối chiếu với tài liệu đã ghi nhận cho Purchase Order
  đó từ 004-eutr-documents để xác định step nào đã có tài liệu, step nào còn thiếu (missing), (c) chỉ
  đếm các step Required (bắt buộc), (d) hiển thị dạng `completed`/`total` và tỷ lệ %.
- **FR-006**: Nếu Purchase Order chưa có Template, cột Progress MUST hiển thị trạng thái riêng cho
  biết chưa có Template, không suy diễn thành 0%.
- **FR-007**: Nếu Template của Purchase Order không có step Required nào, cột Progress MUST hiển thị
  trạng thái riêng cho biết không có step bắt buộc, không suy diễn thành 0% "chưa hoàn thành".
- **FR-008**: Users MUST có thể chuyển trang khi tổng số Purchase Order vượt quá một trang.
- **FR-009**: Users MUST có thể tìm kiếm/lọc danh sách theo Purch Id, Vendor code, hoặc Vendor name
  (khớp kiểu "chứa", không phân biệt hoa/thường).
- **FR-010**: Khi từ khóa tìm kiếm không khớp Purchase Order nào, hệ thống MUST hiển thị trạng thái
  trống ("No data"), không phải lỗi.
- **FR-011**: Màn hình danh sách là **read-only** trong phạm vi tính năng — KHÔNG cung cấp chức năng
  thêm mới (Create), sửa (Edit) hay xóa (Delete) Purchase Order.
- **FR-012**: Mỗi dòng trong bảng MUST có nút **View**; nhấn nút này MUST điều hướng sang màn hình
  chi tiết của đúng Purchase Order đó theo địa chỉ dạng `.../purchase-orders/{PurchId}/view`.
- **FR-013**: Màn hình chi tiết (`PurchId/View`) MUST kiểm tra Purchase Order có tồn tại hay không
  bằng cách tra cứu cùng nguồn tham chiếu type = 15 theo Purch Id trên URL.
- **FR-014**: Nếu Purch Id trên URL không tồn tại ở nguồn tham chiếu type = 15, màn hình chi tiết MUST
  hiển thị thông báo lỗi rõ ràng ("Purchase Order không tồn tại") và không hiển thị phần còn lại của
  màn hình.
- **FR-015**: Phần thông tin đầu trang của màn hình chi tiết MUST hiển thị Purch id, Vendor code,
  Vendor name của Purchase Order đang xem — thay thế hoàn toàn phần Sales ID/Customer/Customer name
  của màn hình Map File gốc (005-eutr-sales-orders).
- **FR-016**: Màn hình chi tiết MUST KHÔNG có phần "Step 1 — Choose Purchase Order" (không có bước
  chọn/tick Purchase Order) — Purchase Order đang xem đã cố định theo Purch Id trên URL.
- **FR-017**: Màn hình chi tiết MUST KHÔNG có bảng "Selected POs" (bỏ hoàn toàn khái niệm chọn nhiều
  Purchase Order để tổng hợp, vốn chỉ áp dụng cho luồng Sales Order gốc).
- **FR-018**: Màn hình chi tiết MUST hiển thị cây thư mục theo các step của Template thật đang gắn
  cho Purchase Order này, tải dữ liệu step từ 003-eutr-templates — theo đúng cách Step 2 của Map File
  (005-eutr-sales-orders) xây dựng cây thư mục theo Template.
- **FR-019**: Nếu Purchase Order chưa có Template, màn hình chi tiết MUST hiển thị trạng thái rõ ràng
  cho biết chưa có Template, không hiển thị cây thư mục rỗng gây hiểu nhầm.
- **FR-020**: Khu vực **AVAILABLE FILES** của màn hình chi tiết MUST hiển thị tài liệu thật đã ghi
  nhận cho Purchase Order này lấy từ 004-eutr-documents, mỗi tài liệu hiển thị đúng step mà nó đã
  được gắn trong cây.
- **FR-021**: Nút **Upload** ở màn hình chi tiết MUST mở đúng popup Add tài liệu đã có sẵn ở
  004-eutr-documents, áp dụng đúng toàn bộ quy tắc trường dữ liệu và luồng tải file thật đã định
  nghĩa ở đặc tả đó — theo đúng cách Upload hoạt động ở Step 2 của Map File.
- **FR-022**: Nút **Edit** trên từng tài liệu ở AVAILABLE FILES MUST mở đúng popup Edit tài liệu đã có
  sẵn ở 004-eutr-documents cho đúng tài liệu đó, áp dụng đúng toàn bộ quy tắc đã định nghĩa ở đặc tả
  đó — theo đúng cách Edit hoạt động ở Step 2 của Map File.
- **FR-023**: Sau khi Upload hoặc Edit thành công, khu vực AVAILABLE FILES và trạng thái của (các)
  step liên quan trong cây template MUST được làm mới (refetch) ngay theo dữ liệu thật mới nhất,
  không yêu cầu người dùng tải lại toàn bộ trang.
- **FR-024**: Riêng tại màn hình chi tiết (`PurchId/View`), khi nhấn nút **Upload**, popup Add tài
  liệu MUST tự điền sẵn trường **Type** = `PO` và trường **Value** = chính Purch Id đang xem (không
  mở trống như mặc định gốc của popup dùng chung ở 004-eutr-documents).
- **FR-025**: Trường Type và Value đã tự điền theo FR-024 MUST vẫn cho phép người dùng chỉnh sửa/đổi
  giá trị khác trước khi lưu — không khóa (disable) hai trường này.
- **FR-026**: Việc tự điền theo FR-024/FR-025 CHỈ áp dụng cho nút Upload ở màn hình `PurchId/View`
  của 012-eutr-purchase-orders; hành vi Upload ở màn hình Map File (005-eutr-sales-orders) MUST giữ
  nguyên như hiện tại (không tự điền Type/Value).
- **FR-027**: Trong popup Add tài liệu mở từ nút Upload ở màn hình `PurchId/View`, trường Type MUST cho
  chọn (tối thiểu) các giá trị đã có sẵn trong hệ thống: **PO**, **Vendor**, **Invoice**, **Delivery
  note** (cùng danh mục type tham chiếu dùng chung với 004-eutr-documents); mỗi khi người dùng đổi giá
  trị Type sang một trong các giá trị này, hệ thống MUST tự động điền lại trường Value như sau: (a) Type
  = PO, Invoice, hoặc Delivery note → Value = Purch Id của Purchase Order đang xem; (b) Type = Vendor →
  Value = Vendor Code của Purchase Order đang xem.
- **FR-028**: Việc tự điền lại Value theo FR-027 MUST thực hiện lại mỗi lần Type thay đổi (không chỉ ở
  lần mở popup đầu tiên), và MUST ghi đè giá trị Value hiện tại (nếu có) bằng giá trị mặc định tương ứng
  Type mới; Value sau khi tự điền lại vẫn KHÔNG bị khóa (disable) — người dùng vẫn có thể chỉnh sửa/xóa/
  đổi sang giá trị khác trước khi lưu, giữ nguyên nguyên tắc không khóa trường như FR-025. Nếu người
  dùng đổi Type sang một giá trị khác ngoài PO/Vendor/Invoice/Delivery note (ví dụ General agreement),
  hệ thống KHÔNG tự điền/ghi đè Value — giữ nguyên hành vi nhập tay hiện có của popup dùng chung.
- **FR-029**: Hành vi tự điền lại Value theo Type (FR-027/FR-028) CHỈ áp dụng cho popup Add tài liệu mở
  từ nút Upload tại màn hình `PurchId/View` của 012-eutr-purchase-orders; hành vi Upload ở màn hình Map
  File (005-eutr-sales-orders) MUST giữ nguyên như hiện tại (không tự điền lại Value khi đổi Type),
  theo đúng phạm vi đã giới hạn ở FR-026.

### Key Entities *(include if feature involves data)*

- **Purchase Order (ERP reference data, type = 15)**: Một đơn mua hàng lấy từ ERP qua nguồn tham
  chiếu dùng chung. Thuộc tính chính dùng ở tính năng này: Purch id, Vendor code, Template (nếu đã
  gắn).
- **Vendor (ERP reference data)**: Nhà cung cấp tương ứng với Vendor code của một Purchase Order.
  Thuộc tính chính: Vendor code, Vendor name — dùng để bổ sung Vendor name khi không có sẵn trực tiếp
  trên dữ liệu Purchase Order.
- **Compliance Template & Step (existing — 003-eutr-templates, chỉ đọc)**: Template compliance đang
  gắn cho một Purchase Order, cùng danh sách step (bắt buộc/không bắt buộc) của template đó — dùng để
  xây cây thư mục và tính Progress.
- **Recorded Compliance Document (existing — 004-eutr-documents, chỉ đọc/ghi qua popup Add/Edit)**:
  Tài liệu đã tải lên và gắn với một Purchase Order và một step cụ thể của Template — dùng để xác
  định step nào đã có tài liệu, step nào còn thiếu, và hiển thị ở khu vực AVAILABLE FILES.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng có thể xem toàn bộ danh sách Purchase Order kèm Vendor, Template, Progress
  thật ngay khi mở màn hình, không cần mở từng đơn để kiểm tra.
- **SC-002**: 100% giá trị Progress hiển thị trên danh sách khớp đúng với số step Required đã có tài
  liệu thật của Purchase Order đó tại cùng một thời điểm dữ liệu.
- **SC-003**: Người dùng có thể mở màn hình chi tiết của một Purchase Order bất kỳ trong tối đa 2 lượt
  nhấn (Search hoặc chuyển trang, rồi View).
- **SC-004**: Người dùng có thể bổ sung một tài liệu còn thiếu cho một step và thấy trạng thái step đó
  cập nhật ngay trên cùng màn hình, không cần tải lại trang.
- **SC-005**: 0% màn hình danh sách hoặc màn hình chi tiết hiển thị dữ liệu Template/Progress/tài
  liệu giả (demo/mock) sau khi tính năng hoàn thành.

## Assumptions

- Nguồn dữ liệu Purchase Order (reference type = 15, entity `RSVNEutrPurchOrders`) đã có sẵn trong hệ
  thống (đã dùng ở 004-eutr-documents và 011-eutr-synchronize-data) và trả về đủ Purch id, Vendor
  code, và giá trị Template gắn trực tiếp trên Purchase Order — tính năng này chỉ tiêu thụ lại nguồn
  dữ liệu đó, không cần đăng ký thêm reference type mới.
- Vendor name không có sẵn trực tiếp trên nguồn dữ liệu Purchase Order nên được tra cứu bổ sung qua
  nguồn dữ liệu Vendor theo Vendor code, theo đúng cách 011-eutr-synchronize-data đã làm cho báo cáo
  của nó.
- Khác với 005-eutr-sales-orders (nơi Template của một Sales Order phải tra qua bảng liên kết
  `eutr_purchase_attachments` vì một Sales Order có thể gắn nhiều Purchase Order/Template), mỗi
  Purchase Order ở tính năng này chỉ có đúng một Template gắn trực tiếp trên chính nó — không cần cơ
  chế chọn/lưu nhiều template như Step 1 của Map File.
- Công thức tính Progress (completed/total step Required, loại trừ các step tự động lấy từ nguồn
  D365) tái sử dụng đúng công thức đã dùng ở màn hình Map File của 005-eutr-sales-orders.
- Mặc định, danh sách hiển thị mọi Purchase Order trả về từ nguồn tham chiếu type = 15, kể cả những
  Purchase Order chưa có Template (hiển thị trạng thái trống ở cột Template/Progress) — không lọc bớt
  theo điều kiện đã có Template.
- Màn hình chi tiết (`PurchId/View`) giữ nguyên đầy đủ khả năng tương tác Upload/Edit tài liệu như
  Step 2 của Map File (không phải chế độ chỉ xem thuần túy như màn hình View riêng của
  005-eutr-sales-orders); tên gọi "View" chỉ phản ánh cách gọi hành động ở cột Action của danh sách.
- Tính năng này KHÔNG bao gồm chức năng tải xuống (Download) file zip tài liệu — nếu cần, sẽ là một
  cập nhật riêng sau này.
- Phân quyền truy cập màn hình này tuân theo đúng cơ chế phân quyền chung đã áp dụng cho các màn hình
  EUTR khác trong hệ thống, không yêu cầu quyền mới.
- "Tự điền mặc định" (FR-024) được hiểu là chỉ đặt giá trị khởi tạo ban đầu cho Type/Value khi popup
  Add mở ra từ nút Upload của `PurchId/View`, không phải khóa cứng giá trị — người dùng vẫn có toàn
  quyền đổi sang Type/Value khác trước khi lưu, giữ đúng nguyên tắc "popup đầy đủ, không giới hạn"
  mà 005-eutr-sales-orders (Decision 26) đã chọn cho chính popup dùng chung này.
- "Dòng active" nhắc tới ở yêu cầu tự điền lại Value theo Type (FR-027/028) là chính Purchase Order
  đang được xem tại màn hình `PurchId/View` (đã cố định theo `PurchId` trên URL) — màn hình này không
  có bảng nhiều dòng/nhiều Purchase Order để chọn "active" khác (khác với màn hình danh sách Overview,
  nơi mỗi dòng có nút View riêng để điều hướng sang đúng `PurchId/View` tương ứng). Vì vậy "PO của dòng
  active" và "Vendor Code của dòng active" đều quy về cùng một Purchase Order đang mở trên trang, nhất
  quán với cách FR-024 đã dùng cụm "Purch Id đang xem".
- Type = PO, Vendor, Invoice, Delivery note là các giá trị type tham chiếu đã tồn tại sẵn trong hệ
  thống (dùng chung với 004-eutr-documents); tính năng này không yêu cầu tạo mới type nào, chỉ bổ sung
  hành vi tự điền Value theo các type đã có.
