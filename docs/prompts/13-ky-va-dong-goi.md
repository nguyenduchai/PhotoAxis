# P13 — Ký ứng dụng, notarization và bộ cài DMG

Thực hiện P13 sau Release Candidate P12. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, `docs/PHAT_HANH_PUBLIC.md`, báo cáo P12 và kiểm tra lại tài liệu Apple chính thức được dẫn trong đó. Đây là chuẩn bị artifact phân phối, chưa publish release.

## Công việc

1. Kiểm tra cấu hình thật: chủ thể/Team/bundle ID/UTI, Developer ID Application và quyền Keychain/notary. Không dùng danh tính mẫu để ký public. Nếu thiếu, nêu đúng đầu vào cần bổ sung và hoàn thành phần script/đóng gói độc lập; không báo notarized giả.
2. Hoàn thiện app icon/tài nguyên PhotoAxis của dự án, Info.plist, version/build, arm64 và minimum macOS 14. Nếu thay bundle ID tạm, kiểm tra document association, Settings, đường recovery/cache và chuyển dữ liệu phát triển có chủ đích.
3. Tạo Release archive từ source commit đã nghiệm thu. Kiểm tra Hardened Runtime, timestamp, release entitlement, nested code; không đưa `get-task-allow`/debug capability vào bản public. Không vô hiệu bảo vệ rộng để bỏ qua lỗi ký.
4. Viết script phát hành có cấu hình, log bỏ secret và fail-fast khi lỗi. Ký app, notarize bằng `notarytool`, chờ/kết luận theo trạng thái thực, lấy log khi lỗi, staple/validate; tạo/ký/notarize/staple DMG theo luồng trong tài liệu public. Không dùng `altool`.
5. Kiểm tra `codesign`/`spctl`/`stapler` bằng lệnh phù hợp artifact và toolchain; kiểm tra nội dung DMG. Dùng xác minh chữ ký sâu khi cần; không dùng ký `--deep` như cách vá thiếu cấu trúc ký.
6. Kiểm tra cài sạch với Gatekeeper/quarantine đúng luồng, chạy offline và workflow nguồn → crop → chữ → `.paxis` → export. Giữ nguyên môi trường bảo vệ hệ thống; máy không có phải ghi chưa kiểm chứng.
7. Sinh SHA-256 sau khi artifact cuối không còn thay đổi. Tạo `docs/RELEASE_MANIFEST.md` ghi version/build, source SHA, toolchain, identity public cần thiết, notary IDs/status và checksum. Không đưa chứng thư/private key/password/token vào repo hoặc báo cáo.

## Hoàn thành khi

- Có `PhotoAxis-1.0.0-arm64.dmg`, checksum và bằng chứng app/DMG ký/notarize/cài đúng; đánh giá R03–R08 và phần R01 liên quan.
- App trong DMG chính là bản đã kiểm tra; nếu code/config ảnh hưởng hành vi thay đổi sau P12, chạy lại kiểm tra liên quan trước khi kết luận.
- Thiếu quyền ký/notary/thiết bị bắt buộc thì giữ trạng thái BLOCKED_EXTERNAL cho phần đó, không thay bằng hướng dẫn tắt Gatekeeper.

Ghi `docs/bao-cao/P13.md`, scripts/hướng dẫn tái tạo, manifest và tiến độ. Giữ bộ cài ở thư mục artifact phù hợp, không commit binary lớn vào Git. Không public ở chặng này.
