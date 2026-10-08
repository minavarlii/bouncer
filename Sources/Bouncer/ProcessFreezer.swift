import AppKit
import Darwin

/// Pauses apps by sending SIGSTOP and resumes them with SIGCONT.
///
/// Why signals instead of clicking "Pause syncing" in each app's menu?
/// Every sync client has a different UI, and those UIs change with updates.
/// A stopped process can't send a single byte, which is exactly what we want
/// during a call. When it gets SIGCONT it picks up where it left off; file
/// changes made in the meantime are still in the FSEvents journal.
final class ProcessFreezer {
    private(set) var frozen: [pid_t: String] = [:]

    /// Freezes every running app that matches one of the targets.
    /// Returns the display names of what was actually paused.
    @discardableResult
    func freeze(_ targets: [Target]) -> [String] {
        let running = NSWorkspace.shared.runningApplications
        var names: [String] = []

        for target in targets {
            for app in running {
                guard let bundleID = app.bundleIdentifier,
                      target.bundleIDs.contains(bundleID) else { continue }
                let pid = app.processIdentifier
                guard frozen[pid] == nil else { continue }
                if kill(pid, SIGSTOP) == 0 {
                    frozen[pid] = target.name
                    if !names.contains(target.name) { names.append(target.name) }
                }
            }
        }
        return names
    }

    /// Resumes everything we paused.
    func thawAll() {
        for pid in frozen.keys {
            kill(pid, SIGCONT)
        }
        frozen.removeAll()
    }

    /// Safety net for launch: if Bouncer crashed mid-call last time, the sync
    /// apps would still be stopped. SIGCONT on a running process is a no-op,
    /// so it's safe to send to every known target.
    static func thawAnyKnownTargets() {
        let ids = Targets.allBundleIDs
        for app in NSWorkspace.shared.runningApplications {
            if let bundleID = app.bundleIdentifier, ids.contains(bundleID) {
                kill(app.processIdentifier, SIGCONT)
            }
        }
    }
}
