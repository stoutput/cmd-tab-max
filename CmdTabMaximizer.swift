import Cocoa
import ApplicationServices

// MARK: - Accessibility permission check

func requireAccessibility() {
    let trusted = AXIsProcessTrusted()
    if !trusted {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        print("⚠️  Accessibility permission required.")
        print("   Grant it in System Settings → Privacy & Security → Accessibility, then rerun.")
        exit(1)
    }
}

// MARK: - Window maximizer

/// Converts an NSScreen visibleFrame (AppKit coords) to Quartz/AX coords.
/// AppKit origin is bottom-left; AX origin is top-left of the primary screen.
func quartzFrame(for nsFrame: NSRect, primaryScreenHeight: CGFloat) -> NSRect {
    return NSRect(
        x: nsFrame.origin.x,
        y: primaryScreenHeight - nsFrame.origin.y - nsFrame.height,
        width: nsFrame.width,
        height: nsFrame.height
    )
}

func screenContaining(_ window: AXUIElement) -> NSScreen? {
    // Read the window's current AX position to find which screen it lives on.
    var posRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
          let posVal = posRef else { return NSScreen.main }

    var point = CGPoint.zero
    AXValueGetValue(posVal as! AXValue, .cgPoint, &point)

    // NSScreen uses flipped Y; convert AX point back to AppKit point.
    let primaryH = NSScreen.screens.first?.frame.height ?? 0
    let appKitPoint = NSPoint(x: point.x, y: primaryH - point.y)

    return NSScreen.screens.first(where: { $0.frame.contains(appKitPoint) }) ?? NSScreen.main
}

func maximizeFrontmostWindow() {
    guard let app = NSWorkspace.shared.frontmostApplication else { return }

    // Skip the Finder desktop and system UI.
    let bundleID = app.bundleIdentifier ?? ""
    if bundleID == "com.apple.finder" || bundleID == "com.apple.systemuiserver" { return }

    let axApp = AXUIElementCreateApplication(app.processIdentifier)

    var windowsRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
          let windows = windowsRef as? [AXUIElement],
          let window = windows.first else { return }

    // Only resize normal windows (not sheets, drawers, etc.).
    var roleRef: CFTypeRef?
    AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef)
    let role = roleRef as? String ?? ""
    guard role == kAXWindowRole as String else { return }

    let primaryH = NSScreen.screens.first?.frame.height ?? 0
    let screen = screenContaining(window) ?? NSScreen.main!
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
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let cmdDown = event.flags.contains(.maskCommand)
        if keyCode == 48 && cmdDown { // 48 = Tab
            cmdTabWasPressed = true
        }

    case .flagsChanged:
        // Detect Cmd being released while we recorded a Cmd-Tab.
        let cmdStillDown = event.flags.contains(.maskCommand)
        if !cmdStillDown && cmdTabWasPressed {
            cmdTabWasPressed = false
            // Brief delay lets macOS finish the app-switch animation.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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

print("✅ CmdTab Maximizer running. Press Cmd-Tab as usual — switched windows will be maximized.")
print("   Press Ctrl-C to stop.")

RunLoop.main.run()
