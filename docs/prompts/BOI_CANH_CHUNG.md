# Bối cảnh chung cho mọi prompt PhotoAxis

## Thẩm quyền và phạm vi

Người dùng đã duyệt `docs/DAC_TA_V1.0.md`, bản **1.0-draft.3**, và yêu cầu bộ prompt xây dựng đến public. Kênh phát hành đã chọn là **tải trực tiếp từ website/GitHub Releases**. Không hỏi lại các quyết định này. Bản đặc tả ưu tiên hơn mockup, tài liệu định hướng cũ và ví dụ trong prompt khi có khác biệt.

Mỗi lần thực hiện một prompt: đọc hướng dẫn repository nếu có, đặc tả, checklist, tài liệu phát hành và trạng thái thực hiện; kiểm tra checkout/Git thực tế trước khi sửa. Không khởi tạo lại repo, xóa thay đổi đang có hoặc giả định mã nguồn còn trống. Các đường dẫn trong bộ prompt tính từ gốc repo PhotoAxis, không phải từ thư mục `docs/prompts`.

**Bản sản phẩm:** PhotoAxis 1.0; **bản public đầu tiên:** 1.0.0; **mã đặc tả:** 1.0-draft.3; **schema `.paxis`:** version 1. Không dùng mã đặc tả làm số phiên bản ứng dụng.

## Các ràng buộc đã duyệt

- macOS 14+, Apple Silicon; Swift/AppKit, MetalKit/Core Image; SwiftUI chỉ bổ trợ khi phù hợp. Không thay ứng dụng native bằng Electron, webview hay mockup chạy trong trình duyệt.
- Workspace tối theo Photoshop; giao diện Tiếng Việt và English, lựa chọn Theo hệ thống/Tiếng Việt/English. Nội dung tài liệu không phụ thuộc ngôn ngữ UI.
- Offline, không tài khoản, không cloud/telemetry/AI/subscription/updater tự động. Trang phân phối nằm ngoài ứng dụng; tài khoản Apple/GitHub là của nhà phát triển, không phải yêu cầu đăng nhập cho người dùng app.
- Layer ảnh/chữ/hình, Normal, chọn một layer; công cụ và giới hạn theo đặc tả. Không tự thêm PSD/RAW, brush, mask, Intel hoặc App Store.
- Perspective Crop tác động toàn tài liệu, gồm layer ẩn/khóa; giữ nguồn, loại layer, ma trận và clip. Không flatten để né khó khăn. Layer mới sau crop dùng canvas đã nắn.
- `.paxis` là một file ZIP có `document.json`, `assets/`, `preview.png`; lưu an toàn, nguồn nhúng. Không lẫn với DMG phân phối ứng dụng. PNG/JPEG là ảnh xuất.
- Dữ liệu tối đa: cạnh 8000 px, 40 MP canvas/mỗi nguồn, 50 layer, 120 MP nguồn duy nhất/tài liệu, 5 tab; lịch sử 100 bước/128 MiB. Kiểm tra giới hạn trước cấp phát.

## Cách thực hiện một chặng

1. Xác minh đầu vào và phụ thuộc của chặng. Nếu có hạng mục trước thiếu bằng chứng, kiểm tra hoặc sửa phần bắt buộc trước; không đánh dấu DONE theo lời nhắn cũ.
2. Thực hiện mã nguồn, UI, tài liệu và kiểm thử đến khi đầu ra của chặng dùng được. Mọi UI của chức năng chưa có phải disabled rõ theo ngữ cảnh; không trả thông báo thành công giả.
3. Chọn giải pháp đơn giản, có thể bảo trì; ghi quyết định đáng kể vào `docs/QUYET_DINH_KY_THUAT.md`. Không cần hỏi từng lựa chọn kỹ thuật thuận nghịch trong phạm vi đã duyệt. Việc thiếu tài khoản ký/phát hành không cản các phần phát triển local độc lập.
4. Dịch chuỗi vi/en ngay khi thêm tính năng. Các fixture hình học, file mẫu và ảnh chụp dùng dữ liệu tự tạo/được phép sử dụng; không dùng file cá nhân ngoài phạm vi yêu cầu.
5. Chạy kiểm tra phù hợp với thay đổi; ưu tiên geometry/model/file integrity/render và luồng người dùng. Không viết test chỉ lặp lại implementation. UI phải kiểm tra trên app native, không dùng mockup HTML làm bằng chứng.
6. Ghi lệnh, cấu hình, kết quả và đường dẫn bằng chứng vào `docs/bao-cao/Pxx.md`. Phân biệt PASS, FAIL, CHƯA KIỂM CHỨNG; không tick checklist khi chỉ compile thành công. Log phải bỏ thông tin nhạy cảm.
7. Cập nhật `docs/TIEN_DO_TRIEN_KHAI.md` và checklist tương ứng. Trạng thái chặng: TODO, IN_PROGRESS, BLOCKED_EXTERNAL hoặc DONE; mục bị chặn phải có nguyên nhân, việc đã xong và thông tin chính xác cần bổ sung.
8. Tạo commit local cho thay đổi của chặng sau khi kiểm tra, nếu danh tính Git đã có. Nếu chưa có, giữ thay đổi và báo rõ, không tự bịa danh tính. Không đưa chứng thư, khóa riêng, token, DerivedData, recovery cá nhân hoặc bộ cài lớn vào Git. Không tự push/publish ở P00–P14; P15 thực hiện phát hành theo yêu cầu của chính prompt đó.

Không tự đổi visibility repository. Public binary không đồng nghĩa public source. Các thao tác ghi đè/xóa dữ liệu người dùng không nằm trong phạm vi xây dựng thông thường.

## Mẫu bàn giao bắt buộc

- Chặng và trạng thái thực tế; đầu ra có thể mở/chạy.
- Thay đổi chính và lý do; ID yêu cầu Fxx, kiểm tra Axx/Rxx liên quan.
- Lệnh đã chạy, kết quả, cấu hình máy/OS, liên kết báo cáo/ảnh/file thử; phần chưa kiểm chứng.
- Commit nếu có; lỗi/tồn đọng có mức ảnh hưởng và người/điều kiện cần xử lý.
- Chặng tiếp theo và điều kiện có thể bắt đầu. Không hỏi lại việc triển khai nội dung đã duyệt.

Prompt của một chặng chỉ yêu cầu chặng đó. Khi người dùng yêu cầu “tiếp tục”, đọc tiến độ thực tế và làm chặng chưa hoàn thành đầu tiên, không khởi động lại từ P00. Nếu người dùng yêu cầu chạy nhiều chặng liên tiếp, tiếp tục trong phạm vi họ giao.
