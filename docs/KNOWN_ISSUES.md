# Cập nhật GitHub/Pages03/10/2026

Repo và website đã public cùng target `nguyenduchai/PhotoAxis`, GPL-3.0-only, hỗ trợ GitHub Issues. Target/source visibility/hosting/license/Issues không còn chưa chốt; phần publisher pháp lý/Team/namespace/notary/cài sạch vẫn thiếu.

- CI Xcode16.4 phát hiện UndoManager callback thiếu ngữ cảnh MainActor: sửa `MainActor.assumeIsolated` để giữ callback đồng bộ và kiểm executor. CI tiếp theo phát hiện test HDR dùng API SDK26; phép đo phụ chỉ biên dịch khi compiler≥6.2, các kiểm HDR/SDR/metadata/pixel vẫn chạy SDK15.
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
| INV2-01 | Khả dụng và độ đọc OCR | Runtime host có `vi-VT`; thiếu `vi-*` thì disabled/từ chối rõ. Chưa kiểm macOS14 hoặc cả OS hỗ trợ. Cần dữ liệu được phép dùng/đa font/chữ mờ/cold-warm; ROI tham chiếu nguồn intake chuẩn hóa, không phải canvas chỉnh hiện tại. OCR không chứng minh chữ đúng; người dùng xác nhận riêng. |
| INV2-02 | Độ trễ OCR lần đầu | Lượt đầu trước bản cuối quan sát khởi tạo model Apple khoảng79,6giây; lượt ấm synthetic nhanh. Worker/spinner/chuỗi bận đã có, chưa đo budget cold/warm trên máy đích. Không nhận quan sát cũ là benchmark cuối. |
| INV2-03 | Phạm vi video | Test/native MOVH.264VFR/rotation/ordinal/PTS nguyên/hash PASS. Chưa bộ codec/camera/longclip/4K/HDR/máy đích;512MiB/file,20video,1track,100.000sample và120sdecode. PNG SDR8bit dẫn xuất; offset tương đối giữPTSgốc/căn cứ, không tự suy giờ quay tuyệt đối. |
| INV2-04 | Độ chính xác đo ngoài thực địa | Một tỷ lệ uniform từ thước/căn cứ do người dùng khai báo; fixture50cm/100cm² PASS và model thay đổi làm calibration stale. Chưa tự kiểm camera/mặt phẳng/lens/depth hoặc tính độ không đảm bảo; cần phương pháp/thước/hình học được kiểm độc lập khi dùng ảnh thực. |
| INV2-05 | Full quota/manifest/latency | Chưa đo100OCR/100calibration/500measure/100frame/20video, tổng10GiB/32MiB/10.000event trên máy16GB.32MiB có thể đạt trước quota danh nghĩa; journal/fullmodel I/O cần đo native dưới tải và lỗi filesystem. |
| INV2-06 | Usability/đầu ra dữ liệu riêng tư | Tọa độ nhập ô số, chưa click chọn điểm/timeline/player/batchOCR/full-text search/PDFautoOCR–measuretable. JSON phân tích unredacted chứa raw/confirmed chữ và nguồn; xuất trước event sau là snapshot đúng thời điểm. Cần rà soát riêng trước chia sẻ, không coi PNG/PDF đã che làm sạch JSON/case. |

**INV2-FIX — đã sửa:** suffix container cho video nguồn, fixture resource path, temp cleanup ENOENT, spinner và tọa độ người đọc được. Source0169bf5;144testPASS, native final và localDMG3 đã có. Lỗi detachDMG trung gian exit16 đã xử lý mount do tác vụ tạo và retry finalPASS; không liên quan chứng nhận public.
