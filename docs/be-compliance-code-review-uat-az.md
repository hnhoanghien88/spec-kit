# Code review: compliance-sys-api, nhánh `uat-az`

- **Phạm vi:** `origin/uat-az` @ `f83fc44`. Gồm các commit EUTR `a3ac76d`, `34f4a05`, `959f574` (có cả tính năng compl-missing-detail).
- **Ngày review:** 06/10/2026
- **Số dòng** trong tài liệu lấy theo `origin/uat-az`.

## Tổng hợp

| # | Vấn đề | Khu vực | Mức độ |
|---|---|---|---|
| 1 | Job purchase missing chỉ tìm folder trong `/PO`, các PO cũ bị báo "No PO folder" | EUTR | Đã xác nhận |
| 2 | `PageSize = purchIds.Count` làm sót vendor code | EUTR | Có khả năng |
| 3 | Kiểm tra trùng tên template chặn Edit khi DB đã có sẵn tên trùng | EUTR | Có khả năng |
| 4 | Refresh missing-detail chạy cùng lúc job alert, email alert bị thiếu dòng | Compl missing detail | Đã xác nhận (khi trùng thời điểm) |
| 5 | Xoá rồi chèn snapshot không có transaction; lệch collation có thể làm bảng trống | Compl missing detail | Có khả năng |
| 6 | Lỗi nhỏ: GET có tác dụng phụ, `PageSize` không giới hạn, comment sai | Compl missing detail | Thấp |

---

## 1. Job purchase missing chỉ tìm folder PO trong `/PO`

**File:** `src/ComplianceSys.Application/Services/EutrSynchronizeDataService.cs:270`
**Mức độ:** Đã xác nhận

```csharp
var poGroupPath = $"{basePath.TrimEnd('/')}/{PoGroupFolderName}";
var folders = await _sharepointService.GetFolders(poGroupPath);
```

Job giờ chỉ tìm folder PO trong `{SharePointEutrPath}/PO`. Trong code không có bước nào chuyển các folder PO cũ (đang nằm trực tiếp dưới `SharePointEutrPath`) vào `/PO`.

**Hậu quả sau khi deploy:**
- Mọi PO cũ có template đều bị đánh dấu "No PO folder", được ghi vào `eutr_purchase_missing` và gửi mail cảnh báo sai.
- Các PO này bị bỏ qua bước kiểm tra step.
- Nếu folder `PO` chưa tồn tại và lệnh `GetFolders` bị lỗi thì cả job dừng.

**Đề xuất:**
- Viết script chuyển folder cũ vào `/PO` và chạy trước khi deploy, hoặc
- Tạm thời tìm ở cả hai chỗ (`/PO` và `basePath`), và xử lý trường hợp chưa có folder `PO`.

---

## 2. `PageSize = purchIds.Count` có thể làm sót vendor code

**File:** `src/ComplianceSys.Application/Services/EutrProgressionService.cs:192`
**Mức độ:** Có khả năng (cần xác nhận bằng dữ liệu thật)

Khi lấy vendor code từ D365 (`RSVNEutrSalesOrderPurchases`), code chỉ xin số row bằng số PO. View này trả về mỗi dòng hàng một row (có cột Qty), nên một PO nhiều dòng có thể chiếm hết trang và đẩy các PO khác ra ngoài.

**Hậu quả:** các PO bị đẩy ra không có vendor code, nên tài liệu loại Vendor của chúng không được đếm. Tiến độ lưu trong DB sẽ thấp hơn số liệu trên màn hình View / Map File.

**Đề xuất:** phân trang cho tới khi lấy hết dữ liệu, hoặc dùng PageSize đủ lớn rồi `GroupBy(PurchId)`.

---

## 3. Kiểm tra trùng tên template chặn cả Edit không đổi tên

**File:** `src/ComplianceSys.Application/Services/EutrTemplatesService.cs:148`
**Mức độ:** Có khả năng

```csharp
await EnsureNameNotDuplicateAsync(dto.Name, ct, existing.Code);
```

`UpdateAsync` giờ kiểm tra trùng tên mỗi lần Edit, kể cả khi `Name` không đổi. Nếu DB đã có 2 template khác `Code` mà trùng tên (tạo trước khi có rule này), thì Edit template nào trong hai cũng bị lỗi *"Template name ... already exists"*.

**Kiểm tra dữ liệu trước khi deploy:**

```sql
SELECT LOWER(TRIM(Name)) AS name_key, COUNT(DISTINCT Code) AS codes
FROM eutr_templates
WHERE IsDeleted = 0
GROUP BY name_key
HAVING COUNT(DISTINCT Code) > 1;
```

**Đề xuất:**
- Chỉ gọi `EnsureNameNotDuplicateAsync` khi tên thực sự thay đổi (so sánh sau khi Trim, không phân biệt hoa/thường).
- Bước kiểm tra chạy ngoài transaction, nên hai người tạo cùng tên gần như cùng lúc vẫn lọt được. Muốn chặn hẳn thì cần thêm unique index trong DB.

---

## 4. Refresh missing-detail chạy cùng lúc job alert, email alert bị thiếu dòng

**File:**
- `src/ComplianceSys.Application/Services/ComplMissingDetailRefreshService.cs:182`
- `src/ComplianceSys.Application/Services/ComplNotificationService.cs:202`, `:318`

**Mức độ:** Đã xác nhận (xảy ra khi hai job trùng thời điểm)

Cả hai job đều xoá toàn bộ bảng `compl_so_missing` rồi ghi lại từng SO (mất vài giờ). Riêng job alert sau đó đọc toàn bộ bảng để gửi email.

Hai job dùng 2 khoá khác nhau:
- Job mới: `static SemaphoreSlim RunLock` và `[DisableConcurrentExecution]` trên `IComplMissingDetailRefreshService`.
- Job alert: không dùng khoá chung với job mới.

Vì vậy không có gì ngăn chúng chạy song song.

**Tình huống lỗi:** job alert đang ghi `compl_so_missing`, đúng lúc người dùng bấm Refresh trên màn hình Compliance missing detail. Job mới gọi `DeleteAllAsync` và xoá các dòng job alert đã ghi, nên job alert đọc thiếu dữ liệu và **gửi email alert thiếu dòng**. Snapshot `compl_missing_detail` cũng bị lệch theo.

Comment trong controller có ghi "Không chạy cùng lúc với job alert", nhưng code không chặn, trong khi endpoint mở cho người dùng bấm bất cứ lúc nào.

**Đề xuất (chọn một):**
- Dùng chung một distributed lock (Hangfire `IStorageConnection.AcquireDistributedLock` cùng tên) cho cả hai job. Nếu đang có job chạy thì bỏ qua hoặc xếp hàng.
- Cho job mới ghi vào bảng tạm riêng, không dùng chung `compl_so_missing`.

---

## 5. Xoá rồi chèn snapshot không có transaction; lệch collation có thể làm bảng trống

**File:**
- `src/ComplianceSys.Application/Services/ComplMissingDetailRefreshService.cs:91-93` (xoá/chèn)
- `src/ComplianceSys.Application/Services/ComplMissingDetailRefreshService.cs:128` (gom nhóm)
- `src/ComplianceSys.Application/Services/ComplMissingDetailSearchService.cs:131` (ghép note)

**Mức độ:** Có khả năng

```csharp
await _detailRepository.DeleteAllAsync(ct);
await _detailRepository.InsertManyAsync(detailRows, ct);
```

Bước 3 xoá rồi chèn mà **không có transaction**. Nếu insert lỗi giữa chừng, `compl_missing_detail` sẽ trống hoặc thiếu dòng cho tới lần chạy sau.

**Một nguyên nhân cụ thể làm insert lỗi:**
- C# gom nhóm bằng `StringComparer.OrdinalIgnoreCase`, chỉ bỏ qua hoa/thường.
- Bảng dùng `utf8mb4_0900_ai_ci`, bỏ qua **cả dấu** (và một số ký tự như `ß` = `ss`).
- Ví dụ `MappedInputValue` có cả `Việt Nam` và `Viet Nam`: C# coi là 2 nhóm, nhưng DB coi là trùng `ux_missing_detail_key`. Insert báo lỗi duplicate key, và mọi dòng sau đó không được ghi.

**Hệ quả phụ:** `GetByKeysAsync` dùng SQL nên tìm được note theo kiểu bỏ qua dấu, nhưng bước ghép trong bộ nhớ (`BuildKey` + `OrdinalIgnoreCase`) không khớp, nên note không hiện trên grid hay trong file export.

**Đề xuất:**
- Bọc bước 3 trong transaction qua `IUnitOfWork`. Bước này nhanh, không cần xem tiến độ như bước 1.
- Đồng bộ quy tắc so sánh giữa C# và DB:
  - đổi collation các cột khoá sang `utf8mb4_0900_as_ci` hoặc `utf8mb4_bin`, **hoặc**
  - gom nhóm và ghép note trong C# theo cùng quy tắc bỏ qua dấu (ví dụ `CompareInfo` với `CompareOptions.IgnoreCase | IgnoreNonSpace`).

---

## 6. Lỗi nhỏ

| File | Vấn đề | Đề xuất |
|---|---|---|
| `ComplMissingDetailController.cs:53` | `[HttpGet("test-compliance-missing")]` khởi chạy job dài nhiều giờ. GET có tác dụng phụ nên dễ bị gọi nhầm khi prefetch hoặc reload. | Đổi sang `POST`, bỏ chữ "test" trong route. |
| `ComplMissingDetailRepository.cs:92` | `PageSize` không có giới hạn trên. Client gửi `pageSize=1000000` là kéo về toàn bộ bảng. | Giới hạn, ví dụ `Math.Min(pageSize, 500)`. |
| `ComplMissingDetail.cs`, `Sqls/Tables/compl_missing_detail.sql`, `IComplMissingDetailRepository.cs` | Comment ghi "xoá rồi chèn trong 1 transaction", nhưng service cố ý không dùng transaction. | Sửa comment, hoặc thêm transaction theo mục 5. |
