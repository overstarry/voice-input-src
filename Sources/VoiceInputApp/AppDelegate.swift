import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences.shared
    private let fnKeyMonitor = FnKeyMonitor()
    private let speechRecorder = SpeechRecorder()
    private let floatingPanel = FloatingPanelController()
    private let textInjector = TextInjector()

    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private var isHandlingRelease = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupCallbacks()
        fnKeyMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        fnKeyMonitor.stop()
        speechRecorder.stopImmediately()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoiceInput")
        item.button?.imagePosition = .imageOnly
        statusItem = item
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let languageMenu = NSMenu()
        for language in SupportedLanguage.allCases {
            let item = NSMenuItem(title: language.title, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            item.state = preferences.selectedLanguage == language ? .on : .off
            languageMenu.addItem(item)
        }
        let languageItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        let llmMenu = NSMenu()
        let configuration = preferences.llmConfiguration
        let toggleItem = NSMenuItem(title: "Enabled", action: #selector(toggleLLM), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = configuration.enabled ? .on : .off
        llmMenu.addItem(toggleItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        llmMenu.addItem(settingsItem)

        let llmItem = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        llmItem.submenu = llmMenu
        menu.addItem(llmItem)

        menu.addItem(.separator())

        let permissionItem = NSMenuItem(title: "Request Keyboard Permission", action: #selector(requestKeyboardPermission), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit VoiceInput", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func setupCallbacks() {
        fnKeyMonitor.onPress = { [weak self] in
            self?.handleFnPress()
        }
        fnKeyMonitor.onRelease = { [weak self] in
            self?.handleFnRelease()
        }
        fnKeyMonitor.onPermissionIssue = { [weak self] in
            self?.showStatusMessage("Grant Accessibility permission, then restart VoiceInput.")
        }

        speechRecorder.onPartialText = { [weak self] text in
            self?.floatingPanel.update(text: text)
        }
        speechRecorder.onRMS = { [weak self] rms in
            self?.floatingPanel.updateRMS(rms)
        }
        speechRecorder.onError = { [weak self] message in
            self?.showStatusMessage(message)
        }
    }

    private func handleFnPress() {
        guard !speechRecorder.isRecording, !isHandlingRelease else {
            return
        }

        speechRecorder.ensurePermissions { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case .success:
                do {
                    try self.speechRecorder.start(language: self.preferences.selectedLanguage)
                    self.floatingPanel.show(text: "")
                } catch {
                    self.showStatusMessage(error.localizedDescription)
                }
            case let .failure(error):
                self.showStatusMessage(error.localizedDescription)
            }
        }
    }

    private func handleFnRelease() {
        guard speechRecorder.isRecording else {
            return
        }

        isHandlingRelease = true
        speechRecorder.stop { [weak self] text in
            self?.handleRecognizedText(text)
        }
    }

    private func handleRecognizedText(_ text: String) {
        let rawText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else {
            isHandlingRelease = false
            floatingPanel.hide()
            return
        }

        let configuration = preferences.llmConfiguration
        if configuration.enabled && configuration.isComplete {
            floatingPanel.setStatus("Refining...")
            Task { @MainActor in
                let finalText: String
                do {
                    finalText = try await LLMClient(configuration: configuration).refine(rawText)
                } catch {
                    finalText = rawText
                }
                injectAndFinish(finalText)
            }
        } else {
            injectAndFinish(rawText)
        }
    }

    private func injectAndFinish(_ text: String) {
        floatingPanel.update(text: text)
        textInjector.inject(text) { [weak self] in
            self?.isHandlingRelease = false
            self?.floatingPanel.hide()
        }
    }

    private func showStatusMessage(_ message: String) {
        floatingPanel.show(text: message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.floatingPanel.hide()
        }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let language = SupportedLanguage(rawValue: rawValue)
        else {
            return
        }
        preferences.selectedLanguage = language
        rebuildMenu()
    }

    @objc private func toggleLLM() {
        var configuration = preferences.llmConfiguration
        configuration.enabled.toggle()
        preferences.llmConfiguration = configuration
        rebuildMenu()
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
    }

    @objc private func requestKeyboardPermission() {
        fnKeyMonitor.start()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
