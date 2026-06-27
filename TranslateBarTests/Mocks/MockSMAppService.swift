import Foundation
import ServiceManagement
@testable import TranslateBar

/// Mock SMAppService，用于 LoginItemService 的单元测试。
final class MockSMAppService: SMAppServiceProtocol {
    var mockStatus: SMAppService.Status = .notRegistered
    var registerShouldThrow = false
    var unregisterShouldThrow = false
    var registerError: Error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "注册失败"])
    var unregisterError: Error = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "取消注册失败"])

    var status: SMAppService.Status {
        mockStatus
    }

    func register() throws {
        if registerShouldThrow {
            throw registerError
        }
        mockStatus = .enabled
    }

    func unregister() throws {
        if unregisterShouldThrow {
            throw unregisterError
        }
        mockStatus = .notRegistered
    }
}
