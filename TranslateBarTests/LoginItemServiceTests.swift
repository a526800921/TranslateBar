import XCTest
import ServiceManagement
@testable import TranslateBar

@MainActor
final class LoginItemServiceTests: XCTestCase {
    var service: LoginItemService!
    var mockSM: MockSMAppService!

    override func setUp() {
        super.setUp()
        mockSM = MockSMAppService()
        service = LoginItemService(service: mockSM)
    }

    override func tearDown() {
        mockSM = nil
        service = nil
        super.tearDown()
    }

    // MARK: - refresh()

    func test_refresh_enabled() {
        mockSM.mockStatus = .enabled
        service.refresh()
        XCTAssertTrue(service.isEnabled)
        XCTAssertNil(service.statusMessage)
    }

    func test_refresh_notRegistered() {
        mockSM.mockStatus = .notRegistered
        service.refresh()
        XCTAssertFalse(service.isEnabled)
        XCTAssertNil(service.statusMessage)
    }

    func test_refresh_requiresApproval() {
        mockSM.mockStatus = .requiresApproval
        service.refresh()
        XCTAssertFalse(service.isEnabled)
        XCTAssertTrue(service.statusMessage?.contains("等待系统批准") ?? false)
    }

    func test_refresh_notFound() {
        mockSM.mockStatus = .notFound
        service.refresh()
        XCTAssertFalse(service.isEnabled)
        XCTAssertTrue(service.statusMessage?.contains("未找到") ?? false)
    }

    // MARK: - toggle()

    func test_toggle_whenEnabled_callsDisable() {
        mockSM.mockStatus = .enabled
        service.refresh()
        XCTAssertTrue(service.isEnabled)

        service.toggle()
        XCTAssertFalse(service.isEnabled)
    }

    func test_toggle_whenDisabled_callsEnable() {
        mockSM.mockStatus = .notRegistered
        service.refresh()
        XCTAssertFalse(service.isEnabled)

        service.toggle()
        XCTAssertTrue(service.isEnabled)
    }

    // MARK: - enable()

    func test_enable_success() {
        service.enable()
        XCTAssertTrue(service.isEnabled)
        XCTAssertNil(service.statusMessage)
    }

    func test_enable_failure() {
        mockSM.registerShouldThrow = true
        mockSM.mockStatus = .notRegistered
        service.refresh()
        XCTAssertFalse(service.isEnabled)

        service.enable()
        // enable() 失败后 status 不变，isEnabled 应为 false
        XCTAssertFalse(service.isEnabled)
    }

    // MARK: - disable()

    func test_disable_success() {
        mockSM.mockStatus = .enabled
        service.refresh()
        XCTAssertTrue(service.isEnabled)

        service.disable()
        XCTAssertFalse(service.isEnabled)
        XCTAssertNil(service.statusMessage)
    }

    func test_disable_failure() {
        mockSM.unregisterShouldThrow = true
        mockSM.mockStatus = .enabled
        service.refresh()

        service.disable()
        // disable() 失败后 status 不变（mock 保持 .enabled）
        XCTAssertTrue(service.isEnabled)
    }

    // MARK: - LoginItemError

    func test_loginItemError_registerFailed() {
        let error = LoginItemService.LoginItemError.registerFailed("test reason")
        XCTAssertTrue(error.errorDescription?.contains("无法启用登录项") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("test reason") ?? false)
    }

    func test_loginItemError_unregisterFailed() {
        let error = LoginItemService.LoginItemError.unregisterFailed("test reason")
        XCTAssertTrue(error.errorDescription?.contains("无法关闭登录项") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("test reason") ?? false)
    }

    func test_loginItemError_notAuthorized() {
        let error = LoginItemService.LoginItemError.notAuthorized
        XCTAssertTrue(error.errorDescription?.contains("没有权限") ?? false)
    }
}
