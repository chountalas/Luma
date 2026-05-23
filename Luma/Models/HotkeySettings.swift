import Foundation

struct HotkeySettings: Codable, Equatable {
    var enabled = true

    static let `default` = HotkeySettings()
}

