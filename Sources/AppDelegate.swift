import AppKit
import WebKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var configPanel: NSPanel!
    private var webView: WKWebView!
    private var configWebView: WKWebView!

    // Data
    private var projects: [[String: Any]] = []
    private var runningServices: [[String: Any]] = []

    // MARK: - Login Item

    private var isLoginItemEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return UserDefaults.standard.bool(forKey: "startAtLogin")
        }
    }

    private func setLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to set login item: \(error)")
            }
        } else {
            UserDefaults.standard.set(enabled, forKey: "startAtLogin")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadProjects()
        setupStatusItem()
        setupPanel()
        setupConfigPanel()
    }

    private func loadProjects() {
        if let data = UserDefaults.standard.data(forKey: "projects"),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            projects = decoded
        }
    }

    private func saveProjects() {
        if let encoded = try? JSONSerialization.data(withJSONObject: projects) {
            UserDefaults.standard.set(encoded, forKey: "projects")
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let icon = createStatusBarIcon()
            button.image = icon
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func createStatusBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // Draw white filled circle
            let circlePath = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            NSColor.white.setFill()
            circlePath.fill()

            // Draw "AI" letters with window background color to create hollow effect
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.windowBackgroundColor,
                .paragraphStyle: paragraphStyle
            ]
            let textSize = "AI".size(withAttributes: attrs)
            let letterRect = NSRect(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            "AI".draw(in: letterRect, withAttributes: attrs)

            return true
        }
        image.isTemplate = false
        return image
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!

        if event.type == .rightMouseUp {
            // Show menu on right click
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Show Projects", action: #selector(showPanel), keyEquivalent: "s"))
            menu.addItem(NSMenuItem(title: "Settings", action: #selector(showConfigPanel), keyEquivalent: ","))
            menu.addItem(NSMenuItem.separator())
            let loginItem = NSMenuItem(title: isLoginItemEnabled ? "✓ Start at Login" : "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
            loginItem.target = self
            menu.addItem(loginItem)
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit ControlAll", action: #selector(quit), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // Show panel on left click
            showPanel()
        }
    }

    // MARK: - Panels

    private func setupPanel() {
        let panelFrame = getStatusItemFrame()

        panel = NSPanel(contentRect: panelFrame,
                      styleMask: [.borderless, .nonactivatingPanel],
                      backing: .buffered,
                      defer: false)

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.hasShadow = true
        panel.backgroundColor = NSColor.clear
        panel.isMovableByWindowBackground = false
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 10
        panel.contentView?.layer?.masksToBounds = true

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "app")

        webView = WKWebView(frame: panel.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self

        panel.contentView?.addSubview(webView)

        loadMainHTML()
    }

    private func setupConfigPanel() {
        let panelFrame = getPanelFrame()

        configPanel = NSPanel(contentRect: panelFrame,
                             styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                             backing: .buffered,
                             defer: false)

        configurePanel(configPanel, title: "Settings")
        configPanel.isMovableByWindowBackground = true

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "app")

        configWebView = WKWebView(frame: configPanel.contentView!.bounds, configuration: config)
        configWebView.autoresizingMask = [.width, .height]
        configWebView.navigationDelegate = self

        configPanel.contentView?.addSubview(configWebView)

        loadConfigHTML()
    }

    private func configurePanel(_ panel: NSPanel, title: String) {
        panel.title = title
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = true
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.isOpaque = false
        panel.hasShadow = true
    }

    private func getPanelFrame() -> NSRect {
        let screen = NSScreen.main!
        let visibleFrame = screen.visibleFrame
        let panelWidth: CGFloat = 380
        let panelHeight: CGFloat = 450
        let x = visibleFrame.maxX - panelWidth - 10
        let y = visibleFrame.maxY - panelHeight - 25
        return NSRect(x: x, y: y, width: panelWidth, height: panelHeight)
    }

    private func getCenteredFrame() -> NSRect {
        let screen = NSScreen.main!
        let visibleFrame = screen.visibleFrame
        let panelWidth: CGFloat = 700
        let panelHeight: CGFloat = 550
        let x = visibleFrame.origin.x + (visibleFrame.width - panelWidth) / 2
        let y = visibleFrame.origin.y + (visibleFrame.height - panelHeight) / 2
        return NSRect(x: x, y: y, width: panelWidth, height: panelHeight)
    }

    private func getStatusItemFrame() -> NSRect {
        guard let button = statusItem.button,
              let buttonWindow = button.window else {
            return getPanelFrame()
        }

        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = buttonWindow.convertToScreen(buttonFrame)

        let panelWidth: CGFloat = 380
        let panelHeight: CGFloat = 450

        // Position directly below the status item button, aligned with it
        let x = screenFrame.origin.x
        let y = screenFrame.origin.y - panelHeight

        return NSRect(x: x, y: y, width: panelWidth, height: panelHeight)
    }

    private func trackClickOutside() {
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.panel.isVisible else { return }

            let clickLocation = event.locationInWindow
            let panelFrame = self.panel.frame

            // Check if click is outside the panel
            if !panelFrame.contains(clickLocation) {
                DispatchQueue.main.async {
                    self.panel.orderOut(nil)
                }
            }
        }
    }

    // MARK: - HTML Loading

    private func loadMainHTML() {
        let html = generateMainHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func loadConfigHTML() {
        let html = generateConfigHTML()
        configWebView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - HTML Generation

    private func generateMainHTML() -> String {
        var servicesHTML = ""

        for (idx, project) in projects.enumerated() {
            let name = project["name"] as? String ?? "Unknown"
            let services = project["services"] as? [[String: Any]] ?? []

            var runningCount = 0
            var serviceItems = ""
            for service in services {
                let serviceName = service["name"] as? String ?? "Service"
                let serviceCmd = service["command"] as? String ?? ""
                let port = service["port"] as? Int
                let workingDir = service["workingDir"] as? String ?? ""

                let isRunning = isServiceRunning(projectId: idx, serviceName: serviceName)
                if isRunning { runningCount += 1 }

                let statusClass = isRunning ? "running" : "stopped"
                let statusText = isRunning ? "Running" : "Stopped"
                let buttonClass = isRunning ? "stop" : "start"
                let buttonText = isRunning ? "■" : "▶"
                let portText = port != nil ? ":\(port!)" : ""

                serviceItems += """
                    <div class="service-item">
                        <span class="service-name">\(serviceName)</span>
                        <span class="service-port">\(portText)</span>
                        <span class="service-status \(statusClass)">\(statusText)</span>
                        <div class="service-actions">
                            <button class="action-btn \(buttonClass)" onclick="toggleService(\(idx), '\(serviceName)', '\(serviceCmd)', \(port ?? 0), '\(workingDir)')">\(buttonText)</button>
                            \(port != nil && isRunning ? "<button class='action-btn open' onclick=\"openBrowser('http://localhost:\(port!)')\">🌐</button>" : "")
                        </div>
                    </div>
                """
            }

            let projectStatus = runningCount > 0 ? "\(runningCount)/\(services.count) Running" : "Stopped"
            let allRunning = runningCount == services.count && services.count > 0
            let (btnClass, btnText, btnAction) = allRunning
                ? ("stop-all-btn", "■ All", "stopAllServices(\(idx))")
                : ("start-all-btn", "▶ All", "startAllServices(\(idx))")

            servicesHTML += """
                <div class="project-item" id="project-\(idx)">
                    <div class="project-header" onclick="toggleProject(\(idx))">
                        <button class="expand-btn" onclick="event.stopPropagation(); toggleProject(\(idx))">+</button>
                        <div class="project-icon">📦</div>
                        <div class="project-info">
                            <div class="project-name">\(name)</div>
                            <div class="project-status-text">\(projectStatus)</div>
                        </div>
                        <button class="\(btnClass)" onclick="\(btnAction)">\(btnText)</button>
                    </div>
                    <div class="services-list" id="services-\(idx)" style="display: none;">
                        \(serviceItems)
                    </div>
                </div>
            """
        }

        if projects.isEmpty {
            servicesHTML = """
                <div class="empty-state">
                    <div style="font-size: 40px;">📦</div>
                    <p>No projects configured</p>
                    <p style="font-size: 12px; color: #86868b; margin-top: 8px;">Click Settings to add projects</p>
                </div>
            """
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: #ffffff;
                    color: #333;
                    font-size: 13px;
                    padding: 12px;
                    -webkit-user-select: text;
                    user-select: text;
                }
                input[type="text"], input[type="number"] {
                    -webkit-user-select: text;
                    user-select: text;
                    -webkit-appearance: none;
                    appearance: none;
                    pointer-events: auto;
                }
                input:focus, input:hover {
                    -webkit-user-select: text;
                    user-select: text;
                }
                .header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding-bottom: 12px;
                    border-bottom: 1px solid #e5e5e5;
                    margin-bottom: 12px;
                }
                .header h1 { font-size: 15px; font-weight: 600; }
                .btn {
                    padding: 5px 12px;
                    border: none;
                    border-radius: 6px;
                    cursor: pointer;
                    font-size: 12px;
                    font-weight: 500;
                }
                .btn-settings { background: #e5e5e5; color: #333; padding: 5px 8px; }
                .btn-settings:hover { background: #d5d5d5; }

                .project-item {
                    background: #f5f5f7;
                    border-radius: 8px;
                    padding: 12px;
                    margin-bottom: 8px;
                }
                .project-header {
                    display: flex;
                    align-items: center;
                    gap: 10px;
                    margin-bottom: 8px;
                    cursor: pointer;
                }
                .project-icon {
                    width: 32px; height: 32px;
                    background: #e5e5e5;
                    border-radius: 6px;
                    display: flex; align-items: center; justify-content: center;
                    font-size: 16px;
                }
                .project-name { font-size: 14px; font-weight: 600; }
                .project-status-text { font-size: 11px; color: #86868b; margin-top: 2px; }
                .expand-btn {
                    width: 24px;
                    height: 24px;
                    background: #e5e5e5;
                    border: none;
                    border-radius: 4px;
                    font-size: 14px;
                    font-weight: bold;
                    cursor: pointer;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .expand-btn:hover { background: #d5d5d5; }
                .start-all-btn {
                    margin-left: auto;
                    padding: 4px 10px;
                    background: #34c759;
                    color: white;
                    border: none;
                    border-radius: 5px;
                    font-size: 11px;
                    font-weight: 500;
                    cursor: pointer;
                }
                .start-all-btn:hover { background: #2db84d; }
                .stop-all-btn {
                    margin-left: auto;
                    padding: 4px 10px;
                    background: #ff3b30;
                    color: white;
                    border: none;
                    border-radius: 5px;
                    font-size: 11px;
                    font-weight: 500;
                    cursor: pointer;
                }
                .stop-all-btn:hover { background: #fc2f23; }
                .start-all-btn:disabled {
                    background: #ccc;
                    cursor: not-allowed;
                }

                .services-list { margin-top: 8px; }
                .service-item {
                    display: flex;
                    align-items: center;
                    padding: 8px 10px;
                    background: white;
                    border-radius: 6px;
                    margin-top: 4px;
                    gap: 10px;
                }
                .service-name { font-size: 13px; font-weight: 500; min-width: 50px; }
                .service-port { font-size: 12px; color: #86868b; min-width: 40px; }
                .service-status {
                    font-size: 11px;
                    padding: 2px 8px;
                    border-radius: 10px;
                }
                .service-status.running { background: #d1f7d1; color: #1b7c1b; }
                .service-status.stopped { background: #f5f5f5; color: #86868b; }
                .service-actions { margin-left: auto; display: flex; gap: 4px; }
                .action-btn {
                    width: 26px; height: 26px;
                    border: none; border-radius: 5px;
                    cursor: pointer; font-size: 12px;
                    display: flex; align-items: center; justify-content: center;
                }
                .action-btn.start { background: #34c759; color: white; }
                .action-btn.stop { background: #ff3b30; color: white; }
                .action-btn.open { background: #0071e3; color: white; }
                .empty-state {
                    text-align: center;
                    padding: 40px 20px;
                    color: #86868b;
                }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>ControlAll</h1>
                <button class="btn btn-settings" onclick="showSettings()">⚙️</button>
            </div>
            <div class="projects-list">
                \(servicesHTML)
            </div>
            <script>
                function showSettings() {
                    window.webkit.messageHandlers.app.postMessage({type: 'showSettings'});
                }
                function toggleService(projectIdx, serviceName, command, port, workingDir) {
                    window.webkit.messageHandlers.app.postMessage({
                        type: 'toggleService',
                        projectIdx: projectIdx,
                        serviceName: serviceName,
                        command: command,
                        port: port,
                        workingDir: workingDir
                    });
                }
                function openBrowser(url) {
                    window.webkit.messageHandlers.app.postMessage({type: 'openBrowser', url: url});
                }
                function refresh() {
                    window.webkit.messageHandlers.app.postMessage({type: 'refresh'});
                }
                function startAllServices(projectIdx) {
                    window.webkit.messageHandlers.app.postMessage({type: 'startAllServices', projectIdx: projectIdx});
                }
                function stopAllServices(projectIdx) {
                    window.webkit.messageHandlers.app.postMessage({type: 'stopAllServices', projectIdx: projectIdx});
                }
                function toggleProject(projectIdx) {
                    var servicesDiv = document.getElementById('services-' + projectIdx);
                    var expandBtn = document.querySelector('#project-' + projectIdx + ' .expand-btn');
                    if (servicesDiv.style.display === 'none') {
                        servicesDiv.style.display = 'block';
                        expandBtn.textContent = '-';
                    } else {
                        servicesDiv.style.display = 'none';
                        expandBtn.textContent = '+';
                    }
                }
            </script>
        </body>
        </html>
        """
    }

    private func generateConfigHTML() -> String {
        var projectsHTML = ""

        for (idx, project) in projects.enumerated() {
            let name = project["name"] as? String ?? ""
            let services = project["services"] as? [[String: Any]] ?? []

            var servicesHTML = ""
            for (sIdx, service) in services.enumerated() {
                let sName = service["name"] as? String ?? ""
                let sCmd = service["command"] as? String ?? ""
                let sPort = service["port"] as? Int ?? 0
                let sDir = service["workingDir"] as? String ?? ""

                servicesHTML += """
                    <div class="service-row">
                        <input type="text" placeholder="Name" value="\(sName)" onchange="updateService(\(idx), \(sIdx), 'name', this.value)">
                        <input type="text" placeholder="Command" value="\(sCmd)" onchange="updateService(\(idx), \(sIdx), 'command', this.value)">
                        <input type="number" placeholder="Port" value="\(sPort > 0 ? String(sPort) : "")" onchange="updateService(\(idx), \(sIdx), 'port', this.value)">
                        <input type="text" placeholder="Work Dir" value="\(sDir)" onchange="updateService(\(idx), \(sIdx), 'workingDir', this.value)">
                        <button class="delete-btn" onclick="deleteService(\(idx), \(sIdx))">×</button>
                    </div>
                """
            }

            projectsHTML += """
                <div class="project-config">
                    <div class="project-config-header">
                        <input type="text" placeholder="Project Name" value="\(name)" onchange="updateProject(\(idx), this.value)">
                        <button class="delete-btn" onclick="deleteProject(\(idx))">Delete Project</button>
                    </div>
                    <div class="services-config">
                        \(servicesHTML)
                        <button class="add-service-btn" onclick="addService(\(idx))">+ Add Service</button>
                    </div>
                </div>
            """
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: #ffffff;
                    color: #333;
                    font-size: 13px;
                    padding: 40px 12px 12px 12px;
                }
                input[type="text"], input[type="number"] {
                    /* Use native input behavior */
                }
                .header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding-bottom: 12px;
                    border-bottom: 1px solid #e5e5e5;
                    margin-bottom: 12px;
                }
                .header h1 { font-size: 15px; font-weight: 600; }
                .btn {
                    padding: 5px 12px;
                    border: none;
                    border-radius: 6px;
                    cursor: pointer;
                    font-size: 12px;
                    font-weight: 500;
                }
                .btn-primary { background: #0071e3; color: white; }
                .btn-primary:hover { background: #0077ed; }
                .btn-back { background: #e5e5e5; color: #333; }

                .project-config {
                    background: #f5f5f7;
                    border-radius: 8px;
                    padding: 12px;
                    margin-bottom: 12px;
                }
                .project-config-header {
                    display: flex;
                    gap: 8px;
                    margin-bottom: 8px;
                }
                .project-config-header input {
                    flex: 1;
                    padding: 7px 10px;
                    border: 1px solid #d5d5d5;
                    border-radius: 5px;
                    font-size: 13px;
                }
                .services-config { margin-top: 8px; }
                .service-row {
                    display: flex;
                    gap: 6px;
                    margin-bottom: 6px;
                    align-items: center;
                }
                .service-row input {
                    padding: 6px 8px;
                    border: 1px solid #d5d5d5;
                    border-radius: 4px;
                    font-size: 12px;
                }
                .service-row input[type="number"] { width: 60px; flex: none; }
                .service-row .name-input { width: 80px; }
                .service-row .cmd-input { flex: 2; }
                .service-row .dir-input { flex: 2; }
                .delete-btn {
                    background: #ff3b30;
                    color: white;
                    border: none;
                    border-radius: 4px;
                    padding: 4px 10px;
                    font-size: 12px;
                    cursor: pointer;
                    flex: none;
                }
                .delete-btn {
                    background: #ff3b30;
                    color: white;
                    border: none;
                    border-radius: 4px;
                    padding: 4px 10px;
                    font-size: 12px;
                    cursor: pointer;
                }
                .delete-btn:hover { background: #fc2f23; }
                .add-service-btn {
                    background: none;
                    border: none;
                    color: #0071e3;
                    font-size: 12px;
                    cursor: pointer;
                    padding: 4px 0;
                }
                .add-service-btn:hover { text-decoration: underline; }
                .add-project-btn {
                    width: 100%;
                    padding: 12px;
                    background: #f5f5f7;
                    border: 2px dashed #d5d5d5;
                    border-radius: 8px;
                    color: #86868b;
                    font-size: 13px;
                    cursor: pointer;
                }
                .add-project-btn:hover { border-color: #0071e3; color: #0071e3; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>Settings</h1>
                <div>
                    <button class="btn btn-back" onclick="goBack()">← Back</button>
                    <button class="btn btn-primary" onclick="saveAndClose()">Save & Close</button>
                </div>
            </div>
            <div class="projects-list">
                \(projectsHTML)
                <button class="add-project-btn" onclick="addProject()">+ Add Project</button>
            </div>
            <script>
                function goBack() {
                    window.webkit.messageHandlers.app.postMessage({type: 'goBack'});
                }
                function saveAndClose() {
                    window.webkit.messageHandlers.app.postMessage({type: 'saveAndClose'});
                }
                function addProject() {
                    window.webkit.messageHandlers.app.postMessage({type: 'addProject'});
                }
                function deleteProject(idx) {
                    window.webkit.messageHandlers.app.postMessage({type: 'deleteProject', idx: idx});
                }
                function addService(projectIdx) {
                    window.webkit.messageHandlers.app.postMessage({type: 'addService', projectIdx: projectIdx});
                }
                function deleteService(projectIdx, serviceIdx) {
                    window.webkit.messageHandlers.app.postMessage({type: 'deleteService', projectIdx: projectIdx, serviceIdx: serviceIdx});
                }
                function updateProject(idx, value) {
                    window.webkit.messageHandlers.app.postMessage({type: 'updateProject', idx: idx, value: value});
                }
                function updateService(projectIdx, serviceIdx, field, value) {
                    window.webkit.messageHandlers.app.postMessage({type: 'updateService', projectIdx: projectIdx, serviceIdx: serviceIdx, field: field, value: value});
                }
                document.addEventListener('contextmenu', function(e) {
                    if (e.target.tagName === 'INPUT') {
                        e.target.select();
                    }
                });
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Service Management

    private func isServiceRunning(projectId: Int, serviceName: String) -> Bool {
        return runningServices.contains { s in
            (s["projectId"] as? Int) == projectId && (s["serviceName"] as? String) == serviceName
        }
    }

    private func startService(projectIdx: Int, serviceName: String, command: String, port: Int, workingDir: String) {
        let workDir = workingDir.isEmpty ? FileManager.default.currentDirectoryPath : workingDir

        DispatchQueue.global().async { [weak self] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = ["-c", command]
            task.currentDirectoryURL = URL(fileURLWithPath: workDir)
            task.environment = ProcessInfo.processInfo.environment

            do {
                try task.run()
                let pid = task.processIdentifier

                DispatchQueue.main.async {
                    self?.runningServices.append([
                        "projectId": projectIdx,
                        "serviceName": serviceName,
                        "pid": pid,
                        "port": port,
                        "command": command
                    ])

                    self?.loadMainHTML()
                }

                task.waitUntilExit()
            } catch {
                print("Failed to start service: \(error)")
            }
        }
    }

    private func stopService(projectIdx: Int, serviceName: String) {
        guard let service = runningServices.first(where: {
            ($0["projectId"] as? Int) == projectIdx && ($0["serviceName"] as? String) == serviceName
        }) else { return }

        let pid = service["pid"] as? pid_t ?? 0
        if pid > 0 {
            kill(pid, SIGTERM)
            usleep(300000)
            kill(pid, SIGKILL)
        }

        if let port = service["port"] as? Int, port > 0 {
            killPort(port)
        }

        runningServices.removeAll {
            ($0["projectId"] as? Int) == projectIdx && ($0["serviceName"] as? String) == serviceName
        }

        loadMainHTML()
    }

    private func killPort(_ port: Int) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-ti", ":\(port)"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let pids = String(data: data, encoding: .utf8) {
                for pidStr in pids.split(separator: "\n") {
                    if let pid = Int32(pidStr.trimmingCharacters(in: .whitespaces)) {
                        kill(pid, SIGKILL)
                    }
                }
            }
        } catch {
            print("Failed to kill port: \(error)")
        }
    }

    // MARK: - Actions

    @objc private func showPanel() {
        panel.setFrame(getStatusItemFrame(), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        trackClickOutside()
        loadMainHTML()
    }

    @objc private func showConfigPanel() {
        panel.orderOut(nil)
        configPanel.setFrame(getCenteredFrame(), display: true)
        configPanel.makeKeyAndOrderFront(nil)
        configPanel.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        loadConfigHTML()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.configPanel.makeFirstResponder(self.configWebView)
        }
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        setLoginItem(enabled: !isLoginItemEnabled)
    }

    @objc private func quit() {
        // Stop all running services
        for service in runningServices {
            if let pid = service["pid"] as? pid_t, pid > 0 {
                kill(pid, SIGTERM)
            }
        }
        NSApp.terminate(nil)
    }
}

// MARK: - WKScriptMessageHandler

extension AppDelegate: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "showSettings":
            showConfigPanel()

        case "toggleService":
            let projectIdx = body["projectIdx"] as? Int ?? 0
            let serviceName = body["serviceName"] as? String ?? ""
            let command = body["command"] as? String ?? ""
            let port = body["port"] as? Int ?? 0
            let workingDir = body["workingDir"] as? String ?? ""

            if isServiceRunning(projectId: projectIdx, serviceName: serviceName) {
                stopService(projectIdx: projectIdx, serviceName: serviceName)
            } else {
                startService(projectIdx: projectIdx, serviceName: serviceName, command: command, port: port, workingDir: workingDir)
            }

        case "openBrowser":
            if let url = body["url"] as? String {
                NSWorkspace.shared.open(URL(string: url)!)
            }

        case "refresh":
            loadMainHTML()

        case "startAllServices":
            if let projectIdx = body["projectIdx"] as? Int {
                let services = projects[projectIdx]["services"] as? [[String: Any]] ?? []
                for service in services {
                    let serviceName = service["name"] as? String ?? ""
                    let command = service["command"] as? String ?? ""
                    let port = service["port"] as? Int ?? 0
                    let workingDir = service["workingDir"] as? String ?? ""
                    if !isServiceRunning(projectId: projectIdx, serviceName: serviceName) && !command.isEmpty {
                        startService(projectIdx: projectIdx, serviceName: serviceName, command: command, port: port, workingDir: workingDir)
                    }
                }
            }

        case "stopAllServices":
            if let projectIdx = body["projectIdx"] as? Int {
                let services = projects[projectIdx]["services"] as? [[String: Any]] ?? []
                for service in services {
                    let serviceName = service["name"] as? String ?? ""
                    if isServiceRunning(projectId: projectIdx, serviceName: serviceName) {
                        stopService(projectIdx: projectIdx, serviceName: serviceName)
                    }
                }
            }

        case "goBack":
            configPanel.orderOut(nil)
            showPanel()

        case "saveAndClose":
            saveProjects()
            configPanel.orderOut(nil)
            showPanel()

        case "addProject":
            projects.append([
                "name": "New Project",
                "services": [[
                    "name": "Frontend",
                    "command": "npm run dev",
                    "port": 5173,
                    "workingDir": ""
                ]]
            ])
            saveProjects()
            loadConfigHTML()

        case "deleteProject":
            if let idx = body["idx"] as? Int {
                projects.remove(at: idx)
                saveProjects()
                loadConfigHTML()
            }

        case "addService":
            if let projectIdx = body["projectIdx"] as? Int {
                var services = projects[projectIdx]["services"] as? [[String: Any]] ?? []
                services.append([
                    "name": "Service",
                    "command": "",
                    "port": 0,
                    "workingDir": ""
                ])
                projects[projectIdx]["services"] = services
                saveProjects()
                loadConfigHTML()
            }

        case "deleteService":
            if let projectIdx = body["projectIdx"] as? Int,
               let serviceIdx = body["serviceIdx"] as? Int {
                var services = projects[projectIdx]["services"] as? [[String: Any]] ?? []
                services.remove(at: serviceIdx)
                projects[projectIdx]["services"] = services
                saveProjects()
                loadConfigHTML()
            }

        case "updateProject":
            if let idx = body["idx"] as? Int,
               let value = body["value"] as? String {
                projects[idx]["name"] = value
                saveProjects()
            }

        case "updateService":
            if let projectIdx = body["projectIdx"] as? Int,
               let serviceIdx = body["serviceIdx"] as? Int,
               let field = body["field"] as? String,
               let value = body["value"] as? Any {
                var services = projects[projectIdx]["services"] as? [[String: Any]] ?? []
                services[serviceIdx][field] = field == "port" ? (Int(value as? String ?? "") ?? 0) : value
                projects[projectIdx]["services"] = services
                saveProjects()
            }

        default:
            break
        }
    }
}

// MARK: - WKNavigationDelegate

extension AppDelegate: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
}
