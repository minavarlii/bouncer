# Bouncer

A macOS menu bar app that keeps your calls smooth by pausing bandwidth-hungry sync apps while you're on one.

When your mic turns on (Zoom, Google Meet, Teams, FaceTime, Discord, any browser WebRTC call), Bouncer pauses Dropbox, Google Drive and OneDrive. When the call ends, it lets them back in.

## Why

Home internet connections usually have a narrow upload. If Dropbox starts uploading a 2 GB folder in the middle of your call, your audio and video are the ones that suffer. Sync apps have a "pause" button, but nobody remembers to press it before every call, and none of them do it automatically.

## How it works

**Call detection.** Bouncer listens to Core Audio's `kAudioDevicePropertyDeviceIsRunningSomewhere` on the default input device. If any process is using the mic, you're probably on a call. This works with every call app and needs no microphone permission, because Bouncer never reads any audio.

**Debouncing.** The mic has to stay on for 5 seconds before Bouncer engages, so Siri or dictation won't trigger it. It has to stay off for 10 seconds before Bouncer releases, so muting or switching headphones doesn't flip things back and forth.

**Pausing.** Bouncer sends `SIGSTOP` to the sync app and `SIGCONT` when the call ends. A stopped process can't send a single byte, and this works the same for every app, no matter how its UI looks. File changes made in the meantime are still picked up through the FSEvents journal after resuming.

**Safety.** Paused apps are resumed when Bouncer quits or receives `SIGTERM` / `SIGINT`. If Bouncer is force killed, the next launch resumes any known sync app.

## Supported apps

- Dropbox
- Google Drive
- OneDrive

Each one can be turned on or off from the menu.

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later (or the Swift 5.9 toolchain)

## Build and run

```bash
git clone https://github.com/<your-username>/bouncer.git
cd bouncer
make run
```

This builds a release binary, packages it into `build/Bouncer.app`, signs it ad hoc and opens it. Look for the ✋ icon in your menu bar.

You can also open `Package.swift` in Xcode and run it from there.

Bouncer is not sandboxed, because sending signals to other apps isn't allowed inside the App Sandbox. That means it will be distributed outside the Mac App Store.

## Roadmap

- [ ] v0.1: mic based call detection, pause Dropbox / Google Drive / OneDrive
- [ ] Pause apps that launch in the middle of a call
- [ ] Custom app list (add any app)
- [ ] Camera based detection as a second signal
- [ ] Warn about Wi-Fi scans and other things that cause latency spikes during calls
- [ ] Launch at login
- [ ] v1.0: Network Extension that throttles all non-call traffic, independent of which apps are installed

## Project structure

```
Sources/Bouncer/
├── BouncerApp.swift      Menu bar UI and app lifecycle
├── Bouncer.swift         Coordinator: detection, debouncing, settings
├── CallDetector.swift    Core Audio mic usage listener
├── ProcessFreezer.swift  SIGSTOP / SIGCONT handling
└── Targets.swift         Supported apps and their bundle ids
```

## License

MIT
