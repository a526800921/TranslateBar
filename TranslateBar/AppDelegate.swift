import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    @objc private var statusItem: NSStatusItem?
    @objc private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.image = menuBarIcon(text: "译")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePopover)
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: TranslatePanelView()
        )
        self.popover = popover
    }

    /// 生成文字菜单栏图标
    private func menuBarIcon(text: String) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.isTemplate = true

        image.lockFocus()

        // 圆角边框
        let inset: CGFloat = 1
        let borderRect = NSRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
        let path = NSBezierPath(roundedRect: borderRect, xRadius: 4, yRadius: 4)
        path.lineWidth = 1.2
        NSColor.black.setStroke()
        path.stroke()

        // 文字
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.black
        ]

        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)
        image.unlockFocus()

        return image
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
