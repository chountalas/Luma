import Carbon
import Foundation

@MainActor
final class HotKeyManager {
    enum Action {
        case pause
        case warmer
        case cooler
        case brighter
        case dimmer
        case reset
    }

    private enum RegisteredHotKey: UInt32 {
        case pause = 1
        case warmer = 2
        case cooler = 3
        case brighter = 4
        case dimmer = 5
        case reset = 6
        case legacyPause = 7

        var action: Action {
            switch self {
            case .pause, .legacyPause:
                .pause
            case .warmer:
                .warmer
            case .cooler:
                .cooler
            case .brighter:
                .brighter
            case .dimmer:
                .dimmer
            case .reset:
                .reset
            }
        }
    }

    var handler: ((Action) -> Void)?

    private var refs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?

    func configure(enabled: Bool) {
        unregister()
        guard enabled else {
            return
        }

        installHandler()
        register(hotKey: .pause, keyCode: kVK_ANSI_L, modifiers: UInt32(optionKey | cmdKey))
        register(hotKey: .legacyPause, keyCode: kVK_ANSI_P)
        register(hotKey: .warmer, keyCode: kVK_DownArrow)
        register(hotKey: .cooler, keyCode: kVK_UpArrow)
        register(hotKey: .brighter, keyCode: kVK_PageUp)
        register(hotKey: .dimmer, keyCode: kVK_PageDown)
        register(hotKey: .reset, keyCode: kVK_Escape)
    }

    func unregister() {
        for ref in refs {
            if let ref {
                UnregisterEventHotKey(ref)
            }
        }
        refs.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                if let hotKey = RegisteredHotKey(rawValue: hotKeyID.id) {
                    Task { @MainActor in
                        manager.handler?(hotKey.action)
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )
    }

    private func register(
        hotKey: RegisteredHotKey,
        keyCode: Int,
        modifiers: UInt32 = UInt32(controlKey | optionKey)
    ) {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4C554D41), id: hotKey.rawValue)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr {
            refs.append(ref)
        }
    }
}
