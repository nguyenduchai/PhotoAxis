// Read-only inventory. Never enables, disables or selects an input source.
import Foundation
import Carbon

func string(_ source: TISInputSource, _ key: CFString) -> String? {
    guard let p = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
}
func flag(_ source: TISInputSource, _ key: CFString) -> Bool {
    guard let p = TISGetInputSourceProperty(source, key) else { return false }
    return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(p).takeUnretainedValue())
}
let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
let sources = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
let rows: [[String: Any]] = sources.compactMap { source in
    guard let id = string(source, kTISPropertyInputSourceID),
          id.contains("Vietnamese") || id == "com.apple.keylayout.ABC" else { return nil }
    return ["id": id, "enabled": flag(source, kTISPropertyInputSourceIsEnabled),
            "selectable": flag(source, kTISPropertyInputSourceIsSelectCapable),
            "selected": flag(source, kTISPropertyInputSourceIsSelected)]
}
let result: [String: Any] = [
    "scope": "TIS read-only inventory; enabled flags do not prove a native NSTextInputContext can select the source. No system preference was modified.",
    "currentSource": string(current, kTISPropertyInputSourceID) ?? "unknown",
    "sources": rows
]
print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
