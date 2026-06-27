import Foundation

@MainActor
final class TranslationService: ObservableObject {
    @Published var result = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var currentTask: Task<Void, Never>?
    private var currentTranslateId: UUID?

    func translate(text: String, mode: TranslationMode) {
        currentTask?.cancel()

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            result = ""
            errorMessage = nil
            isLoading = false
            currentTranslateId = nil
            return
        }

        let id = UUID()
        currentTranslateId = id

        currentTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.performTranslation(text: trimmedText, mode: mode, id: id)
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        currentTranslateId = nil
        isLoading = false
    }

    private func performTranslation(text: String, mode: TranslationMode, id: UUID) async {
        guard currentTranslateId == id else { return }

        isLoading = true
        errorMessage = nil

        do {
            let configuration = try makeConfiguration()

            guard let endpoint = configuration.endpoint else {
                throw TranslationError.invalidEndpoint(configuration.endpointString)
            }

            if configuration.streamingEnabled {
                try await performStreamingTranslation(
                    text: text,
                    mode: mode,
                    configuration: configuration,
                    endpoint: endpoint,
                    id: id
                )
            } else {
                try await performNonStreamingTranslation(
                    text: text,
                    mode: mode,
                    configuration: configuration,
                    endpoint: endpoint,
                    id: id
                )
            }
        } catch is CancellationError {
            return
        } catch {
            guard currentTranslateId == id else { return }
            errorMessage = readableError(error)
        }

        if currentTranslateId == id {
            isLoading = false
        }
    }

    private func performNonStreamingTranslation(
        text: String,
        mode: TranslationMode,
        configuration: TranslationConfiguration,
        endpoint: URL,
        id: UUID
    ) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ChatCompletionRequest(
            model: configuration.model,
            messages: [
                ChatMessage(role: "user", content: makePrompt(text: text, mode: mode))
            ],
            temperature: 0.1,
            topP: 0.6,
            maxTokens: 4096,
            stream: false
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard currentTranslateId == id else { return }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TranslationError.httpError(
                statusCode: httpResponse.statusCode,
                message: parseErrorMessage(from: data)
            )
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        let content = decoded.choices.first?.message?.content ?? decoded.choices.first?.text
        let translatedText = content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if translatedText.isEmpty {
            throw TranslationError.emptyContent
        }

        guard currentTranslateId == id else { return }
        result = translatedText
    }

    private func performStreamingTranslation(
        text: String,
        mode: TranslationMode,
        configuration: TranslationConfiguration,
        endpoint: URL,
        id: UUID
    ) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ChatCompletionRequest(
            model: configuration.model,
            messages: [
                ChatMessage(role: "user", content: makePrompt(text: text, mode: mode))
            ],
            temperature: 0.1,
            topP: 0.6,
            maxTokens: 4096,
            stream: true
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard currentTranslateId == id else { return }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            var errorBody = Data()
            for try await byte in bytes {
                errorBody.append(byte)
                if errorBody.count >= 500 { break }
            }
            let message = String(data: errorBody, encoding: .utf8) ?? ""
            throw TranslationError.httpError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        guard currentTranslateId == id else { return }
        result = ""

        for try await line in bytes.lines {
            guard currentTranslateId == id else { return }

            if line.hasPrefix(":") { continue }
            if line == "data: [DONE]" { break }
            guard line.hasPrefix("data: ") else { continue }

            let jsonString = String(line.dropFirst(6))
            guard let jsonData = jsonString.data(using: .utf8) else { continue }

            do {
                let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: jsonData)
                if let content = chunk.choices.first?.delta?.content {
                    result += content
                }
            } catch {
                continue
            }
        }

        if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard currentTranslateId == id else { return }
            throw TranslationError.emptyContent
        }
    }

    private func makePrompt(text: String, mode: TranslationMode) -> String {
        let target = mode.targetDescription(for: text)

        return """
        Translate the following text to \(target).
        Only output the translated result. Do not explain, summarize, add markdown, or wrap the answer in quotes.

        \(text)
        """
    }

    private func parseErrorMessage(from data: Data) -> String {
        if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
           let message = apiError.error?.message,
           !message.isEmpty {
            return message
        }

        return String(data: data, encoding: .utf8)?.prefix(500).description ?? "Unknown error"
    }

    private func makeConfiguration() throws -> TranslationConfiguration {
        let configuration = TranslationConfiguration.current()

        if configuration.endpointString.isEmpty {
            throw TranslationError.invalidEndpoint(configuration.endpointString)
        }

        if configuration.model.isEmpty {
            throw TranslationError.emptyModel
        }

        return configuration
    }

    private func readableError(_ error: Error) -> String {
        if let translationError = error as? TranslationError {
            return translationError.localizedDescription
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .notConnectedToInternet, .networkConnectionLost:
                return "无法连接本地翻译服务，请确认 \(TranslationConfiguration.current().endpointString) 可访问。"
            case .timedOut:
                return "翻译请求超时，模型可能仍在推理或文本过长。"
            default:
                return "网络错误：\(urlError.localizedDescription)"
            }
        }

        return "翻译失败：\(error.localizedDescription)"
    }
}
