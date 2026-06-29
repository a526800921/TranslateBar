import XCTest
@testable import TranslateBar

@MainActor
final class ModelListServiceTests: XCTestCase {
    var service: ModelListService!
    var mockSession: MockURLSession!

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        service = ModelListService(session: mockSession)
        TranslationConfiguration.persisted.set("local", forKey: TranslationConfiguration.Keys.provider)
        TranslationConfiguration.persisted.set("http://127.0.0.1:8787/v1/chat/completions", forKey: TranslationConfiguration.Keys.endpoint)
        TranslationConfiguration.persisted.set("/path/to/model", forKey: TranslationConfiguration.Keys.model)
    }

    override func tearDown() {
        TranslationConfiguration.persisted.removeObject(forKey: TranslationConfiguration.Keys.provider)
        TranslationConfiguration.persisted.removeObject(forKey: TranslationConfiguration.Keys.endpoint)
        TranslationConfiguration.persisted.removeObject(forKey: TranslationConfiguration.Keys.model)
        TranslationConfiguration.persisted.removeObject(forKey: TranslationConfiguration.Keys.cloudAPIKey)
        TranslationConfiguration.persisted.removeObject(forKey: TranslationConfiguration.Keys.cloudEndpoint)
        mockSession = nil
        service = nil
        super.tearDown()
    }

    // MARK: - fetchModels success

    func test_fetchModels_successWithModels() async {
        let json = #"{"data":[{"id":"model-a"},{"id":"model-b"}]}"#
        mockSession.mockData = json.data(using: .utf8)
        mockSession.mockResponse = MockURLSession.successResponse()

        await service.fetchModels()

        XCTAssertEqual(service.models, ["model-a", "model-b"])
        XCTAssertNil(service.errorMessage)
        XCTAssertFalse(service.isLoading)
    }

    func test_fetchModels_successEmptyList() async {
        let json = #"{"data":[]}"#
        mockSession.mockData = json.data(using: .utf8)
        mockSession.mockResponse = MockURLSession.successResponse()

        await service.fetchModels()

        XCTAssertTrue(service.models.isEmpty)
        XCTAssertNotNil(service.errorMessage)
        XCTAssertTrue(service.errorMessage?.contains("空") ?? false)
        XCTAssertFalse(service.isLoading)
    }

    // MARK: - fetchModels errors

    func test_fetchModels_invalidEndpoint() async {
        TranslationConfiguration.persisted.set("not-a-url", forKey: TranslationConfiguration.Keys.endpoint)

        await service.fetchModels()

        XCTAssertNotNil(service.errorMessage)
        XCTAssertFalse(service.isLoading)
    }

    func test_fetchModels_httpError() async {
        mockSession.mockData = "error".data(using: .utf8)
        mockSession.mockResponse = MockURLSession.successResponse(statusCode: 500)

        await service.fetchModels()

        XCTAssertNotNil(service.errorMessage)
        XCTAssertTrue(service.errorMessage?.contains("500") ?? false)
        XCTAssertFalse(service.isLoading)
    }

    func test_fetchModels_notHTTPResponse() async {
        mockSession.mockData = Data()
        mockSession.mockResponse = URLResponse(url: URL(string: "http://test")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)

        await service.fetchModels()

        XCTAssertNotNil(service.errorMessage)
        XCTAssertTrue(service.errorMessage?.contains("无法连接") ?? false)
        XCTAssertFalse(service.isLoading)
    }

    func test_fetchModels_networkError() async {
        mockSession.mockError = URLError(.cannotConnectToHost)

        await service.fetchModels()

        XCTAssertNotNil(service.errorMessage)
        XCTAssertTrue(service.errorMessage?.contains("模型列表失败") ?? false)
        XCTAssertFalse(service.isLoading)
    }

    // MARK: - isLoading lifecycle

    func test_fetchModels_isLoadingTransitions() async {
        let json = #"{"data":[{"id":"m"}]}"#
        mockSession.mockData = json.data(using: .utf8)
        mockSession.mockResponse = MockURLSession.successResponse()

        XCTAssertFalse(service.isLoading)
        await service.fetchModels()
        XCTAssertFalse(service.isLoading)
    }

    // MARK: - DeepSeek auth

    func test_fetchModels_deepseekAddsAuthorizationHeader() async {
        TranslationConfiguration.persisted.set("deepseek", forKey: TranslationConfiguration.Keys.provider)
        TranslationConfiguration.persisted.set("https://api.deepseek.com/v1/chat/completions", forKey: TranslationConfiguration.Keys.cloudEndpoint)
        TranslationConfiguration.persisted.set("sk-test-key", forKey: TranslationConfiguration.Keys.cloudAPIKey)

        let json = #"{"data":[{"id":"deepseek-chat"}]}"#
        mockSession.mockData = json.data(using: .utf8)
        mockSession.mockResponse = MockURLSession.successResponse(url: URL(string: "https://api.deepseek.com/v1/models")!)

        await service.fetchModels()

        let lastRequest = mockSession.lastDataRequest
        XCTAssertEqual(lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test-key")
        XCTAssertEqual(service.models, ["deepseek-chat"])
    }

    func test_fetchModels_localDoesNotAddAuthorizationHeader() async {
        // setUp already sets provider to "local"
        let json = #"{"data":[{"id":"local-model"}]}"#
        mockSession.mockData = json.data(using: .utf8)
        mockSession.mockResponse = MockURLSession.successResponse()

        await service.fetchModels()

        let lastRequest = mockSession.lastDataRequest
        XCTAssertNil(lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    func test_fetchModels_deepseekMissingAPIKeyDoesNotRequest() async {
        TranslationConfiguration.persisted.set("deepseek", forKey: TranslationConfiguration.Keys.provider)
        TranslationConfiguration.persisted.set("https://api.deepseek.com/v1/chat/completions", forKey: TranslationConfiguration.Keys.cloudEndpoint)
        // 不设置 API key

        await service.fetchModels()

        // 不应该发网络请求，lastDataRequest 应保持为 nil
        XCTAssertNil(mockSession.lastDataRequest)
        XCTAssertNotNil(service.errorMessage)
        XCTAssertTrue(service.errorMessage?.contains("API Key 未配置") ?? false)
        XCTAssertFalse(service.isLoading)
    }

    // MARK: - initial state

    func test_initialState() {
        let svc = ModelListService(session: mockSession)
        XCTAssertTrue(svc.models.isEmpty)
        XCTAssertFalse(svc.isLoading)
        XCTAssertNil(svc.errorMessage)
    }
}
