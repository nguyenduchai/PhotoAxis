# PhotoAxis — Gói phục vụ điều tra, Investigation 1

> Cập nhật UI theo yêu cầu 03/10/2026: từ build5, toàn bộ luồng điều tra được hợp nhất vào workspace qua Nguồn / Phân tích / Đầu ra và canvas dùng chung. Mô tả menu/cửa sổ riêng bên dưới là thiết kế lịch sử, được thay bằng [hướng dẫn hiện tại](HUONG_DAN_DIEU_TRA.md) và ADR-023. Contract dữ liệu/toàn vẹn giữ nguyên.

Ngày 02/10/2026. Người dùng đã yêu cầu triển khai các nhóm chức năng ưu tiên đã thống nhất: giữ file tiếp nhận, bản làm việc, thông tin tiếp nhận/hash/nhật ký; chú thích/so sánh/metadata; bản ảnh A4 và che thông tin khi chia sẻ. Đây là phần mở rộng của baseline **1.0-draft.3**, không sửa lại các yêu cầu A01–A43 hoặc tự đóng các gate public R01–R12. App local: **1.0.0 (2)**, native AppKit/Core Image/Metal/Core Graphics/Core Text/Image I/O, offline.

## Yêu cầu và hành vi

| ID | Yêu cầu | Hành vi triển khai |
| --- | --- | --- |
| I01 | Giữ file tiếp nhận | Sao chép đúng byte vào `originals/<sha256>` trong `.paxcase`, tính SHA-256 trên byte được giữ; file gốc có quyền đọc 0444; không ghi pixel đã xử lý lên file tiếp nhận |
| I02 | Bản làm việc riêng | Mỗi ảnh có `.paxis` nguồn nhúng, nguồn đã chuẩn hóa theo giới hạn trình chỉnh sửa; có thể giảm kích thước sau xác nhận, trong khi file tiếp nhận giữ nguyên |
| I03 | Tiếp nhận và metadata | Mã hồ sơ, tiêu đề, người đang xử lý; nguồn/người cung cấp/người nhận/thời điểm tiếp nhận/biên bản bàn giao/chú thích; để trống điều chưa biết. Thời điểm máy ghi và metadata Image I/O của file gốc tách riêng |
| I04 | Nhật ký bền vững | Ghi nhận tiếp nhận, sửa thông tin, thao tác đã commit, tham số/model sau thao tác, Undo/Redo, Save/Discard, kiểm tra toàn vẹn và xuất file. Nhật ký theo chuỗi SHA-256, tồn tại sau mở lại và độc lập Undo trong phiên; xuất toàn bộ JSON |
| I05 | Quản lý danh mục | Một hồ sơ có nhiều ảnh với ID/mã ảnh ổn định theo thứ tự tiếp nhận, chọn ảnh, sửa thông tin/chú thích, mở bản làm việc; xuất danh mục nguồn JSON |
| I06 | Chú thích ảnh | Mũi tên, ellipse, số, chữ, ô phóng to nguồn; tạo layer image/text/shape riêng, giữ nguồn, chỉnh tiếp qua công cụ và Properties hiện có, một lần thêm là một bước Undo/nhật ký |
| I07 | So sánh | Cửa sổ native nguồn/kết quả, cùng zoom/pan, nút −/+ và pinch, kéo chuột/cuộn, Reset, hai ảnh cạnh nhau hoặc swipe; ảnh xem trước có EXIF orientation, SDR, cạnh tối đa 2000 px |
| I08 | Chia sẻ đã rà soát | Vùng che hình chữ nhật đen đục theo pixel canvas hiện tại; người dùng xác nhận vùng hoặc xác nhận không có vùng; gắn rà soát với SHA-256 model. Sửa model làm rà soát cũ mất hiệu lực; PNG được flatten, không sao chép GPS/ghi chú/thời gian chụp của nguồn |
| I09 | Bản ảnh A4 | PDF 1/2/4 ảnh mỗi trang, chú thích/mã ảnh/hash nguồn, mã hồ sơ/người lập/số trang; mọi ảnh phải rà soát vùng che đúng model. Trang raster 150 PPI, không chứa file nguồn, chữ chọn được hoặc layer PDF ẩn; từ chối chữ quá dài nếu không thể hiển thị đầy đủ |
| I10 | Ghi an toàn và chặn đường vòng | Một writer cho mỗi hồ sơ; manifest atomic; lỗi ghi nhật ký từ chối commit edit/Undo; Save chỉ đặt checkpoint sau manifest thành công. Tài liệu gắn hồ sơ chặn Save As/Place/Clipboard/Export thường; file làm việc mở riêng khóa sửa/xuất đến khi có ngữ cảnh hồ sơ |

## Giới hạn và ngữ nghĩa

- Một hồ sơ tối đa 100 ảnh, 512 MiB/file tiếp nhận, tổng khai báo file tiếp nhận tối đa 10 GiB; manifest tối đa 32 MiB và 10.000 event. 100 vùng che/ảnh. Giới hạn 8000 px/40 MP/50 layer/120 MP/5 tab của baseline giữ nguyên cho bản làm việc.
- Nhật ký chứa full model và thông tin tiếp nhận; có thể chạm giới hạn 32 MiB trước 10.000 event. Ứng dụng báo lỗi và giữ state trước khi không còn ghi được, không âm thầm bỏ event. Không có quay vòng/xóa nhật ký.
- Thông tin người xử lý do người dùng khai báo qua **Thông tin hồ sơ…**, không phải tài khoản được xác thực. Thời điểm máy không phải timestamp tin cậy. Metadata Image I/O là cách hệ thống đọc các trường nhận biết, không cam kết phân tích mọi trường riêng của nhà sản xuất; file gốc vẫn giữ toàn bộ byte.
- Ô phóng to dùng cùng source ID với layer ảnh, giữ clip cũ và clip ROI, không thêm nguồn raster khác. ROI dùng pixel nguồn chưa biến đổi; khung vị trí nguồn ánh xạ qua matrix của layer. Điều chỉnh ảnh được sao chép tại lúc tạo ô, sau đó các layer có thể chỉnh độc lập. Không tự tìm/khôi phục chi tiết.
- So sánh dùng cùng hệ tọa độ hiển thị, không tự đăng ký hình học. Sau Crop/Perspective, nguồn và kết quả có thể khác kích thước/vị trí; không dùng swipe như phép đo sai khác có hiệu chuẩn.
- PDF render tối đa một trang ảnh tại một thời điểm; dữ liệu PDF nén vẫn được giữ trước lần ghi atomic. Dừng nếu bộ đệm vượt ngưỡng an toàn khoảng 512 MiB. 150 PPI là chất lượng trang xuất, không suy ra độ phân giải hay độ chính xác của vật chứng.
- Vùng che chỉ tác động bản chia sẻ. `.paxcase`, `.paxis`, danh mục và nhật ký có thể chứa thông tin riêng tư; không xem chúng là file đã che. PNG/PDF vẫn có nội dung chú thích/mã hồ sơ người dùng chủ động xuất; kiểm tra cả nội dung này trước khi gửi.
- SHA-256 và chuỗi hash phát hiện sai khác nội bộ đã ghi, **không chứng minh nguồn gốc, thời gian chụp, tính xác thực hay thay thế hồ sơ bảo quản/bàn giao**. Chủ filesystem có thể thay byte và tính lại toàn bộ hash. Không có chữ ký số, timestamp bên ngoài, mã hóa hồ sơ hoặc chống sửa bởi quản trị máy.
- Ghi atomic được hỗ trợ trong phạm vi filesystem local: file được đồng bộ trước rename. Output chia sẻ ghi trên worker; manifest được serialize theo hồ sơ. Nên dùng package trên ổ local và sao lưu cả package sau khi đóng app. Không hứa an toàn với mọi hỏng phần cứng, filesystem mạng, phần mềm đồng bộ hoặc thay đổi filesystem có chủ ý trong lúc chạy. Có event bắt đầu nhưng không có event hoàn thành là tác vụ chưa có biên nhận đầy đủ.

## Ngoài phạm vi Investigation 1

OCR, trích frame video và đo có hiệu chuẩn đã được người dùng giao triển khai ở [Investigation 2](DAC_TA_MO_RONG_DIEU_TRA.md), app build3. Tài liệu này giữ hợp đồng Investigation 1/build2. Nhận dạng người/biển số, AI tái tạo, chữ ký số và kho hồ sơ tập trung chưa triển khai. Không có nút giả lập thành công cho các chức năng này. Không bổ sung PSD/RAW, cloud, tài khoản, telemetry hoặc updater.

Hợp đồng file: [DINH_DANG_PAXCASE](DINH_DANG_PAXCASE.md). Quy trình thao tác: [HUONG_DAN_DIEU_TRA](HUONG_DAN_DIEU_TRA.md). Kết quả thực tế: [báo cáo triển khai](bao-cao/GOI_DIEU_TRA.md).
