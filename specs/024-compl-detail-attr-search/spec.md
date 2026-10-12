# Feature Specification: Compl Detail Attribute Search

**Feature Branch**: `024-compl-detail-attr-search`

**Created**: 2026-10-12

**Status**: Draft

**Input**: User description: "Cải thiện compl-detail ở link compliance-detail?page=1&page-size=50. Phần tìm kiếm theo reference type là Product attribute và attribute group, chỉnh lại logic giống với tìm kiếm ở tab compliances of attribute trong 023-compl-sync-attributes"

## Clarifications

### Session 2026-10-12 (Update 1) — Rút gọn nhãn Reference Object + thêm cột Attribute

- **Yêu cầu**: (1) Khi Reference Type = Product attribute, danh sách ở ô Reference Object và giá trị đã chọn chỉ hiển thị "Name1: Name2" (ví dụ "Marble: Yellow Travertine Marble"), bỏ phần mã đứng trước ("5637567577 - "). (2) Lưới thêm cột **Attribute** ngay sau cột **Name**, lấy từ điều kiện (condition) của master có loại tham chiếu là Product attribute và Attribute group, hiển thị dạng danh sách cách nhau bởi dấu phẩy (ví dụ "Leather, Upholstery name, …").
- **Quyết định mặc định**: (a) mã thuộc tính vẫn dùng nội bộ để lọc, chỉ ẩn khỏi nhãn; (b) nhãn rút gọn chỉ áp cho Product attribute, các Reference Type khác giữ nguyên; (c) giá trị trong cột Attribute lấy theo tên hiển thị (cùng dạng nhãn rút gọn), khử trùng, giữ thứ tự khai báo của điều kiện; (d) dòng không có điều kiện attribute/group thì để trống; (e) "ulphosery name" trong yêu cầu được hiểu là "Upholstery name".

## User Scenarios & Testing *(mandatory)*

### User Story 4 - Nhãn Reference Object gọn cho Product attribute (Priority: P2) (Update 1)

Khi chọn Reference Type = Product attribute, người dùng thấy các lựa chọn ở Reference Object dạng "Marble: Yellow Travertine Marble" thay vì "5637567577 - Marble: Yellow Travertine Marble".

**Why this priority**: Mã số không có ý nghĩa với người dùng, làm nhãn dài và khó đọc.

**Independent Test**: Chọn Product attribute, mở danh sách Reference Object, kiểm tra không còn mã số đứng đầu; chọn một mục và Search vẫn ra đúng kết quả.

**Acceptance Scenarios**:

1. **Given** Reference Type = Product attribute, **When** mở Reference Object, **Then** mỗi lựa chọn chỉ có dạng "Name1: Name2", không có "<mã> - ".
2. **Given** đã chọn một mục, **When** bấm Search, **Then** kết quả giống như khi nhãn có mã (lọc theo đúng thuộc tính).
3. **Given** Reference Type khác, **When** mở Reference Object, **Then** nhãn giữ nguyên như hiện tại.

---

### User Story 5 - Cột Attribute trên lưới (Priority: P1) (Update 1)

Người dùng thấy cột "Attribute" ngay sau cột "Name" trong lưới Compliance detail, liệt kê các thuộc tính / nhóm thuộc tính mà master của compliance dùng làm điều kiện, ví dụ "Leather, Upholstery name".

**Why this priority**: Cho biết ngay compliance áp dụng cho thuộc tính nào mà không cần mở master.

**Independent Test**: Mở một compliance có master khai báo điều kiện thuộc tính, đối chiếu giá trị cột Attribute với điều kiện của master.

**Acceptance Scenarios**:

1. **Given** master có điều kiện Product attribute "Leather" và "Upholstery name", **When** xem lưới, **Then** cột Attribute của dòng hiển thị "Leather, Upholstery name".
2. **Given** master có điều kiện Attribute group, **When** xem lưới, **Then** tên Group xuất hiện trong cột Attribute.
3. **Given** master không có điều kiện attribute/group (chỉ Customer, Product…), **When** xem lưới, **Then** cột Attribute trống.
4. **Given** cùng thuộc tính khai báo nhiều lần, **When** xem lưới, **Then** chỉ hiện một lần.

---

### User Story 1 - Tìm theo Reference Type = Product attribute (Priority: P1)

Người dùng ở màn hình Compliance detail chọn Reference Type = "Product attribute", chọn một thuộc tính (ví dụ "Leather") ở ô Reference Object rồi bấm Search. Danh sách phải hiển thị đúng tập compliance mà tab "Compliances of attribute - Leather" ở trang chi tiết Product attribute (feature 023) hiển thị cho cùng thuộc tính đó — gồm cả compliance gắn trực tiếp vào thuộc tính, compliance theo nhóm "Group: …" và compliance khớp theo từng tổ hợp thuộc tính của sản phẩm (ItemId + Type/Name/Option).

**Why this priority**: Hiện tìm kiếm chỉ khớp compliance gắn thẳng vào mã thuộc tính nên thiếu các compliance gián tiếp mà người dùng đã thấy ở màn hình Product attribute; kết quả hai màn hình lệch nhau.

**Independent Test**: Chọn cùng một thuộc tính ở hai màn hình (Compliance detail và trang chi tiết Product attribute), so sánh danh sách compliance — phải trùng nhau.

**Acceptance Scenarios**:

1. **Given** thuộc tính "Leather" có compliance gắn trực tiếp, compliance theo Group và compliance theo tổ hợp, **When** chọn Reference Type = Product attribute, Reference Object = Leather và bấm Search, **Then** danh sách chứa đủ cả ba nguồn, không dòng trùng.
2. **Given** kết quả ở bước trên, **When** so với tab "Compliances of attribute - Leather" của feature 023, **Then** tập compliance giống nhau 100%.
3. **Given** Reference Object để trống, **When** bấm Search với Reference Type = Product attribute, **Then** hành vi giữ như hiện tại (lọc theo loại tham chiếu, không áp logic tổ hợp).
4. **Given** thuộc tính không có tổ hợp hoặc Group nào, **When** tìm kiếm, **Then** vẫn hiển thị compliance gắn trực tiếp (nếu có), nếu không có thì danh sách rỗng.

---

### User Story 2 - Tìm theo Reference Type = Attribute group (Priority: P1)

Người dùng chọn Reference Type = "Attribute group", chọn một Group ở Reference Object rồi Search. Danh sách phải hiển thị đúng tập compliance mà tab "Compliances of attribute group" ở trang chi tiết Attribute group (feature 023, Update 4–5) hiển thị: compliance gắn vào chính Group, compliance của mọi thuộc tính thành viên của Group, và compliance khớp theo tổ hợp thuộc tính thuộc các thành viên đó.

**Why this priority**: Cùng lý do như Product attribute; Attribute group hiện chỉ khớp compliance gắn thẳng vào Group.

**Independent Test**: Chọn cùng một Group ở Compliance detail và ở trang chi tiết Attribute group, so sánh danh sách.

**Acceptance Scenarios**:

1. **Given** một Group có nhiều thuộc tính thành viên, **When** Reference Type = Attribute group, Reference Object = Group đó, Search, **Then** danh sách là hợp không trùng compliance của Group, của từng thành viên và của các tổ hợp liên quan.
2. **Given** kết quả trên, **When** so với tab detail của Group ở feature 023, **Then** trùng 100%.
3. **Given** hệ thống nguồn D365 không truy cập được, **When** tìm kiếm theo Group, **Then** người dùng thấy thông báo lỗi rõ ràng thay vì danh sách thiếu im lặng.

---

### User Story 3 - Các bộ lọc khác và loại tham chiếu khác không đổi (Priority: P2)

Các bộ lọc còn lại (Search text, Expiry days, Compliance type, My compliance, phân trang, sắp xếp, Clear) và tìm kiếm theo các Reference Type khác tiếp tục hoạt động như hiện tại, và kết hợp đúng với tìm kiếm Product attribute / Attribute group.

**Why this priority**: Tránh hồi quy; không phải giá trị chính.

**Independent Test**: Tìm theo Reference Type khác (ví dụ Customer) và so kết quả trước/sau thay đổi; kết hợp Product attribute + Search text + Expiry days.

**Acceptance Scenarios**:

1. **Given** Reference Type khác Product attribute/Attribute group, **When** Search, **Then** kết quả giống trước thay đổi.
2. **Given** Product attribute = Leather và Expiry days = 30, **When** Search, **Then** chỉ hiện compliance (trong tập của US1) còn hiệu lực trong 30 ngày.
3. **Given** Product attribute = Leather và Search text, **When** Search, **Then** kết quả được thu hẹp theo text, đếm tổng và phân trang đúng.

---

### Edge Cases

- Thuộc tính/Group không có dữ liệu tổ hợp trong bảng đồng bộ hoặc bảng rỗng: vẫn trả compliance gắn trực tiếp; dữ liệu tổ hợp tự đồng bộ theo cơ chế 023 (Update 6).
- Một compliance khớp qua nhiều nguồn: chỉ hiển thị một lần; tổng số và phân trang phản ánh số duy nhất.
- Thuộc tính có hàng nghìn tổ hợp: kết quả vẫn phân trang (page-size 50) và phản hồi trong ngưỡng SC-003.
- Group rỗng hoặc không có thành viên: chỉ hiện compliance gắn trực tiếp vào Group.
- Đổi Reference Type: Reference Object cũ được xóa như hiện tại.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Khi Reference Type = Product attribute và có Reference Object, tìm kiếm ở màn hình Compliance detail MUST trả hợp (không trùng) compliance theo đúng quy tắc của tab "Compliances of attribute - <Name>" (feature 023, FR-024/FR-025): compliance gắn trực tiếp, nhóm "Group: …" và các tổ hợp thuộc tính.
- **FR-002**: Khi Reference Type = Attribute group và có Reference Object, tìm kiếm MUST trả hợp (không trùng) compliance theo quy tắc của tab Attribute group (feature 023, FR-026/FR-027/FR-030): compliance gắn vào Group, của các thuộc tính thành viên và của tổ hợp liên quan.
- **FR-003**: Tập kết quả FR-001/FR-002 MUST trùng 100% với tab tương ứng ở feature 023 cho cùng đối tượng được chọn.
- **FR-004**: Tổng số dòng, phân trang, sắp xếp và các cột của lưới MUST phản ánh đúng tập kết quả đã khử trùng.
- **FR-005**: Các bộ lọc Search text, Expiry days, Compliance type/My compliance MUST tiếp tục kết hợp (AND) với tìm kiếm Product attribute / Attribute group.
- **FR-006**: Khi Reference Object trống, hoặc Reference Type là loại khác, hành vi tìm kiếm MUST không đổi so với hiện tại.
- **FR-007**: Lỗi khi lấy dữ liệu Group/thành viên từ D365 MUST hiển thị thông báo rõ ràng; lỗi phần tổ hợp không được làm mất compliance gắn trực tiếp.
- **FR-008**: Không thay đổi ý nghĩa của giao diện lọc (ô Reference Type, Reference Object, Search, Expiry days, nút Search/Clear).

- **FR-009** (Update 1): Với Reference Type = Product attribute, nhãn lựa chọn và giá trị đã chọn ở Reference Object MUST có dạng "Name1: Name2", không kèm mã thuộc tính; việc lọc vẫn dùng đúng thuộc tính đã chọn. Các Reference Type khác MUST giữ nhãn hiện tại.
- **FR-010** (Update 1): Lưới Compliance detail MUST có thêm cột "Attribute" đặt ngay sau cột "Name", mọi Reference Type đều hiển thị.
- **FR-011** (Update 1): Giá trị cột Attribute MUST là danh sách tên (khử trùng, cách nhau bởi dấu phẩy) của các điều kiện master có loại tham chiếu Product attribute hoặc Attribute group; không có điều kiện như vậy thì để trống.
- **FR-012** (Update 1): Cột Attribute MUST hiển thị đúng sau khi sắp xếp, phân trang, lọc, và không làm thay đổi tổng số dòng.

### Key Entities

- **Compliance**: bản ghi compliance hiển thị ở lưới Compliance detail, gắn với master và đối tượng tham chiếu.
- **Thuộc tính sản phẩm (Product attribute)**: giá trị thuộc tính được chọn ở Reference Object, có mã (RecId) và tên.
- **Nhóm thuộc tính (Attribute group)**: Group gồm nhiều thuộc tính thành viên.
- **Tổ hợp thuộc tính (Attribute combine)**: dữ liệu đồng bộ gắn ItemId với bộ Type/Name/Option, dùng để tìm compliance gián tiếp (feature 023).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Với bộ mẫu kiểm thử, 100% thuộc tính được chọn cho kết quả ở Compliance detail trùng hoàn toàn (0 chênh lệch) với tab "Compliances of attribute" tương ứng.
- **SC-002**: Với bộ mẫu kiểm thử, 100% Group được chọn cho kết quả trùng hoàn toàn với tab Attribute group tương ứng.
- **SC-003**: Kết quả tìm kiếm trang đầu hiển thị trong ≤ 5 giây với thuộc tính/Group có tới 1.000 tổ hợp.
- **SC-004**: 0 dòng compliance trùng trong kết quả; tổng số dòng hiển thị khớp số bản ghi thực tế.
- **SC-005**: Tìm kiếm theo các Reference Type khác cho kết quả không đổi so với trước thay đổi (0 hồi quy).

- **SC-006** (Update 1): 100% lựa chọn Product attribute ở Reference Object không còn mã số đứng đầu nhãn.
- **SC-007** (Update 1): Với bộ mẫu kiểm thử, 100% dòng có giá trị cột Attribute trùng với điều kiện attribute/group của master; 0 giá trị trùng lặp trong một ô.

## Assumptions

- (Update 1) Tên thuộc tính/Group trong cột Attribute lấy từ cùng nguồn tên đang dùng cho Reference Object; nếu không có tên thì dùng mã làm dự phòng.
- (Update 1) Cột Attribute chỉ để xem, không thêm ô lọc riêng.

- Ô Reference Object đã cho phép chọn thuộc tính / Group khi Reference Type là Product attribute / Attribute group (nếu chưa, bổ sung nguồn dữ liệu chọn tương ứng là một phần của phạm vi).
- Quy tắc khớp là quy tắc đã được xác lập ở feature 023 (Update 3–5); feature này tái sử dụng, không thay đổi quy tắc đó.
- Dữ liệu tổ hợp lấy từ bảng đồng bộ của feature 023 và tự làm mới theo cơ chế sẵn có.
- Cùng quyền truy cập và các thao tác trên lưới (xem file, tải xuống, cảnh báo) như hiện tại.
- Đây là tính năng mới trên màn hình Compliance detail (không thuộc spec 023), nên tạo thư mục spec riêng; 023 chỉ là nguồn tham chiếu logic.
