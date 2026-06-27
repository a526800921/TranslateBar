import Foundation
@testable import TranslateBar

/// Mock URLSession，用于 TranslationService 和 ModelListService 的单元测试。
final class MockURLSession: URLSessionProtocol {
    /// data(for:) 的预设返回数据
    var mockData: Data?
    /// data(for:) 的预设返回响应
    var mockResponse: URLResponse?
    /// data(for:) 的预设抛出错误
    var mockError: Error?

    /// bytesStream(for:) 的预设返回字节流
    var mockBytesStream: AsyncThrowingStream<UInt8, any Error>?
    /// bytesStream(for:) 的预设返回响应
    var mockBytesResponse: URLResponse?
    /// bytesStream(for:) 的预设抛出错误
    var mockBytesError: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        return (
            mockData ?? Data(),
            mockResponse ?? HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }

    func bytesStream(for request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, any Error>, URLResponse) {
        if let error = mockBytesError {
            throw error
        }
        let stream = mockBytesStream ?? AsyncThrowingStream { $0.finish() }
        let response = mockBytesResponse ?? HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (stream, response)
    }

    /// 便捷方法：创建模拟成功 HTTP 响应
    static func successResponse(url: URL = URL(string: "http://127.0.0.1:8787/v1/chat/completions")!,
                                statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    /// 便捷方法：创建模拟 SSE 字节流
    /// - Parameter lines: SSE 文本行数组，自动追加 \n
    static func sseStream(lines: [String]) -> AsyncThrowingStream<UInt8, any Error> {
        AsyncThrowingStream { continuation in
            for line in lines {
                let lineWithNewline = line + "\n"
                for byte in lineWithNewline.utf8 {
                    continuation.yield(byte)
                }
            }
            continuation.finish()
        }
    }
}
