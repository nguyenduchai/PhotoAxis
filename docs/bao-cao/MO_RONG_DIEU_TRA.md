# Investigation 2 — kết quả OCR, video và đo có hiệu chuẩn

Ngày 02/10/2026. **I11–I14 DONE trong phạm vi triển khai và kiểm chứng local** theo yêu cầu thực hiện ngay cả ba nhóm mở rộng. PhotoAxis **1.0.0 (3)** có đủ OCR tiếng Việt có người xác nhận, tiếp nhận video/trích khung hình có truy vết, đo đoạn/diện tích có thước chuẩn và xuất phân tích JSON. Baseline **1.0-draft.3** và I01–I10 vẫn giữ; chưa xác nhận đủ điều kiện public hoặc chứng nhận công cụ giám định. `releaseReady=false`, `publicReady=false`.

## Kết quả từng nhóm

| Nhóm | Đã triển khai | Kết quả kiểm chứng local |
| --- | --- | --- |
| OCR — I11 | Vision native/offline; kiểm runtime có `vi-*`, không fallback tiếng Anh; ROI trên nguồn chuẩn hóa lúc tiếp nhận; raw text/line box/confidence/engine/revision/OS/hash; cửa sổ ảnh/ROI, bản máy read-only, các xác nhận do người dùng riêng và nhật ký bền vững | Fixture tiếng Việt1600×640: ROI40,20,1520,450 nhận đúng3dòng, loại dòng thứ4 ngoài ROI. Giữ nguyên text máy sau sửa/xác nhận và mở lại hồ sơ. VI và EN đều mở/đọc/xác nhận thật trên app cuối. Host trả ngôn ngữ `vi-VT`; không hardcode `vi-VN`. Test thiếu tiếng Việt từ chối rõ, lỗi ghi receipt giữ bản xác nhận trước. |
| Video — I12 | Giữ file MOV/MP4/M4V nguyên byte, intake/hash/track/duration/transform; AVAssetReader đếm sample hình giải mã theo thứ tự PTS; chọn ordinal từ0; PNG frame SDR8bit riêng; PTS hữu tỷ gốc, video hash, trackID và offset/căn cứ | MOV H.264 VFR có4khung0/100/350/900ms, transform90°. Khung2 cho ảnh xanh dương200×320, PTS350/1000; offset5giây giữ PTS gốc và ghi thời gian tương đối5,350s. Native cuối trích thêm khung1 xanh lá, PTS100/1000, offset0. Byte/hash video nhận bằng fixture; test out-of-range/offset thiếu căn cứ/nguồn bị sửa từ chối, ENOSPC rollback. |
| Đo — I13 | Thước chuẩn hai điểm, độ dài thật/đơn vị mm–cm–m và căn cứ hình học; hash nguồn/model/canvas; đoạn2điểm hoặc đa giác đơn3–64đỉnh; overlay thước xanh/điểm đỏ và kết quả; model đổi làm calibration cũ stale | Fixture tự tạo:100px=10cm; đoạn có Δx300/Δy400 cho50cm; hình vuông100×100px cho100cm². Native mở kết quả và đo lại50cm trên bản cuối. Test đa giác lõm/đảo chiều, tự cắt/thoái hóa/nonfinite/scale sai, stale và lỗi receipt; không sửa pixel. Đây là kiểm toán học trên fixture, chưa chứng nhận độ chính xác đo vật chứng thực. |
| Bảo toàn/xuất — I14 | Case schema2 chứa typed analysis và state digest; schema1 không có analysis giữ canonical digest cũ; JSON phân tích có nguồn/model hiện tại, OCR/raw/confirmation, video/frame/PTS/offset, calibration/measure và input ledger hash; atomic output riêng, Started/Completed/hash | Tải lại schema1/schema2 và phát hiện tamper PASS. Native xuất `native-analysis-vi.json`; script Python độc lập đối chiếu20event/hash/state,3ảnh/archive,1video,2OCR,2frame,3phép đo và receipt output. JSON xuất trước xác nhận English sau đó, là snapshot tại thời điểm xuất. |

## Mã nguồn và định dạng

- [InvestigationAnalysis Core](../../Sources/PhotoAxisCore/Investigation/InvestigationAnalysis.swift): model, validation, rational media time, calibration/measurement và digest.
- [Engine native](../../Sources/PhotoAxisApp/Investigation/InvestigationAnalysisEngine.swift): Vision và AVFoundation chạy worker; [Store](../../Sources/PhotoAxisApp/Investigation/InvestigationAnalysisStore.swift): intake/atomic manifest/receipt/export; [Review](../../Sources/PhotoAxisApp/Investigation/InvestigationReviewController.swift): controls/ROI/overlay/raw và confirmed text.
- [Controller](../../Sources/PhotoAxisApp/Investigation/InvestigationController.swift):7action mới, trạng thái disabled theo context, spinner/“Đang xử lý hồ sơ…” khi bận. Tọa độ hiển thị dạng `(x, y)`, không lộ tên type/module.
- [Đặc tả I11–I14](../DAC_TA_MO_RONG_DIEU_TRA.md), [định dạng case](../DINH_DANG_PAXCASE.md), [hướng dẫn](../HUONG_DAN_DIEU_TRA.md), [quyết định kỹ thuật](../QUYET_DINH_KY_THUAT.md).

`.paxis` thông thường vẫn schema1; working gắn hồ sơ vẫn schema2. `.paxcase` schema1 cũ đọc/verify được; lần đầu thêm analysis chuyển case schema2. App Investigation1 từ chối case schema2. File video nguồn có suffix container trong `originals/<sha256>.<mov|mp4|m4v>` để AVFoundation nhận đúng; nguồn ảnh giữ cách đặt tên theo hash hiện có. Nhập/xuất phân tích không tự tạo layer chữ hoặc sửa pixel nguồn.

## Kiểm thử và native QA

Full suite cuối **144 PASS / 0 FAIL / 4 SKIP** trong148test:48Core PASS,96App PASS/4App SKIP. Thêm14test cho nhóm mới (5Core,9App), cộng17test Investigation1 thành31test điều tra. Bốn SKIP là3benchmark Release opt-in và1test input context không kích hoạt được Telex thực. Không dùng Unicode paste/marked-text thay nghiệm thu bộ gõ. [Summary](bang-chung/INVESTIGATION2/test-summary.json), [log](bang-chung/INVESTIGATION2/debug-test.log).

Release **BUILD SUCCEEDED**, `codesign --verify --deep --strict` ad-hoc PASS; arm64/minOS14.0. Localization **404khóa VI/EN /333tham chiếu** PASS; project deterministic PASS;16policytests phân phối/public PASS. Host thực: M1Pro32GiB/Retina2×/macOS27.0.1/Xcode27.0Build27A266a. Chưa có kết quả runtime macOS14/màn hình1×/M1-16GB.

```sh
bash scripts/check.sh
bash scripts/build.sh Release
python3 scripts/generate-project.py --check
python3 scripts/check-localization.py
python3 -m unittest discover -s Tests/ReleaseTooling -v
python3 scripts/check-website.py
python3 scripts/release-audit.py preflight
python3 scripts/distribution.py local
```

`preflight` trả exit2/BLOCKED_EXTERNAL đúng dự kiến; không upload/publish. Lệnh `collect-evidence.py INVESTIGATION2` thu test log/Release log và hai QA bundle cuối. [Script đối chiếu native](bang-chung/INVESTIGATION2/inspect-native-analysis.py) chạy read-only với case/JSON ở `$BUILD_ROOT/QA/Investigation2`, xuất [kết quả độc lập](bang-chung/INVESTIGATION2/native-analysis-inspection.json).

Native dùng case synthetic `Ho-so-mo-rong.paxcase`, không ảnh cá nhân/vật chứng. Tạo/nhập/OCR đầu trên sourceacfc121; sau sửa spinner/tọa độ, đóng và mở lại bằng source0169bf5, thực hiện OCR/xác nhận/đo/trích frame/xuất JSON VI, rồi mở cùng case EN/đọc/xác nhận/verify. Cả hai app cuối có UUID/Core đúng Release; executable QA ký lại có hash riêng. [Native QA](bang-chung/INVESTIGATION2/native-qa.txt) và ảnh/AX: [OCR VI](bang-chung/INVESTIGATION2/ocr-final-vi.png), [đo VI](bang-chung/INVESTIGATION2/measurement-final-vi.png), [frame VI](bang-chung/INVESTIGATION2/frame-final-vi.png), [case VI](bang-chung/INVESTIGATION2/case-final-vi.png), [case EN](bang-chung/INVESTIGATION2/case-final-en.png), [OCR EN](bang-chung/INVESTIGATION2/ocr-final-en.png). EN không được nhận là đã lặp mọi action video/đo riêng.

Script độc lập xác nhận20event/sequence/payload hash, state digest cuối;3original ảnh và working/intake archive,1video nguyên byte;2OCR với số confirmation `[1,2]`;2frame và3phép đo50cm/100cm²/50cm. Output JSON SHA-256 `9c4903cc84ea012d22d3f5d8da707e9db4314b5bbbda3d51a6e6345b92950c68`, receipt sequence18; English confirmation/verify đến sau nên không có trong snapshot JSON đã xuất. Nhật ký Started không tự được xem là Completed.

## Provenance và bộ cài local

| Trường | Bản cuối đã kiểm |
| --- | --- |
| Source commit | `0169bf52cd0d3793c0027a82888833c8a58f4f78`; source sạch khi build/đóng gói |
| Version/build |1.0.0 /3 |
| Source fingerprint SHA-256 |`317d062da381ee744dc7b680a3b5dd40d23525e9536da30c9cb63c67fa0e9d02` |
| Release UUID |`4EFA7887-E96F-3149-B6F5-68BE3475F219` |
| Executable SHA-256 |`faa4d7264d3d92dc12ff6774ae5a5561b06ea09abb12acfbe8f5c1f1d620128c` |
| Core framework SHA-256 |`8ae55ed513e8d34db8ee6dae8ed59e1128a0bd1cd5abfe9ced58ea1963373058` |
| DMG local |`PhotoAxis-1.0.0-arm64-LOCAL-UNSIGNED.dmg`, ngoài Git tại `$BUILD_ROOT/P13-local-_pehi_4j` |
| DMG SHA-256 |`797ee11a3267d0fde0a90d003a97379fca3ffa442ece1a6d0c75f50aea8a84bc` |
| App tree trong DMG |`24cac782391b5fa84eefe0417b4739fc3201eeb2f618be619fe9049335714ca4` |

Đã mount read-only, copy và đối chiếu cây app/symlink, kiểm codesign, version/build/architecture/minOS và detach thành công. [Build manifest](bang-chung/INVESTIGATION2/build-manifest.json), [distribution manifest](bang-chung/INVESTIGATION2/distribution-manifest.json), [packaging log](bang-chung/INVESTIGATION2/packaging.log), [checksum DMG](bang-chung/INVESTIGATION2/SHA256SUMS.txt). `LOCAL-UNSIGNED` là chưa Developer ID/notarized; app bên trong có chữ ký ad-hoc cho phát triển. Các bản DMG build1 và Investigation1 build2 là lịch sử.

## Lỗi đã xử lý và giới hạn còn lại

- Sửa đường fixture để resource bundle thực chứa P17; giữ suffix video vì nguồn không extension làm AVURLAsset không mở được. Temp cleanup dùng unlink đúng phạm vi để ENOENT không che lỗi gốc. Test màu frame dùng thứ tự/dominance phù hợp H.264 lossy, không hứa pixel video nguyên trạng sau decode/chuyển sRGB.
- Lượt package trung gian bị `hdiutil detach` exit16; mount do tác vụ tạo đã detach được, đóng gói lại bản cuối PASS. Log macOS27 còn deprecation của hdiutil, không tự coi đó là notarization/cài sạch PASS.
- Suite còn1priority-inversion warning tại ExportTests HDR prepare và console Metal `MDB_MAP_FULL`. Chưa khoanh nguyên nhân/đo input-to-present hoặc stress dài hạn, không gọi đã giải quyết từ test xanh.
- OCR lần lạnh đầu từng chờ khởi tạo model Apple khoảng79,6giây trong lượt trước; các lượt ấm synthetic cuối nhanh hơn. Số này là quan sát, không phải benchmark qualification cuối. Spinner/worker đã bổ sung; cần đo cold/warm/thiết bị hỗ trợ và khả dụng ngôn ngữ theo OS.
- Video mới kiểm fixture H.264 VFR/rotation; chưa nghiệm thu bộ codec/clip dài/4K/HDR/dữ liệu camera thực. Chỉ một track,512MiB/file,20video,100.000sample/120giây decode; không có player/timeline/audio/cắt ghép.
- Đo theo một tỷ lệ đồng nhất và căn cứ do người dùng khai báo. Chưa tự kiểm mặt phẳng/camera/lens/perspective/depth hoặc tính độ không đảm bảo. Tọa độ nhập bằng ô số; chưa có công cụ click chọn điểm trên canvas. Không dùng kết quả synthetic để kết luận kích thước vật chứng thực.
-100OCR/100calibration/500measure/100frame cùng quota100ảnh,10GiB original,32MiB manifest/10.000event chưa được đo đầy tải. JSON phân tích chứa chữ/nguồn đầy đủ, **không phải bản chia sẻ đã che**; PDF hiện có chưa tự chèn bảng OCR/đo, chưa batchOCR/full-text search.
- Chữ ký số hồ sơ, timestamp tin cậy độc lập, mã hóa và kho tập trung vẫn ngoài phạm vi. SHA-256/nhật ký tự chứa kiểm toàn vẹn, không xác thực người/giờ/nguồn hay thay quy trình bảo quản.

[Tổng tiến độ và điều kiện public](TONG_TIEN_DO_VA_PUBLIC_2026-10-02.md), [known issues](../KNOWN_ISSUES.md), [readiness](../READINESS_PUBLIC.json). Các giới hạn usability nêu trên không bị mô tả là chức năng đã có; các điều kiện chất lượng/phát hành còn thiếu giữ gate chưa đạt.
