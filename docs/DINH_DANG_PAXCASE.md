# PhotoAxis Investigation — `.paxcase` schema 1/2

`.paxcase` là thư mục package, khác `.paxis` ZIP. Đăng ký UTI `$(PHOTOAXIS_DOCUMENT_UTI).investigation`, conform `com.apple.package`/`public.directory`. Giữ toàn bộ package khi sao lưu hoặc chuyển máy.

```text
Ho-so.paxcase/
  case.json
  .case-lock
  originals/<received-file-sha256>
  projects/<item-uuid>-<working-archive-sha256>.paxis
```

`case.json`: UTF-8 JSON `formatIdentifier=photoaxis.investigation`, `formatVersion=1`. Có UUID/mã/tên hồ sơ, người đang xử lý, thời điểm tạo, `items`, `events`. Quyền folder 0700; manifest/working archive theo atomic writer 0600; original 0444. Quyền đọc không ngăn chủ filesystem tự thay quyền.

Mỗi item có UUID/mã số, chú thích, thông tin tiếp nhận, thời điểm nhập, tên file nhận, hash/byte count, metadata JSON, working source ID, `currentModelJSON`, `savedModelJSON` (Data được Codable encode base64), hash `.paxis` checkpoint và danh sách vùng che/model hash lúc rà soát. `intakeWorkingFileSHA256` giữ archive nguồn chuẩn hóa lúc tiếp nhận; trường tùy chọn để đọc prototype cũ, được bổ sung khi Save. Model có `investigation={caseID,itemID}` và ID tài liệu trùng item ID.

File original được khử trùng theo hash; hai mục tiếp nhận vẫn giữ intake/ID độc lập. Giới hạn tổng 10 GiB tính theo tổng byte count của các mục, kể cả nguồn dùng chung, để việc kiểm tra có tính bảo thủ. `projects` có nguồn đã chuẩn hóa phục vụ bản làm việc. Nhật ký có model lịch sử; không nhúng thêm image asset vào từng event.

Mỗi event có sequence bắt đầu từ 1, UUID, thời điểm ISO8601 UTC của máy, phiên bản app, operation, operatorName, itemID tùy chọn, details và modelAfterJSON tùy chọn. `sha256 = SHA256(JSON sortedKeys(payload))`; `previousSHA256` nối event trước, event đầu nối 64 chữ số 0. `caseStateSHA256` trong details event cuối ràng buộc dữ liệu hồ sơ/items hiện tại. Validate kiểm sequence, ID, hash nối, trạng thái cuối và model hiện tại khớp event model gần nhất của mỗi item. File manifest giới hạn 32 MiB, nesting 24, 128 khóa/object, từ chối khóa trùng trước JSONDecoder.

Không có secret/key/signature. Việc tính lại hash sau sửa toàn bộ package không bị phát hiện bởi phép kiểm nội bộ này. Người nhận cần đối chiếu hash/mã hồ sơ với biên nhận hoặc nguồn lưu độc lập do quy trình của họ quản lý.

## Transaction

POSIX `flock(LOCK_EX|LOCK_NB)` trên `.case-lock` giữ một writer cho mỗi hồ sơ trong phiên. Khóa tự nhả khi app thoát; không cần xóa `.case-lock`. Manifest được đối chiếu hash với phiên đang mở trước khi thay đổi. Regular-file/O_NOFOLLOW, kích thước và timestamp đọc/hash được kiểm; thư mục gốc/originals/projects phải là directory thật.

Edit/Undo/Redo: tạo candidate model/history, ghi manifest có event/model mới bằng atomic writer; chỉ commit model/UI/Undo nếu ghi thành công. Sửa thông tin và rà soát vùng che cũng ghi manifest trước hiển thị. Đóng nhiều tab bằng Don't Save chỉ thay các model hiện tại về checkpoint và append event sau khi mọi lựa chọn đóng đã chấp nhận; Cancel giữ các state.

Save: ghi event `workingSaveStarted`; tạo `.paxis` mới ở stage, hash và publish tên chứa hash; atomic manifest chuyển `workingFileSHA256`/saved model rồi mới đặt saved marker. Lỗi ghi biên nhận dọn archive mới và giữ archive checkpoint cũ. Sau commit chỉ dọn checkpoint trung gian, luôn giữ archive tiếp nhận và checkpoint mới nhất (có thể cùng một file). Khi Delete → Save → Undo rồi khởi động lại, nguồn cần cho current model được lấy thêm từ archive tiếp nhận đã kiểm hash. Crash có thể để orphan không tham chiếu; không tự dùng orphan làm checkpoint. Current model trong case.json vẫn giữ edit chưa Save và được phục hồi khi mở hồ sơ lại; Undo của phiên mới rỗng.

Export: ghi Started; render và ghi file đích atomic ở ngoài `.paxcase` bằng worker utility, không thực hiện lần ghi output trên main thread; ghi Completed với hash file/model/regions hoặc input ledger. Lỗi ở bước biên nhận cuối có thể để file đích đã ghi; app báo lỗi, không báo đã hoàn tất. Không thể atomic đồng thời file bên ngoài và manifest hồ sơ trên hai filesystem. Manifest thao tác vẫn được serialize trong ngữ cảnh điều khiển hồ sơ; package nên ở ổ local, không nhận đây là cam kết UI không thể bị chặn bởi mọi filesystem/provider.

## Tương thích

`.paxis` thông thường tiếp tục schema **1**. Chỉ working archive gắn hồ sơ dùng schema **2**, cùng ZIP profile/typed layer/assets của P09 và thêm investigation reference. App cũ chỉ biết schema 1 phải từ chối schema 2, tránh xuất/sửa mất dấu gắn hồ sơ. App mới mở working archive thiếu ngữ cảnh `.paxcase` sẽ khóa sửa/Save/Export; mở hồ sơ để tiếp tục. Không chuyển schema 2 thành schema 1 bằng Save As.

Format này là bản mở rộng local đầu tiên. Không hỗ trợ merge hai hồ sơ cùng UUID trong một phiên. Không cam kết đọc dữ liệu do phần mềm ngoài tạo nếu không đạt toàn bộ kiểm tra.

## Investigation 2 — schema2

`analysis` tùy chọn chứa `ocr`, `videos`, `frames`, `calibrations`, `measurements`. Bản schema1 không có trường này, state digest vẫn cùng canonical JSON cũ. Khi thêm phân tích, schema2 bắt buộc và state digest cuối bao gồm toàn bộ `analysis`; ID/hash/quan hệ item–video–frame–calibration được kiểm cùng event/model như trước. App build2 chỉ biết formatVersion1 từ chối hồ sơ mới; không giảm schema2 về1 bằng cách bỏ trường.

Video nhận nằm ở `originals/<video-sha256>.<mov|mp4|m4v>` (giữ đuôi container để AVFoundation mở đúng), cùng cơ chế giữ byte/read-only và quota tổng10GiB. Metadata giữ tên nhận/intake/trackID/encodedSize/preferredTransform/duration rational. Frame là item PNG dẫn xuất riêng; `frames` liên kết videoID/itemID/trackID/hash hai đầu, ordinal0-based và PTS `{value:Int64,timescale:Int32}`. Không đổi PTS theo offset. `correctedRelativeSeconds` được tính từ PTS+offset; không tạo giờ quay tuyệt đối.

OCR gắn itemID/originalSHA/sourceSHA/size/ROI; từng dòng có text/confidence/box, confirmations giữ text/operator/giờ máy riêng theo thứ tự append. Nhận dạng không làm đổi model/pixel. Phép đo lưu calibrationID/points/kind/result/operator/giờ máy; calibration giữ nguồn/model hash/canvas/reference2điểm/knownLength/unit/assumption. Validate tính lại kết quả, từ chối polygon tự cắt/không hữu hạn. Phép đo lịch sử còn giữ khi model đổi; store từ chối tạo phép đo mới bằng calibration không trùng model hiện tại.

Export `photoaxis.investigation-analysis` schema1 có caseID/code/title/input ledger hash, currentItems(itemID/originalSHA/currentModelSHA) và toàn bộ analysis. JSON này chứa thông tin chưa che; cần kiểm người nhận/nội dung. Processing log và analysis export bổ sung cho nhau: event ghi operation/ID/hash/ROI; nội dung OCR/calibration đầy đủ được giữ trong manifest/analysis JSON được state digest ràng buộc. [Đặc tả chi tiết](DAC_TA_MO_RONG_DIEU_TRA.md).
