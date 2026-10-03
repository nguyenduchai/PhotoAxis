# PhotoAxis — Bổ sung phát hành công khai

## Phạm vi đã yêu cầu

Người dùng đã chốt đặc tả 1.0-draft.3 và chọn **tải trực tiếp từ website/GitHub Releases**. Phần này bổ sung công việc phân phối vốn nằm ngoài bản đặc tả ứng dụng. Không bổ sung App Store, thanh toán, đăng nhập người dùng, telemetry hoặc cập nhật tự động.

Mục tiêu: người dùng truy cập trang tải, tải **PhotoAxis 1.0.0 cho Apple Silicon/macOS 14+**, cài bằng DMG, mở theo luồng Gatekeeper thông thường và sử dụng offline. Thành công được đo ở file public tải thực tế, không chỉ bản `.app` trên máy phát triển.

## Đầu vào cần có trước phát hành

| Thông tin | Trạng thái khi soạn | Khi cần |
| --- | --- | --- |
| Tên và kênh | PhotoAxis; website/GitHub Releases — ĐÃ CHỐT | Đã đủ |
| Tài khoản/chủ thể phát hành, bundle identifier và UTI chính thức | CHƯA CÓ | Ghi sớm ở P00; chốt trước P13 |
| Apple Developer Team và Developer ID Application khả dụng | CHƯA KIỂM TRA | P13 |
| Cấu hình notarization trong Keychain hoặc cơ chế secret tương đương | CHƯA KIỂM TRA | P13 |
| GitHub owner/repository, quyền push/release | CHƯA CÓ | Ghi sớm ở P00; chốt trước P15 |
| Source public hay private; repo phân phối nếu tách riêng | CHƯA CHỐT | P14/P15; không tự đổi visibility |
| Tên miền/trang tải | CHƯA CÓ | P14; có thể dùng GitHub Pages nếu phù hợp repo và người dùng chọn |
| Tên nhà phát hành, địa chỉ hỗ trợ, điều kiện sử dụng/phân phối | CHƯA CÓ | P14; không tự gán license mã nguồn hoặc cam kết thương mại |
| Máy/OS dùng thử cài sạch, gồm macOS 14 và bản macOS đang hỗ trợ mới hơn | CHƯA KIỂM TRA | P12/P13; ghi rõ phần chưa có thiết bị |

Các giá trị trên là đầu vào chưa biết, không phải mặc định đã được người dùng duyệt. Đọc cấu hình/tài khoản đang có trước khi hỏi; chỉ hỏi phần còn thiếu khi nó thực sự cản công việc. Không yêu cầu dán private key, mật khẩu, token hoặc chứng thư vào chat. Dùng Keychain/secret store và thao tác đăng nhập của người dùng.

## Ghi nhận đầu vào tại P00 — 20/09/2026

- Repository hiện tại: nhánh `main`, chưa có remote; ban đầu chưa có commit. Git author đã cấu hình và chỉ dùng cho commit local; **không** suy ra đó là danh tính/chủ thể phát hành.
- Development bundle ID: `local.photoaxis.development`; framework `local.photoaxis.core`; tests `local.photoaxis.tests`. Các giá trị này là tạm, phải thay bằng namespace đã được chủ dự án xác nhận trước P13. Chưa đăng ký UTI/đuôi `.paxis` vì chưa có reader; UTI chính thức sẽ được chốt trước phát hành.
- Team rỗng, ký ad-hoc (`CODE_SIGN_IDENTITY=-`), Hardened Runtime chưa bật cho build local; version/build `1.0.0` / `1`, deployment target 14.0, arm64. Không cần chứng thư public để build/test P00. P13 bắt buộc Developer ID và bật Hardened Runtime; không đưa cấu hình local này ra public.
- Xcode 27.0 (27A266a), macOS SDK 27.0; host macOS 27.0 (26A428), M1 Pro/32 GiB. Không coi build trên SDK mới là bằng chứng app đã chạy trên macOS 14.
- Chưa xác định Apple Developer Team/Developer ID/notarization, GitHub owner/repo/quyền release, source visibility, domain/trang tải, nhà phát hành/địa chỉ hỗ trợ/điều kiện phân phối. Chưa cần hỏi các giá trị này để hoàn thành build local; giữ các mục R01/R04–R11 chưa đạt.
- Chưa có máy/tài khoản cài sạch macOS 14 được kiểm tra. P12/P13 cần bố trí; không đổi yêu cầu hệ điều hành chỉ vì máy phát triển mới hơn.
- CI chỉ build/test, không public trên push/tag. Không tạo remote, không push, không đổi visibility trong P00.

## Đầu ra phân phối dự kiến

- `PhotoAxis-1.0.0-arm64.dmg`: app đã ký/notarize, kéo vào Applications, không cần script cài đặt có quyền quản trị tùy tiện.
- `SHA256SUMS.txt`: checksum sau mọi thao tác ký/staple/đóng gói. Bất kỳ thay đổi byte nào sau đó phải tạo checksum và kiểm tra lại.
- Release notes Việt/Anh: tính năng thực có, yêu cầu máy, cách cài, hạn chế còn được chấp nhận, thay đổi định dạng nếu có.
- Hướng dẫn tiếng Việt; trang riêng tư phản ánh đúng app offline và hành vi website/hosting; thông tin hỗ trợ và thông báo thư viện/tài nguyên bên thứ ba.
- Release manifest nội bộ: version/build, schema version, app source commit, website commit, thời điểm/toolchain, bundle ID/Team, đường dẫn artifact, SHA-256, submission ID/trạng thái notarization, kết quả kiểm tra. Không chứa secret.

Mã nguồn và symbol/debug artifact không phải mặc định là file public. Nếu source private, cân nhắc repo public chỉ chứa tài liệu/asset phát hành theo lựa chọn của chủ dự án; không đưa source private vào tarball/zip public. Tag của repo nguồn và tag của repo phân phối có thể khác commit, nhưng manifest phải ghi rõ quan hệ, không giả vờ chúng giống nhau.

## Luồng phát hành

1. P12 tạo Release Candidate có A01–A43 đạt hoặc có thay đổi phạm vi được người dùng quyết định rõ. Gắn mọi báo cáo với commit/build; không mang kết quả của bản cũ sang bản đã thay đổi mà không đánh giá ảnh hưởng.
2. P13 tạo Release archive arm64/macOS 14+; ký bằng Developer ID Application, Hardened Runtime, timestamp và entitlement cần thiết. Kiểm tra lại cấu hình Debug/Release.
3. Notarize bằng `notarytool`, kiểm tra Accepted và log. Một luồng dự kiến: notarize ZIP chứa app đã ký → staple/validate app → tạo/ký DMG chứa app đó → notarize/staple/validate DMG. Đối chiếu tài liệu Apple/toolchain thực tế trước khi viết script; không coi gửi upload thành công là notarization đã đạt.
4. Kiểm tra bản trong DMG trên tài khoản/máy thử sạch; tải qua trình duyệt giữ quarantine, không xóa quarantine hoặc tắt Gatekeeper để tạo kết quả PASS. Xác minh offline bằng bản đã staple và thử luồng mở/lưu/xuất.
5. P14 hoàn thiện trang tải và tài liệu; ảnh chụp phải từ app native thật, cả Việt/Anh. Chỉ mô tả chức năng đã nghiệm thu. Chuẩn bị nội dung và preview trước khi public.
6. P15 tạo draft release với tag/commit được xác minh, gắn đầy đủ asset/checksum, đối chiếu manifest, rồi publish và đưa link tải đúng lên website. Khi cấu hình release bất biến được sử dụng, chuẩn bị đủ asset trước khi publish.
7. Tải lại bằng truy cập ẩn danh từ URL public, so SHA-256, kiểm tra ký/staple, cài/mở/luồng tài liệu và kiểm tra website. Website/latest/tag/manifest phải cùng mô tả artifact đã phát hành.

Các yêu cầu ký/notarize và công cụ tham chiếu được kiểm tra ngày 20/09/2026 theo [Apple — Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [Apple — Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow) và [Apple — Packaging Mac software](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution). Luồng draft → asset → publish theo [GitHub — Managing releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository). Đọc lại nguồn chính thức khi chạy P13/P15 vì yêu cầu có thể thay đổi.

## Checklist public — chưa đạt public

| Đạt | Ca | Yêu cầu | Chặng |
| --- | --- | --- | --- |
| [ ] | R01 | Danh tính phát hành, bundle ID, Team, quyền repo và kênh đã xác định; không còn placeholder trong artifact | P13–P15 |
| [ ] | R02 | A01–A43 có kết quả trên build ứng viên; không còn lỗi mất dữ liệu, sai ảnh xuất, sai phối cảnh, crash tái hiện | P12 |
| [ ] | R03 | Source commit/build/toolchain được ghi; binary arm64 và minimum macOS đúng; artifact/checksum có thể truy vết | P13 |
| [ ] | R04 | Chữ ký Developer ID, Hardened Runtime, timestamp và entitlement của app/nested code hợp lệ | P13 |
| [ ] | R05 | Notarization Accepted; app/DMG được staple/validate theo cách đóng gói đã chọn; lưu log đã loại secret | P13 |
| [ ] | R06 | DMG mở/copy đúng, tên/version/icon đúng; app trong DMG khớp artifact đã kiểm tra | P13 |
| [ ] | R07 | Cài từ bản tải qua trình duyệt giữ quarantine; Gatekeeper chấp nhận theo luồng thông thường trên môi trường sạch | P13, P15 |
| [ ] | R08 | Mở dùng offline, lưu/mở `.paxis`, crop/text/PNG/JPEG hoạt động trên bản đã đóng gói; nâng cấp thay app không làm mất dự án | P13 |
| [ ] | R09 | Trang tải, hướng dẫn, riêng tư/hỗ trợ, ghi nhận thành phần, ảnh thật và release notes đầy đủ, đúng tính năng | P14 |
| [ ] | R10 | Website HTTPS và link tải public truy cập ẩn danh được, không 404/redirect sai, không còn nút tải giả | P15 |
| [ ] | R11 | Tải asset public về, SHA-256 khớp; tag/source manifest/version/latest nhất quán; log hậu kiểm đủ | P15 |
| [ ] | R12 | Có cách ngừng giới thiệu bản lỗi, khôi phục link bản tốt khi có, và phát hành bản vá với version/tag mới | P14–P16 |

## Khi phát hiện lỗi sau phát hành

Không ghi đè một binary mới dưới version/tag cũ. Xác định ảnh hưởng, ngừng giới thiệu bản lỗi theo cách phù hợp quyền và trạng thái release, đưa link bản tốt đã biết nếu có. Với bản đầu tiên chưa có bản tốt trước đó, tạm ngưng nút tải và thông báo tình trạng thay vì trỏ vào một bản không tồn tại. Sửa, kiểm tra phần ảnh hưởng và luồng lưu/mở/xuất, tăng patch version, ký/notarize lại rồi phát hành. Không xóa dự án hoặc recovery của người dùng để xử lý lỗi nâng cấp.

Không tạo lịch giám sát tự động chỉ vì có kế hoạch bảo trì; chỉ thiết lập khi người dùng yêu cầu riêng.

## Trạng thái thực 02/10/2026 — P12–P15

P12 đã có43-row matrix,112nativePASS/3benchmarkPASS và full quota; R02 chưa đạt vì native cuối/IME/thiết bị/warnings còn thiếu. P13 có icon riêng, Release/archive/localDMG được kiểm; chưa DeveloperID/notary/cài sạch. P14 có12 trang static Việt/Anh/desktop-mobile/links/provenance/notes/guide/privacy/runbook; thiếu publisher/terms/target/current screenshots và installer. P15 preflight đã chạy BLOCKED_EXTERNAL,15policytestsPASS; chưa push/tag/draft/release/deploy/public download.

[Readiness R01–R12](READINESS_PUBLIC.json), [P15](bao-cao/P15.md), [kế hoạch public](KE_HOACH_PUBLIC.md) là trạng thái mới nhất; các ô public vẫn chưa tick. Không có thay đổi phạm vi nào cho các gate chưa kiểm chứng.


## Hiện trạng build3 — 02/10/2026

I01–I14 local đã triển khai,144PASS/0FAIL/4SKIP, Release/ad-hoc và DMG local build3 verified. [Toàn tiến độ/public](bao-cao/TONG_TIEN_DO_VA_PUBLIC_2026-10-02.md), [manifest](RELEASE_MANIFEST.md). Preflight/readiness vẫnfalse/BLOCKED_EXTERNAL; chưa gateR01–R12PASS đầy đủ. DeveloperIDApplication0, AppleDevelopment1; không remote/target/profile/publicpublisher đã xác nhận. Cần đóng native/IME/máy đích/hiệu năng/quota và qualificationOCR/video/hình học, rồi ký/notary/cài sạch/offline trướcpublic. Giá trị chưa biết trong bảng đầu vào vẫn cần chủ dự án chốt; không yêu cầu gửi secret vào chat.
