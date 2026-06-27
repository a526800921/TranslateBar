import Foundation
import ServiceManagement

/// 协议抽象 SMAppService 的登录项管理能力，便于单元测试 mock。
protocol SMAppServiceProtocol {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: SMAppServiceProtocol {}
