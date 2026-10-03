# Sử dụng gói phục vụ điều tra

PhotoAxis 1.0.0 (5). Các chức năng hồ sơ, OCR, video, đo và đầu ra dùng chung workspace native với trình chỉnh ảnh. Bảng bên phải có **Chỉnh sửa / Nguồn / Phân tích / Đầu ra**; không có menu hay cửa sổ Điều tra riêng. Bản hiện tại là bản phát triển local; xem [kết quả tích hợp](bao-cao/HOP_NHAT_WORKSPACE_2026-10-03.md) và [trạng thái public](READINESS_PUBLIC.json).

## Tiếp nhận và làm việc

1. Trong bảng **Nguồn**, chọn **Tạo hồ sơ…**, nhập mã, tên và người đang xử lý ngay trên bảng bên phải, bấm **Áp dụng**, chọn nơi lưu `.paxcase` trên ổ local. Trong Save Panel, dùng tên file ngắn; dùng **Đi tới thư mục…** để chọn đường dẫn, không dán cả đường dẫn vào ô tên file. Chọn **Mở hồ sơ…** để mở package có sẵn. Có thể mở package từ Finder theo document association của app.
2. Chọn **Tiếp nhận ảnh…**, chọn PNG/JPEG/HEIC/HEIF được hỗ trợ. Nhập nguồn/người cung cấp/người nhận/thời điểm/biên bản bàn giao; để trống điều chưa biết. Không suy thông tin còn thiếu từ tên file. Thời điểm nhập bằng máy được lưu riêng.
3. File tiếp nhận được giữ đúng byte và hash. Nếu ảnh vượt quota trình chỉnh sửa, app yêu cầu xác nhận giảm kích thước riêng cho bản làm việc. Giảm bản làm việc không ghi lên file tiếp nhận.
4. Chọn ảnh trong **Danh mục ảnh**. Bảng bên phải hiển thị hash, thông tin tiếp nhận, metadata Image I/O của bản gốc và các event gần nhất. **Tiếp nhận và chú thích…** sửa thông tin bổ sung; **Thông tin hồ sơ…** đổi mã/tên/người đang xử lý với nhật ký trước/sau.
5. Chọn ảnh trong danh mục để mở bản làm việc thành tab ngay trong workspace; nút **Sửa bản làm việc** mở lại ảnh đang chọn. Chuyển bảng **Chỉnh sửa** để thao tác layer/Properties/History. Dùng Move/Transform/Crop/Perspective/Text/Shape/Image Adjustments của PhotoAxis. Mỗi thao tác đã chốt, Undo và Redo đều ghi nhật ký hồ sơ. Nhập thêm nguồn vào hồ sơ qua Tiếp nhận ảnh; bản làm việc không nhận Place/Clipboard trực tiếp.
6. **Save** lưu checkpoint trong hồ sơ; **Save As** bị chặn với tài liệu gắn hồ sơ. Thao tác đã commit vẫn nằm trong case.json trước Save. Khi đóng, Don't Save phục hồi checkpoint và ghi việc bỏ chỉnh sửa; Cancel giữ các tài liệu. Mở lại hồ sơ phục hồi model hiện tại, Undo bắt đầu mới; nhật ký cũ vẫn còn.
7. **Kiểm tra toàn vẹn** đối chiếu manifest, hash file tiếp nhận và working archive. Nếu thất bại, giữ bản sao hồ sơ để kiểm tra nguyên nhân; ứng dụng không tự sửa hoặc bỏ qua mục hỏng.

## Chú thích và so sánh

Trong bảng **Phân tích**, **Thêm chú thích…** chọn mũi tên, ellipse, số, chữ hoặc ô phóng to. Bấm **Chọn trực tiếp trên ảnh**, kéo một vùng rồi **Áp dụng**. Có thể chỉnh số pixel ở bảng bên phải, gốc trái trên. Với chú thích thông thường đây là canvas bản làm việc. Ô phóng to dùng ROI của nguồn nhúng trước biến đổi và layer ảnh nguồn đầu tiên; khung nguồn đi theo matrix của ảnh, inset giữ cùng source và clip, tối đa phóng 2× để vừa canvas. Điều chỉnh của inset và ảnh sau đó là độc lập. Mỗi thành phần có tên layer để chọn/chỉnh trong workspace.

**So sánh nguồn/kết quả** hiển thị trong khu vực canvas của cùng cửa sổ workspace. **Quay lại chỉnh sửa** trả về canvas tài liệu. Nút **−/+** hoặc pinch thay zoom; kéo chuột và cuộn thay pan của cả hai ảnh; chế độ swipe dùng thanh chia để xem hai kết quả ở cùng vùng hiển thị. Reset đưa zoom/pan về đầu, kể cả khi đã kéo ảnh ra ngoài vùng nhìn thấy. Sau crop/perspective, app không tự căn đăng ký nguồn với kết quả; đây là hỗ trợ nhìn so sánh, không là phép đo có hiệu chuẩn. Ảnh hiển thị tối đa 2000 px/cạnh, không thay file tiếp nhận.

## Rà soát và xuất chia sẻ

1. Trong **Đầu ra**, chọn **Xác nhận vùng che…** cho từng ảnh. Bấm **Chọn trực tiếp trên ảnh**, kéo các vùng, **Đặt lại** xóa bản nháp và **Áp dụng** chốt rà soát. Có thể nhập `x,y,rộng,cao;x,y,rộng,cao` theo canvas đã xử lý. Để trống chỉ khi đã rà soát và quyết định không có vùng cần che. Các hình chữ nhật được che đen đục trên bản xuất, không sửa file gốc.
2. Rà soát gắn với model hiện tại. Khi model hiện tại khác model đã rà soát, kể cả chỉ đổi tên layer, phải xác nhận vùng lại trước khi xuất. Undo về đúng model đã rà soát có thể dùng lại xác nhận của model đó. Cách này ưu tiên kiểm tra lại sau thay đổi hình học hoặc nội dung.
3. **Xuất PNG chia sẻ…** xuất ảnh flatten đục, giữ PPI/sRGB, loại metadata riêng tư của nguồn. Mở file xuất để kiểm tra đúng vùng và cả chú thích trước khi gửi.
4. **Lập bản ảnh A4…** chọn 1, 2 hoặc 4 ảnh mỗi trang. Toàn bộ danh mục theo thứ tự tiếp nhận phải được rà soát đúng model. PDF có mã/chú thích/hash nguồn và tiêu đề/mã hồ sơ/người lập/số trang. Nếu tiêu đề/chú thích quá dài không thể đặt đầy đủ, app báo giới hạn; rút gọn nội dung hoặc chọn bố cục nhiều diện tích hơn.
5. **Danh mục nguồn…** xuất thông tin tiếp nhận, mã ảnh, tên file, byte count/hash và chú thích. **Xuất nhật ký đầy đủ…** xuất toàn bộ event/param/model sau thao tác. Hai file JSON này có thể chứa thông tin riêng tư, không được che như PNG/PDF.

Không lưu bản chia sẻ hoặc file thông thường vào bên trong `.paxcase`. Khi sao lưu/chuyển hồ sơ, giữ toàn bộ package, làm khi không còn thao tác ghi và đối chiếu hash qua **Kiểm tra toàn vẹn** trên bản nhận. Một app giữ writer lock cho hồ sơ đến khi thoát; mở cùng package ở app khác sẽ bị từ chối.

Hash chứng minh byte khớp giá trị đã ghi trong phạm vi kiểm tra. Nó không tự chứng minh nguồn gốc, thời gian, nội dung thật hay thay quy trình bảo quản/bàn giao. Hồ sơ không được mã hóa hoặc ký số trong bản này. OCR/video/đo có hiệu chuẩn đã có như mô tả bên dưới. AI tái tạo chưa triển khai; xem [đặc tả gói](DAC_TA_GOI_DIEU_TRA.md).

## OCR tiếng Việt, video và đo trong workspace — build5

1. Chọn ảnh → **OCR tiếng Việt…**. Bấm **Chọn trực tiếp trên ảnh** để kéo ROI trên nguồn lúc tiếp nhận, hoặc nhập x/y/width/height trên bảng; mặc định toàn nguồn. Kết quả hiện trong khu vực canvas với ảnh/khung cam, bản máy chỉ đọc và bản rà soát có thể sửa. Đối chiếu từng phần nhìn thấy, để trống phần không đọc được rồi **Xác nhận và lưu bản rà soát**. **Rà soát OCR…** mở lại bản gần nhất; xác nhận mới tạo revision, không xóa bản máy/các lần trước. Hệ điều hành thiếu tiếng Việt sẽ tắt OCR có lý do.
2. **Tiếp nhận video…** chọn MOV/MP4, khai báo intake như ảnh. Byte video được giữ riêng. **Trích khung hình…** nhập số video trong danh mục và frameIndex từ0 (khung đầu là0), offset giây nếu có và căn cứ. Khung đã giải mã trở thành ảnh làm việc; chi tiết hồ sơ chứa video/hash/track/ordinal/PTS và offset riêng. Dùng công cụ chú thích/so sánh/che/PDF như ảnh khác. PTS tương đối của track không phải giờ thực tế camera.
3. Chọn ảnh → **Hiệu chuẩn đo…**. Bấm **Chọn trực tiếp trên ảnh**, nhấp hai đầu thước chuẩn; nhập độ dài thật, mm/cm/m và Áp dụng; ghi căn cứ thước và vật cùng mặt phẳng/ảnh đủ điều kiện một tỷ lệ. Xem thước xanh trên canvas. **Đo khoảng cách/diện tích…**: nhấp hai điểm cho khoảng cách hoặc 3–64 đỉnh theo thứ tự quanh biên cho diện tích rồi Áp dụng; xem điểm đỏ và kết quả. Thay model làm nút đo tắt đến khi hiệu chuẩn lại; số đo trước còn lưu như lịch sử. Dùng pixel góc trên trái, số thập phân dấu chấm, không lấy zoom/PPI làm thước chuẩn.
4. **Xuất phân tích và truy vết…** tạo JSON đầy đủ các nhóm trên và hash ledger/model. Đây là dữ liệu chưa che, không gửi thay bản PNG/PDF đã rà soát. Có thể đối chiếu calibration.modelSHA256 với currentItems.currentModelSHA256 để nhận biết phép đo trên trạng thái ảnh trước. Sao lưu cả `.paxcase` sau khi đóng ứng dụng; app Investigation1 không đọc hồ sơ schema2 đã có phân tích.

Các tọa độ chọn bằng chuột được quy đổi về pixel của ảnh hiển thị, độc lập với kích thước vùng canvas trên màn hình. OCR dùng nguồn tiếp nhận; đo/che/chú thích thông thường dùng model hiện tại; ô phóng to dùng nguồn nhúng của layer ảnh đầu tiên và giữ clip đã crop. Return chốt/Escape hủy khi canvas chọn vùng đang có focus; Delete bỏ vùng/điểm cuối. Đổi bảng, đổi tab hoặc thay model hủy lựa chọn chưa chốt. So sánh, OCR và overlay đo ở cùng cửa sổ; nút Quay lại chỉnh sửa đưa về tài liệu.

Bảng Nguồn có danh sách hồ sơ đang mở; tab bản làm việc đổi hồ sơ/ảnh tương ứng tự động. Nếu tồn tại tab phục hồi hoặc tab không gắn session của cùng ảnh, app từ chối mở trùng thay vì bỏ bản chưa lưu. Hãy hoàn tất lưu/đóng tab đó trước. Timeline video, OCR hàng loạt/tìm kiếm toàn hồ sơ và PDF tự chèn bảng OCR/phép đo chưa triển khai.
