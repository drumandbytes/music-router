import CoreAudio

/// Public-API stand-in for Now Playing when the adapter is down: is any
/// process driving the default output device? Coarser than MediaRemote (a
/// call or system sound counts, a paused player doesn't), but it needs no
/// private API and nothing to start.
enum AudioActivity {
    static func isOutputRunning() -> Bool {
        var deviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &deviceAddress, 0, nil, &size, &device
        ) == noErr, device != kAudioObjectUnknown else { return false }

        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &runningAddress, 0, nil, &size, &running) == noErr else {
            return false
        }
        return running != 0
    }
}
