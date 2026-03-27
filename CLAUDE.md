# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ControlAll is a native macOS menu bar application for managing local development projects and services. It displays in the menu bar and provides a panel for controlling multiple services across different projects.

## Build Commands

```bash
# Generate Xcode project from project.yml
xcodegen generate

# Build the project
xcodebuild -project ControlAll.xcodeproj -scheme ControlAll -configuration Debug build

# Run the app
open ~/Library/Developer/Xcode/DerivedData/ControlAll-*/Build/Products/Debug/ControlAll.app
```

## Architecture

- **Entry Point**: `Sources/main.swift` - Manual NSApplication startup (not using @main)
- **Main Logic**: `Sources/AppDelegate.swift` - Contains all application logic:
  - Status item and menu bar icon setup
  - NSPanel management for project panel and settings panel
  - WKWebView for HTML-based UI
  - Service management (start/stop processes)
  - UserDefaults persistence for projects data
  - Login item support via ServiceManagement framework
- **UI**: Dynamic HTML strings generated in `generateMainHTML()` and `generateConfigHTML()` methods
- **Communication**: WKScriptMessageHandler for JS-to-Swift bridge

## Key Components

### Panels
- **Project Panel**: Borderless floating panel below status item, shows projects and services
- **Settings Panel**: Centered titled panel with resize handles, for project configuration

### Data Model
Projects stored in UserDefaults as JSON:
```swift
projects: [[String: Any]]  // Array of projects
project: ["name": String, "services": [[String: Any]]]
service: ["name": String, "command": String, "port": Int, "workingDir": String]
```

### Menu Bar Icon
White circle with "AI" text, created programmatically via `createStatusBarIcon()` using NSImage drawing.

## File Structure

```
controlall-macos/
├── Sources/
│   ├── main.swift          # App entry point
│   ├── AppDelegate.swift   # All application logic
│   └── Info.plist          # LSUIElement=true (menu bar only app)
├── project.yml             # XcodeGen configuration
└── ControlAll.xcodeproj/   # Generated Xcode project
```

## Requirements

- macOS 10.15+
- Xcode 15+
- XcodeGen for project generation
