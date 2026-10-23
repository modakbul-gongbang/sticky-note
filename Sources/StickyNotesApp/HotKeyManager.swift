import Carbon
import Foundation

struct HotKey {
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32
    let displayName: String
    /// What to free when another app already owns the combination.
    let conflictHint: String

    static let togglePanel = HotKey(
        id: 1,
        keyCode: UInt32(kVK_ANSI_Grave),
        modifiers: UInt32(optionKey),
        displayName: "Option+`",
        conflictHint: "Raycast 설정에서 Notes 단축키를 해제한 뒤 다시 시도하세요."
    )
    static let openToday = HotKey(
        id: 2,
        keyCode: UInt32(kVK_ANSI_Grave),
        modifiers: UInt32(optionKey | shiftKey),
        displayName: "Option+Shift+`",
        conflictHint: "같은 단축키를 쓰는 앱에서 해제한 뒤 다시 시도하세요."
    )
}

enum HotKeyError: LocalizedError {
    case registrationFailed(HotKey, OSStatus)

    var errorDescription: String? {
        switch self {
        case let .registrationFailed(hotKey, status):
            if status == eventHotKeyExistsErr {
                return "\(hotKey.displayName)가 다른 앱에서 사용 중입니다. \(hotKey.conflictHint) (OSStatus \(status))"
            }
            return "\(hotKey.displayName) 단축키를 등록하지 못했습니다. OSStatus \(status)"
        }
    }
}

/// One manager owns one registered combination. Each installs its own application handler and
/// passes on presses that carry another manager's id, so several shortcuts can coexist.
final class HotKeyManager {
    private let signature: OSType = 0x53544E54 // STNT
    private let hotKey: HotKey
    private let handler: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(hotKey: HotKey, handler: @escaping () -> Void) {
        self.hotKey = hotKey
        self.handler = handler
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    func register() throws {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if handlerRef == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let callback: EventHandlerUPP = { _, event, pointer in
                guard let event, let pointer else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &id
                )
                guard status == noErr else { return status }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(pointer).takeUnretainedValue()
                guard id.signature == manager.signature, id.id == manager.hotKey.id else {
                    return OSStatus(eventNotHandledErr)
                }
                DispatchQueue.main.async { manager.handler() }
                return noErr
            }
            InstallEventHandler(
                GetApplicationEventTarget(),
                callback,
                1,
                &eventType,
                Unmanaged.passUnretained(self).toOpaque(),
                &handlerRef
            )
        }

        let id = EventHotKeyID(signature: signature, id: hotKey.id)
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else { throw HotKeyError.registrationFailed(hotKey, status) }
    }
}
