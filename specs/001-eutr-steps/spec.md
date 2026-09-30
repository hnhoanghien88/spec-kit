# Feature Specification: EUTR Steps Management

**Feature Branch**: `001-eutr-steps`

**Created**: 2026-06-30

**Status**: Draft

**Input**: User description: "Màn hình EUTR Steps - CRUD quản lý các bước (steps) trong quy trình EUTR, theo thiết kế design/eutr_steps.md. Backend API đã có sẵn tại api/eutr-steps."

## Clarifications

### Session 2026-09-30 — Bug fix: xóa (đơn/nhiều) một Step đang được Template tham chiếu báo lỗi SQL thô thay vì thông báo rõ ràng

- Input: "delete nhiều dòng trong eutr/steps link https://localhost:7141/api/eutr-steps/delete-multi.
  báo lỗi MySql.Data.MySqlClient.MySqlException (0x80004005): Cannot delete or update a parent row: a
  foreign key constraint fails (`compliance_sys_db_eutr`.`eutr_template_details`, CONSTRAINT
  `eutr_template_details_stepid_foreign` FOREIGN KEY (`StepId`) REFERENCES `eutr_steps` (`Id`))".
- Bối cảnh (rà soát mã nguồn xác nhận nguyên nhân gốc): `EutrStepService` trước đây không override
  `DeleteAsync`/`DeleteMultiAsync` — kế thừa nguyên bản từ `BaseService`, không có bước kiểm tra ràng
  buộc khóa ngoại nào trước khi gọi DELETE. Khi một Step đang được ít nhất một Template tham chiếu
  (`eutr_template_details.StepId`), MySQL từ chối lệnh DELETE bằng lỗi 1451 (constraint
  `eutr_template_details_stepid_foreign`) — ngoại lệ `MySqlException` thô này không được bắt riêng nên
  lộ nguyên văn ra tận response API/giao diện. Tính năng `006-eutr-reference-types` đã có sẵn đúng cơ
  chế sửa lỗi này cho một ràng buộc khóa ngoại tương tự (`EutrReferenceTypesService`, bắt lỗi 1451 của
  `eutr_references_reftype_foreign`) — dùng lại đúng mẫu đó cho Step.
- Change: `DeleteAsync`/`DeleteMultiAsync` của Step MUST bắt riêng lỗi MySQL 1451 (vi phạm khóa ngoại)
  phát sinh khi (một hoặc nhiều) Step đang bị Template tham chiếu, và dịch thành thông báo lỗi tiếng
  Anh rõ ràng cho người dùng (theo FR-011, không phải văn bản lỗi SQL thô) — thay vì để ngoại lệ SQL
  gốc lộ ra ngoài. Xóa nhiều (`DeleteMultiAsync`) MUST tiếp tục dùng chung 1 transaction cho cả lượt
  xóa — nếu bất kỳ Step nào trong lượt bị chặn vì đang được tham chiếu, TOÀN BỘ lượt xóa đó rollback
  (không xóa một phần), đúng theo cách `006-eutr-reference-types` đã làm cho tình huống tương tự.
- Q: Vì sao không cho xóa một phần (bỏ qua Step đang bị tham chiếu, chỉ xóa các Step hợp lệ còn lại)?
  → A: Giữ đúng hành vi rollback-toàn-bộ đã có sẵn ở `006-eutr-reference-types` cho ràng buộc khóa
  ngoại tương tự — nhất quán giữa hai màn hình, và tránh để người dùng bối rối khi 1 lượt xóa nhiều chỉ
  thành công một phần mà không có lựa chọn rõ ràng nào để biết trước Step nào sẽ bị chặn.

### Session 2026-07-01

- Q: Phạm vi chuyển sang tiếng Anh — tài liệu spec, giao diện ứng dụng, hay cả hai? → A: Chỉ toàn bộ văn bản hiển thị cho người dùng trên front-end (nhãn cột, nút, breadcrumb, thông báo kiểm tra/lỗi/thành công, trạng thái rỗng, hộp thoại xác nhận) phải bằng tiếng Anh; tài liệu spec giữ nguyên.

### Session 2026-08-11

- Bổ sung yêu cầu: không cho phép tạo mới hoặc sửa một bước thành tên trùng với tên của bước khác đã tồn tại (so khớp không phân biệt hoa/thường, sau khi loại bỏ khoảng trắng đầu/cuối).

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
3. **Given** đã tồn tại một bước có tên "Sourcing", **When** nhập tên "Sourcing" (hoặc "sourcing",
   " Sourcing ") vào biểu mẫu thêm mới và lưu, **Then** hệ thống báo lỗi tên bước đã tồn tại và
   không tạo bản ghi mới.

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
3. **Given** đã tồn tại một bước khác có tên "Sourcing", **When** sửa bước hiện tại thành tên
   "Sourcing" (hoặc khác biệt chỉ ở hoa/thường hay khoảng trắng đầu/cuối) và lưu, **Then** hệ
   thống báo lỗi tên bước đã tồn tại và không lưu thay đổi.
4. **Given** đang sửa một bước, **When** giữ nguyên tên hiện tại (không đổi) và lưu, **Then** hệ
   thống lưu thành công vì bước không bị so trùng với chính nó.

---

### User Story 4 - Xóa bước (Priority: P2)

Người dùng nhấn **Delete** trên một dòng, xác nhận, và bước bị loại khỏi danh sách. Hệ thống
cũng hỗ trợ xóa nhiều bước cùng lúc. **(Cập nhật 2026-09-30)** Nếu (một hoặc nhiều) bước đang được
ít nhất một Template tham chiếu (`eutr_template_details`), hệ thống MUST chặn việc xóa và hiển thị
thông báo lỗi rõ ràng — KHÔNG hiển thị văn bản lỗi SQL thô; xóa nhiều với ít nhất 1 bước bị chặn MUST
rollback toàn bộ lượt xóa đó (không xóa một phần).

**Why this priority**: Dọn dẹp các bước không còn dùng là cần thiết nhưng ít rủi ro nếu để sau.

**Independent Test**: Nhấn Delete trên một dòng, xác nhận, và kiểm tra dòng đó biến mất khỏi bảng.

**Acceptance Scenarios**:

1. **Given** một bước tồn tại, **When** nhấn Delete và xác nhận, **Then** bước biến mất khỏi bảng.
2. **Given** đã chọn nhiều bước, **When** thực hiện xóa nhiều, **Then** tất cả bước đã chọn biến
   khỏi bảng.
3. **Given** hộp thoại xác nhận xóa hiện ra, **When** người dùng hủy, **Then** không có bước nào
   bị xóa.
4. **(Cập nhật 2026-09-30)** **Given** một bước đang được ít nhất một Template tham chiếu
   (`eutr_template_details`), **When** nhấn Delete trên dòng đó và xác nhận, **Then** hệ thống chặn
   việc xóa, bước đó vẫn còn trong bảng, và hiển thị thông báo lỗi rõ ràng bằng tiếng Anh (ví dụ "This
   step is currently used by one or more templates and cannot be deleted.") — KHÔNG hiển thị văn bản
   lỗi SQL thô (`MySqlException`/tên bảng/constraint).
5. **(Cập nhật 2026-09-30)** **Given** đã chọn nhiều bước để xóa, trong đó CÓ ÍT NHẤT 1 bước đang được
   Template tham chiếu (các bước còn lại không bị tham chiếu), **When** thực hiện xóa nhiều, **Then**
   TOÀN BỘ lượt xóa bị chặn — kể cả các bước không bị tham chiếu cũng KHÔNG bị xóa (rollback toàn bộ,
   không xóa một phần) — kèm thông báo lỗi rõ ràng.

---

### Edge Cases

- Khi danh sách rỗng, bảng hiển thị trạng thái trống thân thiện thay vì lỗi.
- Khi tìm kiếm không có kết quả, bảng hiển thị "không có dữ liệu" và phân trang về 0.
- Khi người dùng không có quyền với một thao tác (theo policy của API), nút tương ứng không khả
  dụng hoặc thao tác bị từ chối với thông báo rõ ràng.
- Khi lưu/xóa thất bại do lỗi mạng hoặc máy chủ, người dùng nhận thông báo lỗi và dữ liệu không
  bị thay đổi sai lệch.
- Khi tên nhập vào chỉ khác tên đã tồn tại ở khoảng trắng đầu/cuối hoặc hoa/thường, hệ thống vẫn
  coi là trùng và chặn lưu.
- Khi sửa một bước và giữ nguyên tên hiện tại của chính nó, hệ thống không báo trùng (không tự so
  khớp với bản ghi đang sửa).
- **(Cập nhật 2026-09-30)** Khi xóa một bước đang được Template tham chiếu (`eutr_template_details`),
  hệ thống chặn xóa kèm thông báo lỗi rõ ràng — không phải lỗi hệ thống, người dùng cần gỡ bước đó khỏi
  mọi Template trước (màn `003-eutr-templates`) rồi mới xóa được.
- **(Cập nhật 2026-09-30)** Khi xóa nhiều bước, TẤT CẢ bước trong lượt đều không bị Template nào tham
  chiếu: xóa thành công bình thường như trước (không đổi).

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
- **FR-005a**: Hệ thống MUST chặn việc tạo mới hoặc sửa một bước thành tên trùng với tên của một
  bước khác đã tồn tại (so khớp không phân biệt hoa/thường, sau khi loại bỏ khoảng trắng đầu/cuối)
  và hiển thị thông báo lỗi rõ ràng; bản ghi đang được sửa không tự so trùng với chính nó.
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
- **FR-012 (Cập nhật 2026-09-30, bug fix)**: Khi xóa (đơn hoặc nhiều) một bước đang được ít nhất một
  Template tham chiếu (`eutr_template_details.StepId`), hệ thống MUST chặn việc xóa và hiển thị thông
  báo lỗi rõ ràng bằng tiếng Anh (theo FR-011) — KHÔNG được để lộ văn bản lỗi SQL thô
  (`MySqlException`/tên bảng/constraint) ra giao diện. Xóa nhiều với ít nhất 1 bước bị chặn MUST
  rollback TOÀN BỘ lượt xóa đó trong cùng 1 transaction — không xóa một phần các bước còn lại không bị
  tham chiếu.

### Key Entities *(include if feature involves data)*

- **EUTR Step (Bước EUTR)**: Đại diện cho một bước trong quy trình EUTR. Thuộc tính: định danh,
  tên bước, người tạo, ngày tạo, người cập nhật, ngày cập nhật.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng tìm thấy và mở màn hình EUTR Steps trong vòng 10 giây kể từ khi vào hệ
  thống mà không cần hướng dẫn.
- **SC-002**: Người dùng tạo một bước mới hoàn chỉnh trong dưới 30 giây.
- **SC-003**: 100% thao tác tạo/sửa với tên trống bị chặn và hiển thị thông báo lỗi rõ ràng.
- **SC-003a**: 100% thao tác tạo/sửa với tên trùng (không phân biệt hoa/thường, khoảng trắng
  đầu/cuối) với một bước khác đã tồn tại bị chặn và hiển thị thông báo lỗi rõ ràng.
- **SC-004**: Người dùng lọc đến đúng bước cần tìm bằng từ khóa trong dưới 5 giây với danh sách
  tối thiểu 100 bản ghi.
- **SC-005**: Mọi thao tác xóa đều yêu cầu xác nhận, không có trường hợp xóa nhầm do một cú nhấp.
- **SC-006 (Cập nhật 2026-09-30, bug fix)**: 100% lượt xóa (đơn hoặc nhiều) một bước đang được Template
  tham chiếu hiển thị đúng thông báo lỗi rõ ràng bằng tiếng Anh — 0% lượt xóa như vậy còn hiển thị văn
  bản lỗi SQL thô ra giao diện. 100% lượt xóa nhiều có ít nhất 1 bước bị chặn không xóa bất kỳ bước nào
  trong lượt đó (rollback toàn bộ).

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
