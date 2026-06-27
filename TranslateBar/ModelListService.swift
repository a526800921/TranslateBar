import Foundation

@MainActor
final class ModelListService: ObservableObject {
    @Published var models: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let session: URLSessionProtocol

    init(session: URLSessionProtocol = URLSession.shared) {
        self.session = session
    }

    func fetchModels() async {
        isLoading = true
        errorMessage = nil

        do {
            let configuration = TranslationConfiguration.current()

            guard let modelsURL = configuration.modelsEndpoint else {
                errorMessage = "无法从服务地址推导模型列表地址。请确认服务地址以 /v1/chat/completions 结尾。"
                isLoading = false
                return
            }

            var request = URLRequest(url: modelsURL)
            request.timeoutInterval = 30

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "无法连接模型列表服务。"
                isLoading = false
                return
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
                errorMessage = "模型列表服务返回 HTTP \(httpResponse.statusCode)：\(body)"
                isLoading = false
                return
            }

            let decoded = try JSONDecoder().decode(ModelListResponse.self, from: data)
            models = decoded.data.map { $0.id }

            if models.isEmpty {
                errorMessage = "服务返回了空的模型列表。"
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "读取模型列表失败：\(error.localizedDescription)"
        }

        isLoading = false
    }
}
