# PhotoAxis — Kiến trúc P00–P12

Áp dụng đặc tả **1.0-draft.3**, ứng dụng **1.0.0**, `.paxis` schema **1**. Tài liệu này phân biệt mã đã có và hợp đồng dành cho chặng sau. P04 đã bổ sung Crop chữ nhật, clip renderer và các phép đổi kích thước/xoay/lật canvas trên nền tài liệu/import/Layers/Move/Transform/History; P05 có Perspective Crop ảnh đơn với solver, candidate preview và inverse sampling hữu hạn; P06/P07 đã tích hợp text/shape và Perspective nhiều layer giữ editable; P08 thêm điều chỉnh ảnh theo layer. P09 có bounded ZIP/schema và Save/Open; P10 có Image I/O Export/actual ICC/atomic write; P11 có RecoveryStore và preflight đóng nhiều tài liệu. P12 tối ưu preview tương tác và benchmark/stress; chưa thay các gate native/thiết bị.

## Ranh giới thành phần

| Thành phần | Vị trí | Trách nhiệm và chiều phụ thuộc |
| --- | --- | --- |
| DocumentModel | `Sources/PhotoAxisCore/DocumentModel` | Giá trị không phụ thuộc UI; hiện có CanvasSize, DocumentLimits, PhotoDocumentModel, source registry và payload image/text/shape; placement/quota có kiểm tra. Không đọc AppKit, file hoặc GPU. |
| Geometry | `Sources/PhotoAxisCore/Geometry` | Double, projective matrix và document↔view; dùng chung preview/hit-test/export. Hiện có ghép/inverse/ánh xạ điểm, có CropRegion, giao đa giác lồi và phép đổi hình học canvas; có solver Perspective Crop, kiểm tra miền mẫu số và retained support theo clip. |
| Commands/Undo | `Sources/PhotoAxisApp/Commands` | Điều phối command đã commit và UndoManager mỗi tài liệu; dựa trên Core; không chứa pixel renderer. |
| Renderer | `Sources/PhotoAxisApp/Renderer` | MTKView, Core Image, cache và snapshot render; phụ thuộc Core; không sửa model. |
| Tools | `Sources/PhotoAxisApp/Tools` | P01 có ToolKind, tên/phím tắt và vector icon native. P03 có CanvasEditing/TransformOptionsView và phiên Transform; P04 có CropInteraction/CropOptionsView; P05 có PerspectiveInteraction/PerspectiveOptionsView; text thuộc P06. |
| NativeWorkspace | `Sources/PhotoAxisApp/NativeWorkspace` | P01 có NSWindow/NSView, menu, Tools, Options/overflow, Color/Properties-History/Layers, rulers/status, focus/Tab và WorkspacePreferences. Lệnh backend chưa có được disabled. |
| Localization | `Sources/PhotoAxisApp/Localization` | 298 khóa vi/en, L10n bất biến theo phiên; Settings lưu System Default/vi/en, áp dụng lần mở sau và có English fallback. |
| Persistence | `Sources/PhotoAxisApp/Commands/{PhotoDocument,ProjectStore,RecoveryStore}.swift` và `NativeWorkspace/DocumentCoordinator.swift` | NSDocument, nhập ảnh, ZIP/schema, lưu an toàn, recovery; chuyển DTO hợp lệ thành Core; không làm UI chờ I/O. |
| Export | `Sources/PhotoAxisApp/Commands/{ExportStore,ICCEmbedding}.swift` và `NativeWorkspace/ExportController.swift` | Render snapshot, Image I/O encode PNG/JPEG, ghi tạm/thay thế; dùng chung Renderer, không sửa saved marker. |

`PhotoAxisCore.framework` là module kiểm thử độc lập; `PhotoAxis.app` nhúng module này. Các thư mục còn lại là ranh giới mã nguồn trong target ứng dụng, chưa tách thành hàng loạt framework/package. Không có dependency bên thứ ba. Không dùng webview/Electron/SwiftUI ở P00–P05. Hosted XCTest kiểm tra UI AppKit và preference; Swift Testing kiểm tra Core.

## Hợp đồng tọa độ

- **Layer local**: px nội bộ của ảnh đã chuẩn hóa EXIF orientation, hoặc hệ nội bộ của text/shape; gốc trái trên, x sang phải, y xuống dưới.
- **Document**: px canvas hiện tại, cùng hướng trục. Biên canvas `[0,width] × [0,height]`; tâm pixel `(x+0.5,y+0.5)`.
- **View**: point AppKit trong view flipped. `view = originInView + document × zoom / backingScale`. Origin là vị trí góc trái trên canvas trong viewport, đã gồm pan/căn giữa.
- **Device**: pixel backing. `zoom=1` nghĩa là 1 px ảnh = 1 px thiết bị; trên Retina 2× tương ứng 0.5 pt. Khi chuyển màn hình phải cập nhật backingScale, drawableSize và origin để giữ điểm neo.
- Core Image/Core Graphics không mặc định dùng hệ y-down: adapter tại Renderer chuyển y theo chiều cao extent tương ứng; không chèn phép lật rải rác vào model/Tools. Quy đổi qua API `convertToBacking`/`convertFromBacking` tại ranh giới AppKit để xử lý pixel alignment.
- Tay nắm/đường overlay đo bằng point, không theo scale ảnh. Overlay tách khỏi composite xuất.

## Ma trận layer và clip

`ProjectiveTransform` dùng 9 Double row-major, nhân vector cột: `p_document ~ M_layer × [x_local,y_local,1]`. `existing.followed(by: H)` trả `H × existing`. Ma trận không phụ thuộc ngôn ngữ UI và không làm thay đổi byte nguồn.

Perspective Crop ở P05/P07 phải kiểm tra bốn đỉnh TL/TR/BR/BL theo đúng nhận dạng, lồi/không giao nhau/đủ diện tích; solver tính H từ canvas cũ tới canvas mới. H phải khả nghịch, hữu hạn, mẫu số không qua 0 trên miền cần lấy mẫu. Kiểm tra ma trận/điểm ở P00 **không** thay thế kiểm tra toàn miền này.

Khi Apply: lấy snapshot trước thao tác; với **mọi layer**, kể cả hidden/locked, cập nhật `M_new = H × M_old`. Mỗi layer giữ payload có kiểu image/text/shape; text và shape không bị thay bằng ảnh raster. Nguồn ảnh là asset bất biến dùng chung qua ID; duplicate không nhân đôi ngân sách nguồn.

Clip là các miền đa giác lồi giao nhau trong **tọa độ layer local**. Khi crop, đưa tứ giác được chọn (đã giới hạn canvas cũ) qua `inverse(M_old)` rồi thêm ràng buộc clip cho layer; giữ các clip cũ. Cần xác nhận miền inverse liên tục trước khi tạo đa giác. Clip áp dụng trước ánh xạ layer, sau đó cắt tại canvas đích khi render. Move/transform về sau di chuyển cả nội dung và clip; pixel ngoài vùng đã crop không tự hiện lại. Crop lần hai tiếp tục giao ràng buộc, không bỏ clip lần đầu. Canvas Size không khôi phục pixel đã bị clip. Dữ liệu nguồn vẫn tồn tại để Undo trong phiên.

Layer mới sau crop có ma trận identity trong canvas **mới**, không kế thừa H hoặc clip của layer cũ. Clip và ma trận phải lưu trong `.paxis`; saved preview không phải nguồn. P07 phải chứng minh phương án bằng fixture nhiều layer, cả hidden/locked, crop hai lần, Undo và tiếp tục sửa; P09 bổ sung round-trip file.

## Màu và alpha

Nguồn nhúng giữ nguyên byte khi phù hợp; Image I/O đọc metadata/orientation/profile trước khi decode. Nguồn không profile giả định sRGB; nguồn P3/HDR/độ sâu cao được chuyển theo đặc tả sang workflow SDR sRGB, có thông báo khi cần. Working space của Core Image dự kiến **linear sRGB**, buffer trung gian premultiplied alpha; blending Normal source-over. Pixel ngoài nguồn/clip là transparent black. Bộ lọc ảnh trước phép biến đổi rồi mới composite: Exposure → Brightness/Contrast → Saturation.

Preview dùng display color management của macOS; export chuyển encoded sRGB 8 bit/kênh, gắn ICC và PPI. PNG giữ alpha đúng quy ước encoder; JPEG composite với matte trong không gian làm việc rồi encode. Không làm unpremultiply trên alpha=0 không được bảo vệ. Kiểm chứng viền alpha trên nền sáng/tối trước khi chốt renderer; không suy diễn màu đúng từ screenshot P00.

## State, command và background jobs

AppKit, NSDocument và state đã commit thuộc MainActor. Core chứa value types Sendable. Mỗi tài liệu có ID, revision cho render, UUID state/saved marker, UndoManager; lựa chọn layer/viewport không nằm trong lịch sử. Phiên công cụ là state tạm riêng; Apply tạo một command, Cancel bỏ phiên. Lịch sử giữ snapshot metadata/nguồn dùng chung, tối đa 100 bước/128 MiB, loại cũ nhất và giữ saved marker chính xác.

Decode, render/export, đóng ZIP và recovery chạy ngoài MainActor bằng worker có giới hạn; truyền snapshot bất biến và asset handles hợp lệ. Preview gắn document ID + revision + viewport generation; bỏ kết quả lỗi thời kể cả khi tác vụ GPU không hủy được. Tác vụ nặng có cancellation/progress; dự kiến một export toàn ứng dụng mỗi lúc và coalesce preview theo tài liệu. Không truy cập NSView từ worker, không detached task không có chủ quản lý vòng đời.

Kiểm tra cạnh/diện tích trước cấp phát. Sau đó kiểm tra 50 layer, 5 tab, 120 MP **nguồn duy nhất**, ngân sách cache và tổng tác vụ đang chạy. P02 thực thi cạnh/diện tích, 50 layer, 120 MP nguồn duy nhất, 5 tab và cache 256 MiB. P03 thực thi ngân sách lịch sử 100 bước/128 MiB; stress/benchmark ở P12. Thiếu bộ nhớ thì giữ tài liệu và từ chối công việc mới có lý do.

## Persistence và an toàn file

NSDocument làm adapter vòng đời; Save mặc định chỉ qua `.paxis`, không dùng in-place autosave để ghi đè ảnh nguồn hoặc tự ghi phiên chưa Apply. Recovery riêng chỉ chứa thay đổi đã commit. Save thành công mới cập nhật saved state ID; nếu user đã sửa trong lúc lưu thì revision hiện tại vẫn dirty.

`.paxis` là **một file ZIP**, format identifier `photoaxis.document`, version 1, có `document.json`, `assets/` theo ID ổn định và `preview.png`. P09 đăng ký UTI development `com.photoaxis.document`; reader ZIP32 tự kiểm tra bounds/CRC/path và dùng zlib hệ thống cho DEFLATE; writer STORE giữ nguồn nguyên byte. UTI/bundle ID phát hành phải được chủ dự án chốt trước P13.

Trước đọc: kiểm tra schema, số entry, tổng/kích thước giải nén, path traversal/absolute paths, symlink, ID trùng hoặc nguồn thiếu, số hữu hạn và quota. Khi lưu: snapshot → file tạm cùng volume → hoàn tất/kiểm chứng container → thay thế đích an toàn; lỗi/hủy giữ bản cũ, không báo Saved. Recovery/cache ngoài container, không đưa dữ liệu riêng tư vào Git. Locale/UI preference/undo không ghi vào JSON.

## State workspace và ngôn ngữ (P01)

`WorkspacePreferences` thuộc MainActor, dùng UserDefaults của app, độc lập hoàn toàn với DocumentModel/JSON. `workspace.layout.v1` chứa độ rộng bảng, một/hai cột, thu gọn bảng, hiển thị rulers. Clamp 260–420 pt; dữ liệu hỏng trở về mặc định. Reset chỉ thay layout, giữ lựa chọn ngôn ngữ. Trạng thái ẩn chrome do Tab là tạm trong phiên.

`L10n` đọc lựa chọn lúc launch và giữ bundle vi/en bất biến; Settings chỉ lưu lựa chọn cho launch sau, không tự thoát hoặc thay nội dung đang mở. Khi Theo hệ thống, chọn ngôn ngữ đầu tiên được hỗ trợ; không khớp thì English. Ngôn ngữ UI không đổi locale số macOS. Trường độ rộng bảng hiện chỉ nhận số nguyên 260–420 pt; parse/hiển thị dùng NumberFormatter theo vùng, từ chối chuỗi parse một phần.

Layout workspace dùng NSView flipped và frame theo point; NSStackView chỉ dùng cho nhóm controls. Khởi tạo stack với frame hợp lệ để không sinh xung đột Auto Layout kích thước 0. Apply/Cancel có vùng cố định bên phải; options dài chuyển vào menu overflow. P01 chỉ thử component overflow, chưa có phiên Perspective Crop thực.

Tab được xử lý tại canvas first responder, không có event monitor toàn app chiếm phím của NSTextView. Bảng kéo có focus, phím trái/phải và accessibility Increment/Decrement. NSWindow automatic tabbing tắt để tab tài liệu P02 do workspace quản lý. P02 có tab thật và trạng thái zoom/pan/tool/selection/UndoManager riêng.

## Phần đã triển khai ở P02

- PhotoDocument/NSDocument chứa model, assets sở hữu byte riêng, UndoManager và trạng thái tab. DocumentCoordinator là nơi duy nhất quyết định close/quit; **không đăng ký** các tab với NSDocumentController vì review-unsaved mặc định tạo vòng đời cạnh tranh. Ảnh nhập không trở thành fileURL dự án, autosavesInPlace=false. Save/Export chưa có; không có saved marker giả.
- Image I/O kiểm tra metadata/type/count trước decode; SHA-256 của byte nguồn làm ID. Chèn trên selection, căn giữa, giữ tỷ lệ, không phóng to ảnh nhỏ. Resize cần consent, thumbnail từ URL nếu nguồn vượt giới hạn; không nạp cả payload lớn chỉ để bỏ. File bên ngoài không bị ghi.
- ViewportState đo zoom bằng device px/document px, giữ anchor khi zoom, giữ tâm khi resize/backingScale đổi. Viewport không sửa model/Undo. Rulers dùng cùng tọa độ; border overlay đo point, dùng viewport của frame nhận được.
- ImagePipeline actor thực thi tuần tự decode/render; ID/revision/generation chặn kết quả cũ. MTKView trình bày bitmap đã hoàn tất. LRU decoded cache 256 MiB, thu hồi nguồn tab nền. Đây không phải giới hạn tổng RSS: byte nguồn, đồ thị CI và buffer tạm vẫn theo quota tài liệu.
- Working linear sRGB, EXIF normalization, RGBA8 sRGB; depth cao/HDR gain map có báo SDR. Import có progress/cancel và lỗi từng file. Image I/O/CI không ngắt giữa lời gọi; kiểm tra cancellation trước/sau và không commit tác vụ đã hủy.
- P04 đã bổ sung rasterization clip đa giác; text/shape khác rectangle thuộc P06. Renderer hiện từ chối payload chưa hỗ trợ. Nền trắng/đen là rectangle khóa; UI mở khóa đã có ở P03. Model text/shape đã có kiểu, chưa có công cụ tạo/sửa tương ứng.

## Layer và phiên chỉnh sửa P03

`LayerOperations` kiểm tra khóa, quota và giá trị trước thay model. Duplicate cấp UUID mới, chia sẻ source ID, giữ clip/ma trận/opacity/visibility/lock nhưng tham số độc lập. Xóa chỉ bỏ source khỏi registry hiện tại khi không layer nào còn dùng; PhotoDocument giữ byte nguồn cần cho cả Undo lẫn Redo.

`DocumentHistory` giữ snapshot metadata trước/sau và UUID trạng thái độc lập revision render. Command ID ổn định, nhãn vi/en lấy lúc hiện. Ngân sách gồm metadata ước lượng bảo thủ và byte encoded nguồn có thể chỉ còn cần bởi history ở bất kỳ cursor nào (union nguồn trừ intersection nguồn của mọi trạng thái). Tối đa 100 entry/128 MiB; loại từ đầu và tiến baseline, không di chuyển saved marker sang trạng thái khác. Dữ liệu pixel không nằm trong từng closure UndoManager. Đây không phải giới hạn RSS hoặc decoded cache. Save thật sẽ gọi markSaved(stateID:) của snapshot chỉ sau ghi thành công ở P09.

NSUndoManager dùng groupsByEvent=false; mỗi command là một group, callback đăng ký ngược cho Redo. Rebuild bridge khi thêm/cắt/prune history, phục hồi cursor bằng callback không sửa model. Session giữ model original/preview, Apply mới commit; Cancel bỏ preview. Gesture về đúng trạng thái ban đầu không thêm lịch sử hoặc cắt Redo. Tab khác không kết thúc session; đổi công cụ/chọn lớp/lệnh thay model/đóng hỏi Apply/Discard/Cancel. Keyboard repeat Move kết thúc khi keyUp hoặc mất focus. MouseUp khi đang Space-pan kết thúc tại preview cuối, không cộng pan vào layer.

Transform scale/rotate/translate trong document space rồi nhân bên trái ma trận cũ, giữ phép phối cảnh. X/Y/W/H là bounding box theo trục canvas; angle lấy hướng cạnh trên đã ánh xạ. Liên kết tỷ lệ bật mặc định, Shift đảo trong scale và bắt góc quay tuyệt đối 15°. Geometry chặn pole trong miền ảnh, bbox nhỏ hơn 0.01 px hoặc góc vượt ±1,000,000 px trước gửi CI; handle scale không vượt qua cạnh đối diện, dùng Flip để đổi hướng. Quy tắc này là guard hình học, không đổi giới hạn kích thước tài liệu.

Canvas hit-test nội dung từ trên xuống ngoài MainActor, qua inverse matrix rồi pixel alpha; bỏ hidden/locked/opacity=0. Pending pick bị hủy khi đổi tab/tool/viewport để không áp kết quả tại tọa độ cũ. Handles đo point trên presentedViewport, tám điểm resize và một điểm rotate; renderer snapshot và overlay dùng chung frame generation. Clip renderer có ở P04, text/shape editing tiếp tục P06/P07; P03 nghiệm thu layer ảnh và nền rectangle hiện có.

## Crop và hình học toàn tài liệu P04

`DocumentGeometry` thực hiện atomic trên bản sao model, gồm mọi layer hiện có, cả hidden/locked. Crop giao footprint của layer trong document space với khung nằm trong canvas cũ, inverse-map phần giao về local rồi giao tiếp clip cũ. Biểu diễn một đa giác lồi; `[[]]` là không còn vùng hiển thị, khác `[]` là không hạn chế. Layer/source/UUID và payload vẫn giữ nguyên. Sau đó nhân translation/scale lên ma trận cũ; không reset phần projective. Chỉ những payload đã có local bounds (image và shape hiện có) được xử lý; Type renderer/bounds sẽ nối ở P06/P07.

Core Image dùng mặt nạ grayscale 8-bit trong local space trước transform; kiểm tra 8000 px/40 MP trước cấp phát. Mặt nạ là chi tiết renderer, không phải công cụ mask người dùng. Crop nhiều lần giao thêm ràng buộc; mở rộng canvas, Move hoặc rotate không mở lại pixel cũ. Một mask tối đa 40 MB; đây không phải ngân sách toàn renderer/RSS. Preview và `renderDocument` chia sẻ composite; đường image-only không có checkerboard, lưới hay handles, dành cho kiểm thử pixel và export P10.

CropState riêng từng tab, có region, tỷ lệ/output và basis của lần kéo/Reset cuối. Nhập số liên tục fit từ basis để các chữ số trung gian không làm khung co dần; giá trị lỗi không thay vùng hợp lệ. Ratio lấy kích thước vùng cắt làm tròn ra pixel nguyên, W×H nhận số nguyên và resample bằng cùng đường transform Core Image. Apply một command, Cancel bỏ state; trở về công cụ trước Crop. `hasSession` hợp nhất Crop/Transform tại mọi entry point đang có; Save/Export vẫn disabled đến P09/P10.

Image Size nhân scale toàn tài liệu; chỉ đổi PPI thì giữ nguyên layer/pixel dimensions. Canvas Size dịch theo chín anchor, không scale; phần mở rộng trong suốt và không bỏ clip. Rotate/flip dùng ma trận chính xác quanh canvas. Mỗi Apply/menu action đi qua command/UndoManager; viewport Fit sau thao tác không nằm trong Undo. Các field WxH/PPI/ratio được validate trước commit, không cấp phát ảnh để thử một giá trị số.

## Perspective Crop ảnh đơn P05

`PerspectiveQuad` giải/kiểm tra homography và sinh grid bằng inverse mapping từ các đường 1/3, 2/3 của output. `PerspectiveState` thuộc từng PhotoDocument, giữ quad/mode/constraints/candidate/error; không ghi nguồn hay history trong lúc kéo. Enter/Apply ghi command `.perspectiveCrop`; Esc/Cancel bỏ candidate. Các entry point đã có dùng chung resolve-session; đổi tab giữ phiên riêng.

Output Auto = mean opposite edge lengths; Ratio = giữ diện tích gần Auto rồi ép tỷ lệ, W×H = integer canvas preflight. Swap không tráo thứ tự góc; Clear/Reset/Preview có hợp đồng ở ADR-016. Image-only output không bao gồm lưới, shading, handles hoặc checkerboard.

Miền hợp lệ là phần local source còn sau clip. `LayerGeometry.support` hỗ trợ crop lặp ngay cả khi ma trận có pole ngoài phần giữ lại. Adapter CIPerspectiveTransform vẫn dùng cho nguồn có full bounds hữu hạn; adapter CIWarpKernel Metal lấy mẫu ngược với output extent hữu hạn xử lý trường hợp còn lại. Các phép Move/resize/rotate vẫn ghép ma trận lên dữ liệu cũ; clip/source bytes giữ nguyên. ADR-017 ghi build/ROI/tolerance. Chữ/ellipse/line và mixed-layer editing chưa có renderer/bounds hoàn chỉnh: P06/P07 tích hợp, P09 lưu/mở, P10 xuất PNG/JPEG qua UI.


## Type, Shape, Color P06

`ContentOperations` kiểm tra payload và sửa nguyên tử theo lock/quota. `ContentRasterizer` đo/draw từng dòng Core Text và shape Core Graphics trên worker ảnh; `TextContent.layoutSize` nối với geometry/clip/transform dùng chung. Text/ellipse/line hiện đã render được; mô tả “chưa hỗ trợ” trong các phần P02/P05 phía trên là trạng thái lịch sử của những chặng đó.

`ContentEditing` quản lý transaction trong PhotoDocument. `NativeTextEditor` là NSTextView thật với input context/undo nhập riêng; `ContentInteraction` xử lý click/drag, async hit-test/sample có generation guard, inline/Properties routing. `ContentControlsView` chứa font/style/size/alignment/spacing/fill/stroke và editor Properties; layout thủ công co giãn trong scroll view như phần còn lại của workspace. `ColorControlsView` nhập HEX/RGB/alpha và FG/BG. X/D chỉ ở canvas responder. Nhấn đúp thumbnail layer text mở trình nhập; nhấn đúp tên vẫn đổi tên layer theo mục 7 đặc tả.

Chữ/hình giữ cùng UUID, payload typed, matrix và local clip qua thao tác hiện có. P07 là nghiệm thu mixed-layer Perspective Crop và sửa tiếp; P09/P10 mới có Save/Open/Export qua UI. P06 không thêm dependency hoặc font ngoài.

## Tích hợp Perspective nhiều layer P07

Fixture P07 kết hợp hai layer ảnh chia sẻ nguồn, chữ Việt, ellipse, rectangle ẩn và line khóa. Crop vẫn là transaction metadata: dùng chung H cho mọi layer, giữ type/payload/source/order/flags/opacity, clip local và canvas. Không thêm nhánh flatten cho text/shape. `renderDocument`, viewport, hit-test và Eyedropper dùng renderer chung; text/shape bitmap chỉ là sản phẩm tạm.

`ProjectiveTransform.isAffine` so sánh hàng mẫu số theo tỷ lệ, bất biến với hệ số đồng nhất của ma trận. Sửa chữ projective luôn tới Properties; trình sửa được cuộn vào vùng nhìn thấy ngay cả ở 1100×700 pt. Nhấn đúp shape mở Properties và focus trường kích thước, không đưa focus vào NSTextView ẩn. Text mới sau crop dùng translation và inline editor. Sửa nội dung cũ giữ matrix/clip; thay đổi kích thước không nới miền đã crop.

Renderer bắt đầu bằng canvas trong suốt hữu hạn để tài liệu không còn pixel giữ lại vẫn tạo CGImage được. Bỏ qua opacity 0 và layer có clip loại hoàn toàn trước cấp phát bitmap chữ/hình. Kiểm thử crop/Move/Undo/Redo lặp ghi ngân sách History và decoded cache, giữ asset bytes; đây là fixture nhỏ, không thay benchmark RSS/GPU/40 MP ở P12. Contract serializer chuyển sang [HOP_DONG_DU_LIEU_PAXIS.md](HOP_DONG_DU_LIEU_PAXIS.md), bao gồm phân biệt `[]` và `[[]]`. Save/Open và A20 vẫn thuộc P09; render test không phải UI Export P10.


## Điều chỉnh ảnh P08

`ImageAdjustments` trong Core giữ enabled, EV và ba giá trị phần trăm theo đơn vị UI. Setter image-only kiểm finite/range/lock trước sửa; duplicate sao chép tham số và chia sẻ asset. Geometry/crop không sửa tham số. P09 sẽ serialize nhóm này cùng source/matrix/clip theo [hợp đồng dữ liệu](HOP_DONG_DU_LIEU_PAXIS.md).

`AdjustmentEditing` dùng EditingSession để preview metadata, một commit cho mỗi lần kéo/Return; Cancel không sửa model committed. Enable bypass giữ số; Reset về 0 và bật nhóm. `AdjustmentControlsView` là NSScrollView, NSSlider và NSTextField native, chỉ hiện khi chọn image; text/shape giữ Properties riêng. Numeric dùng locale macOS, tắt action khi mất focus để Cancel không commit trước, capture input/value trước refresh. TransactionSlider xử lý down/drag/up, cell đang tracking không bị refresh ghi đè; keyboard/AX action tạo command riêng. Canvas arrows không ghép Move vào phiên adjustments.

Renderer áp Exposure → Brightness/Contrast → Saturation trong linear-sRGB, trước local clip/geometry/opacity/composite. Neutral hoặc disabled trả lại CIImage nguồn; source bytes bất biến. Ánh xạ filter cụ thể ở ADR-020, không cam kết số Photoshop. Thumbnail dùng cùng filters, key gồm nội dung và tham số; generation đổi cả khi trở về key đã cache qua Undo. Canvas giữ cancellation/generation của snapshot để completion cũ không ghi đè tab/frame mới. Decoded cache vẫn theo source ID, không decode mỗi tick.

Các ca P08 kiểm neutral/bypass bằng byte RGBA, oracle tuyến tính độc lập, alpha edge, layer khác màu đã phối cảnh, lock/duplicate/Undo và gesture 12 tick/1 Undo trong NSWindow VI/EN. Số đo render 640×480 chỉ phát hiện vấn đề ở fixture nhỏ, không thay benchmark quota P12. Xem [P08](bao-cao/P08.md).

## Preview tương tác và nghiệm thu P12

`WelcomeCanvasView` coalesce theo model/viewport/selection/handles/sampling/clip quality. Khi kéo, một pixel/point trên Retina và clip mask lấy mẫu theo viewport tránh tạo mask nguồn hàng chục MP mỗi frame. Hình học/hit-test/overlay không giảm độ chính xác; sau 150 ms yên, yêu cầu full backing resolution/full clip riêng, kể cả viewport 1×. Export, preview dự án và sample màu đi thẳng renderer đầy đủ, không lấy bitmap preview. Worker giữ snapshot/generation và không sửa dữ liệu/nguồn. Regression kiểm full pixel không đổi sau preview và viewport 1×/2× settle.

`BenchmarkTests` chỉ chạy opt-in qua scheme Release có testability; app phân phối dùng Release không testability. Worker latency, RSS/high-water, Metal allocated và cache riêng; không gọi chúng là pointer-to-present hoặc leak proof. Xem báo cáo P12 cho số liệu/giới hạn và warning.
