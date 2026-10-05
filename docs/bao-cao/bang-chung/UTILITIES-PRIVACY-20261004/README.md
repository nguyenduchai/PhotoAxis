# Bằng chứng build10, 04–05/10/2026

Release UUID F06440F4-1139-3943-ABB3-CB217C673086, VIEN QA copies khớp UUID/Core. Native screenshots: VI previewcover/blur/pixelate; chốt2vùng/Undo/Redo/Save kiểm trên Release, không có hồ sơ điều tra. Máy khóa ở bước native Export; chưa kiểm từ giao diện OCR/Bảngảnh/Export/ENreopen. Không suy chứng nhận native toàn bộ từ hosted tests.

Native project audit: schema1,3layers,2lockedcovers,exactsourcebytes,không investigationref. Hosted-export-test: đọc chính project native đã lưu, dùng renderer/pipeline tạo PNG/A4PDF; đây không phải thao tác qua hộp thoại export. Independent-output-audit: Pillow/numpy/pypdf/Poppler đối chiếu93914coveredopaque/930086outsideidentical,PDFsinglebitmapA4/no selectabletext/noattachments. PDF/PNG là fixture tổng hợp, không có dữ liệu cá nhân.

Full final suite:227total223PASS/1knownsyntheticTelexFAIL/3opt-inbenchmarkSKIP;17newPASS. Release/policy16/inventory/localization644keys527refs/site12pagesPASS. Các log trước sửa PDFclose/parent-symlink và bước kiểm metadata quá chặt không được nhận là PASS; chỉ log cuối trong thư mục này dùng làm nghiệm thu. Warning MDB_MAP_FULL/MetalQoS vẫn ghi rõ trong Known Issues. Source/config fingerprint includes final Tests; compiled product sources unchanged after3dc0fe3, final source+testcommit5d89d7a.

Pages proof trongGit thuộcb9f5956. Sau chỉnhwebsitecopyđồngbộ227/223 vàtài liệu, proofdeployedHEADcuối lưu ngoàiGit cùngDeliverables/2026-10-05-build10-utilities-privacy/pages-final-proof. Compiledsourcesfingerprint trongbuildmanifestthuộc5d89d7a; helperwebsitecopy đổi saucompile, khôngđổiSources/Tests/Config/project hoặcUUID/Core/executable.
