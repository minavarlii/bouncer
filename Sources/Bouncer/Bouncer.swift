import Foundation
import SwiftUI

/// Glues the call detector to the freezer, with some debouncing so a quick
/// Siri or dictation burst doesn't pause your sync apps.
final class Bouncer: ObservableObject {
    static let shared = Bouncer()

    /// Mic has to stay on this long before we treat it as a call.
    private let engageDelay: TimeInterval = 5
    /// Mic has to stay off this long before we resume (covers mute/unmute blips
    /// and switching between devices).
    private let releaseDelay: TimeInterval = 10

    @Published private(set) var isOnCall = false
    @Published private(set) var bounced: [String] = []
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            if isEnabled { if micInUse { engage() } } else { release() }
        }
    }
    @Published private(set) var enabledTargetIDs: Set<String>

    private let detector = CallDetector()
    private let freezer = ProcessFreezer()
    private var micInUse = false
    private var pending: DispatchWorkItem?

    private enum Keys {
        static let enabled = "enabled"
        static let targets = "enabledTargets"
    }

    private init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        if let saved = defaults.stringArray(forKey: Keys.targets) {
            enabledTargetIDs = Set(saved)
        } else {
            enabledTargetIDs = Set(Targets.all.map(\.id))
        }
    }

    // MARK: - Lifecycle

    func start() {
        ProcessFreezer.thawAnyKnownTargets()
        detector.onChange = { [weak self] inUse in
            self?.micChanged(inUse)
        }
        detector.start()
    }

    /// Must run before the app exits, otherwise the sync apps stay frozen.
    func shutdown() {
        pending?.cancel()
        detector.stop()
        freezer.thawAll()
    }

    // MARK: - Settings

    func isTargetEnabled(_ target: Target) -> Bool {
        enabledTargetIDs.contains(target.id)
    }

    func setTarget(_ target: Target, enabled: Bool) {
        if enabled {
            enabledTargetIDs.insert(target.id)
        } else {
            enabledTargetIDs.remove(target.id)
        }
        UserDefaults.standard.set(Array(enabledTargetIDs), forKey: Keys.targets)
        // Apply immediately if we're mid-call
        if isOnCall {
            freezer.thawAll()
            bounced = freezer.freeze(activeTargets)
        }
    }

    // MARK: - Call handling

    private var activeTargets: [Target] {
        Targets.all.filter { enabledTargetIDs.contains($0.id) }
    }

    private func micChanged(_ inUse: Bool) {
        micInUse = inUse
        pending?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if inUse { self.engage() } else { self.release() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (inUse ? engageDelay : releaseDelay), execute: work)
    }

    private func engage() {
        guard isEnabled, !isOnCall else { return }
        isOnCall = true
        bounced = freezer.freeze(activeTargets)
    }

    private func release() {
        guard isOnCall else { return }
        freezer.thawAll()
        isOnCall = false
        bounced = []
    }
}
