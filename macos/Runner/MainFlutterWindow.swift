import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let themeBackground = NSColor(
    calibratedRed: 0.008,
    green: 0.067,
    blue: 0.043,
    alpha: 1.0
  )

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    applyThemeChrome()
    self.contentViewController = flutterViewController
    self.contentView?.wantsLayer = true
    self.contentView?.layer?.backgroundColor = themeBackground.cgColor
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    DispatchQueue.main.async {
      self.applyThemeChrome()
      self.showNativeWindowButtons()
    }
  }

  private func applyThemeChrome() {
    self.backgroundColor = themeBackground
    self.isOpaque = true
    self.appearance = NSAppearance(named: .darkAqua)
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true
    showNativeWindowButtons()
  }

  private func showNativeWindowButtons() {
    self.standardWindowButton(.closeButton)?.isHidden = false
    self.standardWindowButton(.miniaturizeButton)?.isHidden = false
    self.standardWindowButton(.zoomButton)?.isHidden = false
  }
}
