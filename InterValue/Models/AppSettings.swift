import Foundation
import SwiftData

@Model
class AppSettings {
    // Sound
    var bellSoundName: String
    var countdownEnabled: Bool
    var volume: Float

    // Default Timers
    var defaultWorkSeconds: Int
    var defaultRestSeconds: Int
    var defaultPrepareSeconds: Int

    // Phase Colors (stored as hex strings)
    var workColorHex: String
    var restColorHex: String
    var prepareColorHex: String
    var finishColorHex: String

    // Appearance
    var theme: AppTheme
    var language: AppLanguage

    init(
        bellSoundName: String = "boxing_bell",
        countdownEnabled: Bool = true,
        volume: Float = 1.0,
        defaultWorkSeconds: Int = 20,
        defaultRestSeconds: Int = 10,
        defaultPrepareSeconds: Int = 10,
        workColorHex: String = "#FF6B6B",
        restColorHex: String = "#6BCB77",
        prepareColorHex: String = "#FFD93D",
        finishColorHex: String = "#A29BFE",
        theme: AppTheme = .system,
        language: AppLanguage = .system
    ) {
        self.bellSoundName = bellSoundName
        self.countdownEnabled = countdownEnabled
        self.volume = volume
        self.defaultWorkSeconds = defaultWorkSeconds
        self.defaultRestSeconds = defaultRestSeconds
        self.defaultPrepareSeconds = defaultPrepareSeconds
        self.workColorHex = workColorHex
        self.restColorHex = restColorHex
        self.prepareColorHex = prepareColorHex
        self.finishColorHex = finishColorHex
        self.theme = theme
        self.language = language
    }
}

enum AppTheme: String, Codable {
    case system, light, dark
}

enum AppLanguage: String, Codable {
    case system, en, he
}
