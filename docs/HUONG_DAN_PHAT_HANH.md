# Công cụ P13 — ký và đóng gói

Chạy từ repository; artifacts ngoài Git trong build root của `scripts/environment.sh`. Dùng Python standard library và công cụ Xcode/macOS. Không cần dependency ngoài.

```sh
scripts/check.sh
scripts/build.sh Release
python3 -m unittest discover -s Tests/ReleaseTooling -v
python3 scripts/distribution.py local
```

Local chỉ tạo DMG `LOCAL-UNSIGNED`, kiểm payload/chữ ký ad-hoc và checksum; không notarize hoặc publish. Không đưa file đó lên nút tải public. Script không ghi đè artifact đã tồn tại và cleanup mount trong finally. macOS27 phát cảnh báo hdiutil deprecated; vẫn dùng giao diện có trên macOS14, warning lưu trong log. Đã sửa parser khi stderr warning làm hỏng plist và kiểm hồi quy bằng stdout XML/stderr riêng.

Để chuẩn bị ký, sao chép `Config/Distribution.example.json` thành `Config/Distribution.local.json` (gitignored). Chỉ điền thông tin chủ dự án đã chốt. Không thêm password/token/API private key; script chỉ nhận tên Keychain profile. Chủ máy cấu hình Developer ID Application và credentials notary trong Keychain bằng công cụ Apple. Git author không là publisher.

```sh
python3 scripts/distribution.py preflight
python3 scripts/distribution.py signed
```

Preflight cần R02 releaseReady, checkout sạch và nguồn/config không khác candidate đã kiểm; identity Developer ID Application khớp Team, notary Keychain profile hoạt động. `signed` tạo Release archive không testability, Hardened Runtime, namespaces theo config; ký framework trước app với runtime/timestamp và empty release entitlements. Verify nested ID/UTI/signature/runtime/timestamp/entitlements, notarize ZIPapp chờ Accepted và lấy log; staple/validate app→spctl execute→create/sign/notarize/staple/validate DMG→spctl open/context primary-signature→mount/compare→checksum cuối. Không ký --deep, không altool, không xóa quarantine/tắt Gatekeeper/disable-library-validation/get-task-allow.

Notary log nguyên giữ ngoài Git; trước chia sẻ phải bỏ account/contact/path nếu có. Script không gửi ảnh/dự án cá nhân, chỉ artifact build đã nghiệm thu. Submission thất bại dừng; không đưa Accepted giả hoặc checksum cũ. Không chạy script signed khi config mẫu/RC blocked.

Bundle ID/UTI mới tách Settings/Recovery/cache khỏi development namespace. Không tự chuyển recovery/preference cá nhân; chủ dự án cần migration có chủ đích và kiểm Finder association/save panel/Settings/Recovery trên signed build. `.paxis` schema/source bytes không đổi khi đổi UI/namespace.

Sau ký: dùng máy/tài khoản sạch macOS14 và OSmới thật, tải qua trình duyệt giữ quarantine, copy Applications/mở Gatekeeper chuẩn, thử offline và source→Perspective→chữ Việt→Save/reopen→PNG/JPEG/Recovery. Bằng chứng phải từ app trong DMG đúng checksum, không lấy local Debug thế. Ghi cleanInstallVerified/offlineWorkflowVerified trong manifest chỉ sau có report/test thực.

Nguồn kiểm ngày02/10/2026: [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [custom workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow), [TN2206 nested signing](https://developer.apple.com/library/archive/technotes/tn2206/). `notarytool submit --help`/`stapler --help` đã đối chiếu trên toolchain27.
