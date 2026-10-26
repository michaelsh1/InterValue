import AVFoundation

class SoundManager {
    static let shared = SoundManager()

    // Silent audio engine — keeps the AVAudioSession active in the background
    // so the OS doesn't suspend the app between bell sounds.
    private let silentEngine = AVAudioEngine()
    private let silentPlayer = AVAudioPlayerNode()

    /// All known sound IDs (including per-count variants for multi-ring sounds).
    static let allSoundNames: [String] = [
        "beep_short",
        "bell_classic",
        "gong_deep",
        "chime_zen",
        "buzz_digital",
        "boxing_bell_once",
        "boxing_bell_twice",
        "boxing_bell_thrice",
        "tibetan_bowl_once",
        "tibetan_bowl_twice",
        "tibetan_bowl_thrice",
        "temple_block_once",
        "temple_block_twice",
        "temple_block_thrice",
        "kantilan_once",
        "kantilan_twice",
        "kantilan_thrice",
        "digital_beep_once",
        "digital_beep_twice",
        "digital_beep_thrice",
    ]

    /// Maps sound IDs to their actual bundle file names (for files whose names differ from the ID).
    private static let fileNameMap: [String: String] = [
        "boxing_bell_once":    "Boxing bell - once",
        "boxing_bell_twice":   "Boxing bell - twice",
        "boxing_bell_thrice":  "Boxing bell - thrice",
        "tibetan_bowl_once":   "Tibetan Bowl - once",
        "tibetan_bowl_twice":  "Tibetan Bowl - twice",
        "tibetan_bowl_thrice": "Tibetan Bowl - thrice",
        "temple_block_once":   "temple block - once",
        "temple_block_twice":  "temple block - twice",
        "temple_block_thrice": "temple block - thrice",
        "kantilan_once":       "Kantilan - once",
        "kantilan_twice":      "Kantilan - twice",
        "kantilan_thrice":     "Kantilan - thrice",
        "digital_beep_once":   "Digital Beep - once",
        "digital_beep_twice":  "Digital Beep - twice",
        "digital_beep_thrice": "Digital Beep - thrice",
    ]

    private var players: [String: AVAudioPlayer] = [:]

    // MARK: - Init

    private init() {
        configureAudioSession()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[SoundManager] Failed to configure AVAudioSession: \(error)")
        }
    }

    // MARK: - Background Session

    /// Call when a workout starts — plays inaudible audio to keep the session alive.
    func startBackgroundSession() {
        silentEngine.attach(silentPlayer)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        silentEngine.connect(silentPlayer, to: silentEngine.mainMixerNode, format: format)
        silentEngine.mainMixerNode.outputVolume = 0

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4410) else { return }
        buffer.frameLength = 4410 // 0.1 s of silence

        do {
            try silentEngine.start()
            silentPlayer.scheduleBuffer(buffer, at: nil, options: .loops)
            silentPlayer.play()
        } catch {
            print("[SoundManager] Failed to start silent engine: \(error)")
        }
    }

    /// Call when the workout ends or is stopped.
    func stopBackgroundSession() {
        silentPlayer.stop()
        silentEngine.stop()
    }

    // MARK: - Public API

    /// Returns the variant sound name (e.g. "boxing_bell_twice") if it exists,
    /// otherwise falls back to the base name.
    static func variant(_ count: String, of base: String) -> String {
        let name = "\(base)_\(count)"
        return allSoundNames.contains(name) ? name : base
    }

    /// Loads and caches an AVAudioPlayer for the given sound name.
    func preload(soundName: String) {
        guard players[soundName] == nil else { return }

        guard let url = bundleURL(for: soundName) else {
            print("[SoundManager] Sound file not found for '\(soundName)' — skipping preload.")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[soundName] = player
        } catch {
            print("[SoundManager] Could not create player for '\(soundName)': \(error)")
        }
    }

    /// Preloads all known sounds. Call this when a workout starts.
    func preloadAll() {
        SoundManager.allSoundNames.forEach { preload(soundName: $0) }
    }

    /// Plays a sound at the specified volume. Preloads on demand if not already loaded.
    func play(soundName: String, volume: Float) {
        if players[soundName] == nil { preload(soundName: soundName) }
        guard let player = players[soundName] else { return }
        player.volume = max(0, min(1, volume))
        player.currentTime = 0
        player.play()
    }

    /// Plays a sound for Settings previews. Preloads on demand if needed.
    func previewSound(soundName: String, volume: Float = 1.0) {
        play(soundName: soundName, volume: volume)
    }

    // MARK: - Helpers

    private func bundleURL(for soundName: String) -> URL? {
        let fileName = SoundManager.fileNameMap[soundName] ?? soundName
        for ext in ["caf", "wav", "m4a", "mp3", "aiff"] {
            if let url = Bundle.main.url(forResource: fileName, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
