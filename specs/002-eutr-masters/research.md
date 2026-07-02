# Research: EUTR Masters Management

Phase 0 — chốt các quyết định kỹ thuật. Các điểm nghiệp vụ chưa rõ đã được giải quyết ở
`/speckit-clarify` (Session 2026-07-02). Không còn NEEDS CLARIFICATION tồn đọng.

## Quyết định 1 — Tạo mới backend theo mẫu `EutrStep`

- **Decision**: Tạo mới toàn bộ backend cho EUTR Masters (Domain/Application/Api + DI), clone cấu
  trúc feature `EutrStep`; route `api/eutr-masters`.
- **Rationale**: Không có controller/service `eutr-masters*` nào tồn tại (đã kiểm tra codebase). Không
  có backend cũ để tái sử dụng (Nguyên tắc III không áp dụng), nên tạo mới theo mẫu đang chạy tốt
  (Nguyên tắc II) để đúng convention DI/validator/BaseService.
- **Alternatives considered**: (a) Làm frontend-only rồi ghép vào một API khác — bị loại vì không có
  API phù hợp; (b) Tự thiết kế backend mới từ đầu — bị loại vì lệch convention.

## Quyết định 2 — Paged query JOIN `eutr_steps` để trả `StepName` + lọc theo tên bước

- **Decision**: `EutrMastersService.GetPagedAsync` **override** BaseService, dùng Dapper SQL JOIN
  `eutr_master_documents m LEFT JOIN eutr_steps s ON s.Id = m.StepId`, SELECT thêm `s.Name AS
  StepName`, và cho phép lọc `s.Name LIKE @kw`; trả `PagedResult<EutrMastersResponseDto>`.
- **Rationale**: Spec yêu cầu grid hiển thị **tên bước** và **tìm kiếm theo tên bước** (FR-002,
  FR-003) với phân trang server-side. Trả StepName từ backend cho kết quả nhất quán, tránh lệ thuộc
  client ghép tên. Mẫu tương tự đã có (các ResponseDto giải tên như `DocumentTypeName`,
  `MasterName`).
- **Alternatives considered**: (a) Frontend tự map StepId→Name từ danh sách steps đã tải — bị loại
  vì tìm-kiếm-theo-tên server-side sẽ phải map ngược tên→id, phức tạp và dễ lệch phân trang;
  (b) Tạo VIEW DB — bị loại vì vượt phạm vi và khó bảo trì.

## Quyết định 3 — Chống trùng cặp (StepId, Prefix): chặn lưu

- **Decision**: Override `AddAsync`/`UpdateAsync` trong `EutrMastersService`; trước khi ghi, kiểm tra
  tồn tại cặp (StepId, Prefix) (khi update loại trừ chính `Id` đang sửa). Nếu trùng → ném lỗi nghiệp
  vụ với message tiếng Anh (vd "A master with the same step and prefix already exists.").
- **Rationale**: Clarify đã chốt **chặn lưu** (FR-007/FR-013). BaseService generic không có sẵn kiểm
  tra này nên phải bổ sung ở service. Kiểm tra ở service đảm bảo áp dụng cho cả Add, Update và Import.
- **Alternatives considered**: (a) Chỉ dựa vào unique index DB — hữu ích như phòng tuyến cuối nhưng
  thông báo lỗi kém thân thiện; có thể thêm unique index sau nhưng validation ở service là bắt buộc;
  (b) Cho lưu và chỉ cảnh báo — bị loại theo clarify.

## Quyết định 4 — Import Excel bằng ClosedXML, đọc từ dòng 2, import một phần

- **Decision**: `EutrMastersImportService` clone mẫu `ComplMasterImportService`: mở `XLWorkbook`, lấy
  worksheet đầu, lặp từ **dòng 2** (dòng 1 tiêu đề — clarify), cột A = step name, cột B = prefix.
  Với mỗi dòng: map step name→StepId theo `eutr_steps.Name` (khớp không phân biệt hoa/thường, trim);
  kiểm tra thiếu prefix; chống trùng với DB **và** với các dòng đã nhận trong cùng file. Dòng lỗi →
  bỏ qua + ghi vào `Errors`/`Duplicates`; dòng hợp lệ → tạo. Trả `ImportEutrMastersResultDto`
  (TotalRows, SuccessCount, FailCount, DuplicateCount, Errors[], Duplicates[]).
- **Rationale**: Clarify chốt **import một phần** + **dòng tiêu đề bị bỏ qua** (FR-011, FR-014).
  ClosedXML đã có sẵn trong project. Trả về báo cáo chi tiết để UI hiển thị (FR-014).
- **Alternatives considered**: (a) All-or-nothing — bị loại theo clarify; (b) Thư viện Excel khác
  (EPPlus) — bị loại vì ClosedXML đã dùng trong repo.

## Quyết định 5 — Quyền theo policy `EutrMasters.*` + seed menu (routing backend-driven)

- **Decision**: Controller dùng `[Authorize(Policy = "EutrMasters.ReadOne/ReadAll/Create/Update/
  Delete")]`. Frontend lấy `permissionList` từ menu (code `eutr-masters`) như mẫu `eutr-steps`.
  Menu + quyền phải được **seed ở backend** (Res.Shared.AuthZ / bảng menu-permission) để user thấy
  và truy cập được màn hình.
- **Rationale**: Bộ nhớ dự án ghi rõ **routing là backend-driven** (route khớp `userMenu` +
  `canAccessMenu`), nên chỉ thêm menu-item tĩnh ở frontend là chưa đủ; cần bản ghi menu/permission
  phía backend. Chính sách `EutrMasters.*` do Res.Shared.AuthZ nạp lúc khởi động.
- **Alternatives considered**: (a) Bỏ kiểm tra quyền ở UI — bị loại vì vi phạm Nguyên tắc V;
  (b) Hardcode route bỏ qua userMenu — bị loại vì lệch cơ chế backend-driven.
- **Ghi chú triển khai (đã xác nhận)**: Menu + permission được **tạo động và phân quyền trực tiếp
  trong DB** (không có code seed trong repo). Vì vậy KHÔNG có task code cho việc này; thay vào đó là
  **tiền đề vận hành/DB**: tạo bản ghi menu code `eutr-masters` (url `/eutr/masters`) và các quyền
  `EutrMasters.ReadAll/ReadOne/Create/Update/Delete`, rồi gán cho role/user trước khi kiểm thử màn
  hình (xem quickstart). Policy string `EutrMasters.*` do Res.Shared.AuthZ nạp lúc khởi động dựa
  trên dữ liệu quyền trong DB.

## Quyết định 7 — Export Excel bằng ClosedXML (workbook mới, GET trả file)

- **Decision**: `EutrMastersExportService` clone mẫu `ComplMasterExportService` nhưng **tạo workbook
  mới** (không dùng template): dòng 1 = tiêu đề `Step name`, `Prefix`; từ dòng 2 ghi mỗi master một
  dòng (StepName, Prefix). Trả `byte[]`. Controller thêm `GET /eutr-masters/export` trả
  `File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName)`.
  Frontend gọi với `responseType: "blob"` rồi kích hoạt tải file.
- **Rationale**: Khớp clarify/spec (FR-018→021): luôn có tiêu đề, rỗng thì chỉ tiêu đề, định dạng
  trùng import để round-trip. ClosedXML đã có sẵn; mẫu export byte[]+`File(...)` đã dùng trong repo.
  Export **toàn bộ** danh sách (không chỉ trang hiện tại) nên lấy dữ liệu qua repository (pageSize
  lớn / hàm lấy tất cả) thay vì state grid của frontend.
- **Alternatives considered**: (a) Export phía client từ dữ liệu đang hiển thị — bị loại vì chỉ có
  trang hiện tại + phải nhúng thư viện Excel ở client; (b) Dùng template file như
  `ComplMasterExportService` — bị loại vì thừa (chỉ 2 cột, tạo mới đơn giản hơn).
- **Ghi chú**: dùng `GET` cho export (tải file trực tiếp, mẫu `export-master`); không cần body.
  Endpoint export dùng policy riêng **`EutrMasters.Download`** (không dùng chung `ReadAll`); frontend
  hiển thị nút Export theo quyền `Download`. Quyền này cần được tạo/gán trong DB (như các quyền khác).

## Quyết định 6 — Frontend dùng lại use case steps sẵn có cho select box

- **Decision**: Modal nạp danh sách bước qua `GetEutrStepsUseCase` + repo `eutrStep` đã đăng ký
  trong `di/repositories.js` (GET `/eutr-steps`), không tạo API/usecase mới cho việc này.
- **Rationale**: Tránh trùng lặp; `getAll()` trả `{ id, name }` đủ dùng cho Select (value=id,
  label=name).
- **Alternatives considered**: Tạo endpoint riêng để nạp dropdown — bị loại vì thừa.
