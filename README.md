# VoiceInput

A macOS 14+ menu-bar voice input app.

## Build

```sh
make build
```

The signed app bundle is written to:

```sh
.build/release/VoiceInput.app
```

By default the bundle uses ad-hoc signing. To use a specific signing identity:

```sh
make build SIGN_IDENTITY="Developer ID Application: Example"
```

## Run

```sh
make run
```

The app runs as `LSUIElement`, so it only appears in the menu bar.

## Permissions

Grant these macOS permissions when prompted:

- Microphone
- Speech Recognition
- Accessibility or Input Monitoring for the global Fn key event tap

Hold Fn to record. Release Fn to paste the recognized text into the currently focused input field.

## LLM Refinement

Use the menu-bar `LLM Refinement > Settings...` item to configure:

- API Base URL, for example `https://api.openai.com/v1`
- API Key
- Model

The API must be compatible with OpenAI Chat Completions at `/chat/completions`.
