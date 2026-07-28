import Foundation
import SwiftUI
import Observation

/// Lightweight app-wide profile + preferences, persisted to UserDefaults.
/// The heavier session/check-in history lives in SwiftData (see Records.swift).
///
/// NOTE: In production this local profile is a cache; the source of truth is the
/// Steady backend (auth, encrypted memory, billing, specialist gating). See the
/// README's "Connecting to the backend" section.
@Observable
final class AppState {
    var name: String {
        didSet { defaults.set(name, forKey: Keys.name) }
    }
    var calmPlace: String {
        didSet { defaults.set(calmPlace, forKey: Keys.calmPlace) }
    }
    /// Audio-only bilateral stimulation default (photosensitivity flag).
    var audioOnlyDefault: Bool {
        didSet { defaults.set(audioOnlyDefault, forKey: Keys.audioOnly) }
    }
    /// Haptic bilateral taps on by default.
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) }
    }
    var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: Keys.onboarded) }
    }
    /// Gated modules the member's specialist has unlocked. Locally simulated in
    /// this first version; server-governed in production.
    var unlockedGatedIds: Set<String> {
        didSet { defaults.set(Array(unlockedGatedIds), forKey: Keys.unlocked) }
    }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let name = "steady.name"
        static let calmPlace = "steady.calmPlace"
        static let audioOnly = "steady.audioOnly"
        static let haptics = "steady.haptics"
        static let onboarded = "steady.onboarded"
        static let unlocked = "steady.unlocked"
    }

    init() {
        name = defaults.string(forKey: Keys.name) ?? ""
        calmPlace = defaults.string(forKey: Keys.calmPlace) ?? ""
        audioOnlyDefault = defaults.bool(forKey: Keys.audioOnly)
        // Default haptics ON unless the user has explicitly set a value.
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        hasOnboarded = defaults.bool(forKey: Keys.onboarded)
        unlockedGatedIds = Set(defaults.stringArray(forKey: Keys.unlocked) ?? [])
    }

    /// Whether a module is available to start, given its tier and prerequisites.
    func isModuleAvailable(_ module: TherapyModule) -> Bool {
        switch module.tier {
        case .autonomous, .maintenance:
            return true
        case .gated:
            return unlockedGatedIds.contains(module.id)
        }
    }
}
