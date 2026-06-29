import AppKit
import SwiftUI

struct TranslatePanelView: View {
    @StateObject private var service: TranslationService
    @StateObject private var loginItemService = LoginItemService()
    @StateObject private var modelListService: ModelListService
    @AppStorage(TranslationConfiguration.Keys.provider, store: TranslationConfiguration.persisted) private var provider = TranslationProvider.local.rawValue
    @AppStorage(TranslationConfiguration.Keys.endpoint, store: TranslationConfiguration.persisted) private var endpoint = TranslationConfiguration.defaultEndpoint
    @AppStorage(TranslationConfiguration.Keys.model, store: TranslationConfiguration.persisted) private var model = TranslationConfiguration.defaultModel
    @AppStorage(TranslationConfiguration.Keys.streamingEnabled, store: TranslationConfiguration.persisted) private var streamingEnabled = false
    @AppStorage(TranslationConfiguration.Keys.cloudEndpoint, store: TranslationConfiguration.persisted) private var cloudEndpoint = TranslationConfiguration.defaultCloudEndpoint
    @AppStorage(TranslationConfiguration.Keys.cloudModel, store: TranslationConfiguration.persisted) private var cloudModel = TranslationConfiguration.defaultCloudModel
    @AppStorage(TranslationConfiguration.Keys.cloudAPIKey, store: TranslationConfiguration.persisted) private var cloudAPIKey = ""

    init(defaults: UserDefaults = TranslationConfiguration.persisted) {
        _service = StateObject(wrappedValue: TranslationService(defaults: defaults))
        _modelListService = StateObject(wrappedValue: ModelListService(defaults: defaults))
    }
    @State private var inputText = ""
    @State private var mode: TranslationMode = .auto
    @State private var autoTranslate = true
    @State private var showsSettings = false

    private var currentProvider: TranslationProvider {
        TranslationProvider(rawValue: provider) ?? .local
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                header
                if showsSettings {
                    Divider()
                    settingsArea
                }
                Divider()
                inputArea
                Divider()
                resultArea
            }
            .frame(width: 420)
        }
        .frame(width: 420, height: 520)
        .clipped()
    }

    // MARK: - Header

    var header: some View {
        HStack(spacing: 8) {
            Button {
                showsSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("设置")

            Toggle("自动翻译", isOn: $autoTranslate)
                .toggleStyle(.switch)

            Picker("", selection: $mode) {
                ForEach(TranslationMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, newMode in
                if autoTranslate {
                    service.translate(text: inputText, mode: newMode)
                }
            }

            Spacer()

            Button("退出") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
    }

    // MARK: - Settings Area

    var settingsArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("服务设置")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("恢复默认") {
                    endpoint = TranslationConfiguration.defaultEndpoint
                    model = TranslationConfiguration.defaultModel
                    cloudEndpoint = TranslationConfiguration.defaultCloudEndpoint
                    cloudModel = TranslationConfiguration.defaultCloudModel
                    // 不自动清空 API key
                    service.cancel()
                    service.errorMessage = nil
                }
                .buttonStyle(.plain)
            }

            // Provider 选择
            VStack(alignment: .leading, spacing: 4) {
                Text("翻译服务")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $provider) {
                    ForEach(TranslationProvider.allCases) { p in
                        Text(p.displayName).tag(p.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: provider) { _, _ in
                    service.cancel()
                    service.errorMessage = nil
                }
            }

            if currentProvider == .local {
                localSettings
            } else {
                deepseekSettings
            }

            Divider()

            HStack {
                Toggle("登录时启动", isOn: Binding(
                    get: { loginItemService.isEnabled },
                    set: { newValue in
                        if newValue {
                            loginItemService.enable()
                        } else {
                            loginItemService.disable()
                        }
                    }
                ))
                .toggleStyle(.switch)
                .onAppear {
                    loginItemService.refresh()
                }

                Spacer()

                if let message = loginItemService.statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
    }

    // MARK: - Local Settings

    var localSettings: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                Text("服务地址")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(
                    "http://127.0.0.1:8787/v1/chat/completions",
                    text: $endpoint
                )
                .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("模型路径")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    if modelListService.models.isEmpty {
                        TextField(
                            "/Users/jafish/Documents/models/Hy-MT2-7B-4bit",
                            text: $model
                        )
                        .textFieldStyle(.roundedBorder)
                    } else {
                        Picker("", selection: $model) {
                            ForEach(modelListService.models, id: \.self) { modelId in
                                Text(modelId).tag(modelId)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await modelListService.fetchModels() }
                    } label: {
                        if modelListService.isLoading {
                            ProgressView()
                                .scaleEffect(0.65)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(modelListService.isLoading)
                    .help("刷新模型列表")
                }

                if let error = modelListService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .onAppear {
                Task { await modelListService.fetchModels() }
            }

            Toggle("流式输出", isOn: $streamingEnabled)
                .toggleStyle(.switch)
                .onChange(of: streamingEnabled) {
                    service.cancel()
                }
        }
    }

    // MARK: - DeepSeek Settings

    var deepseekSettings: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                Text("服务地址")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(
                    "https://api.deepseek.com/v1/chat/completions",
                    text: $cloudEndpoint
                )
                .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("模型")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    if modelListService.models.isEmpty {
                        TextField(
                            "deepseek-v4-flash",
                            text: $cloudModel
                        )
                        .textFieldStyle(.roundedBorder)
                    } else {
                        Picker("", selection: $cloudModel) {
                            ForEach(modelListService.models, id: \.self) { modelId in
                                Text(modelId).tag(modelId)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await modelListService.fetchModels() }
                    } label: {
                        if modelListService.isLoading {
                            ProgressView()
                                .scaleEffect(0.65)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(modelListService.isLoading)
                    .help("刷新模型列表")
                }

                if let error = modelListService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .onAppear {
                Task { await modelListService.fetchModels() }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("API Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    SecureField("sk-...", text: $cloudAPIKey)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        cloudAPIKey = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .disabled(cloudAPIKey.isEmpty)
                    .help("清除 API Key")
                }

                Text(cloudAPIKey.isEmpty ? "未检测到 API Key" : "已检测到 API Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("流式输出", isOn: $streamingEnabled)
                .toggleStyle(.switch)
                .onChange(of: streamingEnabled) {
                    service.cancel()
                }
        }
    }

    // MARK: - Input Area

    var inputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("输入")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("清空") {
                    inputText = ""
                    service.cancel()
                    service.result = ""
                    service.errorMessage = nil
                }
                .disabled(inputText.isEmpty)

                Button("翻译") {
                    service.translate(text: inputText, mode: mode)
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.textBackgroundColor))
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.25))

                TextEditor(text: $inputText)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .padding(4)
            }
            .frame(height: 170)
            .onChange(of: inputText) { _, newValue in
                    if autoTranslate {
                        service.translate(text: newValue, mode: mode)
                    }
                }
        }
        .padding(12)
    }

    // MARK: - Result Area

    var resultArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("翻译结果")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if service.isLoading {
                    ProgressView()
                        .scaleEffect(0.65)
                }

                Spacer()

                Button("复制") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        service.result,
                        forType: .string
                    )
                }
                .disabled(service.result.isEmpty)
            }

            Group {
                if let errorMessage = service.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else if service.result.isEmpty {
                    Text("翻译结果将显示在这里")
                        .foregroundStyle(.tertiary)
                } else {
                    Text(service.result)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .textSelection(.enabled)
                }
            }
            .font(.system(size: 14))
            .frame(
                maxWidth: .infinity,
                minHeight: 100,
                alignment: .topLeading
            )
        }
        .padding(12)
    }
}
