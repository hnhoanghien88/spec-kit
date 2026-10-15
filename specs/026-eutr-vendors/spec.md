# Feature Specification: EUTR Vendors Management

**Feature Branch**: `026-eutr-vendors`

**Created**: 2026-10-14

**Status**: Draft

**Input**: User description: "chức năng mới eutr-vendors. menu đã thêm trong data. làm chức năng cơ bản CRUD. lưu vào bảng eutr_vendors gồm các cột Id, Code, Name, CreatedBy, CreatedDate"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem và tìm kiếm danh sách vendor (Priority: P1)

Người dùng vào mục **EUTR > Vendors** từ thanh điều hướng trái và thấy bảng liệt kê các vendor (nhà cung cấp) dùng trong hệ thống EUTR. Bảng hiển thị mã vendor (Code), tên vendor (Name), người tạo và ngày tạo. Người dùng có thể nhập từ khóa vào ô tìm kiếm để lọc theo Code hoặc Name, và chuyển trang khi danh sách dài.

**Why this priority**: Đây là giá trị cốt lõi của màn hình — chỉ với khả năng xem và tìm kiếm, người dùng đã có thể tra cứu các vendor hiện có.

**Independent Test**: Mở màn hình, xác nhận bảng hiển thị đúng dữ liệu hiện có, nhập từ khóa và thấy danh sách thu hẹp theo Code/Name, chuyển trang và thấy các bản ghi tiếp theo.

**Acceptance Scenarios**:

1. **Given** hệ thống có nhiều vendor, **When** người dùng mở màn hình Vendors, **Then** bảng hiển thị các vendor với cột Code, Name, Created By, Created Date, có phân trang.
2. **Given** danh sách đang hiển thị, **When** người dùng nhập một phần Code hoặc Name vào ô Search, **Then** chỉ các vendor khớp từ khóa được hiển thị.
3. **Given** chưa có vendor nào hoặc từ khóa không khớp, **When** danh sách được tải, **Then** hiển thị trạng thái rỗng thân thiện thay vì lỗi.

---

### User Story 2 - Tạo vendor mới (Priority: P1)

Người dùng bấm **Add**, nhập Code và Name của vendor rồi lưu. Vendor mới xuất hiện trong danh sách, hệ thống tự ghi nhận người tạo và ngày tạo.

**Why this priority**: Không có tạo mới thì danh sách vendor không thể được xây dựng.

**Independent Test**: Bấm Add, nhập Code và Name hợp lệ, lưu, xác nhận vendor mới có trong danh sách với người tạo và ngày tạo đúng.

**Acceptance Scenarios**:

1. **Given** dialog Add đang mở, **When** người dùng nhập Code và Name hợp lệ và lưu, **Then** vendor được tạo, dialog đóng, danh sách làm mới và hiển thị vendor mới.
2. **Given** dialog Add đang mở, **When** người dùng để trống Code hoặc Name, **Then** hệ thống báo lỗi bắt buộc và không lưu.
3. **Given** đã tồn tại vendor có Code "V001", **When** người dùng tạo vendor khác với Code "V001", **Then** hệ thống báo Code đã tồn tại và không lưu.

---

### User Story 3 - Sửa vendor (Priority: P2)

Người dùng bấm biểu tượng sửa trên một dòng, thay đổi Code và/hoặc Name rồi lưu. Thông tin người tạo và ngày tạo giữ nguyên.

**Why this priority**: Cho phép chỉnh sửa sai sót dữ liệu, nhưng danh sách vẫn dùng được nếu chưa có.

**Independent Test**: Sửa Name một vendor, lưu, xác nhận giá trị mới hiển thị và Created By/Created Date không đổi.

**Acceptance Scenarios**:

1. **Given** dialog Edit mở với dữ liệu hiện tại của vendor, **When** người dùng đổi Name và lưu, **Then** thay đổi được lưu và danh sách hiển thị giá trị mới.
2. **Given** dialog Edit đang mở, **When** người dùng đổi Code thành Code của một vendor khác, **Then** hệ thống báo trùng và không lưu.
3. **Given** dialog Edit đang mở, **When** người dùng xóa trống Code hoặc Name, **Then** hệ thống báo lỗi bắt buộc và không lưu.

---

### User Story 4 - Xóa vendor (Priority: P2)

Người dùng bấm biểu tượng xóa trên một dòng, xác nhận trong hộp thoại, vendor bị xóa khỏi danh sách.

**Why this priority**: Dọn dẹp dữ liệu không còn dùng; không chặn các luồng chính.

**Independent Test**: Xóa một vendor, xác nhận nó biến mất khỏi danh sách; hủy xác nhận thì vendor vẫn còn.

**Acceptance Scenarios**:

1. **Given** danh sách có vendor, **When** người dùng bấm xóa và xác nhận, **Then** vendor bị xóa và danh sách làm mới.
2. **Given** hộp thoại xác nhận xóa đang mở, **When** người dùng hủy, **Then** không có gì thay đổi.

---

### Edge Cases

- Code/Name chứa khoảng trắng thừa ở đầu/cuối: hệ thống cắt bỏ trước khi kiểm tra và lưu.
- Kiểm tra trùng Code không phân biệt hoa/thường (ví dụ "v001" trùng "V001").
- Hai người dùng cùng tạo Code giống nhau gần như đồng thời: chỉ một thành công, người còn lại nhận thông báo trùng.
- Sửa/xóa vendor đã bị người khác xóa trước đó: hệ thống báo bản ghi không còn tồn tại và làm mới danh sách.
- Code hoặc Name vượt độ dài tối đa cho phép: báo lỗi giới hạn độ dài.
- Người dùng không có quyền: không thấy/không thực hiện được thao tác tương ứng (Add/Edit/Delete).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hệ thống MUST hiển thị danh sách vendor dạng bảng với các cột Code, Name, Created By, Created Date.
- **FR-002**: Người dùng MUST có thể tìm kiếm vendor theo Code hoặc Name qua ô Search.
- **FR-003**: Hệ thống MUST phân trang danh sách khi số bản ghi vượt một trang.
- **FR-004**: Người dùng MUST có thể tạo vendor mới bằng cách nhập Code và Name; hệ thống tự ghi nhận người tạo và ngày tạo.
- **FR-005**: Hệ thống MUST yêu cầu Code và Name không được để trống khi tạo hoặc sửa.
- **FR-006**: Hệ thống MUST đảm bảo Code là duy nhất giữa các vendor (không phân biệt hoa/thường) và báo lỗi rõ ràng khi trùng, cả khi tạo và khi sửa.
- **FR-007**: Người dùng MUST có thể sửa Code và Name của vendor hiện có; người tạo và ngày tạo MUST giữ nguyên.
- **FR-008**: Người dùng MUST có thể xóa vendor sau khi xác nhận trong hộp thoại.
- **FR-009**: Hệ thống MUST giới hạn độ dài Code và Name và báo lỗi khi vượt giới hạn.
- **FR-010**: Hệ thống MUST kiểm soát quyền truy cập cho xem, thêm, sửa, xóa theo cơ chế phân quyền hiện có của EUTR; mục menu Vendors đã được thêm sẵn trong dữ liệu.
- **FR-011**: Hệ thống MUST lưu dữ liệu vendor vào bảng `eutr_vendors` gồm các cột Id, Code, Name, CreatedBy, CreatedDate.
- **FR-012**: Hệ thống MUST hiển thị thông báo thành công/thất bại thân thiện sau mỗi thao tác tạo, sửa, xóa.

### Key Entities *(include if feature involves data)*

- **Vendor**: Nhà cung cấp trong hệ thống EUTR. Thuộc tính: Id (định danh), Code (mã duy nhất), Name (tên), CreatedBy (người tạo), CreatedDate (ngày tạo). Hiện chưa có quan hệ với thực thể khác trong phạm vi tính năng này.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng tạo một vendor mới (từ lúc bấm Add đến khi thấy trong danh sách) trong dưới 30 giây.
- **SC-002**: Tìm kiếm trả về kết quả hiển thị gần như tức thì (dưới 1 giây) với danh sách tới 10.000 vendor.
- **SC-003**: 100% nỗ lực tạo/sửa vendor với Code trùng hoặc dữ liệu bắt buộc bị trống đều bị chặn với thông báo rõ ràng.
- **SC-004**: 95% người dùng hoàn thành các thao tác thêm, sửa, xóa ngay lần thử đầu mà không cần hướng dẫn.

## Assumptions

- Mục menu **EUTR > Vendors** và quyền liên quan đã được thêm sẵn trong dữ liệu; tính năng này không tạo mới menu.
- Bảng `eutr_vendors` chưa tồn tại trong tài liệu thiết kế DB và sẽ được tạo mới với đúng các cột đã nêu; Code là duy nhất.
- Giới hạn độ dài mặc định: Code tối đa 50 ký tự, Name tối đa 255 ký tự.
- Xóa là xóa vĩnh viễn (không xóa mềm); do chưa có tính năng nào tham chiếu bảng này nên không cần kiểm tra ràng buộc khi xóa.
- Không có cột cập nhật (UpdatedBy/UpdatedDate) — theo đúng danh sách cột được yêu cầu.
- Phạm vi chỉ gồm CRUD cơ bản; không bao gồm import/export, đồng bộ vendor từ hệ thống ngoài, hay gán vendor cho template.
- Người dùng đã đăng nhập qua cơ chế xác thực hiện có; người tạo lấy từ tài khoản đăng nhập hiện tại.
