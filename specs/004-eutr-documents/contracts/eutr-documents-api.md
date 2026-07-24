# API Contract: EUTR Documents (MỚI — cần tạo)

Đích: `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrDocumentsController.cs` (clone mẫu
`EutrStepsController`, bỏ endpoint `GET` all-list vì không có màn hình nào khác cần nạp
`eutr-documents` làm select box). Base route: `api/eutr-documents`. Tất cả endpoint yêu cầu
`[Authorize]` + policy tương ứng. Bao bọc phản hồi: `ApiResponse<T>` (`{ data, message, success }`).

> **Update 19**: 4 endpoint (#8-#11 ở bản trước — `get-unassigned`, `assign-conditions`,
> `condition-assignment` GET/PUT) và endpoint `POST /api/sharepoint/eutr-upload-manual-multi`
> **đã bị xóa hoàn toàn** cùng luồng Assign condition/trang Add cũ (xem ghi chú Update 19 ngay dưới
> bảng). Endpoint #12 (`PUT {id}/step`) **được giữ lại nhưng đổi hẳn hành vi + đổi tên request DTO**
> — nay áp dụng cho mọi Type, không riêng "PO". Bảng dưới đây phản ánh contract **hiện tại** (sau
> Update 19).

| # | Method | Path | Policy | Body / Params | Trả về |
|---|--------|------|--------|---------------|--------|
| 1 | GET | `/api/eutr-documents/get-by-id/{id}` | `EutrDocuments.ReadOne` | — | `EutrDocumentsResponseDto` |
| 2 | POST | `/api/eutr-documents/get-all` | `EutrDocuments.ReadAll` | query: `page,pageSize,sortColumn,sortOrder`; body: `List<FilterRequest>` | `PagedResult<EutrDocumentsResponseDto>` |
| 3 | POST | `/api/eutr-documents` | `EutrDocuments.Create` | `EutrDocumentsRequestDto { name, validFrom, validTo }` | `long` (id mới) |
| 4 | PUT | `/api/eutr-documents/{id}` | `EutrDocuments.Update` | `EutrDocumentsRequestDto { name, validFrom, validTo }` | message |
| 5 | DELETE | `/api/eutr-documents/{id}` | `EutrDocuments.Delete` | — | message |
| 6 | POST | `/api/eutr-documents/delete-multi` | `EutrDocuments.Delete` | `IEnumerable<long> ids` | message |
| 7 | GET | `/api/eutr-documents/get-file-by-idref` | `EutrDocuments.ReadOne` | query: `idRef` (= `FileId`) | `SharepointFileContent` (`{ content, contentType, fileName }`) |
| 12 | PUT | `/api/eutr-documents/{id}/step` | `EutrDocuments.Update` | `EutrUpdateReferenceStepRequestDto { stepId, refValues? }` *(Update 19 — đổi tên từ `EutrUpdatePoStepRequestDto`, dùng chung mọi Type; `refValues` MỚI ở Update 22 — chỉ có giá trị khi Type khác "PO", kích hoạt đối chiếu thêm/xóa chip)* | message |

> Không có endpoint import/export/upload file ở phạm vi feature này (FR-006 — Add chưa có bước
> chọn/upload file thật).
>
> **Update 3** (Type/List PO/Manual trên trang Add — spec FR-016 đến FR-020): không có endpoint
> mới nào. Toàn bộ phần này là UI-only (dữ liệu mẫu tĩnh, không gọi API) — xem research Quyết
> định 8 và `data-model.md`.
>
> **Update 4** (List PO nối dữ liệu PO thật — spec FR-021/FR-022): không có endpoint mới nào dưới
> `api/eutr-documents`. Cột **PO name** của bảng List PO gọi endpoint **dùng chung đã có sẵn**
> `POST /api/dynamics/reference` (base route `api/dynamics`, ngoài phạm vi controller
> `EutrDocumentsController`) với `refType = 15` (`RSVNEutrPurchOrders`) — xem
> `docs/design/eutr` research Quyết định 9 và `data-model.md` để biết chi tiết ánh xạ. `refType =
> 16` (`RSVNEutrSalesOrderPurchases`) cũng được đăng ký ở cùng endpoint này nhưng không có UI nào
> trong feature `004-eutr-documents` gọi tới.
>
> **Update 5** (ô tìm kiếm PO lọc qua API — spec FR-023): KHÔNG có thay đổi contract/endpoint nào.
> Ô tìm kiếm gọi lại đúng `POST /api/dynamics/reference` với `refType = 15`, chỉ thêm `filters =
> [{ column: "Name", operator: "like", value: <từ khóa> }, { column: "Code", operator: "like",
> value: <từ khóa> }]` (do hook `useReferenceObjects` tự dựng) — backend đã tự ánh xạ "Code"/"Name"
> sang cột thật (`PurchId`/`Name`) qua `EntityMappings` có sẵn từ Update 4, nên không cần sửa
> `ComplDynamicsService.cs` hay bất kỳ contract nào (xem research Quyết định 10).
>
> **Update 6** (nút Upload thật ở Screen1 — spec FR-024 đến FR-030): thêm 1 endpoint **MỚI**, nằm
> ở **controller khác** (`SharePointController`, route `api/sharepoint`) — KHÔNG thuộc
> `EutrDocumentsController`/`api/eutr-documents`. Xem chi tiết ngay dưới đây. Contract của
> `api/eutr-documents` (6 endpoint ở bảng trên) **không đổi**.
>
> **Update 7** (validate prefix + ghi `eutr_references` — spec FR-031 đến FR-033): **KHÔNG đổi**
> path/request/response shape của `POST /api/sharepoint/eutr-upload-multi` — chỉ đổi **hành vi nội
> bộ**: thêm bước validate prefix trước khi upload SharePoint (file không khớp bị loại với
> `errorMessage` mới), và ghi thêm dòng `eutr_references` (không lộ ra ngoài response, chỉ ảnh hưởng
> tới việc tạo `documentId`/`success` có thành công hay không). Xem chi tiết ngay dưới.
>
> **Update 8** (nạp Step name/Type ở danh sách, File name/Step name ở List PO — spec FR-034 đến
> FR-038): endpoint #2 (`POST /api/eutr-documents/get-all`) **mở rộng response** — mỗi
> `EutrDocumentsResponseDto` có thêm `stepNames`/`refType` (xem chi tiết dưới bảng). Thêm **1
> endpoint mới** `POST /api/eutr-documents/list-po-references` (cùng controller, route gốc không
> đổi) để tra cứu File name/Step name cho bảng List PO ở trang Add. Không đổi 6 endpoint hiện có ở
> bảng trên (request/response shape giữ nguyên, chỉ endpoint #2 có thêm field response).
>
> **Update 9** (Delete xóa kèm `eutr_references` — spec FR-039/FR-040): endpoint #5
> (`DELETE /api/eutr-documents/{id}`) và #6 (`POST /api/eutr-documents/delete-multi`) **KHÔNG đổi**
> path/request/response — chỉ đổi **hành vi nội bộ**: mỗi document bị xóa nay kèm xóa toàn bộ dòng
> `eutr_references` có `DocumentId` tương ứng, trong cùng transaction với việc xóa
> `eutr_documents` (xem `data-model.md`, research Quyết định 24). Endpoint #5 (thành công): trả về
> message thành công như hiện tại; (thất bại — kể cả lỗi ở bước xóa `eutr_references`): document
> KHÔNG bị xóa (transaction rollback), lỗi được trả về theo cùng cơ chế hiện có (exception →
> `ApiResponse.Fail`), không có field mới trong response. Endpoint #6 (bulk): mỗi document trong
> `ids` được xóa qua 1 transaction **độc lập** — nếu tất cả thành công, response message không đổi;
> nếu 1 hoặc nhiều id lỗi, các id còn lại **vẫn bị xóa thành công** (không rollback lẫn nhau), và
> response trả về lỗi (qua middleware exception hiện có) liệt kê id/lý do của (các) id thất bại —
> client (frontend) cần tải lại danh sách để biết chính xác id nào đã xóa thành công nếu response
> báo lỗi một phần (không có field "per-item result" mới trong response ở phạm vi Update 9).
>
> **Update 10** (icon View mở xem file thật + Delete từng file ở List PO — spec FR-041 đến
> FR-045): thêm **1 endpoint mới** #7 (`GET /api/eutr-documents/get-file-by-idref`, xem chi tiết
> ngay dưới) — clone nguyên vẹn `ComplCompliancesController.GetFileByIds`. Endpoint #2
> (`POST /api/eutr-documents/list-po-references`) **mở rộng response**: mỗi item trong
> `documents[]` có thêm field `fileId` (không đổi request/path). Endpoint #5/#6 (Delete đơn/nhiều)
> **không đổi** — được tái sử dụng nguyên vẹn làm cơ chế xóa cho icon Delete theo từng file ở List
> PO (không có API xóa mới nào cho luồng này). Không có endpoint xóa file SharePoint nào được gọi
> bởi Update 10 (file thật trên SharePoint không bị xóa).
>
> **Update 11** (Screen2 "Upload manual" trở thành upload thật + Assign condition, tạo mới — spec
> FR-046 đến FR-054): thêm 1 endpoint MỚI ở **controller khác**
> (`POST /api/sharepoint/eutr-upload-manual-multi`, `SharePointController`, xem chi tiết dưới) và 2
> endpoint MỚI trong `EutrDocumentsController` (#8, #9 ở bảng trên — xem chi tiết dưới). Endpoint #2
> (`POST get-all`) **mở rộng response**: mỗi `EutrDocumentsResponseDto` có thêm `stepId`/
> `conditions` (xem mục "Mở rộng `EutrDocumentsResponseDto`" dưới). Endpoint #5/#6 (Delete đơn/nhiều)
> **không đổi request/response** — chỉ đổi SQL nội bộ của `DeleteByDocumentIdAsync` để dọn kèm
> `eutr_reference_details` (tránh vi phạm khóa ngoại, xem research Quyết định 30) — hành vi quan sát
> được từ client không đổi (vẫn xóa sạch mọi dữ liệu liên quan, chỉ nay bao gồm cả bảng con mới).
>
> **Update 12** (Edit rẽ nhánh theo Type — spec FR-055 đến FR-058): thêm 3 endpoint MỚI trong
> `EutrDocumentsController` (#10, #11 cho Type="Upload manual"; #12 cho Type="PO" — ở bảng trên).
> Endpoint #1 (`GET get-by-id/{id}`) và #4 (`PUT {id}`) **không đổi** — Edit cho Type="PO" gọi thêm
> endpoint #12 SAU khi #4 thành công (2 lời gọi độc lập cho 1 lượt Save); Edit cho Type="Upload
> manual" KHÔNG gọi #4 nữa (chỉ gọi #10 để tải trước, #11 để lưu).
>
> **Update 13** (`/speckit-clarify`): KHÔNG có endpoint mới — 2 thay đổi hành vi nội bộ: (a)
> `GET get-by-id/{id}`/`POST get-all` MUST trả `stepId` theo quy tắc xác định "Id nhỏ nhất" khi
> document Type="PO" có nhiều `eutr_references` (không đổi response shape, chỉ đổi cách tính giá
> trị); (b) endpoint #9/#11 (`assign-conditions`/`condition-assignment`) MUST validate chặn khi
> `conditions` có 2 dòng cùng `conditionType` (`400 Bad Request`, không đổi response shape khi hợp
> lệ).
>
> **Update 14** (cột Type lấy nhãn thật từ `eutr_reference_types` — spec FR-034): KHÔNG endpoint
> mới. Endpoint #1 (`GET get-by-id/{id}`) và #2 (`POST get-all`) **mở rộng response** — mỗi
> `EutrDocumentsResponseDto` có thêm field `typeName` (`string?`, xem chi tiết dưới bảng). `refType`
> vẫn được trả về nguyên vẹn (dùng cho rẽ nhánh Edit, FR-055/FR-056) — chỉ có nhãn hiển thị cột Type
> đổi nguồn, không đổi field nào khác, không đổi path/policy/request của bất kỳ endpoint nào.
>
> **Update 18** (popup Add gửi kèm `TypeId` khi Type = "PO" — spec FR-076/FR-077): KHÔNG endpoint
> mới, KHÔNG đổi contract của `api/eutr-documents`. `POST /api/sharepoint/eutr-upload-multi` (Update
> 6, xem chi tiết dưới đây) **mở rộng request** — thêm 1 field mới **nullable** `typeId` (`long?`);
> khi có giá trị, backend ghi trực tiếp vào `RefType` của mọi `eutr_references` tạo ở luồng này, thay
> cho hằng số cố định dùng trước đây (không đổi response shape, không đổi path/policy).
>
> **Update 19** (hợp nhất hoàn toàn Add/Edit vào một popup; xóa luồng Assign condition — spec FR-005
> đến FR-042, research Quyết định 53-60): thay đổi phạm vi lớn, **không migration DB mới**.
> - **Xóa hoàn toàn**: `POST get-unassigned`, `POST assign-conditions`,
>   `GET`/`PUT {id}/condition-assignment` (khỏi `EutrDocumentsController`); `POST /api/sharepoint/
>   eutr-upload-manual-multi` (khỏi `SharePointController`). Không có client nào khác ngoài chính SPA
>   này gọi các endpoint đó — xóa hẳn, không giữ route rỗng/410.
> - **`POST list-po-references` KHÔNG bị xóa** (khác dự kiến ban đầu khi lập kế hoạch): feature khác
>   trong cùng SPA (`eutr-sales-orders/ViewSalesOrderPage.jsx`, mục Template Checklist) vẫn gọi qua
>   `GetEutrDocumentsPoReferencesUseCase` — phát hiện khi implement (build thất bại lúc thử xóa), đã
>   khôi phục nguyên vẹn endpoint + DTO + repository method liên quan (xem research Quyết định 57).
> - **`PUT /api/eutr-documents/{id}/step`** (giữ route, đổi tên request DTO
>   `EutrUpdatePoStepRequestDto` → `EutrUpdateReferenceStepRequestDto`): hành vi đổi hoàn toàn — thay
>   vì chỉ áp dụng cho `RefType=0` (PO) và xóa-toàn-bộ-tạo-lại-1-dòng, nay `UPDATE StepId` **tại
>   chỗ** cho mọi dòng `eutr_references` của document, áp dụng cho **mọi Type** (không phân biệt),
>   giữ nguyên `RefValue`/`RefType`/số lượng bản ghi. Xem `data-model.md`.
> - **`POST /api/eutr-documents/get-all`/`GET get-by-id/{id}`** (endpoint #1/#2): field response
>   `conditions` đổi kiểu từ `List<ConditionGroupDto>` sang **`List<string>`** (flat, distinct
>   `RefValue`) — xem mục `EutrDocumentsResponseDto` bên dưới.
> - **`POST /api/sharepoint/eutr-upload-multi`** và **`POST /api/sharepoint/eutr-upload-multi-by-type`**
>   (xem 2 mục dưới đây): mỗi request thêm 2 field mới nullable `validFrom`/`validTo` — popup Add có
>   thêm 2 trường ngày (mặc định hôm nay/`9999-12-31`, editable); giá trị gửi lên được dùng làm
>   `ValidFrom`/`ValidTo` của mọi document tạo trong lượt Upload đó, thay cho hằng số cố định
>   `DateTime.Today`/`9999-12-31` dùng trước đây.
> - Endpoint #1, #2, #4, #5, #6, #7 khác **không đổi path/policy** (chỉ #2 đổi kiểu field `conditions`
>   như trên).
>
> **Update 21** (search box lọc Type/Step name/Conditions — spec FR-046 đến FR-050): endpoint #2
> (`POST /api/eutr-documents/get-all`) **không đổi path/policy/request-response shape công khai** —
> chỉ mở rộng ý nghĩa của `filters` (`List<FilterRequest>`, xem mục `FilterRequest` bên dưới): 3 tên
> `Column` mới, **ảo** (không tồn tại trên entity `EutrDocuments`) được `EutrDocumentsService.
> GetPagedAsync` diễn giải riêng trước khi gọi repository generic — `"TypeId"`, `"StepId"`,
> `"Conditions"`. Không có endpoint mới, không có DTO request mới — xem `data-model.md` mục "Update
> 21" cho chi tiết luồng xử lý (`IEutrReferencesRepository.GetMatchingDocumentIdsAsync` mới, tái dùng
> `Operator = "in"` sẵn có trên cột `Id`).

### API mới — `GET /api/eutr-documents/get-file-by-idref` (spec Update 10, FR-041/FR-042)

| Method | Path | Policy | Query | Trả về |
|---|---|---|---|---|
| GET | `/api/eutr-documents/get-file-by-idref` | `EutrDocuments.ReadOne` | `idRef` (= `FileId` của 1 `eutr_documents`) | `ApiResponse<SharepointFileContent>` |

- Clone nguyên vẹn logic của `ComplCompliancesController.GetFileByIds`
  (`[HttpGet("get-file-by-idref")]`) — cùng gọi `ISharepointService.ReadFileWithMetaAsync(idRef)`,
  cùng retry 1 lần khi gặp lỗi `503`, cùng trả `500`/`503` khi lỗi (xem research Quyết định 25).
- `EutrDocumentsController` nhận thêm `ISharepointService` qua constructor — không đăng ký DI mới
  (interface đã đăng ký sẵn, dùng chung với `ComplCompliancesController`/`SharePointController`).
- Response ví dụ:
  ```json
  {
    "success": true,
    "message": "Get file detail successfully",
    "data": {
      "content": "<base64>",
      "contentType": "application/pdf",
      "fileName": "INV2026_hop-dong-po123.pdf"
    }
  }
  ```
- Dùng để hiển thị popup xem trước file (frontend gọi qua `EutrFileViewerDialog`, xem
  `data-model.md`) cho icon **View** trên danh sách EUTR documents (User Story 1) và trên mỗi dòng
  của bảng List PO (trang Add, User Story 2). Không ghi/đổi dữ liệu nào — read-only.
- Frontend chỉ gọi endpoint này khi document có `FileId` khác `null` (icon View bị vô hiệu hóa khi
  `FileId = null`, không có kịch bản gọi `idRef` rỗng từ UI).

### API mới — `POST /api/sharepoint/eutr-upload-multi` (spec Update 6, FR-024 đến FR-030)

| Method | Path | Policy | Consumes | Body (`multipart/form-data`) | Trả về |
|---|---|---|---|---|---|
| POST | `/api/sharepoint/eutr-upload-multi` | `[Authorize]` (chung với các action khác của `SharePointController`, không có policy riêng) | `multipart/form-data` | `files`: 1+ file; `poCode`: string (mã PO/mã chip đang chọn); `typeId`: long? *(Update 18 — optional)*; `validFrom`/`validTo`: date? *(MỚI, Update 19 — optional, mặc định `DateTime.Today`/`9999-12-31` nếu vắng mặt)* | `ApiResponse<List<EutrUploadFileResultDto>>` |

- Nằm trong `SharePointController.cs` hiện có (cạnh `POST /api/sharepoint/upload-multi`), gọi service
  **mới** `IEutrUploadService.UploadMultipleToSharePointAndSaveDataAsync` — KHÔNG dùng lại
  `IComplUploadService`.
- `400 Bad Request` nếu `files` rỗng hoặc `poCode` rỗng/thiếu.
- Backend dùng `_configuration["SharePointEutrPath"]` (khóa cấu hình mới) làm gốc thư mục SharePoint;
  tự tìm thư mục con theo `poCode` (dùng lại nếu đã có, tạo mới nếu chưa) — xem `data-model.md`.
- Mỗi file trong `files` chỉ được chấp nhận nếu đúng định dạng (PDF, DOC/DOCX, XLS/XLSX, JPG/PNG)
  và ≤ 10MB; file không hợp lệ bị loại (không upload, không tạo document) nhưng vẫn xuất hiện trong
  response với `success: false` kèm `errorMessage`.
- Với mỗi file hợp lệ upload SharePoint thành công, backend tạo 1 bản ghi mới trong
  `eutr_documents` (`Name` = tên file gốc, `ValidFrom` = ngày hiện tại, `ValidTo` = `9999-12-31`,
  `FileId` = id SharePoint) — **không** qua `EutrDocumentsRequestDto`/`POST /api/eutr-documents`.
  Bảng `eutr_documents` không lưu `poCode` — PO chỉ dùng để xác định thư mục SharePoint.
- **(Update 7)** Trước khi upload lên SharePoint, mỗi file MUST qua thêm validate **prefix tên
  file** so với `eutr_master_documents.Prefix` (feature `002-eutr-masters`, chỉ đọc). File không
  khớp bất kỳ `Prefix` nào bị loại — trả về `{ success: false, errorMessage: "No matching prefix
  found in EUTR masters" }` (hoặc tương đương), KHÔNG upload lên SharePoint, KHÔNG tạo document.
- **(Update 7)** File khớp N `StepId` phân biệt trong `eutr_master_documents` thì sau khi upload
  SharePoint + tạo document thành công, backend ghi thêm **N dòng `eutr_references`** (cùng
  `DocumentId`, khác `StepId`, `RefType = 0`, `RefValue = poCode`) — xem `data-model.md`. Nếu bước
  ghi `eutr_references` thất bại, toàn bộ (document + mọi reference của file đó) bị rollback, file
  trả về `success: false` dù đã upload SharePoint thành công trước đó.
- **(Update 18, FR-076/FR-077)** `typeId` (`long?`) là field **mới, nullable** — khi request gửi kèm
  giá trị này (popup Add hợp nhất, Update 15/17, luồng Type = "PO"), backend dùng trực tiếp làm
  `RefType` cho mọi dòng `eutr_references` ghi ở bước trên (thay cho giá trị cố định `0` dùng trước
  đây) — đóng gap với ghi chú "`RefType = 0`" phía trên, vốn chỉ đúng khi `typeId` KHÔNG được gửi.
  Khi caller không gửi `typeId` (ví dụ trang Add độc lập cũ `EutrDocumentsAdd.jsx`, Update 6, **đã bị
  xóa hoàn toàn ở Update 19** — xem ghi chú Update 19 phía trên), hành vi ghi `RefType = 0` giữ nguyên
  như trước.
- **(Update 19, FR-014/FR-015/FR-021)** `validFrom`/`validTo` (`date?`) là 2 field **mới, nullable** —
  giá trị đang hiển thị ở 2 trường ngày trong popup Add tại thời điểm nhấn Upload (mặc định
  `DateTime.Today`/`9999-12-31`, người dùng có thể sửa trước khi Upload). Backend dùng
  `request.ValidFrom ?? DateTime.Today`/`request.ValidTo ?? MaxValidTo` khi ghi `ValidFrom`/`ValidTo`
  của mọi `eutr_documents` tạo trong lượt Upload này — thay cho 2 hằng số cố định dùng trước Update
  19.
- Ví dụ response (kèm 1 file bị loại vì sai prefix — Update 7):
  ```json
  {
    "success": true,
    "message": "Upload files successfully",
    "data": [
      { "fileName": "INV2026_hop-dong-po123.pdf", "success": true, "documentId": 501, "fileId": "01ABCXYZ...", "errorMessage": null },
      { "fileName": "qua-lon.pdf", "success": false, "documentId": null, "fileId": null, "errorMessage": "File exceeds 10MB limit" },
      { "fileName": "khong-co-prefix.pdf", "success": false, "documentId": null, "fileId": null, "errorMessage": "No matching prefix found in EUTR masters" }
    ]
  }
  ```
- Xem chi tiết DTO (`EutrMultiUploadFileRequest`/`EutrUploadFileResultDto`), logic suy ra thư mục,
  validate file, validate prefix và ghi `eutr_references` trong `data-model.md` (mục "Upload nhiều
  file thật lên SharePoint").

### ❌ ĐÃ XÓA kể từ Update 19 — `POST /api/sharepoint/eutr-upload-manual-multi` (spec Update 11, FR-046/FR-047)

Endpoint này (thư mục cố định `UploadManual`, không validate prefix, không ghi `eutr_references`) chỉ
phục vụ Screen2 "Upload manual" của trang Add cũ — đã bị xóa hoàn toàn cùng trang đó (research Quyết
định 57). Mọi Type (kể cả các Type từng đi qua luồng "Upload manual") giờ upload qua popup hợp nhất,
dùng `eutr-upload-multi` (Type="PO") hoặc `eutr-upload-multi-by-type` (Type khác) — xem 2 mục ở trên/
dưới.

### ❌ ĐÃ XÓA kể từ Update 19 — `POST /api/eutr-documents/get-unassigned` (spec Update 11, FR-048)

Danh sách "chưa gán Step/Conditions" chỉ tồn tại vì Screen2/popup Assign condition tạo document
không kèm `eutr_references` ngay lập tức — luồng đó không còn tồn tại (mọi document tạo qua popup
hợp nhất luôn có `eutr_references` ngay khi Upload, trừ trường hợp Type trống không áp dụng cho Add).
Xóa cùng research Quyết định 57.

### ❌ ĐÃ XÓA kể từ Update 19 — `POST /api/eutr-documents/assign-conditions` (spec Update 11, chế độ tạo mới, FR-052)

Popup "Assign condition" (cả 2 mode create/edit) bị loại bỏ hoàn toàn khỏi phạm vi feature — Step/
Value giờ được thu thập ngay trong popup Add hợp nhất tại thời điểm Upload (FR-009 đến FR-013). Xóa
cùng research Quyết định 57; entity/repository `eutr_reference_details` không còn được ghi bởi bất kỳ
luồng nào (bảng vẫn giữ nguyên trong schema, dữ liệu cũ không bị xóa/migrate).

### ❌ ĐÃ XÓA kể từ Update 19 — `GET`/`PUT /api/eutr-documents/{id}/condition-assignment` (spec Update 11/12, chế độ sửa, FR-057/FR-058)

Edit không còn rẽ nhánh mở popup Assign condition cho Type="Upload manual" — mọi Type dùng chung
đúng 1 popup Edit (Type khóa, chip chỉ đọc, Step/Valid from/Valid to sửa được). Sửa Step giờ đi qua
`PUT {id}/step` (xem mục dưới, hành vi mới áp dụng cho mọi Type). Xóa cùng research Quyết định 57.

### `PUT /api/eutr-documents/{id}/step` — Update 19: đơn giản hóa hoàn toàn, dùng chung mọi Type (spec FR-029/FR-033; trước đây Update 12/13, chỉ Type="PO")

| Method | Path | Policy | Body | Trả về |
|---|---|---|---|---|
| PUT | `/api/eutr-documents/{id}/step` | `EutrDocuments.Update` | `EutrUpdateReferenceStepRequestDto { stepId: long, refValues: string[]? }` *(Update 19 — đổi tên từ `EutrUpdatePoStepRequestDto`; `refValues` MỚI Update 22)* | message |

- **Trước Update 19**: chỉ áp dụng cho `RefType=0` (PO) — xóa toàn bộ dòng `eutr_references` cũ, tạo
  lại đúng 1 dòng mới (giữ `RefValue` từ dòng `Id` nhỏ nhất).
- **Từ Update 19**: `UPDATE eutr_references SET StepId=@StepId WHERE DocumentId=@DocumentId` — cập
  nhật **tại chỗ** mọi dòng hiện có của document (bất kể Type/`RefType` nào), giữ nguyên `RefValue`/
  `RefType`/số lượng bản ghi, KHÔNG xóa/tạo lại bản ghi nào (khớp đúng FR-033). Được gọi bởi popup
  Edit hợp nhất (mọi Type có ≥1 `eutr_references`, ngay cả PO) — SAU khi `PUT /api/eutr-documents/{id}`
  (endpoint #4, cập nhật `ValidFrom`/`ValidTo`) thành công, cùng 1 lượt Save.
- Document không có `eutr_references` nào: endpoint này không được gọi (Step field ẩn ở popup Edit).
- **Từ Update 22** (spec FR-051/FR-052): thêm field nullable `refValues: string[]?`. `null`/vắng mặt
  (Type = "PO", hoặc client cũ) → hành vi **không đổi** so với Update 19 ở trên (chỉ `UPDATE StepId`).
  Có giá trị (Type khác "PO") → backend trước tiên đối chiếu (diff) `refValues` gửi lên với tập
  `RefValue` hiện có của document: `INSERT` 1 dòng `eutr_references` mới cho mỗi giá trị chưa tồn tại
  (`DocumentId`, `StepId` = `stepId` đang gửi, `RefType` = suy lại từ dòng hiện có — không cần client
  gửi `TypeId`, `RefValue` = giá trị mới), `DELETE` các dòng có `RefValue` không còn xuất hiện trong
  `refValues`, rồi mới chạy `UPDATE StepId` như trên cho **mọi** dòng còn lại (kể cả dòng vừa insert).
  Toàn bộ 3 bước này gộp trong 1 transaction mới (trước Update 22, endpoint này không cần transaction
  vì chỉ có đúng 1 câu lệnh) — xem `data-model.md` mục "Update 22" và research Quyết định 65/66 cho
  chi tiết SQL/thứ tự bước.

### API dùng chung — `POST /api/dynamics/reference` (đã tồn tại, chỉ mở rộng bảng ánh xạ refType)

| Method | Path | Policy | Body | Trả về |
|---|---|---|---|---|
| POST | `/api/dynamics/reference` | `[Authorize]` (không có policy riêng theo refType) | query: `page,pageSize,sortColumn,sortOrder,refType`; body: `List<FilterRequest>` | `PagedResult<ComplDynReferenceResponseDto>` (`{ id, code, name }`) |

- `refType = 15` → `RSVNEutrPurchOrders`: `code = PurchId`, `name = Name`.
- `refType = 16` → `RSVNEutrSalesOrderPurchases` (chưa dùng ở UI): `code = RSVNRefPurchId`,
  `name = Name`.
- Endpoint và DTO response đã tồn tại từ trước (dùng bởi các refType 0-14 khác, ví dụ Vendor =
  14); feature này chỉ thêm 2 dòng vào `EntityMappings`/`MapDynamicsResponse` trong
  `ComplDynamicsService.cs`, KHÔNG tạo controller/route mới.

### API mới — `POST /api/sharepoint/eutr-upload-multi-by-type` (spec Update 15/16, popup Add hợp nhất, FR-066 đến FR-069)

> ⚠️ **Kể từ Update 17 (FR-072 đến FR-075)**: endpoint này chỉ còn được gọi khi Type đã chọn trong
> popup Add có `Name` **khác** "PO" (Vendor, Invoice, Delivery note, General agreement, Type mới).
> Khi Type = "PO", popup Add gọi lại endpoint gốc `POST /api/sharepoint/eutr-upload-multi` (xem mục
> ngay phía trên, Update 6/7) — không có `stepId` trong request, Step được backend tự suy theo
> Prefix tên file. Đây cũng là lý do cột "KHÔNG validate prefix" bên dưới chỉ còn đúng cho các Type
> khác "PO" gọi qua endpoint này — Type = "PO" vẫn validate prefix, nhưng qua endpoint gốc.
>
> **Update 18**: endpoint gốc mà Type = "PO" gọi lại (`eutr-upload-multi`) nay nhận thêm `typeId` từ
> popup Add (xem mục ngay phía trên) và ghi đúng giá trị đó vào `RefType` — cùng nguyên tắc
> `RefType = typeId` mà endpoint `eutr-upload-multi-by-type` này đã áp dụng cho mọi Type khác từ
> Update 15 (không đổi gì ở chính endpoint `eutr-upload-multi-by-type`).

| Method | Path | Policy | Body (`multipart/form-data`) | Trả về |
|---|---|---|---|---|
| POST | `/api/sharepoint/eutr-upload-multi-by-type` | `[Authorize]` (dùng chung mức controller, không policy riêng) | `EutrTypeMultiUploadFileRequest { files: File[], typeId: long, typeName: string, stepId: long, refValues: string[], validFrom: date?, validTo: date? }` *(`validFrom`/`validTo` MỚI, Update 19)* | `ApiResponse<List<EutrUploadFileResultDto>>` |

- Cùng route gốc `api/sharepoint` với `eutr-upload-multi` (Update 6) — xem `data-model.md` cho chi
  tiết request/response và bảng suy thư mục theo `typeName`.
- `typeId` ghi trực tiếp (cast `(byte)`) vào `eutr_references.RefType` cho mọi dòng tạo ra trong lượt
  này — KHÔNG còn giới hạn `0` (PO)/`1` (Upload manual) như các luồng Update 7/11.
- KHÔNG validate prefix `eutr_master_documents` cho các Type gọi qua endpoint này (Vendor/Invoice/
  Delivery note/General agreement/Type mới) — khác luồng PO (Update 7, và kể từ Update 17 không còn
  đi qua endpoint này nữa).
- **(Update 19)** `validFrom`/`validTo` (`date?`, nullable): cùng ý nghĩa/fallback với `eutr-upload-multi`
  (xem mục ở trên) — giá trị hiển thị ở popup Add tại thời điểm Upload, mặc định
  `DateTime.Today`/`9999-12-31` khi vắng mặt.

### API dùng chung — `GET /api/eutr-reference-types` (đã tồn tại từ feature `006-eutr-reference-types`, không đổi)

| Method | Path | Policy | Trả về |
|---|---|---|---|
| GET | `/api/eutr-reference-types` | `EutrReferenceTypes.ReadAll` | `IEnumerable<EutrReferenceTypes>` (`{ id, name }`) |

- Dùng để nạp **toàn bộ** dropdown Type trong popup Add (FR-060) — khác `EutrDocumentsAdd.jsx` cũ
  (FR-016, 2 lựa chọn hard-coded `TAKE_FROM_OPTIONS`, không đổi, ngoài phạm vi).

### API dùng chung — `GET /api/eutr-steps` (đã tồn tại, không đổi)

| Method | Path | Policy | Trả về |
|---|---|---|---|
| GET | `/api/eutr-steps` | `EutrSteps.ReadAll` | `IEnumerable<EutrSteps>` (`{ id, name }`) |

- Dùng để nạp combobox Step trong popup Add (FR-061) — cùng nguồn dữ liệu Step đã dùng ở popup
  Assign condition (Update 11) qua `GetEutrStepsUseCase.js`.
- **(Update 20)** Vẫn được gọi để tải **toàn bộ** `eutr_steps` (không lọc) — dùng làm nguồn đối chiếu
  object khi map kết quả lọc theo Type (xem mục ngay dưới), KHÔNG bị thay thế bởi API mới.

### API dùng chung — `GET /api/eutr-reference-type-details/by-type/{typeId}` (đã tồn tại từ feature `006-eutr-reference-types`, spec Update 20, FR-043 đến FR-045)

| Method | Path | Policy | Trả về |
|---|---|---|---|
| GET | `/api/eutr-reference-type-details/by-type/{typeId}` | `EutrReferenceTypes.ReadOne` | `IEnumerable<EutrReferenceTypeDetailsResponseDto>` (`{ id, typeId, stepId, stepName, createdBy, createdDate, updatedBy, updatedDate }`, `ORDER BY CreatedDate DESC`) |

- Endpoint/entity/repository/controller **đã được xây dựng đầy đủ** bởi feature `006-eutr-reference-
  types` (màn "Assign Steps") — feature `004-eutr-documents` chỉ **tiêu thụ read-only** qua use case
  frontend đã có sẵn `GetByTypeIdEutrReferenceTypeDetailsUseCase.js`; **0 thay đổi backend** cho
  Update 20 (research Quyết định 61).
- Dùng để lọc combobox Step trong popup Add/Edit (Type khác "PO") chỉ còn các Step có bản ghi
  `eutr_reference_type_details` khớp `TypeId` đang chọn (FR-043); dòng đầu tiên của kết quả được chọn
  sẵn làm mặc định ở mode Add (FR-044); mode Edit đảm bảo Step hiện tại của document luôn hiển thị
  được dù không còn nằm trong kết quả lọc (FR-045).
- Chính sách/quyền: policy `EutrReferenceTypes.ReadOne` (khác nhóm `EutrDocuments.*`) — cùng tiền lệ
  cross-feature đã có với 2 API dùng chung phía trên (`eutr-reference-types`, `eutr-steps`), không cần
  policy mới cho phạm vi feature này (research Quyết định 61).

## EutrDocumentsRequestDto

```json
{ "name": "Bien ban giao nhan go thang 7", "validFrom": "2026-07-01", "validTo": "2027-06-30" }
```

- `name`: bắt buộc, không rỗng (FluentValidation) — hiển thị trên UI là "File name".
- `validFrom`, `validTo`: tùy chọn, có thể `null`.
- Không có ràng buộc duy nhất trên `name` (FR-007b) — không có kiểm tra trùng ở service.

## EutrDocumentsResponseDto

```json
{
  "id": 100, "name": "Bien ban giao nhan go thang 7", "fileId": null,
  "validFrom": "2026-07-01T00:00:00", "validTo": "2027-06-30T00:00:00",
  "createdBy": "hien", "createdDate": "2026-07-07T03:00:00Z",
  "updatedBy": null, "updatedDate": null,
  "stepNames": [],
  "refType": null,
  "typeName": null,
  "stepId": null,
  "conditions": []
}
```

> **Update 19**: `conditions` đổi kiểu từ `List<ConditionGroupDto>` (Update 11) sang **`List<string>`**
> — xem mô tả cập nhật ở cuối phần này.

- `fileId` luôn `null` cho bản ghi tạo qua form Save (Add chưa có input file); có giá trị cho bản
  ghi tạo qua nút Upload (Update 6/7).
- `stepNames`/`refType`: **mới, kể từ Update 8** — nạp bằng cách JOIN `eutr_references`/`eutr_steps`
  theo `DocumentId` (xem `data-model.md`, research Quyết định 20). `[]`/`null` cho document không có
  bản ghi `eutr_references` nào (ví dụ document tạo qua form Save nhập tay). `refType` (`byte?`) vẫn
  được giữ nguyên trong response (dùng bởi Edit để rẽ nhánh popup theo Type, FR-055/FR-056) nhưng
  **kể từ Update 14** KHÔNG còn dùng để map nhãn hiển thị cột Type ở frontend.
- `typeName` (`string?`, **mới, kể từ Update 14, FR-034**): nhãn Type đã tính sẵn ở backend — JOIN
  `RefType` với `eutr_reference_types.Id`, trả về `Name` (xem `data-model.md`, research Quyết định
  41). `null` khi document không có bản ghi `eutr_references` nào, hoặc khi `RefType` không khớp bất
  kỳ bản ghi `eutr_reference_types` nào (dữ liệu ngoại lệ). Cột "Type" trên grid MUST hiển thị trực
  tiếp `typeName` này — KHÔNG còn tra `TAKE_FROM_OPTIONS` ở frontend cho cột này (thay thế hoàn toàn
  cách nạp nhãn cũ mô tả trước Update 14).
- `stepId` (`long?`, **mới, kể từ Update 13**): Step hiện tại — với Type="PO" (nhiều
  `eutr_references` có thể), là `StepId` của dòng có `Id` nhỏ nhất; dùng để nạp dropdown Step khi mở
  Edit (FR-055).
- `conditions` (**Update 19**: `List<string>`, trước đó `List<ConditionGroupDto>` từ Update 11):
  danh sách `RefValue` **phân biệt**, khác `null`, của mọi bản ghi `eutr_references` thuộc document —
  ví dụ `["PO000123", "PO000124"]`; `[]` khi document không có bản ghi nào hoặc mọi bản ghi có
  `RefValue = null` (FR-005). Không còn phân nhóm theo `ConditionType`/đọc từ `eutr_reference_details`
  (bảng đó không còn được feature này ghi bởi bất kỳ luồng nào — xem research Quyết định 54/57). Đây
  là dữ liệu hiển thị trực tiếp ở cột "Conditions" trên grid, mỗi phần tử 1 chip (FR-005/FR-006).

### `POST /api/eutr-documents/list-po-references` — GIỮ NGUYÊN, không xóa (spec Update 8, FR-037/FR-038)

Endpoint này ban đầu chỉ phục vụ bảng "List PO" trên trang Add cũ (Screen1, nay đã xóa) — nhưng
**KHÔNG bị xóa ở Update 19** vì feature khác trong cùng SPA (`eutr-sales-orders/
ViewSalesOrderPage.jsx`, mục Template Checklist) vẫn gọi endpoint này qua `GetEutrDocumentsPoReferencesUseCase`
để suy diễn trạng thái "đã map" theo mã PO. Phát hiện khi implement (build thất bại lúc thử xóa theo
kế hoạch ban đầu) — đã khôi phục nguyên vẹn contract/DTO, không đổi shape. Trong `004-eutr-documents`,
không còn màn hình nào gọi endpoint này nữa (List PO/trang Add cũ đã xóa) — chỉ còn được gọi từ ngoài
phạm vi feature.

## FilterRequest (cho get-all)

```json
{ "column": "Name", "operator": "like", "value": "giao nhan" }
```

- Toán tử hỗ trợ: `like`, `between` (`"a,b"`), `in` (`"1,2,3"`), `>=`, `<=`, `>`, `<`, `=`.
- Cột lọc/sắp xếp hợp lệ: `Id`, `Name`, `ValidFrom`, `ValidTo`, `CreatedBy`, `CreatedDate`,
  `UpdatedBy`, `UpdatedDate` (whitelist mặc định của repository generic — không cần whitelist
  tùy biến vì không có cột dẫn xuất/JOIN nào).
- **(Update 21)** 3 tên `Column` **ảo**, chỉ có ý nghĩa ở endpoint #2 (`get-all`) — không thuộc
  whitelist của repository generic (bị `EutrDocumentsService.GetPagedAsync` rút ra và diễn giải riêng
  trước khi gọi repository, xem `data-model.md`):
  - `"TypeId"` (`operator` bất kỳ, `value` = `Id` của `eutr_reference_types` đang chọn ở dropdown Type
    của search box) — khớp document có ≥1 bản ghi `eutr_references.RefType` bằng giá trị này.
  - `"StepId"` (`value` = `Id` của `eutr_steps` đang chọn ở dropdown Step name) — khớp document có
    ≥1 bản ghi `eutr_references.StepId` bằng giá trị này.
  - `"Conditions"` (`value` = chuỗi tự do người dùng nhập) — khớp document có ≥1 bản ghi
    `eutr_references.RefValue` chứa (không phân biệt hoa/thường) chuỗi này.
  - Cả 3 kết hợp theo AND (khi cùng xuất hiện) nhưng **mỗi điều kiện độc lập** — không bắt buộc khớp
    trên cùng một bản ghi `eutr_references` của document đó (research Quyết định 63).

## Ánh xạ frontend (eutrDocumentsApi.js)

| Use case | Hàm api | Endpoint |
|----------|---------|----------|
| GetPagingEutrDocuments | `getAllPaging(page,pageSize,sortColumn,sortOrder,payload)` | POST `/eutr-documents/get-all` |
| (by id) | `getById(id)` | GET `/eutr-documents/get-by-id/{id}` |
| CreateEutrDocuments | `create(data)` | POST `/eutr-documents` |
| UpdateEutrDocuments | `update(id,data)` | PUT `/eutr-documents/{id}` |
| DeleteEutrDocuments | `delete(id)` | DELETE `/eutr-documents/{id}` |
| DeleteMultiEutrDocuments | `deleteMulti(ids)` | POST `/eutr-documents/delete-multi` |
| (Update 10) GetEutrDocumentsFileByIdRef | `getFileByIdRef(fileId)` | GET `/eutr-documents/get-file-by-idref?idRef={fileId}` |
| (Update 19 — đổi tên từ `UpdateEutrDocumentPoStepUseCase`; Update 22 thêm tham số `refValues`) UpdateEutrDocumentReferenceStep | `updateReferenceStep(id,stepId,refValues?)` | PUT `/eutr-documents/{id}/step` |
| (Update 19) UploadEutrFilesMulti (`ISharePointRepository`, Type="PO") | `uploadEutrFilesMulti(files,poCode,typeId,validFrom,validTo)` | POST `/sharepoint/eutr-upload-multi` |
| (Update 19) UploadEutrFilesMultiByType (`ISharePointRepository`, Type khác) | `uploadEutrFilesMultiByType(files,typeId,typeName,stepId,refValues,validFrom,validTo)` | POST `/sharepoint/eutr-upload-multi-by-type` |
| (Update 8 — **giữ nguyên**, dùng bởi feature `eutr-sales-orders`) GetEutrDocumentsPoReferences | `getPoReferences(poCodes)` | POST `/eutr-documents/list-po-references` |

> **(Update 21)** Search box KHÔNG có use case/API client mới — `handleSearch` (`index.jsx`) gọi lại
> đúng `getAllPaging(...)` hiện có ở trên, chỉ thêm tối đa 3 phần tử `TypeId`/`StepId`/`Conditions`
> vào tham số `payload` (filters) đã có; dropdown Type/Step name của search box tái dùng
> `GetEutrReferenceTypesUseCase`/`GetEutrStepsUseCase` (đã dùng ở popup Add, xem trên).
>
> **Đã xóa kể từ Update 19** (cùng research Quyết định 57): `GetEutrDocumentsUnassigned`
> (`getUnassigned`), `AssignEutrConditions` (`assignConditions`), `GetEutrDocumentConditionAssignment`
> (`getConditionAssignment`), `UpdateEutrConditionAssignment` (`updateConditionAssignment`),
> `UploadEutrManualFilesMulti` (`uploadEutrManualFilesMulti` → `POST /sharepoint/
> eutr-upload-manual-multi`). `GetEutrDocumentsPoReferences`/`getPoReferences` **KHÔNG bị xóa** (khác
> dự kiến ban đầu) — xem ghi chú Update 19 phía trên.
