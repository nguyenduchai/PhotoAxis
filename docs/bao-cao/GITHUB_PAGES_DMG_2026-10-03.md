# PhotoAxis — GitHub Pages, mã nguồn GPLv3 và DMG,03/10/2026

Chủ dự án yêu cầu website GitHub Pages và xuất DMG; sau đó xác nhận cùng một repo public chứa mã nguồn và website, giấy phép GPLv3. Target [nguyenduchai/PhotoAxis](https://github.com/nguyenduchai/PhotoAxis), website https://nguyenduchai.github.io/PhotoAxis/ . Repo public, GPLv3 và Pages Actions/HTTPS đã hoạt động. Deployment ban đầu source08a68a2 PASS; đối chiếu27file công khai qua HTTPS ẩn danh/hashPASS. [Workflow](https://github.com/nguyenduchai/PhotoAxis/actions/runs/37086761276), [HTTPS](bang-chung/GITHUB-PAGES-20261003/https-first-deployment.json).

## Phạm vi

- Website12trang Việt/Anh, metadata/canonical/hreflang đúng project path, link source/Issues/LICENSE/build guide, Privacy GitHub, gallery OCR VI/EN và đo VI build3. Perspective/recovery build1 được ghi đúng lịch sử. Không tracker/backend/account/CDN.
- GPL-3.0-only, LICENSE đầy đủ và thông báo quyền/bảo đảm trong README. Source, tests, fixture tự tạo, tài liệu và website cùng một repo. Bắt đầu snapshot public để loại bytes ảnh Adobe không được phép phân phối; lịch sử cũ còn local. Hash/commit cũ trong báo cáo là provenance lịch sử.
- DMG local1.0.0(3)arm64 từ binary đã QA: UUID4EFA7887-E96F-3149-B6F5-68BE3475F219, binarySHAfaa4d7264d3d92dc12ff6774ae5a5561b06ea09abb12acfbe8f5c1f1d620128c. Chưa thay mã native. Sau chọnGPLv3, packaging thêm LICENSE.txt/SOURCE.txt và đối chiếu byte trong DMG; manifest/checksum cuối sẽ bổ sung sau build ở source sạch.

## Kiểm tra trước deployment

-12trang, links/anchor/metadata/alt/download disabled/provenance/checksum tài nguyên PASS.
-16release policytests PASS, không nới gate signed/public release.
-Patternscan1276blob trong lịch sử:0mẫu credential/0trackedsecret/0blob>40MB. Không phải chứng nhận security toàn diện. [Audit](bang-chung/GITHUB-PAGES-20261003/source-publication-audit.json).
-GitHub Pages Actions/HTTPS enforced PASS.27file HTTP200/hash và commit deployment đúng; `.nojekyll` là controlfile artifact, GitHub không phục vụ URL dotfile, không tính HTTPresource. Desktop1280×900CSS và mobile390px Việt/Anh không tràn ngang, chuyển ngôn ngữ/nút tải disabled đúng. [Browserchecks](bang-chung/GITHUB-PAGES-20261003/browser-checks.json).
-CI Xcode16.4 lần đầu fail callbackUndo actor, lần hai fail phép đo test chỉ có SDK26; đã sửa ởb267165/0ea4029 và đang chạy lại. Fullsuite localb267165 **144PASS/1FAIL/3SKIP**, caTelexNSEvent mô phỏng không chuyển chữ; HDR riêngPASS. ReleaseUUID741E1DF7-BF33-3A1D-9697-90ADCE9DF40E/binarySHA934e24a886f7b5adfe39319ed5f4dec20833819410f80709995ec339b06ca99d, codesignPASS. Bộ cài trước sửaCI được giữ làm lịch sử; đang export lại từ checkout sạch cuối.

## Trạng thái phát hành ứng dụng

Website/mã nguồn có thể public độc lập bộ cài. `releaseReady=false`, `website/release-status.json.publicReady=false`, nút tải disabled; không upload DMGlocalunsigned như bản public. Còn DeveloperID/notarization/cài sạchGatekeeper, A01–A43(19PASS/24open), máy đích/IME/nativeperformance/qualification điều tra. GitHub repo/Pages/license/Issues đã chốt; chưa tự suy publisher pháp lý/namespace/Team/giá.
