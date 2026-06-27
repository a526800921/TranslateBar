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

    func test_keysMatchAppStorage() {
        XCTAssertEqual(TranslationConfiguration.Keys.endpoint, "translationEndpoint")
        XCTAssertEqual(TranslationConfiguration.Keys.model, "translationModel")
        XCTAssertEqual(TranslationConfiguration.Keys.streamingEnabled, "translationStreamingEnabled")
    }

    // MARK: - current(from:)

    func test_current_allKeysPresent() {
        defaults.set("http://custom:8080/v1/chat/completions", forKey: TranslationConfiguration.Keys.endpoint)
        defaults.set("/path/to/model", forKey: TranslationConfiguration.Keys.model)
        defaults.set(true, forKey: TranslationConfiguration.Keys.streamingEnabled)

        let config = TranslationConfiguration.current(defaults: defaults)
        XCTAssertEqual(config.endpointString, "http://custom:8080/v1/chat/completions")
        XCTAssertEqual(config.model, "/path/to/model")
        XCTAssertTrue(config.streamingEnabled)
    }

    func test_current_missingKeysFallbackToDefaults() {
        let config = TranslationConfiguration.current(defaults: defaults)
        XCTAssertEqual(config.endpointString, TranslationConfiguration.defaultEndpoint)
        XCTAssertEqual(config.model, TranslationConfiguration.defaultModel)
        XCTAssertFalse(config.streamingEnabled)
    }

    func test_current_trimsWhitespace() {
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

    // MARK: - endpoint (computed)

    func test_endpoint_validURL() {
        let config = TranslationConfiguration(endpointString: "http://127.0.0.1:8787/v1/chat/completions", model: "m", streamingEnabled: false)
        XCTAssertNotNil(config.endpoint)
        XCTAssertEqual(config.endpoint?.absoluteString, "http://127.0.0.1:8787/v1/chat/completions")
    }

    func test_endpoint_validURLWithDifferentPort() {
        let config = TranslationConfiguration(endpointString: "http://localhost:9999/v1/chat/completions", model: "m", streamingEnabled: false)
        XCTAssertNotNil(config.endpoint)
        XCTAssertEqual(config.endpoint?.port, 9999)
    }

    func test_endpoint_emptyString() {
        let config = TranslationConfiguration(endpointString: "", model: "m", streamingEnabled: false)
        XCTAssertNil(config.endpoint)
    }

    // MARK: - modelsEndpoint (computed)

    func test_modelsEndpoint_standardChatPath() {
        let config = TranslationConfiguration(endpointString: "http://127.0.0.1:8787/v1/chat/completions", model: "m", streamingEnabled: false)
        XCTAssertEqual(config.modelsEndpoint?.absoluteString, "http://127.0.0.1:8787/v1/models")
    }

    func test_modelsEndpoint_nonStandardPath() {
        let config = TranslationConfiguration(endpointString: "http://127.0.0.1:8787/custom/endpoint", model: "m", streamingEnabled: false)
        XCTAssertNil(config.modelsEndpoint)
    }

    func test_modelsEndpoint_nilEndpoint() {
        let config = TranslationConfiguration(endpointString: "invalid url", model: "m", streamingEnabled: false)
        XCTAssertNil(config.modelsEndpoint)
    }

    func test_modelsEndpoint_preservesSchemeAndHost() {
        let config = TranslationConfiguration(endpointString: "https://api.example.com/v1/chat/completions", model: "m", streamingEnabled: false)
        XCTAssertEqual(config.modelsEndpoint?.absoluteString, "https://api.example.com/v1/models")
    }
}
