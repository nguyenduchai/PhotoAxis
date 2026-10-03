# PhotoAxis — Tiến độ thực hiện

## Hợp nhất workspace — build 5, 03/10/2026

**DONE local:** đã bỏ menu/cửa sổ Điều tra riêng, hợp nhất vào bảng **Chỉnh sửa / Nguồn / Phân tích / Đầu ra** của workspace PhotoAxis. Tham số nằm trong bảng bên phải; OCR/đo/vùng che/chú thích chọn trực tiếp trên canvas. Đối chiếu và rà soát hiển thị ngay trong cửa sổ chính. Tệp → Mở nhận `.paxcase`; danh mục và hồ sơ đồng bộ với tab. Draft đổi tab/model được hủy; không thay mất tab orphan chưa lưu; nguồn và durable audit giữ nguyên.

- Full suite cuối **168 ca: 164 PASS / 1 FAIL Telex đã biết / 3 SKIP benchmark**; **9 ca mới PASS**. Release/ad-hoc PASS, UUID **E9797D10-3807-344C-AE33-A172F11B04A5**. 466 khóa VI/EN/392 references, inventory/12 trang website/16 policy PASS; không còn constraint xung đột trong log cuối.
- Native binary cuối VI/EN: mở case/ảnh, kéo ROI OCR34,33,1489,420→đúng3dòng→xác nhận giữ bản máy; đo100mm→50mm; swipe/zoom chung; chọn vùng che→PNG148.200pixel đen đục. Đối chiếu độc lập19event/source/archive/output hashes PASS. OCR cold vẫn chờ đáng kể, chưa đóng qualification.
- [Báo cáo đầy đủ](bao-cao/HOP_NHAT_WORKSPACE_2026-10-03.md), [provenance](bao-cao/bang-chung/WORKSPACE-20261003/build-manifest.json), [hướng dẫn](HUONG_DAN_DIEU_TRA.md). Website VI/EN đã cập nhật thao tác build5; receipts CI/Pages/DMG local được bổ sung cùng bàn giao.
- `releaseReady=false`. Source/website public đã được duyệt; stable installer còn thiếu nghiệm thu IME/native/máy đích/quota/hiệu năng/ảnh-video-đo thực và DeveloperID/notary/cài sạch. **19/43 là acceptance build3 lịch sử, không nhận là full build5.** Trạng thái9DONE/7BLOCKED_EXTERNAL/P16khi cần của baseline chưa đổi. Các tiện ích timeline/batchOCR/search/PDFbảngOCR/nắn sách3D chưa triển khai.


## Scan1 — build4, 03/10/2026

**Đã bổ sung cả bốn nhóm chức năng bản scan theo yêu cầu, S01–S09 DONE local.** Phát hiện góc trang/căn chữ; làm trắng nền/giảm bóng–ám màu/nhiễu/làm rõ chữ/đen trắng thích nghi; nắn cong hai trục thủ công; chuẩn hóa A4/Letter/custom/PPI và batch1–50ảnh. Preview trước/sau/Apply một Undo/Cancel, metadata editable và source giữ nguyên; Scan schema3, đọc lại1/2; audit hồ sơ làm review/chuẩn đo cũ stale khi model đổi.

- Fullsuite mã cuối **155PASS/1FAILTelex/3SKIP**,159total;11caScan mới đềuPASS. NativeVI/EN và batchEN2trang đổi thứ tự→PNG/project/PDF/manifest→byte/hash/schema độc lậpPASS. Release/ad-hocPASS,16policyPASS,452khóaVI/EN/381referencesPASS,12websitepagesPASS.
- Fixture đường cong biết trước: độ trải baseline60px→0px. Đây là oracle nhỏ cho mô hình bow, không phải nghiệm thu mọi trang sách thực. Nắn sách3D tự động/PDF–TIFFimport/batchOCR chưa triển khai. Datasetcamera/sách/chữký/nétmảnh,50trangfullquota/macOS14/M1-16GB/performance chưa qualification.
- GitHubCI Xcode16.4/macOS15.7.9: **154PASS/0FAIL/5SKIP**, Debug/test/ReleasePASS. DMGbuild4 source sạchd8cb1d0 đượcmount/tree/codesign/GPL/hashPASS; SHA256 `0079c4b29cffa37cf68446f8df59cb01fb4a2fd00021bf1d5115eb8f053a05f8`. [CI](bao-cao/bang-chung/SCAN-20261003/ci-summary.json), [receipt](bao-cao/bang-chung/SCAN-20261003/delivery-receipt.json).
- Source/website public tiếp tục cùng GPLv3repo; DMGbuild4local và receipts được giao riêng. `releaseReady=false`, nút tải stable vẫn tắt. 19/43nghiệm thu baseline là phạm vi build3 lịch sử; chưa nhận đủ nghiệm thu build4.

[Đặc tả](DAC_TA_SCAN.md), [hướng dẫn](HUONG_DAN_SCAN.md), [báo cáo kết quả](bao-cao/SCAN_2026-10-03.md), [manifest cuối](bao-cao/bang-chung/SCAN-20261003/build-manifest.json), [readiness](READINESS_PUBLIC.json).


## Website, mã nguồn GitHub và DMG — 03/10/2026

**Đã hoàn thành yêu cầu website GitHub Pages, công khai source và xuất DMG local.** [Một repo ứng dụng/website](https://github.com/nguyenduchai/PhotoAxis), [website Việt/Anh](https://nguyenduchai.github.io/PhotoAxis/), giấy phép **GPL-3.0-only**, hỗ trợ GitHub Issues. 12 trang đã cập nhật hướng dẫn tự build, Privacy GitHub và ảnh OCR/đo build 3; 27 file HTTPS/hash/manifest cùng browser desktop/mobile VI/EN PASS.

- DMG build 3 từ source sạch 43a5b93, binary UUID741E1DF7, SHA256 `447f1b3649d29518edbe4c1eae53acd7300ef8a4dd03bca8c1558bb93b6e94db`; mount/tree/codesign/hash/LICENSE/SOURCE/detach và bản sao giao PASS. Có sửa callback Undo đồng bộ để tương thích Xcode16.4.
- CI GitHub Xcode16.4/macOS15.7.9: **143 PASS/0 FAIL/5 SKIP**, Debug/test và Release PASS. SKIP benchmark/IME/màn hình lớn không đóng các nghiệm thu này. Local full suite **144 PASS/1 FAIL Telex/3 SKIP**; HDR/layout riêng **2 PASS/0 FAIL/0 SKIP**. 16 policy tests, inventory và 404 khóa VI/EN PASS.
- Source/website đã public; **bộ cài stable public vẫn chưa đủ**: 19/43 ca nghiệm thu PASS, thiếu Developer ID/notary/cài sạch và các qualification đang ghi. `releaseReady=false`, installer download disabled. Snapshot source public loại ảnh Adobe nội bộ; lịch sử cũ giữ local.

[Báo cáo và các bằng chứng](bao-cao/GITHUB_PAGES_DMG_2026-10-03.md), [receipt DMG](bao-cao/bang-chung/GITHUB-PAGES-20261003/delivery-receipt.json), [CI](bao-cao/bang-chung/GITHUB-PAGES-20261003/ci-final-summary.json), [readiness](READINESS_PUBLIC.json).

Workflow Pages có job hậu kiểm HTTPS/hash/commit sau mỗi deploy, lưu receipt `pages-https-proof` 30 ngày; bản receipt bàn giao được giữ cùng DMG. Kiểm trên runner GitHub độc lập với AdGuard đang chèn script vào HTML nhận tại máy. [Workflow và kết quả mới nhất](https://github.com/nguyenduchai/PhotoAxis/actions/workflows/pages.yml).

## Nghiệm thu native trước công khai — build 3, 03/10/2026

**Đã chốt thêm A04/A07/A26 qua native Tiếng Việt và English; tổng 19/43 PASS, 24 ca chưa đóng.** Tạo/lưu đủ4preset và custom, validation/nền/PPI,5tab/giới hạn thứ6, phiên chữ/Undo riêng từng tab, History branch và Saved marker đều đã kiểm. Audit độc lập ZIP/model/preview/AX/samples PASS, nguồn sản phẩm/binary không đổi. [Báo cáo](bao-cao/P12-native2.md), [bằng chứng](bao-cao/bang-chung/P12-native2/manifest.json).

- Benchmark build3 mới **3PASS/0FAIL/0SKIP** trên root riêng: Open24MP median97,12ms; PNG24MP356,01ms; recovery5tab14,746s; cache0 sau5vòng full quota. Perspective corner chỉ31% mẫu worker≤33,333ms, cần đánh giá PERF-03; chưa nativeFPS/máyM1-16GB. [Số đo mới/lịch sử](BENCHMARK_P12.md).
- A22 có tiến bộ từng phần: phím ASCII trên UI VI thực thành “tiếng việt\nthử nghiệm”, Return/CmdReturn/Save/Escape và file đúng. EN chưa xác minh nguồn nhập, VNI chưa kiểm; **P06/A22 vẫn BLOCKED_EXTERNAL**. Không thay chứng minh composition cụ thể bằng Unicode paste/marked-text test.
- Full suite144PASS/0FAIL/4SKIP là lượt Investigation2 của cùng code, không nhận đã rerun chặng này. Release/QA VI–EN/Core/fingerprint/codesign đối chiếu lại PASS. App1.0.0(3), source0169bf5/checkout3cfa00b trước báo cáo; chưa sửa mã sản phẩm.

**Chưa đủ public.** P00–P16 vẫn9DONE/7BLOCKED_EXTERNAL/P16khi cần; Investigation1I01–I10 và Investigation2I11–I14 DONE local; R01–R12 chưa gatePASS đầy đủ. Còn IME/native tổng thể/macOS14/non-Retina/M1-16GB/performance/Metal-QoS/quota điều tra, dữ liệu ảnh/video/đo thực, DeveloperID/notary/cài sạch và publisher/support/license/giá/target. [Readiness](READINESS_PUBLIC.json), [known issues](KNOWN_ISSUES.md). Bước tiếp: hoàn tất nguồn nhập/IME để chốtP06, tiếp tục phần native độc lập và qualificationP12; chuỗiP13→P15 khi đủ danh tính/target/gates.

## Bàn giao Investigation 2 — 02/10/2026 (lịch sử)

**Đã triển khai cả ba nhóm mở rộng OCR tiếng Việt, video và đo có hiệu chuẩn; I11–I14 DONE local.** Bản **PhotoAxis1.0.0(3)** gồm I01–I14, native/offline; source `0169bf52cd0d3793c0027a82888833c8a58f4f78`, full suite **144PASS/0FAIL/4SKIP**, Release/ad-hoc và DMG local PASS,16policytestsPASS,404khóaVI/EN/333tham chiếuPASS. [Báo cáo mở rộng](bao-cao/MO_RONG_DIEU_TRA.md), [tổng tiến độ/public](bao-cao/TONG_TIEN_DO_VA_PUBLIC_2026-10-02.md), [hướng dẫn](HUONG_DAN_DIEU_TRA.md), [provenance](bao-cao/bang-chung/INVESTIGATION2/build-manifest.json).

- OCR sourceROI/bản máy read-only, revision xác nhận riêng, hash/engine/OS/log; fixture nhận đúng3dòng ngoài ROI không nhận. Native VI và EN mở/xác nhận/verify trên binary cuối.
- Raw video giữ đúng byte; actual decoded ordinal/PTS rational/track/transform/videohash; frame2 PTS0,350s và offset5giây giữ riêng, frame1 PTS0,100s. FramePNG SDR8bit riêng, không suy từ nominalFPS hoặc hứa pixel decode nguyên video.
- Calibration thước/đơn vị/căn cứ/modelhash; distance50cm và area100cm² trên fixture, stale guard và fault rollback. JSON phân tích snapshot riêng/unredacted với output receipt/hash. Case schema1 vẫn đọc, thêm analysis chuyển schema2; `.paxis` thường1/working2 giữ nguyên.
- Đối chiếu độc lập20event/hash/state,3ảnh/archive,1video,2OCR/2frame/3measure; output trước English confirmation cuối. Ảnh/AX native final UUID **4EFA7887-E96F-3149-B6F5-68BE3475F219** ở [INVESTIGATION2](bao-cao/bang-chung/INVESTIGATION2/native-qa.txt).
- DMG build3 local đúng source sạch, mount/tree/codesign/detachPASS, SHA `797ee11a3267d0fde0a90d003a97379fca3ffa442ece1a6d0c75f50aea8a84bc`; artifact ngoàiGit `$BUILD_ROOT/P13-local-_pehi_4j`. Chưa DeveloperID/notary/Gatekeeper/cài sạch. [Manifest](RELEASE_MANIFEST.md).

**Chưa đủ public.** BảngP00–P16 vẫn9DONE/7BLOCKED_EXTERNAL/P16khi cần; A01–A43 vẫn16PASS/27chưa đóng, R01–R12 chưa gatePASS đầy đủ. Chưa nghiệm thu Telex/VNI/native tổng thể/macOS14/non-Retina/M1-16GB/hiệu năng/quota/Metal-QoS; gói mới cần kiểm VIavailability/cold-warm/video camera/codec/điều kiện đo thực. Gallery website D54/build1 giữ vai trò lịch sử, hướng dẫn/privacy/release notes đã cập nhật nội dung mới. [Known issues](KNOWN_ISSUES.md), [readiness](READINESS_PUBLIC.json), `releaseReady=false`.

Bước tiếp theo: đóng P06/A22 và nghiệm thu native độc lập, bố trí máy đích/dữ liệu được phép dùng/đo full quota để chốt P12; có DeveloperID/Team/namespace/notary và target/publisher/support/terms mới hoàn tất P13→P14→P15. Chữ ký số hồ sơ/timestamp bên ngoài/mã hóa/kho tập trung và các tiện ích timeline/batchOCR/clickpoints/PDFbảngOCR còn ngoài phạm vi hiện có; không tự nâng thành gate baseline mới.

## Bàn giao Investigation 1 — build2 (lịch sử)

**Gói phục vụ điều tra đã triển khai và kiểm chứng local I01–I10 (DONE).** PhotoAxis **1.0.0 (2)**, code `826bebf61c068ca1864fdf8a20f6b410ca13aa2f`; full suite **130 PASS/0 FAIL/4 SKIP**, Release/codesign local PASS, 16policytests PASS, 367khóa vi/en. Native VI/EN mở hồ sơ/Save/verify/zoom/pan/swipe/PNG/PDF/log đã chạy; đối chiếu35event và source/archive/output hashes, PNG2.035pixel vùng che đen đục, PDF raster A4 đã xem từng trang. [Báo cáo đầy đủ](bao-cao/GOI_DIEU_TRA.md), [hướng dẫn thao tác](HUONG_DAN_DIEU_TRA.md), [đặc tả riêng](DAC_TA_GOI_DIEU_TRA.md), [provenance](bao-cao/bang-chung/INVESTIGATION/build-manifest.json).

- Giữ file tiếp nhận đúng byte và metadata riêng trong `.paxcase`; working `.paxis` schema2, bản thông thường schema1; intake/ID/hash và nhật ký bền vững độc lập Undo. Archive tiếp nhận chuẩn hóa được giữ để phục hồi Delete → Save → Undo.
- Danh mục hồ sơ, mũi tên/ellipse/số/chữ/ô phóng to, so sánh nguồn/kết quả đồng bộ và metadata raw phân biệt thông tin do người dùng bổ sung.
- Bản ảnh PDF A4 1/2/4ảnh/trang, danh mục nguồn/full log JSON; review regions gắn model hash, PNG/PDF flatten có vùng che riêng và receipt. Save/lỗi ghi log/Cancel hai tab kiểm bằng test; output ghi worker.

Xcode27 first-launch setup đã hoàn tất và suite mới thực sự PASS trên macOS27.0.1. Bằng chứng assessment exit69 trước đó giữ làm lịch sử. Release hiện hành UUID **12159300-9A9E-32E9-8A06-08297E444A0B**. DMG D54/website gallery build1 là artifact lịch sử, không có Investigation 1. Candidate/readiness build2 đã cập nhật, **chưa đủ public**. A01–A43/R01–R12 không tự được đóng từ I01–I10; bảng P00–P15 dưới đây vẫn giữ trạng thái đã nghiệm thu trước đó.

Bước tiếp theo: thử quy trình với bộ ảnh được phép dùng, đo quota/thiết bị hỗ trợ và tiếp tục đóng nghiệm thu native/IME/Metal-QoS/máy đích; chuẩn bị ký/public khi có danh tính và target. OCR/video/đo có hiệu chuẩn chưa triển khai, thuộc phần mở rộng sau. [Known issues](KNOWN_ISSUES.md), [readiness hiện tại](READINESS_PUBLIC.json). Không suy hash thành bằng chứng nguồn gốc/thời gian hoặc chuỗi bảo quản đầy đủ.

## Quyết định đã xác nhận

- Đặc tả 1.0-draft.3 đã được người dùng chốt.
- Tên PhotoAxis; UI Tiếng Việt/English; `.paxis` một file ZIP.
- Phân phối trực tiếp từ website/GitHub Releases, ngoài Mac App Store.
- **Đánh giá sẵn sàng public trước gói điều tra — 02/10/2026 (lịch sử):** [báo cáo chi tiết từng chặng](bao-cao/DANH_GIA_SAN_SANG_PUBLIC_2026-10-02.md). 9 chặng DONE, 7 BLOCKED_EXTERNAL; A01–A43 có 16 PASS/27 chưa đủ bằng chứng, R01–R12 chưa gate nào đạt đầy đủ. Chưa đủ điều kiện public; phần còn thiếu gồm nghiệm thu native/IME/máy đích/hiệu năng và chuỗi ký–phân phối–vận hành. Kiểm lại inventory/localization/website/15 policy tests và 111 checksum PASS. Rerun `check.sh` trên macOS27.0.1 dừng trước test ở `xcodebuild -checkFirstLaunchStatus` exit69; license check exit0. Giữ 113 PASS trước đó đúng phạm vi macOS27.0, không nhận lượt mới đã PASS. Bằng chứng [READINESS-20261002](bao-cao/bang-chung/READINESS-20261002/assessment-checks.json).
- **P00–P05, P07–P09 DONE; P10/P11 triển khai và test local xong.** Save/Open `.paxis`, PNG/JPEG/ICC/atomic Export và committed recovery đã có. Bản sửa tiến độ **787e3d1 chạy 113 PASS/0 FAIL/4 SKIP**, Release PASS; benchmark renderer riêng trước đó 3 PASS. [P15-native](bao-cao/P15-native.md)/[ma trận](MA_TRAN_NGHIEM_THU.md) là bằng chứng baseline build1: native crop VI/EN, Save/Open/edit/Export/cancel/Recovery/quit hai tab đã có; còn native tổng thể/IME/macOS14/non-Retina/máy chuẩn, chưa đủ R02. Export/Recovery không còn là chức năng “chưa xây”.

## Ảnh chụp trạng thái khi soạn prompt

Repo có tài liệu và Git trên nhánh `main`, chưa có commit và chưa cấu hình remote tại lần kiểm tra này. Đây là dữ liệu ngày 20/09/2026, phải kiểm tra lại khi thực hiện P00. Mockup hiện có là mô phỏng tiếng Anh; chưa thay thế app native hoặc kiểm tra vi/en.

## Các chặng

| Chặng | Nội dung | Trạng thái | Bằng chứng/commit |
| --- | --- | --- | --- |
| P00 | Nền dự án, build, mô hình kiến trúc, dữ liệu thử | DONE | [Báo cáo P00](bao-cao/P00.md): Debug/test 6 PASS, Release build và mở native vi/en, manifest/log/ảnh; commit chứa báo cáo |
| P01 | Workspace native và khung Việt/Anh | DONE | [Báo cáo P01](bao-cao/P01.md): 13 test PASS, 6 ảnh/đo layout native, Release vi/en, persistence/reset; commit chứa báo cáo |
| P02 | Tài liệu, nhập ảnh, canvas, tab, zoom/pan | DONE | [Báo cáo P02](bao-cao/P02.md): 27 test PASS, native nhập/5 tab/zoom/pan/Place/alpha/close, Release và manifest; commit chứa báo cáo |
| P03 | Layer, command/undo, Move/Transform | DONE | [Báo cáo P03](bao-cao/P03.md): 38 test PASS, Release PASS, native Layers/Transform/History/Undo/Redo Việt–Anh; đã sửa overlay vượt viewport |
| P04 | Crop thường và hình học canvas | DONE | [Báo cáo P04](bao-cao/P04.md): 47 test PASS, Release PASS, native Crop/size/rotate/flip Việt–Anh; pixel/clip/source giữ nguyên |
| P05 | Perspective Crop trên ảnh đơn | DONE | [Báo cáo P05](bao-cao/P05.md): 60 test PASS, Release/chữ ký PASS; native quad/Preview/Apply/Undo/Redo vi/en; giữ nguồn/clip, xử lý pole ngoài vùng giữ |
| P06 | Type, Shape, Color | BLOCKED_EXTERNAL | [Báo cáo P06](bao-cao/P06.md): đã triển khai, 69 PASS/0 FAIL/1 IME SKIP; Release/native vi-en PASS phạm vi đã ghi; còn Telex/VNI thực tế A22 |
| P07 | Perspective Crop nhiều layer và chỉnh tiếp | DONE | [Báo cáo P07](bao-cao/P07.md): A18/A19/A21 PASS; 77 PASS/0 FAIL/1 IME SKIP; Release/chữ ký PASS; native VI và hosted VI/EN; P15-native bổ sung pointer EN bản D54; QoS còn theo dõi |
| P08 | Điều chỉnh ảnh | DONE | [Báo cáo P08](bao-cao/P08.md): phần điều chỉnh A25 PASS; 84 PASS/0 FAIL/1 IME SKIP tại mốc P08; Release/native/AX/alpha/Undo; Save/reopen A25 đã được P09 kiểm PASS |
| P09 | Định dạng `.paxis`, Save/Open an toàn | DONE | [P09](bao-cao/P09.md): schema/ZIP bounded, atomic Save/native Finder/VI↔EN; 94 PASS/0 FAIL/1 IME SKIP; A25/A27/A28 |
| P10 | Export PNG/JPEG và màu | BLOCKED_EXTERNAL | [P10](bao-cao/P10.md): implementation/P15-native PNG/JPEG/ICC/cancel40MP PASS; A20/A31/A32/A43 đạt phạm vi host, A33 camera/macOS14 còn thiếu |
| P11 | Recovery, vòng đời tài liệu, hoàn thiện ngôn ngữ/focus | BLOCKED_EXTERNAL | [P11](bao-cao/P11.md): P15-native startup VI/EN/SaveAs/quit2tab/Cancel/DontSave/restart PASS; IME/native tổng thể còn thiếu |
| P12 | Nghiệm thu A01–A43, hiệu năng, Release Candidate | BLOCKED_EXTERNAL | [P12-native2](bao-cao/P12-native2.md): build3 native A04/A07/A26 vi/en,19/43PASS; benchmark mới3PASS;144suitePASS cùng code ở lượt trước; native tổng thể/IME/thiết bị/performance còn thiếu |
| P13 | Ký, notarization, DMG, kiểm tra phân phối | BLOCKED_EXTERNAL | [P13](bao-cao/P13.md): icon/config/script/8policyPASS/localDMGverified; thiếu DeveloperID/R02/notary/clean install |
| P14 | Trang giới thiệu/tải, hướng dẫn, hồ sơ public | BLOCKED_EXTERNAL | [P14](bao-cao/P14.md):GitHub Pages public12trang VI/EN/desktop-mobile/27HTTPS-hash/sourceGPLv3/Issues PASS; gallery D54build1 và4EFAbuild3 cóprovenance; bộcàisigned/acceptance còn chờ |
| P15 | Public và kiểm tra đường tải thực | BLOCKED_EXTERNAL | [P15](bao-cao/P15.md):Source/websiteGitHub public vàPagesHTTPS đãkiểmPASS theo yêu cầu03/10;16policyPASS; bộcàisigned/cleaninstall/tag vẫnchưađủgates |
| P16 | Bảo trì/bản vá sau public | KHI CẦN | Không phải điều kiện chặn 1.0.0 |

## Bàn giao baseline build1 trước gói điều tra (lịch sử)

- **Đã bổ sung kiểm tra native thực và sửa lỗi UI — 02/10/2026.** Code commit `787e3d1`: giữ tiến độ Save/Export khi refresh/đổi tab/zoom. Full suite **113 PASS/0 FAIL/4 SKIP**, Release PASS; 4 SKIP gồm IME và benchmark opt-in. Benchmark riêng 3 PASS trước đó vẫn đúng phạm vi renderer không đổi; 15 policy tests của công cụ phân phối/public. [P15-native](bao-cao/P15-native.md) ghi source/UUID/hash và lỗi fixture QA đã sửa bằng ditto.
- **Các ca đã chốt thêm theo phạm vi máy đã thử:** A20/A23/A29/A30/A31/A32/A43. Native D54: pointer phối cảnh VI/EN; Save As/Open/sửa chữ hai dòng và shape; PNG/JPEG/ICC/PPI; Cancel encode40MP giữ byte đích/0 temp; timer/startup Recovery VI/EN/SaveAs; quit hai tab Cancel giữ dữ liệu, DontSave dọn records và restart không hồi sinh. Model/nguồn nhúng và PNG RGBA VI/EN giống nhau. Không nhận Unicode AX/paste là Telex/VNI.
- **P12–P15 có implementation và đầu ra local; toàn chặng vẫn BLOCKED_EXTERNAL.** Native shortcut/layout/reference/background-close tổng thể, bộ gõ thật, macOS14/non-Retina/M1-16GB/native present latency và đánh giá Metal/QoS còn thiếu. CUA kéo cạnh/góc không tìm được window, chưa kiểm resize tối thiểu; lần rà thêm History/shortcut sau đóng gói bị desktop khóa lại; không gọi đây là lỗi app. [Known issues](KNOWN_ISSUES.md), [readiness](READINESS_PUBLIC.json), `releaseReady=false`.
- **Website đã cập nhật ảnh native cuối VI/EN**, gồm Perspective trước/sau và startup Recovery đúng D54. Kiểm lại static/ảnh/layout CSS1280/390; site ZIP/manifest tách app. Preview localhost8642. Publisher/support/license/giá/target HTTPS/quyền chưa chốt; nút tải vẫn disabled, chưa deploy.
- **P13/P15 chưa signed/public:** có icon/DMG D54 mới được mount/đối chiếu payload và hash đúng bản test (checkout sạch 2a28b93, SHA `dc75214a…aaf9e2e`), archive P13 là lịch sử, và scripts fail-fast; cần Developer ID Application/Team/namespace/notary profile, target GitHub/source visibility/website/quyền và nghiệm thu R02/cài sạch. Không remote/push/tag/public; không dùng checksum local làm checksum bộ cài public. [Release manifest](RELEASE_MANIFEST.md), [P13](bao-cao/P13.md), [P15](bao-cao/P15.md).

## Bàn giao trước lượt native bổ sung (lịch sử)

- **P11 implementation/test hoàn tất; BLOCKED_EXTERNAL native/IME.** 109 PASS/0 FAIL/1 IME SKIP; timer ~10 giây, process QA `_exit(86)`/store mới phục hồi đúng, Cancel nhiều tab giữ records, Save đúng state/Discard chống resurrection. [P11](bao-cao/P11.md). P12 tiếp tục đo 24MP/10 layer và toàn quota.

- **P10 implementation/test đã xong; BLOCKED_EXTERNAL lượt native do máy khóa.** 102 PASS/0 FAIL/1 IME SKIP; PNG/JPEG actual ICC, alpha/matte/resize/PPI/GPS, HDR Save/Open và atomic Export. [P10](bao-cao/P10.md). Tiếp tục P11–P15 độc lập; không biến phần chờ desktop/macOS14 thành PASS.

- **P09 DONE — 02/10/2026.** `.paxis` ZIP32, schema 1 `photoaxis.document`; immutable sources/SHA-256, typed text/shape/image, Double matrix/clip và params. Safe Save/Save As có snapshot/saved state, native overwrite/cancel, Finder open; 94 PASS/0 FAIL/1 IME SKIP. A25/A27/A28 đạt, A20/A43 còn Export. [Báo cáo P09](bao-cao/P09.md), [format](DINH_DANG_PAXIS.md), [manifest](bao-cao/bang-chung/P09/build-manifest.json).
- **Tiếp tục P10–P15 theo yêu cầu làm toàn bộ ngày 01/10/2026.** Export → recovery/lifecycle/languages → acceptance/benchmark → signing/package → website/docs → public/postcheck. P16 chỉ khi có issue sau public. Không khởi động lại P00.
- P06 A22 vẫn BLOCKED_EXTERNAL do chưa có Telex/VNI thực. P12 đã chạy full-quota/worker benchmark; pointer English đã bổ sung native D54. macOS14/non-Retina/máy chuẩn/native present và QoS/MDB_MAP_FULL còn cần đánh giá. P11 xử lý Open/Close wording cũ. Không đổi các mục này thành PASS từ một build/test xanh.
- Máy có Apple Development nhưng **chưa có Developer ID Application**, chưa remote GitHub/website, chưa chốt chủ thể/support/license/giá hoặc notary profile. Đã hỏi thông tin cần thiết và đang làm các phần local độc lập; P13/P15 không giả ký/notarize/public.
- App 1.0.0 (1), baseline 1.0-draft.3; M1 Pro/32 GiB, macOS27/Xcode27, arm64/minOS14. Ký ad-hoc local, không push/public. Bundle/results ngoài repository tại `~/Library/Developer/PhotoAxisBuilds/83990cd22abb`.

## Bàn giao P08 (lịch sử)

- **P08 DONE — 01/10/2026.** Exposure −4…+4 EV; Brightness/Contrast/Saturation −100…+100%, neutral 0. Nhóm Image Adjustments thuộc từng layer image; chỉ chọn ảnh chưa khóa mới sửa. Thứ tự filter trước geometry/composite, neutral/bypass giữ byte RGBA, Saturation −100 xám; không thay nguồn hoặc màu layer khác. Duplicate giữ tham số và chia sẻ source. Contract dữ liệu đã bàn giao P09.
- Properties native có slider/ô số EV/%/Enable/Reset và cuộn. Preview riêng, một drag một Undo; Return chốt số, Cancel/Escape phục hồi đúng; Reset đồng thời bật nhóm. Sửa gesture dừng ở điểm bắt đầu, refresh ghi đè số khi mở session, numeric mất focus trước Cancel và action AX/keyboard. Có hồi quy opacity slider và generation thumbnail khi Undo/đổi tab.
- **84 PASS (33 Core + 51 AppKit), 0 FAIL, 1 IME SKIP, 1 runtime warning QoS cũ P07.** P08 thêm 7 test (2 Core, 5 AppKit); hosted VI/EN kiểm 12 tick/one Undo, numeric/validation/focus/lock và opacity. Pixel kiểm 1.102 mẫu alpha, 87 mẫu alpha một phần, dung sai 1/255; neutral/bypass so byte; oracle linear-sRGB độc lập và layer khác sau Perspective không đổi.
- Đo ngắn 20 render 640×480: median **3,32 ms**, max **4,75 ms**; không tăng decode nguồn qua tick nóng; cache 2.457.600 byte → 0 sau release. 60 preview liên tục/chuyển tab bỏ frame cũ. Chưa thay benchmark toàn quota/RSS/GPU P12.
- Release/chữ ký ad-hoc PASS, **268 khóa vi/en/255 tham chiếu**. Native VI kéo Exposure trên binary trước sửa action AX; final hosted VI/EN PASS. Release EN binary cuối đã chạy AX action/drag/numeric/validation/Cancel/Enable/Reset/Undo/Redo/gray/lock. Nhật ký và manifest ghi riêng UUID từng binary, không gán ảnh cũ cho bản cuối.
- **P06 vẫn BLOCKED_EXTERNAL ở A22.** Ca IME skip do context không có nguồn Telex/VNI thực. Chưa nhận kết quả kiểm tra tay bộ gõ/macOS/Return/Cmd+Return/Escape/composition; Unicode paste/marked-text không thay nghiệm thu này. Commit P06 `494b24e`, P07 `0eeba37`; các bằng chứng cũ giữ nguyên. P07 pointer English mixed-layer và warning QoS tiếp tục theo dõi P12; lượt native P08 không đóng các mục đó.
- Bằng chứng mới: [P08](bao-cao/P08.md), [manifest](bao-cao/bang-chung/P08/build-manifest.json), [summary](bao-cao/bang-chung/P08/test-summary.json), [native QA](bao-cao/bang-chung/P08/native-qa.txt), [số đo](bao-cao/bang-chung/P08/response-measurements.json). Tra commit chặng bằng `git log -1 --format='%H %s' -- docs/bao-cao/P08.md`.
- App Release tại `~/Library/Developer/PhotoAxisBuilds/83990cd22abb/DerivedData/Build/Products/Release/PhotoAxis.app`; QA EN cuối tại `QA/P08/PhotoAxis P08 en verified.app`, cùng executable UUID **FF8AFACD-DEAE-3E9C-A849-DF55BFE9834C**. QA VI completed có chữ ký/UUID cuối, còn ảnh pointer VI ghi ở QA vi verified UUID cũ như nhật ký. Bundle/results ngoài Git; log chuẩn hóa đường dẫn/ID máy.
- **Bàn giao lịch sử từ P08 sang P09 — đã thực hiện, xem mục gần nhất.** A25 còn Save/reopen; A20 còn P09/P10, A43 còn round-trip VI/EN. P09 phải giữ source bytes, params enabled/range/fractions, type/payload/matrix/clip/order/flags, shared sources và saved marker. Không khởi động lại P00.
- App 1.0.0 (1), baseline 1.0-draft.3; M1 Pro/32 GiB, macOS 27/Xcode 27, arm64/minOS14.0, ký local ad-hoc. Không remote/push/public. Recovery P11, full quota/macOS14/non-Retina/P07 pointer EN/QoS P12, ký/phát hành P13–P15 còn chưa triển khai/nghiệm thu.

Lịch sử: [P00](bao-cao/P00.md), [P01](bao-cao/P01.md), [P02](bao-cao/P02.md), [P03](bao-cao/P03.md), [P04](bao-cao/P04.md), [P05](bao-cao/P05.md), [P06](bao-cao/P06.md), [P07](bao-cao/P07.md), [P08](bao-cao/P08.md), [P09](bao-cao/P09.md). Thông tin ký/phát hành còn theo [PHAT_HANH_PUBLIC](PHAT_HANH_PUBLIC.md).
