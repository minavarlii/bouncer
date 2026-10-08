import AppKit
import SwiftUI

@main
struct BouncerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var bouncer = Bouncer.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(bouncer)
        } label: {
            Image(systemName: bouncer.isOnCall ? "hand.raised.fill" : "hand.raised")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        Bouncer.shared.start()
        installSignalHandlers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Bouncer.shared.shutdown()
    }

    /// If Bouncer gets killed from the terminal (Ctrl+C, `kill`), still resume
    /// the apps we paused. SIGKILL can't be caught; the next launch cleans that up.
    private func installSignalHandlers() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                Bouncer.shared.shutdown()
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }
}

struct MenuView: View {
    @EnvironmentObject private var bouncer: Bouncer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bouncer").font(.headline)
                Spacer()
                Toggle("Enabled", isOn: $bouncer.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Text(statusText)
                .font(.callout)
                .foregroundStyle(.secondary)

            if !bouncer.bounced.isEmpty {
                ForEach(bouncer.bounced, id: \.self) { name in
                    Label(name, systemImage: "pause.circle.fill")
                        .font(.callout)
                }
            }

            Divider()

            Text("Pause during calls")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Targets.all) { target in
                Toggle(target.name, isOn: Binding(
                    get: { bouncer.isTargetEnabled(target) },
                    set: { bouncer.setTarget(target, enabled: $0) }
                ))
            }

            Divider()

            Button("Quit Bouncer") {
                NSApp.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 260)
    }

    private var statusText: String {
        if !bouncer.isEnabled { return "Off duty" }
        if !bouncer.isOnCall { return "No call. Everyone's welcome." }
        if bouncer.bounced.isEmpty { return "On a call. Nothing to bounce." }
        return "On a call. Paused for now:"
    }
}
