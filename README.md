# The Orchestra

A kid-friendly AI assistant app with animated agents.

## Requirements

- macOS 14.0+
- Xcode 15+ (for Swift 5.10)

## Build & Run

```bash
# Clone the repo
git clone https://github.com/devpras22/the-orchestra.git
cd the-orchestra
swift build
swift run the-orchestra
```

## How It Works

1. **React UI** - The 3D interface runs in a WKWebView
2. **Swift Backend** - Handles tmux sessions and hooks
3. **Bundled tmux** - Includes tmux binary (no install needed)

## Build Pipeline

After React changes:
```bash
cd _delegation-reference
npm run build
cp -r dist/* ../Sources/Resources/web/
cd ..
swift build
```

## Project Structure

```
theOrchestra/
├── Sources/           # Swift code
│   ├── bin/tmux       # Bundled tmux binary
│   └── Resources/web/ # React UI
├── _delegation-reference/  # React app
└── Package.swift
```

## Acknowledgments

This project builds upon the amazing work of:
- **[The Delegation](https://github.com/arturitu/the-delegation)** - The 3D multi-agent React interface with animated avatars
- **[MASKO](https://github.com/RousselPaul/masko-code)** - The backend for parsing Claude Code terminal output into structured events

## License

Private
