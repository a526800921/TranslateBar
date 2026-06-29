import XCTest
import SwiftUI
import AppKit
@testable import TranslateBar

@MainActor
final class TranslatePanelViewTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TranslationConfiguration.persisted.set("http://127.0.0.1:8787/v1/chat/completions", forKey: TranslationConfiguration.Keys.endpoint)
        TranslationConfiguration.persisted.set("/path/to/model", forKey: TranslationConfiguration.Keys.model)
        TranslationConfiguration.persisted.set(false, forKey: TranslationConfiguration.Keys.streamingEnabled)
    }

    override func tearDown() {
        TranslationConfiguration.persisted.removeObject(forKey: TranslationConfiguration.Keys.endpoint)
        TranslationConfiguration.persisted.removeObject(forKey: TranslationConfiguration.Keys.model)
        TranslationConfiguration.persisted.removeObject(forKey: TranslationConfiguration.Keys.streamingEnabled)
        super.tearDown()
    }

    @discardableResult
    private func render<V: View>(_ view: V) -> NSHostingView<V> {
        let h = NSHostingView(rootView: view)
        h.frame = NSRect(x: 0, y: 0, width: 420, height: 520)
        h.layout()
        return h
    }

    /// 通过 Mirror 修改 TranslatePanelView 的 @State / @StateObject 属性
    private func mutateView(_ view: inout TranslatePanelView,
                            _ block: (inout ViewState) -> Void) {
        var state = ViewState()
        let mirror = Mirror(reflecting: view)

        for child in mirror.children {
            // Try to access TranslationService via @StateObject
            if let svc = child.value as? TranslationService {
                state.translationService = svc
            }
            // Try to access ModelListService
            if let mls = child.value as? ModelListService {
                state.modelListService = mls
            }
            // Try to access LoginItemService
            if let lis = child.value as? LoginItemService {
                state.loginItemService = lis
            }
            // Try to access @State<Bool> (e.g. showsSettings, autoTranslate)
            // The Mirror child label for @State is like "_showsSettings"
            if let label = child.label {
                switch label {
                case "_showsSettings":
                    if let wrapper = Mirror(reflecting: child.value).children.first(where: { $0.label == "_value" })?.value as? Bool {
                        state.showsSettings = wrapper
                    }
                case "_autoTranslate":
                    if let wrapper = Mirror(reflecting: child.value).children.first(where: { $0.label == "_value" })?.value as? Bool {
                        state.autoTranslate = wrapper
                    }
                default:
                    break
                }
            }
        }
        block(&state)
    }

    private struct ViewState {
        var translationService: TranslationService?
        var modelListService: ModelListService?
        var loginItemService: LoginItemService?
        var showsSettings: Bool = false
        var autoTranslate: Bool = true
    }

    // MARK: - Full body in various states

    func test_fullBodyDefault() { render(TranslatePanelView()) }

    func test_fullBodyStreamingEnabled() {
        TranslationConfiguration.persisted.set(true, forKey: TranslationConfiguration.Keys.streamingEnabled)
        render(TranslatePanelView())
    }

    func test_fullBodyCustomEndpoint() {
        TranslationConfiguration.persisted.set("http://example.com:8080/v1/chat/completions", forKey: TranslationConfiguration.Keys.endpoint)
        render(TranslatePanelView())
    }

    func test_fullBodyMultipleTimes() {
        for _ in 0..<3 { render(TranslatePanelView()) }
    }

    // MARK: - Subview rendering (internal access)

    func test_headerRenders() { render(TranslatePanelView().header) }
    func test_settingsRenders() { render(TranslatePanelView().settingsArea) }
    func test_inputRenders() { render(TranslatePanelView().inputArea) }
    func test_resultRenders() { render(TranslatePanelView().resultArea) }

    func test_allSubviewsRender() {
        let v = TranslatePanelView()
        render(v.header)
        render(v.settingsArea)
        render(v.inputArea)
        render(v.resultArea)
    }

    // MARK: - Service state injection via Mirror

    func test_resultWithTranslationSet() {
        var v = TranslatePanelView()
        let m = Mirror(reflecting: v)
        for c in m.children {
            if let svc = c.value as? TranslationService {
                svc.result = "Hello World"
                svc.errorMessage = nil
            }
        }
        render(v.resultArea)
    }

    func test_resultWithError() {
        var v = TranslatePanelView()
        let m = Mirror(reflecting: v)
        for c in m.children {
            if let svc = c.value as? TranslationService {
                svc.result = ""
                svc.errorMessage = "Something went wrong"
            }
        }
        render(v.resultArea)
    }

    func test_resultLoading() {
        var v = TranslatePanelView()
        let m = Mirror(reflecting: v)
        for c in m.children {
            if let svc = c.value as? TranslationService {
                svc.isLoading = true
            }
        }
        render(v.resultArea)
    }

    func test_resultEmpty() {
        var v = TranslatePanelView()
        let m = Mirror(reflecting: v)
        for c in m.children {
            if let svc = c.value as? TranslationService {
                svc.result = ""
                svc.errorMessage = nil
                svc.isLoading = false
            }
        }
        render(v.resultArea)
    }

    func test_bodyWithAllServiceStates() {
        var v = TranslatePanelView()
        // Setup services
        let m = Mirror(reflecting: v)
        for c in m.children {
            if let svc = c.value as? TranslationService {
                svc.result = "Translated text"
                svc.isLoading = false
                svc.errorMessage = nil
            }
            if let mls = c.value as? ModelListService {
                mls.models = ["model1", "model2"]
            }
        }
        render(v)
    }

    // MARK: - ModelListService states

    func test_modelListService_nonEmpty() async {
        let mock = MockURLSession()
        mock.mockData = #"{"data":[{"id":"model-1"},{"id":"model-2"}]}"#.data(using: .utf8)
        mock.mockResponse = MockURLSession.successResponse()
        let svc = ModelListService(session: mock)
        TranslationConfiguration.persisted.set("http://127.0.0.1:8787/v1/chat/completions", forKey: TranslationConfiguration.Keys.endpoint)
        TranslationConfiguration.persisted.set("/model", forKey: TranslationConfiguration.Keys.model)

        await svc.fetchModels()
        XCTAssertEqual(svc.models, ["model-1", "model-2"])
        XCTAssertNil(svc.errorMessage)
        XCTAssertFalse(svc.isLoading)
    }

    func test_modelListService_empty() async {
        let mock = MockURLSession()
        mock.mockData = #"{"data":[]}"#.data(using: .utf8)
        mock.mockResponse = MockURLSession.successResponse()
        let svc = ModelListService(session: mock)
        TranslationConfiguration.persisted.set("http://127.0.0.1:8787/v1/chat/completions", forKey: TranslationConfiguration.Keys.endpoint)
        TranslationConfiguration.persisted.set("/model", forKey: TranslationConfiguration.Keys.model)

        await svc.fetchModels()
        XCTAssertTrue(svc.models.isEmpty)
        XCTAssertNotNil(svc.errorMessage)
    }

    func test_modelListService_loadingState() {
        let svc = ModelListService()
        XCTAssertFalse(svc.isLoading)
        // 设置 models 后 isLoading 应为 false
        XCTAssertTrue(svc.models.isEmpty)
    }

    // MARK: - Default State Assertions

    func test_defaultTranslationMode_isAuto() {
        XCTAssertEqual(TranslationMode.auto.rawValue, "自动")
        XCTAssertEqual(TranslationMode.allCases.count, 3)
    }

    func test_allTranslationModes_exist() {
        let modes = TranslationMode.allCases
        XCTAssertEqual(modes.count, 3)
        XCTAssertTrue(modes.contains(.auto))
        XCTAssertTrue(modes.contains(.zhToEn))
        XCTAssertTrue(modes.contains(.enToZh))
    }

    // MARK: - TranslationService

    func test_translationServiceInitialState() {
        let svc = TranslationService()
        XCTAssertEqual(svc.result, "")
        XCTAssertFalse(svc.isLoading)
        XCTAssertNil(svc.errorMessage)
    }

    func test_translationService_cancel() {
        let svc = TranslationService()
        svc.isLoading = true
        svc.cancel()
        XCTAssertFalse(svc.isLoading)
    }

    func test_translationService_emptyText() async throws {
        let svc = TranslationService()
        svc.result = "old"
        svc.translate(text: "", mode: .auto)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(svc.result, "")
        XCTAssertFalse(svc.isLoading)
    }

    // MARK: - LoginItemService

    func test_loginItemService_initial() {
        let svc = LoginItemService(service: MockSMAppService())
        svc.refresh()
        XCTAssertFalse(svc.isEnabled)
    }

    func test_loginItemService_enabled() {
        let mock = MockSMAppService()
        mock.mockStatus = .enabled
        let svc = LoginItemService(service: mock)
        svc.refresh()
        XCTAssertTrue(svc.isEnabled)
        XCTAssertNil(svc.statusMessage)
    }

    func test_loginItemService_requiresApproval() {
        let mock = MockSMAppService()
        mock.mockStatus = .requiresApproval
        let svc = LoginItemService(service: mock)
        svc.refresh()
        XCTAssertTrue(svc.statusMessage?.contains("等待系统批准") ?? false)
    }

    func test_loginItemService_notFound() {
        let mock = MockSMAppService()
        mock.mockStatus = .notFound
        let svc = LoginItemService(service: mock)
        svc.refresh()
        XCTAssertTrue(svc.statusMessage?.contains("未找到") ?? false)
    }

    // MARK: - Configuration

    func test_configurationKeys() {
        XCTAssertEqual(TranslationConfiguration.Keys.endpoint, "translationEndpoint")
        XCTAssertEqual(TranslationConfiguration.Keys.model, "translationModel")
        XCTAssertEqual(TranslationConfiguration.Keys.streamingEnabled, "translationStreamingEnabled")
    }

    // MARK: - Internal Methods

    func test_makePrompt_allModes() {
        let svc = TranslationService()
        for mode in TranslationMode.allCases {
            let p = svc.makePrompt(text: "test", mode: mode)
            XCTAssertTrue(p.contains("test"))
        }
    }

    func test_readableError_allTranslationErrors() {
        let svc = TranslationService()
        for e: TranslationError in [.invalidEndpoint(""), .invalidEndpoint("x"), .emptyModel, .invalidResponse, .emptyContent, .httpError(statusCode: 400, message: "e"), .httpError(statusCode: 503, message: "")] {
            XCTAssertFalse(svc.readableError(e).isEmpty)
        }
    }

    func test_readableError_allUrlErrors() {
        let svc = TranslationService()
        for c: URLError.Code in [.cannotConnectToHost, .notConnectedToInternet, .networkConnectionLost, .timedOut, .dnsLookupFailed, .badURL, .cancelled, .secureConnectionFailed] {
            XCTAssertFalse(svc.readableError(URLError(c)).isEmpty)
        }
    }

    func test_parseErrorMessage_valid() {
        let svc = TranslationService()
        XCTAssertEqual(svc.parseErrorMessage(from: #"{"error":{"message":"test"}}"#.data(using: .utf8)!), "test")
    }

    func test_parseErrorMessage_invalid() {
        let svc = TranslationService()
        XCTAssertTrue(svc.parseErrorMessage(from: Data()).isEmpty)
    }
}
