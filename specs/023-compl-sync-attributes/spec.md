# Feature Specification: Compl Sync Attributes

**Feature Branch**: `023-compl-sync-attributes`

**Created**: 2026-10-09

**Status**: Draft

**Input**: User description: "compl-sync-attributes. Viết 1 service trong ComplSynchronizeData với endpoint test-compl-sync-attributes. Lấy dữ liệu từ RSVNAttributeRuleGroupCombines, tách ItemRelation và AttributeKey, lưu vào bảng mới compl_attributes_combine (Upholstery Type / Name / Option kèm mã và text)."

## Clarifications

### Session 2026-10-09 (Update 2) — Tab chi tiết nhóm theo tổ hợp (accordion) + nhóm theo GroupValue

- **Yêu cầu**: tab "Compliances detail - <Attribute name>" (Update 1, danh sách phẳng) đổi thành danh sách **accordion** như màn hình mẫu (mỗi dòng có mũi tên mở rộng, tiêu đề đậm):
  1. Mỗi dòng bảng `compl_attributes_combine` thỏa RecId (Type/Name/Option = RecId) là **một nhóm**, tiêu đề = `ItemId UpholsteryTypeText, UpholsteryNameText, UpholsteryOptionText`; bên trong là các compliance (master + detail) phù hợp điều kiện ItemId, UpholsteryType, UpholsteryName, UpholsteryOption (khớp một trong các giá trị).
  2. Thêm các nhóm theo **GroupValue**: lấy từ D365 `RSVNAttributeTypeValueAlls` với `AttributeValueRecId` = RecId, lấy GroupValue; mỗi GroupValue là một nhóm tiêu đề "Group: <GroupValue>" (VD "Group: Leather"), bên trong là compliance master/detail phù hợp GroupValue đó.
- **Quyết định mặc định**: (a) nhóm "Group: …" xếp trước các nhóm tổ hợp; (b) nhóm chỉ tải compliance khi mở rộng (lazy), vì có thể có hàng nghìn tổ hợp; (c) GroupValue rỗng bị bỏ qua, GroupValue trùng chỉ hiện một nhóm; (d) bảng compliance trong mỗi nhóm giống tab 0 (cột, xem file, tải xuống, cảnh báo); (e) D365 lỗi → vẫn hiện các nhóm tổ hợp, nhóm Group bỏ trống.

### Session 2026-10-09 (Update 1) — Màn hình Product attribute: ẩn cột RecId + tab "Compliances detail - <Attribute name>"

- **Bối cảnh**: Dữ liệu `compl_attributes_combine` (US1–US3) đã có; cần dùng nó ở màn hình compliance-view, tab **Product attribute** (`/compliance-view?ref-type=7&page=1&page-size=50`). Lưới hiện có 3 cột: Attribute Value RecId, Attribute Type Name, Attribute Value Name (`compliance-client/src/presentation/pages/compliance-view/hooks/useAllCompliancesColumnsAttribute.jsx`). Click dòng đã điều hướng sang trang chi tiết `compliance-view-so?ref-type=7&codes=<RecId>&obj-display=<RecId>-<Value name>` (`compliance-view/index_new.jsx`, case 7); trang chi tiết hiện chỉ có tab "Compliances of <đối tượng>", và đã có cơ chế tab thứ 3 cho Sales order/Customer (`compliance-view-so/index.jsx`, `hasComplianceDetailTab`).
- **Yêu cầu**:
  1. Ẩn cột **Attribute Value RecId** khỏi lưới tab Product attribute (giá trị RecId vẫn dùng nội bộ để mở trang chi tiết).
  2. Click một dòng trong lưới → vào trang chi tiết (giữ nguyên hành vi).
  3. Trang chi tiết ref-type=7 có thêm tab **"Compliances detail - <Attribute name>"** (ví dụ `Compliances detail - Leather`; `<Attribute name>` lấy từ **Attribute Value Name** của dòng đã click (VD dòng "Upholstery type | Leather" → "Leather"; chỉnh lại sau khi đối chiếu màn hình thực, trước đó ghi nhầm là Attribute Type Name)).
  4. Dữ liệu tab: từ `compl_attributes_combine` lấy các dòng có UpholsteryType **hoặc** UpholsteryName **hoặc** UpholsteryOption = Attribute Value RecId; với mỗi dòng lấy (ItemId, UpholsteryType, UpholsteryName, UpholsteryOption) rồi tìm các master/compliance phù hợp chứa **một trong** các giá trị đó; hiển thị bằng đúng bố cục/cột như danh sách "Compliances of attribute …" (Master code, Parent master, Master name, Actions, Code, Name, Valid from, Valid to, Expiry warning, Alert for, Responsible for).
- **Quyết định (mặc định hợp lý, không cần hỏi thêm)**: (a) điều kiện khớp là OR giữa 4 giá trị (ItemId = Product code, Type/Name/Option = mã thuộc tính); (b) một master/compliance khớp nhiều điều kiện chỉ hiện **một lần**; (c) tab mới chỉ xuất hiện cho ref-type=7 (không đổi các ref-type khác); (d) cách hiển thị lấy lại tab 0 nên giữ các thao tác sẵn có (xem file, tải xuống…).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Đồng bộ tổ hợp thuộc tính từ D365 (Priority: P1)

Người vận hành kích hoạt một endpoint test để hệ thống đọc toàn bộ bản ghi tổ hợp thuộc tính (RSVNAttributeRuleGroupCombines) từ D365, phân tích chuỗi AttributeKey thành ba thuộc tính Upholstery (Type, Name, Option) — mỗi thuộc tính gồm mã số và text hiển thị — rồi lưu mỗi tổ hợp thành một dòng trong bảng `compl_attributes_combine`, gắn với ItemId (lấy từ ItemRelation).

**Why this priority**: Đây là toàn bộ giá trị của tính năng: có dữ liệu tổ hợp thuộc tính đã chuẩn hóa để các màn hình compliance (ví dụ "Compliances of attribute 5637881237-Leather") tra cứu theo ItemId.

**Independent Test**: Gọi endpoint `test-compl-sync-attributes` với dữ liệu D365 mẫu, kiểm tra bảng `compl_attributes_combine` có đúng số dòng và đúng giá trị các cột.

**Acceptance Scenarios**:

1. **Given** một bản ghi D365 có ItemRelation = `ITEM01` và AttributeKey = `Type;5637881237:Leather&Name;5637881238:Cognac&Option;5637881239:Stitch`, **When** chạy đồng bộ, **Then** bảng có 1 dòng: ItemId=`ITEM01`, UpholsteryType=5637881237, UpholsteryTypeText=`Leather`, UpholsteryName=5637881238, UpholsteryNameText=`Cognac`, UpholsteryOption=5637881239, UpholsteryOptionText=`Stitch`, CreatedBy và CreatedDate được ghi.
2. **Given** AttributeKey được tách bởi `&` thành 3 phần A1, A2, A3, **When** xử lý mỗi phần, **Then** phần được tách tiếp bởi `;`, lấy phần tử cuối, rồi tách bởi `:` thành (mã, text); A1 → Type, A2 → Name, A3 → Option.
3. **Given** đồng bộ chạy xong, **When** người vận hành xem kết quả trả về, **Then** nhận được tóm tắt gồm số bản ghi đọc, số dòng lưu, số bản ghi bị bỏ qua.

---

### User Story 2 - Chạy lại đồng bộ không tạo dữ liệu trùng (Priority: P2)

Người vận hành có thể gọi lại endpoint nhiều lần; dữ liệu trong `compl_attributes_combine` luôn phản ánh đúng dữ liệu D365 hiện tại, không bị nhân đôi.

**Why this priority**: Endpoint dạng test sẽ được gọi lặp lại; trùng lặp làm sai dữ liệu tra cứu.

**Independent Test**: Gọi endpoint hai lần liên tiếp với cùng dữ liệu nguồn; số dòng sau lần 2 bằng sau lần 1.

**Acceptance Scenarios**:

1. **Given** bảng đã có dữ liệu từ lần chạy trước, **When** chạy lại với cùng dữ liệu nguồn, **Then** số dòng không đổi.
2. **Given** dữ liệu nguồn thay đổi một tổ hợp, **When** chạy lại, **Then** bảng phản ánh giá trị mới.

---

### User Story 3 - Bỏ qua dữ liệu sai định dạng mà không dừng đồng bộ (Priority: P3)

Bản ghi nguồn có ItemRelation hoặc AttributeKey rỗng/sai cấu trúc bị bỏ qua và ghi nhận, các bản ghi hợp lệ khác vẫn được lưu.

**Why this priority**: Đảm bảo độ bền, nhưng không phải luồng chính.

**Independent Test**: Cho nguồn gồm 1 bản ghi hợp lệ và 1 bản ghi AttributeKey hỏng; kết quả lưu 1 dòng, báo 1 bản ghi bỏ qua.

**Acceptance Scenarios**:

1. **Given** AttributeKey rỗng hoặc không đủ 3 phần, **When** xử lý, **Then** bản ghi bị bỏ qua và được tính vào số bỏ qua.
2. **Given** phần mã không phải số, **When** xử lý, **Then** bản ghi bị bỏ qua (không lưu giá trị sai).

### User Story 4 - Ẩn cột Attribute Value RecId ở tab Product attribute (Priority: P2) (Update 1)

Người dùng xem tab Product attribute chỉ thấy các cột có ý nghĩa nghiệp vụ (Attribute Type Name, Attribute Value Name); mã RecId kỹ thuật không còn hiển thị.

**Why this priority**: Giảm nhiễu trên lưới; RecId là mã nội bộ người dùng không cần đọc.

**Independent Test**: Mở `/compliance-view?ref-type=7`, kiểm tra không có cột Attribute Value RecId và click dòng vẫn mở đúng trang chi tiết.

**Acceptance Scenarios**:

1. **Given** người dùng ở tab Product attribute, **When** lưới tải xong, **Then** cột "Attribute Value RecId" không hiển thị (kể cả trong danh sách bật/tắt cột mặc định).
2. **Given** lưới đang hiển thị, **When** người dùng click một dòng, **Then** hệ thống mở trang chi tiết của đúng thuộc tính đó (tiêu đề dạng "Compliances of attribute <RecId>-<Value name>").

---

### User Story 5 - Tab "Compliances detail - <Attribute name>" trên trang chi tiết (Priority: P1) (Update 1)

Trên trang chi tiết của một thuộc tính (ví dụ Leather), người dùng chuyển sang tab "Compliances detail - Leather" để xem toàn bộ master/compliance liên quan tới thuộc tính này theo các tổ hợp (Item, Type, Name, Option) đã đồng bộ, thay vì chỉ khớp theo đúng một mã RecId.

**Why this priority**: Đây là giá trị chính của cải tiến — cho thấy compliance phủ cả những item có thuộc tính xuất hiện ở vị trí Type/Name/Option.

**Independent Test**: Với một RecId có dòng trong `compl_attributes_combine` và có master/compliance khớp ItemId hoặc một trong 3 mã, mở tab và đối chiếu danh sách với kết quả tra thủ công.

**Acceptance Scenarios**:

1. **Given** dòng "Leather" (RecId=5637881237) được click, **When** trang chi tiết mở, **Then** có thêm tab tên "Compliances detail - Leather" bên cạnh tab "Compliances of attribute 5637881237-Leather (n)".
2. **Given** `compl_attributes_combine` có dòng với UpholsteryType = RecId (hoặc Name/Option = RecId), **When** mở tab, **Then** hệ thống lấy (ItemId, Type, Name, Option) của các dòng đó và liệt kê master/compliance chứa ItemId hoặc một trong ba mã thuộc tính.
3. **Given** một master/compliance khớp nhiều điều kiện cùng lúc, **When** hiển thị, **Then** nó chỉ xuất hiện một lần.
4. **Given** tab hiển thị, **When** so với tab "Compliances of attribute …", **Then** bố cục cột và thao tác giống nhau (Master code, Parent master, Master name, Actions, Code, Name, Valid from, Valid to, Expiry warning, Alert for, Responsible for).
5. **Given** RecId không có dòng nào trong `compl_attributes_combine` hoặc không có master/compliance khớp, **When** mở tab, **Then** hiện trạng thái rỗng "No data", không lỗi.
6. **Given** trang chi tiết của ref-type khác 7, **When** mở, **Then** không xuất hiện tab này.

### Edge Cases

- (Update 1) RecId không tồn tại ở cột nào trong `compl_attributes_combine`; hoặc bảng chưa được đồng bộ (rỗng).
- (Update 1) Cùng một RecId xuất hiện ở các vai trò khác nhau (Type ở dòng này, Option ở dòng khác) — vẫn được gộp.
- (Update 1) Số tổ hợp (ItemId, Type, Name, Option) lớn — tab vẫn phải tải được trong thời gian chấp nhận được.
- (Update 1) Attribute Value Name rỗng — tab dùng nhãn dự phòng "Compliances detail".
- AttributeKey có ít hơn hoặc nhiều hơn 3 phần sau khi tách `&`.
- Một phần thiếu dấu `;` hoặc dấu `:` (không tách được mã/text).
- Text chứa khoảng trắng đầu/cuối (được cắt bỏ) hoặc dài hơn 100 ký tự (cắt về 100).
- ItemRelation rỗng hoặc dài hơn 50 ký tự.
- Nguồn D365 không trả bản ghi nào, hoặc D365 không truy cập được (trả lỗi rõ ràng). (Update 7: dữ liệu cũ đã bị xóa từ đầu lần chạy nên bảng rỗng; lần mở tab kế tiếp tự đồng bộ lại.)
- Nhiều bản ghi nguồn cùng ItemId và cùng tổ hợp.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hệ thống MUST cung cấp một service đồng bộ thuộc nhóm ComplSynchronizeData và một endpoint kiểm thử tên `test-compl-sync-attributes` để kích hoạt đồng bộ (yêu cầu đăng nhập như các endpoint cùng nhóm).
- **FR-002**: Hệ thống MUST đọc toàn bộ bản ghi RSVNAttributeRuleGroupCombines từ D365 làm nguồn.
- **FR-003**: Hệ thống MUST lưu dữ liệu vào bảng mới `compl_attributes_combine` gồm các cột: Id (BigInt), ItemId (Varchar 50), UpholsteryType (BigInt), UpholsteryName (BigInt), UpholsteryOption (BigInt), UpholsteryTypeText (Varchar 100), UpholsteryNameText (Varchar 100), UpholsteryOptionText (Varchar 100), CreatedBy (Varchar 100), CreatedDate (DateTime).
- **FR-004**: ItemId MUST lấy từ trường ItemRelation của bản ghi nguồn.
- **FR-005**: Hệ thống MUST tách AttributeKey theo `&` thành 3 phần A1, A2, A3; mỗi phần tách theo `;`, lấy phần tử cuối; phần tử đó tách theo `:` thành (mã, text).
- **FR-006**: A1 MUST ánh xạ vào UpholsteryType (mã) và UpholsteryTypeText (text); A2 vào UpholsteryName và UpholsteryNameText; A3 vào UpholsteryOption và UpholsteryOptionText.
- **FR-007**: Hệ thống MUST ghi CreatedBy và CreatedDate cho mỗi dòng được tạo.
- **FR-008**: Chạy lại đồng bộ MUST không tạo dòng trùng; dữ liệu phản ánh nguồn hiện tại.
- **FR-009**: Bản ghi có ItemRelation/AttributeKey rỗng hoặc sai cấu trúc, hoặc mã không phải số, MUST bị bỏ qua và được đếm; không làm dừng toàn bộ đồng bộ.
- **FR-010**: Endpoint MUST trả về tóm tắt: số bản ghi nguồn đọc được, số dòng lưu, số bản ghi bỏ qua, thông báo kết quả.
- **FR-011**: Thay đổi cấu trúc CSDL MUST được cung cấp dưới dạng migration có đánh số theo quy ước dự án.
- **FR-012** (Update 1): Lưới tab Product attribute (ref-type=7) MUST không hiển thị cột "Attribute Value RecId" (mặc định ẩn và không nằm trong lựa chọn hiển thị mặc định); các cột Attribute Type Name và Attribute Value Name vẫn hiển thị.
- **FR-013** (Update 1): Click một dòng của lưới MUST mở trang chi tiết của thuộc tính đó, vẫn dùng RecId nội bộ làm định danh (hành vi hiện có, không thay đổi).
- **FR-014** (Update 1): Trang chi tiết ref-type=7 MUST có thêm tab tên "Compliances detail - <Attribute name>", với <Attribute name> là Attribute Value Name của dòng đã click (ví dụ "Leather").
- **FR-015** (Update 1): Dữ liệu tab MUST được xác định bằng cách lấy các dòng `compl_attributes_combine` có UpholsteryType, UpholsteryName hoặc UpholsteryOption bằng RecId của thuộc tính.
- **FR-016** (Update 1): Với mỗi dòng ở FR-015, hệ thống MUST dùng (ItemId, UpholsteryType, UpholsteryName, UpholsteryOption) để tìm master/compliance phù hợp chứa ít nhất một trong các giá trị đó; kết quả là hợp (union) không trùng lặp.
- **FR-017** (Update 1): Danh sách trong tab MUST hiển thị cùng bố cục cột, thao tác và hành vi bảng như danh sách "Compliances of attribute …" hiện có (Master code, Parent master, Master name, Actions, Code, Name, Valid from, Valid to, Expiry warning, Alert for, Responsible for).
- **FR-018** (Update 1): Tab MUST hiển thị trạng thái rỗng "No data" khi không có dòng kết hợp hoặc không có master/compliance khớp, và MUST không xuất hiện ở trang chi tiết của ref-type khác 7.

### Key Entities

- **Tổ hợp thuộc tính nguồn (RSVNAttributeRuleGroupCombines)**: bản ghi D365 gồm ItemRelation (mã item) và AttributeKey (chuỗi mã hóa 3 thuộc tính dạng `...;mã:text&...;mã:text&...;mã:text`).
- **Compl Attributes Combine**: một dòng chuẩn hóa cho mỗi tổ hợp: ItemId, ba cặp (mã, text) Upholstery Type/Name/Option, cùng thông tin tạo (CreatedBy, CreatedDate).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% bản ghi nguồn hợp lệ được lưu với đúng 6 giá trị thuộc tính (3 mã + 3 text) so với kết quả tách thủ công trên bộ mẫu kiểm thử.
- **SC-002**: Chạy đồng bộ hai lần liên tiếp với cùng nguồn cho số dòng bằng nhau (0 dòng trùng).
- **SC-003**: 100% bản ghi sai định dạng được báo trong số bỏ qua và không làm gián đoạn việc lưu các bản ghi hợp lệ.
- **SC-004**: Người vận hành nhận kết quả tóm tắt sau mỗi lần chạy mà không cần truy vấn CSDL để biết kết quả.
- **SC-005** (Update 1): 0 cột "Attribute Value RecId" hiển thị ở tab Product attribute; 100% click dòng mở đúng trang chi tiết của thuộc tính đó.
- **SC-006** (Update 1): Với bộ mẫu kiểm thử, danh sách tab "Compliances detail - <Attribute name>" trùng 100% với kết quả tra thủ công theo (ItemId, Type, Name, Option), không có bản ghi lặp.
- **SC-007** (Update 1): Người dùng thấy nội dung tab trong vòng 5 giây với thuộc tính có tới 1.000 tổ hợp.

## Assumptions

- Dạng AttributeKey: 3 phần ngăn bởi `&`, mỗi phần dạng `<nhãn>;<mã>:<text>`; chỉ phần tử cuối sau `;` được dùng.
- Mỗi bản ghi nguồn tạo đúng một dòng; khóa nhận diện tổ hợp là (ItemId, Type, Name, Option) dùng để chống trùng (upsert).
- Id là khóa chính tự tăng; CreatedBy là tên người dùng/tiến trình đồng bộ (mặc định giá trị hệ thống nếu không có người dùng).
- Text vượt 100 ký tự bị cắt về 100; ItemRelation vượt 50 ký tự coi là sai định dạng.
- Tính năng chỉ gồm backend (service + endpoint kiểm thử); không có màn hình client mới. Kết nối D365 và cơ chế xác thực tái sử dụng từ feature 013 (compl-synchronize-data).
- Không tự động chạy theo lịch; chỉ chạy khi gọi endpoint.
- (Update 1) Update 1 mở rộng phạm vi sang client (màn hình compliance-view, ref-type=7) và một truy vấn đọc dữ liệu tab mới; thay thế ghi chú "không có màn hình client mới" ở trên cho phần này. Việc đồng bộ vẫn do endpoint kiểm thử kích hoạt, tab chỉ đọc dữ liệu đã đồng bộ.
- (Update 1) "Khớp" master/compliance nghĩa là master/compliance đó có điều kiện tham chiếu tới ItemId (Product code) hoặc một trong ba mã thuộc tính, theo cùng quy tắc khớp đang dùng cho các tab compliance hiện có.
- (Update 1) Tab mới dùng cùng quyền truy cập, bộ lọc và thao tác (xem file, tải xuống, cảnh báo) với tab "Compliances of attribute …".

## Update 2 — Bổ sung (2026-10-09)

### User Story 6 - Tab chi tiết dạng accordion theo tổ hợp và theo Group (Priority: P1) (Update 2)

Người dùng mở tab "Compliances detail - Leather" và thấy danh sách nhóm có thể mở rộng: các nhóm "Group: <GroupValue>" và các nhóm theo từng dòng `compl_attributes_combine`; mở một nhóm để xem compliance phù hợp của nhóm đó.

**Independent Test**: với RecId của Leather có ≥1 dòng combine và ≥1 GroupValue ở D365, tab hiện đúng số nhóm; mở từng nhóm hiện đúng compliance.

**Acceptance Scenarios**:

1. **Given** RecId có dòng combine (ITEM01, Leather, Cognac, Stitch), **When** mở tab, **Then** có nhóm tiêu đề "ITEM01 Leather, Cognac, Stitch" (đóng sẵn).
2. **Given** nhóm vừa mở rộng, **When** tải xong, **Then** hiện bảng compliance (master + detail) khớp ItemId hoặc một trong Type/Name/Option; trước khi mở không tải dữ liệu nhóm.
3. **Given** D365 `RSVNAttributeTypeValueAlls` có GroupValue "Leather" cho RecId, **When** mở tab, **Then** có nhóm "Group: Leather"; mở ra hiện compliance phù hợp GroupValue.
4. **Given** nhiều dòng cùng GroupValue hoặc GroupValue rỗng, **When** mở tab, **Then** mỗi GroupValue không rỗng chỉ một nhóm.
5. **Given** không có combine và không có GroupValue, **When** mở tab, **Then** hiện "No data".

- **FR-019** (Update 2): Tab MUST hiển thị danh sách nhóm dạng accordion; thay thế danh sách phẳng của FR-016/FR-017 ở cấp tab (bên trong mỗi nhóm vẫn dùng bố cục cột của FR-017).
- **FR-020** (Update 2): Mỗi dòng `compl_attributes_combine` thỏa FR-015 MUST là một nhóm, tiêu đề `ItemId UpholsteryTypeText, UpholsteryNameText, UpholsteryOptionText`; compliance trong nhóm khớp ItemId hoặc một trong UpholsteryType/Name/Option của dòng đó.
- **FR-021** (Update 2): Hệ thống MUST lấy GroupValue từ D365 `RSVNAttributeTypeValueAlls` theo `AttributeValueRecId` = RecId; mỗi GroupValue không rỗng (khử trùng) là một nhóm "Group: <GroupValue>" chứa compliance phù hợp GroupValue đó; nhóm Group xếp trước.
- **FR-022** (Update 2): Compliance của một nhóm MUST chỉ tải khi mở rộng nhóm lần đầu.
- **FR-023** (Update 2): D365 không truy cập được MUST không làm mất các nhóm tổ hợp (nhóm Group bỏ trống, ghi log).
- **SC-008** (Update 2): Tab hiển thị danh sách nhóm trong ≤ 3 giây với 1.000 dòng combine; mở một nhóm hiển thị compliance trong ≤ 5 giây.
- **SC-009** (Update 2): 100% GroupValue không rỗng của RecId có đúng một nhóm "Group: …"; 0 nhóm trùng.

## Update 3 — Tab chính ref-type 7 cùng nguồn dữ liệu với tab detail (2026-10-09)

- **Yêu cầu**: (1) Nhãn tab đầu của trang chi tiết Product attribute đổi từ "Compliances of attribute <RecId>-<Name> (N)" thành "Compliances of attribute - <Name> (N)" (VD "Compliances of attribute - Leather (7)"). (2) Dữ liệu tab này lấy cùng cách tính với tab "Compliances detail - <Name>" (các nhóm "Group: …" + các dòng `compl_attributes_combine`) nhưng **gộp phẳng**, không chia nhóm theo dòng.
- **FR-024** (Update 3): Tab đầu của ref-type=7 MUST có nhãn "Compliances of attribute - <Attribute Value Name> (N)", N là số dòng compliance đang hiển thị; ref-type khác giữ nhãn cũ.
- **FR-025** (Update 3): Danh sách tab đầu của ref-type=7 MUST là hợp (không trùng) compliance của mọi nhóm ở FR-020/FR-021, tính bằng cùng điều kiện khớp; bố cục cột không đổi. Khi RecId không có nhóm nào thì rỗng.
- **SC-010** (Update 3): Với một RecId, mọi compliance hiện ở một nhóm của tab detail đều có mặt ở tab đầu và ngược lại (0 chênh lệch).
- **Ghi chú**: các điều kiện được gộp thành một lần tính nên điều kiện AND giữa các tổ hợp khác nhau của cùng item có thể khớp chéo; đây là hệ quả của việc không chia nhóm. Hạn chế đã biết về Material/Product+Attribute (xem R8) vẫn áp dụng cho cả hai tab.

## Update 4 — Tab Attribute group (ref-type 12): lấy compliance theo thành viên của Group (2026-10-09)

- **Bối cảnh**: màn hình `compliance-view?ref-type=12`; double click một Group mở trang chi tiết (`codes` = GroupValue) và trước đây chỉ tìm master/compliance gắn thẳng vào GroupValue.
- **Yêu cầu**: lấy từ D365 `RSVNAttributeTypeValueAlls` các bản ghi có `GroupValue` = Group vừa chọn → danh sách `AttributeValueRecId` → từ các RecId đó tìm toàn bộ master/compliance phù hợp để hiển thị.
- **FR-026** (Update 4): Trang chi tiết ref-type=12 MUST lấy các AttributeValueRecId (khử trùng, > 0) của GroupValue từ D365 và hiển thị hợp (không trùng) master/compliance phù hợp với các RecId đó; D365 lỗi MUST trả lỗi rõ ràng (không hiện danh sách thiếu im lặng).
- **FR-027** (Update 4): Compliance gắn thẳng vào chính GroupValue MUST vẫn được hiển thị (giữ hành vi cũ, tránh mất dữ liệu).
- **SC-011** (Update 4): Với một Group, mọi compliance của từng thuộc tính thành viên đều có mặt trong tab; không dòng trùng.
- **Ghi chú**: như Update 3, các RecId được tính chung một lần nên điều kiện AND giữa nhiều thuộc tính khác nhau có thể khớp chéo; giả định D365 trả đủ thành viên của Group trong một lần truy vấn.

## Update 5 — Tab Attribute group: kết hợp compl_attributes_combine + tab "Compliances detail - <Group name>" (2026-10-09)

- **Yêu cầu**: ở trang chi tiết ref-type=12 (Attribute group), sau khi lấy AttributeValueRecId từ D365 `RSVNAttributeTypeValueAlls` theo GroupValue, tiếp tục lấy các dòng `compl_attributes_combine` có `UpholsteryType` = các RecId đó; từ các dòng này tìm master/compliance phù hợp. Có thêm tab "Compliances detail - <Group name>" hiển thị giống tab Product attribute (accordion).
- **FR-028** (Update 5): Nhóm của ref-type=12 MUST gồm: nhóm "Group: <GroupValue>" (payload FR-026/FR-027) rồi mỗi dòng `compl_attributes_combine` có UpholsteryType thuộc các RecId của Group là một nhóm (tiêu đề và điều kiện khớp như FR-020).
- **FR-029** (Update 5): Trang chi tiết ref-type=12 MUST có tab "Compliances detail - <GroupValue>" hiển thị các nhóm FR-028 dạng accordion, tải compliance khi mở nhóm (như FR-019/FR-022).
- **FR-030** (Update 5): Tab đầu của ref-type=12 MUST là hợp (không trùng) compliance của mọi nhóm FR-028 (cùng cách tính với tab detail, gộp phẳng) — cập nhật FR-026 cho khớp.
- **SC-012** (Update 5): Compliance của tab đầu = hợp compliance các nhóm của tab detail (0 chênh lệch).
- **Ghi chú**: chỉ khớp dòng combine theo UpholsteryType (không Name/Option), đúng yêu cầu; D365 lỗi → trả lỗi.

## Update 6 — Tự đồng bộ khi mở tab Product attribute / Attribute group (2026-10-09)

- **Yêu cầu**: khi người dùng mở tab Product attribute (ref-type 7) hoặc Attribute group (ref-type 12) ở `compliance-view`, hệ thống kiểm tra `compl_attributes_combine`: lấy 1 dòng, so `CreatedDate` với hiện tại; bảng rỗng hoặc dữ liệu cũ hơn khoảng 6 giờ thì tự chạy đồng bộ như `test-compl-sync-attributes`.
- **FR-031** (Update 6): Mở hai tab trên (kể cả mở từ URL hoặc quay lại từ trang chi tiết) MUST kích hoạt kiểm tra độ mới; bảng rỗng hoặc `CreatedDate` cũ hơn 6 giờ (so với giờ UTC hiện tại) MUST đưa một lần đồng bộ vào chạy.
- **FR-032** (Update 6): Việc đồng bộ MUST chạy ở nền, không làm người dùng chờ; dữ liệu còn mới (< 6 giờ) MUST không kích hoạt gì.
- **FR-033** (Update 6): Nhiều người/nhiều lần mở tab trong lúc đang đồng bộ MUST không tạo thêm lần đồng bộ trùng; lỗi kiểm tra hoặc đồng bộ MUST không ảnh hưởng việc xem danh sách.
- **SC-013** (Update 6): Với bảng rỗng hoặc cũ hơn 6 giờ, mở tab kích hoạt đúng 1 lần đồng bộ; với dữ liệu còn mới, 0 lần.
- **Ghi chú**: lần mở đầu tiên chỉ kích hoạt đồng bộ; dữ liệu mới có sau khi job nền chạy xong (người dùng tải lại để thấy). Ngưỡng 6 giờ là hằng số trong code (`ComplSyncAttributesService.StaleAfter`).

## Update 7 — Xóa hết dữ liệu cũ trước khi đồng bộ (2026-10-09)

- **Yêu cầu**: trước mỗi lần chạy đồng bộ (endpoint test và job tự động) phải xóa hết dữ liệu trong `compl_attributes_combine`.
- **FR-034** (Update 7): Mỗi lần đồng bộ MUST xóa toàn bộ dữ liệu cũ của `compl_attributes_combine` ngay từ đầu, trước khi đọc D365; thay thế quyết định "chỉ xóa sau khi đọc + parse thành công" (research R2) và quy tắc "lỗi D365 không làm mất dữ liệu cũ". Lỗi xóa MUST dừng đồng bộ và báo lỗi.
- **Hệ quả**: nếu D365 lỗi sau khi xóa, bảng rỗng cho tới lần đồng bộ thành công kế tiếp (các tab Product attribute / Attribute group không có nhóm combine trong thời gian đó; mở tab sẽ tự kích hoạt đồng bộ lại theo FR-031).
