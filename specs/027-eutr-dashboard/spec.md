# Feature Specification: EUTR Dashboard

**Feature Branch**: `027-eutr-dashboard`

**Created**: 2026-10-15

**Status**: Draft

**Input**: User description: "chức năng eutr-dashboard. Hiện tại có link và giao diện ở /dashboard dùng thống kê tài liệu compliance, add thêm thống kê EUTR vào, gợi ý các thông tin cần thống kê hiển thị trên dashboard theo 003, 004, 005, 012"

## Bối cảnh

Màn hình `/dashboard` (breadcrumb "Home / EUDR system / Documents") hiện chỉ thống kê **tài liệu compliance**: 3 thẻ KPI (Total Compliances, Expiring Soon trong 30 ngày, Expired), khối "Compliance by reference" (tỷ lệ compliant theo từng reference type) và biểu đồ tròn "Distribution by reference". Tính năng này **bổ sung phần thống kê EUTR** vào cùng màn hình, lấy dữ liệu từ 3 module EUTR: Documents (004), Sales Orders (005), Purchase Orders (012). Phần thống kê compliance hiện có giữ nguyên.

## Clarifications

### Session 2026-10-15

- Q: Dashboard EUTR đặt ở đâu? → A: Cùng màn hình `/dashboard`, thêm một khu vực "EUTR" tách biệt rõ với khu vực Compliance hiện có; không tạo route mới.
- Q: Phạm vi dữ liệu PO và Sales Order để tổng hợp? → A: Chỉ tính đơn đang mở (Sales Order có Sales status "Open order"; PO thuộc các Sales Order đó hoặc chưa đóng), không tính đơn lịch sử đã đóng.
- Q: Bố cục khu vực EUTR? → A: Một trang cuộn dọc: khu vực Compliance hiện có ở trên, khu vực EUTR bên dưới (không dùng tab).
- Q: Quyền xem khu vực EUTR? → A: Ẩn từng khối theo quyền đọc của menu tương ứng; nếu user không có quyền nào thì ẩn cả khu vực EUTR (chỉ còn Compliance); không tạo quyền riêng.
- Q: Ngày dùng cho "sắp đến hạn giao"? → A: ETD, trong ngưỡng ngày (mặc định 30) tính từ hôm nay.
- Q: Phạm vi đếm Expired/Expiring soon của tài liệu? → A: Chỉ tính tài liệu có Valid to (thực tế Type Vendor); tài liệu không có Valid to bị bỏ qua.
- Q: Danh sách chỉ số? → A: Nhóm A–D ở mục Requirements theo 004/005/012 (nhóm Template 003 đã bỏ).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nhìn nhanh tình trạng tuân thủ của Purchase Order (Priority: P1)

Cán bộ compliance mở `/dashboard` và thấy ngay khu vực EUTR với các thẻ KPI về Purchase Order: tổng số PO, số PO đã hoàn tất 100% step bắt buộc, số PO đang dở dang, số PO chưa gắn Template — để biết PO nào cần xử lý trước.

**Why this priority**: PO + Progress là kết quả cuối cùng của chuỗi Template → Document → PO; đây là chỉ số người dùng quan tâm nhất.

**Independent Test**: Mở `/dashboard`, đối chiếu các số KPI PO với danh sách ở màn hình Purchase Orders (012) — phải khớp.

**Acceptance Scenarios**:

1. **Given** hệ thống có PO ở nhiều trạng thái Progress, **When** mở `/dashboard`, **Then** thấy các thẻ Total PO, Completed, In progress, No template, và tổng các nhóm bằng Total.
2. **Given** PO không có Template, **When** xem dashboard, **Then** PO đó chỉ được đếm vào "No template", không bị tính là 0%.
3. **Given** dữ liệu rỗng, **When** mở dashboard, **Then** các thẻ hiện 0 và biểu đồ hiện trạng thái rỗng, không lỗi.

---

### User Story 2 - Theo dõi tài liệu EUTR còn thiếu theo Sales Order (Priority: P1)

Người dùng xem thống kê Sales Order: tổng số Sales Order đang mở, phân bố Progress (step Mapped vs Missing) và danh sách Sales Order có tỷ lệ hoàn thành thấp nhất để ưu tiên bổ sung tài liệu.

**Why this priority**: Sales Order là đơn vị giao hàng cho khách; thiếu tài liệu EUTR ảnh hưởng trực tiếp xuất hàng.

**Independent Test**: So sánh số Sales Order và Progress trên dashboard với màn hình Sales Orders (005).

**Acceptance Scenarios**:

1. **Given** có Sales Order ở nhiều Sales status (Open order, Invoiced…), **When** xem dashboard, **Then** chỉ các Sales Order "Open order" được tính vào số liệu; đơn đã Invoiced/Delivered không xuất hiện.
2. **Given** có Sales Order còn thiếu step bắt buộc, **When** xem khối "Sales Orders cần bổ sung", **Then** thấy tối đa 10 Sales Order có % hoàn thành thấp nhất; nhấn Sales ID mở màn hình View của Sales Order đó.

---

### User Story 3 - Theo dõi kho tài liệu EUTR (Priority: P2)

Người dùng xem thống kê Document: tổng số, phân bố theo Type (PO, Vendor, Invoice, General…), số tài liệu sắp hết hạn và đã hết hạn (với Type có Valid to, chủ yếu Vendor), và số tài liệu mới upload gần đây.

**Why this priority**: Giúp phát hiện tài liệu Vendor sắp hết hiệu lực trước khi ảnh hưởng PO/Sales Order, nhưng không chặn luồng chính.

**Independent Test**: Số Expiring/Expired khớp với danh sách Documents (004) lọc theo Valid to.

**Acceptance Scenarios**:

1. **Given** có tài liệu Vendor có Valid to trong 30 ngày tới, **When** xem dashboard, **Then** thẻ "EUTR docs expiring soon" đếm đúng và nhấn vào mở danh sách Documents.
2. **Given** tài liệu thuộc Type không có hạn (PO, General), **When** thống kê hạn, **Then** các tài liệu đó không bị tính là Expired.

---

### User Story 4 - Điều chỉnh ngưỡng thống kê (Priority: P3)

Người dùng đổi ngưỡng số ngày "sắp hết hạn/sắp đến hạn giao" để dashboard EUTR tính lại.

**Why this priority**: Tiện ích bổ sung; dashboard vẫn dùng được với mặc định 30 ngày.

**Independent Test**: Đổi ngưỡng, số "Expiring soon" thay đổi tương ứng.

**Acceptance Scenarios**:

1. **Given** ngưỡng mặc định 30 ngày, **When** đổi sang 60 ngày, **Then** các thẻ phụ thuộc ngưỡng tính lại theo 60 ngày.

---

### Edge Cases

- Nguồn dữ liệu ERP (PO/Sales Order) không phản hồi: khối liên quan hiện thông báo lỗi riêng kèm nút tải lại; các khối khác và khu vực Compliance vẫn hiển thị bình thường.
- User không có quyền xem một module (ví dụ menu Purchase Orders): khối của module đó bị ẩn, không lộ số liệu.
- Khối lượng PO/Sales Order lớn: số liệu hiển thị kèm thời điểm cập nhật; dashboard không treo giao diện.
- PO chưa có Template hoặc Template không có step Required: tách thành nhóm riêng, không tính vào tỷ lệ hoàn thành (theo 012 FR-006/FR-007).
- Biểu đồ có nhiều phần nhỏ (như biểu đồ tròn hiện tại có nhãn 0%/2%/3% đè nhau): gom các phần quá nhỏ thành "Other" hoặc dùng chú giải để dễ đọc.

## Requirements *(mandatory)*

### Functional Requirements

**Chung**

- **FR-001**: Màn hình `/dashboard` MUST giữ nguyên toàn bộ thống kê compliance hiện có ở phần trên và MUST thêm khu vực **EUTR** bên dưới trên cùng một trang cuộn dọc (không dùng tab), có tiêu đề riêng để phân biệt rõ với khu vực Compliance.
- **FR-002**: Khu vực EUTR MUST chỉ hiển thị các khối thuộc module mà user có quyền đọc (theo permission của menu tương ứng); khối không có quyền MUST bị ẩn. Nếu user không có quyền đọc ở cả ba menu (Documents, Sales Orders, Purchase Orders) thì MUST ẩn toàn bộ khu vực EUTR kể cả tiêu đề, không hiện khu vực trống; MUST NOT tạo quyền riêng cho dashboard EUTR.
- **FR-003**: Mỗi khối MUST tải độc lập: lỗi hoặc chậm ở một khối không làm ẩn/chặn các khối khác, và có trạng thái loading/empty/error riêng.
- **FR-004**: Mỗi thẻ KPI/phần biểu đồ MUST cho phép nhấn để đến màn hình danh sách tương ứng (Documents/Sales Orders/Purchase Orders); áp dụng bộ lọc tương ứng khi màn hình đó hỗ trợ, nếu không thì mở danh sách không lọc.

- **FR-005**: (Đã đổi theo yêu cầu: thống kê Sales Order tính TOÀN BỘ Sales Order như Purchase Order, không còn giới hạn đơn đang mở; tổng lấy từ danh sách Sales Orders của 005.)

**Nhóm A — Purchase Order (012)**

- **FR-010**: MUST hiển thị tổng số Purchase Order = toàn bộ PO của danh sách Purchase Orders (012, không lọc), khớp số tổng ở màn hình đó. (Update: PO không còn giới hạn theo đơn đang mở.)
- **FR-011**: Phân loại PO và Sales Order theo bảng tiến độ `eutr_progression` (Type = 0: Sales Order, Type = 1: Purchase Order): **Completed** khi Finished = Total (Total > 0); **In progress** khi Finished < Total (còn thiếu step Required); **No template** khi không có bản ghi trong bảng này (hoặc Total = 0). Completed + In progress + No template MUST bằng tổng. Không có nhóm "No required step". Biểu đồ vòng thể hiện % của 3 nhóm trên tổng.
- **FR-012**: MUST hiển thị tỷ lệ % PO Completed trên tổng PO.
- **FR-013**: (Đã bỏ theo yêu cầu: không hiển thị danh sách top 10 PO thấp nhất.)
- **FR-014**: MUST hiển thị số PO đã cấu hình Trader relationship và số PO có từ 2 Vendor trở lên nhưng chưa cấu hình Trader relationship (cảnh báo cần xử lý), dựa trên dữ liệu của 012 Update 54–57.

**Nhóm B — Sales Order (005)**

- **FR-020**: MUST hiển thị tổng số Sales Order = toàn bộ Sales Order của danh sách Sales Orders (005, không lọc), khớp số tổng ở màn hình đó.
- **FR-021**: MUST phân loại Sales Order Completed / In progress / No template theo FR-011 (eutr_progression Type = 0).
- **FR-022**: MUST hiển thị tổng số step bắt buộc **Mapped** so với **Missing** trên toàn bộ Sales Order (theo Map status của 005) và tỷ lệ % Mapped.
- **FR-023**: (Đã bỏ theo yêu cầu: không hiển thị danh sách top 10 Sales Order thấp nhất.)
- **FR-024**: MUST hiển thị số Sales Order đang mở có **ETD** nằm trong khoảng từ hôm nay đến hôm nay + ngưỡng ngày (mặc định 30, đổi được theo FR-051) mà chưa Completed; Sales Order không có ETD MUST NOT được tính vào chỉ số này.

**Nhóm C — Documents (004)**

- **FR-030**: MUST hiển thị tổng số tài liệu EUTR và số tài liệu được tải lên trong 7 ngày và 30 ngày gần nhất.
- **FR-031**: MUST hiển thị phân bố tài liệu theo Type (PO, Vendor, Invoice, General…) dưới dạng biểu đồ.
- **FR-032**: MUST hiển thị số tài liệu **Expiring soon** (Valid to trong ngưỡng ngày, mặc định 30) và **Expired** (Valid to < hôm nay), chỉ tính tài liệu có Valid to (thực tế Type Vendor); tài liệu không có Valid to MUST bị bỏ qua, không đếm vào cả hai chỉ số.
- **FR-033**: (Đã bỏ theo yêu cầu: không hiển thị danh sách tài liệu sắp hết hạn.)

**Nhóm D — Thời điểm & ngưỡng**

- **FR-050**: (Đã bỏ theo yêu cầu: không có nút Refresh ở khu vực EUTR; mỗi khối vẫn có nút Retry khi lỗi.)
- **FR-051**: Ngưỡng "sắp hết hạn" MUST cố định 30 ngày (giống phần compliance hiện có); không có ô chọn ngưỡng ("Expiring within") trên giao diện.
- **FR-052**: Mọi con số trên dashboard MUST khớp với màn hình danh sách tương ứng tại cùng thời điểm; MUST NOT dùng định nghĩa Progress/Mapped riêng khác với 005/012. Với nhóm A và B, "tương ứng" nghĩa là danh sách đã lọc đơn đang mở (FR-005).

### Key Entities *(include if feature involves data)*

- **EUTR Summary Metric**: Một chỉ số tổng hợp (tên, giá trị, module nguồn, thời điểm tính). Không lưu mới; suy ra từ dữ liệu của 003/004/005/012.
- **Document (004)**: Type, Step, Valid from/Valid to, ngày tạo.
- **Sales Order (005)**: Sales status, ETD/Delivery Date, Template, Progress (step Mapped/Missing).
- **Purchase Order (012)**: Vendor, Template, Progress, Trader relationship.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng nắm được số PO/Sales Order chưa hoàn tất tài liệu EUTR trong ≤ 10 giây sau khi mở `/dashboard`, không cần mở từng màn hình danh sách.
- **SC-002**: 100% số liệu KPI trên dashboard EUTR khớp với màn hình danh sách tương ứng (004/005/012) tại cùng thời điểm khi đối chiếu mẫu.
- **SC-003**: Số liệu chính của khu vực EUTR hiển thị xong trong ≤ 5 giây với quy mô dữ liệu vận hành hiện tại.
- **SC-004**: Từ một con số bất thường (Expired, Missing…), người dùng đến đúng danh sách liên quan trong ≤ 2 lần nhấn.
- **SC-005**: Khi một nguồn dữ liệu lỗi, các khối còn lại vẫn hiển thị bình thường trong 100% trường hợp thử nghiệm.
- **SC-006**: Thống kê compliance hiện có giữ nguyên kết quả và không chậm đi đáng kể so với trước khi bổ sung.

## Assumptions

- Dashboard EUTR dùng chung route `/dashboard` và cơ chế quyền menu hiện có; không tạo menu mới.
- Định nghĩa Progress/Mapped/Missing tái sử dụng từ 005 và 012, không tạo công thức mới.
- Dữ liệu PO/Sales Order lấy từ ERP có thể chậm; chấp nhận số liệu có độ trễ nhỏ kèm thời điểm cập nhật.
- Chỉ đọc: dashboard không chỉnh sửa dữ liệu.
- Giao diện tiếng Anh, theo kiểu thẻ KPI + biểu đồ tròn/cột như phần compliance hiện có.
- Không bao gồm thống kê Template (003) trong phạm vi này.
- Không bao gồm xuất báo cáo (Excel/PDF) và gửi cảnh báo email trong phạm vi này.

## Cập nhật hiển thị (2026-10-15)

- Biểu đồ vòng của mỗi khối (PO, Sales Order, Documents): giữa vòng hiển thị **tổng**, chú giải hiển thị số lượng và **% từng nhóm trên tổng**; không gom nhóm nhỏ thành "Other". Với PO/Sales Order các nhóm là Completed, In progress, No template.
- Bỏ: danh sách top 10 (PO, Sales Order), danh sách tài liệu sắp hết hạn, ô "Expiring within", nút Refresh. Khu vực EUTR hiển thị đủ 3 khối theo quyền menu.
