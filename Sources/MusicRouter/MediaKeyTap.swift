import AppKit
import ApplicationServices
import CoreGraphics

/// Intercepts media keys at the HID/session level, before macOS decides
/// nothing's listening and launches Music.app. AirPlay/Handoff/Siri launches
/// bypass this; `MusicLauncherGuard` covers those.
///
/// Needs BOTH Input Monitoring and Accessibility: `CGEventTapCreate` returns
/// nil with only the first. Re-signing with another identity, or running the
/// raw binary, can silently drop either grant (see README).
final class MediaKeyTap {
    /// Returns whether to swallow the event; `false` passes it through to the Now Playing owner.
    typealias Handler = (MediaKey, Bool) -> Bool

    // raw values are NX_KEYTYPE_* (ev_keymap.h), so decode is just MediaKey(rawValue:)
    enum MediaKey: Int32 {
        case playPause = 16
        case next = 17
        case previous = 18
    }

    private let handler: Handler
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?
    private var shouldBeRunning = false

    // NSEvent.EventType.systemDefined; CGEventType has no case for it
    private static let systemDefinedEventType: UInt32 = 14

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    var hasInputMonitoring: Bool { CGPreflightListenEventAccess() }
    var hasAccessibility: Bool { AXIsProcessTrusted() }

    /// `false` = a grant is missing; a started tap installs itself once both exist.
    var hasPermission: Bool { hasInputMonitoring && hasAccessibility }

    /// Back-to-back TCC requests only show the first alert. Request the second
    /// only after the first is granted (see AppDelegate).
    func requestInputMonitoringPermission() {
        CGRequestListenEventAccess()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Marks the tap as wanted; the health check retries until it installs.
    func start() {
        shouldBeRunning = true
        if healthCheckTimer == nil {
            healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                self?.healthCheck()
            }
        }
        install()
    }

    func stop() {
        shouldBeRunning = false
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        teardown()
    }

    /// Taps can go inert after a re-sign, and install() fails without grants;
    /// reinstall while wanted. Not via stop()/start(): stop() kills this timer.
    private func healthCheck() {
        guard shouldBeRunning else { return }
        if let tap = eventTap, CGEvent.tapIsEnabled(tap: tap) { return }
        teardown()
        install()
    }

    private func install() {
        guard hasPermission, eventTap == nil else { return }

        let eventMask = 1 << Self.systemDefinedEventType
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, type, cgEvent, refcon in
                guard let refcon else { return Unmanaged.passUnretained(cgEvent) }
                let tap = Unmanaged<MediaKeyTap>.fromOpaque(refcon).takeUnretainedValue()
                return tap.handle(type: type, cgEvent: cgEvent)
            },
            userInfo: selfPointer
        ) else { return }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func teardown() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        // The OS disables a tap under load; re-enabling is the documented fix.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(cgEvent)
        }

        guard
            type.rawValue == Self.systemDefinedEventType,
            let nsEvent = NSEvent(cgEvent: cgEvent),
            nsEvent.subtype.rawValue == 8,
            let (mediaKey, isPressed) = Self.decode(data1: nsEvent.data1)
        else {
            return Unmanaged.passUnretained(cgEvent)
        }

        return handler(mediaKey, isPressed) ? nil : Unmanaged.passUnretained(cgEvent)
    }

    /// Unpacks key + press state from `data1`. Static so the bit-masking is unit-testable.
    static func decode(data1: Int) -> (MediaKey, isPressed: Bool)? {
        let keyCode = Int32((data1 & 0xFFFF_0000) >> 16)
        let keyFlags = data1 & 0x0000_FFFF
        let isPressed = ((keyFlags & 0xFF00) >> 8) == 0xA

        guard let mediaKey = MediaKey(rawValue: keyCode) else { return nil }
        return (mediaKey, isPressed)
    }
}
