import Cocoa
import ApplicationServices

private let tabKeyCode: Int64 = 48
private let windowSwitchDelay: TimeInterval = 0.15
private let skippedBundleIDs: Set<String> = [
    "com.apple.finder",
    "com.apple.systemuiserver",
]

// MARK: - Accessibility permission check

func requireAccessibility() {
    guard !AXIsProcessTrusted() else { return }

    // Show the system prompt once, then poll — never exit, since KeepAlive
    // would immediately relaunch and re-show the dialog in a loop.
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    AXIsProcessTrustedWithOptions(opts)
    print("⚠️  Accessibility permission required.")
    print("   Enable CmdTabMax in System Settings → Privacy & Security → Accessibility.")

    while !AXIsProcessTrusted() {
        Thread.sleep(forTimeInterval: 3)
    }
    print("✅ Accessibility permission granted.")
}

// MARK: - Window maximizer

/// Converts an NSScreen visibleFrame (AppKit coords, origin bottom-left) to
/// Quartz/AX coords (origin top-left of the primary screen).
func quartzFrame(for nsFrame: NSRect, primaryScreenHeight: CGFloat) -> NSRect {
    NSRect(
        x: nsFrame.origin.x,
        y: primaryScreenHeight - nsFrame.origin.y - nsFrame.height,
        width: nsFrame.width,
        height: nsFrame.height
    )
}

func screenContaining(_ window: AXUIElement, primaryScreenHeight: CGFloat) -> NSScreen? {
    var posRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
          posRef != nil else { return NSScreen.main }

    var point = CGPoint.zero
    AXValueGetValue(posRef as! AXValue, .cgPoint, &point)

    let appKitPoint = NSPoint(x: point.x, y: primaryScreenHeight - point.y)
    return NSScreen.screens.first(where: { $0.frame.contains(appKitPoint) }) ?? NSScreen.main
}

func maximizeFrontmostWindow() {
    guard let app = NSWorkspace.shared.frontmostApplication,
          !skippedBundleIDs.contains(app.bundleIdentifier ?? "") else { return }

    let axApp = AXUIElementCreateApplication(app.processIdentifier)

    var windowsRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
          let windows = windowsRef as? [AXUIElement],
          let window = windows.first else { return }

    var roleRef: CFTypeRef?
    AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef)
    guard (roleRef as? String) == kAXWindowRole as String else { return }

    let primaryH = NSScreen.screens.first?.frame.height ?? 0
    let screen = screenContaining(window, primaryScreenHeight: primaryH) ?? NSScreen.main!
    let targetFrame = quartzFrame(for: screen.visibleFrame, primaryScreenHeight: primaryH)

    var origin = targetFrame.origin
    if let axPos = AXValueCreate(.cgPoint, &origin) {
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPos)
    }

    var size = targetFrame.size
    if let axSize = AXValueCreate(.cgSize, &size) {
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
    }
}

// MARK: - Event tap

var cmdTabWasPressed = false

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
            // Brief delay lets macOS finish the app-switch animation.
            DispatchQueue.main.asyncAfter(deadline: .now() + windowSwitchDelay) {
                maximizeFrontmostWindow()
            }
        }

    default:
        break
    }

    return Unmanaged.passRetained(event)
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

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("✅ CmdTabMax running. Cmd-Tab as usual — switched windows will be maximized.")
print("   Press Ctrl-C to stop.")

RunLoop.main.run()
