import Cocoa
import Carbon

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
        let smallItem = sizeMenu.addItem(withTitle: "Small (250x80)", action: #selector(resizeSmall), keyEquivalent: "")
        smallItem.target = self
        let mediumItem = sizeMenu.addItem(withTitle: "Medium (350x120)", action: #selector(resizeMedium), keyEquivalent: "")
        mediumItem.target = self
        let largeItem = sizeMenu.addItem(withTitle: "Large (500x150)", action: #selector(resizeLarge), keyEquivalent: "")
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
        resizeWindow(to: NSSize(width: 250, height: 80))
    }
    
    @objc private func resizeMedium() {
        resizeWindow(to: NSSize(width: 350, height: 120))
    }
    
    @objc private func resizeLarge() {
        resizeWindow(to: NSSize(width: 500, height: 150))
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
        
        let newWidth = max(200, startSize.width + deltaX)
        let newHeight = max(80, startSize.height - deltaY)
        
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

class ShortcutManager {
    static let shared = ShortcutManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID: EventHotKeyID = EventHotKeyID(signature: 0x50464C54, id: 1) // "PFLT" as hex
    
    weak var windowController: FloatingWindowController?
    
    private init() {}
    
    func registerGlobalShortcut() {
        unregisterGlobalShortcut() // Clean up any existing registration
        
        let shortcut = getCurrentShortcut()
        print("Registering global shortcut: \(shortcut.displayString)")
        
        // Use NSEvent-based global monitoring instead of Carbon
        let eventMask: NSEvent.EventTypeMask = [.keyDown]
        
        NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handleGlobalKeyEvent(event)
        }
        
        print("Global shortcut monitoring started")
    }
    
    private func handleGlobalKeyEvent(_ event: NSEvent) {
        let shortcut = getCurrentShortcut()
        
        // Check if the event matches our shortcut
        let expectedModifiers = NSEvent.ModifierFlags(rawValue: UInt(shortcut.modifiers))
        let actualModifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
        
        if Int(event.keyCode) == shortcut.keyCode && actualModifiers == expectedModifiers {
            print("Global shortcut triggered!")
            DispatchQueue.main.async {
                self.windowController?.toggleWindowVisibility()
            }
        }
    }
    
    func unregisterGlobalShortcut() {
        // NSEvent monitoring will be cleaned up when the app terminates
        print("Global shortcut monitoring stopped")
    }
    
    private struct ShortcutInfo {
        let keyCode: Int
        let modifiers: Int
        let displayString: String
    }
    
    private func getCurrentShortcut() -> ShortcutInfo {
        let savedShortcut = UserDefaults.standard.string(forKey: "GlobalShortcut") ?? "cmd+option+space"
        
        switch savedShortcut.lowercased() {
        case "cmd+option+space":
            return ShortcutInfo(keyCode: 49, modifiers: Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.option.rawValue), displayString: "⌘⌥Space")
        case "cmd+shift+p":
            return ShortcutInfo(keyCode: 35, modifiers: Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue), displayString: "⌘⇧P")
        case "cmd+option+p":
            return ShortcutInfo(keyCode: 35, modifiers: Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.option.rawValue), displayString: "⌘⌥P")
        default:
            return ShortcutInfo(keyCode: 49, modifiers: Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.option.rawValue), displayString: "⌘⌥Space")
        }
    }
    
    func getCurrentShortcutString() -> String {
        return getCurrentShortcut().displayString
    }
    
    func setShortcut(_ shortcutKey: String) {
        UserDefaults.standard.set(shortcutKey, forKey: "GlobalShortcut")
        registerGlobalShortcut()
    }
    
    private func fourCharCode(_ string: String) -> FourCharCode {
        let chars = Array(string.utf8)
        return FourCharCode(chars[0]) << 24 | FourCharCode(chars[1]) << 16 | FourCharCode(chars[2]) << 8 | FourCharCode(chars[3])
    }
}

class FloatingWindowController: NSWindowController {
    
    private var textField: NSTextField!
    private var isHidden = false
    private var savedPosition: NSPoint = NSPoint(x: 50, y: 100)
    
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
        let windowFrame = NSRect(x: 50, y: 100, width: 300, height: 100)
        
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
        
        self.window = floatingWindow
    }
    
    private func setupContentView(for window: NSWindow) {
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 8
        
        let material = NSVisualEffectView()
        material.frame = contentView.bounds
        material.autoresizingMask = [.width, .height]
        material.material = .hudWindow
        material.blendingMode = .behindWindow
        material.state = .active
        material.alphaValue = 0.6
        material.wantsLayer = true
        material.layer?.cornerRadius = 8
        
        contentView.addSubview(material)
        
        let minimizeButton = MinimizeButton()
        minimizeButton.translatesAutoresizingMaskIntoConstraints = false
        minimizeButton.windowController = self
        
        let settingsButton = SettingsButton()
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.windowController = self
        
        let resizeHandle = ResizeHandle()
        resizeHandle.translatesAutoresizingMaskIntoConstraints = false
        resizeHandle.windowController = self
        
        textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.stringValue = "Prompt Autocompletion\nFloating Window"
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.textColor = NSColor.controlTextColor
        textField.font = NSFont.systemFont(ofSize: 14)
        textField.alignment = .center
        textField.maximumNumberOfLines = 0
        
        contentView.addSubview(textField)
        contentView.addSubview(minimizeButton)
        contentView.addSubview(settingsButton)
        contentView.addSubview(resizeHandle)
        
        NSLayoutConstraint.activate([
            // Text field constraints
            textField.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textField.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -30),
            textField.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 30),
            textField.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -30),
            
            // Minimize button constraints (left of settings)
            minimizeButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -4),
            minimizeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            minimizeButton.widthAnchor.constraint(equalToConstant: 20),
            minimizeButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Settings button constraints
            settingsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            settingsButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            settingsButton.widthAnchor.constraint(equalToConstant: 20),
            settingsButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Resize handle constraints
            resizeHandle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            resizeHandle.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            resizeHandle.widthAnchor.constraint(equalToConstant: 20),
            resizeHandle.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        window.contentView = contentView
    }
    
    func updateText(_ text: String) {
        textField.stringValue = text
    }
    
    func updateTextFieldFrame() {
        // Text field now uses constraints, so just force a layout update
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
}