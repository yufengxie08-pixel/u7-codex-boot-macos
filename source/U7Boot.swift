import AppKit
import AVFoundation
import CoreGraphics

private let codexBundleID = "com.openai.codex"
private let holdAt = 5.25
private let fadeAt = 5.75
private let fadeDuration = 0.55

final class BootWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class BootController: NSObject, NSApplicationDelegate {
    private var window: BootWindow!
    private var player: AVPlayer!
    private var timer: Timer?
    private var status: NSTextField!
    private var started = Date()
    private var appReadySince: Date?
    private var holding = false
    private var finishing = false
    private var activatedTarget = false
    private var keyMonitor: Any?
    private var targetApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let video = Bundle.main.url(forResource: "startup", withExtension: "mp4") else {
            showError("找不到 startup.mp4")
            return
        }
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: codexBundleID) != nil else {
            showError("这台 Mac 没有找到 Codex 应用。")
            return
        }

        let area = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)
        let width = min(1280, area.width * 0.94)
        let height = width * 9 / 16
        let rect = NSRect(x: area.midX - width / 2, y: area.midY - height / 2,
                          width: width, height: height)
        window = BootWindow(contentRect: rect, styleMask: [.borderless],
                            backing: .buffered, defer: false)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = NSColor(calibratedRed: 0.025, green: 0.043, blue: 0.09, alpha: 1)
        window.isOpaque = true
        window.hasShadow = true

        let view = NSView(frame: NSRect(origin: .zero, size: rect.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = CGColor(red: 0.025, green: 0.043, blue: 0.09, alpha: 1)
        window.contentView = view

        player = AVPlayer(url: video)
        player.actionAtItemEnd = .pause
        let layer = AVPlayerLayer(player: player)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspect
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(layer)

        status = NSTextField(labelWithString: "Esc 跳过")
        status.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        status.textColor = NSColor.white.withAlphaComponent(0.5)
        status.alignment = .right
        status.frame = NSRect(x: width - 154, y: height - 37, width: 130, height: 18)
        view.addSubview(status)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.finish(); return nil }
            return event
        }
        NotificationCenter.default.addObserver(self, selector: #selector(videoEnded),
            name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        started = Date()
        openCodex()
        player.play()
        timer = Timer.scheduledTimer(timeInterval: 0.05, target: self,
                                     selector: #selector(tick), userInfo: nil, repeats: true)
    }

    private func openCodex() {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: codexBundleID).first {
            targetApp = running
            return
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: codexBundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: config) { [weak self] app, _ in
            self?.targetApp = app
            self?.window?.orderFrontRegardless()
        }
    }

    private func targetHasWindow(_ app: NSRunningApplication) -> Bool {
        // Codex can be on another Space while this floating player is visible.
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return windows.contains { item in
            guard let pid = item[kCGWindowOwnerPID as String] as? Int,
                  pid == Int(app.processIdentifier),
                  let layer = item[kCGWindowLayer as String] as? Int, layer == 0,
                  let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let w = bounds["Width"] as? Double,
                  let h = bounds["Height"] as? Double else { return false }
            return w >= 450 && h >= 280
        }
    }

    @objc private func tick() {
        if finishing { return }
        let elapsed = Date().timeIntervalSince(started)
        if elapsed > 45 {
            finish()
            return
        }
        if targetApp == nil {
            targetApp = NSRunningApplication.runningApplications(withBundleIdentifier: codexBundleID).first
        }
        if let app = targetApp, !app.isTerminated, targetHasWindow(app) {
            if appReadySince == nil { appReadySince = Date() }
        } else {
            appReadySince = nil
        }
        let ready = appReadySince.map { Date().timeIntervalSince($0) > 0.5 } ?? false
        let t = player.currentTime().seconds
        guard t.isFinite else { return }
        if t >= holdAt && !ready {
            if !holding {
                player.pause()
                player.seek(to: CMTime(seconds: holdAt, preferredTimescale: 600),
                            toleranceBefore: .zero, toleranceAfter: .zero)
                holding = true
                status.stringValue = "正在等待 Codex…   Esc 跳过"
                status.frame.origin.x = window.frame.width - 262
                status.frame.size.width = 238
            }
            return
        }
        if holding && ready {
            holding = false
            status.stringValue = "Esc 跳过"
            status.frame.origin.x = window.frame.width - 154
            status.frame.size.width = 130
            player.play()
        }
        if t >= fadeAt {
            if !activatedTarget, let app = targetApp {
                app.activate()
                activatedTarget = true
            }
            window.alphaValue = CGFloat(1 - min(1, (t - fadeAt) / fadeDuration))
        }
        if t >= fadeAt + fadeDuration { finish() }
    }

    @objc private func videoEnded() { finish() }

    private func finish() {
        guard !finishing else { return }
        finishing = true
        timer?.invalidate()
        player?.pause()
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
        window?.orderOut(nil)
        if let app = targetApp, !app.isTerminated {
            app.activate()
        }
        NSApp.terminate(nil)
    }

    private func showError(_ text: String) {
        let alert = NSAlert()
        alert.messageText = "U7 Codex Boot"
        alert.informativeText = text
        alert.runModal()
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = BootController()
app.delegate = controller
app.run()
