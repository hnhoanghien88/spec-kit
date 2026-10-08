# Tasks: Compliance Missing Detail

**Input**: Design documents in `/specs/020-compl-missing-detail/` (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)

**Tests**: Không yêu cầu test tự động (xem plan.md → Testing); kiểm tra thủ công theo quickstart.md.

**Quy tắc chung (FR-015)**: mọi file là MỚI (copy từ `ComplSoMissing*` / `compliance-missing` rồi chỉnh). Chỉ được THÊM dòng ở các file đăng ký cũ (DI ×2, `repositories.js`, `RouteResolver.jsx`, `ComplianceSystem.jsx`), không đổi logic hiện có. Comment code bằng tiếng Việt. Đường dẫn: `API` = `compliance-sys-api/src`, `WEB` = `compliance-client/src`.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup (DB schema & menu)

- [x] T001 [P] Tạo `API/ComplianceSys.Infrastructure/Sqls/Migration/35_create_compl_missing_detail.sql` và bản tham chiếu `API/ComplianceSys.Infrastructure/Sqls/Tables/compl_missing_detail.sql` theo data-model.md (cột như `compl_so_missing` bỏ SalesId, thêm `DetailId` PK, `CreatedDate`, UNIQUE 4 cột khóa, cột khóa NOT NULL DEFAULT '', `CREATE TABLE IF NOT EXISTS`)
- [x] T002 [P] Tạo `API/ComplianceSys.Infrastructure/Sqls/Migration/36_create_compl_missing_detail_note.sql` và `API/ComplianceSys.Infrastructure/Sqls/Tables/compl_missing_detail_note.sql` theo data-model.md
- [x] T003 ~~Migration 37 seed menu/quyền~~ — HỦY: menu/quyền đã được app khác cập nhật; không tạo migration menu (cũng không có migration 34)

## Phase 2: Foundational (Domain + Repository, chặn mọi user story)

- [x] T004 [P] Tạo entity `API/ComplianceSys.Domain/Entities/ComplMissingDetail.cs` (copy `ComplSoMissing.cs` bỏ SalesId, thêm DetailId/CreatedDate) và `ComplMissingDetailNote.cs` (copy `ComplSoMissingNote`, khóa MasterCode/Code/MappedRefTypeCode/MappedInputValue)
- [x] T005 [P] Tạo `API/ComplianceSys.Application/Interfaces/Repositories/IComplMissingDetailRepository.cs` (DeleteAllAsync, InsertManyAsync, SearchAsync, SearchAllAsync, replace trong transaction do service điều phối) và `IComplMissingDetailNoteRepository.cs` (copy `IComplSoMissingNoteRepository` đổi khóa)
- [x] T006 Tạo `API/ComplianceSys.Infrastructure/Repositories/ComplMissingDetailRepository.cs` (Dapper; Search: WHERE Status-tính-lúc-đọc `Code='' → Missing`, `ValidTo < CURDATE() → Expired`, loại dòng khác; filter/sort whitelist cột theo research R8; insert theo lô 500) — mẫu `ComplSoMissingRepository.cs` + `ComplSoMissingReportRepository.cs`
- [x] T007 [P] Tạo `API/ComplianceSys.Infrastructure/Repositories/ComplMissingDetailNoteRepository.cs` (upsert `ON DUPLICATE KEY UPDATE`, GetByKeysAsync một truy vấn, xóa khi rỗng cả hai) — mẫu `ComplSoMissingNoteRepository.cs`
- [x] T008 Thêm 2 dòng đăng ký repository vào `API/ComplianceSys.Infrastructure/DependencyInjection.cs` (chỉ thêm dòng)
- [x] T009 [P] Tạo DTO `API/ComplianceSys.Application/Dtos/Request/MissingDetailSearchRequestDto.cs`, `Dtos/Response/MissingDetailRowDto.cs`, `Dtos/Response/MissingDetailRefreshResultDto.cs`, DTO note request/import-result (copy `SoMissingNote*Dto`, đổi khóa) theo contracts/

## Phase 3: User Story 1 - Làm mới snapshot (Priority: P1) 🎯 MVP

**Goal**: Trigger `test-compliance-missing` làm mới `compl_so_missing` (bản copy), group, thay `compl_missing_detail` atomic, không gửi mail.

**Independent Test**: quickstart scenarios 3–7, 13.

- [x] T010 [P] [US1] Tạo `API/ComplianceSys.Application/Interfaces/Services/IComplMissingDetailRefreshService.cs` (`RefreshAsync(ct) → MissingDetailRefreshResultDto`)
- [x] T011 [US1] Tạo `API/ComplianceSys.Application/Services/ComplMissingDetailRefreshService.cs`: copy `RefreshSalesOrderMissingComplianceAsync` + `MapToComplSoMissing` + `BuildCurrentSalesOrderAlertComplianceListAsync` từ `ComplNotificationService.cs` (dòng ~200–380, KHÔNG sửa file gốc, KHÔNG gọi SendMail/Notify), dùng `IComplDynamicsService`, `IViewCompliancesService`, `IComplSoMissingRepository` nguyên trạng; đếm SO lỗi; group theo 4 cột chuẩn hóa null→'' + Trim, lấy dòng đầu, bỏ SalesId; thay snapshot trong `IUnitOfWork` transaction ReadCommitted (xóa → insert lô → commit, lỗi rollback) theo mẫu `ComplSoMissingReportJobService.cs`; khóa chạy đơn (static `SemaphoreSlim(1,1)`, nếu đang chạy ném lỗi để controller trả 409)
- [x] T012 [US1] Thêm đăng ký `IComplMissingDetailRefreshService` vào `API/ComplianceSys.Application/DependencyInjection.cs` (chỉ thêm dòng)
- [x] T013 [US1] Tạo `API/ComplianceSys.Api/Controllers/ComplMissingDetailController.cs` (route `api/compl-missing-detail`, `[Authorize]`) với `[HttpGet("test-compliance-missing")]` policy `ComplianceMissingDetail.Update`: 200 kèm kết quả, 409 khi đang chạy, 499 khi hủy, 500 khi lỗi — mẫu `ComplSoMissingController.cs`

**Checkpoint**: gọi trigger → `compl_missing_detail` có dữ liệu, không email.

## Phase 4: User Story 2 - Xem danh sách (Priority: P1)

**Goal**: Màn hình `/compliance-missing` đọc `compl_missing_detail`, không có cột SO, Status tính lúc đọc.

**Independent Test**: quickstart scenarios 1, 2, 8, 9, 14, 15.

- [x] T014 [P] [US2] Tạo `IComplMissingDetailSearchService.cs` (`API/ComplianceSys.Application/Interfaces/Services/`) và `API/ComplianceSys.Application/Services/ComplMissingDetailSearchService.cs`: SearchAsync/SearchAllAsync, validate cột filter/sort whitelist (400 nếu sai), map DTO, tính `Status`/`DaysRemaining` ("-n days left", rỗng nếu ValidTo rỗng) và `ResponsibleEmails` (parse `ResponsibleGroupsJson`) bằng bản copy helper của `ComplSoMissingReportJobService`/`ComplNotificationService`, join note theo khóa chuẩn hóa một truy vấn — mẫu `ComplSoMissingSearchService.cs`
- [x] T015 [US2] Thêm endpoint `POST search` (policy `ComplianceMissingDetail.ReadAll`) vào `ComplMissingDetailController.cs`; thêm đăng ký search service vào `API/ComplianceSys.Application/DependencyInjection.cs`
- [x] T016 [P] [US2] Tạo `WEB/domain/interfaces/IComplMissingDetailRepository.js`, `WEB/infrastructure/api/complMissingDetailApi.js`, `WEB/infrastructure/repositories/RestComplMissingDetailRepository.js`, `WEB/application/usecases/compl-missing-detail/SearchComplMissingDetailUseCase.js` (copy `compl-so-missing`, base `api/compl-missing-detail`)
- [x] T017 [US2] Thêm `complMissingDetail: new RestComplMissingDetailRepository()` + import vào `WEB/di/repositories.js` (chỉ thêm dòng)
- [x] T018 [P] [US2] Tạo `WEB/presentation/pages/compliance-missing-detail/hooks/useComplMissingDetailData.js` (copy `useComplSoMissingData.js`: bỏ Year/Week/refresh-D365, giữ phân trang/sort/filter server-side; getRowId theo 4 cột khóa)
- [x] T019 [P] [US2] Tạo `WEB/presentation/pages/compliance-missing-detail/hooks/useComplMissingDetailColumns.jsx` (copy `useComplSoMissingColumns.jsx`, BỎ salesId/etd/invoiceDate/custAccount/custName; giữ master, status, code, name, valid from/to, days remaining, responsible emails, type, product, product name, description, follow up date, note)
- [x] T020 [US2] Tạo `WEB/presentation/pages/compliance-missing-detail/index.jsx` (copy `compliance-missing/index.jsx`: bỏ bộ lọc Year/Week và nút Refresh; menu code `compliance-missing-detail`, permission `ComplianceMissingDetail.*`; grid-preference `('compliance-missing-detail','compliance-missing-detail-main')`; trạng thái "no data" khi rỗng; chưa gồm export/note/import — làm ở US4)
- [x] T021 [US2] Đăng ký route/menu: thêm lazy import + `'compliance-missing-detail': <ComplianceMissingDetailPage />` vào `WEB/app/routes/RouteResolver.jsx`; thêm mục menu url `/compliance-missing` code `compliance-missing-detail` vào `WEB/presentation/menu-items/ComplianceSystem.jsx` (chỉ thêm)

**Checkpoint**: màn hiển thị snapshot; màn open-orders không đổi.

## Phase 5: User Story 3 - Lọc/tìm kiếm (Priority: P2)

**Goal**: Lọc/sort như màn cũ trên các cột còn lại.

**Independent Test**: quickstart scenario 10.

- [x] T022 [US3] Hoàn thiện filter model/quick filter (Status, MasterCode, Code…) và Clear trong `WEB/presentation/pages/compliance-missing-detail/index.jsx` + `hooks/useComplMissingDetailData.js`; đảm bảo tên cột gửi lên khớp whitelist backend; xác nhận backend filter operators (contains/equals) trong `ComplMissingDetailRepository.cs` chạy đúng

## Phase 6: User Story 4 - Ghi chú & Export (Priority: P3)

**Goal**: Nhập follow-up date/note, import từ Excel, export Excel, độc lập màn cũ, bền qua refresh.

**Independent Test**: quickstart scenarios 11, 12.

- [x] T023 [P] [US4] Tạo `IComplMissingDetailNoteService.cs` + `API/ComplianceSys.Application/Services/ComplMissingDetailNoteService.cs` (save/xóa note, import Excel theo khóa 4 cột, chuẩn hóa null→'' + Trim) — mẫu `ComplSoMissingNoteService.cs`
- [x] T024 [P] [US4] Tạo `IComplMissingDetailExportService.cs` + `API/ComplianceSys.Application/Services/ComplMissingDetailExportService.cs` (ClosedXML, header `#C18C75`, dòng Expired `#fff59d`, không có 5 cột SO, thêm Follow up date/Note) — mẫu `ComplSoMissingExportService.cs`
- [x] T025 [US4] Thêm endpoints `POST export` (`ComplianceMissingDetail.Download`, file `compliance-missing-detail-{yyyyMMddHHmmss}.xlsx`), `POST note`, `POST note/import` (`ComplianceMissingDetail.Update`) vào `ComplMissingDetailController.cs`; đăng ký note/export service vào `API/ComplianceSys.Application/DependencyInjection.cs`
- [x] T026 [P] [US4] Tạo usecases `ExportComplMissingDetailUseCase.js`, `SaveComplMissingDetailNoteUseCase.js`, `ImportComplMissingDetailNotesUseCase.js` trong `WEB/application/usecases/compl-missing-detail/` và bổ sung hàm tương ứng vào API client + repository FE mới (T016)
- [x] T027 [US4] Tạo `WEB/presentation/pages/compliance-missing-detail/hooks/useComplMissingDetailNote.js` (copy `useComplSoMissingNote.js`) và nối vào `index.jsx`: cột follow-up date/note sửa trực tiếp, nút Export, nút Import + dialog lỗi (copy từ `compliance-missing/index.jsx`)

## Phase 7: Polish

- [x] T028 [P] Build kiểm tra: `dotnet build compliance-sys-api` (không lỗi) và `npm run build`/lint trong `compliance-client`
- [x] T029 [P] Tạo tài liệu `compliance-sys-api/docs/compliance-missing-detail/README.md` (mô tả trigger, bảng, rủi ro dùng chung `compl_so_missing`, thứ tự migration 35→36)
- [ ] T030 Chạy quickstart.md (15 kịch bản) và ghi kết quả; xác nhận file cũ chỉ thay đổi bằng thêm dòng (`git diff` các file đăng ký)

## Phase 8: Update 2 — Nút Get from D365

- [x] T031 Client: thêm `refresh` vào `complMissingDetailApi.js`, `IComplMissingDetailRepository`, `RestComplMissingDetailRepository`, tạo `RefreshComplMissingDetailUseCase.js`, thêm nút "Get from D365" vào `compliance-missing-detail/index.jsx` (backend không đổi, đã chạy Hangfire; eslint sạch)
- [ ] T032 Chạy thử thủ công: click nút → "Refresh has been queued", job hiện ở Hangfire dashboard (NOT run — cần môi trường live)

## Phase 9: Update 3 — Ẩn tạm Export/Import và cột Follow up date/Note

- [x] T033 Client: thêm cờ `SHOW_EXPORT_IMPORT = false` (`index.jsx`) và `SHOW_FOLLOW_UP_COLUMNS = false` (`useComplMissingDetailColumns.jsx`) để ẩn 2 nút và 2 cột; backend không đổi (eslint sạch)
- [ ] T034 Kiểm tra thủ công trên UI: không còn nút Export/Import, cột Follow up date/Note (NOT run — cần môi trường live)

## Dependencies & Execution Order

- Phase 1 → Phase 2 → US1 (P1) → US2 (P1) → US3 → US4 → Polish. US2 cần dữ liệu từ US1 để kiểm thử nhưng code độc lập sau Phase 2.
- Trong Phase 2: T004, T005, T009 song song; T006 sau T004/T005; T007 song song với T006; T008 sau T006–T007.
- US1: T010 song song; T011 sau T010 + Phase 2; T012–T013 sau T011.
- US2: T014/T016/T018/T019 song song; T015 sau T013+T014; T017 sau T016; T020 sau T018–T019; T021 sau T020.
- US4: T023/T024/T026 song song; T025 sau T013; T027 sau T020, T026.
- Backend và frontend của cùng story có thể làm song song nhóm.

## Parallel Example (US2)

```text
T014 ComplMissingDetailSearchService | T016 FE api/repository/usecase | T018 useComplMissingDetailData | T019 useComplMissingDetailColumns
```

## Implementation Strategy

- **MVP**: Phase 1–3 (US1) + Phase 4 (US2): có snapshot và màn hình xem được.
- Tiếp theo US3 (lọc), US4 (ghi chú/export), cuối cùng Polish.
- Migration chỉ tạo file; KHÔNG tự chạy trên DB (người dùng chạy theo thứ tự 35→36; menu/quyền do app khác quản lý).

## Phase 10: Update 4 — Đổi link menu

- [x] T032 Đổi `url` trong `WEB/presentation/menu-items/ComplianceSystem.jsx`: `compliance-missing` → `/compliance-missing`, `compliance-missing-detail` → `/compliance-missing-bk` (chỉ sửa code, chưa chạy kiểm thử UI)
- [ ] T033 Cập nhật `url` của hai menu trong `userMenu` (app quản lý menu khác) — không có migration trong repo này

## Phase 11: Update 5 — Dùng chung quyền ComplianceMissing

- [x] T034 Đổi 5 `[Authorize(Policy=...)]` trong `API/ComplianceSys.Api/Controllers/ComplMissingDetailController.cs` sang `ComplianceMissing.*`; client `compliance-missing-detail/index.jsx` đọc menu `compliance-missing`; `compliance-missing-type/index.jsx` cho cả hai Type theo menu `compliance-missing`
- [ ] T035 Cấp `ComplianceMissing.ReadAll/Download/Update` cho role đang có `ComplianceMissingDetail.*` rồi xóa menu `compliance-missing-bk` ở app quản lý menu (ngoài repo)
