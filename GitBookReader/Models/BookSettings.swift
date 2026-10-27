import SwiftUI
import Combine

// MARK: - BookSettings

class BookSettings: ObservableObject {
    // MARK: - Theme Enum

    enum Theme: String, CaseIterable, Identifiable {
        case system
        case light
        case dark
        case sepia

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system: return String(localized: "theme.system")
            case .light: return String(localized: "theme.light")
            case .dark: return String(localized: "theme.dark")
            case .sepia: return String(localized: "theme.sepia")
            }
        }
    }

    // MARK: - Published Properties

    @Published var fontSizeMultiplier: Double {
        didSet {
            UserDefaults.standard.set(fontSizeMultiplier, forKey: Keys.fontSize)
        }
    }

    @Published var readingTheme: Theme {
        didSet {
            UserDefaults.standard.set(readingTheme.rawValue, forKey: Keys.readingTheme)
        }
    }

    // MARK: - Keys

    private enum Keys {
        static let fontSize = "fontSizeMultiplier"
        static let readingTheme = "readingTheme"
    }

    // MARK: - Constants

    static let minFontSize: Double = 0.6
    static let maxFontSize: Double = 2.0
    static let defaultFontSize: Double = 1.0

    // MARK: - Initialization

    init() {
        let savedFontSize = UserDefaults.standard.double(forKey: Keys.fontSize)
        self.fontSizeMultiplier = savedFontSize > 0
            ? savedFontSize
            : Self.defaultFontSize

        if let themeString = UserDefaults.standard.string(forKey: Keys.readingTheme),
           let theme = Theme(rawValue: themeString) {
            self.readingTheme = theme
        } else {
            self.readingTheme = .system
        }
    }

    // MARK: - Computed Properties

    var backgroundColor: Color {
        switch readingTheme {
        case .system:
            return Color.adaptiveBackground
        case .light:
            return .white
        case .dark:
            return Color(white: 0.1)
        case .sepia:
            return Color(red: 251 / 255, green: 240 / 255, blue: 217 / 255)
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch readingTheme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        case .sepia:
            return .light
        }
    }
}
