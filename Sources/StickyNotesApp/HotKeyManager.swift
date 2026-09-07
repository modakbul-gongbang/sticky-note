import Carbon
import Foundation

enum HotKeyError: LocalizedError {
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            if status == eventHotKeyExistsErr {
                return "Option+`가 다른 앱에서 사용 중입니다. Raycast 설정에서 Notes 단축키를 해제한 뒤 다시 시도하세요. (OSStatus \(status))"
            }
            return "Option+` 단축키를 등록하지 못했습니다. OSStatus \(status)"
        }
    }
}

final class HotKeyManager {
    private let signature: OSType = 0x53544E54 // STNT
    private let handler: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(handler: @escaping () -> Void) {
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
                guard id.signature == manager.signature else { return OSStatus(eventNotHandledErr) }
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

        let id = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_Grave),
            UInt32(optionKey),
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else { throw HotKeyError.registrationFailed(status) }
    }
}
