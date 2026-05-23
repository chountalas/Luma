import SwiftUI

@main
struct LumaGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var preferences = PreferencesStore()
    @StateObject private var displayController = DisplayController()
    private let hotKeyManager = HotKeyManager()
    @State private var servicesWired = false

    init() {
        NotificationCenter.default.addObserver(
            forName: .lumaGuardWillTerminate,
            object: nil,
            queue: .main
        ) { _ in
            CGDisplayRestoreColorSyncSettings()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(preferences)
                .environmentObject(displayController)
                .onAppear {
                    wireServices()
                }
        } label: {
            Image(systemName: displayController.runtime.isPaused ? "moon.zzz.fill" : "leaf.circle.fill")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)

        Window("LumaGuard", id: "settings") {
            SettingsView()
                .environmentObject(preferences)
                .environmentObject(displayController)
                .frame(minWidth: 680, minHeight: 560)
                .onAppear {
                    wireServices()
                }
        }
        .defaultSize(width: 720, height: 620)
    }

    @MainActor
    private func wireServices() {
        guard !servicesWired, !isRunningTests else {
            return
        }
        servicesWired = true

        preferences.onChange = { settings in
            displayController.update(settings: settings)
            hotKeyManager.configure(enabled: settings.hotkeys.enabled)
        }

        hotKeyManager.handler = { action in
            switch action {
            case .pause:
                displayController.togglePaused()
            case .warmer:
                preferences.nudgeCurrentKelvin(by: -500)
            case .cooler:
                preferences.nudgeCurrentKelvin(by: 500)
            case .brighter:
                preferences.nudgeCurrentBrightness(by: 10)
            case .dimmer:
                preferences.nudgeCurrentBrightness(by: -10)
            case .reset:
                displayController.setPaused(true)
                displayController.resetDisplay()
            }
        }

        hotKeyManager.configure(enabled: preferences.settings.hotkeys.enabled)
        displayController.start(settings: preferences.settings)
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
