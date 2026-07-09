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
          { "documentId": 501, "fileName": "INV2026_hop-dong-po123.pdf", "stepNames": ["Bước kiểm tra hóa đơn"] }
        ]
      }
    ]
  }
  ```
- `documents: []` khi PO đó chưa có bản ghi `eutr_references` nào — frontend hiển thị "No data",
  không phải lỗi.
- Nguồn dữ liệu và cấu trúc DTO chi tiết: xem `data-model.md` (mục "Nạp File name/Step name cho
  List PO...") và research Quyết định 21.

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
