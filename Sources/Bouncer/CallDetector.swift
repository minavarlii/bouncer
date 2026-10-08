import CoreAudio
import Foundation

/// Watches the default input device and reports whether any process on the
/// system is currently using the microphone. That's our "you're on a call" signal:
/// it works for Zoom, Meet, Teams, FaceTime, Discord and browser WebRTC alike.
///
/// Reading kAudioDevicePropertyDeviceIsRunningSomewhere does not need the
/// microphone permission, because we never touch the audio itself.
final class CallDetector {
    /// Called on the main queue whenever mic usage flips.
    var onChange: ((Bool) -> Void)?

    private let queue = DispatchQueue(label: "bouncer.call-detector")
    private var isMicInUse = false
    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var runningListener: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?

    private var runningAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private var defaultInputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    func start() {
        // Re-attach whenever the user switches mics (AirPods connect, etc.)
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.attachToDefaultInput()
        }
        defaultDeviceListener = listener
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddress,
            queue,
            listener
        )
        queue.async { self.attachToDefaultInput() }
    }

    func stop() {
        queue.sync {
            detachFromDevice()
            if let listener = defaultDeviceListener {
                AudioObjectRemovePropertyListenerBlock(
                    AudioObjectID(kAudioObjectSystemObject),
                    &defaultInputAddress,
                    queue,
                    listener
                )
            }
            defaultDeviceListener = nil
        }
    }

    // MARK: - Private (always on `queue`)

    private func attachToDefaultInput() {
        detachFromDevice()

        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddress,
            0, nil,
            &size, &id
        )
        guard status == noErr, id != kAudioObjectUnknown else {
            report(false)
            return
        }

        deviceID = id
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refresh()
        }
        runningListener = listener
        AudioObjectAddPropertyListenerBlock(id, &runningAddress, queue, listener)
        refresh()
    }

    private func detachFromDevice() {
        if let listener = runningListener, deviceID != kAudioObjectUnknown {
            AudioObjectRemovePropertyListenerBlock(deviceID, &runningAddress, queue, listener)
        }
        runningListener = nil
        deviceID = AudioObjectID(kAudioObjectUnknown)
    }

    private func refresh() {
        guard deviceID != kAudioObjectUnknown else { return report(false) }
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &runningAddress, 0, nil, &size, &running)
        report(status == noErr && running != 0)
    }

    private func report(_ inUse: Bool) {
        guard inUse != isMicInUse else { return }
        isMicInUse = inUse
        DispatchQueue.main.async { self.onChange?(inUse) }
    }
}
