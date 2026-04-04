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

            // Consume the real Cmd-release and replace it with a synthetic
            // sequence posted at the HID level: Option-down → Cmd-up (Option
            // still held) → Option-up. This is identical to what the hardware
            // produces when the user physically holds Option, so the App
            // Switcher sees Option held at the moment Cmd releases and restores
            // minimized windows.
            let cmdKeyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let src = CGEventSource(stateID: .hidSystemState)

            let sequence: [(Int64, CGEventFlags)] = [
                (optionKeyCode, [.maskCommand, .maskAlternate]), // Option down
                (cmdKeyCode,    [.maskAlternate]),               // Cmd up, Option held
                (optionKeyCode, []),                             // Option up
            ]
            for (keycode, flags) in sequence {
                if let e = CGEvent(source: src) {
                    e.type = .flagsChanged
                    e.setIntegerValueField(.keyboardEventKeycode, value: keycode)
                    e.flags = flags
                    e.post(tap: .cghidEventTap)
                }
            }

            return nil // consumed; replaced by the synthetic sequence above
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
