# Quickdict

Local-First Voice Dictation for macOS

## Features

- **Hold-to-record dictation** - Press and hold Right Option to record, release to transcribe
- **Lock mode** - Hold trigger and press Space for extended recording
- **Text processing** - Automatic filler word removal, false start detection, number conversion
- **Auto-paste** - Automatically paste transcribed text into any app
- **Transform selected text** - Use voice commands to transform selected text (requires Ollama)
- **Local-first** - All dictation runs on-device using Apple Neural Engine

## System Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3/M4)
- No internet required for core dictation

## Installation

### Step 1: Mount the DMG

Double-click `Quickdict-1.0.0.dmg` to mount it.

### Step 2: Copy to Applications

Drag `Quickdict.app` to your Applications folder.

### Step 3: Open the App

Right-click on Quickdict.app and select "Open" (required for Gatekeeper bypass on unsigned apps).

Alternatively, you can run:
```bash
xattr -cr /Applications/Quickdict.app
open /Applications/Quickdict.app
```

### Step 4: Grant Permissions

The app will request two permissions:

1. **Microphone Permission** - Required for dictation
   - System Settings → Privacy & Security → Microphone
   - Enable Quickdict

2. **Accessibility Permission** - Required for global hotkey and text insertion
   - System Settings → Privacy & Security → Accessibility
   - Enable Quickdict

## Transform Feature (Optional)

The transform feature lets you transform selected text using voice commands like:
- "rewrite more formally"
- "reformat as bullets"
- "make it shorter"
- "translate to Spanish"

### Setup Transform Feature

1. **Install Ollama**
   ```bash
   brew install ollama
   ```

2. **Pull Qwen 2.5 2B model**
   ```bash
   ollama pull qwen2.5:2b
   ```

3. **Start Ollama** (runs automatically on login if installed via Homebrew)
   ```bash
   ollama serve
   ```

4. Enable "Transform selected text" in Quickdict Settings

## Usage

### Starting Dictation

1. Click the microphone icon in the menu bar
2. Or hold **Right Option** (default trigger) in any app
3. Speak your text
4. Release to transcribe

### Lock Mode

While holding the trigger key, press **Space** to lock recording for longer takes. Press the trigger again to stop.

### Transform Mode

1. Select text in any app
2. Hold trigger and speak a command (e.g., "rewrite more formally")
3. The selected text will be replaced with the transformed version

### Settings

Click the menu bar icon → Settings to configure:
- Trigger key (Right Option, FN/Globe, or custom)
- Microphone selection
- ASR model (Parakeet v3 or Qwen3 ASR)
- Text processing options
- Output behavior (auto-paste, clipboard, auto-send)

## Troubleshooting

### App doesn't respond to hotkey

1. Check System Settings → Privacy & Security → Accessibility
2. Ensure Quickdict is enabled

### No audio input detected

1. Check System Settings → Privacy & Security → Microphone
2. Ensure Quickdict is enabled
3. Try refreshing microphones in Settings

### Text doesn't paste

1. Ensure the target app has a text field focused
2. Check that Accessibility permission is granted

### Transform not working

1. Ensure Ollama is installed: `brew install ollama`
2. Ensure Qwen model is pulled: `ollama pull qwen2.5:2b`
3. Ensure Ollama is running: `ollama serve`
4. Check "Transform selected text" is enabled in Settings

## Architecture

```
Quickdict/
├── Sources/
│   ├── App/              main.swift, AppDelegate.swift
│   ├── Core/
│   │   ├── Audio/       AVAudioEngine capture, VAD
│   │   ├── ASR/         CoreML inference (demo mode)
│   │   ├── LLM/         Transform via Ollama
│   │   ├── Processing/  Text pipeline (fillers, ITN, etc.)
│   │   └── Output/      Clipboard, auto-paste, auto-send
│   ├── Hotkey/           Carbon Events global hotkey
│   ├── Settings/         UserDefaults persistence
│   └── UI/
│       ├── MenuBar/     Status item, recording indicator
│       └── Settings/    Settings panels
└── Resources/
    ├── Info.plist
    └── Quickdict.entitlements
```

## Building from Source

```bash
# Generate Xcode project
xcodegen generate

# Build
xcodebuild -project Quickdict.xcodeproj -scheme Quickdict -configuration Release build

# Create DMG
./Scripts/create-dmg.sh
```

## License

MIT License
