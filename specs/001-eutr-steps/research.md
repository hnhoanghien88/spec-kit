# Research: EUTR Steps Management

Phase 0 — giải quyết các điểm chưa rõ. Vì backend đã tồn tại và có mẫu frontend `document-type`,
không còn NEEDS CLARIFICATION nào tồn đọng.

## Quyết định 1 — Tái sử dụng backend `api/eutr-steps`

- **Decision**: Bind frontend vào các endpoint sẵn có, không viết lại backend.
- **Rationale**: `EutrStepsController` đã cung cấp đủ GET (list/by-id), POST `get-all` (phân
  trang/lọc/sắp xếp), POST (tạo), PUT (sửa), DELETE (xóa), POST `delete-multi`. Có sẵn policy
  quyền và validator. Viết lại sẽ vi phạm Nguyên tắc III và rủi ro lệch hợp đồng/DB.
- **Alternatives considered**: Tự sinh lại controller/service — bị loại vì trùng lặp và rủi ro.

## Quyết định 2 — Clone mẫu `document-type`

- **Decision**: Sao chép cấu trúc đầy đủ của feature `document-type` qua mọi tầng và đổi tên.
- **Rationale**: Đây là CRUD cùng dạng, đã hoạt động, đúng convention (DI, hook DataGrid server
  mode, modal, confirm dialog, permission từ menu). Nguyên tắc II yêu cầu dùng mẫu tham chiếu.
- **Alternatives considered**: Thiết kế mới từ đầu — bị loại vì dễ lệch convention.

## Quyết định 3 — Cột "Prefix" là slug suy ra từ Name

- **Decision**: Tính `prefix` ở client bằng cách slug hóa `name` (bỏ dấu, thường hóa, thay khoảng
  trắng bằng `-`), chỉ để hiển thị; KHÔNG gửi lên backend.
- **Rationale**: Thực thể backend `EutrStep` chỉ có `Name` (+ trường audit), không có cột prefix.
  Thiết kế `design/eutr_steps.md` hiển thị prefix dạng `bien-ban-giao-nhan...` đúng kiểu slug.
- **Alternatives considered**: (a) Thêm cột prefix vào backend — bị loại vì vi phạm Nguyên tắc
  III và vượt phạm vi; (b) Bỏ hẳn cột — bị loại vì design yêu cầu hiển thị.

## Quyết định 4 — Quyền theo menu + policy

- **Decision**: Lấy `permissionList` từ menu (`getMenuDataFromStorage`, code `eutr-steps`) như mẫu
  `document-type`; nút Create/Update/Delete hiển thị theo quyền. Backend vẫn chặn bằng policy
  `EutrSteps.*`.
- **Rationale**: Đồng nhất với mẫu hiện hữu (Nguyên tắc V) và bảo vệ hai lớp (UI + API).

## Quyết định 5 — Sắp xếp/lọc/phân trang server-side

- **Decision**: Dùng `DataGrid` server mode + hook `useEutrStepData` gọi `GetPagingEutrStepsUseCase`,
  payload lọc qua `useFilterPayload`, giống `useDocumentTypeData`.
- **Rationale**: Endpoint `get-all` đã nhận `page/pageSize/sortColumn/sortOrder` + filters.

## Quyết định 6 — Chống trùng tên bước (FR-005a, 2026-08-11)

- **Decision**: Thêm `IEutrStepRepository.ExistsNameAsync(name, excludeId, ct)` (Dapper, so khớp
  `LOWER(TRIM(Name)) = LOWER(TRIM(@name))`, có `AND Id <> @excludeId` khi sửa) và override
  `EutrStepService.AddAsync`/`UpdateAsync` để gọi kiểm tra này trước khi lưu, `throw new
  InvalidOperationException("A step with this name already exists.")` khi trùng.
- **Rationale**: Đây là **verified gap** — backend hiện tại (`EutrStepRequestDtoValidator` chỉ có
  `NotEmpty`, `EutrStepService` dùng `IRepository<EutrStep, long>` generic) chưa có kiểm tra trùng
  tên. Mẫu chống trùng y hệt đã tồn tại ở `EutrMastersService.AddAsync/UpdateAsync` +
  `IEutrMastersRepository.ExistsStepPrefixAsync` (Nguyên tắc II — dùng lại mẫu thay vì phát minh
  cách mới) và ở `ComplMasterHierarchyService`/`ExistsAsync`. `InvalidOperationException` đã được
  `ValidationExceptionMiddleware` map sẵn sang HTTP 409 + `ApiResponse<string>.Fail(...)` — không
  cần thêm middleware/exception type mới.
- **Alternatives considered**:
  (a) Thêm rule `MustAsync` trong FluentValidation với repository inject qua constructor — bị loại
  vì không có validator nào trong codebase hiện làm async DB-backed validation; sẽ tạo tiền lệ mới
  không cần thiết trong khi mẫu Service-override đã có sẵn và đã được review.
  (b) Kiểm tra trùng chỉ ở client (so với danh sách đã tải) — bị loại vì danh sách hiển thị có
  phân trang/lọc, không đảm bảo có đủ toàn bộ tên hiện có để so khớp chính xác; server luôn phải là
  nguồn sự thật cuối cùng.
- **Frontend surfacing**: `presentation/pages/eutr-steps/index.jsx` bắt lỗi ở catch block của
  Create/Update, lấy `err?.response?.data?.message || err?.message`, hiển thị qua
  `CustomSnackbar` (severity "error") — đúng cách `eutr-masters/index.jsx` đang xử lý lỗi trùng
  (StepId, Prefix); không thêm lỗi inline theo field vì không có tiền lệ trong codebase.
