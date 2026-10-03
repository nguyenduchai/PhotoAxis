# Hợp nhất chức năng điều tra vào workspace — build 5, 03/10/2026

**DONE local theo yêu cầu giao diện:** PhotoAxis 1.0.0 (5) dùng một cửa sổ chỉnh sửa, một hệ tab và canvas chung. Đã bỏ menu Điều tra và cửa sổ hồ sơ/đối chiếu/rà soát riêng. Các tham số thao tác được đặt trực tiếp trong bảng bên phải; không còn hộp form modal riêng của gói điều tra. File picker Open/Save chuẩn của macOS vẫn dùng để chọn nguồn và đích.

Code đã kiểm: `218b788d04fb0bb6abd8bf3516e49409265eb435`. [Build manifest](bang-chung/WORKSPACE-20261003/build-manifest.json), [hướng dẫn đã cập nhật](../HUONG_DAN_DIEU_TRA.md), [ADR-023](../QUYET_DINH_KY_THUAT.md).

## Hành vi hiện tại

| Bảng trong workspace | Chức năng |
| --- | --- |
| Chỉnh sửa / Edit | Color, Properties, History, Layers và công cụ chỉnh ảnh hiện có |
| Nguồn / Sources | Tạo/mở/chọn hồ sơ, thông tin tiếp nhận, ảnh/video, danh mục, kiểm hash, mở bản làm việc thành tab |
| Phân tích / Analysis | Chú thích, đối chiếu nguồn/kết quả, OCR/rà soát, khung hình video, hiệu chuẩn và đo |
| Đầu ra / Output | Rà soát vùng che, PNG chia sẻ, PDF A4, danh mục, nhật ký và JSON phân tích |

- Tệp → Mở mở cả ảnh, `.paxis` và `.paxcase`; mở hồ sơ hiện bảng Nguồn. Nhấp một hàng ảnh mở hoặc chọn tab của bản làm việc, kể cả nhấp lại hàng đầu đã được chọn. Chuyển tab giữa hai hồ sơ đồng bộ danh mục/hồ sơ.
- OCR, đo, chọn vùng che và chú thích có nút **Chọn trực tiếp trên ảnh**. Kéo vùng hoặc nhấp các điểm trên canvas; tọa độ được đổi từ vùng ảnh thực sang pixel, loại bỏ phần lề. Điểm đo tồn tại sau mouseUp. Đặt lại, Return, Escape và Delete được hỗ trợ.
- OCR chọn ROI trên ảnh tiếp nhận; đo/vùng che/chú thích thường chọn trên canvas đã xử lý. Ô phóng to chọn theo nguồn nhúng ban đầu, kể cả khi canvas đã crop nhỏ hơn nguồn.
- Đối chiếu và rà soát OCR hiển thị trong vùng canvas, có **Quay lại chỉnh sửa**. Chuyển tab/model hoặc rời bảng đang nhập hủy draft chưa áp dụng; kết quả bất đồng bộ chỉ hiển thị khi ngữ cảnh còn khớp.
- Tab orphan/recovery cùng UUID nhưng không còn session hồ sơ được bảo vệ: không tự đóng hoặc thay mất tài liệu chưa lưu để mở lại item.
- Đã giữ nguyên byte tiếp nhận, định dạng hồ sơ, Undo và nhật ký bền vững. Đối chiếu, OCR và measurement là bản phân tích riêng; không biến Undo thành log và không đưa dữ liệu phân tích vào PNG chia sẻ.

## Kiểm thử và build

| Kiểm tra | Kết quả, phạm vi |
| --- | --- |
| Full suite mã cuối | **168 ca: 164 PASS / 1 FAIL / 3 SKIP**; [summary](bang-chung/WORKSPACE-20261003/test-summary.json), [log](bang-chung/WORKSPACE-20261003/debug-test.log) |
| 9 ca mới | **9 PASS**: inline Apply/Cancel, draft đổi tab/model, orphan không mất dữ liệu, hai hồ sơ đồng bộ tab, ROI/lề/reverse/clamp/NaN, mouseUp/Escape, chú thích một Undo/nguồn không đổi, magnifier sau crop, compute CPU chỉ dùng thiết bị Vision hỗ trợ |
| Targeted trước bổ sung compute | 40 PASS / 0 FAIL; không thay full suite cuối |
| Release | **BUILD SUCCEEDED**, local ad-hoc/arm64/minOS14; UUID **E9797D10-3807-344C-AE33-A172F11B04A5** |
| Inventory/localization | PASS; 466 khóa VI/EN, 392 tham chiếu |
| Website / release tooling | 12 trang PASS; 16 policy tests PASS |
| AutoLayout | Không có cảnh báo constraint xung đột trong full log cuối; đã sửa view khởi tạo kích thước 0 khi embed |

FAIL duy nhất là `ContentEditingTests.testInstalledVietnameseInputContext`: chuỗi phím Telex tổng hợp vẫn cho `tieengs vieetj ` thay vì `tiếng việt `. Đây là lỗi gate IME đã tồn tại trước build 5; không nhận cả suite PASS. Ba benchmark opt-in được SKIP. Các cảnh báo Metal `MDB_MAP_FULL` và QoS vẫn cần đánh giá. 19/43 nghiệm thu A01–A43 là bằng chứng build 3 lịch sử, chưa phải full acceptance build 5.

## Kiểm tra native trên binary cuối

QA VI/EN là bản sao Release chỉ đổi bundle ID/tên và ký ad-hoc lại, giữ **UUID và Core framework hash khớp Release**. [Binary verification](bang-chung/WORKSPACE-20261003/binary-verification.log). Máy: macOS27.0.1, M1 Pro/32GiB, Retina2×, Xcode27. Chỉ dùng fixture tổng hợp, không có hồ sơ thật.

| Luồng | Bằng chứng và kết quả |
| --- | --- |
| VI mở `.paxcase` bằng Tệp → Mở | Hồ sơ vào Nguồn; nhấp hàng đang chọn mở tab IMG-0001; menu không có Điều tra |
| VI chọn OCR bằng chuột, nhận và xác nhận | ROI **34,33,1489,420** trên nguồn1600×640; nhận đúng3dòng, không nhận dòng ngoài ROI; bản máy không đổi sau xác nhận. [Picker](bang-chung/WORKSPACE-20261003/vi-ocr-picker.png), [review](bang-chung/WORKSPACE-20261003/vi-ocr-review.png), [AX](bang-chung/WORKSPACE-20261003/vi-ocr-review.ax.txt) |
| VI hiệu chuẩn và đo bằng hai điểm | Đoạn chuẩn100mm, đoạn bằng nửa cho **50mm**; tính độc lập bằng tọa độ lưu khớp. [Ảnh](bang-chung/WORKSPACE-20261003/vi-measurement.png), [AX](bang-chung/WORKSPACE-20261003/vi-measurement.ax.txt) |
| EN rà soát OCR | Xác nhận và ghi log ngay trong cửa sổ chính. EN dùng bản nhận dạng đã lưu từ intake thử trước; không nhận là lượt nhận OCR mới trên EN. [Ảnh](bang-chung/WORKSPACE-20261003/en-ocr-review.png), [AX](bang-chung/WORKSPACE-20261003/en-ocr-review.ax.txt) |
| EN đối chiếu | Cùng canvas, swipe35%, zoom125% và controls cập nhật đúng. [Ảnh](bang-chung/WORKSPACE-20261003/en-comparison.png), [AX](bang-chung/WORKSPACE-20261003/en-comparison.ax.txt) |
| EN vùng che và PNG | Kéo vùng **32,468,1425,104**, Apply, xuất qua Output. PNG1600×640, **148.200 pixel đen đục**, hash khớp sharingCompleted; metadata chỉ ICC/PPI/kích thước/color space, không GPS/camera/text. [Ảnh trạng thái](bang-chung/WORKSPACE-20261003/en-output.png), [AX](bang-chung/WORKSPACE-20261003/en-output.ax.txt) |

[Audit độc lập](bang-chung/WORKSPACE-20261003/native-audit.json): 19 event giữa hai bản case có sequence/previous/hash payload khớp; original **70.012 byte**, SHA256 `b9ddf1340f1c09d8d7079d660e1cd186fb851ba7b771c922bcfcb8ae8b8abf24` và archive làm việc khớp. Intake và OCR đầu được tạo ở bản thử trong chặng này; lượt OCR thứ hai VI và review/đo/PNG nói trên dùng bản Release cuối. Không nhận PDF/video đầy đủ đã được rerun native trong chặng hợp nhất; backend regression của các luồng này đã có trong full suite.

OCR native lần đầu vẫn có thời gian chờ đáng kể khi Vision khởi tạo compute; sample cho thấy TextRecognition/ANE chờ semaphore rồi hoàn tất. Bản cuối đặt CPU ở các stage Vision công bố có CPU; nhận đúng3dòng và ghi compute policy, nhưng chưa chứng minh hết cold latency trên mọi stage/máy. Cold/warm và khả dụng tiếng Việt trên macOS đích tiếp tục là qualification mở.

## Phân phối và sẵn sàng public

Website Việt/Anh đã cập nhật nội dung build 5 và thao tác trong workspace. Repo/source/website public theo GPL-3.0-only đã được người dùng duyệt. GitHub [CI build5](https://github.com/nguyenduchai/PhotoAxis/actions/runs/37105754309) trên macOS15.7.9/Xcode16.4: **163 PASS / 0 FAIL / 5 SKIP**, 168total, Debug/test/Release thành công. SKIP3benchmark/Telex/large-layout không đóng các gate đó. [CI summary](bang-chung/WORKSPACE-20261003/ci-summary.json), [log](bang-chung/WORKSPACE-20261003/ci.log).

[Pages build5](https://github.com/nguyenduchai/PhotoAxis/actions/runs/37105754277) deploy và hậu kiểm anonymous HTTPS/hash **27file**/commit9333cff PASS; [receipt](bang-chung/WORKSPACE-20261003/pages-https.json). Các ảnh gallery build1/build3 giữ vai trò lịch sử, nội dung hướng dẫn build5 đã cập nhật.

DMG build5 từ checkout sạch9333cff được mount/tree/codesign/GPL/source notice/detach/copyhash PASS, SHA256 **32a7fad3139708906dcd445c76af6e18f092f8f0b201eb98cdf1ee31d1230802**, 2446543byte. Bản giao ở `$BUILD_ROOT/Deliverables/2026-10-03-build5-workspace`. [Release manifest](../RELEASE_MANIFEST.md), [receipt](bang-chung/WORKSPACE-20261003/delivery-receipt.json). Source/config/test/script fingerprint không đổi giữa mã sản phẩm218b788, checkout đóng gói/CI9333cff và commit tài liệu/receipts sau đó.

**Yêu cầu hợp nhất DONE local; stable public chưa đủ điều kiện.** `releaseReady=false`: cần đóng IME/native acceptance/máy đích/non-Retina/M1-16GB/performance/Metal-QoS/full quota/ảnh-video-đo thực, có Developer ID/notarization và cài sạch/Gatekeeper. Chức năng timeline video, batch OCR, tìm kiếm toàn hồ sơ, tự chèn bảng OCR/đo vào PDF, nắn sách3D tự động vẫn chưa triển khai; đây là tiện ích ngoài phạm vi hiện có. [Readiness](../READINESS_PUBLIC.json), [known issues](../KNOWN_ISSUES.md).
