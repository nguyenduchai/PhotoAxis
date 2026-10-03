# PhotoAxis — public và xử lý sự cố

## Chuẩn bị và kiểm tra R01–R09/R12

Đọc RELEASE_CANDIDATE/RELEASE_MANIFEST/MA_TRAN_NGHIEM_THU/KNOWN_ISSUES/KE_HOACH_PUBLIC. Không đánh dấu ready từ build xanh. Source repo, distribution repo và website có thể khác nhau; giữ quan hệ commit/asset/hash rõ. Không đổi visibility, force-push, dời public tag hoặc cấp phép source từ Git author. Chỉ publish target đã được chủ dự án xác nhận.

1. Đóng gate native cuối/Telex/macOS14/non-Retina/máy chuẩn và warning có đánh giá; record R02 theo build mới. Chốt publisher/support/terms/pricing/namespace/Team/identity/notary profile; không đặt secrets trong JSON/chat/Git.
2. Build/accept/archive từ sourcecommit sạch; P13signed→Accepted→staple→payload/checksum cuối. Nếu byte/code/config đổi, quay lại nhóm nghiệm thu/ký tương ứng; không reuse checksum cũ.
3. Trên môi trường sạch, giữ quarantine/browser download, Gatekeeper chuẩn/offline/minOS/workflow/upgrade; record R07/R08. Mở khóa Mac cho native; không lấy hosted callback thay thao tác thực.
4. Hoàn thiện website production: current native VI/EN/Perspective before/after, host/privacy/publisher/support/terms/price thực, versioned DMG/release/checksumlinks/canonical. Không public preview có thiếu metadata. Kiểm12page/mobile/keyboard/links nữa khi nội dung thay đổi.
5. Kiểm source/distribution repo quyền và visibility hiện tại; remoteURL/tag/targetSHA đúng; CI của sourcecommit đã thành công nếu có. Push sourcecommit/tag không force. Repo phân phối riêng dùng commit của chính repo đó, không giả sourceSHA là distributionSHA.
6. Draft releasev1.0.0 tại repo phân phối đã chốt, attach DMGfinal +SHA256SUMS+notes. Nếu draft đã có, đọc assets và đối chiếu hash trước; không clobber hay duplicate. Nếu tag/public đã tồn tại khác artifact, dừng và dùng patch mới sau kiểm lại.
7. Tải lại assets draft theo quyền developer, hash/sign/staple/manifest nhất quán; publish khi đủ gate. Deploy ZIPsite production đúnghost/config; không gửi email/mạng xã hội.
8. R10/R11: truy cập HTTPS/redirect/404 và tải asset không auth/cookie; kiểm SHA/sign/staple/version/payload bản tải, cài Gatekeeper chuẩn và offline/fullworkflow. Ghi actual URLs, downloaded hash, source/tag/distribution commit/websitecommit. Không dùng localapp thay downloadedasset.

Luồng draft→attach→publish theo [GitHub Managing releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository), kiểm02/10/2026. Quy trình signed/notary theo nguồn Apple trong HUONG_DAN_PHAT_HANH. Không thêm automation theo dõi khi chưa có yêu cầu riêng.

## Ngừng giới thiệu bản lỗi

- Khi phát hiện download/hash/signature/Save/Export/phối cảnh/mất dữ liệu lỗi: ghi đúng version/asset/SHA, giữ fixture và report tối thiểu không chứa ảnh riêng; đánh giá ảnh hưởng trước tiếp tục phát hành.
- Tắt nút tải/đánh dấu tình trạng website đãdeploy và ngừng quảng bá version lỗi; không thaybinary dưới cùngtag. Nếu có bản tốt trước đó, chỉ trỏ versionedlink của bản đã kiểm. **Bản1.0.0 đầu tiên chưa có bản rollback:** tạm ngừng download và thông báo, không bịa link bản tốt.
- Giữ release/evidence/checksum lịch sử để truy vết; không tự xóa version/tag đãpublic, source/recovery/dự án của người dùng. Việc gỡ asset nếu cần phải có quyền/đánh giá cụ thể và ghi hồ sơ.
- Sửa trên branch/bản mới, regression đúng nguyên nhân, kiểm Save/Open/Export/Perspective/IME phầnảnh hưởng; tăng patch version/build, ký/notarize/cài/verify mới. Đưa1.0.1/tag mới khiđạt, cập nhật latest/site/hash rồi tải ẩn danh postcheck.
- Nếu site deploy hỏng nhưng binary tốt, khôi phục siteartifact trước đã kiểm hoặc trang thông báo bảo trì; không đổi binary để vá link. R12 chỉ coi hoàn tất vận hành khi target/quyền và artifact sitebackup thật đã có.
