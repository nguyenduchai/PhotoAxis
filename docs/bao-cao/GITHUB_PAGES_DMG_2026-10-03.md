# PhotoAxis — mã nguồn GPLv3, GitHub Pages và DMG, 03/10/2026

**Đã hoàn thành yêu cầu công khai mã nguồn và website trong cùng một repo, đồng thời xuất DMG local build 3.** Website: https://nguyenduchai.github.io/PhotoAxis/ ; mã nguồn: https://github.com/nguyenduchai/PhotoAxis . Chủ dự án xác nhận mô hình này và chọn GNU GPL phiên bản 3 (GPL-3.0-only).

## Website và mã nguồn

Website có 12 trang Việt/Anh: giới thiệu, hướng dẫn, riêng tư, hỗ trợ, thành phần và ghi chú phiên bản. Đã thêm liên kết source/Issues/LICENSE, hướng dẫn tự build, nội dung OCR/video/đo có hiệu chuẩn và ảnh native OCR VI/EN, đo VI của build 3. Ảnh Perspective/Recovery build 1 vẫn được ghi rõ là lịch sử. App và bộ cài hiện vẫn là bản phát triển; nút tải bộ cài public còn tắt, robots noindex.

Repo public chứa ứng dụng, tests, fixture tự tạo, tài liệu và website. LICENSE đầy đủ ở root, thông báo quyền/bảo đảm ở README và trong DMG. Snapshot public bắt đầu ở 08a68a2; lịch sử triển khai cũ giữ local trên `local/implementation-history`. Bytes ảnh tham chiếu Adobe chỉ được dùng nội bộ đã bị loại khỏi toàn bộ lịch sử public; giữ URL/hash để tra cứu. Pattern scan 1.276 blob lịch sử chưa phát hiện mẫu credential hoặc tracked secret; đây là kiểm tra có phạm vi, không phải chứng nhận security toàn diện.

GitHub Pages chạy bằng Actions, HTTPS enforced, các action ghim SHA. Payload chỉ chứa HTML/CSS/ảnh và metadata phân phối website, không chứa source, tests, hồ sơ hoặc DMG. `deployment-manifest.json` ghi commit và hash từng file. `.nojekyll` là control file trong artifact; GitHub không phục vụ URL dotfile này. Các link/ảnh dùng đúng project path `/PhotoAxis/`. GitHub Issues là kênh báo lỗi; Privacy có chính sách GitHub. Website không có tracker, form tài khoản, backend hoặc CDN font.

## DMG cuối

| Mục | Kết quả |
| --- | --- |
| App | PhotoAxis 1.0.0 (3), arm64; deployment target macOS 14 |
| Source đóng gói | 43a5b9334704f0d957946202ebd8f45b2c553c2f, `sourceDirty=false` |
| Binary UUID | 741E1DF7-BF33-3A1D-9697-90ADCE9DF40E |
| Binary SHA256 | 934e24a886f7b5adfe39319ed5f4dec20833819410f80709995ec339b06ca99d |
| Core SHA256 | 8ae55ed513e8d34db8ee6dae8ed59e1128a0bd1cd5abfe9ced58ea1963373058 |
| DMG | PhotoAxis-1.0.0-arm64-LOCAL-UNSIGNED.dmg, 2.318.267 byte |
| DMG SHA256 | 447f1b3649d29518edbe4c1eae53acd7300ef8a4dd03bca8c1558bb93b6e94db |
| Payload | PhotoAxis.app; Applications symlink → /Applications; LICENSE.txt; SOURCE.txt |
| Kiểm tra | Mount read-only, đối chiếu byte license/source notice, app tree, codesign, detach và hash bản giao: PASS |
| Bản giao | `$BUILD_ROOT/Deliverables/2026-10-03-build3-final/` |
| Chữ ký/phát hành | Ad-hoc local; chưa Developer ID/notarization/cài sạch Gatekeeper; không upload DMG unsigned như bản phát hành public |

[Receipt](bang-chung/GITHUB-PAGES-20261003/delivery-receipt.json), [distribution manifest](bang-chung/GITHUB-PAGES-20261003/distribution-manifest.json), [build manifest](bang-chung/GITHUB-PAGES-20261003/build-manifest.json). Source tương ứng có thể lấy tại [commit 43a5b93](https://github.com/nguyenduchai/PhotoAxis/tree/43a5b9334704f0d957946202ebd8f45b2c553c2f). Các DMG trước sửa CI được giữ riêng làm lịch sử.

## Kiểm chứng và giới hạn

| Kiểm tra | Kết quả và phạm vi |
| --- | --- |
| Website local | 12 trang VI/EN, links/anchor/metadata/alt, download disabled và asset provenance: PASS |
| Website live | 27 file HTTP 200, HTTPS ẩn danh với xác minh certificate bình thường, SHA256 và commit manifest: PASS ở các deployment đã ghi bằng chứng |
| Browser live | Desktop 1280×900 CSS; mobile 390px VI/EN, chuyển ngôn ngữ, ảnh và nút tải: PASS, không tràn ngang |
| Policy phát hành | 16 PASS; không bỏ gates của installer signed/notarized |
| Inventory/ngôn ngữ | Xcode project khớp source; 404 khóa VI/EN, 333 tham chiếu: PASS |
| Local full suite sau sửa native | 144 PASS / 1 FAIL / 3 SKIP, 148 total. FAIL là Telex dùng NSEvent mô phỏng trả ASCII chưa chuyển; không bỏ test hoặc đổi thành PASS |
| Local HDR/layout sau chỉnh điều kiện test | 2 PASS / 0 FAIL / 0 SKIP |
| GitHub CI | 143 PASS / 0 FAIL / 5 SKIP; Debug/test và Release PASS trên arm64, macOS 15.7.9, Xcode 16.4 |

[CI cuối 37087879643](https://github.com/nguyenduchai/PhotoAxis/actions/runs/37087879643) chạy ở source 78adb1b. Native Sources/Config/project ở commit này khớp source của DMG 43a5b93; chỉ tests khác. Năm ca SKIP gồm ba benchmark opt-in, Telex context không khả dụng và màn hình runner không đủ 1440×900. Không suy nghiệm thu IME/layout lớn/benchmark từ CI xanh. [CI summary](bang-chung/GITHUB-PAGES-20261003/ci-final-summary.json), [local full suite](bang-chung/GITHUB-PAGES-20261003/native-local-test-summary.json), [HDR/layout](bang-chung/GITHUB-PAGES-20261003/native-hdr-layout-summary.json), [browser](bang-chung/GITHUB-PAGES-20261003/browser-checks.json), [HTTPS](bang-chung/GITHUB-PAGES-20261003/https-second-deployment.json).

CI thực đã tìm ra hai điểm tương thích SDK: UndoManager callback cần kiểm MainActor đồng bộ ở SDK cũ; một metric HDR chỉ có trong SDK macOS 26. Đã sửa ở b267165/0ea4029. macOS 15 còn trả headroom metadata khác cho fixture được encode bằng Image I/O mới; tests giữ kiểm nguồn/gain map/byte/pixel/SDR/metadata và chỉ chứng nhận metric mới trên OS có căn cứ. Khi window server giới hạn kích thước, test bố cục ghi SKIP rõ ràng. Local HDR/layout kiểm đủ vẫn PASS. Chỉ sửa một callback native; không thay thuật toán hình học, OCR/video/đo hay persistence.

## Tiến độ phát hành ứng dụng

Website và source đã public; gói xuất DMG local đã hoàn thành. **Ứng dụng chưa đủ điều kiện phát hành bộ cài stable public:** `releaseReady=false`, installer `publicReady=false`; A01–A43 vẫn 19 PASS/24 ca chưa đóng. Còn IME/native tổng thể/macOS 14/non-Retina/M1-16GB/hiệu năng/Metal-QoS/quota và qualification dữ liệu điều tra thực, Developer ID/notarization/cài sạch. Target repo/visibility/GitHub Pages/license/Issues đã chốt; không còn tính là đầu vào thiếu. Publisher pháp lý/namespace/Team vẫn chưa được suy từ GitHub author.

Latest website commit được kiểm bằng manifest HTTPS và receipt hậu kiểm; artifact/source/CI có các commit riêng ở trên. Bàn giao này không tạo tag v1.0.0 hoặc bật tải bộ cài chưa nghiệm thu. Khi source/docs commit cuối được push, deployment manifest được cập nhật từ đúng HEAD và đối chiếu lại; receipt cuối lưu cùng thư mục DMG để tránh hash tự tham chiếu của chính commit báo cáo.
