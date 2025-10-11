# PromptFloater - Low Level Design (LLD)

## Project Structure

```
PromptFloater.xcodeproj/
├── PromptFloater/
│   ├── AppDelegate.swift           # Main application entry point
│   ├── FloatingWindowController.swift # Core window management
│   ├── Info.plist                 # App configuration
│   ├── PromptFloater.entitlements  # Security permissions
│   ├── Assets.xcassets/            # App icons and resources
│   └── Base.lproj/
│       └── Main.storyboard         # Interface Builder file
└── build/                          # Compiled output
```

## Core Classes and Components

### 1. AppDelegate.swift
```swift
@main class AppDelegate: NSObject, NSApplicationDelegate
```

**Key Properties:**
- `floatingWindowController: FloatingWindowController?` - Main window controller instance

**Key Methods:**
- `applicationDidFinishLaunching(_:)` - Creates and shows floating window, sets activation policy
- `applicationSupportsSecureRestorableState(_:)` - Returns true for state restoration

**Configuration:**
- `NSApp.setActivationPolicy(.accessory)` - Prevents dock/menu bar appearance

### 2. FloatingWindowController.swift

#### Main Window Controller
```swift
class FloatingWindowController: NSWindowController
```

**Key Properties:**
- `textField: NSTextField!` - Main text display area

**Key Methods:**
- `setupFloatingWindow()` - Configures window properties and behavior
- `setupContentView(for:)` - Creates and configures UI elements
- `updateText(_:)` - Updates displayed text content
- `updateTextFieldFrame()` - Refreshes layout after resize

**Window Configuration:**
```swift
let floatingWindow = NSWindow(
    contentRect: NSRect(x: 50, y: 100, width: 300, height: 100),
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
```

#### Settings Button Component
```swift
class SettingsButton: NSView
```

**Key Properties:**
- `windowController: FloatingWindowController?` - Weak reference to parent
- `isHovered: Bool` - Tracks hover state for visual feedback

**Key Methods:**
- `mouseDown(with:)` - Shows settings menu on click
- `showSettingsMenu()` - Creates and displays context menu
- `resizeSmall/Medium/Large()` - Preset size handlers
- `resetPosition()` - Returns window to default position
- `draw(_:)` - Custom gear icon rendering

**Menu Structure:**
```
Settings Menu
├── Window Size >
│   ├── Small (250x80)
│   ├── Medium (350x120)
│   └── Large (500x150)
├── ───────────────
└── Reset Position
```

**Visual Rendering:**
- Custom gear icon with 8 teeth
- Hover state with accent color highlighting
- Proper tracking area management

#### Resize Handle Component
```swift
class ResizeHandle: NSView
```

**Key Properties:**
- `windowController: FloatingWindowController?` - Weak reference to parent
- `isResizing: Bool` - Tracks resize state
- `startLocation: NSPoint` - Initial mouse position
- `startSize: NSSize` - Initial window size

**Key Methods:**
- `mouseDown/Dragged/Up(with:)` - Handle resize gesture
- `draw(_:)` - Renders grip dots pattern

**Resize Logic:**
```swift
let deltaX = currentLocation.x - startLocation.x
let deltaY = currentLocation.y - startLocation.y
let newWidth = max(200, startSize.width + deltaX)
let newHeight = max(80, startSize.height - deltaY)
```

## UI Layout System

### Auto Layout Constraints
```swift
NSLayoutConstraint.activate([
    // Text field - centered with margins
    textField.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
    textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
    textField.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
    textField.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -30),
    
    // Settings button - top-right corner
    settingsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
    settingsButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
    settingsButton.widthAnchor.constraint(equalToConstant: 20),
    settingsButton.heightAnchor.constraint(equalToConstant: 20),
    
    // Resize handle - bottom-right corner
    resizeHandle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    resizeHandle.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
    resizeHandle.widthAnchor.constraint(equalToConstant: 20),
    resizeHandle.heightAnchor.constraint(equalToConstant: 20)
])
```

### Visual Effects Configuration
```swift
let material = NSVisualEffectView()
material.frame = contentView.bounds
material.autoresizingMask = [.width, .height]
material.material = .hudWindow
material.blendingMode = .behindWindow
material.state = .active
material.alphaValue = 0.6
material.wantsLayer = true
material.layer?.cornerRadius = 8
```

## Build Configuration

### Info.plist Key Settings
```xml
<key>LSUIElement</key>
<true/>
<key>NSMainStoryboardFile</key>
<string>Main</string>
<key>NSPrincipalClass</key>
<string>NSApplication</string>
```

### Entitlements
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```

### Build Settings
- **Deployment Target**: macOS 14.0
- **Architecture**: ARM64 (Apple Silicon primary)
- **Swift Version**: 5.0
- **Code Signing**: Automatic (Developer)

## State Management

### Window State
- **Position**: Stored in window frame, persistent across app sessions
- **Size**: Three predefined presets + manual sizing
- **Visibility**: Always visible when app is running

### Text Content
- **Current Text**: Stored in `textField.stringValue`
- **Update Method**: `updateText(_: String)` for external integration

### User Preferences (Future)
- **Default Size**: User's preferred startup size
- **Default Position**: User's preferred startup position
- **Transparency Level**: Configurable opacity
- **Theme**: Light/dark/auto adaptation

## Performance Optimizations

### Memory Management
- Weak references between components prevent retain cycles
- Minimal object allocation during runtime
- Efficient constraint-based layout system

### Rendering Efficiency
- Custom drawing only for simple icons (gear, grip dots)
- Native NSVisualEffectView for background effects
- Minimal redraws on resize operations

### Event Handling
- Proper tracking area management for hover states
- Efficient mouse event delegation
- Background processing for non-UI operations

## Error Handling

### Graceful Failures
- Window creation failure fallbacks
- Menu system error recovery
- Constraint conflict resolution

### Debug Support
- Build-time logging for development
- Console output for troubleshooting
- Xcode project compatibility for debugging

## Integration APIs

### Public Methods
```swift
// Text content management
func updateText(_ text: String)

// Window control
func updateTextFieldFrame()

// Size presets
func resizeWindow(to size: NSSize)
```

### Future Extension Points
- Notification observers for external text updates
- Custom theme/color configuration
- Multi-window support architecture
- Plugin system for custom behaviors

## Testing Strategy

### Manual Testing Checklist
1. Window appears on launch
2. Stays above other applications
3. Drag functionality works smoothly
4. Resize handle operates correctly
5. Settings menu displays and functions
6. Preset sizes work as expected
7. Position reset functions properly
8. No focus stealing occurs
9. Transparency adapts to background
10. Performance remains smooth during operations