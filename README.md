# ControlAll

A macOS menu bar application for managing local development projects and services.

## Features

- **Menu Bar App**: Runs in the macOS menu bar with a clean icon
- **Project Management**: Organize projects with multiple services
- **Service Control**: Start/stop services with one click
- **Browser Opening**: Open running services directly in your browser
- **Start at Login**: Option to launch ControlAll automatically on startup
- **Collapsible Projects**: Expand/collapse projects to fit your workflow

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/chongdlz/controlall-macos.git
   ```

2. Generate the Xcode project:
   ```bash
   cd controlall-macos
   xcodegen generate
   ```

3. Open `ControlAll.xcodeproj` in Xcode and build.

## Usage

- **Left-click** the menu bar icon to show the project panel
- **Right-click** for options (Show Projects, Settings, Start at Login, Quit)
- Click **+** to expand a project and see its services
- Click **▶ All** to start all services in a project
- Click **Settings** (⚙️) to configure projects

## Configuration

In Settings, you can add:
- **Project Name**: A descriptive name for your project
- **Services**: Each service has:
  - **Name**: e.g., "Frontend", "Backend", "Database"
  - **Command**: The start command (e.g., `npm run dev`, `python manage.py runserver`)
  - **Port**: The port number (optional)
  - **Working Directory**: The directory to run the command in

## Requirements

- macOS 10.15 or later
- Xcode 15 or later (for building)

## Tech Stack

- Native macOS with AppKit
- NSPanel for native window management
- WKWebView for the UI
- ServiceManagement for login item support
