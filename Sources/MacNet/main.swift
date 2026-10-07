import AppKit

let app = NSApplication.shared
// `NSApplication.delegate` is weak; this global keeps the delegate alive.
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // menu bar only: no Dock icon, no app menu
app.run()
