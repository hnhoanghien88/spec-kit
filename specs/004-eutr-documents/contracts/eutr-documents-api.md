# API Contract: EUTR Documents (MỚI — cần tạo)

Đích: `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrDocumentsController.cs` (clone mẫu
`EutrStepsController`, bỏ endpoint `GET` all-list vì không có màn hình nào khác cần nạp
`eutr-documents` làm select box). Base route: `api/eutr-documents`. Tất cả endpoint yêu cầu
`[Authorize]` + policy tương ứng. Bao bọc phản hồi: `ApiResponse<T>` (`{ data, message, success }`).

| # | Method | Path | Policy | Body / Params | Trả về |
|---|--------|------|--------|---------------|--------|
| 1 | GET | `/api/eutr-documents/get-by-id/{id}` | `EutrDocuments.ReadOne` | — | `EutrDocumentsResponseDto` |
| 2 | POST | `/api/eutr-documents/get-all` | `EutrDocuments.ReadAll` | query: `page,pageSize,sortColumn,sortOrder`; body: `List<FilterRequest>` | `PagedResult<EutrDocumentsResponseDto>` |
| 3 | POST | `/api/eutr-documents` | `EutrDocuments.Create` | `EutrDocumentsRequestDto { name, validFrom, validTo }` | `long` (id mới) |
| 4 | PUT | `/api/eutr-documents/{id}` | `EutrDocuments.Update` | `EutrDocumentsRequestDto { name, validFrom, validTo }` | message |
| 5 | DELETE | `/api/eutr-documents/{id}` | `EutrDocuments.Delete` | — | message |
| 6 | POST | `/api/eutr-documents/delete-multi` | `EutrDocuments.Delete` | `IEnumerable<long> ids` | message |
| 7 | GET | `/api/eutr-documents/get-file-by-idref` | `EutrDocuments.ReadOne` | query: `idRef` (= `FileId`) | `SharepointFileContent` (`{ content, contentType, fileName }`) |

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
| POST | `/api/sharepoint/eutr-upload-multi` | `[Authorize]` (chung với các action khác của `SharePointController`, không có policy riêng) | `multipart/form-data` | `files`: 1+ file; `poCode`: string (mã PO đang chọn ở List PO) | `ApiResponse<List<EutrUploadFileResultDto>>` |

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
  "refType": null
}
```

- `fileId` luôn `null` cho bản ghi tạo qua form Save (Add chưa có input file); có giá trị cho bản
  ghi tạo qua nút Upload (Update 6/7).
- `stepNames`/`refType`: **mới, kể từ Update 8** — nạp bằng cách JOIN `eutr_references`/`eutr_steps`
  theo `DocumentId` (xem `data-model.md`, research Quyết định 20). `[]`/`null` cho document không có
  bản ghi `eutr_references` nào (ví dụ document tạo qua form Save nhập tay) — frontend map `refType`
  sang nhãn hiển thị qua `TAKE_FROM_OPTIONS`.
- Không có `conditions` trong response — cột này chỉ tồn tại ở phía grid frontend và luôn hiển thị
  trống (không đổi bởi Update 8, xem FR-003/FR-036).

## `POST /api/eutr-documents/list-po-references` (spec Update 8, FR-037/FR-038) — endpoint MỚI

| Method | Path | Policy | Body | Trả về |
|---|---|---|---|---|
| POST | `/api/eutr-documents/list-po-references` | `EutrDocuments.ReadAll` (dùng chung, không thêm policy mới) | `EutrDocumentsListPoReferencesRequestDto { poCodes: string[] }` | `ApiResponse<List<EutrDocumentsPoReferenceDto>>` |

- Request: `{ "poCodes": ["PO000123"] }` — frontend chỉ gửi mã PO đang được chọn ở List PO (xem
  research Quyết định 22), nhưng endpoint hỗ trợ nhiều mã trong 1 lần gọi.
- Response ví dụ:
  ```json
  {
    "success": true,
    "message": "OK",
    "data": [
      {
        "poCode": "PO000123",
        "documents": [
          { "documentId": 501, "fileId": "01ABCXYZ...", "fileName": "INV2026_hop-dong-po123.pdf", "stepNames": ["Bước kiểm tra hóa đơn"] }
        ]
      }
    ]
  }
  ```
- `documents: []` khi PO đó chưa có bản ghi `eutr_references` nào — frontend hiển thị "No data",
  không phải lỗi.
- **(Update 10)** Field `fileId` được thêm vào mỗi item của `documents[]` — dùng cho icon View
  (mở popup xem trước qua `GET get-file-by-idref?idRef={fileId}`) và icon Delete (xóa qua
  `DELETE /eutr-documents/{documentId}` hiện có) theo từng file trên bảng List PO, xem FR-043/FR-044.
- Nguồn dữ liệu và cấu trúc DTO chi tiết: xem `data-model.md` (mục "Nạp File name/Step name cho
  List PO...") và research Quyết định 21/28.

## FilterRequest (cho get-all)

```json
{ "column": "Name", "operator": "like", "value": "giao nhan" }
```

- Toán tử hỗ trợ: `like`, `between` (`"a,b"`), `in` (`"1,2,3"`), `>=`, `<=`, `>`, `<`, `=`.
- Cột lọc/sắp xếp hợp lệ: `Id`, `Name`, `ValidFrom`, `ValidTo`, `CreatedBy`, `CreatedDate`,
  `UpdatedBy`, `UpdatedDate` (whitelist mặc định của repository generic — không cần whitelist
  tùy biến vì không có cột dẫn xuất/JOIN nào).

## Ánh xạ frontend (eutrDocumentsApi.js)

| Use case | Hàm api | Endpoint |
|----------|---------|----------|
| GetPagingEutrDocuments | `getAllPaging(page,pageSize,sortColumn,sortOrder,payload)` | POST `/eutr-documents/get-all` |
| (by id) | `getById(id)` | GET `/eutr-documents/get-by-id/{id}` |
| CreateEutrDocuments | `create(data)` | POST `/eutr-documents` |
| UpdateEutrDocuments | `update(id,data)` | PUT `/eutr-documents/{id}` |
| DeleteEutrDocuments | `delete(id)` | DELETE `/eutr-documents/{id}` |
| DeleteMultiEutrDocuments | `deleteMulti(ids)` | POST `/eutr-documents/delete-multi` |
| (Update 8) GetEutrDocumentsPoReferences | `getPoReferences(poCodes)` | POST `/eutr-documents/list-po-references` |
| (Update 10) GetEutrDocumentsFileByIdRef | `getFileByIdRef(fileId)` | GET `/eutr-documents/get-file-by-idref?idRef={fileId}` |
