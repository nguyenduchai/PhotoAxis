# Phân tích theo ảnh đang mở và con trỏ công cụ — 04/10/2026

**DONE triển khai local — PhotoAxis 1.0.0 (8).** Đã xử lý hai yêu cầu: Phân tích/Đầu ra dùng đúng tab đang mở; con trỏ AppKit đổi theo công cụ, tay nắm và thao tác. Bản cuối đã kiểm native Việt/Anh trong phạm vi dưới đây, audit file xuất độc lập, chạy local/CI và đóng gói DMG local. `releaseReady=false`; không nhận nghiệm thu public đầy đủ.

## Cách hoạt động

Trước đây các lệnh phân tích phụ thuộc ảnh được chọn trong danh mục hồ sơ, gây thêm bước cho ảnh đang chỉnh. Bản 8 resolve session của tab đang hoạt động hoặc `OpenImageAnalysis` khớp documentID/hash model **và hash model của item snapshot**. Chọn một hồ sơ khác trong Nguồn không thay đích phân tích của tab thường. Đổi tab/model hủy parameter continuation và ROI; capture bất đồng bộ kiểm lại đích trước khi hiện kết quả.

- Tab thường dựng committed canvas thành PNG, gồm các chỉnh sửa đã chốt và layer nhìn thấy, rồi dùng OCR/đo/che/chia sẻ trên snapshot. Không sửa model, fileURL, History, nguồn hoặc gắn reference vào tab. Chú thích sửa ngay tài liệu đang mở, một Undo. Đối chiếu tab thường dùng checkpoint lúc mở tab và canvas hiện tại; không nhận đây là file gốc tiếp nhận.
- **Lưu phân tích thành hồ sơ…** giữ snapshot/kết quả/log trong `.paxcase` mới. Caption/intake/event `openImageSnapshot` ghi rõ nguồn dựng, hash model và nguồn nhúng; không coi PNG này là file gốc nhận bàn giao. Tab `.paxis` vẫn chỉnh sửa được; hồ sơ giữ snapshot riêng và không tự cập nhật theo các chỉnh sửa tiếp theo. Model đổi cần OCR/hiệu chuẩn/rà soát vùng che lại. Sửa tab case của snapshot đã lưu cũng không được dùng kết quả đó thay canvas gốc.
- Save kiểm hash nguồn/archive/manifest trước và sau copy trong worker, rồi ghi event hồ sơ; rollback đích mới khi lỗi. Native đã phát hiện guard export cấm luôn đích `.paxcase` mới. Đã sửa để kiểm **thư mục cha**, vẫn cấm đích tồn tại hoặc lồng bên trong hồ sơ được bảo vệ. Có hồi quy và native Save/Open xác nhận sửa thành công.
- Hồ sơ tiếp nhận chính thức vẫn nhập đúng byte file gốc qua Nguồn; OCR tab bản làm việc của hồ sơ giữ nguồn intake, đo/che theo model hiện tại. Phiên canvas tạm chưa có crash recovery, giải phóng khi đóng tab/lifetime cuối. Checkpoint dùng COW assets giữ đến đóng tab; quota/performance máy đích còn qualification.

Con trỏ dùng `NSCursor` cached: badge vector sở hữu cho Crop/phối cảnh/Move/Brush/Clone/Eyedropper/hình; chữ I-beam; Zoom±; Hand mở/nắm. Cạnh/góc Crop/Transform có resize đúng hướng; tay nắm xoay có cursor xoay. Option đổi Zoom/Clone sampling; Space tạm pan và khôi phục công cụ. Cọ giữ vòng đường kính, ẩn trong Space pan. Thả Space giữa pan, nhả chuột, đổi tab hoặc mất focus xóa trạng thái kéo. Cursor rect clip trong bounds hữu hạn; overlay render cập nhật invalidate rect. ROI dùng crosshair, comparison dùng hand.

## Kết quả kiểm

| Kiểm tra | Kết quả và phạm vi |
| --- | --- |
| Local full suite cuối | **201 tổng: 197 PASS / 1 FAIL Telex đã biết / 3 SKIP benchmark** |
| 10 ca mới | **PASS** snapshot đúng pixel/giữ model-History-assets-checkpoint; active tab/case/closed tab; stale calibration/redactions; Save/Open ledger; sửa snapshot không thay canvas; cleanup/fault/corrupt raster; annotation một Undo/cancel; async tab switch; cursor images/cache/hotspots/NSCursor.current; crop/hand/Space/offscreen rect |
| GitHub CI | **201 tổng: 196 PASS / 0 FAIL / 5 SKIP**, cả 10 ca mới PASS; Debug/test/Release PASS, macOS15.7.9/Xcode16.4 |
| CI SKIP | 3 benchmark opt-in, input context tiếng Việt thực và fixture workspace lớn; không đóng các gate này |
| Release local | BUILD SUCCEEDED, ad-hoc arm64/minOS14; hai app QA giữ đúng UUID/Core của Release |
| Inventory/ngôn ngữ | PASS; **536 khóa VI/EN, 435 references** |
| Policy/website | **16 policy tests / 12 trang VI/EN PASS**; HTTPS/hash/commit của **27 file** PASS trên GitHub runner |

`ContentEditingTests.testInstalledVietnameseInputContext` vẫn FAIL local: chuỗi Telex chưa chuyển thành tiếng Việt. Không nhận full suite local PASS. `MDB_MAP_FULL`/Metal-QoS cũ tiếp tục cần đánh giá. CI: [run37142191499](https://github.com/nguyenduchai/PhotoAxis/actions/runs/37142191499), [summary](bang-chung/OPEN-IMAGE-CURSOR-20261004/ci-summary.json).

## Native bản cuối và audit độc lập

- Việt: mở ảnh tổng hợp 1600×640, tương phản20 → Apply → Save/Open `.paxis`; Analysis hiện tên tab và nguồn canvas. Tham số native hiệu chuẩn100mm với các điểm(100,550)/(500,550), đo(100,550)/(300,550) → **50mm**. Rà soát vùng40,193,791,187 → PNG; lưu thành hồ sơ mới và **Kiểm tra toàn vẹn PASS**.
- English: mở `.paxis` thường → Analysis; mở lại `.paxcase` và giữ tab thường → Analysis **không lấy chuẩn đo của case đang chọn**. Mở working image → Analysis dùng đúng case, chuẩn đo còn hiệu lực; comparison mở trong canvas chung. Kéo góc Crop1600×640 →1516×560 rồi Cancel, chuyển Brush/Clone/Hand và gửi thao tác pan. Không đổi model hồ sơ.
- **10 event** kiểm hash chain và state digest độc lập; source/archive/model/receipt hashes khớp. `.paxis` giữ nguyên SHA256/byte count suốt phân tích/lưu hồ sơ, không có investigation reference, giữ tương phản20; nguồn nhúng bằng đúng byte fixture. Event snapshot khớp ID/hash model của `.paxis` và hash PNG dẫn xuất.
- PNG1600×640: **147.917 pixel đen đục** trong vùng; **876.083 pixel ngoài vùng** bằng snapshot canvas. Không GPS/comment/description riêng tư; phép đo tính lại từ tọa độ =50mm. Không nhận fixture tổng hợp là phép đo ảnh thực.
- **OCR native cuối: CHƯA KIỂM CHỨNG hoàn tất.** Yêu cầu cold giữ busy qua nhiều lần quan sát, ứng dụng còn phản hồi; đã ghi trạng thái rồi quit QA/mở lại tài liệu đã lưu để kiểm phần còn lại. Case bàn giao thử cuối không có OCR event. Trước sửa guard Save đã quan sát pointer ROI nhận đúng3dòng và xác nhận riêng; ảnh bằng chứng có tiền tố `pre-save-guard-`, không nhận đó là lượt chạy lại binary cuối. Cold/warm và máy đích tiếp tục mở.
- CUA phủ con trỏ điều khiển riêng lên screenshot; không dùng ảnh chụp để nhận bitmap cursor OS đã đạt. Hosted tests kiểm **NSCursor.current**, image/hotspot/cache thật; native Crop drag/tool selection kiểm dispatch riêng. Option/Space/tất cả tay nắm/xoay/offscreen ở đây thuộc phạm vi hosted.

[Native audit](bang-chung/OPEN-IMAGE-CURSOR-20261004/native-audit.json), [script](bang-chung/OPEN-IMAGE-CURSOR-20261004/native-audit.py), [fixture ZIP tổng hợp](bang-chung/OPEN-IMAGE-CURSOR-20261004/native-fixture.zip). ZIP được kiểm CRC và replay audit từ thư mục độc lập PASS; cần Python/Pillow, chạy script với hai tham số: thư mục giải nén fixture và thư mục bằng chứng mới. [Giao diện phân tích Việt](bang-chung/OPEN-IMAGE-CURSOR-20261004/analysis-current-vi.png), [lưu thành hồ sơ](bang-chung/OPEN-IMAGE-CURSOR-20261004/analysis-saved-vi.png), [English theo tab](bang-chung/OPEN-IMAGE-CURSOR-20261004/ordinary-with-selected-case-en.png), [cursor gallery từ bitmap NSCursor](bang-chung/OPEN-IMAGE-CURSOR-20261004/gallery.png).

## Bản giao và phạm vi public

Mã sản phẩm đã kiểm `831ef1a58b86b6b9a64344a7bf2d8e05d53c1fd8`; fingerprint `98ef8ee6522f2a0f29c81945a310536a2ed50c59e7950ab4ab218f2728897bc0`. Release UUID **43209510-3056-3E94-AF2B-25E5AAB23E0D**. Đóng gói từ checkout sạch `a4e44de60bbb12898e8ac1fd6b817252d07f0754`; binary/Core/UUID khớp bản đã kiểm. DMG **2,611,249 byte**, SHA256 `a2525c73714e63629e075afd08dcc979b09b66a5d5fdd380be62f6875aaa2080`; mount/tree/codesign/GPL/SOURCE/detach/copy hash PASS. Bản giao ngoài Git: `$BUILD_ROOT/Deliverables/2026-10-04-build8-open-image-cursor/PhotoAxis-1.0.0-arm64-LOCAL-UNSIGNED.dmg`. [Receipt](bang-chung/OPEN-IMAGE-CURSOR-20261004/delivery-receipt.json), [build manifest](bang-chung/OPEN-IMAGE-CURSOR-20261004/build-manifest.json), [distribution](bang-chung/OPEN-IMAGE-CURSOR-20261004/distribution-manifest.json), [Pages proof](bang-chung/OPEN-IMAGE-CURSOR-20261004/pages-https.json).

Định dạng project/case không đổi. Các phạm vi Paint/Scan/Investigation trước giữ nguyên. Source/website GPLv3 đã public; DMG này là bản local ad-hoc, chưa Developer ID/notarize/cài sạch, không public stable/tag. **19/43 nghiệm thu baseline thuộc build3 lịch sử**, không nhận full build8. IME/VNI/native tổng thể/macOS14/non-Retina/M1-16GB/hiệu năng/fullquota/Metal-QoS/OCRcold/dữ liệu thực/DeveloperID/notary/cài sạch vẫn mở. [Hướng dẫn thao tác](../HUONG_DAN_DIEU_TRA.md), [ADR-026](../QUYET_DINH_KY_THUAT.md), [known issues](../KNOWN_ISSUES.md), [readiness](../READINESS_PUBLIC.json).
