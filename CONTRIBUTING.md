# Contributing

## Development Setup

1. Install Xcode 15+
2. Install XcodeGen

```bash
brew install xcodegen
```

3. Generate the project

```bash
xcodegen generate
```

4. Build or run tests

```bash
xcodebuild -project Quickdict.xcodeproj -scheme Quickdict -configuration Debug build
xcodebuild -project Quickdict.xcodeproj -scheme Quickdict -configuration Debug test
```

## Guidelines

- Keep changes small and focused
- Prefer minimal fixes over broad rewrites unless the architecture truly requires it
- Preserve existing user-facing behavior unless the change intentionally improves it
- Add or update tests for processing logic when changing text-processing behavior
- Document known tradeoffs instead of hiding them behind optimistic labels

## Bug Reports

When filing bugs, include:

- macOS version
- Apple Silicon model
- selected ASR model
- selected transform model (if relevant)
- whether Accessibility, Input Monitoring, and Microphone permissions are enabled
- reproduction steps
- screenshots of diagnostics when relevant
