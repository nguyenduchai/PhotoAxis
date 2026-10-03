import AppKit

#if DEBUG
if RecoveryCrashFixture.startIfRequested() { dispatchMain() }
#endif

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
