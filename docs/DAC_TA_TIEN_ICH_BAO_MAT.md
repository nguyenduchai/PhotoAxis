# Tiện ích tài liệu và bảo mật 1 — thay đổi phạm vi build10

Yêu cầu trực tiếp mới của chủ dự án ngày04/10/2026 thay thế phạm vi Investigation1/2 trong sản phẩm: chỉ giữ OCR tiếng Việt và lập bảng ảnh; bổ sung làm mờ/che. Baseline editor1.0-draft.3, Scan1, Paint1, Preferences và native cursor giữ nguyên.

- U01: giao diện chung Chỉnh sửa/OCR/Bảng ảnh/Làm mờ-che; không controller hồ sơ trong AppDelegate, không menu/form điều tra.
- U02: OCR Vision accurate revision3 chỉ ngôn ngữ `vi-*` được runtime hỗ trợ, current committed canvas hoặc ROI; editable text/copy/TXT, cancel và chặn kết quả muộn/đổi context. Không audit/receipt hoặc biến đổi ảnh.
- U03: bảng ảnh current snapshot/multifile, reorder/caption/title/note,1/2/4/6perA4,orientation, optional filenames off, automatic preview/page selection. RasterPDFallpages300PPI/PNGcurrent300PPI, fittedaspectnocrop, bound100photos/4MP/16MiBeach/128MiBtotal/256MiBPDF. Rejectcliptext. DraftRAMonly.
- U04: manual rectangular ROI up to20, black cover/CI Gaussian blur/pixelation, strengthlive preview, opaque raster patches, optional offline Vision face bounding boxes with padding and manual review. One commit/Undo; locked ordinary shape/image layers, asset byte preservation, all-or-nothing validation of layer/source quota. No automatic identity recognition.
- U05: compatibility reader1–4 unchanged, no newschema; managed legacy projects detach reference into dirty unsaved ordinary copy, protected destination checks nearest existing symlink ancestor. Oldcase format/backend/tests remain dormant for compatibility; no newcase lifecycle or edits to archive originals.
- U06: VIEN/accessibility, contextual cursor, scrollable panel at minimumwidth260, cancellation/context invalidation before commit, off-main render/export and atomic writes.

Guide: [Sử dụng](HUONG_DAN_OCR_BANG_ANH_BAO_MAT.md). Qualification riêng OCRcold/targets, face positive real fixtures, privacy at fullquota/input-to-present latency,100photo/256MiB boundary and baseline release gates remain subject to evidence; implementation alone is not public installer acceptance.
