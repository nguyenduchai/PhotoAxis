# PhotoAxis1.0.0(6) — Paint1 và xem trực tiếp

- Brush B: nét theo màu tiền cảnh, cỡ/hardness/opacity, nội suy, layer paint editable; mouseUp một Undo, Escape hủy nét.
- Clone Stamp S: Option-click hoặc click→Option-Return lấy composite cố định; aligned/unaligned, nguồn sRGB/SHA256 nhúng trong schema4.
- Scan không cần nút Preview; Crop/Perspective tự hiện inset; Image Size/Canvas Size tự preview khi nhập/đổi neo. Apply chốt Undo; Cancel giữ original.
- Save/Open/Export/recovery và case audit tiếp nhận paint; derived case giữ mẫu chưa Save, không ghi đè intake.
- Development build local, chưa stable public/DeveloperID/notary; không pressure/tablet/eraser/healing/texture/mask. [Hướng dẫn](HUONG_DAN_BRUSH_CLONE.md), [phạm vi](DAC_TA_PAINT.md).

# PhotoAxis 1.0.0 (5) — workspace tích hợp, bản phát triển

Đã hợp nhất chức năng điều tra vào workspace chỉnh sửa: Nguồn/Phân tích/Đầu ra trong bảng bên phải, mở hồ sơ qua Tệp → Mở, ảnh thành tab và danh mục đồng bộ hồ sơ. Bỏ menu và cửa sổ Điều tra riêng; tham số inline, chọn ROI/điểm trực tiếp trên canvas, đối chiếu/OCR review trong cùng cửa sổ. Draft đổi tab/model hủy an toàn; bảo vệ tab orphan chưa lưu. Full168ca164PASS/1knownTelexFAIL/3benchmarkSKIP,9ca mớiPASS; Release/native VI/EN scoped và16policyPASS. [Hướng dẫn](HUONG_DAN_DIEU_TRA.md), [báo cáo/bằng chứng](bao-cao/HOP_NHAT_WORKSPACE_2026-10-03.md).

Investigation tools now share the native editing workspace. Sources, Analysis and Output live in the sidebar; cases open through File → Open and working images use document tabs. Separate Investigation menus, windows and modal parameter forms are removed. Pick image regions and points on the canvas; compare and review OCR in the same window. Draft cancellation protects changed contexts and unsaved orphan tabs. Local168tests:164PASS/1knownTelexFAIL/3benchmarkSKIP, including9newpassingtests. Native cold OCR and supported-target/full acceptance remain unqualified; no signed/notarized stable installer yet.

---

# PhotoAxis1.0.0(4) — Scan1, bản phát triển

Scan1 thêm nhận diện trang/căn góc chữ, làm sạch nền/đen trắng thích nghi, nắn bow hai trục thủ công, chuẩn hóa A4/Letter/pixel/PPI và batch1–50ảnh xuất PNG/project/PDF/manifest. Giữ nguồn và typed layers, một Apply một Undo; file có Scan dùngschema3, reader mới vẫn đọc1/2. Fullsuite155PASS/1knownTelexFAIL/3SKIP;11Scan testsPASS, Release/ad-hoc PASS. [Hướng dẫn](HUONG_DAN_SCAN.md), [bằng chứng và giới hạn](bao-cao/SCAN_2026-10-03.md).

Scan1 adds page/text-angle detection, paper cleanup and adaptive black/white, manual two-axis bow correction, standard page sizes/PPI and serial batch PNG/editable-project/PDF/hash-manifest output for up to50images. Source bytes remain embedded; Scan projects require schema3, with backward reading of1/2. Real camera/book/fullquota and supported-target qualification are pending. Local155PASS/1knownTelexFAIL/3SKIP;11newScan testsPASS. No signed/notarized stable installer yet.

---

# PhotoAxis 1.0.0 (3) — release notes chuẩn bị, chưa public

Nghiệm thu local03/10/2026 bổ sung New presets/5tab isolation/History–saved markers nativeVI/EN trên build3:19/43caPASS. Phím Telex VI nhập hai dòng/commit/cancel có bằng chứng,EN source/VNI còn thiếu. Benchmark riêng3PASS nhưngcorner chỉ31% mẫu worker≤33,333ms; chưa chứng nhận nativeFPS/máy đích. Không sửa mã sản phẩm hoặc đổi trạng thái public. [Báo cáo](bao-cao/P12-native2.md).

Local verification on 3October2026 closes New presets, five-tab isolation and History/saved markers in native VI/EN:19of43acceptance cases pass. Real VI Telex key conversion/multiline/commit/cancel is recorded;EN input context/VNI remain unverified. A separate benchmark passes3tests, but only31% of perspective corner worker samples are within33.333ms; nativeFPS/target hardware remain unqualified. Product code and public status are unchanged.

## Investigation 1 — phần mở rộng local

Gói phục vụ điều tra đã có hồ sơ `.paxcase`, file tiếp nhận đúng byte/SHA-256/metadata, thông tin bàn giao và nhật ký xử lý bền vững độc lập Undo; danh mục ảnh, chú thích typed và ô phóng to, so sánh nguồn/kết quả đồng bộ zoom/pan/swipe. Working archive điều tra dùng `.paxis` schema2; tài liệu thường giữ schema1. Export PNG/PDF A4 1/2/4ảnh/trang yêu cầu rà soát vùng che theo model hiện tại; file chia sẻ flatten, không nhúng nguồn. Có xuất danh mục/full log JSON.

## Investigation 2 — OCR/video/đo, build3 lịch sử

Build3 thêm OCR tiếng Việt native Vision trên ROI nguồn tiếp nhận; giữ bản máy read-only và các xác nhận người dùng riêng, engine/OS/hash/log. Giữ videoMOV/MP4/M4V nguyên byte và trích frame từ sample hình thực với ordinal/PTS hữu tỷ/track/transform/hash; offset thời gian tương đối cần căn cứ và không thayPTSgốc. Đo đoạn/diện tích cần thước chuẩn/đơn vị/căn cứ hình học, lưu điểm/modelhash và từ chối calibration cũ khi model đổi. JSON phân tích snapshot riêng có receipt/hash chứa dữ liệu chưa che. Case1 đọc tương thích, thêm analysis chuyển case2; `.paxis` thường1/working2 giữ nguyên.

144PASS/0FAIL/4SKIP, Release/ad-hoc/localDMG3PASS; native VI/EN có phạm vi ghi rõ. OCR theo khả dụng `vi-*` runtime; không fallback tiếng Anh hoặc dựng chữ. Video một track/512MiB/120sdecode, PNG SDR8bit dẫn xuất, chưa timeline/player. Đo một tỷ lệ đồng nhất, không tự kiểm camera/mặt phẳng/lens/depth/độ không đảm bảo. Chưa batchOCR/search/clickpoints/PDFautoOCR–measuretable, chữ ký số/timestamp độc lập/mã hóa/kho tập trung. SHA-256 không xác thực nguồn gốc/thời gian hoặc thay hồ sơ bảo quản. [Hướng dẫn](HUONG_DAN_DIEU_TRA.md), [bằng chứng/giới hạn](bao-cao/MO_RONG_DIEU_TRA.md), [public](bao-cao/TONG_TIEN_DO_VA_PUBLIC_2026-10-02.md).

Investigation1 provides exact original bytes, intake/raw metadata, durable audit history, case catalogs, typed annotations/magnifiers, synchronized comparison and reviewed flattened PNG/A4 PDF sharing. Investigation2 adds runtime-available native Vietnamese OCR with separate raw text and explicit human confirmations, preserved original video and decoded frame ordinal/exact rational PTS with justified relative offsets, and calibrated distance/area tied to source/model hashes. Analysis JSON is an unredacted snapshot with audit/output receipts. Case1 remains readable; adding analysis upgrades to case2. Ordinary project1/bound working project2 remain unchanged.

Local build3 has144passing tests/0failures/4skips, scoped native VI/EN verification and an ad-hoc local DMG. No public notarized installer or supported-target/full-quota qualification yet. Vietnamese OCR availability varies by OS; no English substitution. Video output is derived SDR8-bit, one video track with documented limits. Measurements require independently suitable geometry/scale; no automatic camera/lens/depth or uncertainty assessment. Signatures/trusted timestamps/encryption/central storage and timeline/batchOCR/canvas point picking/PDF analysis tables remain outside current implementation. Hashes do not authenticate origin/time or replace custody procedures.

## Tiếng Việt

PhotoAxis là trình chỉnh ảnh native trên macOS, có workspace Tiếng Việt/English, layer ảnh/chữ/hình và Perspective Crop toàn tài liệu giữ editable. Luồng đã triển khai gồm nhập PNG/JPEG/HEIC, nhiều tab, Move/Transform/History, Crop/kích thước/xoay/lật, chữ/hình/màu/Eyedropper và điều chỉnh ảnh theo layer.

Save `.paxis` schema1 giữ nguồn nguyên byte và layer/ma trận/clip/thông số trong một ZIP tự chứa. Export PNG/JPEG tạo ảnh phẳng sRGB8-bit với alpha hoặc matte, quality/kích thước/PPI và loại metadata GPS nguồn; export không xóa dirty marker. Recovery lưu thay đổi đã chốt; phiên chưa Apply không được hứa phục hồi. History không lưu qua lần mở lại; font không nhúng và thiếu font có thể thay hình thức chữ.

Mục tiêu Apple Silicon/macOS14+, tối đa8000px/cạnh,40MP canvas/mỗi nguồn,50layer,120MP nguồn duy nhất/tài liệu,5tab,100 bước/128MiB History. App offline, không tài khoản/cloud/telemetry/AI/subscription/updater. Không PSD/RAW/Mask/Intel/App Store.

**Trạng thái chuẩn bị:** chưa có bộ cài public. Còn nghiệm thu Telex/VNI thực, native shortcut/bố cục/tác vụ nền tổng thể, macOS14/non-Retina/máy chuẩn, warning Metal/QoS, ký/notarize/cài sạch/offline. Publisher/support/license/giá/targetrepo/website chưa chốt. Bản ghi chú này phải được đối chiếu với manifest và phạm vi nghiệm thu cuối trước publish; không xóa các hạn chế khi chưa xử lý hoặc được chấp thuận rõ.

## English

PhotoAxis is a native macOS image editor with Vietnamese/English UI, typed image/text/shape layers, and document-wide editable Perspective Crop. Implemented workflows include PNG/JPEG/HEIC import, tabs, Move/Transform/History, crop/size/rotate/flip, text/shapes/color/Eyedropper and per-image adjustments.

Save `.paxis` schema1 preserves original embedded sources and layer/matrix/clip/parameters in one self-contained ZIP. Export creates 8-bit sRGB PNG/JPEG with alpha or matte, quality/size/PPI and fresh metadata without original GPS. Export leaves the project dirty marker intact. Recovery stores committed edits, not uncommitted tool drafts. History is session-only; fonts are not embedded and fallback can alter text appearance.

Target Apple Silicon/macOS14+,8000px/edge,40MP canvas/source,50layers,120MP unique sources/document,5tabs,100steps/128MiB History. Offline, without accounts/cloud/telemetry/AI/subscription/automatic updater. No PSD/RAW/Mask/Intel/App Store.

**Preparation status:** no public installer. Real Telex/VNI, remaining native shortcut/layout/background-task checks, macOS14/non-Retina/reference hardware, Metal/QoS evaluation and signed/notarized clean/offline installation remain pending. Publisher/support/license/pricing/repository/website targets are unconfirmed. Review against the final manifest and accepted scope before publication; do not erase unresolved limitations.
