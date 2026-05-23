import Carbon
import Foundation

@MainActor
final class HotKeyManager {
    enum Action: UInt32, CaseIterable {
        case pause = 1
        case warmer = 2
        case cooler = 3
        case brighter = 4
        case dimmer = 5
        case reset = 6
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
        register(action: .pause, keyCode: kVK_ANSI_P)
        register(action: .warmer, keyCode: kVK_DownArrow)
        register(action: .cooler, keyCode: kVK_UpArrow)
        register(action: .brighter, keyCode: kVK_PageUp)
        register(action: .dimmer, keyCode: kVK_PageDown)
        register(action: .reset, keyCode: kVK_Escape)
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
                if let action = Action(rawValue: hotKeyID.id) {
                    Task { @MainActor in
                        manager.handler?(action)
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

    private func register(action: Action, keyCode: Int) {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4C554D41), id: action.rawValue)
        var ref: EventHotKeyRef?
        let modifiers = UInt32(controlKey | optionKey)
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
