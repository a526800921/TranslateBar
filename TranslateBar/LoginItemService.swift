import Foundation
import ServiceManagement

/// 封装 SMAppService.mainApp 的登录项操作，提供中文错误信息。
@MainActor
final class LoginItemService: ObservableObject {
    @Published var isEnabled = false
    @Published var statusMessage: String?

    private let service: SMAppServiceProtocol

    init(service: SMAppServiceProtocol = SMAppService.mainApp) {
        self.service = service
    }

    enum LoginItemError: LocalizedError {
        case registerFailed(String)
        case unregisterFailed(String)
        case notAuthorized

        var errorDescription: String? {
            switch self {
            case let .registerFailed(reason):
                return "无法启用登录项：\(reason)"
            case let .unregisterFailed(reason):
                return "无法关闭登录项：\(reason)"
            case .notAuthorized:
                return "没有权限修改登录项，请在系统设置中手动操作。"
            }
        }
    }

    /// 读取当前登录项状态并更新 isEnabled
    func refresh() {
        let status = service.status
        switch status {
        case .enabled:
            isEnabled = true
            statusMessage = nil
        case .notRegistered:
            isEnabled = false
            statusMessage = nil
        case .requiresApproval:
            isEnabled = false
            statusMessage = "登录项等待系统批准，请检查系统设置。"
        case .notFound:
            isEnabled = false
            statusMessage = "应用未找到，请重新安装。"
        @unknown default:
            isEnabled = false
            statusMessage = "未知的登录项状态。"
        }
    }

    /// 切换登录项状态
    func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }

    /// 启用登录项
    func enable() {
        do {
            try service.register()
            refresh()
        } catch {
            statusMessage = LoginItemError.registerFailed(
                error.localizedDescription
            ).localizedDescription
            refresh()
        }
    }

    /// 关闭登录项
    func disable() {
        do {
            try service.unregister()
            refresh()
        } catch {
            statusMessage = LoginItemError.unregisterFailed(
                error.localizedDescription
            ).localizedDescription
            refresh()
        }
    }
}
