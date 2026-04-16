import Foundation

struct LLMConfiguration {
    var enabled: Bool
    var apiBaseURL: String
    var apiKey: String
    var model: String

    var isComplete: Bool {
        !apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKey.isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

final class Preferences {
    static let shared = Preferences()

    private enum Key {
        static let selectedLanguage = "selectedLanguageIdentifier"
        static let llmEnabled = "llm.enabled"
        static let llmAPIBaseURL = "llm.apiBaseURL"
        static let llmAPIKey = "llm.apiKey"
        static let llmModel = "llm.model"
    }

    private let defaults = UserDefaults.standard

    var selectedLanguage: SupportedLanguage {
        get {
            guard let value = defaults.string(forKey: Key.selectedLanguage),
                  let language = SupportedLanguage(rawValue: value)
            else {
                return .simplifiedChinese
            }
            return language
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.selectedLanguage)
        }
    }

    var llmConfiguration: LLMConfiguration {
        get {
            LLMConfiguration(
                enabled: defaults.bool(forKey: Key.llmEnabled),
                apiBaseURL: defaults.string(forKey: Key.llmAPIBaseURL) ?? "",
                apiKey: defaults.string(forKey: Key.llmAPIKey) ?? "",
                model: defaults.string(forKey: Key.llmModel) ?? ""
            )
        }
        set {
            defaults.set(newValue.enabled, forKey: Key.llmEnabled)
            defaults.set(newValue.apiBaseURL, forKey: Key.llmAPIBaseURL)
            defaults.set(newValue.apiKey, forKey: Key.llmAPIKey)
            defaults.set(newValue.model, forKey: Key.llmModel)
        }
    }
}
