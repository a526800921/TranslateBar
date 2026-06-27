import Foundation

struct TranslationConfiguration {
    enum Keys {
        static let endpoint = "translationEndpoint"
        static let model = "translationModel"
    }

    static let defaultEndpoint = "http://127.0.0.1:8787/v1/chat/completions"
    static let defaultModel = "/Users/jafish/Documents/models/Hy-MT2-7B-4bit"

    let endpointString: String
    let model: String

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

    static func current(defaults: UserDefaults = .standard) -> TranslationConfiguration {
        let endpoint = defaults.string(forKey: Keys.endpoint) ?? defaultEndpoint
        let model = defaults.string(forKey: Keys.model) ?? defaultModel

        return TranslationConfiguration(
            endpointString: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
