# Sử dụng gói phục vụ điều tra

PhotoAxis 1.0.0 (2) — Investigation 1. Giao diện Tiếng Việt/English. Chọn **Điều tra → Hồ sơ ảnh điều tra** trên menu để mở cửa sổ hồ sơ. Bản hiện tại là bản phát triển local; xem trạng thái nghiệm thu ở [GOI_DIEU_TRA](bao-cao/GOI_DIEU_TRA.md).

## Tiếp nhận và làm việc

1. Chọn **Tạo hồ sơ…**, nhập mã, tên và người đang xử lý, chọn nơi lưu `.paxcase` trên ổ local. Trong Save Panel, dùng tên file ngắn; dùng **Đi tới thư mục…** để chọn đường dẫn, không dán cả đường dẫn vào ô tên file. Chọn **Mở hồ sơ…** để mở package có sẵn. Có thể mở package từ Finder theo document association của app.
2. Chọn **Tiếp nhận ảnh…**, chọn PNG/JPEG/HEIC/HEIF được hỗ trợ. Nhập nguồn/người cung cấp/người nhận/thời điểm/biên bản bàn giao; để trống điều chưa biết. Không suy thông tin còn thiếu từ tên file. Thời điểm nhập bằng máy được lưu riêng.
3. File tiếp nhận được giữ đúng byte và hash. Nếu ảnh vượt quota trình chỉnh sửa, app yêu cầu xác nhận giảm kích thước riêng cho bản làm việc. Giảm bản làm việc không ghi lên file tiếp nhận.
4. Chọn ảnh trong **Danh mục ảnh**. Bảng bên phải hiển thị hash, thông tin tiếp nhận, metadata Image I/O của bản gốc và các event gần nhất. **Tiếp nhận và chú thích…** sửa thông tin bổ sung; **Thông tin hồ sơ…** đổi mã/tên/người đang xử lý với nhật ký trước/sau.
5. Chọn **Sửa bản làm việc** để chuyển sang workspace native. Dùng Move/Transform/Crop/Perspective/Text/Shape/Image Adjustments của PhotoAxis. Mỗi thao tác đã chốt, Undo và Redo đều ghi nhật ký hồ sơ. Nhập thêm nguồn vào hồ sơ qua Tiếp nhận ảnh; bản làm việc không nhận Place/Clipboard trực tiếp.
6. **Save** lưu checkpoint trong hồ sơ; **Save As** bị chặn với tài liệu gắn hồ sơ. Thao tác đã commit vẫn nằm trong case.json trước Save. Khi đóng, Don't Save phục hồi checkpoint và ghi việc bỏ chỉnh sửa; Cancel giữ các tài liệu. Mở lại hồ sơ phục hồi model hiện tại, Undo bắt đầu mới; nhật ký cũ vẫn còn.
7. **Kiểm tra toàn vẹn** đối chiếu manifest, hash file tiếp nhận và working archive. Nếu thất bại, giữ bản sao hồ sơ để kiểm tra nguyên nhân; ứng dụng không tự sửa hoặc bỏ qua mục hỏng.

## Chú thích và so sánh

**Thêm chú thích…** chọn mũi tên, ellipse, số, chữ hoặc ô phóng to. Vùng nhập dạng `x,y,rộng,cao`, dùng pixel, gốc trái trên; ví dụ `20,30,80,60`. Với chú thích thông thường đây là canvas bản làm việc. Ô phóng to dùng ROI của nguồn nhúng trước biến đổi và layer ảnh nguồn đầu tiên; khung nguồn đi theo matrix của ảnh, inset giữ cùng source và clip, tối đa phóng 2× để vừa canvas. Điều chỉnh của inset và ảnh sau đó là độc lập. Mỗi thành phần có tên layer để chọn/chỉnh trong workspace.

**So sánh nguồn/kết quả** mở cửa sổ riêng. Nút **−/+** hoặc pinch thay zoom; kéo chuột và cuộn thay pan của cả hai ảnh; chế độ swipe dùng thanh chia để xem hai kết quả ở cùng vùng hiển thị. Reset đưa zoom/pan về đầu, kể cả khi đã kéo ảnh ra ngoài vùng nhìn thấy. Sau crop/perspective, app không tự căn đăng ký nguồn với kết quả; đây là hỗ trợ nhìn so sánh, không là phép đo có hiệu chuẩn. Ảnh hiển thị tối đa 2000 px/cạnh, không thay file tiếp nhận.

## Rà soát và xuất chia sẻ

1. Chọn **Xác nhận vùng che…** cho từng ảnh. Nhập `x,y,rộng,cao;x,y,rộng,cao` theo canvas đã xử lý. Để trống chỉ khi đã rà soát và quyết định không có vùng cần che. Các hình chữ nhật được che đen đục trên bản xuất, không sửa file gốc.
2. Rà soát gắn với model hiện tại. Khi model hiện tại khác model đã rà soát, kể cả chỉ đổi tên layer, phải xác nhận vùng lại trước khi xuất. Undo về đúng model đã rà soát có thể dùng lại xác nhận của model đó. Cách này ưu tiên kiểm tra lại sau thay đổi hình học hoặc nội dung.
3. **Xuất PNG chia sẻ…** xuất ảnh flatten đục, giữ PPI/sRGB, loại metadata riêng tư của nguồn. Mở file xuất để kiểm tra đúng vùng và cả chú thích trước khi gửi.
4. **Lập bản ảnh A4…** chọn 1, 2 hoặc 4 ảnh mỗi trang. Toàn bộ danh mục theo thứ tự tiếp nhận phải được rà soát đúng model. PDF có mã/chú thích/hash nguồn và tiêu đề/mã hồ sơ/người lập/số trang. Nếu tiêu đề/chú thích quá dài không thể đặt đầy đủ, app báo giới hạn; rút gọn nội dung hoặc chọn bố cục nhiều diện tích hơn.
5. **Danh mục nguồn…** xuất thông tin tiếp nhận, mã ảnh, tên file, byte count/hash và chú thích. **Xuất nhật ký đầy đủ…** xuất toàn bộ event/param/model sau thao tác. Hai file JSON này có thể chứa thông tin riêng tư, không được che như PNG/PDF.

Không lưu bản chia sẻ hoặc file thông thường vào bên trong `.paxcase`. Khi sao lưu/chuyển hồ sơ, giữ toàn bộ package, làm khi không còn thao tác ghi và đối chiếu hash qua **Kiểm tra toàn vẹn** trên bản nhận. Một app giữ writer lock cho hồ sơ đến khi thoát; mở cùng package ở app khác sẽ bị từ chối.

Hash chứng minh byte khớp giá trị đã ghi trong phạm vi kiểm tra. Nó không tự chứng minh nguồn gốc, thời gian, nội dung thật hay thay quy trình bảo quản/bàn giao. Hồ sơ không được mã hóa hoặc ký số trong bản này. OCR/video/đo đạc hiệu chuẩn/AI tái tạo chưa có; xem [đặc tả gói](DAC_TA_GOI_DIEU_TRA.md).

## OCR tiếng Việt, video và đo — Investigation2/build3

1. Chọn ảnh → **OCR tiếng Việt…**. Nhập ROI x/y/width/height theo nguồn làm việc lúc tiếp nhận; mặc định toàn nguồn. Cửa sổ mở có ảnh/khung cam, bản máy chỉ đọc và bản rà soát có thể sửa. Đối chiếu từng phần nhìn thấy, để trống phần không đọc được rồi **Xác nhận và lưu bản rà soát**. **Rà soát OCR…** mở lại bản gần nhất; xác nhận mới tạo revision, không xóa bản máy/các lần trước. Hệ điều hành thiếu tiếng Việt sẽ tắt OCR có lý do.
2. **Tiếp nhận video…** chọn MOV/MP4, khai báo intake như ảnh. Byte video được giữ riêng. **Trích khung hình…** nhập số video trong danh mục và frameIndex từ0 (khung đầu là0), offset giây nếu có và căn cứ. Khung đã giải mã trở thành ảnh làm việc; chi tiết hồ sơ chứa video/hash/track/ordinal/PTS và offset riêng. Dùng công cụ chú thích/so sánh/che/PDF như ảnh khác. PTS tương đối của track không phải giờ thực tế camera.
3. Chọn ảnh → **Hiệu chuẩn đo…**. Hai điểm thước chuẩn dạng `x,y; x,y`, độ dài thật, mm/cm/m; ghi căn cứ thước và vật cùng mặt phẳng/ảnh đủ điều kiện một tỷ lệ. Xem thước xanh trên canvas. **Đo khoảng cách/diện tích…**: đoạn2điểm hoặc đa giác3–64đỉnh quanh biên; xem điểm đỏ và kết quả. Thay model làm nút đo tắt đến khi hiệu chuẩn lại; số đo trước còn lưu như lịch sử. Dùng pixel góc trên trái, số thập phân dấu chấm, không lấy zoom/PPI làm thước chuẩn.
4. **Xuất phân tích và truy vết…** tạo JSON đầy đủ các nhóm trên và hash ledger/model. Đây là dữ liệu chưa che, không gửi thay bản PNG/PDF đã rà soát. Có thể đối chiếu calibration.modelSHA256 với currentItems.currentModelSHA256 để nhận biết phép đo trên trạng thái ảnh trước. Sao lưu cả `.paxcase` sau khi đóng ứng dụng; app Investigation1 không đọc hồ sơ schema2 đã có phân tích.

Các tọa độ được nhập rõ bằng ô native và có ảnh xem/overlay để đối chiếu. Gói này không có timeline video, chọn điểm đo bằng chuột, OCR hàng loạt/tìm kiếm toàn hồ sơ hoặc báo cáo PDF tự chèn bảng OCR/phép đo. Những cải tiến quy trình này không được mô tả như đã có.
