import Foundation
import zlib

/// ZIP32 profile: stored/deflate, regular files, no encryption, descriptors or ZIP64.
/// Entries remain in memory; no path from the archive is ever extracted to disk.
public enum BoundedZIP {
    public static let archiveLimit = 1_073_741_824
    public static let jsonLimit = 64 * 1_024 * 1_024
    public static let previewLimit = 8 * 1_024 * 1_024
    public static let assetLimit = 512 * 1_024 * 1_024
    private struct Entry {
        let name: String
        let flags, method: UInt16
        let crc: UInt32
        let compressed, size, offset: Int
    }
    private static func limit(_ name: String) throws -> Int {
        if name == "document.json" { return jsonLimit }
        if name == "preview.png" { return previewLimit }
        if name.hasPrefix("assets/"), ProjectSchema.isSourceID(String(name.dropFirst(7))) { return assetLimit }
        throw ProjectError.invalidArchive
    }
    private static func u16(_ data: Data, _ at: Int) throws -> UInt16 {
        guard at >= 0, at + 2 <= data.count else { throw ProjectError.invalidArchive }
        return UInt16(data[at]) | UInt16(data[at+1]) << 8
    }
    private static func u32(_ data: Data, _ at: Int) throws -> UInt32 {
        UInt32(try u16(data, at)) | UInt32(try u16(data, at+2)) << 16
    }
    private static func crc(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { UInt32(crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(data.count))) }
    }
    public static func read(url: URL) throws -> [String: Data] {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let count = Int(try handle.seekToEnd())
        guard count >= 22, count <= archiveLimit else { throw ProjectError.resourceLimit }
        func read(_ offset: Int, _ length: Int) throws -> Data {
            guard offset >= 0, length >= 0, offset <= count, length <= count-offset else { throw ProjectError.invalidArchive }
            try handle.seek(toOffset: UInt64(offset))
            guard let data = try handle.read(upToCount: length), data.count == length else { throw ProjectError.invalidArchive }
            return data
        }
        let tailOffset = max(0, count - 65_557), tail = try read(tailOffset, count-tailOffset)
        var end: Int?
        for i in stride(from: tail.count-22, through: 0, by: -1) {
            if try u32(tail, i) == 0x06054b50, i+22+Int(try u16(tail,i+20)) == tail.count { end = i; break }
        }
        guard let end, try u16(tail,end+4) == 0, try u16(tail,end+6) == 0,
              try u16(tail,end+8) == u16(tail,end+10) else { throw ProjectError.invalidArchive }
        let entries = Int(try u16(tail,end+10)), centralSize = Int(try u32(tail,end+12)), centralOffset = Int(try u32(tail,end+16))
        guard (2...52).contains(entries), centralSize <= 131_072,
              centralOffset + centralSize == tailOffset + end else { throw ProjectError.invalidArchive }
        let central = try read(centralOffset, centralSize)
        var cursor = 0, total = 0, names = Set<String>(), records: [Entry] = []
        for _ in 0..<entries {
            guard try u32(central,cursor) == 0x02014b50, try u16(central,cursor+6) <= 20,
                  try u16(central,cursor+34) == 0 else { throw ProjectError.invalidArchive }
            let flags = try u16(central,cursor+8), method = try u16(central,cursor+10)
            let compressed = Int(try u32(central,cursor+20)), size = Int(try u32(central,cursor+24))
            let n = Int(try u16(central,cursor+28)), extra = Int(try u16(central,cursor+30)), comment = Int(try u16(central,cursor+32))
            let external = try u32(central,cursor+38), mode = (external >> 16) & 0xf000
            guard flags == 0 || flags == 0x800, method == 0 || method == 8,
                  mode == 0 || mode == 0x8000, external & 0x10 == 0,
                  (1...80).contains(n), cursor+46+n+extra+comment <= central.count,
                  let name = String(data: central.subdata(in: cursor+46..<cursor+46+n), encoding: .utf8),
                  names.insert(name).inserted else { throw ProjectError.invalidArchive }
            let quota = try limit(name)
            guard size <= quota, compressed <= archiveLimit, total <= archiveLimit-size else { throw ProjectError.resourceLimit }
            if method == 0 && compressed != size { throw ProjectError.invalidArchive }
            // Extra fields are outside this minimal, deterministic profile.
            guard extra == 0 else { throw ProjectError.invalidArchive }
            records.append(Entry(name: name, flags: flags, method: method, crc: try u32(central,cursor+16),
                compressed: compressed, size: size, offset: Int(try u32(central,cursor+42))))
            total += size; cursor += 46+n+extra+comment
        }
        guard cursor == central.count, names.contains("document.json"), names.contains("preview.png") else { throw ProjectError.invalidArchive }
        var nextOffset = 0
        for record in records.sorted(by: { $0.offset < $1.offset }) {
            try Task.checkCancellation()
            let header = try read(record.offset,30), n = Int(try u16(header,26)), extra = Int(try u16(header,28))
            guard record.offset == nextOffset, try u32(header,0) == 0x04034b50,
                  try u16(header,4) <= 20, try u16(header,6) == record.flags, try u16(header,8) == record.method,
                  try u32(header,14) == record.crc, Int(try u32(header,18)) == record.compressed,
                  Int(try u32(header,22)) == record.size, extra == 0,
                  n == record.name.utf8.count, try read(record.offset+30,n) == Data(record.name.utf8) else { throw ProjectError.invalidArchive }
            nextOffset = record.offset+30+n+record.compressed
            guard nextOffset <= centralOffset else { throw ProjectError.invalidArchive }
        }
        guard nextOffset == centralOffset else { throw ProjectError.invalidArchive }
        var result: [String: Data] = [:]
        // Metadata is parsed before reading or decompressing any image payload.
        for record in records.sorted(by: { $0.name == "document.json" && $1.name != "document.json" }) {
            try Task.checkCancellation()
            let packed = try read(record.offset+30+record.name.utf8.count,record.compressed)
            let data = try record.method == 0 ? packed : inflateRaw(packed, size: record.size)
            guard data.count == record.size, crc(data) == record.crc else { throw ProjectError.invalidArchive }
            if record.name == "document.json" {
                let schema = try ProjectSchema.decode(data)
                let expected = Set(schema.sources.map { "assets/"+$0.id }).union(["document.json","preview.png"])
                guard expected == names else { throw ProjectError.assetMismatch }
            }
            result[record.name] = data
        }
        return result
    }
    private static func inflateRaw(_ data: Data, size: Int) throws -> Data {
        var stream = z_stream()
        guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw ProjectError.invalidArchive }
        defer { inflateEnd(&stream) }
        var output = Data(count: size+1)
        let status = data.withUnsafeBytes { input in output.withUnsafeMutableBytes { bytes in
            stream.next_in = UnsafeMutablePointer(mutating: input.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(data.count); stream.next_out = bytes.bindMemory(to: Bytef.self).baseAddress
            stream.avail_out = uInt(size+1)
            return inflate(&stream, Z_FINISH)
        } }
        guard status == Z_STREAM_END, stream.total_out == size, stream.total_in == data.count else { throw ProjectError.invalidArchive }
        output.removeLast(); return output
    }
    /// Streams stored entries without creating a second copy of all embedded sources.
    public static func write(_ entries: [(String, Data)], sink: (Data) throws -> Void) throws {
        guard (2...52).contains(entries.count), Set(entries.map { $0.0 }).count == entries.count else { throw ProjectError.invalidArchive }
        var offset = 0, central = Data()
        func emit(_ data: Data) throws { guard offset <= archiveLimit-data.count else { throw ProjectError.resourceLimit }; try sink(data); offset += data.count }
        for (name,data) in entries {
            try Task.checkCancellation()
            guard data.count <= (try limit(name)) else { throw ProjectError.resourceLimit }
            let n = Data(name.utf8), checksum = crc(data), localOffset = offset
            var header = Data()
            header.put32(0x04034b50); header.put16(20); header.put16(0x800); header.put16(0)
            header.put16(0); header.put16(0x21); header.put32(checksum); header.put32(UInt32(data.count)); header.put32(UInt32(data.count))
            header.put16(UInt16(n.count)); header.put16(0); header.append(n); try emit(header)
            for start in stride(from: 0, to: data.count, by: 1_048_576) {
                try Task.checkCancellation(); try emit(data.subdata(in: start..<min(data.count,start+1_048_576)))
            }
            central.put32(0x02014b50); central.put16(20); central.put16(20); central.put16(0x800); central.put16(0)
            central.put16(0); central.put16(0x21); central.put32(checksum); central.put32(UInt32(data.count)); central.put32(UInt32(data.count))
            central.put16(UInt16(n.count)); central.put16(0); central.put16(0); central.put16(0); central.put16(0); central.put32(0); central.put32(UInt32(localOffset)); central.append(n)
        }
        let centralOffset = offset; try emit(central)
        var end = Data(); end.put32(0x06054b50); end.put16(0); end.put16(0); end.put16(UInt16(entries.count)); end.put16(UInt16(entries.count))
        end.put32(UInt32(central.count)); end.put32(UInt32(centralOffset)); end.put16(0); try emit(end)
    }
}

private extension Data {
    mutating func put16(_ n: UInt16) { append(UInt8(n & 255)); append(UInt8(n >> 8)) }
    mutating func put32(_ n: UInt32) { put16(UInt16(n & 65535)); put16(UInt16(n >> 16)) }
}
