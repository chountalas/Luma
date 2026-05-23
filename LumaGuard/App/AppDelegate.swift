import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.post(name: .lumaGuardWillTerminate, object: nil)
    }
}

extension Notification.Name {
    static let lumaGuardWillTerminate = Notification.Name("LumaGuardWillTerminate")
}

