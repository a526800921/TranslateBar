import Combine
import Foundation

/// 封装 TranslatePanelView 的所有用户设置，支持注入自定义 UserDefaults 以便测试隔离。
@MainActor
final class TranslatePanelSettings: ObservableObject {
    @Published var provider: String
    @Published var endpoint: String
    @Published var model: String
    @Published var streamingEnabled: Bool
    @Published var cloudEndpoint: String
    @Published var cloudModel: String
    @Published var cloudAPIKey: String

    let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    init(defaults: UserDefaults = TranslationConfiguration.persisted) {
        self.defaults = defaults
        self.provider = defaults.string(forKey: TranslationConfiguration.Keys.provider) ?? TranslationProvider.local.rawValue
        self.endpoint = defaults.string(forKey: TranslationConfiguration.Keys.endpoint) ?? TranslationConfiguration.defaultEndpoint
        self.model = defaults.string(forKey: TranslationConfiguration.Keys.model) ?? TranslationConfiguration.defaultModel
        self.streamingEnabled = defaults.bool(forKey: TranslationConfiguration.Keys.streamingEnabled)
        self.cloudEndpoint = defaults.string(forKey: TranslationConfiguration.Keys.cloudEndpoint) ?? TranslationConfiguration.defaultCloudEndpoint
        self.cloudModel = defaults.string(forKey: TranslationConfiguration.Keys.cloudModel) ?? TranslationConfiguration.defaultCloudModel
        self.cloudAPIKey = defaults.string(forKey: TranslationConfiguration.Keys.cloudAPIKey) ?? ""

        // 每次 @Published 值变化时自动写回 UserDefaults
        $provider.sink { [weak self] in self?.defaults.set($0, forKey: TranslationConfiguration.Keys.provider) }
            .store(in: &cancellables)
        $endpoint.sink { [weak self] in self?.defaults.set($0, forKey: TranslationConfiguration.Keys.endpoint) }
            .store(in: &cancellables)
        $model.sink { [weak self] in self?.defaults.set($0, forKey: TranslationConfiguration.Keys.model) }
            .store(in: &cancellables)
        $streamingEnabled.sink { [weak self] in self?.defaults.set($0, forKey: TranslationConfiguration.Keys.streamingEnabled) }
            .store(in: &cancellables)
        $cloudEndpoint.sink { [weak self] in self?.defaults.set($0, forKey: TranslationConfiguration.Keys.cloudEndpoint) }
            .store(in: &cancellables)
        $cloudModel.sink { [weak self] in self?.defaults.set($0, forKey: TranslationConfiguration.Keys.cloudModel) }
            .store(in: &cancellables)
        $cloudAPIKey.sink { [weak self] in self?.defaults.set($0, forKey: TranslationConfiguration.Keys.cloudAPIKey) }
            .store(in: &cancellables)
    }
}
