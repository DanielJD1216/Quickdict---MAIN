# Architecture

## High-Level Flow

1. Global trigger starts a dictation session
2. `AVAudioEngine` captures raw microphone audio
3. Raw session audio is buffered during recording
4. On stop, audio is downmixed/resampled to 16 kHz mono Float32
5. Selected ASR backend transcribes the normalized audio
6. Optional text-processing pipeline runs
7. Output is copied/pasted or routed through selected-text transform flow

## Main Subsystems

### App
- `AppDelegate` owns app lifecycle, hotkey wiring, and dictation completion handling
- `AppStatusCenter` exposes synchronized app state to the UI

### Audio
- `AudioCaptureManager` handles capture, buffering, conversion, and diagnostics
- `VoiceActivityDetector` provides basic speech detection

### ASR
- `ASREngine` switches between:
  - Parakeet v3 via `FluidAudio`
  - Qwen3 ASR via `FluidAudio`

### Transform
- `TransformManager` routes selected-text transformations through Ollama
- Qwen 3.5 transform models are managed separately from ASR models

### Output
- `OutputManager` handles clipboard, paste, and selected-text capture fallback

## Current Tradeoffs

- Parakeet is the low-latency dictation path
- Qwen ASR is multilingual but slower
- Transform reliability still depends on target app selection/paste behavior
