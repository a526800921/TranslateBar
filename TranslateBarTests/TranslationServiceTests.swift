import Combine
import XCTest
@testable import TranslateBar

@MainActor
final class TranslationServiceTests: XCTestCase {
    var service: TranslationService!
    var mockSession: MockURLSession!
    var testDefaults: UserDefaults!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        // 用独立 suite 隔离测试，不碰真实持久化域
        testDefaults = UserDefaults(suiteName: "com.translatebar.tests")
        testDefaults.removePersistentDomain(forName: "com.translatebar.tests")
        service = TranslationService(session: mockSession, defaults: testDefaults)
        cancellables.removeAll()
        testDefaults.set("local", forKey: TranslationConfiguration.Keys.provider)
        testDefaults.set("http://127.0.0.1:8787/v1/chat/completions", forKey: TranslationConfiguration.Keys.endpoint)
        testDefaults.set("/path/to/model", forKey: TranslationConfiguration.Keys.model)
        testDefaults.set(false, forKey: TranslationConfiguration.Keys.streamingEnabled)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "com.translatebar.tests")
        testDefaults = nil
        mockSession = nil
        service = nil
        super.tearDown()
    }

    // MARK: - translate(text:mode:)

    func test_translate_emptyText_clearsResult() async throws {
        service.result = "old result"
        service.errorMessage = "old error"
        service.isLoading = true

        service.translate(text: "", mode: .auto)
        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(service.result, "")
        XCTAssertNil(service.errorMessage)
        XCTAssertFalse(service.isLoading)
    }

    func test_translate_whitespaceOnlyText_clearsResult() async throws {
        service.result = "old"
        service.translate(text: "   \n  ", mode: .auto)
        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(service.result, "")
        XCTAssertFalse(service.isLoading)
    }

    // MARK: - cancel()

    func test_cancel_clearsLoadingState() {
        service.isLoading = true

        service.cancel()

        XCTAssertFalse(service.isLoading)
    }

    // MARK: - makePrompt (internal)

    func test_makePrompt_zhToEn() {
        let prompt = service.makePrompt(text: "你好", mode: .zhToEn)
        XCTAssertTrue(prompt.contains("English"))
        XCTAssertTrue(prompt.contains("你好"))
        XCTAssertTrue(prompt.contains("Only output the translated result"))
    }

    func test_makePrompt_enToZh() {
        let prompt = service.makePrompt(text: "hello", mode: .enToZh)
        XCTAssertTrue(prompt.contains("Chinese"))
        XCTAssertTrue(prompt.contains("hello"))
    }

    func test_makePrompt_autoChinese() {
        let prompt = service.makePrompt(text: "世界", mode: .auto)
        XCTAssertTrue(prompt.contains("English"))
        XCTAssertTrue(prompt.contains("世界"))
    }

    func test_makePrompt_autoEnglish() {
        let prompt = service.makePrompt(text: "world", mode: .auto)
        XCTAssertTrue(prompt.contains("Chinese"))
        XCTAssertTrue(prompt.contains("world"))
    }

    // MARK: - makeConfiguration (internal)

    func test_makeConfiguration_validConfig() throws {
        testDefaults.set("http://valid.com/v1/chat/completions", forKey: TranslationConfiguration.Keys.endpoint)
        testDefaults.set("/model", forKey: TranslationConfiguration.Keys.model)

        let config = try service.makeConfiguration(defaults: testDefaults)
        XCTAssertNotNil(config)
        XCTAssertEqual(config.endpointString, "http://valid.com/v1/chat/completions")
    }

    func test_makeConfiguration_emptyEndpoint_throws() {
        testDefaults.set("", forKey: TranslationConfiguration.Keys.endpoint)
        testDefaults.set("/model", forKey: TranslationConfiguration.Keys.model)

        XCTAssertThrowsError(try service.makeConfiguration(defaults: testDefaults)) { error in
            guard let translationError = error as? TranslationError,
                  case .invalidEndpoint = translationError else {
                XCTFail("Expected invalidEndpoint, got \(error)")
                return
            }
        }
    }

    func test_makeConfiguration_emptyModel_throws() {
        testDefaults.set("http://valid.com/v1/chat/completions", forKey: TranslationConfiguration.Keys.endpoint)
        testDefaults.set("", forKey: TranslationConfiguration.Keys.model)

        XCTAssertThrowsError(try service.makeConfiguration(defaults: testDefaults)) { error in
            guard let translationError = error as? TranslationError,
                  case .emptyModel = translationError else {
                XCTFail("Expected emptyModel, got \(error)")
                return
            }
        }
    }

    // MARK: - parseErrorMessage (internal)

    func test_parseErrorMessage_validAPIError() {
        let json = #"{"error":{"message":"Service Unavailable","type":"server_error"}}"#
        let data = json.data(using: .utf8)!
        let message = service.parseErrorMessage(from: data)
        XCTAssertEqual(message, "Service Unavailable")
    }

    func test_parseErrorMessage_invalidJSON() {
        let data = "plain text error".data(using: .utf8)!
        let message = service.parseErrorMessage(from: data)
        XCTAssertTrue(message.contains("plain text error"))
    }

    func test_parseErrorMessage_emptyData() {
        let data = Data()
        let message = service.parseErrorMessage(from: data)
        // Empty Data → utf8 decode returns "" (non-nil) → prefix(500) → ""
        // The ?? fallback is not triggered because String? is non-nil
        XCTAssertEqual(message, "")
    }

    // MARK: - readableError (internal)

    func test_readableError_translationError() {
        let message = service.readableError(TranslationError.emptyModel)
        XCTAssertTrue(message.contains("模型路径不能为空"))
    }

    func test_readableError_urlErrorCannotConnect() {
        let error = URLError(.cannotConnectToHost)
        let message = service.readableError(error)
        XCTAssertTrue(message.contains("无法连接本地翻译服务"))
    }

    func test_readableError_urlErrorTimedOut() {
        let error = URLError(.timedOut)
        let message = service.readableError(error)
        XCTAssertTrue(message.contains("超时"))
    }

    func test_readableError_urlErrorNotConnected() {
        let error = URLError(.notConnectedToInternet)
        let message = service.readableError(error)
        XCTAssertTrue(message.contains("无法连接本地翻译服务"))
    }

    func test_readableError_urlErrorOther() {
        let error = URLError(.dnsLookupFailed)
        let message = service.readableError(error)
        XCTAssertTrue(message.contains("网络错误"))
    }

    func test_readableError_genericError() {
        let error = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "something went wrong"])
        let message = service.readableError(error)
        XCTAssertTrue(message.contains("翻译失败"))
        XCTAssertTrue(message.contains("something went wrong"))
    }

    // MARK: - Non-streaming translation

    func test_performNonStreaming_success() async {
        let responseJSON = #"{"choices":[{"message":{"role":"assistant","content":"Hello"}}]}"#
        mockSession.mockData = responseJSON.data(using: .utf8)
        mockSession.mockResponse = MockURLSession.successResponse()

        let exp = expectation(description: "translation completes")
        service.$result
            .dropFirst()
            .sink { result in
                if result == "Hello" { exp.fulfill() }
            }
            .store(in: &cancellables)

        service.translate(text: "你好", mode: .zhToEn)
        await fulfillment(of: [exp], timeout: 5)

        XCTAssertEqual(service.result, "Hello")
        XCTAssertNil(service.errorMessage)
        XCTAssertFalse(service.isLoading)
    }

    func test_performNonStreaming_emptyContent_showsError() async {
        let responseJSON = #"{"choices":[{"message":{"role":"assistant","content":""}}]}"#
        mockSession.mockData = responseJSON.data(using: .utf8)
        mockSession.mockResponse = MockURLSession.successResponse()

        let exp = expectation(description: "error received")
        service.$errorMessage
            .dropFirst()
            .compactMap { $0 }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        service.translate(text: "你好", mode: .zhToEn)
        await fulfillment(of: [exp], timeout: 5)

        XCTAssertNotNil(service.errorMessage)
        XCTAssertEqual(service.result, "")
        XCTAssertFalse(service.isLoading)
    }

    func test_performNonStreaming_httpError() async {
        let errorJSON = #"{"error":{"message":"Server Error","type":"server_error"}}"#
        mockSession.mockData = errorJSON.data(using: .utf8)
        mockSession.mockResponse = MockURLSession.successResponse(statusCode: 500)

        let exp = expectation(description: "error received")
        service.$errorMessage
            .dropFirst()
            .compactMap { $0 }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        service.translate(text: "你好", mode: .zhToEn)
        await fulfillment(of: [exp], timeout: 5)

        XCTAssertNotNil(service.errorMessage)
        // error message will contain the parsed API error or status code info
        XCTAssertFalse(service.errorMessage?.isEmpty ?? true)
    }

    func test_performNonStreaming_notHTTPResponse() async {
        mockSession.mockData = Data()
        mockSession.mockResponse = URLResponse(url: URL(string: "http://test")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)

        let exp = expectation(description: "error received")
        service.$errorMessage
            .dropFirst()
            .compactMap { $0 }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        service.translate(text: "你好", mode: .zhToEn)
        await fulfillment(of: [exp], timeout: 5)

        XCTAssertNotNil(service.errorMessage)
    }

    // MARK: - Streaming translation

    func test_performStreaming_success() async {
        testDefaults.set(true, forKey: TranslationConfiguration.Keys.streamingEnabled)

        let lines = [
            #"data: {"choices":[{"delta":{"content":"Hel"},"finish_reason":null}]}"#,
            #"data: {"choices":[{"delta":{"content":"lo"},"finish_reason":null}]}"#,
            "data: [DONE]",
        ]
        mockSession.mockBytesStream = MockURLSession.sseStream(lines: lines)
        mockSession.mockBytesResponse = MockURLSession.successResponse()

        let exp = expectation(description: "streaming completes")
        service.$result
            .dropFirst()
            .sink { result in
                if result == "Hello" { exp.fulfill() }
            }
            .store(in: &cancellables)

        service.translate(text: "你好", mode: .zhToEn)
        await fulfillment(of: [exp], timeout: 5)

        XCTAssertEqual(service.result, "Hello")
        XCTAssertNil(service.errorMessage)
        XCTAssertFalse(service.isLoading)
    }

    func test_performStreaming_skipComments() async {
        testDefaults.set(true, forKey: TranslationConfiguration.Keys.streamingEnabled)

        let lines = [
            ": heartbeat",
            #"data: {"choices":[{"delta":{"content":"OK"},"finish_reason":null}]}"#,
            "data: [DONE]",
        ]
        mockSession.mockBytesStream = MockURLSession.sseStream(lines: lines)
        mockSession.mockBytesResponse = MockURLSession.successResponse()

        let exp = expectation(description: "streaming completes")
        service.$result
            .dropFirst()
            .sink { result in
                if result == "OK" { exp.fulfill() }
            }
            .store(in: &cancellables)

        service.translate(text: "hello", mode: .zhToEn)
        await fulfillment(of: [exp], timeout: 5)

        XCTAssertEqual(service.result, "OK")
    }

    func test_performStreaming_httpError() async {
        testDefaults.set(true, forKey: TranslationConfiguration.Keys.streamingEnabled)

        let lines = ["error body"]
        mockSession.mockBytesStream = MockURLSession.sseStream(lines: lines)
        mockSession.mockBytesResponse = MockURLSession.successResponse(statusCode: 500)

        let exp = expectation(description: "error received")
        service.$errorMessage
            .dropFirst()
            .compactMap { $0 }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        service.translate(text: "你好", mode: .zhToEn)
        await fulfillment(of: [exp], timeout: 5)

        XCTAssertNotNil(service.errorMessage)
    }

    // MARK: - DeepSeek non-streaming

    func test_deepseekNonStreaming_addsAuthorizationHeader() async {
        testDefaults.set("deepseek", forKey: TranslationConfiguration.Keys.provider)
        testDefaults.set("https://api.deepseek.com/v1/chat/completions", forKey: TranslationConfiguration.Keys.cloudEndpoint)
        testDefaults.set("deepseek-v4-flash", forKey: TranslationConfiguration.Keys.cloudModel)
        testDefaults.set("sk-test-key", forKey: TranslationConfiguration.Keys.cloudAPIKey)

        let responseJSON = #"{"choices":[{"message":{"role":"assistant","content":"Hello"}}]}"#
        mockSession.mockData = responseJSON.data(using: .utf8)
        mockSession.mockResponse = MockURLSession.successResponse(url: URL(string: "https://api.deepseek.com/v1/chat/completions")!)

        let exp = expectation(description: "translation completes")
        service.$result
            .dropFirst()
            .sink { result in
                if result == "Hello" { exp.fulfill() }
            }
            .store(in: &cancellables)

        service.translate(text: "你好", mode: .zhToEn)
        await fulfillment(of: [exp], timeout: 5)

        let lastRequest = mockSession.lastDataRequest
        XCTAssertEqual(lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test-key")
    }

    func test_deepseekNonStreaming_disablesThinking() async {
        testDefaults.set("deepseek", forKey: TranslationConfiguration.Keys.provider)
        testDefaults.set("https://api.deepseek.com/v1/chat/completions", forKey: TranslationConfiguration.Keys.cloudEndpoint)
        testDefaults.set("deepseek-v4-flash", forKey: TranslationConfiguration.Keys.cloudModel)
        testDefaults.set("sk-test-key", forKey: TranslationConfiguration.Keys.cloudAPIKey)

        let responseJSON = #"{"choices":[{"message":{"role":"assistant","content":"Hello"}}]}"#
        mockSession.mockData = responseJSON.data(using: .utf8)
        mockSession.mockResponse = MockURLSession.successResponse(url: URL(string: "https://api.deepseek.com/v1/chat/completions")!)

        let exp = expectation(description: "translation completes")
        service.$result
            .dropFirst()
            .sink { result in
                if result == "Hello" { exp.fulfill() }
            }
            .store(in: &cancellables)

        service.translate(text: "你好", mode: .zhToEn)
        await fulfillment(of: [exp], timeout: 5)

        let lastRequest = mockSession.lastDataRequest
        XCTAssertNotNil(lastRequest?.httpBody)
        let body = try! JSONSerialization.jsonObject(with: lastRequest!.httpBody!) as? [String: Any]
        let kwargs = body?["chat_template_kwargs"] as? [String: Any]
        XCTAssertEqual(kwargs?["enable_thinking"] as? Bool, false)
    }

    // MARK: - DeepSeek streaming

    func test_deepseekStreaming_addsAuthorizationHeader() async {
        testDefaults.set("deepseek", forKey: TranslationConfiguration.Keys.provider)
        testDefaults.set("https://api.deepseek.com/v1/chat/completions", forKey: TranslationConfiguration.Keys.cloudEndpoint)
        testDefaults.set("deepseek-v4-flash", forKey: TranslationConfiguration.Keys.cloudModel)
        testDefaults.set("sk-test-key", forKey: TranslationConfiguration.Keys.cloudAPIKey)
        testDefaults.set(true, forKey: TranslationConfiguration.Keys.streamingEnabled)

        let lines = [
            #"data: {"choices":[{"delta":{"content":"Hi"},"finish_reason":null}]}"#,
            "data: [DONE]",
        ]
        mockSession.mockBytesStream = MockURLSession.sseStream(lines: lines)
        mockSession.mockBytesResponse = MockURLSession.successResponse(url: URL(string: "https://api.deepseek.com/v1/chat/completions")!)

        let exp = expectation(description: "streaming completes")
        service.$result
            .dropFirst()
            .sink { result in
                if result == "Hi" { exp.fulfill() }
            }
            .store(in: &cancellables)

        service.translate(text: "你好", mode: .zhToEn)
        await fulfillment(of: [exp], timeout: 5)

        let lastRequest = mockSession.lastBytesRequest
        XCTAssertEqual(lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test-key")
    }

    // MARK: - Local request (no auth)

    func test_localRequest_doesNotAddAuthorizationHeader() async {
        // setUp already sets provider to "local"
        let responseJSON = #"{"choices":[{"message":{"role":"assistant","content":"Hello"}}]}"#
        mockSession.mockData = responseJSON.data(using: .utf8)
        mockSession.mockResponse = MockURLSession.successResponse()

        let exp = expectation(description: "translation completes")
        service.$result
            .dropFirst()
            .sink { result in
                if result == "Hello" { exp.fulfill() }
            }
            .store(in: &cancellables)

        service.translate(text: "你好", mode: .zhToEn)
        await fulfillment(of: [exp], timeout: 5)

        let lastRequest = mockSession.lastDataRequest
        XCTAssertNil(lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    func test_localRequest_disablesThinking() async {
        let responseJSON = #"{"choices":[{"message":{"role":"assistant","content":"Hello"}}]}"#
        mockSession.mockData = responseJSON.data(using: .utf8)
        mockSession.mockResponse = MockURLSession.successResponse()

        let exp = expectation(description: "translation completes")
        service.$result
            .dropFirst()
            .sink { result in
                if result == "Hello" { exp.fulfill() }
            }
            .store(in: &cancellables)

        service.translate(text: "你好", mode: .zhToEn)
        await fulfillment(of: [exp], timeout: 5)

        let lastRequest = mockSession.lastDataRequest
        XCTAssertNotNil(lastRequest?.httpBody)
        let body = try! JSONSerialization.jsonObject(with: lastRequest!.httpBody!) as? [String: Any]
        let kwargs = body?["chat_template_kwargs"] as? [String: Any]
        // 本地始终关闭思考
        XCTAssertEqual(kwargs?["enable_thinking"] as? Bool, false)
    }

    func test_deepseekMissingAPIKey_showsReadableError() async {
        testDefaults.set("deepseek", forKey: TranslationConfiguration.Keys.provider)
        testDefaults.set("https://api.deepseek.com/v1/chat/completions", forKey: TranslationConfiguration.Keys.cloudEndpoint)
        testDefaults.set("deepseek-v4-flash", forKey: TranslationConfiguration.Keys.cloudModel)
        // 不设置 API key

        let exp = expectation(description: "error received")
        service.$errorMessage
            .dropFirst()
            .compactMap { $0 }
            .sink { message in
                if message.contains("API Key") { exp.fulfill() }
            }
            .store(in: &cancellables)

        service.translate(text: "你好", mode: .zhToEn)
        await fulfillment(of: [exp], timeout: 5)

        XCTAssertNotNil(service.errorMessage)
        XCTAssertTrue(service.errorMessage?.contains("API Key 未配置") ?? false)
    }

    // MARK: - readableError (provider-aware)

    func test_readableError_deepseekCannotConnect() {
        testDefaults.set("deepseek", forKey: TranslationConfiguration.Keys.provider)
        testDefaults.set("https://api.deepseek.com/v1/chat/completions", forKey: TranslationConfiguration.Keys.cloudEndpoint)

        let error = URLError(.cannotConnectToHost)
        let message = service.readableError(error)
        XCTAssertTrue(message.contains("DeepSeek"))
        XCTAssertTrue(message.contains("API key"))
    }

    // MARK: - URLSession protocol extension (covers URLSessionProtocol.swift)

    func test_urlSessionExtension_bytesStream() async throws {
        // Use a real URLSession with URLProtocol mock to exercise the extension
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SSEMockURLProtocol.self]
        let realSession = URLSession(configuration: config)

        let sseData = "data: {\"test\":true}\n\n".data(using: .utf8)!
        SSEMockURLProtocol.mockData = sseData
        SSEMockURLProtocol.mockStatusCode = 200

        let protoSession: URLSessionProtocol = realSession
        let (stream, response) = try await protoSession.bytesStream(
            for: URLRequest(url: URL(string: "http://127.0.0.1:8787/v1/chat/completions")!)
        )
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)

        var collected = Data()
        for try await byte in stream {
            collected.append(byte)
        }
        XCTAssertEqual(collected, sseData)
    }
}

/// URLProtocol mock for testing URLSession extension bytesStream
private final class SSEMockURLProtocol: URLProtocol {
    static var mockData = Data()
    static var mockStatusCode = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let resp = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.mockStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.mockData)
        client?.urlProtocolDidFinishLoading(self)
    }
}
