# PhotoAxis Document — schema 1 và profile điều tra schema 2

Triển khai P09 theo baseline 1.0-draft.3; app mở rộng hiện tại PhotoAxis 1.0.0 (2). Tài liệu thông thường tiếp tục schema 1; riêng bản làm việc gắn hồ sơ Investigation 1 dùng schema 2. `.paxis` là **một file ZIP32 thông thường**, không phải thư mục package. Reader không thực thi nội dung và không giải nén đường dẫn ra filesystem. Đây là hợp đồng format cho reader/writer hiện tại; phiên bản sau phải tăng `formatVersion` khi đổi ngữ nghĩa không tương thích.

## Cấu trúc

- `document.json`: UTF-8 JSON, `formatIdentifier: "photoaxis.document"`, `formatVersion: 1` với tài liệu thường; `2` với bản làm việc điều tra.
- `assets/<sha256>`: byte ảnh nguồn bất biến, SHA-256 lowercase 64 ký tự; không có đuôi mở rộng. Một nguồn dùng chung chỉ có một entry. PNG/JPEG/HEIC/HEIF vẫn là byte đã nhập; nguồn đã được đồng ý giảm kích thước hoặc từ Clipboard dùng PNG chuẩn hóa của P02.
- `preview.png`: sRGB RGBA8, tối đa 512×512, chỉ để xem nhanh. Không thay thế nguồn hoặc layer.

Writer dùng ZIP method 0 (stored), CRC32, tên UTF-8, không encryption/extra fields/data descriptor. Điều này tránh nén lại các ảnh vốn đã nén và cho phép stream từng MiB vào file tạm. Reader hỗ trợ method 0 và Deflate raw (8) qua zlib hệ thống. Cả hai profile không nhận ZIP64, archive nhiều disk, encrypted ZIP, data descriptor, extra fields, directory/symlink/non-regular entry, prefix executable hoặc vùng dữ liệu dư. ZIP tạo bởi công cụ bên ngoài phải thuộc profile này; không cam kết đọc mọi biến thể ZIP. Cấu trúc ZIP tham chiếu [PKWARE APPNOTE 6.3.10](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT); raw Deflate và kiểm tra stream tham chiếu [zlib manual](https://zlib.net/manual.html). Không sao chép APPNOTE vào repository.

## JSON và đơn vị

Các trường bắt buộc cấp tài liệu: `id` UUID, `name` Unicode, `canvas: {width,height}`, `ppi` Double hữu hạn >0, `revision` UInt64, `sources`, `layers`. Width/height là pixel nguyên đã validate: cạnh 1…8000, canvas/source riêng ≤40 MP. `sources` là mảng `{id,size:{width,height}}`, kích thước đã áp dụng EXIF orientation. Tổng nguồn unique ≤120 MP; registry phải đúng tập ID layer dùng. Không lưu URL nguồn.

`layers` giữ thứ tự từ dưới lên, ≤50, UUID không trùng. Mỗi layer có `id`, `name`, `type`, `transform`, `clip`, `isVisible`, `isLocked`, `opacity` (0…1). Payload chỉ được phép đúng loại:

| type | Trường bắt buộc | Không xuất hiện |
| --- | --- | --- |
| image | `sourceID`, `imageAdjustments` | text, shape |
| text | `text` | sourceID, shape, imageAdjustments |
| shape | `shape` | sourceID, text, imageAdjustments |

`imageAdjustments`: `enabled`, `exposure` −4…+4 EV, `brightness`/`contrast`/`saturation` −100…+100. Giữ Double và giá trị khi disabled, không lưu hệ số CI hoặc chuỗi theo locale. `text`: text Unicode nhiều dòng, fontName (PostScript), fontFamily, fontStyle, fontSize px (1…1000), alignment left/center/right, lineSpacing px (0…1000), layoutSize width/height, color. Font thiếu giữ payload và extent gốc, báo fallback; không nhúng font binary. `shape`: kind rectangle/ellipse/line, size, fill/stroke, strokeWidth (0…1000 px), lineStart/lineEnd tọa độ chuẩn hóa 0…1. Màu dùng `{red,green,blue,alpha}`, Double sRGB 0…1; alpha=0 là None.

`transform` có đúng 9 Double hữu hạn, row-major, column vector `p_canvas ~ M × [x_local,y_local,1]`, gốc trái trên, y xuống, tọa độ biên pixel. Giữ đầy đủ độ chính xác Double. `clip` là giao các polygon lồi trong pixel local, giữ thứ tự/winding; `[]` không thêm clip, **`[[]]` loại toàn bộ**. Reader kiểm miền giữ lại không đi qua pole; pole ngoài miền clip hợp lệ. Hợp đồng hình học đầy đủ ở [HOP_DONG_DU_LIEU_PAXIS](HOP_DONG_DU_LIEU_PAXIS.md).

UI language, selection, FG/BG, zoom/pan, tool session, Undo, saved marker không nằm trong file. Mở lại tạo Undo mới rỗng và saved marker của state vừa đọc. Revision là bộ đếm nội dung, không phải lịch sử thao tác hoặc bằng chứng thời gian.

## Giới hạn container và reader

Giới hạn phòng tài nguyên của triển khai: archive và tổng entry chưa nén ≤1 GiB; mỗi source ≤512 MiB encoded; JSON ≤64 MiB; preview ≤8 MiB encoded; 2…52 entries; central directory ≤128 KiB; JSON nesting ≤24, tối đa 32 field/object và không có khóa trùng (kể cả escape tương đương); name layer/document ≤4096 byte UTF-8, text ≤1 MiB/layer. Clip ≤100 polygon/layer, ≤512 đỉnh/polygon, tổng ≤16.384 đỉnh/document. Các quota này được kiểm trước đọc/decompress payload hoặc trước phép hình học tương ứng. Không phải lời hứa tải file giới hạn trong thời gian benchmark chuẩn.

Reader kiểm EOCD, central/local header đồng nhất, miền byte không chồng lấn/liên tục, tên entry đúng whitelist, CRC32, kích thước khai báo/chính xác và kết thúc Deflate không có dữ liệu dư. JSON được đọc/validate trước image payload; registry phải khớp chính xác entry. Từng ảnh kiểm SHA-256, Image I/O type/count, metadata kích thước/orientation trước decode pixel. Preview cũng có giới hạn và decode hoàn chỉnh. Không lấy hash làm bằng chứng nguồn gốc hay thời gian.

Version >1 báo bản mới hơn, không tạo tài liệu và không ghi lại file. Version <1/identifier khác/malformed bị từ chối. Không tự sửa file hỏng hoặc bỏ layer để mở được.

## Save và điểm commit

Snapshot model/source/stateID lấy trên main actor sau khi giải quyết phiên chưa commit. Worker tạo preview, đóng gói nguồn gốc và JSON vào file `.photoaxis-<UUID>.tmp` cùng thư mục đích, mode 0600/O_EXCL/O_NOFOLLOW. File tạm được synchronize; tại điểm an toàn cuối kiểm hủy rồi rename cùng filesystem. Lỗi trước rename giữ bản trước; temp dọn bằng defer. Rename là điểm commit: hủy đến sau điểm này không hoàn tác một lần ghi đã thành công. Directory metadata được fsync khi filesystem hỗ trợ; không hứa chịu được mọi lỗi phần cứng/provider hoặc filesystem từ xa.

Saved marker chỉ được đặt sau worker thành công và theo **stateID snapshot**, nên edit phát sinh sau snapshot vẫn dirty; Undo về đúng state đã ghi trở lại clean. Save/Save As không tạo Undo. NSSavePanel cung cấp xác nhận overwrite. Export là luồng riêng P10. Coordinator là authority cho tab/quit, không đăng ký thêm NSDocumentController để tránh hai vòng close-review.

Mở cùng ID từ hai URL trong một phiên hiện bị từ chối để không trùng identity tab; đóng tab cũ rồi mở bản sao. File copied vẫn self-contained. Reader/writer không phụ thuộc ngôn ngữ UI. Fixture Deflate độc lập: `Fixtures/P09/empty-deflate.paxis`; mixed editable fixture và so byte render nằm trong bằng chứng P09.

## Profile điều tra schema 2

Schema 2 giữ cấu trúc ZIP, nguồn nhúng và layer typed ở trên, thêm `investigation: {caseID, itemID}` là hai UUID. `itemID` phải trùng ID tài liệu; schema 2 bắt buộc reference, schema 1 không được chứa reference. Writer không nâng version cho tài liệu thông thường. Reader hiện tại nhận tối đa version 2; version lớn hơn bị từ chối. PhotoAxis bản cũ chỉ đọc schema 1 sẽ từ chối schema 2.

Working archive được quản lý trong `.paxcase`, có checkpoint/hash riêng và nguồn tiếp nhận chuẩn hóa được giữ để phục hồi Delete → Save → Undo. Khi mở từ hồ sơ, current model trong manifest có thể mới hơn checkpoint; Undo trong phiên mới rỗng nhưng nhật ký hồ sơ vẫn đầy đủ. Khi mở `.paxis` điều tra riêng, app khóa sửa/Save/Export đến khi mở đúng hồ sơ. Save As/Place/Clipboard/Export thường bị chặn cho tài liệu gắn hồ sơ để giữ ngữ cảnh xử lý và rà soát chia sẻ. [Hợp đồng `.paxcase`](DINH_DANG_PAXCASE.md), [quy trình sử dụng](HUONG_DAN_DIEU_TRA.md).


## Paint1 — schema4 (build6)

Có typed paint layer thì formatVersion4, ưu tiên hơn Scan3/working2. Reader mới đọc1/2/3/4; project không paint giữ quy tắc version cũ. Paint có size và strokes: kind brush/clone, điểm top-left, diameter/hardness/opacity/colorRGBA, sourceID/sourceOffset chỉ cho clone. Mẫu clone PNG nhúng `assets/SHA256` cùng registry; sourceID phải tồn tại, payload không được gắn nhầm image/text/shape. Legacyversion1–3 chứa paint bị từ chối.

Nguồn clone là composite sRGB8-bit cố định; không cần ảnh input ngoài project. Paint sourceIDs dùng chung registry/hash/quota và giữ trong Undo khi layer xóa. Các điểm/settings giữ editable, transform/clip layer áp như nội dung khác. Settings công cụ hiện hành/cursor/điểm lấy mẫu UI không lưu; chỉ offset và nguồn của từng nét lưu. Giới hạn4096điểm/65536mẫu/nét;512nét/32768điểm/layer;262144điểm/120MP ROI document. [Đặc tả](DAC_TA_PAINT.md).
