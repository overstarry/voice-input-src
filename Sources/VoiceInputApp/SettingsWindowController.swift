import AppKit

final class SettingsWindowController: NSWindowController {
    private let apiBaseURLField = NSTextField()
    private let apiKeyField = NSSecureTextField()
    private let modelField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "")

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 230),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LLM Refinement Settings"
        window.center()
        self.init(window: window)
        buildUI()
        loadConfiguration()
    }

    override func showWindow(_ sender: Any?) {
        loadConfiguration()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let contentView = window?.contentView else {
            return
        }

        let grid = NSGridView(views: [
            [label("API Base URL"), apiBaseURLField],
            [label("API Key"), apiKeyField],
            [label("Model"), modelField]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).width = 320

        apiBaseURLField.placeholderString = "https://api.openai.com/v1"
        modelField.placeholderString = "gpt-4o-mini"
        apiKeyField.placeholderString = "sk-..."

        let testButton = NSButton(title: "Test", target: self, action: #selector(testConfiguration))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveConfiguration))
        saveButton.keyEquivalent = "\r"

        let buttonStack = NSStackView(views: [testButton, saveButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .centerY
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(grid)
        contentView.addSubview(buttonStack)
        contentView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            grid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            grid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            statusLabel.leadingAnchor.constraint(equalTo: grid.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: grid.trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 18),

            buttonStack.trailingAnchor.constraint(equalTo: grid.trailingAnchor),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    private func loadConfiguration() {
        let configuration = Preferences.shared.llmConfiguration
        apiBaseURLField.stringValue = configuration.apiBaseURL
        apiKeyField.stringValue = configuration.apiKey
        modelField.stringValue = configuration.model
        statusLabel.stringValue = ""
    }

    @objc private func saveConfiguration() {
        var configuration = Preferences.shared.llmConfiguration
        configuration.apiBaseURL = apiBaseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        configuration.apiKey = apiKeyField.stringValue
        configuration.model = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        Preferences.shared.llmConfiguration = configuration
        statusLabel.stringValue = "Saved."
    }

    @objc private func testConfiguration() {
        saveConfiguration()
        let configuration = Preferences.shared.llmConfiguration
        guard configuration.isComplete else {
            statusLabel.stringValue = "API Base URL, API Key, and Model are required for testing."
            return
        }

        statusLabel.stringValue = "Testing..."
        Task { @MainActor in
            do {
                let result = try await LLMClient(configuration: configuration).test()
                statusLabel.stringValue = "Test succeeded: \(result)"
            } catch {
                statusLabel.stringValue = "Test failed: \(error.localizedDescription)"
            }
        }
    }

    private func label(_ string: String) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.alignment = .right
        return label
    }
}
