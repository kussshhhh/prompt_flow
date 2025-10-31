import Cocoa
import Carbon
import Combine

class MinimizeButton: NSView {
    weak var windowController: FloatingWindowController?
    private var isHovered = false
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }
    
    override func mouseDown(with event: NSEvent) {
        windowController?.toggleWindowVisibility()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let color = isHovered ? NSColor.controlAccentColor.withAlphaComponent(0.8) : NSColor.controlTextColor.withAlphaComponent(0.6)
        color.setFill()
        
        // Draw minimize line
        let lineRect = NSRect(x: bounds.midX - 6, y: bounds.midY - 1, width: 12, height: 2)
        let path = NSBezierPath(roundedRect: lineRect, xRadius: 1, yRadius: 1)
        path.fill()
    }
}

class SettingsButton: NSView {
    weak var windowController: FloatingWindowController?
    private var isHovered = false
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }
    
    override func mouseDown(with event: NSEvent) {
        showSettingsMenu()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    private func showSettingsMenu() {
        let menu = NSMenu()
        
        let sizeMenu = NSMenu()
        let smallItem = sizeMenu.addItem(withTitle: "Small (400x300)", action: #selector(resizeSmall), keyEquivalent: "")
        smallItem.target = self
        let mediumItem = sizeMenu.addItem(withTitle: "Medium (600x400)", action: #selector(resizeMedium), keyEquivalent: "")
        mediumItem.target = self
        let largeItem = sizeMenu.addItem(withTitle: "Large (800x500)", action: #selector(resizeLarge), keyEquivalent: "")
        largeItem.target = self
        
        let sizeMenuItem = NSMenuItem(title: "Window Size", action: nil, keyEquivalent: "")
        sizeMenuItem.submenu = sizeMenu
        menu.addItem(sizeMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Reset Position", action: #selector(resetPosition), keyEquivalent: "")
        
        menu.addItem(NSMenuItem.separator())
        let shortcutItem = menu.addItem(withTitle: "Change Shortcut...", action: #selector(changeShortcut), keyEquivalent: "")
        shortcutItem.target = self
        
        let currentShortcut = ShortcutManager.shared.getCurrentShortcutString()
        let shortcutInfoItem = menu.addItem(withTitle: "Current: \(currentShortcut)", action: nil, keyEquivalent: "")
        shortcutInfoItem.isEnabled = false
        
        for item in menu.items {
            item.target = self
        }
        
        let location = NSPoint(x: bounds.minX, y: bounds.maxY)
        menu.popUp(positioning: nil, at: location, in: self)
    }
    
    @objc private func resizeSmall() {
        resizeWindow(to: NSSize(width: 400, height: 300))
    }
    
    @objc private func resizeMedium() {
        resizeWindow(to: NSSize(width: 600, height: 400))
    }
    
    @objc private func resizeLarge() {
        resizeWindow(to: NSSize(width: 800, height: 500))
    }
    
    @objc private func resetPosition() {
        guard let window = windowController?.window else { return }
        var frame = window.frame
        frame.origin = NSPoint(x: 50, y: 100)
        window.setFrame(frame, display: true)
    }
    
    @objc private func changeShortcut() {
        windowController?.showShortcutChangeDialog()
    }
    
    private func resizeWindow(to size: NSSize) {
        guard let window = windowController?.window else { return }
        var frame = window.frame
        let oldSize = frame.size
        frame.size = size
        // Keep the top-left corner in the same position
        frame.origin.y += (oldSize.height - size.height)
        window.setFrame(frame, display: true, animate: true)
        windowController?.updateTextFieldFrame()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let color = isHovered ? NSColor.controlAccentColor.withAlphaComponent(0.8) : NSColor.controlTextColor.withAlphaComponent(0.6)
        color.setStroke()
        
        let lineWidth: CGFloat = 1.5
        
        // Draw gear/settings icon
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = 6
        let innerRadius: CGFloat = 3
        let teeth = 8
        
        let path = NSBezierPath()
        
        for i in 0..<teeth * 2 {
            let angle = CGFloat(i) * .pi / CGFloat(teeth)
            let currentRadius = i % 2 == 0 ? radius : innerRadius
            let x = center.x + currentRadius * cos(angle)
            let y = center.y + currentRadius * sin(angle)
            
            if i == 0 {
                path.move(to: NSPoint(x: x, y: y))
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }
        path.close()
        path.lineWidth = lineWidth
        path.stroke()
        
        // Draw center circle
        let centerCircle = NSBezierPath(ovalIn: NSRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4))
        centerCircle.lineWidth = lineWidth
        centerCircle.stroke()
    }
}

class ResizeHandle: NSView {
    weak var windowController: FloatingWindowController?
    private var isResizing = false
    private var startLocation = NSPoint.zero
    private var startSize = NSSize.zero
    
    override func mouseDown(with event: NSEvent) {
        isResizing = true
        startLocation = event.locationInWindow
        startSize = window?.frame.size ?? NSSize.zero
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isResizing, let window = self.window else { return }
        
        let currentLocation = event.locationInWindow
        let deltaX = currentLocation.x - startLocation.x
        let deltaY = currentLocation.y - startLocation.y
        
        let newWidth = max(400, startSize.width + deltaX)
        let newHeight = max(300, startSize.height - deltaY)
        
        var frame = window.frame
        frame.size.width = newWidth
        frame.origin.y = frame.origin.y + (frame.size.height - newHeight)
        frame.size.height = newHeight
        
        window.setFrame(frame, display: true)
        
        if let controller = windowController {
            controller.updateTextFieldFrame()
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isResizing = false
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.gray.withAlphaComponent(0.3).setFill()
        let path = NSBezierPath()
        for i in 0..<3 {
            for j in 0..<3 {
                if i + j >= 2 {
                    let x = CGFloat(i * 4 + 8)
                    let y = CGFloat(j * 4 + 8)
                    path.appendOval(in: NSRect(x: x, y: y, width: 2, height: 2))
                }
            }
        }
        path.fill()
    }
}

class FloatingWindowController: NSWindowController {
    
    // MARK: - PromptFlow Components
    private var mainInputTextView: AutocompleteTextView!
    private var executeButton: NSButton!
    private var showPanelButton: NSButton!
    private var managementWindow: NSWindow?
    
    // MARK: - State Management
    private var isHidden = false
    private var savedPosition: NSPoint = NSPoint(x: 50, y: 100)
    private var isPanelVisible = false
    private var cancellables = Set<AnyCancellable>()
    private let promptFlowManager = PromptFlowManager.shared
    
    // MARK: - Layout Constants
    private let mainWindowWidth: CGFloat = 600
    private let mainWindowHeight: CGFloat = 400
    
    override init(window: NSWindow?) {
        super.init(window: window)
        setupFloatingWindow()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupFloatingWindow()
    }
    
    convenience init() {
        self.init(window: nil)
        ShortcutManager.shared.windowController = self
        ShortcutManager.shared.registerGlobalShortcut()
    }
    
    private func setupFloatingWindow() {
        let windowFrame = NSRect(x: 50, y: 100, width: mainWindowWidth, height: mainWindowHeight)
        
        let floatingWindow = NSWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        floatingWindow.level = NSWindow.Level.floating
        floatingWindow.isOpaque = false
        floatingWindow.backgroundColor = NSColor.clear
        floatingWindow.hasShadow = false
        floatingWindow.ignoresMouseEvents = false
        floatingWindow.isMovableByWindowBackground = true
        floatingWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        setupContentView(for: floatingWindow)
        setupBindings()
        
        self.window = floatingWindow
    }
    
    private func setupContentView(for window: NSWindow) {
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 12
        
        // Background material with translucency
        let material = NSVisualEffectView()
        material.frame = contentView.bounds
        material.autoresizingMask = [.width, .height]
        material.material = .hudWindow
        material.blendingMode = .behindWindow
        material.state = .active
        material.alphaValue = 0.95 // Default translucency
        material.wantsLayer = true
        material.layer?.cornerRadius = 12
        
        contentView.addSubview(material)
        
        // Window control buttons
        let minimizeButton = MinimizeButton()
        minimizeButton.translatesAutoresizingMaskIntoConstraints = false
        minimizeButton.windowController = self
        
        let settingsButton = SettingsButton()
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.windowController = self
        
        let resizeHandle = ResizeHandle()
        resizeHandle.translatesAutoresizingMaskIntoConstraints = false
        resizeHandle.windowController = self
        
        // Header with title and translucency slider
        let headerView = createHeaderView()
        
        // Main input area
        let inputScrollView = NSScrollView()
        inputScrollView.translatesAutoresizingMaskIntoConstraints = false
        inputScrollView.hasVerticalScroller = true
        inputScrollView.hasHorizontalScroller = false
        inputScrollView.autohidesScrollers = true
        inputScrollView.borderType = .noBorder
        
        mainInputTextView = AutocompleteTextView()
        mainInputTextView.autocompleteDelegate = self
        mainInputTextView.string = "Write your prompt here...\\nCall other prompts using promptName()\\n\\nExample: deployInfra() then createDatabase()"
        mainInputTextView.textColor = NSColor.labelColor
        mainInputTextView.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3)
        mainInputTextView.isRichText = false
        
        inputScrollView.documentView = mainInputTextView
        
        // Button area
        let buttonStackView = NSStackView()
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        buttonStackView.orientation = .horizontal
        buttonStackView.spacing = 8
        buttonStackView.distribution = .gravityAreas
        
        showPanelButton = NSButton(title: "📚 Manage", target: self, action: #selector(togglePanel))
        showPanelButton.translatesAutoresizingMaskIntoConstraints = false
        
        executeButton = NSButton(title: "▶️ Execute", target: self, action: #selector(executePrompt))
        executeButton.translatesAutoresizingMaskIntoConstraints = false
        executeButton.keyEquivalent = "\\r"
        executeButton.keyEquivalentModifierMask = [.command]
        
        buttonStackView.addArrangedSubview(showPanelButton)
        buttonStackView.addArrangedSubview(executeButton)
        
        // Add all subviews
        contentView.addSubview(headerView)
        contentView.addSubview(inputScrollView)
        contentView.addSubview(buttonStackView)
        contentView.addSubview(minimizeButton)
        contentView.addSubview(settingsButton)
        contentView.addSubview(resizeHandle)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Header
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -50),
            headerView.heightAnchor.constraint(equalToConstant: 60),
            
            // Input area
            inputScrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            inputScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            inputScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            inputScrollView.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -8),
            
            // Button area
            buttonStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            buttonStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            buttonStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            buttonStackView.heightAnchor.constraint(equalToConstant: 32),
            
            // Window controls
            minimizeButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -4),
            minimizeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            minimizeButton.widthAnchor.constraint(equalToConstant: 20),
            minimizeButton.heightAnchor.constraint(equalToConstant: 20),
            
            settingsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            settingsButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            settingsButton.widthAnchor.constraint(equalToConstant: 20),
            settingsButton.heightAnchor.constraint(equalToConstant: 20),
            
            resizeHandle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            resizeHandle.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            resizeHandle.widthAnchor.constraint(equalToConstant: 20),
            resizeHandle.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        window.contentView = contentView
    }
    
    private func createHeaderView() -> NSView {
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title
        let titleLabel = NSTextField(labelWithString: "PromptFlow")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Write prompts, call them like functions, chain them into workflows")
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Translucency slider
        let opacitySlider = NSSlider()
        opacitySlider.translatesAutoresizingMaskIntoConstraints = false
        opacitySlider.minValue = 0.3
        opacitySlider.maxValue = 1.0
        opacitySlider.doubleValue = 0.95
        opacitySlider.target = self
        opacitySlider.action = #selector(opacitySliderChanged(_:))
        
        let opacityIcon = NSTextField(labelWithString: "👁")
        opacityIcon.font = NSFont.systemFont(ofSize: 12)
        opacityIcon.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        headerView.addSubview(opacityIcon)
        headerView.addSubview(opacitySlider)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor),
            
            opacityIcon.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            opacityIcon.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            opacityIcon.widthAnchor.constraint(equalToConstant: 20),
            
            opacitySlider.centerYAnchor.constraint(equalTo: opacityIcon.centerYAnchor),
            opacitySlider.leadingAnchor.constraint(equalTo: opacityIcon.trailingAnchor, constant: 4),
            opacitySlider.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            opacitySlider.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        return headerView
    }
    
    func updateText(_ text: String) {
        mainInputTextView?.string = text
    }
    
    func updateTextFieldFrame() {
        // Views now use constraints, so just force a layout update
        window?.contentView?.needsLayout = true
        window?.contentView?.layoutSubtreeIfNeeded()
    }
    
    func toggleWindowVisibility() {
        guard let window = self.window else { return }
        
        if isHidden {
            // Show window
            window.setFrameOrigin(savedPosition)
            window.alphaValue = 0.0
            window.makeKeyAndOrderFront(nil)
            window.animator().alphaValue = 1.0
            isHidden = false
        } else {
            // Hide window
            savedPosition = window.frame.origin
            window.animator().alphaValue = 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                window.orderOut(nil)
                self.isHidden = true
            }
        }
    }
    
    func showShortcutChangeDialog() {
        let alert = NSAlert()
        alert.messageText = "Change Global Shortcut"
        alert.informativeText = "Choose a new keyboard shortcut to show/hide the window:"
        
        alert.addButton(withTitle: "⌘⌥Space (Default)")
        alert.addButton(withTitle: "⌘⇧P")
        alert.addButton(withTitle: "⌘⌥P")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            ShortcutManager.shared.setShortcut("cmd+option+space")
        case .alertSecondButtonReturn:
            ShortcutManager.shared.setShortcut("cmd+shift+p")
        case .alertThirdButtonReturn:
            ShortcutManager.shared.setShortcut("cmd+option+p")
        default:
            break
        }
    }
    
    // MARK: - Actions
    
    @objc private func opacitySliderChanged(_ sender: NSSlider) {
        if let material = window?.contentView?.subviews.first(where: { $0 is NSVisualEffectView }) as? NSVisualEffectView {
            material.alphaValue = sender.doubleValue
        }
    }
    
    @objc private func togglePanel() {
        isPanelVisible.toggle()
        showPanelButton.title = isPanelVisible ? "❌ Hide" : "📚 Manage"
        
        if isPanelVisible {
            showManagementPanel()
        } else {
            hideManagementPanel()
        }
    }
    
    @objc private func executePrompt() {
        let content = mainInputTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        promptFlowManager.executeContent(content)
        
        // Clear input if execution started
        if promptFlowManager.isExecuting {
            mainInputTextView.string = ""
        }
    }
    
    private func showManagementPanel() {
        // Create management window if it doesn't exist
        if managementWindow == nil {
            createManagementWindow()
        }
        
        managementWindow?.makeKeyAndOrderFront(nil)
    }
    
    private func hideManagementPanel() {
        managementWindow?.orderOut(nil)
    }
    
    private func createManagementWindow() {
        let windowFrame = NSRect(x: 200, y: 200, width: 500, height: 600)
        
        managementWindow = NSWindow(
            contentRect: windowFrame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        managementWindow?.title = "PromptFlow Manager"
        managementWindow?.level = NSWindow.Level.floating
        
        // Simple management interface
        let contentView = NSView()
        let label = NSTextField(labelWithString: "Prompt Management\\n\\nThis will contain:\\n• Prompt list\\n• Create/Edit prompts\\n• Execution logs\\n• Search functionality")
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.font = NSFont.systemFont(ofSize: 14)
        label.alignment = .center
        
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        
        managementWindow?.contentView = contentView
    }
    
    private func setupBindings() {
        // Set up Combine bindings for reactive updates
        promptFlowManager.$isExecuting
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isExecuting in
                self?.executeButton.isEnabled = !isExecuting
                self?.executeButton.title = isExecuting ? "⏳ Executing..." : "▶️ Execute"
            }
            .store(in: &cancellables)
        
        // Show execution dialog when execution starts
        promptFlowManager.$currentExecutionSteps
            .combineLatest(promptFlowManager.$currentStepIndex)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] steps, stepIndex in
                if !steps.isEmpty && stepIndex < steps.count {
                    self?.showExecutionDialog()
                }
            }
            .store(in: &cancellables)
    }
    
    private func showExecutionDialog() {
        guard promptFlowManager.isExecuting,
              promptFlowManager.currentStepIndex < promptFlowManager.currentExecutionSteps.count else { return }
        
        let currentStep = promptFlowManager.currentExecutionSteps[promptFlowManager.currentStepIndex]
        
        let alert = NSAlert()
        alert.messageText = "Step \\(promptFlowManager.currentStepIndex + 1) of \\(promptFlowManager.currentExecutionSteps.count)"
        alert.informativeText = "Context: \\(currentStep.context)\\n\\nProvide values for variables: \\(currentStep.variables.joined(separator: ", "))"
        
        // Add input fields for each variable
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8
        
        var textFields: [String: NSTextField] = [:]
        
        for variable in currentStep.variables {
            let label = NSTextField(labelWithString: "\\(variable):")
            let textField = NSTextField()
            textField.placeholderString = "Enter value for \\(variable)"
            
            stackView.addArrangedSubview(label)
            stackView.addArrangedSubview(textField)
            textFields[variable] = textField
        }
        
        alert.accessoryView = stackView
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Collect values and submit
            var values: [String: String] = [:]
            for (variable, textField) in textFields {
                values[variable] = textField.stringValue
            }
            
            promptFlowManager.executionValues = values
            
            if promptFlowManager.submitCurrentStepValues() {
                // If there are more steps, show the next dialog
                if promptFlowManager.isExecuting {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.showExecutionDialog()
                    }
                }
            } else {
                // Show error for missing values
                let errorAlert = NSAlert()
                errorAlert.messageText = "Missing Values"
                errorAlert.informativeText = "Please provide values for all required variables."
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
                
                // Show the dialog again
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.showExecutionDialog()
                }
            }
        } else {
            promptFlowManager.cancelExecution()
        }
    }
}

// MARK: - AutocompleteTextViewDelegate

extension FloatingWindowController: AutocompleteTextViewDelegate {
    
    func textViewDidChangeCursor(_ textView: AutocompleteTextView, position: Int) {
        // Handle cursor position changes if needed
    }
    
    func textViewDidChangeText(_ textView: AutocompleteTextView, text: String) {
        // Handle text changes if needed
    }
    
    func textViewShouldShowSuggestions(_ textView: AutocompleteTextView, for query: String, at position: Int) -> [AutocompleteSuggestion] {
        return promptFlowManager.getAutocompleteSuggestions(for: query)
    }
    
    func textViewDidSelectSuggestion(_ textView: AutocompleteTextView, suggestion: AutocompleteSuggestion) {
        textView.insertSuggestion(suggestion)
    }
}