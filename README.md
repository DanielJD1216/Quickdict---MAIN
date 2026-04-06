# Quickdict

Local-first voice dictation for macOS.

Quickdict is a native macOS app for system-wide dictation with local ASR models and optional local text transforms through Ollama.

## What It Does

- Hold-to-record dictation with a global trigger key
- Local transcription with Parakeet v3 or Qwen3 ASR
- Optional post-processing: filler removal, false-start cleanup, number conversion, bullet formatting
- Output to clipboard and active app
- Transform selected text with local Ollama models

## System Requirements

- macOS 14 or later
- Apple Silicon Mac
- Microphone access
- Accessibility access
- Input Monitoring access
- Internet only when downloading models

## Install

### DMG Install

1. Open `Quickdict-1.0.1.dmg`
2. Drag `Quickdict.app` into `Applications`
3. Open `Applications/Quickdict.app`

If macOS blocks the app the first time:

1. Right-click `Quickdict.app`
2. Click `Open`
3. Confirm the warning dialog

### Required Permissions

Enable Quickdict in:

1. `System Settings > Privacy & Security > Accessibility`
2. `System Settings > Privacy & Security > Input Monitoring`
3. `System Settings > Privacy & Security > Microphone`

If you change Accessibility or Input Monitoring, quit and relaunch Quickdict.

## Models

### ASR Models

- `Parakeet v3`
  - fastest dictation path
  - English-focused
- `Qwen3 ASR`
  - multilingual
  - slower than Parakeet
  - prefers `int8` when available

### Transform Models

Transform models run through Ollama and are managed separately from ASR models.

Recommended:

- `Qwen 3.5 2B` for fastest transform response

Optional:

- `Qwen 3.5 4B`
- `Qwen 3.5 9B`

Quickdict can install these through the Models screen if Ollama is installed.

## Ollama Setup

If you want transform mode:

1. Install Ollama

```bash
brew install ollama
```

2. Start Ollama

```bash
ollama serve
```

3. In Quickdict, open `Models`
4. Under `Transform Models`, install and select a Qwen 3.5 model

## Usage

### Dictation

1. Open Quickdict
2. Hold the trigger key or use the Dictation screen controls
3. Speak
4. Release the trigger to transcribe

### Transform Selected Text

1. Select text in another app
2. Make sure `Transform selected text` is enabled
3. Dictate a command like:
   - `rewrite more formally`
   - `make this more humorous`
   - `remove orange juice from this list`
4. Quickdict will replace the selected text with the transformed version

## Build From Source

```bash
xcodegen generate
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Quickdict.xcodeproj \
  -scheme Quickdict \
  -configuration Release \
  -derivedDataPath ./build \
  build
```

## Local Signed Install

If you are developing locally and want a stable installed app identity:

```bash
./Scripts/install-local-signed.sh
```

This script:

- builds Quickdict
- copies it to `/Applications/Quickdict.app`
- signs it with a local Apple Development identity if available

## Create DMG

```bash
./Scripts/create-dmg.sh
```

This creates:

- `Quickdict-1.0.1.dmg`

## Troubleshooting

### Global hotkey does not work

Check:

1. Accessibility is enabled
2. Input Monitoring is enabled
3. You relaunched Quickdict after enabling them

### Dictation records but no text appears

Check:

1. Microphone permission is enabled
2. The selected ASR model shows `Ready`
3. You are using `Parakeet v3` for lowest latency

### Transform does nothing

Check:

1. Ollama is running
2. A transform model is installed and selected
3. Text was selected before dictation started

## Distribution Notes

For other people to use the app, the most practical path is:

1. Build a release app
2. Create a DMG
3. Upload the DMG to a GitHub Release
4. Include these permission steps in the release notes

If you want fully smooth public distribution, the long-term path is Apple code signing + notarization.
