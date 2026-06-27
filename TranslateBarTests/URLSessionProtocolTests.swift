import XCTest
@testable import TranslateBar

/// URLProtocol mock that serves predefined data for testing URLSession extension
private final class MockURLProtocol: URLProtocol {
    static var mockData = Data()
    static var mockStatusCode = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.mockStatusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/event-stream"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.mockData)
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class URLSessionProtocolTests: XCTestCase {
    var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
    }

    override func tearDown() {
        session = nil
        super.tearDown()
    }

    func test_urlSessionConformsToProtocol() {
        XCTAssertTrue(session is URLSessionProtocol)
    }

    func test_urlSessionExtension_data() async throws {
        MockURLProtocol.mockData = "hello world".data(using: .utf8)!
        MockURLProtocol.mockStatusCode = 200

        let protocolSession: URLSessionProtocol = session
        let (data, response) = try await protocolSession.data(for: URLRequest(url: URL(string: "http://test/v1/chat/completions")!))

        XCTAssertEqual(data, "hello world".data(using: .utf8))
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    func test_urlSessionExtension_bytesStream() async throws {
        // Simulate SSE data
        let sseData = "data: {\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]}\n\ndata: [DONE]\n".data(using: .utf8)!
        MockURLProtocol.mockData = sseData
        MockURLProtocol.mockStatusCode = 200

        let protocolSession: URLSessionProtocol = session
        let (stream, response) = try await protocolSession.bytesStream(for: URLRequest(url: URL(string: "http://test/v1/chat/completions")!))

        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)

        // Collect all bytes
        var bytes = Data()
        for try await byte in stream {
            bytes.append(byte)
        }
        XCTAssertEqual(bytes, sseData)
    }

    func test_mockSession_data() async throws {
        let mock = MockURLSession()
        mock.mockData = "test".data(using: .utf8)
        mock.mockResponse = MockURLSession.successResponse()

        let (data, _) = try await mock.data(for: URLRequest(url: URL(string: "http://test")!))
        XCTAssertEqual(data, "test".data(using: .utf8))
    }

    func test_mockSession_bytesStream() async throws {
        let mock = MockURLSession()
        mock.mockBytesStream = MockURLSession.sseStream(lines: ["a", "b"])
        mock.mockBytesResponse = MockURLSession.successResponse()

        let (stream, _) = try await mock.bytesStream(for: URLRequest(url: URL(string: "http://test")!))
        var bytes = Data()
        for try await byte in stream { bytes.append(byte) }
        XCTAssertEqual(bytes.count, 4) // "a\nb\n"
    }
}
