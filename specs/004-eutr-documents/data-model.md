# Data Model: EUTR Documents

## Thực thể: EutrDocuments (bảng `eutr_documents`)

Nguồn sự thật DB: `docs/design/eutr/eutr_db.sql`. Entity backend mới:
`compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrDocuments.cs` (kế thừa `BaseEntity`).

| Trường | Kiểu | Nguồn | Ghi chú |
|--------|------|-------|---------|
| `Id` | long (BIGINT UNSIGNED) | DB | Khóa chính, auto-increment, chỉ đọc |
| `Name` | string? (VARCHAR(255) sau migration) | Người dùng nhập **hoặc** tên file gốc khi tạo qua Upload (Update 6) | **Bắt buộc, không rỗng** — hiển thị ở grid là "File name". Hiện là BIGINT trong schema thật → **MUST migrate** (xem research Quyết định 3) |
| `FileId` | string? (VARCHAR(255)) | **(Update 6)** id file trả về từ SharePoint khi tạo qua nút Upload | Tồn tại sẵn trong schema. Document tạo qua form Save (File name/Valid from/Valid to nhập tay) vẫn luôn `null`; document tạo qua nút Upload (Screen1, FR-029) MUST được gán giá trị này |
| `ValidFrom` | DateTime? (DATE) | Người dùng nhập, hoặc **ngày hiện tại** khi tạo qua Upload (Update 6) | Tùy chọn khi nhập tay; bắt buộc = hôm nay khi qua Upload |
| `ValidTo` | DateTime? (DATE) | Người dùng nhập, hoặc **`9999-12-31`** (sentinel "không giới hạn") khi tạo qua Upload (Update 6) | Tùy chọn khi nhập tay; cố định sentinel khi qua Upload |
| `CreatedBy` | string | Hệ thống | Ghi tự động từ user đăng nhập |
| `CreatedDate` | datetime | Hệ thống | Ghi tự động |
| `UpdatedBy` | string | Hệ thống | Ghi tự động khi sửa |
| `UpdatedDate` | datetime | Hệ thống | Ghi tự động khi sửa |

## Trường chỉ hiển thị trên grid — Conditions luôn trống; Step name/Type nạp qua `eutr_references` (Update 8)

| Trường (frontend) | Nguồn | Ghi chú |
|---|---|---|
| `stepName` | **(Update 8)** `EutrDocumentsResponseDto.StepNames` (`List<string>`, mới) | Cột "Step name" — JOIN `eutr_references.StepId` → `eutr_steps.Name` theo `DocumentId` (FR-034); nhiều giá trị hiển thị qua `MultiValueChips` (xem mục dưới) |
| `conditions` | Không có | Cột "Conditions" — vẫn không map field nào, luôn hiển thị trống (FR-003/FR-036, không đổi) |
| `type` | **(Update 8)** `EutrDocumentsResponseDto.RefType` (`byte?`, mới) | Cột "Type" — frontend map giá trị này qua hằng số có sẵn `TAKE_FROM_OPTIONS` để lấy nhãn ("PO"/"Upload manual") (FR-034); `null` khi document không có bản ghi `eutr_references` nào |

Cột Conditions tương ứng dữ liệu vốn nằm ở `eutr_template_details` (qua `TakeFrom`) trong thiết kế
tổng thể, nhưng **không được liên kết** trong phạm vi feature `004-eutr-documents` — xem
Assumptions trong `spec.md`. Step name/Type **đã được liên kết** kể từ Update 8 (xem mục "Nạp Step
name/Type..." bên dưới) — không còn thuộc nhóm "luôn trống" này.

## Xem file thật qua icon View (spec Update 10, FR-041/FR-042) — endpoint MỚI trong `EutrDocumentsController`

### `GET /api/eutr-documents/get-file-by-idref` (request)

Query string: `idRef` = `FileId` của một `eutr_documents` (ví dụ `?idRef=01ABCXYZ...`). Clone
nguyên vẹn logic của `ComplCompliancesController.GetFileByIds` (`[HttpGet("get-file-by-idref")]`)
— cùng gọi `ISharepointService.ReadFileWithMetaAsync(idRef)`, cùng retry 1 lần khi gặp
`HttpRequestException(ServiceUnavailable)`, cùng `500`/`503` khi lỗi. `EutrDocumentsController`
nhận thêm `ISharepointService _sharepointService` qua constructor (không qua Application service
trung gian — cùng cách `ComplCompliancesController`/`SharePointController` đã làm, xem research
Quyết định 25).

### `SharepointFileContent` (response, kiểu có sẵn từ `Shared.ExternalServices.Models.Sharepoint`)

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

- Document không có `FileId` (`null`) — frontend KHÔNG gọi endpoint này (icon View đã bị vô hiệu
  hóa từ trước, xem FR-042), nên không có kịch bản `idRef = null`/rỗng cần xử lý ở backend cho
  luồng UI này.
- Đây là lời gọi **read-only**, không ghi/đổi dữ liệu nào trên `eutr_documents`/SharePoint.
- Policy: `EutrDocuments.ReadOne` (dùng chung với `GET get-by-id/{id}` — cùng ngữ nghĩa "xem 1
  document", không thêm policy mới).

### Bổ sung `FileId` vào chuỗi dữ liệu List PO (spec Update 10, FR-043/FR-044)

Để icon View/Delete theo từng file ở bảng List PO (trang Add) hoạt động, `FileId` (đã tồn tại trên
`eutr_documents`, xem bảng entity ở trên) MUST được nạp thêm vào 2 nơi hiện có (không migration DB
mới — cột đã tồn tại từ đầu):

- `EutrReferencePoDocumentInfo` (projection, `ComplianceSys.Application/Dtos/Response/`): thêm
  `public string? FileId { get; set; }`.
- SQL trong `EutrReferencesRepository.GetDocumentsByPoCodesAsync` (xem mục
  `EutrReferencesRepository` dưới): thêm `d.FileId AS FileId` vào `SELECT`.
- `EutrDocumentsPoReferenceItemDto` (response item của `list-po-references`): thêm
  `public string? FileId { get; set; }`; `EutrDocumentsService.GetPoReferencesAsync` gán
  `FileId = g.First().FileId` khi dựng từng item (giống nhau trên mọi bản ghi cùng `DocumentId`,
  vì `FileId` thuộc về document, không thuộc về từng dòng `eutr_references`).
- Ví dụ response `list-po-references` sau khi bổ sung:
  ```json
  { "documentId": 501, "fileId": "01ABCXYZ...", "fileName": "INV2026_hop-dong-po123.pdf", "stepNames": ["Bước kiểm tra hóa đơn"] }
  ```
- Document tạo qua Upload (Update 6/7) luôn có `FileId` — mọi dòng trong `poReferenceDocuments` (đến
  từ `eutr_references` với `RefType=0`, chỉ được ghi bởi luồng Upload) MUST có `fileId` khác `null`;
  không có kịch bản `fileId = null` cần xử lý riêng ở bảng List PO (khác với danh sách chính, nơi
  document tạo qua Save/không upload vẫn xuất hiện và cần disable icon View).

### Frontend: tái dùng cấu trúc "1 dòng = 1 document" đã có (research Quyết định 28) — không đổi cấu trúc UI

Bảng chi tiết List PO (`EutrDocumentsAdd.jsx`, Grid size=5) từ Update 8 đã render 1 `TableRow` cho
mỗi `doc` trong `poReferenceDocuments` — đúng granularity "theo từng file" mà clarify Update 10 chọn
(xem Clarifications trong `spec.md`). Update 10 chỉ đổi hành vi 2 icon đã có sẵn trên mỗi dòng,
không thêm/xóa dòng hay cột nào:

- Icon **View**: `onClick` mở `EutrFileViewerDialog` với `{ fileId: doc.fileId, fileName:
  doc.fileName }` (thay `onClick={() => {}}`); `disabled` không cần thiết vì mọi `doc` ở đây luôn
  có `fileId` (xem trên).
- Icon **Delete**: `onClick` mở `ConfirmDialog`, xác nhận thì gọi
  `deleteEutrDocumentsUseCase.execute(doc.documentId)` (dùng lại `DeleteEutrDocumentsUseCase` đã có
  — chính là API đã xử lý dọn `eutr_references` từ Update 9), sau đó refetch
  `poReferenceDocuments` của PO đang chọn (gọi lại logic ở `useEffect` theo `selectedPoId`, research
  Quyết định 22) để dòng vừa xóa biến mất khỏi bảng ngay lập tức.
- KHÔNG gọi bất kỳ API xóa file SharePoint nào (ví dụ `POST /api/sharepoint/delete-file` đã tồn tại
  sẵn cho mục đích khác) — file thật trên SharePoint được giữ lại nguyên vẹn, đúng quyết định đã
  chốt ở clarify Update 10.

## Nạp Step name/Type cho danh sách EUTR documents (spec Update 8, FR-034/FR-035)

Mở rộng `EutrDocumentsResponseDto` (2 field mới, không đổi entity `EutrDocuments`/bảng
`eutr_documents`):

```json
{
  "id": 501, "name": "INV2026_hop-dong-po123.pdf", "fileId": "01ABCXYZ...",
  "validFrom": "2026-07-09T00:00:00", "validTo": "9999-12-31T00:00:00",
  "createdBy": "hien", "createdDate": "2026-07-09T03:00:00Z",
  "updatedBy": null, "updatedDate": null,
  "stepNames": ["Bước kiểm tra hóa đơn", "Bước xác minh nguồn gốc"],
  "refType": 0,
  "typeName": "PO"
}
```

- `stepNames`: `List<string>` — tên các Step (JOIN `eutr_steps.Name` theo `StepId`) của mọi bản ghi
  `eutr_references` có `DocumentId` = `Id` của document này; `[]` nếu không có bản ghi nào.
- `refType`: `byte?` — giá trị `RefType` của các bản ghi đó (giống nhau trên mọi bản ghi cùng
  `DocumentId`, theo FR-033/Update 7); `null` nếu không có bản ghi nào. **Trước Update 14**: frontend
  map giá trị này sang nhãn hiển thị qua hằng số `TAKE_FROM_OPTIONS`. **Kể từ Update 14**: `refType`
  vẫn được trả về (dùng để Edit rẽ nhánh popup theo Type, FR-055/FR-056) nhưng KHÔNG còn dùng để suy
  ra nhãn hiển thị cột Type — xem field `typeName` mới ngay dưới.
- `typeName` (`string?`, **mới, kể từ Update 14, FR-034**): nhãn Type đã tính sẵn ở backend — JOIN
  `RefType` với `eutr_reference_types.Id`, trả `Name` của bản ghi khớp (bảng quản lý CRUD bởi feature
  `006-eutr-reference-types`, xem research Quyết định 41). `null` khi document không có bản ghi
  `eutr_references` nào, hoặc `RefType` không khớp bất kỳ bản ghi `eutr_reference_types` nào. Đây là
  thay đổi duy nhất khiến "PO name ở List PO" (backend trả mã, frontend map nhãn) không còn là quy
  tắc chung cho MỌI nhãn tham chiếu trong feature này — cột Type nay là ngoại lệ có chủ đích, vì nhãn
  của nó đến từ một bảng CRUD được người dùng quản lý trực tiếp (`eutr_reference_types`), không phải
  một hằng số cố định trong code.
- Nguồn dữ liệu: `EutrReferencesRepository.GetStepInfoByDocumentIdsAsync(documentIds)` (SQL JOIN
  `eutr_references`+`eutr_steps`, `WHERE DocumentId IN @DocumentIds`) — xem research Quyết định 20.
  **Kể từ Update 14**, câu SQL này JOIN thêm `eutr_reference_types` (`LEFT JOIN eutr_reference_types
  t ON t.Id = r.RefType`) để lấy `t.Name AS TypeName` (research Quyết định 41).
  `EutrDocumentsService.GetPagedAsync` gọi method này với `Id` của mọi document trong trang hiện
  tại, group theo `DocumentId`, rồi gán vào `StepNames`/`RefType`/`TypeName` của từng
  `EutrDocumentsResponseDto` tương ứng — clone mẫu `ComplCountryGroupService.AttachMembersAsync`.

## Nạp File name/Step name cho List PO trên trang Add (spec Update 8, FR-037/FR-038) — endpoint MỚI trong `EutrDocumentsController`

### `EutrDocumentsListPoReferencesRequestDto` (request)

```json
{ "poCodes": ["PO000123"] }
```

- `poCodes`: `List<string>`, mã PO cần tra cứu — frontend chỉ gửi PO đang được chọn ở List PO
  (`[selectedPo.code]`, xem research Quyết định 22), nhưng backend hỗ trợ nhận nhiều mã trong 1 lần
  gọi (không giới hạn số lượng ở phạm vi feature này).

### `EutrDocumentsPoReferenceDto` (response item, cho mỗi PO trong request)

```json
[
  {
    "poCode": "PO000123",
    "documents": [
      { "documentId": 501, "fileId": "01ABCXYZ...", "fileName": "INV2026_hop-dong-po123.pdf", "stepNames": ["Bước kiểm tra hóa đơn"] },
      { "documentId": 508, "fileId": "01ABCDEF...", "fileName": "packing-list-po123.pdf", "stepNames": ["Bước xác minh nguồn gốc", "Bước đóng gói"] }
    ]
  }
]
```

> **Update 10**: field `fileId` được thêm vào mỗi item (xem mục "Xem file thật qua icon View" ở
> trên) — dùng để mở popup xem trước file (icon View) và xác định document cần xóa (icon Delete)
> ngay trên bảng List PO, không cần gọi thêm API nào để lấy `fileId` riêng.

- Trả về `ApiResponse<List<EutrDocumentsPoReferenceDto>>` qua
  `POST /api/eutr-documents/list-po-references` (policy `EutrDocuments.ReadAll` — dùng chung, không
  thêm policy mới).
- `documents: []` khi PO đó chưa có bản ghi `eutr_references` nào (`RefType=0`, `RefValue`=mã PO đó)
  — frontend hiển thị "No data" cho PO này, không phải lỗi.
- Mỗi phần tử `documents[]` tương ứng **một document** (`DocumentId` phân biệt) liên kết với PO đó;
  `stepNames` của từng document có thể có nhiều giá trị nếu file đó khớp Prefix của nhiều `StepId`
  phân biệt (Update 7).
- Nguồn dữ liệu: `EutrReferencesRepository.GetDocumentsByPoCodesAsync(poCodes)` (SQL JOIN
  `eutr_references`+`eutr_documents`+`eutr_steps`, `WHERE RefType=0 AND RefValue IN @PoCodes`) — xem
  research Quyết định 21. `EutrDocumentsService.GetPoReferencesAsync` group theo `PoCode` rồi theo
  `DocumentId` để dựng cấu trúc lồng nhau trên.

## `EutrReferencesRepository` — repository MỚI, chỉ đọc (spec Update 8)

`eutr_references` từ Update 7 chỉ có đường **ghi** (qua `IRepository<EutrReferences,long>` generic,
trong `EutrUploadService`). Update 8 bổ sung đường **đọc** — 2 method mới, cả hai đều
`DapperRepository<EutrReferences,long>` subclass (clone mẫu `EutrMastersRepository`, chỉ nhận
`IUnitOfWork` qua constructor, không có state khác):

```csharp
public interface IEutrReferencesRepository
{
    Task<List<EutrReferenceStepInfo>> GetStepInfoByDocumentIdsAsync(
        IEnumerable<long> documentIds, CancellationToken ct = default);

    Task<List<EutrReferencePoDocumentInfo>> GetDocumentsByPoCodesAsync(
        IEnumerable<string> poCodes, CancellationToken ct = default);
}
```

- `EutrReferenceStepInfo { long DocumentId; string? StepName; byte? RefType; long ReferenceId;
  long? StepId; string? TypeName; }` — projection phẳng, không phải entity `EutrReferences` đầy đủ
  (không cần `Id`/`RefId`/`RefValue` cho mục đích này). `ReferenceId`/`StepId` được thêm ở Update 13
  (suy ra `StepId` "hiện tại" theo `Id` nhỏ nhất, FR-055); `TypeName` **mới, kể từ Update 14** — JOIN
  thêm `eutr_reference_types` (`LEFT JOIN eutr_reference_types t ON t.Id = r.RefType`), lấy `t.Name`.
- `EutrReferencePoDocumentInfo { string PoCode; long DocumentId; string? FileId; string? FileName; string? StepName; }`
  — projection phẳng tương tự, service group thành cấu trúc lồng nhau ở trên. **(Update 10)**: thêm
  `FileId` (JOIN cùng `d.FileId` như `d.Name`/`FileName`) để icon View/Delete theo từng file ở List
  PO có đủ dữ liệu, không cần lời gọi API riêng.
- Đăng ký DI: `services.AddScoped<IEutrReferencesRepository, EutrReferencesRepository>();` trong
  `ComplianceSys.Infrastructure/DependencyInjection.cs` (cạnh dòng đăng ký `IEutrMastersRepository`
  đã có). Không ảnh hưởng đường ghi hiện có (`IRepository<EutrReferences,long>` generic vẫn hoạt
  động độc lập, không đổi).
- Không có migration DB mới — mọi cột cần (`DocumentId`, `StepId`, `RefType`, `RefValue` trên
  `eutr_references`; `Name` trên `eutr_steps`/`eutr_documents`) đã tồn tại từ Update 7.

## Xóa `eutr_references` khi xóa document (spec Update 9, FR-039/FR-040)

`eutr_references` từ Update 7 chỉ có đường **ghi thêm** (`AddAsync` qua
`IRepository<EutrReferences,long>` generic trong `EutrUploadService`) và từ Update 8 có đường
**đọc** (`EutrReferencesRepository`, 2 method JOIN). Update 9 bổ sung đường **xóa** — 1 method mới
trên `IEutrReferencesRepository` (cạnh 2 method đọc hiện có, xem mục trên):

```csharp
Task DeleteByDocumentIdAsync(long documentId, CancellationToken ct = default);
```

Implement trong `EutrReferencesRepository` (raw SQL, cùng style `Connection.ExecuteAsync` +
`CommandDefinition` đã dùng ở 2 method đọc):

```sql
DELETE FROM eutr_references WHERE DocumentId = @DocumentId;
```

- Xóa **toàn bộ** dòng khớp `DocumentId`, không phân biệt số lượng (0, 1, hoặc nhiều `StepId` khác
  nhau) hay `RefType`.
- Vì `EutrReferencesRepository` nhận cùng `IUnitOfWork` (scoped) với `EutrDocumentsService`, câu
  `DELETE` này tự động chạy trong transaction mà `EutrDocumentsService` đã mở qua
  `_unitOfWork.BeginTransactionAsync(...)` — không cần tham số transaction riêng.

### `EutrDocumentsService.DeleteAsync`/`DeleteMultiAsync` — override, KHÔNG sửa `IBaseService` (research Quyết định 24)

`EutrDocumentsService` hiện dùng nguyên `DeleteAsync`/`DeleteMultiAsync` của
`BaseService<EutrDocuments,long,EutrDocumentsRequestDto>` (không override). Update 9 thêm override
cho cả hai, trong cùng file `EutrDocumentsService.cs`:

```csharp
public override async Task DeleteAsync(long id, string userEmail, CancellationToken ct = default)
{
    ArgumentException.ThrowIfNullOrWhiteSpace(userEmail);

    var existing = await _repository.GetByIdAsync(id, ct);
    if (existing == null)
        throw new KeyNotFoundException($"EutrDocuments with id {id} not found.");

    try
    {
        await _unitOfWork.BeginTransactionAsync(IsolationLevel.ReadCommitted);

        // Update 9 (FR-039): xoa het eutr_references lien quan truoc, cung transaction voi
        // viec xoa eutr_documents - khong de lai ban ghi mo coi.
        await _referencesRepository.DeleteByDocumentIdAsync(id, ct);
        await _repository.DeleteAsync(id, ct);

        await _unitOfWork.CommitAsync();
    }
    catch (Exception)
    {
        await _unitOfWork.RollbackAsync();
        throw;
    }
}

public override async Task DeleteMultiAsync(IEnumerable<long> ids, CancellationToken ct = default)
{
    var idList = ids?.ToList() ?? [];
    if (idList.Count == 0)
        throw new ArgumentException("Ids cannot be null or empty", nameof(ids));

    // Update 9 (FR-040): moi document 1 transaction rieng (KHAC BaseService.DeleteMultiAsync
    // dung 1 transaction chung ca batch) - loi o 1 document khong chan cac document khac.
    var failures = new List<string>();
    foreach (var id in idList)
    {
        try
        {
            await _unitOfWork.BeginTransactionAsync(IsolationLevel.ReadCommitted);
            await _referencesRepository.DeleteByDocumentIdAsync(id, ct);
            await _repository.DeleteAsync(id, ct);
            await _unitOfWork.CommitAsync();
        }
        catch (Exception ex)
        {
            await _unitOfWork.RollbackAsync();
            failures.Add($"Id={id}: {ex.Message}");
        }
    }

    if (failures.Count > 0)
        throw new InvalidOperationException(
            $"Failed to delete {failures.Count} document(s): {string.Join("; ", failures)}");
}
```

- `EutrDocumentsService` cần thêm 1 field riêng `private readonly IUnitOfWork _unitOfWork;` (constructor
  đã nhận `unitOfWork` từ trước — trước Update 9 chỉ truyền cho `base(...)`, không giữ lại).
- Document không có `eutr_references` nào liên kết: `DeleteByDocumentIdAsync` chạy, xóa 0 dòng,
  không phải lỗi — `DeleteAsync`/`DeleteMultiAsync` tiếp tục xóa `eutr_documents` như bình thường.
- `DeleteMultiAsync`: các id xóa thành công **trước** id gặp lỗi vẫn giữ trạng thái đã xóa (mỗi vòng
  lặp `CommitAsync()` độc lập) — exception tổng hợp ném ra **sau** vòng lặp chỉ báo lỗi cho client,
  không rollback các transaction đã commit trước đó.
- Không đổi `IBaseService`/`IEutrDocumentsService` — chữ ký `DeleteAsync`/`DeleteMultiAsync` giữ
  nguyên (`Task`, không trả kết quả per-item); không đổi `EutrDocumentsController`,
  `DELETE /api/eutr-documents/{id}`, `POST /api/eutr-documents/delete-multi` (path/request/response
  không đổi — chỉ hành vi nội bộ thay đổi). Lỗi (kể cả `InvalidOperationException` tổng hợp của
  `DeleteMultiAsync`) tiếp tục được middleware xử lý exception hiện có của hệ thống chuyển thành
  `ApiResponse.Fail(...)`, cùng cơ chế đã áp dụng cho `KeyNotFoundException` ở `Delete` đơn từ
  trước — không cần thêm xử lý riêng ở Controller.

## Quy tắc nghiệp vụ (validation)

- `Name` (File name) bắt buộc, không rỗng/chỉ khoảng trắng → chặn ở form (Add page + Edit popup)
  + FluentValidation ở backend (FR-007, FR-010).
- `ValidFrom`, `ValidTo`: **không bắt buộc**, không có ràng buộc so sánh giữa hai giá trị (spec
  không yêu cầu).
- **Không có ràng buộc duy nhất** trên `Name` — nhiều document được phép trùng File name
  (FR-007b). Không có unique index, không có kiểm tra service-side.
- `FileId` không có input nào trong UI cho form Save/Edit (`api/eutr-documents`) → luôn `null` cho
  document tạo/sửa qua đường này. **(Update 6)** Document tạo qua nút Upload (`api/sharepoint/
  eutr-upload-multi`) là đường ghi dữ liệu **khác**, đi thẳng qua `IRepository<EutrDocuments,long>`
  (không qua `EutrDocumentsRequestDto`/`IEutrDocumentsService.AddAsync`) — `FileId` MUST được gán
  giá trị SharePoint trả về, `Name` = tên file gốc, `ValidFrom`/`ValidTo` do hệ thống tự tính (xem
  bảng trên). Document tạo theo đường này **không có bước validate trùng/chỉnh sửa qua UI Edit
  popup** khác với document tạo qua Save — vẫn hiển thị và Edit/Delete được bình thường ở danh sách
  chung (User Story 1/3/4) vì cùng nằm trên bảng `eutr_documents`.
- `Id` không sửa được; Update gửi qua URL `PUT /eutr-documents/{id}`.
- Xóa là **hard delete** thật (không có cờ `IsDeleted`/`IsHide` trong schema `eutr_documents`).
  **(Update 9)** Xóa MUST kèm dọn toàn bộ `eutr_references` có `DocumentId` = document bị xóa —
  xem mục "Xóa `eutr_references` khi xóa document" dưới đây.

## Đối tượng truyền (frontend ↔ backend)

- **Tạo/Sửa (request)** — `EutrDocumentsRequestDto`: `{ name, validFrom, validTo }` (Update kèm
  `id` ở URL). Không có `fileId` trong request DTO (chưa có input file).
- **Phản hồi danh sách (get-all)**: `PagedResult<EutrDocumentsResponseDto>` →
  `{ items: [{ id, name, fileId, validFrom, validTo, createdBy, createdDate, updatedBy, updatedDate }], totalCount }`.
  (`fileId` sẽ luôn `null` cho các bản ghi tạo qua feature này, nhưng field vẫn tồn tại trên
  entity/DTO để phản ánh đúng schema DB).
- **Xóa nhiều**: mảng `ids` (number[]) → `POST /eutr-documents/delete-multi`.

## Quan hệ

- `EutrDocuments` không có khóa ngoại tới bảng nào khác (khác `eutr-masters` có FK `StepId`). Bảng
  `eutr_documents` trong thiết kế tổng thể được `eutr_references.DocumentId` tham chiếu tới (không
  có FK ràng buộc chiều ngược — `eutr_references.DocumentId` mới là bên có FK trỏ tới
  `eutr_documents.Id`, xem `eutr_db.sql`). **Kể từ Update 8**, feature này đọc (JOIN, read-only)
  liên kết này qua `EutrReferencesRepository` để nạp Step name/Type (danh sách) và File name/Step
  name (List PO) — xem 2 mục ở trên. Feature vẫn chỉ CRUD trực tiếp bảng `eutr_documents`; việc ghi
  vào `eutr_references` tiếp tục thuộc về `EutrUploadService` (Update 7), không đổi bởi Update 8.
- **Kể từ Update 14**: `eutr_references.RefType` có ràng buộc khóa ngoại tới `eutr_reference_types.Id`
  (`eutr_references_reftype_foreign`, theo `docs/design/eutr/eutr_db.sql`). Feature này đọc (JOIN,
  read-only) thêm bảng `eutr_reference_types` — quản lý CRUD hoàn toàn bởi feature
  `006-eutr-reference-types` — để nạp nhãn hiển thị cột Type (`typeName`, xem mục trên). Feature này
  KHÔNG tạo/sửa/xóa bản ghi nào trong `eutr_reference_types`.

## Trạng thái chỉ-giao-diện trên trang Add (Type/List PO/Manual) — KHÔNG có entity/DTO

Bổ sung theo `docs/design/eutr/eutr_documents_overview.md`, ở phạm vi **chỉ giao diện** (spec
Session Update 3, FR-016 đến FR-020):

| Trường (chỉ UI, local state) | Giá trị | Ghi chú |
|---|---|---|
| `takeFrom` | `0` ("PO") \| `1` ("Upload manual"), mặc định `0` | State cục bộ trong `EutrDocumentsAdd.jsx` (`useState`), giá trị lấy từ hằng số có sẵn `TAKE_FROM_OPTIONS` (`@utils/helpers`) — KHÔNG gửi lên backend, KHÔNG có trong `EutrDocumentsRequestDto` |
| `demoFileList` | Mảng tĩnh hard-code 8 dòng `{ fileName: "File 1".."File 8" }` (Screen2) | Hằng số trong component, không gọi API |

> Ghi chú: `demoPoList` (dữ liệu mẫu tĩnh cho cột PO name ở Screen1) đã bị **loại bỏ khi triển khai
> Update 4** — cột PO name giờ lấy dữ liệu thật qua API reference (xem mục "Entity D365 ngoài hệ
> thống" bên dưới), không còn là state chỉ-giao-diện.

Không có thay đổi nào tới entity `EutrDocuments`, `EutrDocumentsRequestDto`/`ResponseDto`, hay
bảng `eutr_documents` — Save vẫn chỉ gửi `{ name, validFrom, validTo }` như trước (FR-020). Không
cần migration DB mới cho phần này.

## Entity D365 ngoài hệ thống (external, read-only) — List PO nối dữ liệu thật (spec Update 4)

Không phải bảng MySQL cục bộ — đọc trực tiếp qua endpoint tham chiếu dùng chung
`POST /api/dynamics/reference` (tham số `refType`), đã tồn tại từ trước (`DynController.ReferenceData`
→ `ComplDynamicsService.GetDynRefePagedAsync`). Domain model D365 đã có sẵn trong
`ComplianceSys.Domain/Dynamics/`, chỉ cần đăng ký vào `EntityMappings` (xem research Quyết định 9).

| refType | Entity D365 | Domain model (đã tồn tại) | Cột lọc (`FilterableFields`) | Dùng ở đâu trong feature này |
|---|---|---|---|---|
| **15** | `RSVNEutrPurchOrders` | `RSVNEutrPurchOrders.cs` (`ModelType = 15`) | `PurchId`, `OrderAccount`, `Name` | Cột **PO name** trong bảng List PO (Screen1, Type = PO) — FR-017, FR-021 |
| **16** | `RSVNEutrSalesOrderPurchases` | `RSVNEutrSalesOrderPurchases.cs` (`ModelType = 16`) | `RSVNRefPurchId`, `InterCompanyOriginalSalesId`, `Name`, `OrderAccount`, `Qty` | **Không dùng ở UI nào trong feature này** — chỉ đăng ký backend cho một tính năng sau — FR-022 |

Ánh xạ sang `ComplDynReferenceResponseDto` (`{ Id, Code, Name }`) trong `MapDynamicsResponse`:

- refType 15: `Id = Code = PurchId`, `Name = Name`.
- refType 16: `Id = Code = RSVNRefPurchId`, `Name = Name`.

List PO (frontend) lấy dữ liệu qua hook generic `useReferenceObjects` (đã dùng ở
`ReferenceObjectAutocomplete.jsx`) gọi `GetReferenceDataUseCase.execute(page, pageSize, sortColumn,
sortOrder, 15, filters)` → hiển thị `name` của mỗi item vào cột **PO name**. Cột **File name** vẫn
không có nguồn dữ liệu (không có field tương ứng ở `ComplDynReferenceResponseDto` hay entity D365
này) → tiếp tục hiển thị trống theo đúng hành vi trước Update 4.

### Tìm kiếm PO qua API (`filters`, spec Update 5) — không cần thay đổi mapping ở trên

Tham số `filters` trong lệnh gọi trên (`[{ column: "Name", operator: "like", value: query }, {
column: "Code", operator: "like", value: query }]`, do `useReferenceObjects` tự dựng khi có từ khóa)
được `ComplDynamicsService.BuildFilterString` ánh xạ generic sang cột thật theo đúng bảng
`EntityMappings` ở trên: cột "Code" → `mapping.CodeColumn` (`PurchId` với refType 15), cột "Name" →
`mapping.NameColumn` (`Name` với refType 15). Vì mapping cho refType 15 đã có sẵn từ Update 4, ô
tìm kiếm PO (Update 5) hoạt động đúng **mà không cần sửa bảng nào ở trên hay bất kỳ dòng code
backend nào** — chỉ là cách gọi hook ở frontend thay đổi (truyền `query` thay vì chuỗi rỗng).

## Upload nhiều file thật lên SharePoint (spec Update 6, FR-024 đến FR-030) — endpoint MỚI, ngoài `api/eutr-documents`

Không đi qua `EutrDocumentsRequestDto`/`IEutrDocumentsService` — dùng DTO và service riêng trong
cùng `SharePointController` (`api/sharepoint`), vì `EutrDocumentsRequestDto` không có field `FileId`
(xem research Quyết định 11).

### `EutrMultiUploadFileRequest` (request, `[FromForm]`, `multipart/form-data`)

```json
{ "files": ["<binary>", "<binary>"], "poCode": "PO000123", "typeId": 3 }
```

- `files`: bắt buộc ít nhất 1 file (`400` nếu rỗng, cùng validate với `upload-multi` hiện có).
- `poCode`: bắt buộc, không rỗng (`400` nếu thiếu) — giá trị `code` của PO đang chọn ở List PO
  (tương ứng `PurchId` từ `RSVNEutrPurchOrders`, refType 15).
- `typeId` *(`long?`, MỚI — spec Update 18, FR-076)*: **nullable**, KHÔNG `[Required]` — `Id` thật của
  bản ghi `eutr_reference_types` đang được chọn ở dropdown Type trong popup Add (chỉ gửi khi
  `Type.Name` = "PO"). Khi có giá trị, backend dùng trực tiếp làm `RefType` khi ghi
  `eutr_references` (FR-077, xem mục "Ghi dữ liệu" bên dưới), thay cho hằng số `PoRefType` cố định.
  Caller cũ không gửi field này (ví dụ trang Add độc lập `EutrDocumentsAdd.jsx`, Update 6) tiếp tục
  không bị ảnh hưởng — backend giữ nguyên hằng số cũ khi `typeId` vắng mặt (research Quyết định 52).

### `EutrUploadFileResultDto` (response item, cho mỗi file trong request)

```json
[
  { "fileName": "hop-dong-po123.pdf", "success": true, "documentId": 501, "fileId": "01ABCXYZ...", "errorMessage": null },
  { "fileName": "qua-lon.pdf", "success": false, "documentId": null, "fileId": null, "errorMessage": "File exceeds 10MB limit" }
]
```

- Trả về `ApiResponse<List<EutrUploadFileResultDto>>` — luôn liệt kê đủ mọi file trong request
  (kể cả file bị loại do validate), để frontend hiển thị đúng file nào thành công/thất bại (FR-030).
- `fileName` trong response là tên file **gốc** (`IFormFile.FileName`), không phải tên đã làm duy
  nhất trên SharePoint.

### Suy ra thư mục SharePoint từ `poCode` (research Quyết định 13)

1. `basePath = configuration["SharePointEutrPath"]` (khóa cấu hình mới, cạnh `SharePointCompPath`).
2. `EutrUploadService` gọi `ISharepointService.GetFolders(basePath)`; nếu đã có thư mục tên đúng
   `poCode`, dùng lại; nếu chưa, gọi `ISharepointService.CreateFolder($"{basePath}/{poCode}")`.
3. Upload từng file hợp lệ vào thư mục đã suy ra (`ISharepointService.UploadFile`), tên file trên
   SharePoint được làm duy nhất (hậu tố 6 ký tự, cùng helper `ComplUploadService` đã dùng) để tránh
   ghi đè — không ảnh hưởng tới `Name` lưu trong `eutr_documents` (vẫn là tên gốc).
4. Không có bảng MySQL nào lưu ánh xạ PO ↔ thư mục — việc tìm/tạo thư mục thực hiện trực tiếp trên
   SharePoint ở mỗi lượt gọi.

### Validate file (research Quyết định 13, FR-026)

- Đuôi file hợp lệ (không phân biệt hoa/thường): `.pdf`, `.doc`, `.docx`, `.xls`, `.xlsx`, `.jpg`,
  `.jpeg`, `.png`.
- Kích thước tối đa: 10MB (`10 * 1024 * 1024` byte) mỗi file.
- File không hợp lệ: loại khỏi lượt upload lên SharePoint, không tạo document, trả về item
  `{ success: false, errorMessage: "..." }` tương ứng — không chặn các file hợp lệ khác.

### Ghi `eutr_documents` per-file (research Quyết định 14, FR-029/FR-030)

- Mỗi file hợp lệ upload SharePoint thành công → 1 transaction (`IUnitOfWork`) ghi 1 dòng
  `eutr_documents`: `Name` = tên file gốc, `FileId` = id SharePoint, `ValidFrom` = `DateTime.Today`,
  `ValidTo` = `9999-12-31`, `CreatedBy`/`CreatedDate` tự động. **Kể từ Update 7**, transaction này
  MỞ RỘNG để bao gồm luôn các dòng `eutr_references` của cùng file (xem mục dưới) — không còn là
  transaction chỉ ghi riêng `eutr_documents` như mô tả ban đầu ở Update 6.
- File/transaction lỗi không rollback các file đã commit trước đó trong cùng request (best-effort,
  KHÔNG all-or-nothing) — phạm vi "file" ở đây (từ Update 7) là "1 document + N reference", không
  chỉ riêng document.
- Bảng `eutr_documents` **không có cột lưu `poCode`** — document tạo qua đường này không thể truy
  vấn ngược lại PO đã dùng để upload trực tiếp trên chính bảng `eutr_documents` (xác nhận ở clarify
  Update 6); từ Update 7, liên kết PO/Step được truy vấn gián tiếp qua bảng `eutr_references` (xem
  mục dưới).

## Validate prefix tên file theo `eutr_master_documents` (spec Update 7, FR-032)

Trước khi upload file lên SharePoint (sau khi đã qua validate định dạng/kích thước ở FR-026),
`EutrUploadService` gọi method mới `IEutrMastersRepository.GetMatchingPrefixesAsync(fileName, ct)`
(bổ sung vào repository **đã có sẵn** của feature `002-eutr-masters`, KHÔNG tạo repository mới —
xem research Quyết định 17):

```sql
SELECT Id, StepId, Prefix FROM eutr_master_documents
WHERE Prefix IS NOT NULL AND Prefix <> ''
  AND @fileName LIKE CONCAT(
    REPLACE(REPLACE(REPLACE(Prefix, '\\', '\\\\'), '%', '\\%'), '_', '\\_'), '%');
```

- Đây là truy vấn "LIKE đảo chiều": giá trị cột `Prefix` (dữ liệu) được escape rồi dùng làm **pattern**,
  `fileName` (tham số) là chuỗi cần khớp — ngược với truy vấn tìm kiếm LIKE thông thường. Việc escape
  `\`, `%`, `_` trong `Prefix` là bắt buộc vì đây là chuỗi tự do người dùng nhập ở `002-eutr-masters`
  (không có ràng buộc loại trừ ký tự đại diện LIKE khi nhập).
- Khớp không phân biệt hoa/thường (dựa vào collation mặc định của DB — các bảng `eutr_*` hiện không
  khai báo collation riêng nên dùng collation mặc định của schema, giả định case-insensitive).
- Trả về **danh sách** bản ghi khớp (0, 1, hoặc nhiều) — KHÔNG phải một bản ghi duy nhất.
- 0 kết quả → file bị loại khỏi lượt upload, KHÔNG upload lên SharePoint, kết quả trả về
  `{ success: false, errorMessage: "No matching prefix found in EUTR masters" }` (hoặc tương đương).
- ≥ 1 kết quả → lấy tập `StepId` **phân biệt** (`Distinct`) trong số các bản ghi khớp (nhiều bản ghi
  có thể trùng `StepId` nếu nhiều `Prefix` khác nhau đều là tiền tố hợp lệ và cùng gắn 1 Step) — mỗi
  `StepId` phân biệt sẽ tạo 1 dòng `eutr_references` (xem mục dưới).

## Bảng `eutr_references` — entity mới + cột mới `StepId` (spec Update 7, FR-033)

Bảng `eutr_references` đã tồn tại trong schema (`Id, RefId, DocumentId, RefType, RefValue` + audit)
nhưng **chưa có entity backend nào** trước Update 7 (không service/repository nào ghi/đọc bảng
này). Update 7 bổ sung:

- **Entity mới** `ComplianceSys.Domain/Entities/EutrReferences.cs` (`[Table("eutr_references")]`,
  kế thừa `BaseEntity`): `Id (long)`, `RefId (long?)` — **KHÔNG dùng bởi feature này**, giữ nguyên
  cho mục đích thiết kế cũ (trỏ `eutr_template_details`), `DocumentId (long?)`, **`StepId (long?)`
  — cột MỚI**, `RefType (byte?)`, `RefValue (string?)`.
- **Migration mới** `10_add_stepid_to_eutr_references.sql`:
  ```sql
  ALTER TABLE eutr_references ADD COLUMN StepId BIGINT UNSIGNED NULL AFTER RefId;
  ALTER TABLE eutr_references ADD CONSTRAINT eutr_references_stepid_foreign
    FOREIGN KEY (StepId) REFERENCES eutr_steps(Id);
  ```
  KHÔNG sửa/xóa cột `RefId` hay ràng buộc khóa ngoại `eutr_references_refid_foreign` hiện có (trỏ
  `eutr_template_details(Id)`) — hai cột `RefId`/`StepId` hoàn toàn độc lập trên cùng bảng.
- **Không tạo repository riêng** — dùng thẳng `IRepository<EutrReferences, long>` generic (đã đăng
  ký open-generic sẵn, đúng mẫu `EutrDocuments`) vì chỉ cần `AddAsync`, không có truy vấn tùy biến
  nào trên bảng này trong phạm vi feature.

### Ghi `eutr_references` per-file, gộp transaction với `eutr_documents` (research Quyết định 18, FR-033)

Với mỗi file đã qua validate định dạng/kích thước (FR-026) VÀ validate prefix (FR-032, có ít nhất 1
`StepId` khớp) và đã upload SharePoint thành công:

1. Mở 1 transaction (`IUnitOfWork.BeginTransactionAsync`).
2. `_repository<EutrDocuments,long>.AddAsync(...)` → lấy `documentId` mới.
3. Với mỗi `StepId` phân biệt đã khớp prefix: `_repository<EutrReferences,long>.AddAsync(new
   EutrReferences { DocumentId = documentId, StepId = stepId, RefType = resolvedRefType, RefValue =
   poCode })`, trong đó `resolvedRefType = request.TypeId.HasValue ? (byte)request.TypeId.Value :
   PoRefType` *(kể từ Update 18, research Quyết định 52 — trước đó luôn là hằng số `PoRefType`)*.
4. `CommitAsync()`. Nếu bất kỳ bước 2-3 nào throw → `RollbackAsync()` — **toàn bộ** (cả
   `eutr_documents` lẫn mọi `eutr_references` đã insert trong bước 3 của file này) bị hủy; file đó
   được báo `success: false` trong kết quả trả về (không để lại document "mồ côi" không có
   `eutr_references`).
- `RefType`: **kể từ Update 18**, bằng `(byte)request.TypeId` khi popup Add gửi kèm field này (luồng
  Type = "PO" của popup Add hợp nhất, Update 15/17) — giá trị này là `Id` thật của bản ghi
  `eutr_reference_types` có `Name` = "PO", không còn phụ thuộc giả định "PO luôn có Id = 0" (giả định
  này từng đúng nhờ seed cưỡng bức ở Update 14, nhưng không còn đảm bảo từ khi feature
  `006-eutr-reference-types` cho phép CRUD tự do trên bảng đó). Khi request KHÔNG gửi `typeId` (caller
  cũ, ví dụ trang Add độc lập `EutrDocumentsAdd.jsx`), `RefType` giữ nguyên hằng số `PoRefType` như
  trước Update 18 — không đổi hành vi của caller đó.
- `RefValue` = `poCode` (cùng giá trị dùng để suy ra thư mục SharePoint, xem mục "Suy ra thư mục
  SharePoint từ `poCode`" ở trên) — giống nhau trên mọi dòng `eutr_references` của cùng file.
- Ví dụ (kể từ Update 18, popup Add gửi `typeId = 3` cho Type "PO"): file `"INV2026_report.pdf"` khớp
  2 bản ghi `eutr_master_documents` (`Prefix = "INV"`, `StepId = 5` và `Prefix = "INV2026"`,
  `StepId = 7`) → tạo 1 dòng `eutr_documents` (`Id = 501`) và 2 dòng `eutr_references`:
  `{ DocumentId: 501, StepId: 5, RefType: 3, RefValue: "PO000123" }` và
  `{ DocumentId: 501, StepId: 7, RefType: 3, RefValue: "PO000123" }`.

## Thực thể mới: EutrReferenceDetails (bảng `eutr_reference_details`, spec Update 11, FR-052)

Bảng **đã tồn tại sẵn** trong `docs/design/eutr/eutr_db.sql` (không migration mới — xem research
Quyết định 29). Entity backend mới `ComplianceSys.Domain/Entities/EutrReferenceDetails.cs`
(`[Table("eutr_reference_details")]`, kế thừa `BaseEntity`):

| Trường | Kiểu | Nguồn | Ghi chú |
|---|---|---|---|
| `Id` | long | DB | Khóa chính, auto-increment |
| `RefId` | long? | Popup Assign condition | FK → `eutr_references.Id` (khóa ngoại `eutr_reference_details_refid_foreign` — **khác** `eutr_references.RefId`, hai cột trùng tên ở hai bảng, không liên quan) |
| `ConditionType` | byte? | Popup Assign condition (dropdown "Conditions type") | Giá trị `refType` dùng để tải Condition value (`15`="PO", `14`="Vendor") — không có bảng mapping riêng |
| `ConditionValue` | string? | Popup Assign condition (Condition value đã chọn) | Mã/tên định danh của 1 PO hoặc 1 Vendor — mỗi giá trị multi-select = 1 dòng riêng |

Không có repository generic phù hợp cho đọc/xóa tùy biến (cần JOIN + xóa theo `RefId` không phải
khóa chính) — tạo `IEutrReferenceDetailsRepository`/`EutrReferenceDetailsRepository`
(`DapperRepository<EutrReferenceDetails,long>`, clone `EutrReferencesRepository`):

```csharp
public interface IEutrReferenceDetailsRepository
{
    Task<List<EutrConditionGroupRow>> GetGroupedConditionsByDocumentIdsAsync(
        IEnumerable<long> documentIds, CancellationToken ct = default);
    Task DeleteByRefIdAsync(long refId, CancellationToken ct = default);
}
```

- `EutrConditionGroupRow { long DocumentId; byte ConditionType; string ConditionValue; }` —
  projection phẳng (JOIN `eutr_reference_details`+`eutr_references` theo `RefId`=`Id`, lọc
  `WHERE eutr_references.DocumentId IN @DocumentIds`); service gộp theo `DocumentId` rồi theo
  `ConditionType` thành `List<ConditionGroupDto>` (xem mục "Mở rộng `EutrDocumentsResponseDto`" bên
  dưới).
- `DeleteByRefIdAsync`: `DELETE FROM eutr_reference_details WHERE RefId = @RefId` — dùng khi sửa
  (FR-058, xem mục "Sửa Step/Conditions" bên dưới).
- Đường **ghi thêm** dùng thẳng `IRepository<EutrReferenceDetails,long>` generic (giống cách
  `EutrReferences` được ghi ở `EutrUploadService`) — không cần method riêng cho `AddAsync`.

### ⚠️ Sửa `DeleteByDocumentIdAsync` để tránh vi phạm khóa ngoại (research Quyết định 30)

`eutr_reference_details_refid_foreign` KHÔNG có `ON DELETE CASCADE`. Từ Update 11,
`EutrReferencesRepository.DeleteByDocumentIdAsync` (dùng bởi `EutrDocumentsService.DeleteAsync`/
`DeleteMultiAsync`, FR-039/FR-040) MUST đổi SQL thành 2 câu trong cùng transaction — xóa
`eutr_reference_details` con trước, rồi mới xóa `eutr_references` cha:

```sql
DELETE FROM eutr_reference_details
WHERE RefId IN (SELECT Id FROM eutr_references WHERE DocumentId = @DocumentId);
DELETE FROM eutr_references WHERE DocumentId = @DocumentId;
```

Chữ ký method (`Task DeleteByDocumentIdAsync(long documentId, ct)`) và toàn bộ caller **không đổi**
— chỉ SQL nội bộ thay đổi.

## Upload file thật cho Screen2 ("Upload manual") — endpoint MỚI trong `SharePointController` (spec Update 11, FR-046/FR-047)

### `POST /api/sharepoint/eutr-upload-manual-multi` (request, `multipart/form-data`)

```
files: File[]   (multiple, cùng field name "files")
```

`EutrManualMultiUploadFileRequest { List<IFormFile> Files }` — **không có** `PoCode` (khác
`EutrMultiUploadFileRequest` của Update 6). Validate định dạng/kích thước tái dùng nguyên vẹn
(PDF/DOC/DOCX/XLS/XLSX/JPG/PNG, tối đa 10MB) — KHÔNG validate prefix `eutr_master_documents`.

### Response — tái dùng `List<EutrUploadFileResultDto>` (không đổi shape so với Update 6)

```json
{
  "success": true,
  "data": [
    { "fileName": "note1.pdf", "success": true, "documentId": 601, "fileId": "01XYZ..." },
    { "fileName": "bad.exe", "success": false, "errorMessage": "Invalid file type" }
  ]
}
```

- Thư mục SharePoint đích **cố định**: `{SharePointEutrPath}/UploadManual` (tự tạo nếu chưa có,
  dùng lại `ResolveOrCreatePoFolderAsync(basePath, "UploadManual")` — tên hàm giữ nguyên, chỉ đổi
  tham số truyền vào).
- Mỗi file thành công tạo **đúng 1 dòng `eutr_documents`** (`Name`, `FileId`, `ValidFrom`=hôm nay,
  `ValidTo`=sentinel `9999-12-31`) — **KHÔNG** tạo bất kỳ dòng `eutr_references`/
  `eutr_reference_details` nào ở bước này (khác nhánh PO của Update 6/7).
- Policy: dùng chung `[Authorize]` cấp controller của `SharePointController` (không thêm policy
  riêng theo action, giống `upload-multi`/`eutr-upload-multi` hiện có).

## Danh sách file "chưa gán Step/Conditions" — endpoint MỚI trong `EutrDocumentsController` (spec Update 11, FR-048)

### `POST /api/eutr-documents/get-unassigned` (request — giống `get-all`)

Query: `page`, `pageSize`, `sortColumn`, `sortOrder`. Body: `filters: FilterRequest[]` (whitelist
theo cột thật của `eutr_documents`: `Name`, `ValidFrom`, `ValidTo`, `CreatedBy`, `CreatedDate`).

### Response — `PagedResult<EutrDocumentsResponseDto>` (cùng shape `get-all`, các field
Step/Type/Conditions luôn rỗng/`null`)

```json
{
  "items": [
    { "id": 601, "name": "note1.pdf", "fileId": "01XYZ...", "validFrom": "2026-07-10T00:00:00",
      "validTo": "9999-12-31T00:00:00", "createdBy": "hien", "createdDate": "2026-07-10T09:00:00Z",
      "stepNames": [], "refType": null, "stepId": null, "conditions": [] }
  ],
  "totalCount": 1
}
```

- Điều kiện lọc **cố định**, luôn áp dụng (không thuộc whitelist filter người dùng gõ):
  `WHERE NOT EXISTS (SELECT 1 FROM eutr_references r WHERE r.DocumentId = eutr_documents.Id)` —
  xem research Quyết định 33 (lý do phải viết SQL tùy biến, generic repository không hỗ trợ).
  Nguồn: `EutrReferencesRepository.GetUnassignedDocumentsPagedAsync(PagedRequest, ct)` (đặt cạnh 2
  method JOIN hiện có, cùng lý do sở hữu mọi truy vấn cross-table trên `eutr_references`).
- Bao gồm CẢ document tạo qua form Save nhập tay (chưa từng upload) VÀ document tạo qua khu Upload
  File Screen2 (Update 11) chưa được Assign condition — loại trừ document đã có `eutr_references`
  (ví dụ tạo qua Upload Screen1, luôn có `eutr_references` ngay khi tạo).
- Policy: `EutrDocuments.ReadAll` (dùng chung với `get-all`).

## Popup "Assign condition" — 3 endpoint MỚI trong `EutrDocumentsController` (spec Update 11/12, FR-051 đến FR-058)

### `POST /api/eutr-documents/assign-conditions` (chế độ tạo mới, FR-052) — request

```json
{
  "documentIds": [601, 602],
  "stepId": 5,
  "conditions": [
    { "conditionType": 15, "values": ["PO000123", "PO000124"] },
    { "conditionType": 14, "values": ["V001"] }
  ]
}
```

`EutrAssignConditionsRequestDto { List<long> DocumentIds, long StepId, List<EutrConditionRowDto>
Conditions }`; `EutrConditionRowDto { byte ConditionType, List<string> Values }`. Validator
(`EutrAssignConditionsRequestDtoValidator`, FluentValidation) MUST chặn khi: `DocumentIds` rỗng,
`StepId <= 0`, `Conditions` rỗng HOẶC bất kỳ dòng nào có `Values` rỗng (FR-052, "ít nhất 1 dòng
Conditions type với ít nhất 1 giá trị"), HOẶC `Conditions` có 2 dòng cùng `ConditionType` (Update
13, FR-051 — dùng `Distinct().Count()`, xem research Quyết định 34).

- Với **mỗi** `DocumentId`, 1 transaction riêng (per-item, per-document lỗi không chặn document
  khác trong cùng request — cùng ngữ nghĩa FR-030/FR-040): insert 1 dòng `eutr_references`
  (`DocumentId`, `StepId`, `RefType=1`, `RefValue=null`), rồi insert N dòng `eutr_reference_details`
  (1 dòng/giá trị trong mỗi `Conditions[].Values`, `RefId`=Id vừa tạo, `ConditionType`,
  `ConditionValue`).
- Response: `List<EutrUploadFileResultDto>`-style hoặc đơn giản `ApiResponse<string>` liệt kê số
  document thành công/thất bại (chi tiết chữ ký trả về là quyết định triển khai, không ảnh hưởng
  hành vi quan sát được — FR-052/SC-028 chỉ yêu cầu đúng số bản ghi được tạo).
- Policy: `EutrDocuments.Update`.

### `GET /api/eutr-documents/{id}/condition-assignment` (chế độ sửa, tải trước, FR-057) — response

```json
{ "stepId": 5, "conditions": [{ "conditionType": 15, "values": ["PO000123", "PO000124"] }] }
```

`EutrDocumentConditionAssignmentDto { long? StepId, List<EutrConditionRowDto> Conditions }`. Policy:
`EutrDocuments.ReadOne`. Document không có `eutr_references`/`RefType=1` → `404`/`stepId: null`
(not-found rõ ràng, theo mẫu xử lý đã có ở nơi khác trong feature).

### `PUT /api/eutr-documents/{id}/condition-assignment` (chế độ sửa, lưu, FR-058) — request

Cùng shape `EutrUpdateConditionAssignmentRequestDto { long StepId, List<EutrConditionRowDto>
Conditions }` (không có `DocumentIds` — 1 document duy nhất, lấy từ route `{id}`), cùng validator
(Step bắt buộc, ≥1 Conditions type hợp lệ, không trùng `ConditionType`). Trong 1 transaction: (a)
`UpdateAsync` đổi `StepId` của dòng `eutr_references` hiện có (giữ `DocumentId`/`RefType=1`/
`RefValue=null`); (b) `DeleteByRefIdAsync(refId, ct)` xóa hết `eutr_reference_details` cũ, rồi ghi
lại từ đầu đúng bộ `Conditions` mới (replace toàn bộ — KHÔNG giữ `Id` cũ, xem research Quyết định
34). Policy: `EutrDocuments.Update`.

## Sửa Step cho document Type="PO" — endpoint MỚI trong `EutrDocumentsController` (spec Update 12/13, FR-055)

### `PUT /api/eutr-documents/{id}/step` (request/response)

Request: `EutrUpdatePoStepRequestDto { long StepId }`. Trong 1 transaction: lấy `RefValue` (mã PO)
từ dòng `eutr_references` (`RefType=0`) có `Id` **nhỏ nhất** trong số các dòng của document đó
(quy tắc xác định của Update 13/FR-055), xóa **toàn bộ** các dòng đó, insert **đúng 1** dòng mới
(`DocumentId`, `StepId` mới, `RefType=0`, `RefValue` giữ nguyên). Policy: `EutrDocuments.Update`.

## Mở rộng `EutrDocumentsResponseDto` — `StepId` (Update 13) + `Conditions` (Update 11)

```json
{
  "id": 501, "name": "INV2026_hop-dong-po123.pdf", "...": "...",
  "stepNames": ["Bước kiểm tra hóa đơn"], "refType": 0, "stepId": 5,
  "conditions": []
}
```
```json
{
  "id": 701, "name": "vendor-cert.pdf", "...": "...",
  "stepNames": ["Bước xác minh nguồn gốc"], "refType": 1, "stepId": 9,
  "conditions": [
    { "conditionType": 15, "values": ["PO000123", "PO000124"] },
    { "conditionType": 14, "values": ["V001"] }
  ]
}
```

- `stepId` (`long?`, mới): Step hiện tại — với `refType=0` (PO), là `StepId` của dòng
  `eutr_references` có `Id` nhỏ nhất trong nhóm (Update 13 tie-break); với `refType=1` (Upload
  manual), luôn đúng 1 dòng nên không cần tie-break. Dùng để nạp dropdown Step khi mở Edit (Quyết
  định 38), tránh gọi thêm API riêng.
- `conditions` (`List<ConditionGroupDto>`, mới): `ConditionGroupDto { byte ConditionType,
  List<string> Values }` — nhóm `eutr_reference_details` theo `ConditionType`; `[]` khi document
  không có bản ghi nào (Type="PO", hoặc Type="Upload manual" nhưng chỉ có Step, không có Conditions
  type nào — không còn xảy ra sau Update 13 vì Save bắt buộc ≥1 dòng, nhưng dữ liệu cũ trước Update
  13 vẫn có thể ở trạng thái này). Frontend map `conditionType` → nhãn qua `CONDITION_TYPE_OPTIONS`
  mới (`compliance-client/src/utils/helpers.js`, cạnh `TAKE_FROM_OPTIONS`).
- Nguồn: `EutrReferenceStepInfo` (projection JOIN hiện có) thêm field `ReferenceId` (= `eutr_references
  .Id`, dùng để suy `stepId` theo `Id` nhỏ nhất); `IEutrReferenceDetailsRepository.
  GetGroupedConditionsByDocumentIdsAsync(documentIds)` (mới, xem trên) cho `conditions`. Cả hai được
  gộp trong cùng bước `AttachStepInfoAsync` (đổi tên `AttachStepAndConditionInfoAsync`) đã có từ
  Update 8 — không thêm round-trip HTTP mới cho grid chính.

## Popup Add hợp nhất Type/Step/Value/Upload — endpoint MỚI trong `SharePointController` (spec Update 15/16, FR-059 đến FR-070)

> ⚠️ **Ngoại lệ kể từ Update 17 (FR-072 đến FR-075)**: khi Type đã chọn trong popup Add có `Name` =
> "PO", request/endpoint **KHÔNG còn đi qua** `EutrTypeMultiUploadFileRequest`/
> `eutr-upload-multi-by-type` mô tả dưới đây — frontend gọi lại **nguyên vẹn**
> `EutrMultiUploadFileRequest`/`POST /api/sharepoint/eutr-upload-multi` (Update 6/7, xem mục "Upload
> nhiều file thật lên SharePoint" phía trên) với `PoCode` = giá trị chip PO đã chọn. Không có `stepId`
> trong request này — Step (`eutr_references.StepId`) được backend tự suy theo Prefix tên file (có
> thể nhiều dòng/file, xem mục "Validate prefix tên file..." phía trên), không phải một giá trị đơn
> truyền từ client. Mọi nội dung bên dưới (`EutrTypeMultiUploadFileRequest`, cách suy thư mục theo
> `typeName`, ghi N `eutr_references`=N chip) tiếp tục áp dụng nguyên vẹn cho **mọi Type khác "PO"**
> (Vendor, Invoice, Delivery note, General agreement, Type mới) — không đổi so với Update 15/16.
>
> **Cập nhật Update 18 (FR-076/FR-077, research Quyết định 52)**: `EutrMultiUploadFileRequest` (mục
> "Upload nhiều file thật lên SharePoint" phía trên) nay có thêm field nullable `typeId`, và popup Add
> MUST truyền `type.id` (Id thật của Type "PO" đang chọn) vào đó khi gọi endpoint `eutr-upload-multi`
> — đóng gap trước đó (`RefType` ghi cứng bằng hằng số, KHÔNG khớp `typeId` thật), để nhánh Type =
> "PO" ghi `RefType` theo đúng cùng nguyên tắc "`RefType` = `Id` của Type đã chọn" mà bảng
> `EutrTypeMultiUploadFileRequest` bên dưới đã áp dụng cho mọi Type khác từ Update 15.

### `EutrTypeMultiUploadFileRequest` (request, `[FromForm]`, `multipart/form-data`)

```json
{
  "files": ["<binary>", "<binary>"],
  "typeId": 3,
  "typeName": "Invoice",
  "stepId": 5,
  "refValues": ["PO000123", "PO000124"]
}
```

- `typeId` (`long`): `Id` của bản ghi `eutr_reference_types` đã chọn ở popup Add — ghi trực tiếp
  (cast `(byte)`) vào `eutr_references.RefType`, KHÔNG còn giới hạn ở `0`/`1` như luồng Update 7/11.
- `typeName` (`string`): `Name` của bản ghi đó — CHỈ dùng ở backend để suy tên thư mục SharePoint
  (Quyết định 43), KHÔNG lưu vào bảng nào (tên hiển thị Type đã có sẵn qua JOIN `eutr_references.
  RefType`→`eutr_reference_types.Id`, xem Update 14).
- `stepId` (`long`): Step đã chọn — ghi giống nhau trên mọi dòng `eutr_references` được tạo cho các
  file trong cùng lượt Upload.
- `refValues` (`List<string>`): danh sách giá trị chip tại thời điểm nhấn Upload — 1 phần tử nếu Type
  là "PO"/"Vendor" (FR-064), có thể nhiều phần tử với Type khác.

### Response — tái dùng `List<EutrUploadFileResultDto>` (không đổi shape so với Update 6/11)

Không có field mới — mỗi phần tử vẫn `{ FileName, Success, ErrorMessage?, DocumentId?, FileId? }`.

### Ghi `eutr_documents` + N `eutr_references` per-file (research Quyết định 42, FR-068)

Với mỗi file hợp lệ: 1 transaction — insert 1 `eutr_documents` (`Name`=tên file gốc,
`ValidFrom`=hôm nay, `ValidTo`=`9999-12-31`, `FileId`=id SharePoint, giống hệt Update 6/7) rồi insert
N dòng `eutr_references` (N = `refValues.Count`, `DocumentId` giống nhau, `StepId`=`request.StepId`
giống nhau, `RefType`=`(byte)request.TypeId` giống nhau, `RefValue`=từng giá trị trong `refValues`
— khác nhau giữa các dòng). Cột `RefId` hiện có KHÔNG bị ghi (giữ đúng quy ước từ Update 7).

### Suy thư mục SharePoint từ `typeName` (research Quyết định 43, FR-067)

| `typeName` (so khớp không phân biệt hoa/thường) | Thư mục SharePoint |
|---|---|
| "PO" | *(Không còn đi qua bảng này kể từ Update 17 — xem ghi chú ⚠️ ở đầu mục. Thư mục vẫn `{SharePointEutrPath}/{poCode}`, nhưng suy ra bởi endpoint `eutr-upload-multi` gốc, không phải `ResolveFolderName` của endpoint này.)* |
| "Vendor" | `{SharePointEutrPath}/{refValues[0]}` (theo mã Vendor đã chọn) |
| "Invoice" | `{SharePointEutrPath}/Invoice` (cố định) |
| "Delivery note" | `{SharePointEutrPath}/DeliveryNote` (cố định) |
| "General agreement" | `{SharePointEutrPath}/GeneralAgreement` (cố định) |
| Khác (Type mới do feature `006` thêm) | `{SharePointEutrPath}/{typeName không khoảng trắng}` (cố định) |

Dùng lại nguyên vẹn `ResolveOrCreatePoFolderAsync(basePath, folderName)` đã có (Quyết định 13) — chỉ
tính `folderName` theo bảng trên rồi gọi hàm này, không sửa hàm.

### Trạng thái chỉ tồn tại ở frontend — Type/Step/Value/chip trong popup Add (KHÔNG có entity/DTO backend)

- **Type** (đối tượng `eutr_reference_types` đã chọn, từ `GetEutrReferenceTypesUseCase` — không entity
  frontend mới, tái dùng `EutrReferenceTypes.js` đã có từ feature `006`).
- **Step** (đối tượng `eutr_steps` đã chọn, từ `GetEutrStepsUseCase` — không entity frontend mới).
- **Value/chip**: mảng chuỗi (Type không có nguồn gợi ý) hoặc mảng đối tượng tham chiếu D365 (Type có
  nguồn gợi ý, cùng shape với kết quả `useReferenceObjects` — `{ id, code, name }`) — state cục bộ của
  `EutrDocumentsAddDialog.jsx`/`EutrAddValueAutocomplete.jsx`, gửi lên backend dưới dạng `refValues:
  string[]` (lấy `code` nếu là object, hoặc chuỗi thô nếu Type không có nguồn) khi nhấn Upload.
- Không có migration DB nào cho phần này — `eutr_references.RefType`/`StepId`/`RefValue` đã đủ linh
  hoạt từ Update 7/14 để lưu bất kỳ tổ hợp Type/Step/giá trị nào.

## Update 19 — Hợp nhất hoàn toàn Add/Edit vào một popup; đơn giản hóa Conditions; xóa luồng Assign condition

Đây là một **thay đổi phạm vi lớn**, KHÔNG migration DB mới (mọi cột cần đều đã tồn tại từ Update
7/14). Xem research Quyết định 53-60 cho lý do từng quyết định.

### Cột Conditions đổi nguồn — flat `RefValue`, không còn `eutr_reference_details` (FR-005, research Quyết định 54)

`EutrDocumentsResponseDto.Conditions` đổi kiểu từ `List<ConditionGroupDto>` (Update 11, nhóm theo
`ConditionType`) sang **`List<string>`** — danh sách `RefValue` **phân biệt** (distinct), khác `null`,
của mọi bản ghi `eutr_references` có `DocumentId` = document đó, giữ thứ tự xuất hiện.

```json
{
  "id": 501, "name": "INV2026_hop-dong-po123.pdf", "...": "...",
  "stepNames": ["Bước kiểm tra hóa đơn", "Bước xác minh nguồn gốc"], "refType": 3,
  "typeName": "PO", "stepId": 5,
  "conditions": ["PO000123"]
}
```

Nguồn dữ liệu: `EutrReferencesRepository.GetStepInfoByDocumentIdsAsync` mở rộng thêm `r.RefValue` vào
`SELECT` (cùng câu SQL JOIN `eutr_references`+`eutr_steps`+`eutr_reference_types` đã có từ Update
8/14) — `EutrReferenceStepInfo` (projection) thêm field `string? RefValue`.
`AttachStepAndConditionInfoAsync` (`EutrDocumentsService`) nhóm theo `DocumentId`, lấy
`.Select(x => x.RefValue).Where(v => !string.IsNullOrEmpty(v)).Distinct()` làm `Conditions`. KHÔNG
còn gọi `IEutrReferenceDetailsRepository` (bị xóa hoàn toàn, xem mục dưới).

- Document không có bản ghi `eutr_references` nào, hoặc mọi bản ghi có `RefValue = null` (ví dụ tạo
  qua popup Assign condition cũ trước Update 19) → `conditions: []` (trống, không lỗi).
- Document Type="PO" khớp N `StepId` phân biệt cho cùng 1 mã PO (Update 7/18) → N dòng
  `eutr_references` cùng `RefValue` → `Distinct()` gộp về **đúng 1 chip**, không hiển thị trùng lặp.

### Xóa hoàn toàn `EutrReferenceDetails`/`eutr_reference_details` khỏi backend feature này (research Quyết định 57)

Bảng `eutr_reference_details` (Update 11) **không bị xóa/migrate** — dữ liệu cũ được giữ nguyên trong
schema theo đúng Assumptions của spec. Nhưng feature này xóa hoàn toàn khỏi codebase:
`EutrReferenceDetails.cs` (entity), `IEutrReferenceDetailsRepository.cs`/
`EutrReferenceDetailsRepository.cs`, `ConditionGroupDto.cs`, `EutrConditionGroupRow.cs` — không còn
lớp nào trong `ComplianceSys.*` đọc/ghi bảng này.

**Ngoại lệ giữ nguyên**: SQL 2 bước của `EutrReferencesRepository.DeleteByDocumentIdAsync` (Update
11, research Quyết định 30) — vẫn xóa `eutr_reference_details` con trước khi xóa `eutr_references`
cha, dùng raw SQL trực tiếp (không qua repository đã xóa), vì khóa ngoại
`eutr_reference_details_refid_foreign` vẫn tồn tại và dữ liệu lịch sử vẫn có thể vi phạm nó nếu bỏ
bước này (research Quyết định 58). Chữ ký method và mọi caller không đổi.

### Popup hợp nhất — request/response cho Add (Valid from/Valid to mới, research Quyết định 55)

Cả 2 request DTO dùng cho Upload thêm 2 field nullable:

```json
{ "files": ["<binary>"], "poCode": "PO000123", "typeId": 3, "validFrom": "2026-07-20", "validTo": "9999-12-31" }
```

- `EutrMultiUploadFileRequest` (nhánh Type="PO", `eutr-upload-multi`): + `ValidFrom (DateTime?)`,
  `ValidTo (DateTime?)`.
- `EutrTypeMultiUploadFileRequest` (nhánh Type khác, `eutr-upload-multi-by-type`): + `ValidFrom
  (DateTime?)`, `ValidTo (DateTime?)`.
- `EutrUploadService`: 2 nơi đang gán cứng `ValidFrom = DateTime.Today`/`ValidTo = MaxValidTo` đổi
  thành `request.ValidFrom ?? DateTime.Today`/`request.ValidTo ?? MaxValidTo` — mọi document tạo ra
  từ 1 lượt Upload nhận đúng 1 cặp giá trị Valid from/Valid to (giá trị đang hiển thị ở popup tại thời
  điểm nhấn Upload), giống nhau trên mọi file trong cùng lượt (FR-021).
- Response (`List<EutrUploadFileResultDto>`) không đổi shape.

### `PUT /api/eutr-documents/{id}/step` — đơn giản hóa hoàn toàn, dùng chung cho mọi Type (research Quyết định 56, FR-029/FR-033)

Đổi tên request DTO `EutrUpdatePoStepRequestDto` → `EutrUpdateReferenceStepRequestDto` (cùng shape
`{ long StepId }`). Hành vi backend đổi hoàn toàn:

- **Trước Update 19** (Update 12/13): chỉ áp dụng cho `RefType=0` (PO) — đọc `RefValue` từ dòng `Id`
  nhỏ nhất, xóa toàn bộ dòng cũ, insert đúng 1 dòng mới.
- **Từ Update 19**: áp dụng cho **mọi** document có ít nhất 1 bản ghi `eutr_references` (không phân
  biệt Type) — `IEutrReferencesRepository.UpdateStepIdByDocumentIdAsync(documentId, stepId, updatedBy,
  ct)` chạy `UPDATE eutr_references SET StepId=@StepId, UpdatedBy=@UpdatedBy, UpdatedDate=@UpdatedDate
  WHERE DocumentId=@DocumentId` — cập nhật **tại chỗ** mọi dòng hiện có, giữ nguyên `RefValue`/
  `RefType`/số lượng bản ghi, KHÔNG xóa/tạo lại bản ghi nào (khớp đúng FR-033).
- Logic này chuyển từ `IEutrConditionAssignmentService` (bị xóa, xem mục dưới) sang method mới
  `EutrDocumentsService.UpdateReferenceStepAsync(documentId, stepId, userEmail, ct)`, đặt cạnh
  `DeleteAsync`/`DeleteMultiAsync` override đã có từ Update 9.
- Document không có bản ghi `eutr_references` nào → endpoint này không được frontend gọi (Step field
  ẩn ở popup Edit, research Quyết định 60) — backend không cần xử lý đặc biệt cho trường hợp 0 dòng
  (UPDATE ảnh hưởng 0 dòng, không lỗi).

### Xóa hoàn toàn: `IEutrConditionAssignmentService`, 4 endpoint Assign-condition/Unassigned (research Quyết định 57)

Xóa khỏi `EutrDocumentsController`: `POST get-unassigned`, `POST assign-conditions`, `GET`/
`PUT {id}/condition-assignment`. Xóa khỏi `SharePointController`: `POST eutr-upload-manual-multi`.
Xóa toàn bộ DTO/entity/repository/service chỉ phục vụ các endpoint này:
`IEutrConditionAssignmentService`/`EutrConditionAssignmentService`,
`EutrManualMultiUploadFileRequest`, `EutrAssignConditionsRequestDto` (+validator),
`EutrConditionRowDto`, `EutrUpdateConditionAssignmentRequestDto` (+validator),
`EutrDocumentConditionAssignmentDto`; `EutrDocumentsService.GetUnassignedPagedAsync`;
`IEutrReferencesRepository.GetUnassignedDocumentsPagedAsync`;
`EutrUploadService.UploadManualMultipleToSharePointAndSaveDataAsync`. Xóa toàn bộ DI registration
tương ứng.

> **⚠️ Điều chỉnh khi implement**: `POST list-po-references` và toàn bộ chuỗi
> `EutrDocumentsListPoReferencesRequestDto`/`EutrDocumentsPoReferenceDto`/
> `EutrDocumentsPoReferenceItemDto`/`EutrReferencePoDocumentInfo`/
> `EutrDocumentsService.GetPoReferencesAsync`/`IEutrReferencesRepository.GetDocumentsByPoCodesAsync`/
> frontend `GetEutrDocumentsPoReferencesUseCase` **KHÔNG bị xóa** — khảo sát call site ban đầu bỏ sót
> feature khác (`eutr-sales-orders/ViewSalesOrderPage.jsx`) vẫn gọi chuỗi này để suy diễn trạng thái
> "đã map" ở Template Checklist. Phát hiện qua build thất bại khi thử xóa, đã khôi phục nguyên vẹn —
> xem research Quyết định 57 (điều chỉnh) để biết chi tiết.

### Frontend: dữ liệu Edit lấy trực tiếp từ `row` grid, 0 round-trip HTTP mới (research Quyết định 59)

`EutrDocumentsFormDialog.jsx` (đổi tên từ `EutrDocumentsAddDialog.jsx`, research Quyết định 53) mode
`edit` nhận `initialData = row` (đã có `refType`/`typeName`/`stepId`/`conditions`/`validFrom`/
`validTo` từ response `get-all` hiện có, không gọi thêm API nào):

| Trường popup | Mode `add` | Mode `edit` |
|---|---|---|
| Type | Autocomplete editable, đổi giá trị xóa hết chip | Autocomplete **disabled**, giá trị = phần tử `referenceTypes` khớp `id === initialData.refType` |
| Step | Ẩn khi `isPoType`; ngược lại bắt buộc (research Quyết định 51/60) | Ẩn khi `initialData.refType == null`; ngược lại **luôn hiện, kể cả PO** (research Quyết định 60), preselect theo `initialData.stepId` |
| Value/chip | `EutrAddValueAutocomplete` + chip có nút xóa | KHÔNG hiển thị input; chip **chỉ đọc** (không nút xóa) từ `initialData.conditions` |
| Valid from/to | Mặc định hôm nay/`9999-12-31`, editable | Nạp `initialData.validFrom`/`validTo`, editable (KHÔNG reset về mặc định) |
| Nút chính | Upload (input file ẩn) | Save (không có control file nào) |

Save (mode `edit`) gọi tuần tự: (1) `UpdateEutrDocumentsUseCase.execute({id, name: initialData.name,
validFrom, validTo})` → `PUT /api/eutr-documents/{id}` (base CRUD, không đổi contract); (2) nếu Step
đang hiển thị: `UpdateEutrDocumentReferenceStepUseCase.execute(id, stepId)` (đổi tên từ
`UpdateEutrDocumentPoStepUseCase`, research Quyết định 57) → `PUT /api/eutr-documents/{id}/step`.

### Xóa hoàn toàn trang Add cũ, popup Edit cũ, popup Assign condition (research Quyết định 53)

Xóa: `EutrDocumentsAdd.jsx`, route `/eutr/documents/add` (`MainRoutes.jsx`),
`EutrDocumentsModal.jsx`, `AssignConditionDialog.jsx`, cùng mọi use case/method chỉ dùng bởi các file
này (`AssignEutrConditionsUseCase`, `GetEutrDocumentConditionAssignmentUseCase`,
`UpdateEutrConditionAssignmentUseCase`, `GetEutrDocumentsUnassignedUseCase`,
`uploadEutrManualFilesMulti`/`executeManualMulti`) — **`GetEutrDocumentsPoReferencesUseCase` GIỮ LẠI**
(vẫn dùng bởi feature `eutr-sales-orders`, xem mục trên). Khác Update 15 (giữ `EutrDocumentsAdd.jsx`
làm dead code có chủ đích) — lần này xóa hẳn vì spec dùng từ ngữ "loại bỏ hoàn toàn khỏi phạm vi
feature" và các file này không còn tự đủ để chạy (phụ thuộc endpoint đã xóa ở trên).

### Quy tắc nghiệp vụ bổ sung (Update 19)

- `ValidFrom <= ValidTo` MUST được validate ở client trước khi Upload/Save khả dụng (FR-016); backend
  không thêm validator riêng cho 2 endpoint upload (client là điểm chặn duy nhất, xem research Quyết
  định 55).
- Document không có bản ghi `eutr_references` nào: Edit hiển thị Type/chip trống, ẩn Step, chỉ Valid
  from/Valid to khả dụng để sửa (FR-034) — Save chỉ gọi bước (1) ở trên, không gọi bước (2).
- `docs/design/eutr/eutr_documents_overview.md` (tài liệu thiết kế tĩnh) vẫn mô tả layout Screen1/
  Screen2/Assign condition cũ — **ngoài phạm vi cập nhật của kế hoạch này** (không phải artifact do
  `/speckit-plan` sinh ra); cần được đội ngũ cập nhật riêng để khớp thiết kế popup hợp nhất.

## Update 20 — Combobox Step lọc theo `eutr_reference_type_details` của Type đang chọn, mặc định chọn dòng đầu (FR-043 đến FR-045)

### Không có entity/DTO backend mới — tiêu thụ read-only bảng đã có sẵn (research Quyết định 61)

Bảng `eutr_reference_type_details` (Id, StepId, TypeId, CreatedBy, CreatedDate, UpdatedBy,
UpdatedDate) và toàn bộ entity/repository/service/controller/policy tương ứng
(`EutrReferenceTypeDetails`, `EutrReferenceTypeDetailsRepository.GetByTypeIdAsync`,
`EutrReferenceTypeDetailsController.GetByTypeId`) **đã tồn tại đầy đủ**, được xây dựng bởi feature
`006-eutr-reference-types` (Assign Steps). Feature `004-eutr-documents` chỉ đọc (read-only) endpoint
`GET /api/eutr-reference-type-details/by-type/{typeId}` đã có sẵn (xem
`contracts/eutr-documents-api.md`) — không thêm entity/DTO/repository/controller/migration nào ở
phạm vi feature này.

### `EutrReferenceTypeDetailsResponseDto` (item của response, đã có sẵn từ feature `006`)

```json
{
  "id": 5, "typeId": 3, "stepId": 12, "stepName": "Harvesting",
  "createdBy": "hien", "createdDate": "2026-07-20T10:00:00Z",
  "updatedBy": null, "updatedDate": null
}
```

- Frontend map mỗi item sang hình dạng `{ id: stepId, name: stepName }` để tương thích với
  `Autocomplete` Step hiện có (vốn nhận mảng `EutrSteps { id, name }` từ `GetEutrStepsUseCase`) —
  không đổi cấu trúc component, chỉ đổi nguồn dữ liệu nạp vào.

### Quy tắc nghiệp vụ bổ sung (Update 20)

- Mode Add: mỗi khi Type đổi, gọi lại `GetByTypeIdEutrReferenceTypeDetailsUseCase.execute(type.id)`;
  danh sách Step hiển thị = kết quả trả về (map sang `{id, name}`); nếu rỗng, combobox Step trống và
  Upload tiếp tục vô hiệu hóa (Step vẫn bắt buộc theo FR-017, Type khác "PO") — không phải lỗi hệ
  thống.
- Mode Add: ngay sau khi danh sách lọc tải xong, tự động `setStep(filteredSteps[0] ?? null)` (FR-044).
- Mode Edit: gọi 1 lần khi mở popup, dùng Type hiện tại của document (đã khóa, không đổi). Step hiện
  tại của document (xác định theo Quyết định 59 — bản ghi `Id` nhỏ nhất) MUST luôn có mặt trong danh
  sách hiển thị: nếu không nằm trong kết quả lọc (đã bị gỡ khỏi Assign Steps sau khi document được
  tạo), chèn thêm chính Step đó vào đầu mảng hiển thị — KHÔNG tự động đổi giá trị `step` đang chọn
  sang Step khác (FR-045).
- Type = "PO": không đổi — combobox Step tiếp tục ẩn hẳn (`isPoType`), không gọi API này (FR-010,
  Quyết định 51/60 không đổi).
- Document không có bản ghi `eutr_references` nào (Type/chip trống, Edit ẩn Step theo FR-034): không
  gọi API này (không có Type để xác định `typeId` lọc theo).

## Update 21 — Search box lọc danh sách theo Type/Step name/Conditions (FR-046 đến FR-050)

### `POST /api/eutr-documents/get-all` — không đổi path/request shape, mở rộng ý nghĩa 3 `Column` trong `filters`

Request body vẫn `List<FilterRequest>` (`{ column, operator, value }`, generic `Shared.Dapper`) —
search box chỉ thêm, khi có giá trị, tối đa 3 phần tử với `Column` ∈ `{"TypeId", "StepId",
"Conditions"}`:

```json
[
  { "column": "TypeId", "operator": "=", "value": 3 },
  { "column": "StepId", "operator": "=", "value": 12 },
  { "column": "Conditions", "operator": "like", "value": "PO0001" }
]
```

- 3 `Column` này **không tồn tại** trên entity `EutrDocuments` — nếu để nguyên trong `filters` và gọi
  thẳng repository generic, chúng sẽ bị **âm thầm bỏ qua** (whitelist property của `TEntity`, xem
  research Quyết định 62). `EutrDocumentsService.GetPagedAsync` MUST rút 3 phần tử này ra khỏi
  `request.Filters` (so khớp `Column` không phân biệt hoa/thường) **trước** khi gọi
  `base.GetPagedAsync`, đọc `typeId`/`stepId`/`conditionsQuery` từ `Value` của chúng (bỏ qua
  `Operator` gửi lên — service tự áp dụng đúng ngữ nghĩa `=`/`like` tương ứng ở bước dưới).
- Không cung cấp bất kỳ phần tử nào trong 3 tên cột trên → hành vi `get-all` **không đổi** so với
  trước Update 21 (không gọi thêm truy vấn nào, không ảnh hưởng hiệu năng của các màn hình/luồng khác
  đang gọi endpoint này).

### `IEutrReferencesRepository.GetMatchingDocumentIdsAsync` — method mới, đọc-only

```csharp
Task<List<long>> GetMatchingDocumentIdsAsync(
    long? typeId, long? stepId, string? conditionsQuery, CancellationToken ct = default);
```

SQL (xem research Quyết định 63 cho lý do dùng 3 `EXISTS` độc lập thay vì 1 JOIN cùng dòng):

```sql
SELECT d.Id
FROM eutr_documents d
WHERE (@typeId IS NULL OR EXISTS (
        SELECT 1 FROM eutr_references r WHERE r.DocumentId = d.Id AND r.RefType = @typeId))
  AND (@stepId IS NULL OR EXISTS (
        SELECT 1 FROM eutr_references r WHERE r.DocumentId = d.Id AND r.StepId = @stepId))
  AND (@conditionsQuery IS NULL OR EXISTS (
        SELECT 1 FROM eutr_references r WHERE r.DocumentId = d.Id
          AND r.RefValue LIKE CONCAT('%', @conditionsQuery, '%')));
```

- Mỗi tham số `null` vô hiệu hóa điều kiện `EXISTS` tương ứng (luôn đúng) — 0, 1, 2, hoặc cả 3 điều
  kiện có thể áp dụng đồng thời, độc lập với nhau.
- `@typeId` so khớp `RefType` (`TINYINT`) — ép kiểu ở service trước khi gọi (`(byte)typeId.Value`),
  cùng quy ước đã dùng từ Update 15/18. Không tra `eutr_reference_types` ở đây — `typeId` là `Id` gửi
  thẳng từ dropdown Type của search box (đã tải qua `GetEutrReferenceTypesUseCase`, cùng nguồn dữ liệu
  dùng ở popup Add).
- `@conditionsQuery` là chuỗi tìm kiếm thô (không phải pattern) — khớp kiểu "chứa", không phân biệt
  hoa/thường (theo collation mặc định của schema, cùng giả định đã dùng ở Quyết định 17).

### `EutrDocumentsService.GetPagedAsync` — luồng xử lý đầy đủ (mở rộng, không đổi chữ ký public)

```csharp
public override async Task<PagedResult<EutrDocumentsResponseDto>> GetPagedAsync(
    PagedRequest request, CancellationToken ct = default)
{
    var (typeId, stepId, conditionsQuery) = ExtractSearchBoxFilters(request.Filters); // rut 3 filter ao

    if (typeId.HasValue || stepId.HasValue || conditionsQuery != null)
    {
        var matchingIds = await _referencesRepository.GetMatchingDocumentIdsAsync(
            typeId, stepId, conditionsQuery, ct);

        if (matchingIds.Count == 0)
            return new PagedResult<EutrDocumentsResponseDto> { Items = [], TotalCount = 0 };

        request.Filters.Add(new FilterRequest
        {
            Column = "Id", Operator = "in", Value = string.Join(",", matchingIds)
        });
    }

    var pagedResult = await base.GetPagedAsync(request, ct);
    var responseItems = _mapper.Map<List<EutrDocumentsResponseDto>>(pagedResult.Items);
    await AttachStepAndConditionInfoAsync(responseItems, ct);
    return new PagedResult<EutrDocumentsResponseDto>
    { Items = responseItems, TotalCount = pagedResult.TotalCount };
}
```

- `matchingIds.Count == 0` → trả `PagedResult` rỗng **ngay**, không gọi `base.GetPagedAsync` (tránh 1
  truy vấn phân trang thừa khi chắc chắn không có kết quả nào) — khớp Acceptance Scenario "không có
  document nào khớp điều kiện → hiển thị No data" (spec User Story 6, kịch bản 6).
  `FilterRequest { Column = "Id", Operator = "in", ... }` tái dùng **nguyên vẹn** cơ chế `in` đã có sẵn
  của generic repository (`Id` đã nằm trong whitelist cột filter/sắp xếp mặc định của
  `EutrDocuments`, xem `contracts/eutr-documents-api.md` mục `FilterRequest`) — không cần thêm logic
  filter tùy biến nào ở tầng repository generic.
- Các filter khác (nếu có, ví dụ người dùng đồng thời dùng filter cột của DataGrid) tiếp tục đi qua
  `base.GetPagedAsync` như trước, không bị ảnh hưởng bởi bước rút/thêm filter ảo này.

### Không có entity/DTO/migration mới

Toàn bộ Update 21 chỉ thêm 1 method repository (đọc-only) + mở rộng logic nội bộ 1 method service đã
có — không có bảng/cột mới, không có DTO request/response mới, `EutrDocumentsResponseDto` không đổi.

## Update 22 — Edit cho phép thêm/xóa chip Value khi Type khác "PO" (FR-051 đến FR-055)

Không migration DB mới (mọi cột — `RefValue`, `StepId`, `RefType` — đã tồn tại từ Update 7/14); không
entity/endpoint mới — mở rộng đúng 1 DTO + 1 method service + 2 method repository của
`PUT /api/eutr-documents/{id}/step` (Update 19). Xem research Quyết định 65-67 cho lý do từng quyết
định.

### `EutrUpdateReferenceStepRequestDto` — thêm 1 field nullable

```csharp
public class EutrUpdateReferenceStepRequestDto
{
    public long StepId { get; set; }
    public List<string>? RefValues { get; set; }   // MỚI, Update 22 — null = giữ hành vi cũ (chỉ update StepId)
}
```

```json
{ "stepId": 12, "refValues": ["PO000123", "PO000456"] }
```

- `RefValues = null` (hoặc field vắng mặt trong body): Type = "PO", hoặc client cũ chưa gửi field này
  — hành vi backend **không đổi** so với Update 19 (chỉ `UPDATE StepId`, không transaction, không đối
  chiếu).
- `RefValues` có giá trị (kể cả mảng rỗng `[]`, xem quy tắc chặn ở FR-054/spec edge case — client
  MUST không cho Save với 0 chip nên trường hợp `[]` không nên xảy ra trong thực tế, nhưng backend vẫn
  xử lý đúng nếu xảy ra: xóa hết mọi `RefValue` hiện có, giữ 0 dòng `eutr_references` cho document —
  không có validator server-side riêng chặn mảng rỗng, client là điểm chặn duy nhất, cùng nguyên tắc đã
  áp dụng cho `ValidFrom <= ValidTo` ở Update 19): kích hoạt bước đối chiếu bên dưới.

### `EutrDocumentsService.UpdateReferenceStepAsync` — mở rộng chữ ký, thêm nhánh đối chiếu

```csharp
public async Task UpdateReferenceStepAsync(
    long documentId, long stepId, List<string>? refValues, string userEmail, CancellationToken ct = default)
{
    ArgumentException.ThrowIfNullOrWhiteSpace(userEmail);

    if (refValues == null)
    {
        // Khong doi so voi Update 19 - Type = "PO" hoac client cu
        await _referencesRepository.UpdateStepIdByDocumentIdAsync(documentId, stepId, userEmail, ct);
        return;
    }

    await _unitOfWork.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
    try
    {
        var existingRows = await _referencesRepository.GetStepInfoByDocumentIdsAsync([documentId], ct);
        var existingValues = existingRows
            .Select(r => r.RefValue)
            .Where(v => !string.IsNullOrEmpty(v))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
        var refType = existingRows.Select(r => r.RefType).FirstOrDefault(t => t.HasValue);

        var toAdd = refValues.Except(existingValues, StringComparer.OrdinalIgnoreCase).ToList();
        var toRemove = existingValues.Except(refValues, StringComparer.OrdinalIgnoreCase).ToList();

        if (toRemove.Count > 0)
            await _referencesRepository.DeleteByDocumentIdAndRefValuesAsync(documentId, toRemove, ct);

        if (toAdd.Count > 0 && refType.HasValue)
            await _referencesRepository.AddReferencesAsync(documentId, stepId, refType.Value, toAdd, userEmail, ct);

        await _referencesRepository.UpdateStepIdByDocumentIdAsync(documentId, stepId, userEmail, ct);

        await _unitOfWork.CommitAsync(ct);
    }
    catch
    {
        await _unitOfWork.RollbackAsync(ct);
        throw;
    }
}
```

- **Nguồn đọc trạng thái hiện có**: tái dùng nguyên vẹn `GetStepInfoByDocumentIdsAsync` (Update 8/14/19)
  — projection đã có sẵn `RefValue`/`RefType` theo từng dòng `eutr_references`, không cần thêm method
  đọc mới. `refType` lấy từ dòng đầu tiên có giá trị (mọi dòng của cùng document luôn cùng `RefType`,
  bất biến đã có từ Update 7 — Type bị khóa ở Edit nên không đổi giữa các dòng).
- **So sánh không phân biệt hoa/thường** (`StringComparer.OrdinalIgnoreCase`) — nhất quán với cách
  validate giá trị gõ tay ở Value combobox (FR-012) và validate prefix PO (FR-020).
- Thứ tự bước: xóa trước, thêm sau, cập nhật `StepId` cuối cùng — đảm bảo bước cuối áp dụng cho **mọi**
  dòng còn tồn tại (kể cả dòng vừa thêm), khớp đúng FR-052(c).
- Toàn bộ gói trong 1 transaction mới (`_unitOfWork`, cùng mẫu `DeleteAsync`/`DeleteMultiAsync` của
  Update 9) — nếu bất kỳ bước nào lỗi (ví dụ lỗi kết nối giữa lúc xóa và thêm), `RollbackAsync` khiến
  toàn bộ lượt Save đó không để lại thay đổi một phần.

### `IEutrReferencesRepository` — 2 method ghi mới

```csharp
Task DeleteByDocumentIdAndRefValuesAsync(
    long documentId, IEnumerable<string> refValues, CancellationToken ct = default);

Task AddReferencesAsync(
    long documentId, long stepId, byte refType, IEnumerable<string> refValues, string createdBy,
    CancellationToken ct = default);
```

`DeleteByDocumentIdAndRefValuesAsync` — raw SQL, dọn kèm `eutr_reference_details` mồ côi trước (cùng
mẫu 2 bước phòng thủ của `DeleteByDocumentIdAsync`, Update 11/research Quyết định 30, cho dữ liệu lịch
sử vẫn có thể còn liên kết qua `RefId`):

```sql
DELETE FROM eutr_reference_details
WHERE RefId IN (
  SELECT Id FROM eutr_references WHERE DocumentId = @DocumentId AND RefValue IN @RefValues);
DELETE FROM eutr_references WHERE DocumentId = @DocumentId AND RefValue IN @RefValues;
```

`AddReferencesAsync` — raw SQL INSERT, thực thi 1 lần cho cả tập `refValues` (Dapper multi-exec, mỗi
phần tử 1 bộ tham số):

```sql
INSERT INTO eutr_references (DocumentId, StepId, RefType, RefValue, CreatedBy, CreatedDate, UpdatedBy, UpdatedDate)
VALUES (@DocumentId, @StepId, @RefType, @RefValue, @CreatedBy, @Now, @CreatedBy, @Now);
```

- Cả hai chạy trong `Transaction` do `EutrDocumentsService` mở (tham số `transaction:` truyền vào
  `Connection.ExecuteAsync`, cùng style đã dùng ở `UpdateStepIdByDocumentIdAsync`/
  `DeleteByDocumentIdAsync`).
- `AddReferencesAsync` KHÔNG ghi `RefId` (cột này không được ghi bởi bất kỳ luồng nào của feature này,
  bất biến từ Update 7) — cùng shape với đường ghi hiện có trong `EutrUploadService` (Add mode).

### Frontend — payload `refValues` gửi kèm `stepId`, tái dùng helper `toRefValue` có sẵn

```js
// EutrDocumentsFormDialog.jsx, handleSave (mode edit)
const refValues = showEditableChips ? chips.map(toRefValue) : undefined;
if (showStep && step) {
  await updateEutrDocumentReferenceStepUseCase.execute(initialData.id, step.id, refValues);
}
```

`showEditableChips = isEdit && initialData?.refType != null && !isPoType` — cùng cách tính với
`showStep` đã có (Update 19), chỉ thêm điều kiện `!isPoType`. `toRefValue` là helper đã tồn tại sẵn
trong file này (dùng để build `refValues: string[]` cho request Upload ở mode `add`) — không viết hàm
mới, tái dùng nguyên vẹn để đảm bảo cùng quy tắc trích xuất giá trị chip (chip có thể là `string` hoặc
`{ id, code, name }` tùy nguồn gợi ý) giữa Add và Edit.

### Quy tắc nghiệp vụ bổ sung (Update 22)

- Vùng chip Value ở Edit MUST còn lại ít nhất 1 chip tại thời điểm Save khi `showEditableChips` — chặn
  ở **client** (`canSubmit` thêm điều kiện `!showEditableChips || chips.length > 0`), không có
  validator server-side riêng cho ràng buộc này (cùng nguyên tắc "client là điểm chặn duy nhất" đã áp
  dụng cho `ValidFrom <= ValidTo`, Update 19) — xem mục "`RefValues` có giá trị" ở trên cho hành vi
  backend nếu client vẫn gửi mảng rỗng.
- Type = "Vendor" tiếp tục giới hạn tối đa 1 chip trong Edit — kế thừa **miễn phí** từ
  `EutrAddValueAutocomplete.jsx` (không có logic giới hạn chip nào mới ở tầng dialog hay backend).
- Type = "PO": `RefValues` luôn gửi `undefined`/không có trong request — hành vi Save với Type = "PO"
  không đổi so với Update 19 (chỉ `UPDATE StepId`, giữ nguyên toàn bộ `RefValue`/`RefType`/số lượng bản
  ghi).
