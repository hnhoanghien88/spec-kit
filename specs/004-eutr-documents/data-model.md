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
  "refType": 0
}
```

- `stepNames`: `List<string>` — tên các Step (JOIN `eutr_steps.Name` theo `StepId`) của mọi bản ghi
  `eutr_references` có `DocumentId` = `Id` của document này; `[]` nếu không có bản ghi nào.
- `refType`: `byte?` — giá trị `RefType` của các bản ghi đó (giống nhau trên mọi bản ghi cùng
  `DocumentId`, theo FR-033/Update 7); `null` nếu không có bản ghi nào. Frontend map sang nhãn hiển
  thị qua `TAKE_FROM_OPTIONS` (`0` → "PO", `1` → "Upload manual") — backend KHÔNG trả nhãn đã dịch
  sẵn, giữ đúng tinh thần "PO name" ở List PO (backend trả mã, frontend map nhãn).
- Nguồn dữ liệu: `EutrReferencesRepository.GetStepInfoByDocumentIdsAsync(documentIds)` (SQL JOIN
  `eutr_references`+`eutr_steps`, `WHERE DocumentId IN @DocumentIds`) — xem research Quyết định 20.
  `EutrDocumentsService.GetPagedAsync` gọi method này với `Id` của mọi document trong trang hiện
  tại, group theo `DocumentId`, rồi gán vào `StepNames`/`RefType` của từng `EutrDocumentsResponseDto`
  tương ứng — clone mẫu `ComplCountryGroupService.AttachMembersAsync`.

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

- `EutrReferenceStepInfo { long DocumentId; string? StepName; byte? RefType; }` — projection phẳng,
  không phải entity `EutrReferences` đầy đủ (không cần `Id`/`RefId`/`RefValue` cho mục đích này).
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
{ "files": ["<binary>", "<binary>"], "poCode": "PO000123" }
```

- `files`: bắt buộc ít nhất 1 file (`400` nếu rỗng, cùng validate với `upload-multi` hiện có).
- `poCode`: bắt buộc, không rỗng (`400` nếu thiếu) — giá trị `code` của PO đang chọn ở List PO
  (tương ứng `PurchId` từ `RSVNEutrPurchOrders`, refType 15).

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
   EutrReferences { DocumentId = documentId, StepId = stepId, RefType = 0, RefValue = poCode })`.
4. `CommitAsync()`. Nếu bất kỳ bước 2-3 nào throw → `RollbackAsync()` — **toàn bộ** (cả
   `eutr_documents` lẫn mọi `eutr_references` đã insert trong bước 3 của file này) bị hủy; file đó
   được báo `success: false` trong kết quả trả về (không để lại document "mồ côi" không có
   `eutr_references`).
- `RefType` luôn là `0` (giá trị "PO" của `TAKE_FROM_OPTIONS` phía frontend) vì khu Upload thật chỉ
  tồn tại ở Screen1 (Type = PO) — không có nhánh nào ghi `RefType = 1` trong phạm vi feature này.
- `RefValue` = `poCode` (cùng giá trị dùng để suy ra thư mục SharePoint, xem mục "Suy ra thư mục
  SharePoint từ `poCode`" ở trên) — giống nhau trên mọi dòng `eutr_references` của cùng file.
- Ví dụ: file `"INV2026_report.pdf"` khớp 2 bản ghi `eutr_master_documents` (`Prefix = "INV"`,
  `StepId = 5` và `Prefix = "INV2026"`, `StepId = 7`) → tạo 1 dòng `eutr_documents` (`Id = 501`) và
  2 dòng `eutr_references`: `{ DocumentId: 501, StepId: 5, RefType: 0, RefValue: "PO000123" }` và
  `{ DocumentId: 501, StepId: 7, RefType: 0, RefValue: "PO000123" }`.
