# Tools

P01 có `ToolKind` với định danh không phụ thuộc ngôn ngữ, phím tắt và icon vector AppKit tự vẽ. Toolbar/flyout/tooltip nằm trong NativeWorkspace. Chưa có backend sửa tài liệu.

Phiên input/crop/transform/text tách khỏi model, triển khai theo P03–P08. Apply hợp lệ mới phát command; Cancel giữ snapshot cũ. Hợp đồng: [KIEN_TRUC.md](../../../docs/KIEN_TRUC.md).
