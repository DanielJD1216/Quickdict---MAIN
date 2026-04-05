import AppKit

let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

if !isRunningTests {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
