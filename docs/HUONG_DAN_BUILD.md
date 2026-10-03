# Build và kiểm tra PhotoAxis

## Yêu cầu

- Mac Apple Silicon; deployment target macOS 14.0, Swift 6; Xcode 16.4 trở lên với macOS SDK và thiết lập ban đầu hoàn tất. Máy P00–P02 dùng Xcode 27.0, xem báo cáo để biết cấu hình đã kiểm chứng; khả năng chạy trên macOS 14 phải thử riêng ở P12.
- Python 3 để kiểm tra/tái tạo project và bản dịch. Không cần Homebrew package, dependency ứng dụng, Apple Developer Team hoặc chứng thư phát hành.
- Chủ máy đọc/chấp nhận license Xcode khi Xcode yêu cầu. Script không tự chấp nhận license, cài component hệ thống hoặc đổi xcode-select toàn máy.

## Lệnh từ gốc repository

```sh
./scripts/check.sh
./scripts/build.sh Debug
./scripts/build.sh Release
```

`check.sh` kiểm tra inventory Xcode, khóa dịch vi/en, plist, build Debug và chạy Swift Testing (Core) cùng XCTest hosted trong PhotoAxis.app qua shared scheme. Bộ P08 có 85 ca: 33 Core + 52 AppKit/Image I/O/renderer, gồm hồi quy P00–P07. Trên máy hiện tại 84 PASS, một ca IME skip do input context chỉ thấy ABC; cần nghiệm thu Telex/VNI thực tế trước khi chốt P06. Summary giữ một cảnh báo QoS tại shape Cancel/focus để theo dõi ở P12; xem báo cáo P08. Fixture nhỏ tự tạo ở Fixtures/P02 được nhúng vào test bundle; Cmd+U/CLI không cần đọc Documents hoặc sinh fixture trước. Lỗi bước nào thì dừng với exit code khác 0; result bundle `.xcresult` được in ở cuối. Release build dùng tối ưu `-O`; vẫn là bản ký ad-hoc cho phát triển, Hardened Runtime chưa bật vì không có Team ID để xác thực framework nhúng, **chưa phải bản public**. P13 phải dùng Developer ID và bật runtime; không cần thay đổi bảo vệ hệ thống để chạy bản local.

Script giữ DEVELOPER_DIR nếu đã đặt. Nếu xcode-select chỉ CLT và `/Applications/Xcode.app` tồn tại, script chọn Xcode này riêng cho tiến trình. Có thể chỉ định Xcode khác:

```sh
DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer ./scripts/check.sh
```

Output mặc định: `~/Library/Developer/PhotoAxisBuilds/<hash-path-repo>/DerivedData/Build/Products/{Debug,Release}/PhotoAxis.app`. Hash tách build của các checkout; đường dẫn thật được script in ra. Để lấy đường dẫn và mở app:

```sh
bash -c 'source scripts/environment.sh; open "$PHOTOAXIS_BUILD_ROOT/DerivedData/Build/Products/Debug/PhotoAxis.app"'
```

Muốn lưu log:

```sh
mkdir -p build/logs
set -o pipefail
./scripts/check.sh 2>&1 | tee build/logs/debug-test.log
```

Override `PHOTOAXIS_BUILD_ROOT` nếu cần, chọn ổ local ngoài Documents/iCloud/File Provider. Không đặt output build vào Git. Metadata Finder trên bundle có thể khiến codesign từ chối; lỗi này không phải thiếu Developer ID. Không cần xóa quarantine để chạy app tự build.

## Mở bằng Xcode

```sh
open PhotoAxis.xcodeproj
```

Chọn shared scheme **PhotoAxis**, destination **My Mac**, Run (Cmd+R), Test (Cmd+U). Xcode dùng DerivedData mặc định của Xcode ngoài repo; project không cần generator cài thêm. Debug/Release lấy cấu hình từ `Config/*.xcconfig`. Local bundle ID `local.photoaxis.development`, Team rỗng, identity `-`; tên ứng dụng PhotoAxis, version 1.0.0 (build 3).

Khi thêm/xóa file Swift hoặc thay cấu trúc target:

```sh
python3 scripts/generate-project.py
python3 scripts/generate-project.py --check
```

Generator là nguồn cấu trúc project; sửa generator thay vì sửa project.pbxproj thủ công. Shared scheme được lưu riêng trong `xcshareddata/xcschemes`. Không commit xcuserdata.

## Fixture và kiểm tra cửa sổ

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift scripts/generate-fixtures.swift
```

Xem `Fixtures/README.md`; generator tự đọc lại metadata và ghi manifest. Đây chưa phải test đường nhập ảnh của app.

P01 có workspace tối và Cài đặt (Cmd+,). Đổi System Default/Tiếng Việt/English, đóng PhotoAxis bằng Cmd+Q rồi mở lại để áp dụng. Thử đổi bố cục, thu gọn, menu Cửa sổ > Đặt lại không gian làm việc và Tab khi canvas có focus; Tab trong ô nhập Cài đặt phải giữ nguyên bảng.

Khi lựa chọn ngôn ngữ trong Cài đặt là **Theo hệ thống**, có thể smoke-test mà không đổi preference toàn máy:

```sh
bash -c 'source scripts/environment.sh; open -n "$PHOTOAXIS_BUILD_ROOT/DerivedData/Build/Products/Debug/PhotoAxis.app" --args -AppleLanguages "(vi)"'
# Lần sau thoát app và thay (vi) bằng (en).
```

Không mở nhiều instance có tài liệu thật bằng cách này ở các chặng sau. Kiểm tra cửa sổ, text, nút disabled, Cmd+W và mở lại qua Dock; chụp chỉ cửa sổ app, lưu bằng chứng cùng phiên bản/máy. Ứng dụng có override ngôn ngữ lưu riêng, nên `-AppleLanguages` không thay thế lựa chọn Tiếng Việt/English đã lưu trong Cài đặt. P02 đã bật New/Open/Place và điều hướng canvas. Save/Save As/Export chưa triển khai vẫn disabled; P03 bật Move/Transform/Layers, P04 bật Crop thường và menu Image Size/Canvas Size/rotate/flip; P05 bật Perspective Crop ảnh đơn; P06 bật Type/Shape/Color/Eyedropper. Đóng tài liệu chưa lưu mặc định Cancel; chỉ Không lưu mới bỏ dữ liệu.

## CI và release

`.github/workflows/ci.yml` khai báo macos-15 arm64/Xcode 16.4, Debug/test và Release local; checkout ghim SHA. CI chạy khi PR/push nhánh main hoặc codex/** hoặc gọi thủ công. Không có secret ký, thao tác publish, tạo tag hay tải binary công khai. Repo public và CI đã hoạt động tại https://github.com/nguyenduchai/PhotoAxis/actions . CI Xcode16.4 được kiểm thực; xem báo cáo Pages03/10 về các lỗi và bản sửa. Local macOS27 fullsuite gần nhất144PASS/1FAIL Telex/3SKIP, không thay nghiệm thu IME/thiết bị.

P13/P15 mới bổ sung danh tính, Developer ID/notarization và phát hành có kiểm soát; không dùng app ad-hoc phát triển để public.

## Kiểm tra bố cục P01

`PhotoAxisAppTests` tạo các cửa sổ native ở 1440×900, 1280×800, 1100×700 pt cho vi/en. Xuất 6 PNG content view và `layout-measurements.json` vào `$PHOTOAXIS_BUILD_ROOT/p01-native-tests/` khi chạy script (ngoài Git); JSON ghi cả frame cửa sổ, content view và backing scale. Chiều cao title bar thuộc macOS, không trừ cố định để giả lập số đo. Test dùng suite UserDefaults riêng và dọn suite của chính nó.

Các test còn kiểm tra language lifecycle/fallback, persistence/reset/corrupt preference, giới hạn và parse số, mouse hit-test/responder và keyboard qua NSWindow, focus khi nhập, tool/flyout disabled và overflow. Mở `.xcresult` bằng Xcode để xem từng test; ảnh PNG bổ sung cần xem trực quan. Không dùng test window thay cho nghiệm thu trên macOS 14/non-Retina hoặc chuột/trackpad thật.

Bộ tham chiếu được cố định ở `docs/tham-chieu/P01/`; kết quả đã kiểm tra ở `docs/bao-cao/P01.md`. Ảnh từ công cụ điều khiển app có thể đã thu nhỏ, không dùng để đo kích thước point. Hosted tests cần phiên macOS có WindowServer; CI macOS chưa được kiểm chứng trong repository hiện chưa có remote.

## Kiểm tra tài liệu P02

New (Cmd+N), Open (Cmd+O), File > Place Embedded; thả vào canvas để chèn layer, vào thanh tab để mở tài liệu mới. Dán PNG/TIFF hoặc URL ảnh khi canvas có focus. Hand (H), Zoom (Z), Space tạm dùng Hand, scroll pan, pinch zoom; ô zoom nhận 5–1600%, số thập phân theo **vùng macOS**, độc lập ngôn ngữ UI. 100% là pixel thiết bị (0.5 pt/pixel ở Retina 2×).

Fixture cố định trong test bundle ở Fixtures/P02 (108 KiB). Test bổ sung tự sinh HEIC, gray 16 bit, PNG không profile, APNG, TIFF nhiều trang, PNG cạnh 8001 trong output test. Kết quả pixel PNG tại `$PHOTOAXIS_BUILD_ROOT/p02-native-tests/`; `.xcresult` có các assertion. Các đường này áp dụng script; Xcode direct đặt output cạnh cây sản phẩm test tương ứng. Không dùng file người dùng làm fixture.

Nếu có tài liệu thật đang mở, dùng bản sao QA có bundle ID riêng; chỉ thay Info.plist nhận dạng, ký lại ad-hoc và ghi hash vào báo cáo. Không đóng instance chứa dữ liệu ngoài bộ thử. Save/Export/Recovery chưa có; bản P02 chưa phù hợp để giữ công việc chỉ tồn tại trong tài liệu chưa lưu.

## Kiểm tra Layers/Transform P03

Mở fixture `Fixtures/P02/grid-corners.png`, chọn Move (V), nhân bản Cmd+J, double-click tên hoặc nút Đổi tên; thử visibility/lock/opacity, đưa lên/xuống và xóa. Cmd+T mở X/Y/W/H/góc, liên kết tỷ lệ/flip; nhập số theo vùng hệ thống. Return trong ô nhập trả focus canvas, Return tiếp theo Apply; Escape ở canvas Cancel. Khi phiên còn mở, đổi tool/đóng/chọn lớp khác hỏi Apply/Discard/Cancel. Chuyển tab giữ nguyên phiên ở tab cũ.

Arrow dịch 1 px, Shift+Arrow 10 px; Auto-Select bỏ qua phần alpha rỗng và layer ẩn/khóa. Tám tay nắm resize cùng tay nắm quay, Shift tạm đổi giữ tỷ lệ/bắt quay 15°. Cmd+Z/Shift+Cmd+Z và History có tên command theo UI; chọn trạng thái cũ rồi sửa cắt Redo. Pan/zoom/chọn layer không thêm lịch sử. Save `.paxis` vẫn disabled, marker chỉ đã kiểm chứng qua API/model đến P09.

`LayerHistoryTests` và `LayerEditingTests` kiểm tra lock/quota/shared source, projective composition, 100 bước/128 MiB, saved marker/nhánh, rollback/UndoManager, linear opacity/pixel alpha, native handles/modifier/keyboard/Space-pan, fields và opacity action. PNG trong `$PHOTOAXIS_BUILD_ROOT/p03-native-tests/` là output renderer của hosted tests; ảnh cửa sổ Release và giới hạn QA ghi trong báo cáo P03. Không dùng test responder thay bằng chứng kéo chuột vật lý.

## Kiểm tra Crop/kích thước P04

Chạy `./scripts/check.sh` rồi `./scripts/build.sh Release`. Bộ tại mốc P04 gồm 47 test (20 Core + 27 AppKit). `CropGeometryTests` kiểm tra giao clip, source immutable, hidden/locked, 9 anchor, PPI, orientation và projective composition; `CropEditingTests` đối chiếu pixel render, Undo/Cancel/session theo tab, responder handles/pan và nhập số liên tục. PNG image-only ở `$PHOTOAXIS_BUILD_ROOT/p04-native-tests/`.

Trên bản QA cô lập: Open `Fixtures/P02/grid-corners.png`, nhấn C, kéo góc/cạnh, chọn tỷ lệ hoặc W×H, Return/Apply và Undo/Redo. Thử 8001 rồi sửa 160 để xác minh validation phục hồi. Menu Image có Image Size, Canvas Size và rotate/flip. Sau Crop, Canvas Size mở rộng không được lộ lại vùng đã cắt. Settings → English cần mở lại app. Nhật ký/ảnh và cấu hình ở [báo cáo P04](bao-cao/P04.md); chỉ dùng fixture tự tạo, không ghi ảnh cá nhân vào bằng chứng.

## Perspective Crop P05 và Metal Toolchain

P05 thêm Core Image warp kernel biên dịch offline. Với Xcode có Metal Toolchain tách riêng, cài thành phần chính thức một lần nếu compiler báo thiếu:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -downloadComponent MetalToolchain
```

Generator tạo build phase có dependency cho `Sources/PhotoAxisApp/Renderer/Perspective.ci.metal`. Phase ghi intermediate trong TEMP_DIR và nhúng `Perspective.metallib` vào Resources; script sandbox vẫn bật. `./scripts/check.sh` kiểm cả đường Metal bằng fixture có pole ngoài vùng giữ lại. `./scripts/build.sh Release` phải chứa metallib và qua codesign verify. Không cần tải toolchain khi chạy app đã build.

QA: Open fixture, Shift+C hoặc flyout Crop, kéo tạo khung/chỉnh bốn góc; kiểm Auto/Ratio/W×H, Swap/Clear/Reset/grid/Preview và Enter/Escape. Mỗi Apply chỉ một History entry, Undo/Redo khôi phục canvas. Báo cáo [P05](bao-cao/P05.md) tách hosted tests, native Release và thiết bị còn chưa kiểm chứng; F08 toàn V1.0 còn P07/P09/P10.

## Tích hợp nhiều layer P07

Chạy cùng `./scripts/check.sh` và `./scripts/build.sh Release`. `MultiLayerGeometryTests` kiểm mapping/rollback nguyên tử và matrix scale; `MultiLayerPerspectiveTests` kiểm pixel oracle, Preview/Apply, Undo/Redo hai crop, nguồn typed/hidden/locked, chữ cũ Properties/chữ mới affine, shape edit/Move/Transform/hit-test và clip không hồi sinh. Output PNG/JSON ở `$PHOTOAXIS_BUILD_ROOT/p07-native-tests/`; số đo 24 vòng fixture nhỏ không thay benchmark toàn quota P12.

QA native dùng tài liệu ảnh/chữ/ellipse, khóa/ẩn layer cũ rồi Shift+C crop; Undo/Redo; double-click thumbnail chữ cũ mở Properties; thêm chữ mới nằm thẳng; sửa Fill/Stroke ellipse. Hosted test VI/EN kiểm focus/scroll ở 1100×700 pt. Bằng chứng và giới hạn pointer English/Telex/QoS ở [P07](bao-cao/P07.md); Save/Open A20 chưa nghiệm thu trước P09/P10.


## Điều chỉnh ảnh P08

Chọn layer ảnh chưa khóa, Properties có Exposure −4…+4 EV và Brightness/Contrast/Saturation −100…+100%. Kéo slider preview rồi nhả chuột để chốt một Undo; nhập số theo locale macOS và Return; Apply/Cancel hoặc Escape cho numeric preview. Tắt Image Adjustments chỉ bypass, giữ số; Reset bật nhóm và đưa bốn số về 0. Khóa layer chặn cả UI và model. Text/shape không có nhóm này.

QA: neutral/bypass, các cực trị, Saturation −100 ra xám, alpha edge, hai layer đã Perspective; Cancel/Undo/Redo, một gesture nhiều tick và một entry History; kiểm đổi tab không nhận frame cũ. Renderer test viết PNG ở `$PHOTOAXIS_BUILD_ROOT/p08-native-tests`, không phải tính năng Export UI. Kết quả và provenance native VI/EN ở [P08](bao-cao/P08.md); Save/reopen A25 thuộc P09.

## Các công cụ local sau P12–P15

- `scripts/benchmark.sh`: Release opt-in, 3 ca thật/không skip; worker latency và quota, không phải native FPS.
- `scripts/build.sh Release`: binary local không testability; app/DerivedData/results ngoài repository.
- `python3 -m unittest discover -s Tests/ReleaseTooling -v`: policy và hậu kiểm synthetic.
- `python3 scripts/distribution.py local`: DMG LOCAL-UNSIGNED/payload/hash, không public.
- `python3 scripts/build-website.py` và `python3 scripts/check-website.py`: preview 12 trang Việt/Anh, nút tải disabled. Chạy HTTP server theo website README để xem.
- `python3 scripts/release-audit.py preflight --config Config/Distribution.example.json`: hiện BLOCKED exit2 do config mẫu/gates. Không sửa readiness để bỏ qua nghiệm thu.

Đọc P12–P15/manifest/known issues cho UUID/commits và khác biệt Release/benchmark/QA/archive. Signed/notary/public cần đầu vào thật; không dùng local DMG để kết luận Gatekeeper hoặc public download.
