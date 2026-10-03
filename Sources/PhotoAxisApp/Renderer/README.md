# Renderer P02

ImagePipeline actor nối Image I/O/Core Image: metadata/quota trước decode, byte nhúng sở hữu riêng, EXIF/sRGB/SDR, LRU decoded cache 256 MiB, compose snapshot và evaluate viewport ngoài MainActor. Nguồn/layer/transform không bị thay bằng composite.

MetalPresentationView dùng MTKView, CIContext/MTLCommandBuffer trình bày frame hoàn tất. Canvas hủy task và kiểm tra document ID/revision/generation; overlay lấy viewport của frame nhận được. Clip đa giác, text và shape ngoài rectangle còn ở P04/P06; renderer từ chối payload chưa hỗ trợ, không âm thầm bỏ clip hoặc flatten.

Hợp đồng: [KIEN_TRUC.md](../../../docs/KIEN_TRUC.md). Bằng chứng: [P02](../../../docs/bao-cao/P02.md).
