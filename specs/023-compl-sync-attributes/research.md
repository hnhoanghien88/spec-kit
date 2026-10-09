# Research: Compl Sync Attributes

- **R1 – Nguồn D365**: Đọc entity `RSVNAttributeRuleGroupCombines` qua `IDynamicService.QueryAsync` + `DynamicsParameterManager` (cùng kỹ thuật `ComplSynchronizeDataService.FetchAllSalesLinesAsync`), phân trang top=1000 đến khi trang ngắn; gọi `_paramManager.Clear()` trước mỗi URL. Alternatives: `MasterDefaultRefSyncService.QueryAllFromDynamicsAsync` (private, gắn với trigger) — không tái sử dụng được.
- **R2 – Chiến lược ghi**: Lấy + parse toàn bộ dữ liệu trước; chỉ khi thành công mới `DeleteAll` rồi chèn lại. Đảm bảo không trùng (FR-008) và lỗi D365 không làm mất dữ liệu cũ. Alternative: upsert theo khóa (ItemId, Type, Name, Option) — phức tạp hơn, không cần khi nguồn là snapshot đầy đủ. Loại trùng trong bộ nhớ theo khóa này trước khi chèn.
- **R3 – Parse AttributeKey**: Split `&` → cần đúng 3 phần; mỗi phần lấy phần tử cuối sau `;`, rồi split `:` ở dấu `:` đầu tiên (text có thể chứa `:`) → (mã `long`, text trim, cắt 100). Sai → bỏ qua và đếm.
- **R4 – Kiểu dữ liệu**: Id `bigint unsigned AUTO_INCREMENT`; mã `bigint` NOT NULL; text `varchar(100)` NOT NULL; ItemId `varchar(50)` NOT NULL; CreatedBy `varchar(100)`; CreatedDate `datetime`.
- **R5 – CreatedBy**: Hằng `"compl-sync-attributes"` (tiến trình đồng bộ), vì tái sử dụng phụ thuộc user context là không cần thiết.
- **R6 – Migration**: file mới `Sqls/Migration/38_create_compl_attributes_combine.sql` + bản tham chiếu `Sqls/Tables/compl_attributes_combine.sql` (theo quy ước dự án).

## Update 1

- **R7 – Tái dùng SP**: `sp_load_compl_by_conditions` (qua `GetViewCompliancesForSoDetailAsync`) đã nhận danh sách `ViewCompliancesRequest` và trả `ViewCompliancesResponseDto` (cùng bố cục tab 0). Alternative: viết SP mới — loại vì lặp logic khớp điều kiện/phiên bản/hierarchy.
- **R8 – OR semantics**: mỗi dòng combine sinh tối đa 4 request đơn trường: `{Product=ItemId}`, `{Attribute=Type}`, `{Attribute=Name}`, `{Attribute=Option}`; khử trùng toàn bộ. Request đơn trường tránh yêu cầu "tất cả điều kiện cùng thỏa" (AND) của một request nhiều trường. Rủi ro cần kiểm khi chạy thật: master chỉ có điều kiện Attribute phải khớp với request chỉ có Attribute (đã xác nhận mô hình tương tự dòng Variant/Material của SO). 
- **R9 – Truy vấn combine**: `WHERE UpholsteryType=@v OR UpholsteryName=@v OR UpholsteryOption=@v` (RecId là `long`; RecId không phải số → trả rỗng).
- **R10 – Khử trùng kết quả**: client đã distinct theo `code-name-validFrom-validTo-fileName`; backend thêm `DistinctBy` theo (MasterId, Id compliance) để FR-016 đúng cả khi gọi trực tiếp.
- **R11 – Nhãn tab**: truyền `attr-type` (= Attribute Value Name) trên URL; thiếu → nhãn dự phòng "Compliances detail".
- **R12 – Không đổi DB**: chỉ đọc; không migration.

## Update 2

- **R13 – Lazy per nhóm**: trả danh sách nhóm + payload, client gọi `get-for-so-detail` khi mở (tái dùng `ProductRowCompliances`). Alternative: backend trả sẵn compliance mọi nhóm — loại vì N lần gọi SP (SC-008).
- **R14 – GroupValue**: `GetFromDynamics<RSVNAttributeTypeValueAlls>([recId],"RSVNAttributeTypeValueAlls","AttributeValueRecId","Attributes",ObjectType.ATTRIBUTE)` (đã dùng ở `ReferenceNameResolverService`, có cache); lấy `GroupValue` không rỗng, khử trùng. Payload nhóm Group `{AttributeGroup=GroupValue}` (trường đã có trong `ViewCompliancesRequest`, dùng ở `ComplianceDownloadService`).
- **R15 – Thay endpoint Update 1**: endpoint phẳng không còn dùng → gỡ để tránh code chết.
