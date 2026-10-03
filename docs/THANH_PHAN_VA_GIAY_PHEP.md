# Cập nhật công khai03/10/2026

Chủ dự án xác nhận mã nguồn mở trong cùng repository ứng dụng/website và chọn **GNU GPL phiên bản 3 (GPL-3.0-only)**. LICENSE ở root là toàn văn; thông báo quyền/bảo đảm ở README. Điều này thay thế ghi chú “chưa chọn license/source visibility” ở các mốc lịch sử dưới đây. Framework Apple và zlib theo điều khoản của chủ sở hữu tương ứng; không đưa file font hệ thống vào source/app.

GitHub Pages actions configure-pages v5, upload-pages-artifact v4, deploy-pages v4 và checkout v6 được ghim SHA trong `.github/workflows/pages.yml`; đây là công cụ CI ngoài app. Ảnh Adobe chỉ tham chiếu bằng URL/hash; bản local và lịch sử Git chứa ảnh không được push vào repo public.

# Thành phần và giấy phép — P00–P14

- Chưa thêm dependency mã nguồn bên thứ ba vào ứng dụng. Xcode không khai báo/tải package ngoài.
- AppKit/Foundation, MetalKit/Core Image/Core Graphics/Image I/O/Core Text là framework hệ thống Apple; sử dụng theo điều khoản SDK của Apple. Swift Testing và XCTest phục vụ phát triển, không nhúng test bundle vào app Release.
- Python 3 và shell chỉ phục vụ script build/project; dùng standard library, không cài pip/gem/npm.
- GitHub Actions checkout v4 được ghim commit `11d5960a326750d5838078e36cf38b85af677262`; action có [MIT License](https://github.com/actions/checkout/blob/11d5960a326750d5838078e36cf38b85af677262/LICENSE). Action chỉ chạy trong CI, không phân phối cùng app.
- Fixture là hình học/màu/chữ tự tạo bằng script của repo; font hệ thống chỉ dùng render, không sao chép file font. Không có ảnh cá nhân/ảnh stock/logo ngoài.
- Chưa gán license công khai cho mã nguồn PhotoAxis. Chủ dự án sẽ xác nhận điều kiện phân phối và danh tính ở P14; không mặc định source là public hoặc MIT.

Mọi dependency/tài nguyên bổ sung cần ghi mục đích, phiên bản/commit, nguồn và license trước khi đưa vào bản phát hành.

## Tài nguyên giao diện P01

- Icon công cụ: vector NSBezierPath tự vẽ trong ToolKind; controls phụ dùng SF Symbols qua NSImage API của macOS, không sao chép font/tập ảnh hệ thống.
- [Bộ tham chiếu nội bộ](tham-chieu/P01/README.md) chứa ảnh workspace từ trang Adobe và mockup PhotoAxis tự tạo trước đó; nguồn/hash được cố định. Ảnh Adobe chỉ là tài liệu đối chiếu có ghi nguồn, không phải tài nguyên sản phẩm hoặc ảnh được cấp phép phân phối lại. Không được đưa vào app/DMG/trang tải. Kiểm tra resource membership P01 xác nhận app chỉ có tài nguyên localization và executable/framework cần thiết.
- Nhận diện P01 là tên PhotoAxis dạng chữ; chưa có icon phát hành. Hoàn thiện icon/giấy phép hồ sơ public ở P13/P14.

## Chữ và hình P06

Core Text/Core Graphics là framework hệ thống; font family/style lấy từ font đã cài, chỉ lưu tên và tham số trong model. Không nhúng hoặc sao chép file font. Hình chữ nhật/elip/đường và chữ Việt trong bằng chứng là dữ liệu tự tạo của bộ kiểm thử.

## P09–P14

zlib là thư viện hệ thống macOS, dùng inflate DEFLATE và CRC cho ZIP/PNG ICC; không copy/bundle binary zlib hay dependency package. Xem [zlib license](https://zlib.net/zlib_license.html). ICNS tự sinh bằng Core Graphics/iconutil; nguồn vector/path ở scripts/generate-app-icon.swift, không phải tài nguyên Adobe. Website dùng CSS/system fonts và ảnh PhotoAxis-native/fixtures tự tạo có provenance; ảnh reference Adobe không được copy sang website. Không mặc định cấp phép public source/giá/điều kiện thương mại; chờ chủ dự án chốt.


## Investigation 1–2

Vision, AVFoundation và CoreMedia là framework hệ thống Apple dùng OCR tiếng Việt và đọc/giải mã video native. Không thêm package/dịch vụ OCR hoặc model tải riêng do PhotoAxis phân phối. Khả dụng ngôn ngữ Vision kiểm runtime; thời gian khởi tạo model hệ thống chưa qualified toànOS. Fixtures OCR/video là chữ/màu/timing tự tạo, font hệ thống chỉ render; không nhúng font/ảnh ngoài. Quy trình PDF dùng CoreGraphics/CoreText hiện có, không nhúng file nguồn vào bản đã rà soát. Điều kiện phát hành/license nguồn vẫn chờ chủ dự án xác nhận.
