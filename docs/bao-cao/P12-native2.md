# P12 — bổ sung nghiệm thu native build 3, 03/10/2026

**A04, A07 và A26 PASS trên host đã thử bằng cả giao diện Tiếng Việt và English.** Ma trận hiện có **19/43 PASS, 24 ca chưa đóng**. P06/P12 và public vẫn `BLOCKED_EXTERNAL`; `releaseReady=false`. Không thay phạm vi macOS14/non-Retina/máy chuẩn bằng kết quả trên host hiện tại.

## Sản phẩm và cấu hình kiểm tra

- PhotoAxis **1.0.0 (3)**, baseline `1.0-draft.3`; product code `0169bf52cd0d3793c0027a82888833c8a58f4f78`. Checkout trước bổ sung báo cáo `3cfa00b957e4ae843a106b85c0f2abac07333417`. Chặng này bổ sung bằng chứng/tài liệu, không sửa mã sản phẩm.
- M1 Pro/32 GiB/macOS27.0.1/Xcode27; Apple Silicon/Retina2×, cửa sổ native1280×800pt. Số hiển thị theo vùng máy có dấu phẩy ngay cả khi UI English.
- Release UUID **4EFA7887-E96F-3149-B6F5-68BE3475F219**, SHA256 **faa4d7264d3d92dc12ff6774ae5a5561b06ea09abb12acfbe8f5c1f1d620128c**. Hai bản QA đã re-sign local, cùng UUID và Core SHA256; tên/ID riêng để kiểm vi/en. Fingerprint nguồn **317d062da381ee744dc7b680a3b5dd40d23525e9536da30c9cb63c67fa0e9d02** đối chiếu lại PASS.
- Các lệnh `codesign --verify --deep --strict` cho Release, QA VI/EN và benchmark PASS. Đây vẫn là chữ ký local ad-hoc. [Manifest](bang-chung/P12-native2/manifest.json), [binary log](bang-chung/P12-native2/binary-verification.log).
- Suite **144 PASS/0 FAIL/4 SKIP** là lượt trước của cùng mã sản phẩm ở [Investigation2](bang-chung/INVESTIGATION2/test-summary.json); không nhận đã chạy lại full suite trong chặng này. Benchmark mới chạy riêng, không ghi đè DerivedData của app native.

## Nghiệm thu qua UI thật

Thao tác bằng CUA trên app native; ảnh/AX và `.paxis` được lưu trong [P12-native2](bang-chung/P12-native2/manifest.json). Chỉ dùng dữ liệu thử tự tạo. Hộp thoại Finder có sidebar cá nhân không được đưa vào bộ bằng chứng. Các nguồn nhập không được thêm/xóa/bật/tắt bởi tác vụ này.

| Ca | Thực hiện và kết quả | Kết luận |
| --- | --- | --- |
| A04 | Mỗi UI tạo và lưu 1080²/72PPI trong suốt, 1920×1080/72PPI trắng, 1080×1920/72PPI đen, A4 2480×3508/300PPI trắng; custom640×480/144,5PPI. Swap→480×640 rồi về640×480. Width8001/PPI0 có lỗi rõ và Create disabled; sửa số đúng tạo được | PASS host vi/en |
| A07 | Có5tab, New disabled; VI mở ảnh thứ6 và EN mở dự án thứ6 đều báo giới hạn, không thêm tab. A có phiên chữ chưa commit, đổi B duplicate/Undo, về A còn nguyên nội dung/phiên; Apply/Undo của A độc lập với Redo của B; C giữ History/chữ75%/Saved | PASS host vi/en |
| A26 | Tạo chữ → tạo hình chữ nhật → opacity60% → duplicate → Save As. Undo bỏ duplicate và chuyển Unsaved; Redo phục hồi duplicate/Saved. Chọn Create Text trong History → đổi chữ75%, các shape/redo cũ mất; Edit menu Redo disabled. Save nhánh mới → Undo dirty → Redo Saved | PASS host vi/en |
| A22 | Lượt VI mới có chuyển đổi thật từ ASCII thành chữ Việt, Return/CmdReturn/Escape và file lưu đúng. EN chưa xác nhận được nguồn nhập, VNI vẫn chưa chạy | CHƯA KIỂM CHỨNG toàn ca |

Mẫu A04 là 10 file `A04-*.paxis`. Kiểm độc lập ZIP/`document.json` và PNG preview bằng Python chuẩn: canvas/PPI/schema1/UUID riêng đúng; trong suốt alpha0, nền trắng/đen đúng **mọi pixel preview**, layer nền khóa/visible/opacity1. Đây là preview lưu trong file, không được gọi là full-resolution export oracle.

`A26-first-save-en.paxis` thực có text+2shape, opacity1/0,6/0,6. File `A26-branch-save-vi.paxis` và `…-en.paxis` thực chỉ còn text “Kiểm thử History”,24pt/opacity0,75. Mốc Save đầu VI có ảnh/AX, không có bản sao file trước khi Save nhánh ghi lại; không suy ra đã độc lập kiểm file snapshot đó. History/Undo phiên trước không được hứa phục hồi khi mở lại.

Ảnh tiêu biểu: [A4 VI](bang-chung/P12-native2/preset-a4-white-vi.png), [custom EN](bang-chung/P12-native2/preset-custom-saved-en.png), [History Saved EN](bang-chung/P12-native2/history-saved-en.png), [phiên A được giữ VI](bang-chung/P12-native2/tabs-a-preview-restored-vi.png). Menu Redo có AX; CUA không trả screenshot của menu tại một số lần, không tạo ảnh giả thay thế.

## A22 — tiến bộ thực tế, chưa chốt P06

Lượt trước dưới ABC gửi phím `tieengs vieetj` vẫn nguyên ASCII, ghi ở `ime-abc-before.*`. Inventory mới thấy Apple `com.apple.inputmethod.VietnameseIM.VietnameseTelex` enabled, VNI disabled. Đây là trạng thái bên ngoài tác vụ; tác vụ không thay cấu hình danh sách nguồn nhập. Probe TIS chạy từ CLI vẫn thấy currentABC, không dùng nó để chứng nhận selected source của `NSTextInputContext` trong app.

Lượt VI mới dùng `pressKey` từng ASCII character, **không paste/setValue Unicode**: `tieengs vieetj` → “tiếng việt”; Return → dòng mới; `thuwr nghieemj` → “thử nghiệm”; CmdReturn tạo đúng một layer chữ hai dòng. Save thật vào `A22-Telex-native-vi.paxis`. Edit Text → Select All → phím `thuwr` → Escape hủy phiên; Saved trở lại và SHA256 file vẫn nguyên. [Preview hai dòng](bang-chung/P12-native2/ime-telex-multiline-preview-vi.png), [file mẫu](bang-chung/P12-native2/A22-Telex-native-vi.paxis).

EN đã thử chuyển nguồn bằng shortcut nhưng vẫn nhận ASCII nguyên; selected source của cửa sổ chưa xác minh được. Không kết luận lỗi app hoặc PASS Telex EN từ lượt đó. VNI chưa khả dụng/chưa kiểm; trạng thái composition cụ thể và toàn bộ font/cỡ/căn lề/shortcut hai bộ gõ vẫn cần nghiệm thu. Các test marked-text cũ có giá trị riêng, không thay bằng chứng IME thực. **A22, A34/A42 và P06 chưa đóng.** Yêu cầu xác nhận thêm nguồn VNI tạm trong Cài đặt hệ thống vẫn chờ; công cụ UI yêu cầu xác nhận trước thay thiết lập hệ thống.

## Benchmark mới trên build 3

Lệnh thực đã chạy: `PHOTOAXIS_BUILD_ROOT=$BUILD_ROOT/P12-native2-benchmark bash scripts/benchmark.sh`. Xcresult `Benchmark-20261002-184106-90909.xcresult`: **3 PASS/0 FAIL/0 SKIP**, runtime173,448s. Kết quả được đọc lại và đối chiếu ngày03/10. Console `/tmp` không còn sau refresh môi trường thực thi; giữ giới hạn này trong manifest. `runtimeWarnings=[]` trong xcresult không chứng minh console không có Metal warning.

Benchmark binary Release với `ENABLE_TESTABILITY=YES` có UUID/hash riêng; không coi là bản app phát hành. Fixture6000×4000/24MPJPEG sRGB trên SSD;10layer; viewport1000×680pt/2×;5lượt mỗi chỉ tiêu,20mẫu/lượt mỗi tương tác. [Các số đo và phạm vi](../BENCHMARK_P12.md), [raw JSON](bang-chung/P12-native2/benchmark-interactions.json).

| Chỉ tiêu | N | Median ms | Max ms | p95 ms | Tỷ lệ worker ≤33,333ms |
| --- | --- | --- | --- | --- | --- |
| Open24MP | 5 | 97,12 | 99,34 | 99,34 | Không áp dụng |
| PNG24MP | 5 | 356,01 | 358,07 | 358,07 | Không áp dụng |
| Pan | 100 | 28,66 | 33,30 | 31,50 | 100% |
| Perspective corner | 100 | 34,57 | 65,09 | 40,91 | **31%** |
| Slider | 100 | 28,40 | 34,19 | 31,31 | 98% |
| Zoom | 100 | 28,33 | 33,07 | 30,75 | 100% |

Recovery5tab14,746s (mục tiêu30s).40MPPNG1,373s một lượt; không gọi là benchmark5lượt40MP. Stress5vòng thực canvas40MP/50layer/120MPnguồn/5tab; normalized decode cache0 sau mỗi vòng; process high-waterRSS tối đa2.799.468.544byte. GPU currentAllocated là sample; không suy ra leak-free, nativeFPS hoặc đáp ứng M1/16GB từ số đo này.

Open/Export/Recovery đạt mục tiêu worker tương ứng trên host. Perspective chỉ31% mẫu trong33,333ms, thấp hơn lượt lịch sử98%; tải/cache khác nhau chưa được kiểm soát đủ để gọi là regression sản phẩm. Test PASS không đồng nghĩa mục tiêu30fps đạt: assertion tương tác kiểm workerp95≤100ms, chưa input-to-present. Ghi **PERF-03** cần profile/đánh giá frame native và máy chuẩn trước đóng A36. A36/A37 vẫn mở; warning Metal/QoS ở lượt full suite trước vẫn chưa giải quyết.

## Kiểm tra độc lập và bàn giao

Chạy `python3 docs/bao-cao/bang-chung/P12-native2/verify.py`: **283 assertions PASS**; [kết quả](bang-chung/P12-native2/independent-audit.json) gồm ZIP/CRC/PNG/model, mốc Saved/Unsaved/Redo AX, phiên tab và tính lại median/max/p95/tỷ lệ từ mẫu gốc. Đây là audit của bằng chứng đã ghi, không phải một lượt UI mới. [SHA256SUMS](bang-chung/P12-native2/SHA256SUMS.txt) kiểm lại **157 file PASS**.

16 policy tests phân phối/public PASS; project inventory deterministic PASS;404khóaVI/EN/333tham chiếuPASS;12trang website previewPASS;git diff whitespace/link nội bộ/JSON và số19tick trong checklist khớp19PASS trong ma trận. [Summary](bang-chung/P12-native2/validation-summary.json). Preflight exit2 **BLOCKED_EXTERNAL**, publicReady=false/mutationPerformed=false đúng điều kiện hiện tại; [kết quả](bang-chung/P12-native2/publication-preflight.json). Đây là gate chặn phát hành dự kiến, không báo thành lỗi kiểm thử chức năng.

Tiến độ P00–P16 vẫn **9 DONE/7 BLOCKED_EXTERNAL/P16 khi cần**. Investigation1I01–I10 và Investigation2I11–I14 DONE local, không có gate public được đóng thêm. A01–A43 tăng **16→19PASS**,24ca chưa đóng. R01–R12 chưa gate nào PASS đầy đủ.

Tiếp theo: hoàn tất nguồn nhập/IME VI–EN và VNI để chốt P06; tiếp tục layout/shortcut/background-close/full workflow native. Bố trí macOS14/non-Retina/M1-16GB và dữ liệu camera/video được phép dùng, profile performance/Metal/QoS/quota điều tra. P13–P15 cần Developer ID/Team/namespace/notary và publisher/support/license/giá/repository/website target do chủ dự án xác nhận. Chưa remote/push/tag/public; DMG build3 local giữ provenance cũ đúng mã sản phẩm.
