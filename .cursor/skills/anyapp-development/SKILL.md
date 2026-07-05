---
name: anyapp-development
description: Implement and modify features in the anyapp iOS memo app (recording, transcription, item detail UI, SwiftData). Use when changing Swift files under anyapp/, adding memo/recording/STT behavior, or fixing keyboard and navigation layout in ItemDetailView.
paths:
  - "anyapp/**/*.swift"
  - "anyappTests/**/*.swift"
---

# anyapp development

Guide for implementing features in the anyapp iOS + SwiftUI memo app.

## When to Use

- Adding or changing memo, recording, playback, or transcription behavior
- Editing `ItemDetailView`, `ContentView`, `Item`, or STT/recording services
- Fixing keyboard, scroll, or toolbar layout in item detail
- Writing or updating tests in `anyappTests/`

## Architecture

```
ContentView          — memo list, + button, phone/tablet navigation split
ItemDetailView       — notebook UI: saved notes, playback, input bar, mic
Item (SwiftData)     — timestamp, textNote, audioFileName, audioDuration, lastTranscribedAudioFileName
AudioRecorder        — mic permission + AVAudioRecorder lifecycle (sync stop only)
STTRouter            — routes to Grok or on-device Apple Speech based on STTMode
AudioFileStore       — UUID .m4a files in Documents directory
```

### Recording pipeline (do not break this contract)

1. **Start:** `AudioFileStore.newRecordingURL()` → `AudioRecorder.startRecording(to:)`
2. **Stop:** `AudioRecorder.stopRecording()` returns duration synchronously — no STT inside `AudioRecorder`
3. **Persist:** set `item.audioFileName` and `item.audioDuration`, then `modelContext.save()`
4. **Transcribe:** async via `STTRouter.transcribe`, append with `item.appendTextEntry`, set `lastTranscribedAudioFileName`

Before replacing audio on re-record, await any in-flight transcription (`ensureTranscriptionCompleteBeforeReplacingAudio`).

### Item detail layout rules

- Use a **VStack**: `ScrollView` (saved note + playback) above a fixed **input toolbar** (text field, save, mic).
- Do **not** put the toolbar inside the ScrollView — keyboard inset must compress scroll content, not the bar.
- Toolbar background uses `.bar` with `.ignoresSafeArea(.container, edges: .bottom)` only (never into keyboard region).
- Mic lives in the input bar: idle = `mic.fill`, recording = red circle + `pause.fill` + timer.
- Korean UI copy is the project default (e.g. "생각을 적어보세요", "저장", "변환 중…").

### Navigation

- **iPhone:** single `NavigationStack` with `navigationDestination(for: PersistentIdentifier.self)` — never duplicate `ItemDetailView`.
- **iPad:** `NavigationSplitView` with sidebar selection; detail column shows `ItemDetailView` directly.

## Implementation checklist

1. Read existing code in the target area before editing; match naming, `@Observable` / `@State` patterns, and `@MainActor` usage.
2. Keep platform scope **iOS + SwiftUI only** unless explicitly requested.
3. Persist with **SwiftData** on `Item`; store audio files on disk via `AudioFileStore`, not in the model blob.
4. Inject test seams (`MicrophonePermissionProviding`, `AudioSessionControlling`, `RecordingEngineFactory`) rather than calling AVFoundation directly in new recording code.
5. Add **`accessibilityIdentifier`** on interactive controls you add or change (existing IDs: `micButton`, `saveMemoButton`, `playbackButton`, `transcribingLabel`, `recordingTimer`).
6. Handle edge cases already modeled: permission denied, empty recording, transcription failure with retry, draft auto-save on disappear.

## Testing

- Use **Swift Testing** (`import Testing`, `@Test`) in `anyappTests/`.
- Mock AVFoundation via the protocols in `AudioRecorder.swift`; see `RecordingFlowTests.swift` and `TranscriptionFlowTests.swift` for patterns.
- When changing persistence contracts, assert on `Item` fields the same way `RecordingFlowTests` mirrors `finishRecording`.
- Run CI locally if available: `xcodebuild test` or the project's GitHub Actions workflow.

## Git workflow

- One branch per feature (`cursor/<description>-5770`).
- Commit incrementally with clear messages.
- Do not mix unrelated changes on the same branch.

## Key files

| File | Role |
|------|------|
| `anyapp/ContentView.swift` | List, toolbar, navigation |
| `anyapp/ItemDetailView.swift` | Memo notebook, recording, playback, STT |
| `anyapp/Item.swift` | SwiftData model + `appendTextEntry` / `deleteAudioFile` |
| `anyapp/AudioRecorder.swift` | Recording engine + injectable seams |
| `anyapp/Services/STTRouter.swift` | Grok vs on-device transcription routing |
| `anyapp/Views/APIKeySettingsView.swift` | Grok API key + STT mode settings |

## Avoid

- macOS, watchOS, or UIKit view controllers unless explicitly requested
- STT or network calls inside `AudioRecorder.stopRecording()`
- Nested NavigationStacks that instantiate `ItemDetailView` twice on iPhone
- English-only strings when surrounding UI is Korean
