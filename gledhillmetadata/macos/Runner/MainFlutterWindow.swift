import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  private static let savedFrameKey = "GledhillMetadataMainWindowFrame"
  private static let legacyAutosaveKey = "NSWindow Frame GledhillMetadataMainWindow"
  private static let minimumWindowSize = NSSize(width: 760, height: 520)
  private static let preferredWindowSize = NSSize(width: 1200, height: 820)

  private var didFinishRestoringFrame = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.minSize = Self.minimumWindowSize
    self.delegate = self
    UserDefaults.standard.removeObject(forKey: Self.legacyAutosaveKey)

    let restoredFrame = Self.restoredFrame() ?? Self.defaultFrame(fallback: windowFrame)
    self.contentViewController = flutterViewController
    self.setFrame(restoredFrame, display: true)
    didFinishRestoringFrame = true

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  func windowDidMove(_ notification: Notification) {
    saveFrameIfReady()
  }

  func windowDidResize(_ notification: Notification) {
    saveFrameIfReady()
  }

  func windowWillClose(_ notification: Notification) {
    saveFrame()
  }

  private func saveFrameIfReady() {
    if didFinishRestoringFrame {
      saveFrame()
    }
  }

  private func saveFrame() {
    UserDefaults.standard.set(NSStringFromRect(self.frame), forKey: Self.savedFrameKey)
  }

  private static func restoredFrame() -> NSRect? {
    guard let savedFrameString = UserDefaults.standard.string(forKey: savedFrameKey) else {
      return nil
    }

    let savedFrame = NSRectFromString(savedFrameString)
    guard savedFrame.width >= minimumWindowSize.width && savedFrame.height >= minimumWindowSize.height else {
      UserDefaults.standard.removeObject(forKey: savedFrameKey)
      return nil
    }

    return normalizedFrame(savedFrame)
  }

  private static func defaultFrame(fallback: NSRect) -> NSRect {
    guard let screen = NSScreen.main else {
      return normalizedFrame(fallback)
    }

    let visibleFrame = screen.visibleFrame
    let width = min(preferredWindowSize.width, visibleFrame.width)
    let height = min(preferredWindowSize.height, visibleFrame.height)
    let x = visibleFrame.midX - width / 2
    let y = visibleFrame.midY - height / 2

    return normalizedFrame(NSRect(x: x, y: y, width: width, height: height))
  }

  private static func normalizedFrame(_ frame: NSRect) -> NSRect {
    guard let screen = screen(for: frame) else {
      return frame
    }

    let visibleFrame = screen.visibleFrame
    let width = min(max(frame.width, minimumWindowSize.width), visibleFrame.width)
    let height = min(max(frame.height, minimumWindowSize.height), visibleFrame.height)
    let maxX = visibleFrame.maxX - width
    let maxY = visibleFrame.maxY - height
    let x = min(max(frame.origin.x, visibleFrame.minX), maxX)
    let y = min(max(frame.origin.y, visibleFrame.minY), maxY)

    return NSRect(x: x, y: y, width: width, height: height)
  }

  private static func screen(for frame: NSRect) -> NSScreen? {
    if let containingScreen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) }) {
      return containingScreen
    }

    return NSScreen.main
  }
}
