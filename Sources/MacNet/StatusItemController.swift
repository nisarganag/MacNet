import AppKit
import MacNetCore
import os
import SwiftUI

private let log = Logger(subsystem: "com.nisarganag.macnet", category: "panel")

/// Owns the menu bar item: draws the speed label and shows or hides the panel.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let makePanelContent: (PanelNavigation) -> AnyView
    /// Nil whenever the panel is closed — see `openPanel`.
    private var panel: GlassPanel?
    private var navigation: PanelNavigation?
    private var dismissMonitors: [Any] = []
    private var activationObserver: NSObjectProtocol?
    private var shownLabel: Label?

    private struct Label: Equatable {
        let upload: CompactSpeed
        let download: CompactSpeed
        let style: UnitStyle
    }

    init(makePanelContent: @escaping (PanelNavigation) -> AnyView) {
        self.makePanelContent = makePanelContent
        super.init()
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePanel)
        button.imagePosition = .imageOnly
        show(.zero, style: .bytes)
    }

    /// Redraws only when the visible text changes: most seconds it doesn't,
    /// and an unchanged image is free.
    func show(_ rate: Throughput, style: UnitStyle) {
        let label = Label(upload: SpeedFormatter.compact(bytesPerSecond: rate.upload, style: style),
                          download: SpeedFormatter.compact(bytesPerSecond: rate.download, style: style),
                          style: style)
        guard label != shownLabel, let button = statusItem.button else { return }
        shownLabel = label
        button.image = MenuBarLabelRenderer.image(upload: label.upload, download: label.download, style: style)

        let up = SpeedFormatter.detailed(bytesPerSecond: rate.upload, style: style)
        let down = SpeedFormatter.detailed(bytesPerSecond: rate.download, style: style)
        button.toolTip = "Upload \(up.number) \(up.unit)\nDownload \(down.number) \(down.unit)"
        button.setAccessibilityLabel(
            "Upload \(up.number) \(SpeedFormatter.spokenUnit(up.unit)), "
                + "download \(down.number) \(SpeedFormatter.spokenUnit(down.unit))")
    }

    var isPanelShown: Bool { panel?.isVisible ?? false }

    @objc private func togglePanel() {
        if isPanelShown { closePanel() } else { openPanel(.monitor) }
    }

    /// Builds the panel's SwiftUI tree on open; `closePanel` destroys it.
    /// A hidden tree that doesn't exist can't spend CPU re-rendering live
    /// graphs nobody can see, and rebuilding one small view costs nothing.
    func openPanel(_ page: PanelPage) {
        guard panel == nil, let button = statusItem.button else { return }
        let panel = GlassPanel(size: Theme.panelSize)
        let navigation = PanelNavigation(page: page)
        self.navigation = navigation
        let host = NSHostingView(rootView: makePanelContent(navigation))
        host.frame = NSRect(origin: .zero, size: Theme.panelSize)
        // `wantsLayer` first: `layer` is nil until it is set. The window is a
        // rectangle; only this mask keeps its corners from showing around
        // the rounded glass.
        host.wantsLayer = true
        host.layer?.backgroundColor = .clear
        host.layer?.cornerRadius = Theme.cornerRadius
        host.layer?.cornerCurve = .continuous
        host.layer?.masksToBounds = true
        panel.contentView = host

        position(panel, under: button)
        log.notice("open \(String(describing: page), privacy: .public): item window \(String(describing: button.window?.frame), privacy: .public), panel \(String(describing: panel.frame), privacy: .public)")
        panel.orderFrontRegardless()
        panel.makeKey()
        self.panel = panel
        button.highlight(true)
        // A borderless window's shadow comes from its pixels; recompute it
        // once the rounded content has drawn, or it is cast by the square.
        panel.invalidateShadow()
        DispatchQueue.main.async { [weak panel] in panel?.invalidateShadow() }
        startDismissMonitors()
    }

    func closePanel(_ reason: String = "toggle") {
        log.notice("close: \(reason, privacy: .public)")
        stopDismissMonitors()
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
        navigation = nil
        statusItem.button?.highlight(false)
    }

    /// Centred under the item, clamped so a panel opened near the screen's
    /// edge stays fully visible.
    ///
    /// A hidden item — no room left beside the notch, or tucked away by a
    /// menu bar manager such as Bartender — sits in a zero-height window at
    /// the screen's bottom-left corner (measured on macOS 27). Anchoring to
    /// that dropped the panel into the corner, so a hidden item anchors under
    /// the pointer instead: the user just clicked there, in whichever bar is
    /// showing the item, or opened the app from Finder. Only the window's
    /// height is trusted as the signal — position checks would also misread
    /// a visible item in a full-screen Space's auto-hiding menu bar.
    private func position(_ panel: NSPanel, under button: NSStatusBarButton) {
        guard let screen = button.window?.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        var item = button.window.map { $0.convertToScreen(button.convert(button.bounds, to: nil)) } ?? .zero
        let isHidden = (button.window?.frame.height ?? 0) < 1
        if isHidden {
            item = NSRect(x: NSEvent.mouseLocation.x, y: visible.maxY, width: 0, height: 0)
        }
        let size = panel.frame.size
        var origin = NSPoint(x: item.midX - size.width / 2, y: min(item.minY, visible.maxY) - size.height - 6)
        origin.x = min(max(visible.minX + 8, origin.x), visible.maxX - size.width - 8)
        origin.y = max(visible.minY + 8, origin.y)
        panel.setFrameOrigin(origin)
    }

    /// Closes on a click anywhere else, Escape, or another app coming to the
    /// front — what a menu does.
    ///
    /// The global monitor sees clicks in other apps; the local one sees
    /// clicks in this app outside the panel. Clicks on the status item itself
    /// are left to `togglePanel`: closing here first would make the toggle
    /// read "closed" and immediately reopen it. The activation observer
    /// catches what no click does — Cmd-Tab, and the panel's own links and
    /// "Open Login Items" bringing another app forward — so the panel never
    /// floats over the window it just opened.
    private func startDismissMonitors() {
        stopDismissMonitors()
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: clicks, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.closePanel("click in another app") }
        }) {
            dismissMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: clicks, handler: { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel else { return }
                if event.window === self.statusItem.button?.window { return }
                if event.window !== panel { self.closePanel("click outside the panel") }
            }
            return event
        }) {
            dismissMonitors.append(local)
        }
        if let escape = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard event.keyCode == 53 else { return event }
            MainActor.assumeIsolated { self?.escape() }
            return nil
        }) {
            dismissMonitors.append(escape)
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let pid = app?.processIdentifier
            MainActor.assumeIsolated {
                guard pid != ProcessInfo.processInfo.processIdentifier else { return }
                self?.closePanel("another app became active")
            }
        }
    }

    /// Steps back out of Settings first; closes from the top level.
    private func escape() {
        guard let navigation else { return }
        if let previous = navigation.page.afterEscape {
            navigation.show(previous)
        } else {
            closePanel("escape")
        }
    }

    private func stopDismissMonitors() {
        dismissMonitors.forEach(NSEvent.removeMonitor)
        dismissMonitors.removeAll()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
    }
}
