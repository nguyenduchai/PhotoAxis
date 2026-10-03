#if DEBUG
import Foundation
import Darwin

/// Noninteractive, debug-only child process for A29. It exits abnormally only
/// after the real recovery manifest has committed. Never targets the user's app.
enum RecoveryCrashFixture {
    static func startIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard ProcessInfo.processInfo.environment["PHOTOAXIS_QA_MODE"] == "1", args.count == 4,
              args[1] == "--photoaxis-recovery-crash-fixture" else { return false }
        let root = URL(fileURLWithPath:args[2]), source = URL(fileURLWithPath:args[3])
        guard root.lastPathComponent.hasPrefix(".qa-recovery-") else { _exit(87) }
        Task.detached {
            do {
                let pipeline = ImagePipeline(), store = RecoveryStore(root:root,pipeline:pipeline)
                let snapshot = try await store.projects.open(source)
                guard try await store.write(snapshot) else { _exit(87) }
                _exit(86)
            } catch { _exit(87) }
        }
        return true
    }
}
#endif
