import AppKit
import Carbon
import CoreGraphics

struct PasteboardSnapshot {
    let items: [NSPasteboardItem]

    init(pasteboard: NSPasteboard) {
        items = pasteboard.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                } else if let string = item.string(forType: type) {
                    copy.setString(string, forType: type)
                }
            }
            return copy
        } ?? []
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}

final class TextInjector {
    func inject(_ text: String, completion: (() -> Void)? = nil) {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        let originalInputSource = InputSourceManager.currentInputSource()
        let shouldSwitchInputSource = originalInputSource.map(InputSourceManager.isCJKInputSource) ?? false

        if shouldSwitchInputSource {
            InputSourceManager.selectASCIICapableInputSource()
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Self.sendCommandV()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if shouldSwitchInputSource, let originalInputSource {
                    InputSourceManager.select(originalInputSource)
                }
                snapshot.restore(to: pasteboard)
                completion?()
            }
        }
    }

    private static func sendCommandV() {
        let keyCodeForV: CGKeyCode = 9
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

enum InputSourceManager {
    static func currentInputSource() -> TISInputSource? {
        TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
    }

    static func select(_ inputSource: TISInputSource) {
        TISSelectInputSource(inputSource)
    }

    static func selectASCIICapableInputSource() {
        if let ascii = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue() {
            TISSelectInputSource(ascii)
            return
        }
        if let ascii = TISCopyCurrentASCIICapableKeyboardInputSource()?.takeRetainedValue() {
            TISSelectInputSource(ascii)
        }
    }

    static func isCJKInputSource(_ inputSource: TISInputSource) -> Bool {
        let sourceID = stringProperty(inputSource, key: kTISPropertyInputSourceID) ?? ""
        if sourceID.localizedCaseInsensitiveContains("chinese")
            || sourceID.localizedCaseInsensitiveContains("pinyin")
            || sourceID.localizedCaseInsensitiveContains("shuangpin")
            || sourceID.localizedCaseInsensitiveContains("wubi")
            || sourceID.localizedCaseInsensitiveContains("kotoeri")
            || sourceID.localizedCaseInsensitiveContains("japanese")
            || sourceID.localizedCaseInsensitiveContains("korean")
            || sourceID.localizedCaseInsensitiveContains("hangul")
        {
            return true
        }

        for language in languages(inputSource) {
            let normalized = language.lowercased()
            if normalized.hasPrefix("zh") || normalized.hasPrefix("ja") || normalized.hasPrefix("ko") {
                return true
            }
        }

        return false
    }

    private static func stringProperty(_ inputSource: TISInputSource, key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(inputSource, key) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private static func languages(_ inputSource: TISInputSource) -> [String] {
        guard let pointer = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceLanguages) else {
            return []
        }
        let languages = Unmanaged<CFArray>.fromOpaque(pointer).takeUnretainedValue() as? [String]
        return languages ?? []
    }
}
