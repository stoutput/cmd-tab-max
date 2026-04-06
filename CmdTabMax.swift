import Cocoa
import ApplicationServices

private let tabKeyCode: Int64 = 48
private let skippedBundleIDs: Set<String> = [
    "com.apple.finder",
    "com.apple.systemuiserver",
]

// MARK: - Accessibility permission check

func requireAccessibility() {
    // Retry silently first — TCC may not be ready immediately at login.
    for _ in 0..<20 {
        if AXIsProcessTrusted() { return }
        Thread.sleep(forTimeInterval: 0.5)
    }
    // Still not trusted after 10 seconds — prompt and wait.
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    AXIsProcessTrustedWithOptions(opts)
    while !AXIsProcessTrusted() { Thread.sleep(forTimeInterval: 3) }
}

// MARK: - Window handling

func restoreMinimized(app: NSRunningApplication) {
    guard !skippedBundleIDs.contains(app.bundleIdentifier ?? "") else { return }

    let axApp = AXUIElementCreateApplication(app.processIdentifier)

    var windowsRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
          let windows = windowsRef as? [AXUIElement] else { return }

    for window in windows {
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef)
        guard (roleRef as? String) == kAXWindowRole as String else { continue }

        var minRef: CFTypeRef?
        let isMinimized = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minRef) == .success
            && minRef != nil
            && CFBooleanGetValue((minRef as! CFBoolean))

        if isMinimized {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
    }
}

// MARK: - Event tap

var cmdTabWasPressed = false
var expectingSwitch = false

let eventCallback: CGEventTapCallBack = { _, type, event, _ in
    switch type {
    case .keyDown:
        if event.getIntegerValueField(.keyboardEventKeycode) == tabKeyCode
            && event.flags.contains(.maskCommand) {
            cmdTabWasPressed = true
        }
    case .flagsChanged:
        if !event.flags.contains(.maskCommand) && cmdTabWasPressed {
            cmdTabWasPressed = false
            expectingSwitch = true
        }
    default:
        break
    }
    return Unmanaged.passRetained(event)
}

// MARK: - App activation observer

NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification,
    object: nil,
    queue: .main
) { notification in
    guard expectingSwitch else { return }
    expectingSwitch = false
    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication else { return }
    restoreMinimized(app: app)
}

// MARK: - Entry point

requireAccessibility()

let eventsOfInterest: CGEventMask =
    (1 << CGEventType.keyDown.rawValue) |
    (1 << CGEventType.flagsChanged.rawValue)

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: eventsOfInterest,
    callback: eventCallback,
    userInfo: nil
) else {
    print("❌ Could not create event tap. Make sure Accessibility is granted.")
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("✅ CmdTabMax running.")

RunLoop.main.run()
