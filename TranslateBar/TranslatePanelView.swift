import AppKit
import SwiftUI

struct TranslatePanelView: View {
    @StateObject private var service = TranslationService()
    @AppStorage(TranslationConfiguration.Keys.endpoint) private var endpoint = TranslationConfiguration.defaultEndpoint
    @AppStorage(TranslationConfiguration.Keys.model) private var model = TranslationConfiguration.defaultModel
    @State private var inputText = ""
    @State private var mode: TranslationMode = .auto
    @State private var autoTranslate = true
    @State private var showsSettings = false

    var body: some View {
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
        .frame(width: 420, height: 520)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
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

            Button("退出") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)

            Button {
                showsSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("设置")
        }
        .padding(12)
    }

    // MARK: - Settings Area

    private var settingsArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("服务设置")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("恢复默认") {
                    endpoint = TranslationConfiguration.defaultEndpoint
                    model = TranslationConfiguration.defaultModel
                    service.cancel()
                    service.errorMessage = nil
                }
                .buttonStyle(.borderless)
            }

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
                TextField(
                    "/Users/jafish/Documents/models/Hy-MT2-7B-4bit",
                    text: $model
                )
                .textFieldStyle(.roundedBorder)
            }
        }
        .padding(12)
    }

    // MARK: - Input Area

    private var inputArea: some View {
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

            TextEditor(text: $inputText)
                .font(.system(size: 14))
                .frame(height: 170)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25))
                )
                .onChange(of: inputText) { _, newValue in
                    if autoTranslate {
                        service.translate(text: newValue, mode: mode)
                    }
                }
        }
        .padding(12)
    }

    // MARK: - Result Area

    private var resultArea: some View {
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
                    ScrollView {
                        Text(service.result)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .textSelection(.enabled)
                    }
                }
            }
            .font(.system(size: 14))
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
        }
        .padding(12)
    }
}
