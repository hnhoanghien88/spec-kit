# Research: Compliance Missing Detail

## R1 — Nguồn dữ liệu của màn hình

- **Decision**: Snapshot bảng `compl_missing_detail`, sinh bởi trigger `GET api/compl-missing-detail/test-compliance-missing`; màn hình chỉ SELECT từ bảng này (FR-004).
- **Rationale**: Yêu cầu của người dùng (Update 2026-10-05). Đánh giá theo open SO nặng (gọi D365 + SP cho từng SO), nên tách khỏi đường đọc của màn hình (SC-002).
- **Alternatives**: Query live từ masters/references/compliances (phương án trước, đã bị thay thế); Hangfire job tự chạy (ngoài phạm vi, có thể thêm sau vì service refresh tách riêng).

## R2 — Tái dùng logic refresh mà không sửa code cũ

- **Decision**: `ComplMissingDetailRefreshService` chứa **bản copy** của `RefreshSalesOrderMissingComplianceAsync` + `BuildCurrentSalesOrderAlertComplianceListAsync` + `MapToComplSoMissing` (đều `private` trong `ComplNotificationService`). Nó gọi nguyên trạng `IComplDynamicsService.GetDynRefePagedAsync(SALE_ORDER_OPEN)`, `IViewCompliancesService.GetViewCompliancesAsync(...)` và `IComplSoMissingRepository` (DeleteAll/InsertMany/GetAll). Không có `SendMailAndNotification*`, không `NotifyJobSuccess`.
- **Rationale**: FR-006, FR-015; copy giữ đúng quy tắc 009 (kể cả fallback ngày check theo InvoiceDate như code hiện tại).
- **Alternatives**: Đổi hàm cũ thành `public` hoặc tách helper dùng chung — chạm code đang chạy.

## R3 — Dùng chung `compl_so_missing` làm vùng trung gian

- **Decision**: Chấp nhận như yêu cầu: trigger xóa-và-ghi-lại `compl_so_missing`. Giảm rủi ro bằng: (a) trigger mới khóa chạy đơn (một lần tại một thời điểm, `SemaphoreSlim`/cờ trong service singleton-scoped static) để hai lần gọi trigger mới không chồng nhau; (b) ghi chú trong API doc là không chạy cùng lúc với `test-sales-order-alert*`/job alert; (c) màn hình không đọc `compl_so_missing` nên không bị đọc dở.
- **Rationale**: Không thể tránh nếu bắt buộc chạy "hàm refresh" ghi vào `compl_so_missing`; alert cũ tự xóa-và-ghi-lại ở đầu mỗi lần chạy nên vẫn tự nhất quán sau đó.
- **Rủi ro còn lại**: Nếu alert cũ đang đọc `GetAllAsync` đúng lúc trigger mới xóa bảng, alert đó có thể gửi thiếu dòng. Cần lên lịch tránh giờ chạy alert.
- **Alternatives**: Dùng bảng làm việc riêng (`compl_missing_detail_work`) — an toàn hơn nhưng khác yêu cầu "ghi vào compl_so_missing"; có thể đề xuất sau.

## R4 — Group và chuẩn hóa khóa

- **Decision**: Group theo `(MasterCode, Code, MappedRefTypeCode, MappedInputValue)` với `null → ''` và `Trim()`; lấy dòng đầu mỗi nhóm; bỏ SalesId. Lưu vào `compl_missing_detail` có khóa UNIQUE trên 4 cột này (các cột khóa `NOT NULL DEFAULT ''`).
- **Rationale**: FR-007, FR-014; khóa UNIQUE bảo vệ khỏi bản ghi trùng; chuẩn hóa tránh hai dòng khác nhau chỉ vì `NULL` vs `''` (khác code cũ chỉ ở điểm này, có lợi cho FR-014).

## R5 — Thay snapshot không dùng transaction

- **Decision**: Không dùng transaction (yêu cầu 2026-10-05, để nhìn `compl_so_missing` biết run tới SO nào). Giai đoạn đánh giá chạy trước và ghi `compl_so_missing` từng SO (autocommit); sau đó `DELETE FROM compl_missing_detail` → insert theo lô 500. Lỗi ở giai đoạn đánh giá giữ nguyên snapshot cũ; lỗi giữa xóa và chèn có thể để bảng rỗng/thiếu tới lần chạy sau (rủi ro chấp nhận). Lỗi từng SO lẻ vẫn bị bắt, ghi log, đếm `SalesOrdersFailed`.
- **Rationale**: FR-008, US1-5. Lỗi từng sales order lẻ vẫn bị bắt và bỏ qua như logic gốc (ghi log, đếm `FailedSalesOrderCount` trả về trong response); lỗi toàn cục (xóa, phân trang D365, ghi DB) làm trigger thất bại và snapshot cũ giữ nguyên.

## R6 — Status/DaysRemaining tính lúc đọc

- **Decision**: SQL lọc/sort: `Status = CASE WHEN Code = '' THEN 'Missing' WHEN ValidTo IS NOT NULL AND ValidTo < CURDATE() THEN 'Expired' END`; dòng NULL (không Missing/Expired) bị loại bằng WHERE. `DaysRemaining` và email trách nhiệm tính trong service khi map DTO (copy helper `ComputeSoMissingStatus` / parse `ResponsibleGroupsJson` của `ComplSoMissingReportJobService` dạng bản sao).
- **Rationale**: FR-013; spec 009 yêu cầu Status tính từ Code/ValidTo thay vì copy giá trị lưu.
- **Alternatives**: Lưu sẵn Status/DaysRemaining — sẽ lệch qua ngày.

## R7 — Ghi chú

- **Decision**: Bảng `compl_missing_detail_note`, UNIQUE (MasterCode, Code, MappedRefTypeCode, MappedInputValue), NOT NULL DEFAULT ''. Join trong tầng Application theo khóa chuẩn hóa (một truy vấn cho cả trang), tồn tại qua các lần thay snapshot (SC-007).
- **Rationale**: FR-009/FR-014; cùng bài học NULL-trong-UNIQUE của note cũ.

## R8 — Bộ lọc

- **Decision**: Bỏ Year/Week. Filter/sort DataGrid gửi lên server với whitelist cột: `MasterCode, MasterName, Status, Code, Name, MappedRefTypeCode, MappedInputValue, ValidFrom, ValidTo`; cột ngoài whitelist → 400.
- **Rationale**: FR-002/FR-003; tránh SQL injection ở sort/filter (repo cũ dùng whitelist tương tự).

## R9 — Phân quyền, menu, trigger

- **Decision**: Resource `ComplianceMissingDetail` với permission `ViewMenu`, `ReadAll`, `Download`, `Update`; trigger dùng policy `ComplianceMissingDetail.Update` (ghi/thay dữ liệu). Menu code `compliance-missing-detail`, url `/compliance-missing`, parent `compliance-new`. Menu/quyền (kể cả đổi url màn cũ) do app khác cập nhật, repo không có migration cho phần này.
- **Rationale**: FR-011/FR-012; route FE khớp theo `menus.Url` từ backend, component theo `code`.
- **Alternatives**: Permission riêng `Refresh` (rõ ràng hơn nhưng thêm bước cấp quyền); `[AllowAnonymous]` như một số endpoint test (không chấp nhận được vì ghi dữ liệu).

## R10 — Trigger chạy đồng bộ

- **Decision**: GET chạy đồng bộ như `test-sales-order-alert`, trả `ApiResponse` với số dòng ghi và số SO lỗi. Hỗ trợ `CancellationToken`.
- **Rationale**: Khớp mẫu hiện có và yêu cầu "service [HttpGet]". Nếu timeout HTTP thành vấn đề thì chuyển sang Hangfire (service đã tách riêng nên dễ).
