import Foundation

struct TranslationConfiguration {
    /// 固定 suite 共享 UserDefaults，避免 ad-hoc 签名变化导致存储域丢失
    static let persisted = UserDefaults(suiteName: "com.translatebar.app") ?? .standard
    enum Keys {
        static let endpoint = "translationEndpoint"
        static let model = "translationModel"
        static let streamingEnabled = "translationStreamingEnabled"
        static let provider = "translationProvider"
        static let cloudAPIKey = "translationCloudAPIKey"
        static let cloudEndpoint = "translationCloudEndpoint"
        static let cloudModel = "translationCloudModel"
        static let cloudTimeoutSeconds = "translationCloudTimeoutSeconds"
    }

    static let defaultEndpoint = "http://127.0.0.1:8787/v1/chat/completions"
    static let defaultModel = "/Users/jafish/Documents/models/Hy-MT2-7B-4bit"
    static let defaultProvider = TranslationProvider.local
    static let defaultCloudEndpoint = "https://api.deepseek.com/v1/chat/completions"
    static let defaultCloudModel = "deepseek-v4-flash"
    static let defaultCloudTimeoutSeconds = 30.0

    let provider: TranslationProvider
    let endpointString: String
    let model: String
    let streamingEnabled: Bool
    let apiKey: String?
    let timeoutInterval: TimeInterval

    var endpoint: URL? {
        URL(string: endpointString)
    }

    /// 从 chat endpoint 推导 /v1/models endpoint。
    /// 例如 `http://127.0.0.1:8787/v1/chat/completions` → `http://127.0.0.1:8787/v1/models`
    var modelsEndpoint: URL? {
        guard let endpoint = endpoint else { return nil }

        guard endpoint.path.hasSuffix("/v1/chat/completions") else {
            return nil
        }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.path = "/v1/models"
        return components?.url
    }

    static func current(defaults: UserDefaults = persisted) -> TranslationConfiguration {
        let providerRaw = defaults.string(forKey: Keys.provider) ?? ""
        let provider = TranslationProvider(rawValue: providerRaw) ?? defaultProvider

        let endpoint: String
        let model: String

        switch provider {
        case .local:
            endpoint = defaults.string(forKey: Keys.endpoint) ?? defaultEndpoint
            model = defaults.string(forKey: Keys.model) ?? defaultModel
        case .deepseek:
            endpoint = defaults.string(forKey: Keys.cloudEndpoint) ?? defaultCloudEndpoint
            model = defaults.string(forKey: Keys.cloudModel) ?? defaultCloudModel
        }

        let streamingEnabled = defaults.bool(forKey: Keys.streamingEnabled)
        let apiKey = defaults.string(forKey: Keys.cloudAPIKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let timeoutInterval: TimeInterval
        switch provider {
        case .local:
            timeoutInterval = 120
        case .deepseek:
            let val = defaults.double(forKey: Keys.cloudTimeoutSeconds)
            timeoutInterval = val > 0 ? val : defaultCloudTimeoutSeconds
        }

        return TranslationConfiguration(
            provider: provider,
            endpointString: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            streamingEnabled: streamingEnabled,
            apiKey: apiKey,
            timeoutInterval: timeoutInterval
        )
    }
}
