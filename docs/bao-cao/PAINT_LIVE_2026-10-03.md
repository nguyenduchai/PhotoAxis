# Brush, Clone Stamp và xem trước trực tiếp — 03/10/2026

**Đã triển khai Paint1 trong PhotoAxis1.0.0(6), DONE local.** Yêu cầu mới ngày03/10 cho phép Brush/Clone ngoài baseline1.0-draft.3. Công cụ nằm trong workspace native chung với chức năng điều tra, không mở menu/form riêng. [Đặc tả](../DAC_TA_PAINT.md), [hướng dẫn](../HUONG_DAN_BRUSH_CLONE.md).

| Nội dung | Kết quả |
| --- | --- |
| Brush | Màu tiền cảnh RGBA, cỡ1–1000px, độ cứng/độ đậm0–100%, nội suy dấu chấm/nét; opacity một lần trên hợp nét mỗi stroke |
| Clone Stamp | Option-click hoặc click + Option-Return lấy mẫu composite đã chốt; PNG sRGB đóng băng, Aligned/không Aligned, source offset theo pixel tài liệu |
| Live và History | Pointer xem ngay, thả một Undo, Escape/focus/tab hủy draft; `[ ]` đổi cỡ, slider/ô số cập nhật trực tiếp |
| Scan | Auto coalescing85ms, kết quả mới hợp lệ mới cho Apply; không còn nút Xem trước |
| Crop/Perspective | Inset512px coalescing45ms tự cập nhật, vẫn kéo góc/vùng trên ảnh gốc; full preview tùy chọn |
| Image Size/Canvas Size | Tự preview khi đổi số/neo; tham số sai khóa Apply; Cancel phục hồi model và viewport, Apply một Undo |
| Lưu/phục hồi/xuất | Typed paint schema4; reader1–4, reject downgrade/future; Save/recovery bỏ draft, PNG/JPEG dùng composite |
| Hồ sơ điều tra | Intake nguyên byte, mẫu clone `derived/SHA256` read-only; atomic model/audit rollback, mở kiểm hash/decode; review/chuẩn đo cũ stale khi model đổi |

Nét nằm trên paint layer riêng; ẩn/khóa/opacity/duplicate/Move/Transform/Crop/Perspective dùng phép layer hiện có. Paint đã biến đổi hoặc lệch canvas tạo layer mới khi vẽ tiếp. Quota4096điểm/65536mẫu mỗi nét,512nét/32768điểm mỗi layer,262144điểm/120MP ROI mỗi document; clone dùng ngân sách nguồn50ID/120MP. Các lỗi quota hoặc commit giữ trạng thái cuối hợp lệ.

Full suite mã cuối trên macOS27.0.1/Xcode27/M1Pro32GiB/Retina2×: **184total,180PASS/1FAIL/3SKIP**. FAIL duy nhất là test nguồn nhập Telex đã biết `ContentEditingTests.testInstalledVietnameseInputContext`: ASCII `tieengs vieetj ` chưa đổi thành tiếng Việt. Ba benchmark opt-in không chạy; không suy ra60FPS hoặc đạt full quota. **16ca mới PASS**:5Core +11App gồm oracle pixel/mask/nội suy/opacity/orientation; nguồn mẫu composite/frozen; quota/lock/reference/schema/history; draft/Save/Export/recovery; audit/rollback/tamper; native Option-click/Aligned/Escape; controlsVIEN/narrow overflow; autoScan/latest-generation; Image/Canvas Size; Crop/Perspective auto.

Release ad-hoc arm64/minOS14 **BUILD SUCCEEDED**. Inventory,486khóaVIEN/400references,12trangwebsite và16release-policytests PASS. `MDB_MAP_FULL`/QoS vẫn có trong log; gate hiệu năng không đóng.

Native QA trên bản Release cuối đổi bundleID cho VI/EN, cùng UUID/Core với Release. Fixture tổng hợp1200×900: VI lưu5nét/3nguồn; EN mở lại rồi vẽ và đóng dấu thành7nét/4nguồn, Save As/PNG. Audit ZIP/schema/sourceSHA256 và byte nguồn gốc PASS;4pixel tâm brush đen đục, tâm clone xanh lá/xanh dương đúng mẫu đóng băng,3pixel ngoài vùng nét đúng nguồn gốc. Native Undo một nét về Saved, Redo Unsaved, Undo về Saved; khởi động lại mở schema4 Saved. Đường lấy mẫu native bằng click+Option-Return; Option-click có kiểm NSEvent hosted, không nhận đã thao tác chuột Option-click ngoài test đó.

Native VI Scan3° tự ra1246×962, Image Size nhập600 tự height450, Perspective kéo quad ra956×699 và hiện inset khi full-preview tắt; Cancel giữ1200×900/Saved. Crop thường và Canvas Size auto được kiểm hosted, không nhận đã chạy chuột riêng. Kiểm native phát hiện dải đen ngoài ROI nét khi Scan xoay; sửa vùng mask/nền trong suốt và oracle inverse-map alpha độc lập tại−3°/+3°/+14°/Perspective, kiểm lại binary cuối thấy lỗi hết.

[Bằng chứng](bang-chung/PAINT-LIVE-20261003/build-manifest.json), [audit độc lập](bang-chung/PAINT-LIVE-20261003/native-audit.json), [test summary](bang-chung/PAINT-LIVE-20261003/test-summary.json). Native QA dùng dữ liệu tổng hợp; không là nghiệm thu đầy đủ A01–A43 hoặc dữ liệu điều tra thực.

DMG build6 từ checkout sạch `7312eb1e7101c63bcc1d554d6c8416baa2f68bdd` đã mount/tree/codesign/GPL/source notice/detach/copyhash PASS; UUID/Core/executable khớp Release đã kiểm. SHA256 **`5caf36bf04225f134a176163d3b2ea4304f4b75a3ac95a932170ab4ddbe1b4a2`**,2526701byte. Bản giao `$BUILD_ROOT/Deliverables/2026-10-03-build6-paint-live` ngoàiGit. [Distribution manifest](bang-chung/PAINT-LIVE-20261003/distribution-manifest.json), [receipt](bang-chung/PAINT-LIVE-20261003/delivery-receipt.json), [release manifest](../RELEASE_MANIFEST.md).

WebsiteVI/EN build6 đã triển khai; hậu kiểm27fileHTTPS/hash/commit PASS trên runnerGitHub, không bị AdGuard local chèn script. [Receipt Pages](bang-chung/PAINT-LIVE-20261003/pages-https.json). CI GitHub source sạch`7312eb1e7101c63bcc1d554d6c8416baa2f68bdd` trên macOS15.7.9/Xcode16.4: **184total,179PASS/0FAIL/5SKIP**, Debug/test/ReleasePASS;16ca mớiPASS. SKIP gồm3benchmark, nguồn nhậpTelex và fixtureworkspace lớn, không đóng các gate đó. [Run](https://github.com/nguyenduchai/PhotoAxis/actions/runs/37123347410), [summary](bang-chung/PAINT-LIVE-20261003/ci-summary.json), [log kiểm thử/build](bang-chung/PAINT-LIVE-20261003/ci-test-build.log). Source/config/tests/scripts fingerprint không đổi giữa mã sản phẩm`bf0f303` đã test, checkoutCI/DMG`7312eb1` và tài liệu/receipts sau đó.

**Source/website public đã được duyệt, stable installer chưa đủ điều kiện.** `releaseReady=false`;19/43 là build3 lịch sử. Còn Telex/VNI/full native/macOS14/non-Retina/M1-16GB/input-to-present/full quota/Metal-QoS/OCR-cold/ảnh-video-đo thực và Developer ID/notary/cài sạch. Chưa pressure/tablet/custom brush/eraser/healing/masks; timeline/batchOCR/search/PDFbảngOCR/nắn sách3D vẫn ngoài phạm vi hiện có. [Readiness](../READINESS_PUBLIC.json), [known issues](../KNOWN_ISSUES.md).
