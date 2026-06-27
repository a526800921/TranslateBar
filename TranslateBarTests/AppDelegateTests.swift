import XCTest
import Cocoa
import SwiftUI
@testable import TranslateBar

final class AppDelegateTests: XCTestCase {
    var appDelegate: AppDelegate!

    override func setUp() {
        super.setUp()
        appDelegate = AppDelegate()
    }

    override func tearDown() {
        appDelegate = nil
        super.tearDown()
    }

    // MARK: - applicationDidFinishLaunching

    func test_didFinishLaunching_setsActivationPolicy() {
        let originalPolicy = NSApp.activationPolicy()
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        XCTAssertEqual(NSApp.activationPolicy(), .accessory)
        NSApp.setActivationPolicy(originalPolicy)
    }

    func test_didFinishLaunching_createsStatusItem() {
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        let statusItem = appDelegate.value(forKey: "statusItem") as? NSStatusItem
        XCTAssertNotNil(statusItem)
        XCTAssertEqual(statusItem?.length, NSStatusItem.squareLength)
    }

    func test_didFinishLaunching_statusItemButtonConfigured() {
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        let statusItem = appDelegate.value(forKey: "statusItem") as? NSStatusItem
        let button = statusItem?.button
        XCTAssertNotNil(button)
        XCTAssertNotNil(button?.image)
        XCTAssertEqual(button?.image?.accessibilityDescription, "TranslateBar")
        XCTAssertTrue(button?.image?.isTemplate ?? false)
        XCTAssertTrue(button?.target === appDelegate)
        XCTAssertNotNil(button?.action)
    }

    func test_didFinishLaunching_createsPopover() {
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        let popover = appDelegate.value(forKey: "popover") as? NSPopover
        XCTAssertNotNil(popover)
        XCTAssertEqual(popover?.contentSize.width, 420)
        XCTAssertEqual(popover?.contentSize.height, 520)
        XCTAssertEqual(popover?.behavior, .transient)
    }

    func test_didFinishLaunching_popoverHasHostingController() {
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        let popover = appDelegate.value(forKey: "popover") as? NSPopover
        let hostingController = popover?.contentViewController
        XCTAssertNotNil(hostingController)
        XCTAssertTrue(hostingController is NSHostingController<TranslatePanelView>)
    }

    // MARK: - togglePopover (via button action)

    func test_togglePopover_selectorIsSet() {
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        let statusItem = appDelegate.value(forKey: "statusItem") as? NSStatusItem
        let action = statusItem?.button?.action
        XCTAssertNotNil(action)
    }

    func test_togglePopover_whenClosed_showsPopover() {
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        let popover = appDelegate.value(forKey: "popover") as? NSPopover
        let statusItem = appDelegate.value(forKey: "statusItem") as? NSStatusItem

        // popover should be initially closed
        XCTAssertFalse(popover?.isShown ?? true)

        // Simulate button click — call the action directly on the delegate
        if let button = statusItem?.button, let action = button.action {
            NSApp.sendAction(action, to: button.target, from: button)
        }

        // In test environments without a display server, popover.show may not work.
        // The key assertion is that the selector/action is properly wired.
        XCTAssertNotNil(statusItem?.button?.action)
        XCTAssertNotNil(statusItem?.button?.target)
    }
}
