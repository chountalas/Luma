import SwiftUI

@main
struct LumaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var preferences = PreferencesStore()
    @StateObject private var displayController = DisplayController()
    @State private var servicesWired = false

    init() {
        NotificationCenter.default.addObserver(
            forName: .lumaWillTerminate,
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
            Image(systemName: displayController.runtime.isPaused ? "moon.zzz.fill" : "sun.max.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .onAppear {
                    wireServices()
                }
        }
        .menuBarExtraStyle(.window)

        Window("Luma", id: "settings") {
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
        }

        displayController.start(settings: preferences.settings)
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
