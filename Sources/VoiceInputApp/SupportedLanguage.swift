import Foundation

enum SupportedLanguage: String, CaseIterable {
    case english = "en-US"
    case simplifiedChinese = "zh-CN"
    case traditionalChinese = "zh-TW"
    case japanese = "ja-JP"
    case korean = "ko-KR"

    var title: String {
        switch self {
        case .english:
            "English"
        case .simplifiedChinese:
            "Simplified Chinese"
        case .traditionalChinese:
            "Traditional Chinese"
        case .japanese:
            "Japanese"
        case .korean:
            "Korean"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}
