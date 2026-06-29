import XCTest
@testable import TranslateBar

final class TranslationConfigurationTests: XCTestCase {
    var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "TranslationConfigurationTests")
        defaults.removePersistentDomain(forName: "TranslationConfigurationTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "TranslationConfigurationTests")
        defaults = nil
        super.tearDown()
    }

    // MARK: - Defaults

    func test_defaultEndpoint() {
        XCTAssertEqual(TranslationConfiguration.defaultEndpoint, "http://127.0.0.1:8787/v1/chat/completions")
    }

    func test_defaultModel() {
        XCTAssertEqual(TranslationConfiguration.defaultModel, "/Users/jafish/Documents/models/Hy-MT2-7B-4bit")
    }

    func test_defaultProviderIsLocal() {
        XCTAssertEqual(TranslationConfiguration.defaultProvider, .local)
    }

    func test_defaultCloudEndpoint() {
        XCTAssertEqual(TranslationConfiguration.defaultCloudEndpoint, "https://api.deepseek.com/v1/chat/completions")
    }

    func test_defaultCloudModel() {
        XCTAssertEqual(TranslationConfiguration.defaultCloudModel, "deepseek-v4-flash")
    }

    func test_defaultCloudDisableThinking() {
        XCTAssertTrue(TranslationConfiguration.defaultCloudDisableThinking)
    }

    func test_keysMatchAppStorage() {
        XCTAssertEqual(TranslationConfiguration.Keys.endpoint, "translationEndpoint")
        XCTAssertEqual(TranslationConfiguration.Keys.model, "translationModel")
        XCTAssertEqual(TranslationConfiguration.Keys.streamingEnabled, "translationStreamingEnabled")
        XCTAssertEqual(TranslationConfiguration.Keys.provider, "translationProvider")
        XCTAssertEqual(TranslationConfiguration.Keys.cloudAPIKey, "translationCloudAPIKey")
        XCTAssertEqual(TranslationConfiguration.Keys.cloudEndpoint, "translationCloudEndpoint")
        XCTAssertEqual(TranslationConfiguration.Keys.cloudModel, "translationCloudModel")
        XCTAssertEqual(TranslationConfiguration.Keys.cloudDisableThinking, "translationCloudDisableThinking")
    }

    // MARK: - current(from:) — local provider

    func test_current_allKeysPresent() {
        defaults.set("local", forKey: TranslationConfiguration.Keys.provider)
        defaults.set("http://custom:8080/v1/chat/completions", forKey: TranslationConfiguration.Keys.endpoint)
        defaults.set("/path/to/model", forKey: TranslationConfiguration.Keys.model)
        defaults.set(true, forKey: TranslationConfiguration.Keys.streamingEnabled)

        let config = TranslationConfiguration.current(defaults: defaults)
        XCTAssertEqual(config.provider, .local)
        XCTAssertEqual(config.endpointString, "http://custom:8080/v1/chat/completions")
        XCTAssertEqual(config.model, "/path/to/model")
        XCTAssertTrue(config.streamingEnabled)
    }

    func test_current_missingKeysFallbackToDefaults() {
        let config = TranslationConfiguration.current(defaults: defaults)
        XCTAssertEqual(config.provider, .local)
        XCTAssertEqual(config.endpointString, TranslationConfiguration.defaultEndpoint)
        XCTAssertEqual(config.model, TranslationConfiguration.defaultModel)
        XCTAssertFalse(config.streamingEnabled)
    }

    func test_current_trimsWhitespace() {
        defaults.set("local", forKey: TranslationConfiguration.Keys.provider)
        defaults.set("  http://example.com/v1/chat/completions  ", forKey: TranslationConfiguration.Keys.endpoint)
        defaults.set("  /model/path  ", forKey: TranslationConfiguration.Keys.model)

        let config = TranslationConfiguration.current(defaults: defaults)
        XCTAssertEqual(config.endpointString, "http://example.com/v1/chat/completions")
        XCTAssertEqual(config.model, "/model/path")
    }

    func test_current_streamingEnabledTrue() {
        defaults.set(true, forKey: TranslationConfiguration.Keys.streamingEnabled)
        let config = TranslationConfiguration.current(defaults: defaults)
        XCTAssertTrue(config.streamingEnabled)
    }

    func test_current_streamingEnabledFalse() {
        defaults.set(false, forKey: TranslationConfiguration.Keys.streamingEnabled)
        let config = TranslationConfiguration.current(defaults: defaults)
        XCTAssertFalse(config.streamingEnabled)
    }

    // MARK: - current(from:) — DeepSeek provider

    func test_current_deepseekDefaults() {
        defaults.set("deepseek", forKey: TranslationConfiguration.Keys.provider)

        let config = TranslationConfiguration.current(defaults: defaults)
        XCTAssertEqual(config.provider, .deepseek)
        XCTAssertEqual(config.endpointString, TranslationConfiguration.defaultCloudEndpoint)
        XCTAssertEqual(config.model, TranslationConfiguration.defaultCloudModel)
        XCTAssertNil(config.apiKey)
        XCTAssertTrue(config.disableThinking)
    }

    func test_current_deepseekReadsAPIKeyFromDefaults() {
        defaults.set("deepseek", forKey: TranslationConfiguration.Keys.provider)
        defaults.set("sk-test-key-123", forKey: TranslationConfiguration.Keys.cloudAPIKey)

        let config = TranslationConfiguration.current(defaults: defaults)
        XCTAssertEqual(config.apiKey, "sk-test-key-123")
    }

    func test_current_deepseekTrimsAPIKey() {
        defaults.set("deepseek", forKey: TranslationConfiguration.Keys.provider)
        defaults.set("  sk-test-key-456  ", forKey: TranslationConfiguration.Keys.cloudAPIKey)

        let config = TranslationConfiguration.current(defaults: defaults)
        XCTAssertEqual(config.apiKey, "sk-test-key-456")
    }

    func test_current_deepseekMissingAPIKey() {
        defaults.set("deepseek", forKey: TranslationConfiguration.Keys.provider)
        // 不设置 API key
        let config = TranslationConfiguration.current(defaults: defaults)
        XCTAssertNil(config.apiKey)
    }

    func test_current_deepseekDisableThinkingFalse() {
        defaults.set("deepseek", forKey: TranslationConfiguration.Keys.provider)
        defaults.set(false, forKey: TranslationConfiguration.Keys.cloudDisableThinking)

        let config = TranslationConfiguration.current(defaults: defaults)
        XCTAssertFalse(config.disableThinking)
    }

    // MARK: - endpoint (computed)

    func test_endpoint_validURL() {
        let config = makeConfig(endpointString: "http://127.0.0.1:8787/v1/chat/completions")
        XCTAssertNotNil(config.endpoint)
        XCTAssertEqual(config.endpoint?.absoluteString, "http://127.0.0.1:8787/v1/chat/completions")
    }

    func test_endpoint_validURLWithDifferentPort() {
        let config = makeConfig(endpointString: "http://localhost:9999/v1/chat/completions")
        XCTAssertNotNil(config.endpoint)
        XCTAssertEqual(config.endpoint?.port, 9999)
    }

    func test_endpoint_emptyString() {
        let config = makeConfig(endpointString: "")
        XCTAssertNil(config.endpoint)
    }

    // MARK: - modelsEndpoint (computed)

    func test_modelsEndpoint_standardChatPath() {
        let config = makeConfig(endpointString: "http://127.0.0.1:8787/v1/chat/completions")
        XCTAssertEqual(config.modelsEndpoint?.absoluteString, "http://127.0.0.1:8787/v1/models")
    }

    func test_modelsEndpoint_nonStandardPath() {
        let config = makeConfig(endpointString: "http://127.0.0.1:8787/custom/endpoint")
        XCTAssertNil(config.modelsEndpoint)
    }

    func test_modelsEndpoint_nilEndpoint() {
        let config = makeConfig(endpointString: "invalid url")
        XCTAssertNil(config.modelsEndpoint)
    }

    func test_modelsEndpoint_preservesSchemeAndHost() {
        let config = makeConfig(endpointString: "https://api.example.com/v1/chat/completions")
        XCTAssertEqual(config.modelsEndpoint?.absoluteString, "https://api.example.com/v1/models")
    }

    // MARK: - Helpers

    private func makeConfig(
        endpointString: String,
        model: String = "m",
        provider: TranslationProvider = .local
    ) -> TranslationConfiguration {
        TranslationConfiguration(
            provider: provider,
            endpointString: endpointString,
            model: model,
            streamingEnabled: false,
            apiKey: nil,
            disableThinking: true,
            timeoutInterval: 120
        )
    }
}
