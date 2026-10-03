# PhotoAxis — website GitHub Pages

Website12trang Việt/Anh được triển khai từ cùng repo public [nguyenduchai/PhotoAxis](https://github.com/nguyenduchai/PhotoAxis), giấy phép GPL-3.0-only theo quyết định chủ dự án03/10/2026. URL: https://nguyenduchai.github.io/PhotoAxis/ . Đây là website giới thiệu bản phát triển; bộ cài public vẫn chưa được ký/notarize và tải còn disabled.

```sh
python3 scripts/build-website.py
python3 scripts/check-website.py
python3 -m http.server 8650 --bind 127.0.0.1 --directory website
```

`.github/workflows/pages.yml` build/check trên Ubuntu rồi stage bằng `scripts/package-website.py`, upload/deploy GitHub Pages. Push main có thay đổi website/scripts/workflow/LICENSE hoặc workflow_dispatch sẽ chạy; quyền Pages/OIDC chỉ ở job deploy, actions ghim SHA. Payload chỉ HTML/CSS/PNG/release-status/robots/.nojekyll/deployment-manifest; không chứa Sources/Tests/hồ sơ/DMG. Manifest ghi commit nguồn và SHA256 từng file.

Sau deploy, job `verify` chạy `scripts/check-pages-live.py` trên runner GitHub: kiểm 27 file HTTP 200, HTTPS ẩn danh với xác minh TLS bình thường, SHA256 và đúng commit. `.nojekyll` là control file của artifact, không phải URL HTTP. Receipt `pages-https-proof` được lưu 30 ngày. Runner giúp kiểm bytes gốc độc lập với AdGuard đang chèn script vào HTML nhận tại máy phát triển.

Không backend/account/CDN/analytics/cookie/tracker. Canonical/hreflang dùng đúng project path. Robots noindex trong lúc bản ứng dụng đang phát triển. Privacy nêu rõ GitHub Pages và liên kết chính sách GitHub; hỗ trợ qua GitHub Issues. `publicReady=false` áp dụng bộ cài, không ngăn giới thiệu mã nguồn. Generator không bật download nếu chưa nghiệm thu.

`asset-provenance.json` ghi hash/source/scope. Perspective/recovery VI/EN là lịch sử build1 UUIDD54. OCR VI/EN và đo VI là ảnh native build3 UUID4EFA, dùng fixture tự tạo; ảnh không thay nghiệm thu public hoặc dữ liệu thực. Ảnh Adobe nội bộ không được phân phối. Xem báo cáo `docs/bao-cao/GITHUB_PAGES_DMG_2026-10-03.md`.
