import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private static let frameAutosaveKey = "MainFlutterWindow"
  private static let defaultContentSize = NSSize(width: 1280, height: 800)
  private static let minContentSize = NSSize(width: 400, height: 600)

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Match Linux/Windows minimum logical viewport so compact layouts never clip.
    self.contentMinSize = Self.minContentSize

    if !self.setFrameUsingName(Self.frameAutosaveKey) {
      var targetSize = Self.defaultContentSize
      if let visibleFrame = (self.screen ?? NSScreen.main)?.visibleFrame {
        let contentBounds = self.contentRect(forFrameRect: visibleFrame)
        targetSize.width = min(
          targetSize.width,
          max(Self.minContentSize.width, contentBounds.width)
        )
        targetSize.height = min(
          targetSize.height,
          max(Self.minContentSize.height, contentBounds.height)
        )
      }
      self.setContentSize(targetSize)
      self.center()
    }
    self.setFrameAutosaveName(Self.frameAutosaveKey)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
