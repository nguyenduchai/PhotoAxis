# Benchmark P12 — cập nhật build 3, 03/10/2026

Mã sản phẩm `0169bf5`, checkout trước báo cáo `3cfa00b`; fingerprint **317d062d…a0e9d02** vẫn khớp. PhotoAxis1.0.0(3), M1 Pro/32GiB/macOS27.0.1/Xcode27, SSD/arm64/Retina2×. [P12-native2](bao-cao/P12-native2.md), [manifest](bao-cao/bang-chung/P12-native2/manifest.json). Không có số đo M1/16GB/macOS14/non-Retina hoặc native input-to-present/FPS.

Lệnh thực: `PHOTOAXIS_BUILD_ROOT=$BUILD_ROOT/P12-native2-benchmark bash scripts/benchmark.sh`; root/DerivedData riêng, không thay regular Release app. Benchmark binary Release `ENABLE_TESTABILITY=YES`, UUID/hash riêng. Xcresult `Benchmark-20261002-184106-90909.xcresult` **3PASS/0FAIL/0SKIP**, đọc lại03/10/2026; runtime173,448s. Console/tmp không còn sau refresh môi trường; runtimeWarnings=[] trong xcresult không chứng minh không có console Metal warnings.

Fixture6000×4000JPEG sRGB/24MP fixed-seed,10layer (24MP+4MP+4text+4shape), viewport1000×680pt/backing2×/interactive sampling0,5.5lượt mỗi chỉ tiêu;20mẫu/lượt mỗi tương tác=100;warm-up loại, không xóa warm OS cache. Median toán học/p95 nearest-rank được tính lại từ raw JSON trong audit độc lập; không dùng một mẫu nhanh nhất.

| Chỉ tiêu | N | Median ms | Max ms | p95 ms | Worker≤33,333ms |
| --- | --- | --- | --- | --- | --- |
| Open24MP | 5 | 97,12 | 99,34 | 99,34 | — |
| PNG24MP | 5 | 356,01 | 358,07 | 358,07 | — |
| Pan | 100 | 28,66 | 33,30 | 31,50 | 100% |
| Perspective corner | 100 | 34,57 | 65,09 | 40,91 | **31%** |
| Slider | 100 | 28,40 | 34,19 | 31,31 | 98% |
| Zoom | 100 | 28,33 | 33,07 | 30,75 | 100% |

| Full-quality worker sau kéo | N | Median ms | Max ms | Max+150ms debounce |
| --- | --- | --- | --- | --- |
| Pan | 5 | 29,08 | 32,36 | 182,36ms |
| Perspective corner | 5 | 63,96 | 64,57 | 214,57ms |
| Slider | 5 | 28,76 | 29,62 | 179,62ms |
| Zoom | 5 | 27,45 | 30,27 | 180,27ms |

Open/Export/Recovery đạt mục tiêu worker trên host. **PERF-03:** corner31%≤33,333ms ở lượt mới, lượt lịch sử98% giữ bên dưới đúng phạm vi của nó. Tải/cache chưa kiểm soát nên chưa kết luận regression sản phẩm; không chọn lượt98% thay kết quả mới. Test tương tác chỉ assert workerp95≤100ms, không assert toàn mẫu≤33,333ms hay native30fps. Cần profile/native frame/input-to-present/máy chuẩn trước đóngA36.

Stress mới dùng3nguồn40MP distinct/120MP perdoc,50layer/5tab,5vòng thực Save/Open/edit/switch/render/resized Export/Recovery/Close;rejectlayer51/source120MP+1/tab6. Recovery5tab **14,746s** (mục tiêu30s);40MPPNG **1,373s**, chỉ một lượt. Cache decoded0 sau mỗi vòng;high-waterRSS tối đa2.799.468.544byte;RSS/currentMetalAllocated là sample,không peakGPUtrace/leak-free. [Rawstress](bao-cao/bang-chung/P12-native2/benchmark-stress.json), [open/export](bao-cao/bang-chung/P12-native2/benchmark-open-export.json), [interaction samples](bao-cao/bang-chung/P12-native2/benchmark-interactions.json), [audit](bao-cao/bang-chung/P12-native2/independent-audit.json). A36/A37/R02 vẫn mở; Metal/QoS từ suite trước chưa xử lý.

Các số bên dưới là lịch sử build1, không là số đo hiện hành build3.

# Mốc lịch sử build 1 — 02/10/2026

Code/product commit `a9737df`; baseline 1.0-draft.3; app1.0.0(1). Host M1 Pro/32 GiB/macOS27/Xcode27, SSD nội bộ, arm64, viewport1000×680pt/2×. Không có số đo M1/16GB, macOS14, pointer/input-to-present hoặc frame presentation GPU.

Lệnh: `scripts/benchmark.sh`; scheme PhotoAxisBenchmark/Release `-O`/WMO, `ENABLE_TESTABILITY=YES` chỉ phục vụ XCTest. App local final được build riêng bằng `scripts/build.sh Release` không testability. Fixture JPEG sRGB6000×4000 tự sinh fixed-seed; 10 layer: ảnh24MP + ảnh4MP +4text +4shape. Fixture hashes và toàn bộ sample nằm trong JSON. 5 lượt mỗi chỉ tiêu, 20 frame/lượt/tương tác =100 mẫu; median toán học (trung bình 2 mẫu giữa nếu số chẵn), p95 nearest-rank. Warm-up mở/render một lần bị loại; cache mở mới trong từng lượt, warm OS cache không bị xóa. Tác vụ Export dùng shared renderer→Image I/O→atomic destination.

| Chỉ tiêu | N | Median ms | Max ms | p95 ms | Phạm vi mục tiêu |
| --- | --- | --- | --- | --- | --- |
| Open24MP | 5 | 90.35 | 97.66 | 97.66 | worker ≤3000ms, chưa WindowServer |
| PNG24MP | 5 | 339.80 | 345.81 | 345.81 | ≤10000ms |
| pan worker | 100 | 25.29 | 30.62 | 28.98 | 100% ≤33,3ms; worker p95≤100ms |
| perspectiveCorner worker | 100 | 30.88 | 38.97 | 32.86 | 98% ≤33,3ms; worker p95≤100ms |
| slider worker | 100 | 24.89 | 31.71 | 28.69 | 100% ≤33,3ms; worker p95≤100ms |
| zoom worker | 100 | 24.67 | 29.60 | 28.09 | 100% ≤33,3ms; worker p95≤100ms |

| Full-quality worker sau kéo | N | Median ms | Max ms | Max +150ms debounce |
| --- | --- | --- | --- | --- |
| pan | 5 | 25.31 | 27.50 | 177.50ms worker estimate, chưa native present |
| perspectiveCorner | 5 | 57.03 | 59.95 | 209.95ms worker estimate, chưa native present |
| slider | 5 | 24.81 | 26.05 | 176.05ms worker estimate, chưa native present |
| zoom | 5 | 24.63 | 26.63 | 176.63ms worker estimate, chưa native present |

Trước tối ưu (P11 product code2796424, fixture tương tự): Perspective candidate worker median62,57ms, p95 69,65ms, 0%≤33,3ms. JSON tương tác trước được giữ riêng `interactions-before.json`. Sau giảm lấy mẫu Retina nhưng trước tối ưu mask vẫn ~60ms; mask cấp phát nguyên24MP+4MP là phần phải giảm theo viewport. Kết quả cuối dùng sampling0,5 và lightweight clip; final full clip/render không thay. Regression byte equality và settle1×/2× PASS. Một lượt khác cùng product optimization có ~68% mẫu perspective≤33,3ms, so với98% ở lượt cuối; tải/cache hệ thống có ảnh hưởng. Không dùng số đo worker này để tuyên bố native30fps đã đạt.

## Stress và thu hồi

Thực tạo/đọc 3 nguồn40MP distinct, tổng120MP/tài liệu, canvas8000×5000/40MP,50layer gồm3image+4text+43shape; mở5 `.paxis` bằng reader thật với UUID riêng và owned asset Data. 5 vòng Save→Open→edit→switch/render→Export resized→Recovery→Don’t Save/Close; full40MPPNG một lượt. Reject layer51, nguồn120MP+1 và tab6 nguyên tử. JSON ghi mỗi vòng/RSS/cache/Metal API. Không áp mục tiêu30fps cho tập giới hạn.

Recovery hoàn tất5tab `14.53s` (mục tiêu30s). PNG40MP một lượt `1.36s`; không phải benchmark5lượt PNG40MP.

RSS là resident snapshot và process cumulative high-water; `MTLDevice.currentAllocatedSize` là API sample, không là peak GPU trace. Cache normalized sau đóng phải0 trong cả5vòng. Allocator/driver retention có thể còn; không tuyên bố leak-free hay hỗ trợ8GB chỉ từ kết quả này. Console Metal MDB_MAP_FULL còn; xem KNOWN_ISSUES, không tắt/xóa log. Native UI responsiveness, Instruments và máy/OS/màn hình yêu cầu chưa kiểm chứng nên A36/A37 và R02 chưa PASS.
