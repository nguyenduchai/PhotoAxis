# Phạm vi build10 — 05/10/2026

OCR/Bảng ảnh/Privacy hiện hành thay thế các trang hồsơ/đo/video/audit/so sánh cũ. Dự ánmanagedlegacy mởbản sao unsaved, tệp hồsơgiữnguyên. `.paxis`giữnguồn, chia sẻ bằngflattenedPNG/JPEG/PDF. Bảngảnhsnapshotlúcthêm, khôngđồngbộtheotab; draft/OCRchỉRAM, chưalưu/recovery. RasterPDFkhôngcopychữ. Captionquádàibáolỗi;4MPeach/100photos/128MiBbound. BlurpatchsauApplyfixed; underlyingcontentmove phải kiểm vùngche; facegợiýmanualreview, chưapositivefixturequalification.

Fullsuite227:223PASS/1knownTelexFAIL/3SKIP,17newPASS. Nativeprivacy/modes/Apply/Undo/Redo/SaveVIđãkiểm; nativeOCR/Bảngảnh/export/ENreopen bị giánđoạn khiMaclock, chưaPASS. Hostedexportđọcprojectnativevàindependentpixel/PDFauditPASS; khôngthaychohộpthoạiexportnative. Các gatecũIME/target/MetalQoS/performance/fullacceptance/Scan/Paint/signing/install vẫn mở; gatecase/video/measurementđượcretiredoownerremove, khôngđổiPASS.

[Báo cáo hiện hành](bao-cao/TIEN_ICH_BAO_MAT_2026-10-05.md), [hướng dẫn](HUONG_DAN_OCR_BANG_ANH_BAO_MAT.md). Các phần build3–9 dưới là lịch sử.

---

# Phạm vi bản phát triển build9 — 04/10/2026

Cài đặt native sáu nhóm có Tối/Sáng/Theo hệ thống; theme/liveworkspace không sửa pixel hoặc History. Recovery luôn bật10/30/60giây, đổi từ chu kỳ chờ tiếp theo. Exportdefaults chỉ ảnh hưởng hộp thoại mở mới. Ngôn ngữ cần khởi động lại; cọ mặc định chỉ áp tài liệu thêm mới. Reset chỉ nhóm hiện tại.

OCR đã có **Hủy nhận dạng chữ**, bỏ kết quả muộn và không ghi audit chưa hoàn tất. macOS có thể chưa dừng worker ngay; OCR mới báo bận cho đến worker thoát, chỉnh sửa vẫn hoạt động. Cold/warmruntime/mọiOS/máyđích vẫn chưa đạt qualification; không dùng nút hủy làm bằng chứng OCRcoldhoàn tất. Lịch sử build8 bên dưới mô tả tình trạng trước sửa.

Fullsuite210ca206PASS/1FAILTelexmôphỏng/3SKIPbenchmark; CI205PASS/0FAIL/5SKIP do không cóTelexcontext và desktopgiới hạn. Không bỏ FAILlocal. Benchmarkriêng3PASS nhưng Perspectiveworker23%≤33,333ms chưa đạt mục tiêu và không là nativeFPS. MDB_MAP_FULL/Metal-QoS tiếp tục đánh giá. Minlayout chỉ kiểm hosted; resizeattempt native chưa thành công. A01–A43/máyđích macOS14/non-Retina/M1-16GB/IMEVNI/realdata/Scan/Paint/fullquota/cài sạch/DeveloperID/notary tiếp tục mở.19/43làbuild3lịch sử.

[Báo cáo build9](bao-cao/CAI_DAT_KIEM_THU_2026-10-04.md), [Cài đặt](HUONG_DAN_CAI_DAT.md).

---

# Phạm vi bản phát triển build8 — 04/10/2026

Phân tích/Đầu ra dùng tab đang mở; với tab thường, nguồn phân tích là PNG dựng từ committed canvas. Chốt/cancel draft Crop/Scan/chữ trước khi phân tích. Lưu phiên thành hồ sơ để giữ OCR/đo/vùng che/log; chưa recovery phiên tạm sau crash. Sửa canvas phải phân tích/hiệu chuẩn/rà soát lại; hồ sơ snapshot đã lưu không tự cập nhật theo tab thường. OCR tab hồ sơ vẫn dùng nguồn tiếp nhận; tab thường dùng canvas hiện tại. Checkpoint so sánh tab thường giữ lúc mở tab, tăng lifetime nguồn COW cho tới khi đóng tab; maximum quota/performance vẫn cần qualification. Không nhận bản dựng là file gốc hay đầy đủ lịch sử trước tiếp nhận.

Con trỏ tool/hover/modifier/drag dùng NSCursor native; pressure/tablet, custom brush/healing/masks không thuộc chặng này. Các gate Telex/VNI/macOS14/non-Retina/M1-16GB/hiệu năng/full quota/DeveloperID/notary/cài sạch tiếp tục mở; nghiệm thu19/43 thuộc build3 lịch sử. [Báo cáo](bao-cao/OPEN_IMAGE_CURSOR_2026-10-04.md).

---

OCR cold native bản cuối build8 chưa trả kết quả qua nhiều lần quan sát; QA đã ghi trạng thái, quit và mở lại tài liệu đã lưu. Case thử cuối không có OCR event. Lượt ROI3dòng/xác nhận trước sửa guard Save không thay nghiệm thu OCR cold/warm trên bản cuối/máy đích. [Bằng chứng phạm vi](bao-cao/OPEN_IMAGE_CURSOR_2026-10-04.md).

# Phạm vi bản phát triển build7 — 03/10/2026

Thước/Cài đặt/trang workspace đã được cải tiến. Thước mm/cm/in theo PPI thể hiện kích thước in, không suy kích thước vật trong ảnh; dùng Hiệu chuẩn ở Phân tích. Cọ mặc định chỉ ảnh hưởng tài liệu thêm mới. Ngôn ngữ cần khởi động lại app. Các gate IME/macOS14/non-Retina/hiệu năng/DeveloperID/notary/cài sạch tiếp tục mở; nghiệm thu19/43 thuộc build3 lịch sử. [Báo cáo build7](bao-cao/WORKSPACE_UI_2026-10-03.md).

# Paint1 và live preview — build6, 03/10/2026

- Brush/Clone cơ bản có chuột, không pressure/tablet/eraser/healing/texture/mask. Mẫu clone đóng băng; muốn lấy thay đổi vừa sửa phải lấy mẫu lại. Lấy mẫu có thể chờ render/encode canvas đầy đủ.
- Nét/ROI/source/History có quota; không chứng nhận full quota hoặc native60FPS/máy đích từ fixture nhỏ. Inset/Scan có coalescing và bỏ tác vụ cũ, không phải deadline FPS.
- Project có paint là schema4, app trước build6 từ chối; nguồn/mẫu còn nhúng kể cả ngoài crop hoặc dưới nét phủ. Dùng output đã rà soát khi chia sẻ.
- Local Telex event test vẫn FAIL, benchmark opt-in SKIP; warning MDB_MAP_FULL và QoS cũ tiếp tục qualification. Full nghiệm thu A01–A43, macOS14/non-Retina/M1-16GB/ảnh thực/DeveloperID/notary/cài sạch còn mở. 19/43 là build3 lịch sử.

# Workspace tích hợp — build5, 03/10/2026

Đã hợp nhất Điều tra vào Sources/Analysis/Output của workspace, bỏ menu/window/form modal riêng. Native VI/EN scoped OCR/đo/đối chiếu/PNG và9testmới PASS; full168ca164PASS/1knownTelexFAIL/3benchmarkSKIP. [Báo cáo](bao-cao/HOP_NHAT_WORKSPACE_2026-10-03.md).

- OCR native cold vẫn chờ đáng kể trong Vision compute. CPU chỉ được đặt ở stage công bố hỗ trợ; chưa chứng minh hết độ trễ trên mọi stage/máy. Cần đo cold/warm độc lập trên hệ điều hành đích.
- Không nhận full nghiệm thu A01–A43 trên build5;19/43 build3 giữ lịch sử. IME/macOS14/non-Retina/M1-16GB/Metal-QoS/quota/DeveloperID/notary/cài sạch vẫn mở.
- PDF/video native không được rerun toàn bộ trong chặng hợp nhất; regression backend đã chạy trong fullsuite. Tính năng mới chọn điểm/vùng đã có, nên thông tin “clickpoints chưa triển khai” ở mốc lịch sử bên dưới không còn hiện hành.

# Scan1 — build4, 03/10/2026

Scan đã triển khai local: phát hiện trang/góc, làm sạch giấy, nắn bow thủ công và batch1–50ảnh với PNG/project/PDF/manifest. [Báo cáo](bao-cao/SCAN_2026-10-03.md), [hướng dẫn](HUONG_DAN_SCAN.md). Không còn ghi các chức năng này là chưa xây.

- SCAN-01: cần bộ giấy/sách chụp thực được phép dùng: chữ ký/nét mảnh/mực nhạt/bóng mạnh/biên khó. Tăng whitening/threshold có thể bỏ nét hoặc thay hình thức mực, phải rà từng trang.
- SCAN-02: nắn cong là chỉnh bow hai trục thủ công, chưa tự dựng3D mọi trang sách/nếp gấp. Chú thích layer khác không theo bow; kiểm vị trí.
- SCAN-03: đã thử batch nhỏ và rollback lỗi/Cancel, chưa qualification50trang ở fullquota/thời gian/memory/máy macOS14/M1-16GB. Một call Vision/GPU/ImageIO đang chạy không bị ngắt giữa call. Crash có thể để staging ẩn. Chưa import PDF/TIFF/batchOCR.
- SCAN-04: Scan project dùng schema3; build3 cũ từ chối mở. File nguồn/GPS/pixel crop vẫn nhúng trong project. Batch không phải bản hồ sơ đã che hoặc chain-of-custody.
- Các gate IME/máy đích/Metal-QoS/ký/notary/cài sạch bên dưới vẫn mở; 19/43 là bằng chứng baseline build3, chưa nghiệm thu lại toàn bộ trên build4.

# Cập nhật GitHub/Pages03/10/2026

Repo và website đã public cùng target `nguyenduchai/PhotoAxis`, GPL-3.0-only, hỗ trợ GitHub Issues. Target/source visibility/hosting/license/Issues không còn chưa chốt; phần publisher pháp lý/Team/namespace/notary/cài sạch vẫn thiếu.

- CI Xcode16.4 phát hiện UndoManager callback thiếu ngữ cảnh MainActor: sửa `MainActor.assumeIsolated` để giữ callback đồng bộ và kiểm executor. CI tiếp theo phát hiện test HDR dùng API SDK26; phép đo phụ chỉ biên dịch khi compiler≥6.2, các kiểm HDR/SDR/metadata/pixel vẫn chạy SDK15.
- CI cuối source78adb1b **143PASS/0FAIL/5SKIP**, Debug/test/ReleasePASS; SKIP3benchmark/Telexcontext/màn hình không đủ900pt. Hai metricfixtureHDR khác trênmacOS15 được ghi điều kiệnOS, các kiểmbyte/SDR/pixel/metadata vẫn chạy. HDR/layoutlocal2PASS. Không đóng nghiệm thu thiết bị/IME/hiệu năng từ CIgreen.
- Local fullsuite sourceb267165: **144PASS/1FAIL/3SKIP**,148total. FAIL `testInstalledVietnameseInputContext`: sự kiện NSEvent mô phỏng trả `tieengs vieetj ` thay `tiếng việt `. Không xóa/bỏ test để tạo PASS; VI physical typing lịch sử vẫn có, nhưng A22 cần kiểm hoàn chỉnh và EN/VNI. HDR riêng sau sửa guard PASS. [Bằng chứng](bao-cao/bang-chung/GITHUB-PAGES-20261003/native-local-test-summary.json).
- Metal MDB_MAP_FULL và priority-inversion warning vẫn xuất hiện. Website public không chứng nhận bộ cài/hiệu năng/IME.

# PhotoAxis 1.0.0 (3) — tồn đọng nghiệm thu, 03/10/2026

Đây là bản phát triển local, chưa có bản public. Các gate bên ngoài chưa được người dùng thay đổi phạm vi. `releaseReady=false`; không có xác nhận R02.

| ID | Mức ảnh hưởng | Tình trạng/bằng chứng | Điều kiện xử lý |
| --- | --- | --- | --- |
| QA-01 | Chặn nghiệm thu A22/A34/A42 | P12-native2 đã gửi phím ASCII thành tiếng Việt2dòng trên UI VI;Return/CmdReturn/Save/Escape đúng,file không đổi sau Cancel. EN nguồn nhập chưa xác minh, VNI disabled/chưa kiểm;marked-text cụ thể/shortcut/font/cỡ/căn lề đầy đủ còn thiếu. Suite trước IME SKIP | Có VNI/nguồn nhập thực đúng ở từng cửa sổVI–EN,kiểmcomposition/shortcut/đa dòng/commit/cancel;không dùng CLI TIS currentABC thay input context app |
| QA-02 | Còn nghiệm thu native tổng thể | P12-native2 chốt A04/A07/A26 qua nativeVI/EN build3;19/43PASS. Investigation build3 giữ phạm vi riêng. Còn full shortcut/layout/background-close toàn editor; CUA resize cạnh/góc ở lượt lịch sử chưa thay kích thước | Kiểm thủ công/công cụ resize tại1100×700/1280/1440pt;rà shortcut/tooltip/focus và crop/transform/close trong tác vụ nền.Không coi lỗi công cụ là lỗi app |
| QA-03 | Chặn phạm vi hỗ trợ/R02/R07/R08 | Host mới nhất M1 Pro32GiB/macOS27.0.1/Retina2×/Xcode27. Build minOS14 không chứng minh runtime macOS14. Simulated viewport1× không thay non-Retina thật | Máy/tài khoản sạch macOS14 và màn hình1×; máy chuẩn M1/16GB hoặc quyết định phạm vi khác rõ của người dùng |
| PERF-01 | Cần đánh giá GPU/logging trước chốt A37 | Console nhiều `(Metal) mdb_txn_commit … MDB_MAP_FULL`. Pixel/render/stress tests vẫn PASS. Process QA có Metal `archiveUsage.db/data.mdb` 131072 byte; CI probe độc lập không module/kernel PhotoAxis không tái hiện warning. Chưa chứng minh nguyên nhân là OS/driver hay app | Instruments/log filter trên native cuối, khoanh kernel/context/cache; giữ warnings trong bằng chứng, không tắt checker/xóa cache hệ thống để tạo PASS |
| PERF-02 | Cần đánh giá độ trễ native | Suite build3 hiện144PASS/0FAIL/4SKIP còn một priority-inversion warning ở ExportTests HDR prepare dòng113; console Metal MDB_MAP_FULL vẫn xuất hiện. Hai warning P11 là lịch sử. Test xanh không giải quyết QoS | Thu stack/Instruments khi desktop hoạt động; chỉ sửa scheduling có bằng chứng. P12 test-summary ghi warning thực của lượt mới |
| PERF-03 | Chặn chốt hiệu năngA36 | Benchmark build3 mới3PASS,corner worker median34,57ms/p9540,91ms,max65,09ms,chỉ31%≤33,333ms so với98% ở lượt lịch sử. Tải/cache chưa được kiểm soát; chưa xác nhận regression sản phẩm. Test assertion workerp95≤100ms không chứng nhận30fps | Profile với tải được ghi,đo input-to-present/frame native,máyM1-16GB;không chọn lượt nhanh nhất làm kết luận. Benchmark console/tmp không còn sau refresh nên runtimeWarnings=[] không chứng minh hết Metal warning |
| DIST-01 | Chặn P13/P15 | Keychain có Apple Development nhưng không có Developer ID Application. Chưa Team/bundle ID/UTI/notary profile chính thức | Chủ dự án cấu hình Developer ID/Keychain và cung cấp tên profile/identity/Team; không gửi khóa riêng/password/token vào chat |
| DIST-02 | Chặn P14/P15 | Không Git remote, chưa owner/repo/source visibility/website/publisher/support/license/giá | Chủ dự án cung cấp các giá trị; không suy từ Git author, không tự tạo repo/đổi visibility/gán MIT hoặc giá |

**UI-01 — đã sửa:** refresh/tab/zoom có thể ghi đè tiến độ Save/Export bằng trạng thái Saved. Commit 787e3d1 giữ taskProgress; regression vi/en và native Cancel40MP PASS, 113 PASS/0 FAIL/4 SKIP. Sửa này không thay renderer/atomic writer. Xem [P15-native](bao-cao/P15-native.md).

Không phát hiện mất nguồn, sai marker, sai clip hoặc crash sản phẩm trong các lượt tự động/native synthetic đã lưu. Kết luận đó chỉ áp dụng dữ liệu/host đã thử, không phải chứng nhận không còn lỗi trên mọi môi trường. Memory/Metal allocated là snapshot và high-water trong process XCTest; 5 vòng không đủ khẳng định không leak hoặc GPU ổn định dài hạn.

## Investigation 1 — giới hạn còn lại

I01–I10 triển khai/kiểm chứng local, không phải chứng nhận forensic hoặc public. [Báo cáo](bao-cao/GOI_DIEU_TRA.md). Xcode first-launch setup exit69 của assessment trước đã xử lý; build/test hiện chạy PASS trên macOS27.0.1.

| ID | Mức ảnh hưởng | Tình trạng | Điều kiện xử lý |
| --- | --- | --- | --- |
| INV-01 | Cần đo dung lượng/latency thực tế | Chưa chạy native toàn100ảnh/10GiB/32MiB/10.000event. Manifest full-model có thể chạm32MiB trước event quota; journal serialized và có I/O trong ngữ cảnh UI | Đo hồ sơ được phép dùng ở các mức tải, latency/RSS/GPU và lỗi ổ đĩa/filesystem; không dùng test nhỏ thay phép đo |
| INV-02 | Giới hạn quy trình bảo quản | Hash nối/state digest kiểm sai khác nội bộ; raw0444, không mã hóa/chữ ký/timestamp độc lập; operator/time là khai báo và đồng hồ máy | Quy trình tổ chức đối chiếu/biên nhận/sao lưu/kiểm quyền riêng; chữ ký/kho tập trung là phạm vi sau |
| INV-03 | Cần nghiệm thu thao tác/máy đích | Binary cuối native VI/EN case/Save/verify/PNG/PDF/log/pan/zoom/swipe PASS; physical pinch, IME, file camera/macOS14/1×/reference hardware còn thiếu | Máy đích và dữ liệu được phép dùng, ghi bằng chứng đúng binary; kéo ảnh ngoài viewport dùng Reset |

**INV-FIX-01…03 — đã sửa:** output sharing I/O rời main thread; comparison drag tính từ vị trí con trỏ; giữ archive intake khi Delete → Save → Undo. Source826bebf,130testPASS và native final provenance. Native QA Save Panel dán absolute path vào ô tên từng tạo tên có dấu `:`; đã chọn folder/tên đúng và di chuyển file QA ra khỏi repo. Không xóa event bắt đầu thiếu receipt. `.paxis` thường schema1 giữ nguyên, case working schema2; bộ cài D54/build1 không chứa phần mở rộng này.


## Investigation 2 — giới hạn còn lại

I11–I14 DONE local; [báo cáo](bao-cao/MO_RONG_DIEU_TRA.md). Native/automated dùng fixtures tự tạo trên host27.0.1, không phải chứng nhận xử lý mọi ảnh/video hoặc đo vật chứng. Case chuyển schema2 khi thêm analysis; app Investigation1 cũ từ chối mở schema2.

| ID | Ảnh hưởng | Tình trạng/điều kiện xử lý |
| --- | --- | --- |
| INV2-01 | Khả dụng và độ đọc OCR | Runtime host có `vi-VT`; thiếu `vi-*` thì disabled/từ chối rõ. Chưa kiểm macOS14 hoặc cả OS hỗ trợ. Cần dữ liệu được phép dùng/đa font/chữ mờ/cold-warm; ROI tab hồ sơ tham chiếu nguồn intake chuẩn hóa; tab thường build8 dùng snapshot committed canvas hiện tại. OCR không chứng minh chữ đúng; người dùng xác nhận riêng. |
| INV2-02 | Độ trễ OCR lần đầu | Lượt đầu trước bản cuối quan sát khởi tạo model Apple khoảng79,6giây; lượt ấm synthetic nhanh. Worker/spinner/chuỗi bận đã có, chưa đo budget cold/warm trên máy đích. Không nhận quan sát cũ là benchmark cuối. |
| INV2-03 | Phạm vi video | Test/native MOVH.264VFR/rotation/ordinal/PTS nguyên/hash PASS. Chưa bộ codec/camera/longclip/4K/HDR/máy đích;512MiB/file,20video,1track,100.000sample và120sdecode. PNG SDR8bit dẫn xuất; offset tương đối giữPTSgốc/căn cứ, không tự suy giờ quay tuyệt đối. |
| INV2-04 | Độ chính xác đo ngoài thực địa | Một tỷ lệ uniform từ thước/căn cứ do người dùng khai báo; fixture50cm/100cm² PASS và model thay đổi làm calibration stale. Chưa tự kiểm camera/mặt phẳng/lens/depth hoặc tính độ không đảm bảo; cần phương pháp/thước/hình học được kiểm độc lập khi dùng ảnh thực. |
| INV2-05 | Full quota/manifest/latency | Chưa đo100OCR/100calibration/500measure/100frame/20video, tổng10GiB/32MiB/10.000event trên máy16GB.32MiB có thể đạt trước quota danh nghĩa; journal/fullmodel I/O cần đo native dưới tải và lỗi filesystem. |
| INV2-06 | Usability/đầu ra dữ liệu riêng tư | Tọa độ nhập ô số, chưa click chọn điểm/timeline/player/batchOCR/full-text search/PDFautoOCR–measuretable. JSON phân tích unredacted chứa raw/confirmed chữ và nguồn; xuất trước event sau là snapshot đúng thời điểm. Cần rà soát riêng trước chia sẻ, không coi PNG/PDF đã che làm sạch JSON/case. |

**INV2-FIX — đã sửa:** suffix container cho video nguồn, fixture resource path, temp cleanup ENOENT, spinner và tọa độ người đọc được. Source0169bf5;144testPASS, native final và localDMG3 đã có. Lỗi detachDMG trung gian exit16 đã xử lý mount do tác vụ tạo và retry finalPASS; không liên quan chứng nhận public.
