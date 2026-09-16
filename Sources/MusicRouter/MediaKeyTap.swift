import AppKit
import ApplicationServices
import CoreGraphics

/// Intercepts the physical play/pause/next/previous media keys at the
/// HID/session level, before macOS's default handler can decide "nothing's
/// listening" and launch Music.app. The handler decides whether to swallow
/// the event: swallowing it here means Music never launches for this
/// trigger at all (no launch-then-kill flicker); letting it through lets
/// macOS's native routing reach whatever already owns Now Playing.
/// (AirPlay/Handoff/Siri-triggered launches don't go through this path;
/// `MusicLauncherGuard` covers those the only way anyone knows how to.)
///
/// Needs BOTH Input Monitoring and Accessibility (System Settings > Privacy
/// & Security) — confirmed empirically: `CGEventTapCreate` silently returns
/// nil with only Input Monitoring granted. Reliability is also tied to
/// code-signing identity: re-signing the app with a different identity, or
/// launching the raw binary instead of the .app bundle, can silently drop
/// either grant with no error — see the health-check timer below, and
/// README for the full explanation.
final class MediaKeyTap {
    /// Returns whether to swallow the event. `false` lets it pass through
    /// untouched — used when something else already owns Now Playing, so
    /// macOS's native routing reaches it directly (see AppDelegate).
    typealias Handler = (MediaKey, Bool) -> Bool

    // Raw values are the IOKit/hidsystem NX_KEYTYPE_* constants (ev_keymap.h)
    // for media keys — lets `decode` below go straight from the packed key
    // code to a case via `MediaKey(rawValue:)`, no separate constants/switch.
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

    // NSEvent.EventType.systemDefined.rawValue — not exposed on CGEventType,
    // so it has to be matched/masked by raw numeric value instead.
    private static let systemDefinedEventType: UInt32 = 14

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    var hasInputMonitoring: Bool { CGPreflightListenEventAccess() }
    var hasAccessibility: Bool { AXIsProcessTrusted() }

    /// `false` means Input Monitoring and/or Accessibility isn't granted yet
    /// — call `requestInputMonitoringPermission()`/`requestAccessibilityPermission()`
    /// to prompt; a started tap installs itself once both are granted.
    var hasPermission: Bool { hasInputMonitoring && hasAccessibility }

    /// Requesting both TCC prompts back-to-back only shows the first one —
    /// macOS silently registers the second request without an alert if it
    /// arrives while the first is still up. Call these separately, and only
    /// call the second once the first is confirmed granted (see AppDelegate).
    func requestInputMonitoringPermission() {
        CGRequestListenEventAccess()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Marks the tap as wanted and keeps trying until it is. The health check
    /// runs independently of whether this first attempt succeeds, so a
    /// failure here (no permission yet, or `tapCreate` refusing) is retried
    /// rather than left permanently dead.
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

    /// CGEventTaps tied to Input Monitoring can go silently inert after a
    /// re-sign without the OS reporting it, and `install()` can fail outright
    /// when a grant is missing — reinstall in either case, for as long as the
    /// tap is meant to be running. Deliberately not routed through
    /// `stop()`/`start()`: `stop()` kills this very timer, so a failed
    /// recovery attempt used to take the retry mechanism down with it.
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

    /// Pulls a media key + press state out of an `NSSystemDefined` event's
    /// packed `data1` field. Pure and static so the bit-masking (the one
    /// genuinely fiddly part of this class) is directly unit-testable
    /// without needing a real `CGEvent`/`NSEvent`.
    static func decode(data1: Int) -> (MediaKey, isPressed: Bool)? {
        let keyCode = Int32((data1 & 0xFFFF_0000) >> 16)
        let keyFlags = data1 & 0x0000_FFFF
        let isPressed = ((keyFlags & 0xFF00) >> 8) == 0xA

        guard let mediaKey = MediaKey(rawValue: keyCode) else { return nil }
        return (mediaKey, isPressed)
    }
}
