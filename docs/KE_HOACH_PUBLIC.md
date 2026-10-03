# Cập nhật03/10/2026

Chủ dự án chọn cùng repo public [nguyenduchai/PhotoAxis](https://github.com/nguyenduchai/PhotoAxis) cho mã nguồn và website, GPL-3.0-only. GitHub Pages [website](https://nguyenduchai.github.io/PhotoAxis/), hỗ trợ GitHub Issues; target/visibility/hosting/license đã chốt. Source bắt đầu snapshot loại ảnh Adobe nội bộ; lịch sử cũ giữ local. Website preview triển khai độc lập gates bộ cài. Hậu kiểm thực ở [báo cáo](bao-cao/GITHUB_PAGES_DMG_2026-10-03.md); `publicReady=false` vẫn là trạng thái bộ cài. Kế hoạch02/10 dưới đây là lịch sử; các mục target/source/license chưa chốt được cập nhật bởi quyết định mới này.

# PhotoAxis 1.0.0 — kế hoạch public thực tế, 02/10/2026

**BLOCKED_EXTERNAL**, chưa push/publish/deploy. Kênh website/GitHub Releases đã duyệt; target, chủ thể, quyền ký và nghiệm thu chưa đủ. [JSON kế hoạch](KE_HOACH_PUBLIC.json) dùng null cho dữ liệu chưa biết, không có URL/repo giả. Distribution config chỉ chứa tên profile Keychain, không chứa secret; giá trị chính thức chờ chủ dự án.

| Đầu vào/đầu ra | Trạng thái thật |
| --- | --- |
| App/version/build/schema | PhotoAxis 1.0.0 (1)/schema1/native; P12 code a9737df, P13 resources 8b8c15d |
| Source repo/visibility/remote/push | Chưa xác nhận; checkout main không remote; không suy từ Git author |
| Distribution repo/tag/target commit | Chưa repo/quyền/visibility; tag dự kiến v1.0.0, chưa tạo/push |
| R02/native/IME/macOS14/máy/màn hình | BLOCKED_EXTERNAL theo RC manifest và ma trận |
| Publisher/support/license/giá/namespace/Team/Developer ID/notary profile | Chưa đủ, đã hỏi; không có Developer ID Application |
| Artifact public | PhotoAxis-1.0.0-arm64.dmg chưa có; chưa checksum/notary ID |
| Artifact local | LOCAL-UNSIGNED DMG đã mount/hash/sign ad-hoc; không được đưa lên link tải public |
| Website | website/12 trang Việt/Anh/static; localhost8642 preview kiểm 1280/390 CSS, links/metadata/provenance PASS |
| Website public/hosting/deploy | Chưa chốt URL/host/quyền; không deploy |
| Ảnh | P07 native/P11 hosted native/P12 actual Export có hash; current P11/P12 Perspective workspace/ảnh binary cuối còn chờ |
| Release notes/docs/privacy/notices/runbook | Có nội dung local Việt/Anh, phân biệt Save/Export/Recovery/GPS/font/history; chờ terms/support/host chính thức |
| Hậu kiểm ẩn danh/install/offline | Chưa có public URL/artifact; không kiểm bằng local thay public |

Khi đủ đầu vào, điền kế hoạch với source/distribution/site commits và checksum cuối, chạy preflight P15. Cập nhật nội dung production và đúng URL asset versioned. Repo phân phối riêng phải có target commit thật của repo đó; source private không được push sang repo phân phối hoặc tự đổi public. Site ZIP chỉ gồm website HTML/CSS/ảnh của PhotoAxis, không kèm Sources/Tests/.paxis/DMG unsigned/reference Adobe.

[Runbook](RUNBOOK_PHAT_HANH.md) có thứ tự draft/assets/verify/publish/deploy/postcheck và cách ngừng giới thiệu bản lỗi/phát hành patch mới. Với 1.0.0 không có bản rollback trước. R12 phần kế hoạch đã chuẩn bị, gate vận hành còn quyền/host/backup thật.
