# Fixture PhotoAxis

Dữ liệu trong bộ này tự tạo bằng `scripts/generate-fixtures.swift`, không lấy ảnh/file của người dùng. Chạy từ gốc repo bằng `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift scripts/generate-fixtures.swift`. Kết quả ở `Fixtures/Generated/` (không commit file sinh lớn), có manifest kích thước/profile/orientation/SHA-256 để cố định tập của từng lần thử. Byte encoder có thể khác giữa các SDK; khi benchmark phải dùng đúng manifest đã ghi, không sinh lại giữa các lượt.

| Fixture | P00 | Kỳ vọng và sử dụng |
| --- | --- | --- |
| grid-corners.png | Generator có | 640×480, sRGB; lưới 40 px, TL đỏ/TR xanh lá/BR xanh dương/BL vàng; đối chiếu orientation, homography, đảo trục A14–A17 |
| alpha-edges.png | Generator có | Đĩa đỏ có viền alpha chuyển dần 24 px, ngoài hoàn toàn trong suốt; xem trên trắng/đen, không halo; A31/A33 |
| grid-exif-6.jpg | Generator có | Encoded 640×480, EXIF orientation 6; sau normalize thành 480×640, góc theo phép xoay 90° CW; A05/A33 |
| colors-srgb.png / colors-display-p3.png | Generator có | Cùng RGB gradient 640×480, profile khác; chuyển sang sRGB phải theo ICC, không chỉ đổi nhãn; A33 |
| chữ-tiếng-Việt.txt | Generator có | Unicode nhiều dấu, nhiều dòng, tên file có dấu/khoảng trắng; sau nhập phải giữ nguyên nội dung; A22/A40–A43 |
| invalid-truncated.png | Generator có | Chỉ 24 byte đầu PNG; decoder phải báo lỗi, không tạo tài liệu thành công; A35 |
| Layer-set / `.paxis` | Kế hoạch P03/P07/P09 | Ảnh grid + ảnh phủ + text Việt + rectangle/ellipse/line; có layer hidden/locked; crop hai lần, Undo, lưu/mở, thêm/sửa chữ; A18–A21/A27 |
| ZIP/schema lỗi | Kế hoạch P09 | JSON lỗi/version mới, thiếu/trùng asset, NaN/Infinity, `../`, absolute path, symlink, bomb theo giới hạn, tên Unicode; test tạo trong temp directory, không bung dữ liệu nguy hiểm ra ngoài; A28 |
| HEIC, grayscale, HDR/depth cao | Kế hoạch P02/P10 | Sinh bằng Image I/O khi encoder SDK hỗ trợ; lưu manifest/nguồn/profile và kỳ vọng chuyển SDR; A05/A33 |
| Tập 24 MP/10 layer và tập giới hạn | Kế hoạch P12 | 6000×4000 tự tạo, overlay ≤4 MP, 4 text + 4 shape; canvas 40 MP/50 layer/nguồn ≤120 MP. Sinh có chủ đích khi đo, không commit binary lớn; A35–A37 |

Metadata generator kiểm tra được không đồng nghĩa PhotoAxis đã đọc/xuất các định dạng đó. P00 chưa có đường nhập ảnh. Fixture nhiều layer phải dùng schema/model thật khi có; không tạo `.paxis` giả để đánh dấu hoàn thành.

Mọi fixture mới cần mô tả nguồn/quyền sử dụng, kích thước, profile/alpha/orientation, giá trị kỳ vọng và ca Axx. File hỏng sinh trong thư mục thử riêng; không sửa file tài liệu người dùng. Log/ảnh bằng chứng phải tránh dữ liệu cá nhân.

## Fixture kiểm thử P02

Fixtures/P02 là bản nhỏ cố định của 5 ảnh, text Unicode, PNG hỏng và manifest do generator trên tạo, được commit làm input và **chỉ nhúng vào test bundle**. Có thể truyền thư mục đích cho generator: `swift scripts/generate-fixtures.swift /duong/dan/output`.

DocumentAppTests sinh thêm HEIC tĩnh, tên Việt/khoảng trắng, grayscale PNG 16 bit, PNG bỏ profile, PNG 8001×1, APNG hai frame và TIFF nhiều trang. Test kiểm tra EXIF/pixel/alpha/P3, cảnh báo depth → SDR, nguồn bất biến khi file ngoài đổi, preflight quota/resize consent và cancel/stale. HDR gain-map thực từ camera và stress 40 MP/120 MP vẫn cần P12; PNG 16 bit không thay thế toàn bộ HDR.
