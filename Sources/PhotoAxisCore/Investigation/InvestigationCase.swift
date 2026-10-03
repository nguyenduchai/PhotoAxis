import Foundation
import CryptoKit

public enum InvestigationError: Error, Equatable {
    case invalidCase, limit, integrity, locked, protectedDestination, auditUnavailable, staleRedactions, missingCase, ocrUnavailable, ocrBusy, videoUnavailable, staleCalibration
    public var localizationKey: String { "investigation.error." + String(describing: self) }
}

public struct InvestigationReference: Codable, Equatable, Sendable {
    public let caseID, itemID: UUID
    public init(caseID: UUID, itemID: UUID) { self.caseID = caseID; self.itemID = itemID }
}

public struct EvidenceIntake: Codable, Equatable, Sendable {
    public var source: String
    public var provider: String
    public var receiver: String
    /// User-supplied receipt time, distinct from the machine's import timestamp.
    public var receivedAt: String
    public var handover: String
    public init(source: String = "", provider: String = "", receiver: String = "", receivedAt: String = "", handover: String = "") {
        self.source = source; self.provider = provider; self.receiver = receiver
        self.receivedAt = receivedAt; self.handover = handover
    }
    public func validate() throws {
        guard [source, provider, receiver, receivedAt, handover].allSatisfy({ $0.utf8.count <= 4096 }) else { throw InvestigationError.limit }
    }
}

/// Coordinates are top-left pixels of the committed working canvas, never a UI zoom.
public struct EvidenceRegion: Codable, Equatable, Sendable {
    public var x, y, width, height: Int
    public init(x: Int, y: Int, width: Int, height: Int) { self.x = x; self.y = y; self.width = width; self.height = height }
    public func validate(in canvas: CanvasSize) throws {
        guard x >= 0, y >= 0, width > 0, height > 0, x <= canvas.width, y <= canvas.height,
              width <= canvas.width - x, height <= canvas.height - y else { throw InvestigationError.invalidCase }
    }
}

public struct EvidenceItem: Codable, Sendable {
    public let id: UUID
    public let number: Int
    public var caption: String
    public var intake: EvidenceIntake
    public let importedAt: String
    public let originalName: String
    public let originalSHA256: String
    public let originalByteCount: Int
    public let originalMetadataJSON: String
    public let workingSourceSHA256: String
    public var currentModelJSON: Data
    public var savedModelJSON: Data
    public var workingFileSHA256: String
    /// Retains the intake's normalized pixels even after Delete → Save → Undo.
    public var intakeWorkingFileSHA256: String?
    public var redactions: [EvidenceRegion] = []
    public var redactionModelSHA256: String?
    public init(id: UUID, number: Int, caption: String, intake: EvidenceIntake, importedAt: String,
                originalName: String, originalSHA256: String, originalByteCount: Int, originalMetadataJSON: String,
                workingSourceSHA256: String, modelJSON: Data, workingFileSHA256: String) {
        self.id = id; self.number = number; self.caption = caption; self.intake = intake; self.importedAt = importedAt
        self.originalName = originalName; self.originalSHA256 = originalSHA256; self.originalByteCount = originalByteCount
        self.originalMetadataJSON = originalMetadataJSON; self.workingSourceSHA256 = workingSourceSHA256
        currentModelJSON = modelJSON; savedModelJSON = modelJSON; self.workingFileSHA256 = workingFileSHA256
        intakeWorkingFileSHA256 = workingFileSHA256
    }
    public var code: String { String(format: "IMG-%04d", number) }
    public var model: PhotoDocumentModel { get throws { try ProjectSchema.decode(currentModelJSON).model() } }
    public var hasUnsavedChanges: Bool { currentModelJSON != savedModelJSON }
    public func validate(caseID: UUID) throws {
        try intake.validate()
        guard (1...100).contains(number), caption.utf8.count <= 4096, originalName.utf8.count <= 4096,
              importedAt.utf8.count <= 128, originalByteCount > 0, originalByteCount <= InvestigationCase.maximumOriginalBytes,
              originalMetadataJSON.utf8.count <= 262_144,
              [originalSHA256, workingSourceSHA256, workingFileSHA256].allSatisfy(ProjectSchema.isSourceID),
              redactions.count <= 100 else { throw InvestigationError.invalidCase }
        let current = try model, saved = try ProjectSchema.decode(savedModelJSON).model()
        if let intakeWorkingFileSHA256 { guard ProjectSchema.isSourceID(intakeWorkingFileSHA256) else { throw InvestigationError.invalidCase } }
        let reference = InvestigationReference(caseID: caseID, itemID: id)
        guard current.id == id, saved.id == id, current.investigation == reference, saved.investigation == reference else { throw InvestigationError.invalidCase }
        if let redactionModelSHA256 { guard ProjectSchema.isSourceID(redactionModelSHA256) else { throw InvestigationError.invalidCase } }
        // Stale regions remain recorded, but cannot be exported until explicitly reviewed.
        if redactionModelSHA256 == InvestigationDigest.hash(currentModelJSON) { for region in redactions { try region.validate(in: current.canvas) } }
    }
}

public enum InvestigationDigest {
    public static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    public static func timestamp() -> String { ISO8601DateFormatter().string(from: Date()) }
}

/// A hash-linked local processing record. This is not a signature, a trusted clock,
/// proof of provenance, or a complete chain of custody.
public struct InvestigationEvent: Codable, Sendable {
    public struct Payload: Codable, Sendable {
        public let sequence: Int
        public let id: UUID
        public let recordedAt, appVersion, operation, operatorName, previousSHA256: String
        public let itemID: UUID?
        public let details: [String: String]
        public let modelAfterJSON: Data?
    }
    public let payload: Payload
    public let sha256: String
    public init(sequence: Int, previousSHA256: String, operation: String, operatorName: String,
                itemID: UUID?, details: [String: String], modelAfterJSON: Data?, appVersion: String) throws {
        payload = Payload(sequence: sequence, id: UUID(), recordedAt: InvestigationDigest.timestamp(),
                          appVersion: appVersion, operation: operation, operatorName: operatorName,
                          previousSHA256: previousSHA256, itemID: itemID, details: details, modelAfterJSON: modelAfterJSON)
        sha256 = InvestigationDigest.hash(try InvestigationDigest.encode(payload))
    }
}

public struct InvestigationCase: Codable, Sendable {
    public static let maximumOriginalBytes = 536_870_912
    public static let maximumManifestBytes = 33_554_432
    public var formatIdentifier = "photoaxis.investigation"
    public var formatVersion = 1
    public let id: UUID
    public var code, title, examiner: String
    public let createdAt: String
    public var items: [EvidenceItem] = []
    public var events: [InvestigationEvent] = []
    public var analysis: InvestigationAnalysis?
    public init(code: String, title: String, examiner: String) {
        id = UUID(); self.code = code; self.title = title; self.examiner = examiner; createdAt = InvestigationDigest.timestamp()
    }
    public mutating func record(operation: String, itemID: UUID? = nil, details: [String: String] = [:],
                                modelAfterJSON: Data? = nil, appVersion: String) throws {
        guard events.count < 10_000 else { throw InvestigationError.limit }
        var recordedDetails = details; recordedDetails["caseStateSHA256"] = try stateDigest()
        let event = try InvestigationEvent(sequence: events.count + 1, previousSHA256: events.last?.sha256 ?? String(repeating: "0", count: 64),
                                          operation: operation, operatorName: examiner, itemID: itemID, details: recordedDetails,
                                          modelAfterJSON: modelAfterJSON, appVersion: appVersion)
        events.append(event)
    }
    public func validate() throws {
        guard formatIdentifier == "photoaxis.investigation", (formatVersion == 1 || formatVersion == 2),
              (analysis == nil || formatVersion == 2),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              [code, title, examiner].allSatisfy({ $0.utf8.count <= 4096 }), createdAt.utf8.count <= 128,
              items.count <= 100, items.allSatisfy({ $0.originalByteCount > 0 && $0.originalByteCount <= Self.maximumOriginalBytes }),
              items.reduce(Int64(0), { $0 + Int64($1.originalByteCount) }) <= 10_737_418_240,
              events.count <= 10_000, !events.isEmpty,
              Set(items.map(\.id)).count == items.count, Set(items.map(\.number)).count == items.count else { throw InvestigationError.invalidCase }
        for item in items { try item.validate(caseID: id) }
        if let analysis {
            try analysis.validate(items: items)
            guard items.reduce(Int64(0), { $0 + Int64($1.originalByteCount) }) + analysis.videos.reduce(Int64(0), { $0 + Int64($1.byteCount) }) <= 10_737_418_240 else { throw InvestigationError.limit }
        }
        var previous = String(repeating: "0", count: 64), latest: [UUID: Data] = [:]
        var eventIDs = Set<UUID>()
        for (index, event) in events.enumerated() {
            let p = event.payload
            guard p.sequence == index + 1, p.previousSHA256 == previous, eventIDs.insert(p.id).inserted,
                  p.operation.utf8.count <= 128, p.recordedAt.utf8.count <= 128, p.appVersion.utf8.count <= 128,
                  p.operatorName.utf8.count <= 4096, p.details.count <= 64,
                  p.details.allSatisfy({ $0.key.utf8.count <= 256 && $0.value.utf8.count <= 262_144 }),
                  event.sha256 == InvestigationDigest.hash(try InvestigationDigest.encode(p)) else { throw InvestigationError.integrity }
            if let itemID = p.itemID {
                guard items.contains(where: { $0.id == itemID }) else { throw InvestigationError.invalidCase }
                if let model = p.modelAfterJSON {
                    let state = try ProjectSchema.decode(model).model()
                    guard state.id == itemID, state.investigation == InvestigationReference(caseID: id, itemID: itemID) else { throw InvestigationError.integrity }
                    latest[itemID] = model
                }
            } else if p.modelAfterJSON != nil { throw InvestigationError.invalidCase }
            previous = event.sha256
        }
        for item in items { guard latest[item.id] == item.currentModelJSON else { throw InvestigationError.integrity } }
        guard events.last?.payload.details["caseStateSHA256"] == (try stateDigest()) else { throw InvestigationError.integrity }
    }
    private func stateDigest() throws -> String {
        struct State: Encodable { let id: UUID; let code, title, examiner, createdAt: String; let items: [EvidenceItem]; let analysis: InvestigationAnalysis? }
        return InvestigationDigest.hash(try InvestigationDigest.encode(State(id: id, code: code, title: title, examiner: examiner, createdAt: createdAt, items: items, analysis: analysis)))
    }
    public func encoded() throws -> Data {
        try validate(); let data = try InvestigationDigest.encode(self)
        guard data.count <= Self.maximumManifestBytes else { throw InvestigationError.limit }; return data
    }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= maximumManifestBytes else { throw InvestigationError.limit }
        try validateEnvelope(data)
        let value = try JSONDecoder().decode(Self.self, from: data); try value.validate(); return value
    }
    private static func validateEnvelope(_ data: Data) throws {
        var depth = 0, quoted = false, escaped = false, start = 0
        var token: Range<Int>?, keys: [Set<String>?] = []
        for (index, byte) in data.enumerated() {
            if quoted {
                if escaped { escaped = false } else if byte == 92 { escaped = true }
                else if byte == 34 { quoted = false; token = start..<index + 1 }
            } else if byte == 34 { quoted = true; start = index; token = nil }
            else if byte == 91 || byte == 123 {
                depth += 1; guard depth <= 24 else { throw InvestigationError.limit }
                keys.append(byte == 123 ? Set<String>() : nil); token = nil
            } else if byte == 93 || byte == 125 {
                guard depth > 0, (byte == 125) == (keys.last! != nil) else { throw InvestigationError.invalidCase }
                depth -= 1; keys.removeLast(); token = nil
            } else if byte == 58 {
                guard let range = token, range.count <= 4096, !keys.isEmpty, var names = keys[keys.count - 1] else { throw InvestigationError.invalidCase }
                let key = try JSONDecoder().decode(String.self, from: data.subdata(in: range))
                guard names.insert(key).inserted, names.count <= 128 else { throw InvestigationError.invalidCase }
                keys[keys.count - 1] = names; token = nil
            } else if ![9, 10, 13, 32].contains(byte) { token = nil }
        }
        guard depth == 0, !quoted else { throw InvestigationError.invalidCase }
    }
}
