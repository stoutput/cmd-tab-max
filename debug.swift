import Cocoa
import ApplicationServices

if !AXIsProcessTrusted() {
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    AXIsProcessTrustedWithOptions(opts)
    print("Accessibility permission required.")
    print("Grant it in System Settings → Privacy & Security → Accessibility, then rerun.")
    exit(1)
}

guard let app = NSWorkspace.shared.frontmostApplication else {
    print("No frontmost application.")
    exit(1)
}

print("App: \(app.localizedName ?? "?") (\(app.bundleIdentifier ?? "?"))")

let axApp = AXUIElementCreateApplication(app.processIdentifier)

func attr(_ el: AXUIElement, _ key: String) -> CFTypeRef? {
    var ref: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, key as CFString, &ref) == .success ? ref : nil
}

// Top-level window attributes
for key in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
    if let val = attr(axApp, key) {
        print("\(key): present (\(CFGetTypeID(val)))")
    } else {
        print("\(key): nil/error")
    }
}

// All windows
guard let windowsRef = attr(axApp, kAXWindowsAttribute),
      let windows = windowsRef as? [AXUIElement] else {
    print("kAXWindowsAttribute: nil/error")
    exit(0)
}

print("kAXWindowsAttribute: \(windows.count) window(s)\n")

for (i, win) in windows.enumerated() {
    let title = attr(win, kAXTitleAttribute) as? String ?? "?"
    let role  = attr(win, kAXRoleAttribute)  as? String ?? "?"

    var minRef: CFTypeRef?
    let minErr = AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minRef)
    let minCF  = minRef.map { CFBooleanGetValue($0 as! CFBoolean) }

    // Current position and size
    var posRef: CFTypeRef?
    var sizeRef: CFTypeRef?
    var curPos  = CGPoint.zero
    var curSize = CGSize.zero
    if AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef) == .success, posRef != nil {
        AXValueGetValue(posRef as! AXValue, .cgPoint, &curPos)
    }
    if AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef) == .success, sizeRef != nil {
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &curSize)
    }

    print("  [\(i)] \"\(title)\"")
    print("       role=\(role)  minimized err=\(minErr.rawValue) value=\(String(describing: minCF))")
    print("       current position=\(curPos)  size=\(curSize)")

    // Attempt resize to main screen's visible frame
    guard let screen = NSScreen.main else { continue }
    let ph      = NSScreen.screens.first?.frame.height ?? 0
    let vf      = screen.visibleFrame
    let target  = NSRect(x: vf.origin.x,
                         y: ph - vf.origin.y - vf.height,
                         width: vf.width,
                         height: vf.height)
    print("       target   position=\(target.origin)  size=\(target.size)")

    var origin = target.origin
    var size   = target.size
    let posErr  = AXValueCreate(.cgPoint, &origin).map {
        AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, $0)
    }
    let sizeErr = AXValueCreate(.cgSize, &size).map {
        AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, $0)
    }
    print("       setPosition AXError=\(posErr?.rawValue ?? -1)  setSize AXError=\(sizeErr?.rawValue ?? -1)")

    // Read back to confirm
    var newPos = CGPoint.zero; var newSize = CGSize.zero
    if AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef) == .success, posRef != nil {
        AXValueGetValue(posRef as! AXValue, .cgPoint, &newPos)
    }
    if AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef) == .success, sizeRef != nil {
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &newSize)
    }
    print("       after    position=\(newPos)  size=\(newSize)")
    print()
}
