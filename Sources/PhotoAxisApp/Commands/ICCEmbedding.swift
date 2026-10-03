import Foundation
import CoreGraphics
import PhotoAxisCore
import zlib

/// Image I/O can optimize named sRGB to a PNG sRGB/JPEG hint. The export contract
/// requires an actual ICC payload, so embed the system's sRGB profile explicitly.
enum ICCEmbedding {
    static func attachSRGB(to data: Data, format: ExportFormat) throws -> Data {
        guard let space = CGColorSpace(name:CGColorSpace.sRGB), let raw = space.copyICCData() else { throw CocoaError(.fileWriteUnknown) }
        let profile = raw as Data
        return try format == .png ? png(data,profile:profile) : jpeg(data,profile:profile)
    }
    private static func png(_ data: Data, profile: Data) throws -> Data {
        guard data.starts(with:[137,80,78,71,13,10,26,10]) else { throw CocoaError(.fileWriteUnknown) }
        var compressed = Data(count:Int(compressBound(uLong(profile.count)))), count = uLongf(compressBound(uLong(profile.count)))
        let status = profile.withUnsafeBytes { input in compressed.withUnsafeMutableBytes { output in
            compress2(output.bindMemory(to:Bytef.self).baseAddress,&count,input.bindMemory(to:Bytef.self).baseAddress,uLong(profile.count),Z_DEFAULT_COMPRESSION)
        } }
        guard status == Z_OK else { throw CocoaError(.fileWriteUnknown) }; compressed.count = Int(count)
        var payload = Data("sRGB IEC61966-2.1".utf8); payload.append(contentsOf:[0,0]); payload.append(compressed)
        var chunk = Data(); chunk.big32(UInt32(payload.count)); let checked = Data("iCCP".utf8)+payload; chunk.append(checked)
        chunk.big32(checked.withUnsafeBytes { UInt32(crc32(0,$0.bindMemory(to:Bytef.self).baseAddress,uInt(checked.count))) })
        var result = Data(data.prefix(8)), cursor = 8, inserted = false
        while cursor+12 <= data.count {
            let length = data[cursor..<cursor+4].reduce(0) { ($0 << 8) | Int($1) }, end = cursor+12+length
            guard end <= data.count else { throw CocoaError(.fileWriteUnknown) }
            let type = String(decoding:data[cursor+4..<cursor+8],as:UTF8.self)
            if type != "iCCP" && type != "sRGB" { result.append(data.subdata(in:cursor..<end)) }
            if type == "IHDR" { guard !inserted else { throw CocoaError(.fileWriteUnknown) }; result.append(chunk); inserted = true }
            cursor = end
        }
        guard inserted, cursor == data.count else { throw CocoaError(.fileWriteUnknown) }; return result
    }
    private static func jpeg(_ data: Data, profile: Data) throws -> Data {
        guard data.starts(with:[0xff,0xd8]), profile.count <= 65_519 else { throw CocoaError(.fileWriteUnknown) }
        var segment = Data([0xff,0xe2]); segment.big16(UInt16(profile.count+16)); segment.append(Data("ICC_PROFILE\0".utf8)); segment.append(contentsOf:[1,1]); segment.append(profile)
        var result = Data([0xff,0xd8]), cursor = 2, inserted = false
        while cursor+4 <= data.count {
            guard data[cursor] == 0xff else { throw CocoaError(.fileWriteUnknown) }
            let marker = data[cursor+1]
            if !inserted && marker != 0xe0 { result.append(segment); inserted = true }
            if marker == 0xda { result.append(data.subdata(in:cursor..<data.count)); return result }
            let length = Int(data[cursor+2]) << 8 | Int(data[cursor+3]), end = cursor+2+length
            guard length >= 2, end <= data.count else { throw CocoaError(.fileWriteUnknown) }
            let isICC = marker == 0xe2 && data.subdata(in:cursor+4..<end).starts(with:Data("ICC_PROFILE\0".utf8))
            if !isICC { result.append(data.subdata(in:cursor..<end)) }
            cursor = end
        }
        throw CocoaError(.fileWriteUnknown)
    }
}

private extension Data {
    mutating func big16(_ value: UInt16) { append(UInt8(value >> 8)); append(UInt8(value & 255)) }
    mutating func big32(_ value: UInt32) { big16(UInt16(value >> 16)); big16(UInt16(value & 65535)) }
}
