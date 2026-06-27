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
        UserDefaults.standard.set("http://127.0.0.1:8787/v1/chat/completions", forKey: TranslationConfiguration.Keys.endpoint)
        UserDefaults.standard.set("/path/to/model", forKey: TranslationConfiguration.Keys.model)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: TranslationConfiguration.Keys.endpoint)
        UserDefaults.standard.removeObject(forKey: TranslationConfiguration.Keys.model)
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
        UserDefaults.standard.set("not-a-url", forKey: TranslationConfiguration.Keys.endpoint)

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

    // MARK: - initial state

    func test_initialState() {
        let svc = ModelListService(session: mockSession)
        XCTAssertTrue(svc.models.isEmpty)
        XCTAssertFalse(svc.isLoading)
        XCTAssertNil(svc.errorMessage)
    }
}
