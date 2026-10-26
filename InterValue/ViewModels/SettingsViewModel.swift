import Foundation
import Observation
import SwiftUI

struct SoundOption: Identifiable {
    let id: String
    let label: String
}

@Observable
class SettingsViewModel {

    // MARK: - Sound display names (ID → user-facing label)

    static let soundOptions: [SoundOption] = [
        SoundOption(id: "boxing_bell",  label: "Boxing Bell"),
        SoundOption(id: "tibetan_bowl", label: "Tibetan Bowl"),
        SoundOption(id: "temple_block", label: "Temple Block"),
        SoundOption(id: "kantilan",     label: "Kantilan"),
        SoundOption(id: "digital_beep", label: "Digital Beep"),
    ]

    // MARK: - Stored reference

    private(set) var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Sound

    var bellSoundName: String {
        get { settings.bellSoundName }
        set { settings.bellSoundName = newValue }
    }

    var countdownEnabled: Bool {
        get { settings.countdownEnabled }
        set { settings.countdownEnabled = newValue }
    }

    var volume: Float {
        get { settings.volume }
        set { settings.volume = newValue }
    }

    // MARK: - Default Timers

    var defaultWorkSeconds: Int {
        get { settings.defaultWorkSeconds }
        set { settings.defaultWorkSeconds = newValue }
    }

    var defaultRestSeconds: Int {
        get { settings.defaultRestSeconds }
        set { settings.defaultRestSeconds = newValue }
    }

    var defaultPrepareSeconds: Int {
        get { settings.defaultPrepareSeconds }
        set { settings.defaultPrepareSeconds = newValue }
    }

    // MARK: - Colors (Color ↔ hex bridge)

    var workColor: Color {
        get { Color(hex: settings.workColorHex) }
        set { settings.workColorHex = newValue.toHex() }
    }

    var restColor: Color {
        get { Color(hex: settings.restColorHex) }
        set { settings.restColorHex = newValue.toHex() }
    }

    var prepareColor: Color {
        get { Color(hex: settings.prepareColorHex) }
        set { settings.prepareColorHex = newValue.toHex() }
    }

    var finishColor: Color {
        get { Color(hex: settings.finishColorHex) }
        set { settings.finishColorHex = newValue.toHex() }
    }

    // MARK: - Workout Display (stored in UserDefaults to avoid SwiftData migration)

    var showSetPreview: Bool {
        get { UserDefaults.standard.object(forKey: "showSetPreview") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showSetPreview") }
    }

    var largeWorkoutText: Bool {
        get { UserDefaults.standard.object(forKey: "largeWorkoutText") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "largeWorkoutText") }
    }

    // MARK: - Appearance

    var theme: AppTheme {
        get { settings.theme }
        set { settings.theme = newValue }
    }

    var language: AppLanguage {
        get { settings.language }
        set { settings.language = newValue }
    }
}
