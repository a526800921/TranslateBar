# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TranslateBar is a macOS menu-bar-only translation app. It lives in the menu bar (`LSUIElement = true`), shows an `NSPopover` on click, and calls a local OpenAI Chat Completions-compatible API (`http://127.0.0.1:8787/v1/chat/completions`) with the model `/Users/jafish/Documents/models/Hy-MT2-7B-4bit` to perform Chinese↔English translation.

## Build & Install

```bash
# Build (Debug or Release)
xcodebuild -project TranslateBar.xcodeproj -scheme TranslateBar -configuration Release build

# Full install: build → install to ~/Applications → clean duplicates → re-register LaunchServices
./scripts/install_app.sh
```

**Important**: Running bare `xcodebuild build` (or building in Xcode IDE) registers the DerivedData copy with LaunchServices, creating a duplicate in Launchpad. Always use `./scripts/install_app.sh` for the final install — it unregisters stale copies via `lsregister -u` before deleting them, then registers only `~/Applications/TranslateBar.app`.

## Architecture

```
TranslateBarApp.swift          — @main entry point, bridges to AppDelegate via @NSApplicationDelegateAdaptor
  └─ AppDelegate.swift         — NSStatusBar icon + NSPopover with NSHostingController(rootView: TranslatePanelView())
       └─ TranslatePanelView.swift — Main UI: header (auto-translate toggle, mode picker, quit/settings buttons),
                                      settings area (endpoint/model config, login-item toggle),
                                      input area (TextEditor + translate/clear buttons),
                                      result area (output text, copy button, error display)
            ├─ TranslationService.swift  — @MainActor ObservableObject, calls local API, UUID-based task cancellation
            ├─ TranslationConfiguration.swift — UserDefaults-backed endpoint/model configuration
            ├─ LoginItemService.swift    — SMAppService.mainApp wrapper (enable/disable/refresh), Chinese error messages
            └─ Models.swift              — ChatCompletionRequest/Response, ChatMessage, TranslationMode enum, TranslationError
```

### Key Patterns

- **Task cancellation**: `TranslationService` uses a `currentTranslateId: UUID?` to detect stale tasks. When a new translation starts, it cancels the previous `Task` and assigns a new UUID. Before applying results, it checks `currentTranslateId == id` — this prevents cancelled tasks from overwriting newer ones.
- **300ms debounce**: After input changes (when auto-translate is on), the service sleeps 300ms before sending the request.
- **Configuration**: `TranslationConfiguration` reads/writes `UserDefaults` via `@AppStorage` keys (`translationEndpoint`, `translationModel`). The `current()` factory provides defaults from `TranslateBar.fixed.md`.
- **TranslationMode.auto**: Detects Chinese characters (Unicode range `0x4E00–0x9FFF`) — if present, translates to English; otherwise translates to Chinese.
- **Login item**: `LoginItemService` wraps `SMAppService.mainApp`. Default is off. Toggle in settings area with Chinese error feedback.

### Deployment Target

- macOS 15.0 (`MACOSX_DEPLOYMENT_TARGET = 15.0`)
- Swift 5.0
- arm64 (Apple Silicon)
- Code sign: Automatic, Hardened Runtime enabled

## Development Governance

This project uses plan-governed development. See `docs/PLAN_MAP.md` for the plan index, dependencies, and completion evidence. Multi-step changes that alter API contracts, packaging, or startup behavior should go through a plan. One-off fixes do not.

Completed plans (all phases done):
- `translatebar-v1` — core menu bar app
- `service-settings-and-install` — configurable endpoint/model, install to ~/Applications
- `install-cleanup-and-login-item` — build/install/cleanup script, login-item toggle

The original spec baseline is `TranslateBar.fixed.md`.
