import Cocoa

private let tabKeyCode: Int64 = 48
private let optionKeyCode: Int64 = 58 // kVK_Option (left)

// MARK: - Accessibility permission check

func requireAccessibility() {
    guard !AXIsProcessTrusted() else { return }

    // Show the system prompt once, then poll — never exit, since KeepAlive
    // would immediately relaunch and re-show the dialog in a loop.
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    AXIsProcessTrustedWithOptions(opts)
    while !AXIsProcessTrusted() { Thread.sleep(forTimeInterval: 3) }
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

            // Inject Option into the Cmd-release event. The App Switcher sees
            // "Cmd released while Option held" and restores minimized windows.
            event.flags.insert(.maskAlternate)

            // Release Option shortly after so it doesn't bleed into the new app.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if let src = CGEventSource(stateID: .hidSystemState),
                   let optUp = CGEvent(source: src) {
                    optUp.type = .flagsChanged
                    optUp.setIntegerValueField(.keyboardEventKeycode, value: optionKeyCode)
                    optUp.flags = []
                    optUp.post(tap: .cghidEventTap)
                }
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
