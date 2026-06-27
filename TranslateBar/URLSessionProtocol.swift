import Foundation

/// 协议抽象 URLSession 的网络请求能力，便于单元测试 mock。
protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func bytesStream(for request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, any Error>, URLResponse)
}

extension URLSession: URLSessionProtocol {
    func bytesStream(for request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, any Error>, URLResponse) {
        let (bytes, response) = try await self.bytes(for: request)
        let stream = AsyncThrowingStream<UInt8, any Error> { continuation in
            Task {
                do {
                    for try await byte in bytes {
                        continuation.yield(byte)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        return (stream, response)
    }
}
