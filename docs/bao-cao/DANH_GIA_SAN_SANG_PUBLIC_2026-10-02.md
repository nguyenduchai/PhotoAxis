# PhotoAxis — đánh giá triển khai và khả năng public, 02/10/2026

## Kết luận

**Chưa đủ điều kiện phát hành/vận hành public bản 1.0.0.** Ứng dụng native có các chức năng cốt lõi và các luồng dữ liệu chạy thực tế; có thể tiếp tục QA local có kiểm soát trên môi trường đã thử. Chưa có cơ sở công bố bản ổn định cho mọi máy trong phạm vi macOS 14+/Apple Silicon. Thiếu cả nghiệm thu sản phẩm và chuỗi phân phối, không chỉ chứng thư ký.

Baseline: `1.0-draft.3`; app `1.0.0 (1)`, schema `.paxis` 1. Checkout được đánh giá: `d4f4cf1e900a27e412684c9d49afb293bd9e5d10`, nhánh `main`, sạch trước đánh giá, chưa có remote. Mã app/test/config/project/fixtures/CI không đổi từ bản đã thử `787e3d1384f101fbd081c4fd8b3fc96a26d2520d`; website scripts và hồ sơ có thay đổi sau đó. Lượt đánh giá này chỉ bổ sung báo cáo/bằng chứng, không thay mã app hoặc nâng trạng thái gate.

Có **9 chặng DONE**, **7 chặng BLOCKED_EXTERNAL**, P16 thực hiện khi có issue sau public. A01–A43: **16 PASS, 27 CHƯA KIỂM CHỨNG**. R01–R12: **chưa gate nào đạt đầy đủ**, `releaseReady=false`, `publicReady=false`. Đây là số tiêu chí đã đủ bằng chứng; không phải tỷ lệ chức năng đã viết hay phần trăm công việc còn lại. Một chặng DONE vẫn có thể còn ca nghiệm thu tích hợp toàn sản phẩm ở P12.

Nguồn đối chiếu: [đặc tả](../DAC_TA_V1.0.md), [bối cảnh](../prompts/BOI_CANH_CHUNG.md), [tiến độ](../TIEN_DO_TRIEN_KHAI.md), prompt P00–P16, mã nguồn/test/config/scripts, [ma trận](../MA_TRAN_NGHIEM_THU.md), [P15 native](P15-native.md), [known issues](../KNOWN_ISSUES.md), RC/readiness/release manifests. Kiểm tra có chọn lọc các luồng model/render, lifecycle, ZIP giới hạn và ghi file nguyên tử; đây không phải kiểm toán bảo mật độc lập hay chứng nhận không còn lỗi.

## Đánh giá từng chặng

| Chặng | Trạng thái ghi nhận | Phần thực tế đã có | Phần còn thiếu hoặc giới hạn nghiệm thu |
| --- | --- | --- | --- |
| P00 — nền dự án | DONE | Xcode project, Swift/AppKit/Core/renderer, fixtures, build/test/evidence scripts và workflow CI. Debug/Release và app native có bằng chứng. | CI mới có cấu hình, chưa có lượt chạy remote. Lượt kiểm lại Xcode hôm nay bị chặn thiết lập ban đầu; xem phần kiểm tra mới. |
| P01 — workspace VI/EN | DONE | Menu, Tools/Options/Tabs/Sidebar, cấu hình và khôi phục layout, ngôn ngữ. Có ảnh/đo native ở các mốc. | Đối chiếu reference trên bản tích hợp cuối ở 1100×700, 1280×800, 1440×900 pt; toàn hover, focus, overflow và accessibility. |
| P02 — tài liệu/nhập/canvas | DONE | New/presets; JPEG/PNG/HEIC, EXIF/P3/alpha; Place/Clipboard; giới hạn tab/ảnh; canvas Metal, zoom/pan. | Nhập bộ ảnh thực trên macOS14; Finder drag/Clipboard liên ứng dụng bản cuối; pinch/đổi màn hình thật. |
| P03 — Layers/Undo/Transform | DONE | Layer ảnh/chữ/hình, thứ tự/khóa/opacity/duplicate, command/history/Undo/Redo, Move/Transform. | Reorder và handles/modifiers/History qua pointer/keyboard trên bản tích hợp cuối với mixed typed layers. |
| P04 — Crop/kích thước | DONE | Crop free/ratio/W×H, resize/anchor, rotate/flip, clip và nguồn giữ nguyên. Có geometry/pixel/native tests. | Luồng UI tích hợp cuối và máy/OS đích; close/quit khi đang crop/transform. |
| P05 — Perspective ảnh đơn | DONE | Quad 4 góc, Auto/Ratio/W×H, Preview/Apply/Cancel/Undo, kiểm quad lỗi, oracle định hướng/pixel. | Bản cuối đã có pointer VI/EN; còn Space/pinch/nhiều mức zoom/1× thật và độ trễ hiển thị. |
| P06 — Type/Shape/Color | BLOCKED_EXTERNAL | Unicode/TextKit, font/fallback, shape, fill/stroke, HEX/RGB, Eyedropper; nội dung giữ editable sau Perspective. | Telex/VNI thực là gate A22. Rà toàn shortcut/focus và X/D/Shift/Eyedropper cuối; paste Unicode không thay IME. |
| P07 — Perspective nhiều layer | DONE | Common mapping cho ảnh/chữ/hình/ẩn/khóa, source/type/clip giữ nguyên, chỉnh tiếp và thêm layer affine. A18/A19/A21 PASS. | Bản D54 bổ sung pointer EN và edit text/shape. Cảnh báo QoS và hiệu năng tổng thể tiếp tục đánh giá ở P12. |
| P08 — điều chỉnh ảnh | DONE | Exposure/Brightness/Contrast/Saturation, Enable/Reset, preview, một gesture một Undo, neutral/pixel oracle và source bất biến. | A25 Save/reopen đã được P09 kiểm và PASS; UI/focus tích hợp cuối còn thuộc A34/A40/A42. |
| P09 — `.paxis`/Save/Open | DONE | ZIP tự chứa, schema/model/type/matrix/clip/params/sources, bounded reader và CRC/SHA; atomic Save, marker đúng snapshot, Finder và VI↔EN. | A27/A28 PASS trong phạm vi đã ghi. Chưa nghiệm thu cài sạch/máy khác, close/quit trong Save/Export nền và đầy đủ alert native. Undo phiên cũ không lưu là thiết kế đã duyệt. |
| P10 — PNG/JPEG/màu | BLOCKED_EXTERNAL | Export thực, sRGB8/ICC/PPI/resize, PNG alpha, JPEG quality/matte, bỏ metadata nguồn không cần thiết, atomic/overwrite/cancel. Native D54 và tests PASS phạm vi host. | HDR camera thực, bộ ảnh rộng/halo và macOS14 (A33); không gọi synthetic ISO gain-map là ảnh camera đã thử. |
| P11 — Recovery/lifecycle/ngôn ngữ | BLOCKED_EXTERNAL | Timer snapshot thật, startup recovery VI/EN, recovered dirty/Save As, lỗi/corrupt/race tests, Quit hai tab Cancel/DontSave/restart native. | IME; crop/transform và close/quit trong Save/Export đang chạy; settings/restart dirty, shortcut/tooltip/accessibility/error sweep cuối. |
| P12 — nghiệm thu/RC/hiệu năng | BLOCKED_EXTERNAL | Functional suite, 3 benchmark opt-in, full-quota/5 vòng, workflow VI/EN, ma trận/manifest/known issues. | 27 ca chưa đủ bằng chứng; macOS14/1×/M1-16GB/low-resource, native input-to-present, Instruments/long run và Metal/QoS. |
| P13 — ký/DMG | BLOCKED_EXTERNAL | Icon, config/script/policy, local DMG D54 có provenance và đã mount/đối chiếu payload. | Developer ID Application, namespace/Team/notary profile chính thức; signed archive hiện hành, Hardened Runtime/timestamp, Accepted/staple, Gatekeeper/cài sạch/offline/upgrade. |
| P14 — website/hồ sơ | BLOCKED_EXTERNAL | 12 trang VI/EN, hướng dẫn/support/privacy/notices/release notes, ảnh native Perspective/Recovery D54, preview desktop/mobile và ZIP riêng. | Chủ thể/support/license/giá/terms chính thức, HTTPS host/canonical, link bộ cài đã ký. Download còn disabled, chưa deploy. |
| P15 — public/hậu kiểm | BLOCKED_EXTERNAL | Preflight R01–R12, 15 policy tests, kiểm HTTPS/hash/signature và runbook. | Chưa remote/push/CI/tag/release/deploy. Chưa tải ẩn danh từ URL thực, cài bản tải, đối chiếu commit/checksum giữa các đích; rollback thực chưa được kiểm. |
| P16 — bảo trì | KHI CẦN | Có định hướng xử lý issue/runbook. | Chưa có phát hành public để bắt đầu vòng bảo trì; P16 không phải điều kiện phải hoàn thành trước 1.0.0. |

Báo cáo lịch sử ghi số test ở từng mốc; không cộng 6+13+27+… thành tổng test hiện hành. Một chặng bị chặn không có nghĩa chưa viết chức năng, và một chặng DONE không tự đóng R02.

## Kiểm tra mới trong lượt đánh giá

Bằng chứng mới tại [READINESS-20261002](bang-chung/READINESS-20261002/assessment-checks.json); [checksum hồ sơ](bang-chung/READINESS-20261002/SHA256SUMS.txt).

| Kiểm tra | Kết quả | Phạm vi |
| --- | --- | --- |
| `python3 scripts/generate-project.py --check` | PASS | Xcode project khớp inventory hiện hành. |
| `python3 scripts/check-localization.py` | PASS | 298 khóa VI/EN khớp, 285 tham chiếu được resolve. Không thay sweep nội dung/focus/IME native. |
| `python3 scripts/check-website.py` | PASS | 12 trang; local links/anchors/metadata/alt/provenance/disabled download; không scripts/trackers. Không kiểm host/HTTPS ngoài repo. |
| `python3 -m unittest discover -s Tests/ReleaseTooling -v` | 15 PASS | Chính sách phát hành và downloader: chặn sai identity/gate, HTTPS downgrade/checksum/size, giữ file cũ… Không phải 15 lượt upload/cài public. |
| `python3 scripts/release-audit.py preflight --config Config/Distribution.example.json` | BLOCKED_EXTERNAL, exit 2 | `publicReady=false`, `mutationPerformed=false`; liệt kê chính xác config và gate thiếu. Exit 2 là fail-fast đúng dự kiến. |
| Đối chiếu hồ sơ/artifact | PASS | 111 checksum bằng chứng P15-native, 43 checkbox khớp ma trận; UUID/hash app/Core khớp RC/DMG; checksum DMG, cây file/symlink app đã đóng gói; 25 file website/ZIP CRC/byte khớp. |
| `codesign --verify --deep --strict` app Release và payload đã đóng gói | PASS local | Chữ ký **ad-hoc** hợp lệ, arm64; không Developer ID, không Hardened Runtime, không Accepted/staple. |
| Đọc lại `.xcresult` functional/benchmark | PASS hồ sơ | Functional 113 PASS/0 FAIL/4 SKIP/2 runtime warnings; benchmark riêng 3 PASS/0 FAIL/0 SKIP. Các lượt này chạy trên macOS27.0. |
| `bash scripts/check.sh` hôm nay | BLOCKED_SETUP, exit 69 | Máy hiện macOS27.0.1; project/localization/plist PASS rồi dừng ở `xcodebuild -checkFirstLaunchStatus`, **chưa chạy test**. |

Đã kiểm rõ thiết lập Xcode: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, Xcode27.0 (27A266a); `-license check` exit0 nhưng `-checkFirstLaunchStatus` exit69, stdout/stderr rỗng. Global `xcode-select` là CommandLineTools; script đã tự chọn Xcode per-process đúng hướng dẫn, nên đây không phải lỗi script dùng nhầm CLT. Chưa tự đổi xcode-select, cài thành phần hay nhận kết quả test mới. Cần hoàn tất thiết lập đầu Xcode rồi chạy lại suite trên27.0.1. [Log](bang-chung/READINESS-20261002/full-suite-attempt.log), [probe explicit](bang-chung/READINESS-20261002/xcode-status-explicit.json).

Release đang đối chiếu: UUID `D54A11BC-024A-3419-B64C-9D70715C2ED9`, executable SHA-256 `efb838f4862a126a463cd2fbe200e2ff8e6aadba11929e30067113f1f8d1c9ba`, Core SHA-256 `abd7d3e450bf3cae2a8bd283fd9d4df44eb792785b5e7ed88715776a436e196e`. Local DMG SHA-256 `dc75214a98520c14bd6b3d34e4e510580cd49f4824122d7eef8a06b04aaf9e2e`. Đây là checksum **local unsigned**, không phải checksum bộ cài public. Không rebuild Release, chạy lại benchmark hoặc native UI sweep trong lượt đánh giá. Không đổi fingerprint mã đã compile sang HEAD tài liệu mới.

Các nguồn API HDR được rà trong SDK header: `kCGImageSourceDecodeRequest`/`kCGImageSourceDecodeToSDR` khai báo từ macOS14.0, không thấy mâu thuẫn availability ở các symbol đó. Điều này không thay chạy app/ảnh HDR thực trên macOS14. Scan TODO/FIXME không thấy placeholder chức năng tương ứng; `required init(coder:)` có `fatalError` là initializer bị cấm trong UI lập trình, không tự suy đó là crash người dùng đã tái hiện.

## Những phần nghiệm thu chưa thực hiện đủ

- **A01–A13:** reference/layout cuối, preset toàn bộ, ảnh thực/OS đích, drag/paste liên ứng dụng, session/Undo đa tab, pinch/màn hình, typed reorder/Transform/Crop/Size. Có tự động và native lịch sử, chưa đủ bản tích hợp cuối ở mọi điều kiện yêu cầu.
- **A15:** đã có pointer quad/Preview/Apply VI/EN D54; còn Space/pinch/zoom, màn hình1× và độ trễ hiển thị thực.
- **A22/A24/A26:** Telex/VNI thực; pointer/keyboard màu/shape/Eyedropper; History nhiều loại command cùng Save. Các phần model/Unicode có test không thay thao tác đầu vào này.
- **A33:** HDR camera, đánh giá màu/halo trên bộ ảnh thực và macOS14.
- **A34/A39–A42:** phím tắt/focus/IME, toàn luồng người dùng, menu/tooltip/AX/alert VI/EN, Settings/restart với dirty documents, mọi dialog tại ba kích thước cửa sổ.
- **A35–A38:** quota trên máy ít tài nguyên, M1/16GB, native FPS/input-to-present, Instruments/long run; cài sạch/offline bản signed thực từ download/Gatekeeper.

Các ca đã PASS: A14, A16, A17, A18, A19, A20, A21, A23, A25, A27, A28, A29, A30, A31, A32, A43. Xem cột phạm vi trong [ma trận](../MA_TRAN_NGHIEM_THU.md), đặc biệt synthetic/fault/hosted/native và OS. Chưa tái kiểm desktop đang khóa hay mở khóa trong lượt đánh giá; tình trạng khóa ở P15-native là bằng chứng lịch sử. Lỗi công cụ resize `windowNotFoundAtPosition` không chứng minh lỗi layout app.

## Hiệu năng và độ ổn định: khả quan nhưng chưa đủ kết luận public

Số đo [P12](../BENCHMARK_P12.md) trên **M1 Pro/32GiB/macOS27.0/Retina2×**: Open24MP median90.35ms/max97.66ms; PNG24MP median339.80ms/max345.81ms (mỗi chỉ tiêu5 lượt). Pan/zoom/slider worker ~25ms; Perspective median30.88ms, p95 32.86ms, max38.97ms/100mẫu. Một lượt khác chỉ ~68% mẫu Perspective dưới33.3ms so với98% lượt cuối. Đây là **worker**, không phải FPS hay thời gian từ input đến màn hình.

Full-quota đã thực tạo/đọc 40MP/50layer/120MP/5tab, 5 vòng Save/Open/edit/render/Export/Recovery/Close. Recovery5tab14.528s (<30s), cache normalized về0 sau mỗi vòng; peak process high-water RSS2,782,789,632byte (~2.8GB). Một lượt PNG40MP1.355s không thay benchmark5lượt. Metal allocated là sample, không GPU peak trace; 5 vòng không chứng minh không leak. Chưa xác nhận cấu hình tối thiểu đề xuất8GB/khuyến nghị16GB hoặc benchmark chuẩn M1/16GB.

Console Metal `MDB_MAP_FULL` và 2 cảnh báo priority inversion vẫn cần khoanh nguyên nhân và mức ảnh hưởng bằng stack/Instruments/native. Test xanh không giải quyết cảnh báo; chưa có bằng chứng kết luận chúng gây crash, cũng chưa có bằng chứng kết luận vô hại trên mọi máy. Lỗi tiến độ Save/Export bị refresh/đổi tab/zoom ghi đè đã sửa tại787e3d1 và có regression/native Cancel40MP.

CI hiện chỉ chạy native `check.sh` và Release build trên `macos-15`/Xcode16.4. Cần bổ sung hoặc kết nối việc chạy static website và 15 release-policy tests vào CI trước public, rồi có lượt chạy remote thực trên source phát hành; chưa nhận CI PASS từ YAML tồn tại. Theo [GitHub runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), `macos-15` là arm64/M1/7GB; [image manifest](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md) có Xcode16.4. Chưa thấy cấu hình đó sai theo inventory hiện tại; CI VM không thay máy chuẩn16GB/màn hình1×/IME thực.

## Những bước phân phối/vận hành chưa thực hiện

| Gate | Trạng thái | Phần chưa có |
| --- | --- | --- |
| R01 | BLOCKED_EXTERNAL | Chủ thể phát hành/support/license/giá, bundle IDs/UTI/Team/Developer ID/notary profile, GitHub/website/visibility/quyền chính thức. |
| R02 | BLOCKED_EXTERNAL | Nghiệm thu sản phẩm đầy đủ, môi trường/máy đích, warnings và native tổng thể. |
| R03 | CHƯA KIỂM CHỨNG | Provenance của signed artifact cuối; local D54 khớp không thay artifact này. |
| R04 | BLOCKED_EXTERNAL | Developer ID Application và chữ ký phân phối/Hardened Runtime/timestamp thật. |
| R05 | BLOCKED_EXTERNAL | Notarization Accepted và staple/validate app/DMG thật. |
| R06 | CHƯA KIỂM CHỨNG | Bộ cài public/checksum cuối; local DMG đã kiểm vẫn chưa đủ. |
| R07 | BLOCKED_EXTERNAL | Download qua browser/quarantine/Gatekeeper/cài sạch trên OS đích. |
| R08 | BLOCKED_EXTERNAL | Luồng offline và nâng cấp với bản signed đã cài, dữ liệu/Recovery an toàn. |
| R09 | BLOCKED_EXTERNAL | Website HTTPS và hồ sơ chính thức/link signed installer; hiện preview disabled. |
| R10 | CHƯA KIỂM CHỨNG | Tải ẩn danh từ URL HTTPS public thật, redirects/content/size/hash/signature. |
| R11 | CHƯA KIỂM CHỨNG | Đối chiếu source/HEAD/tag/CI/site/asset/checksum và bản tải sau public. |
| R12 | CHƯA KIỂM CHỨNG | Quyền đích, artifact/trang maintenance, thử rollback thực; có runbook nhưng chưa diễn tập. |

Apple mô tả Developer ID cho Gatekeeper khi phát hành ngoài App Store, kiểm app với Hardened Runtime, notarization và ticket/stapler tại [Signing Mac Software with Developer ID](https://developer.apple.com/developer-id/). Việc local `codesign --verify` PASS không thay chuỗi phân phối đó. Keychain hiện có Apple Development nhưng không Developer ID Application.

R01–R09 và R12 là chuẩn bị/nghiệm thu trước public theo tooling hiện hành. **R10/R11 thực hiện sau khi có URL/artifact public**; không yêu cầu giả kết quả tải trước khi publish. Cần giữ khả năng gỡ link/bảo trì/rollback khi hậu kiểm thất bại. Quy trình đã chọn: nghiệm thu → signed/notarized/stapled installer → clean install/offline/upgrade → website/hồ sơ/rollback sẵn → source CI/tag/release/deploy → anonymous download/install/commit-hash cross-check. Không mở nút tải trước khi các gate tiền phát hành đạt.

Ứng dụng offline không cần xây backend/tài khoản/cloud để public. Phần vận hành cần kênh tải và hỗ trợ thật, người phụ trách, phát hành bản vá thủ công, bảo trì/rollback và quản lý version/artifact. Chưa có bằng chứng các đích vận hành ngoài repo đã hoạt động.

## Công việc tiếp theo và đầu vào cần thiết

1. Hoàn tất môi trường Xcode hiện tại và rerun suite; đóng các ca native có thể kiểm trên desktop: IME, layout/keyboard/History/màu, đa tab/settings, close/quit trong task và session. Đánh giá Metal/QoS có số đo; sửa nếu tái hiện ảnh hưởng.
2. Nghiệm thu macOS14, màn hình1×, M1/16GB và low-resource; xác minh8GB nếu tiếp tục công bố là cấu hình tối thiểu. Không âm thầm đổi phạm vi đã duyệt.
3. Chốt publisher/support/license/giá; namespace App/Core/UTI; Team và tên Developer ID Application/notary Keychain profile đã cấu hình trên máy. Không cần gửi bí mật vào chat.
4. Chốt source repository/visibility, distribution repository public (có thể khác repo source), remote/quyền, website HTTPS/hosting/deploy mode/terms URL. Tạo CI checks đầy đủ và chạy thực trên revision phát hành.
5. Hoàn thành P13–P15 theo gate: signed/notary/staple/package/checksum/cài sạch/offline/upgrade, website chính thức, rollback, public và hậu kiểm. P16 sau public khi có issue.

Các bước1–2 có công việc QA/kỹ thuật, không được quy hết cho thiếu tài khoản ký. Các bước3–4 cần quyết định/quyền thật của chủ dự án. Chưa có cơ sở ước lượng chắc thời gian hoặc công bố phần trăm hoàn tất từ số chặng.

## Phần ngoài phạm vi V1.0

PSD/RAW, brush/eraser, pixel selection/mask, AI/OCR, Intel/App Store, cloud/tài khoản/updater tự động… được loại khỏi baseline; không coi chúng là hạng mục quên triển khai của V1.0.

Gói phục vụ điều tra đã được người dùng đồng ý **ghi nhớ để triển khai sau**, chưa nhập vào baseline1.0-draft.3 và chưa có implementation/nghiệm thu riêng: kho file tiếp nhận nguyên byte/bản làm việc/hồ sơ bàn giao/SHA-256/nhật ký bền vững; vụ việc/danh mục ảnh/chú thích/so sánh nguồn-kết quả/EXIF; A4-PDF/che dữ liệu bản xuất. OCR/video/đo hiệu chuẩn ở giai đoạn sau. Không lấy Undo hiện tại làm audit log qua Save/Open, hoặc `.paxis` nguồn nhúng/crop/layer che làm bảo đảm bảo toàn hồ sơ và xóa dữ liệu chia sẻ. Gói này không chặn public V1.0 đúng baseline, nhưng PhotoAxis hiện chưa thể được giới thiệu là bộ công cụ hồ sơ ảnh điều tra hoàn chỉnh.

## Đầu ra đánh giá

[Tiến độ](../TIEN_DO_TRIEN_KHAI.md) được cập nhật để dẫn báo cáo này và tình trạng rerun môi trường. [Ma trận](../MA_TRAN_NGHIEM_THU.md), [READINESS_PUBLIC.json](../READINESS_PUBLIC.json), [RELEASE_CANDIDATE.json](../RELEASE_CANDIDATE.json) giữ nguyên16/27 và `false`. Không push/tag/publish/deploy; không tạo signed artifact mới hoặc gán các ảnh/native lịch sử cho lượt đánh giá này.
