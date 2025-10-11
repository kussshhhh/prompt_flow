# PromptFloater - High Level Design (HLD)

## Overview
PromptFloater is a macOS native application that provides a floating, transparent window designed for prompt autocompletion display. The window stays above all other applications while remaining non-intrusive and fully interactive for positioning and sizing.

## System Architecture

### Core Components
1. **Main Application (AppDelegate)**
   - Entry point and lifecycle management
   - Configured as LSUIElement (background app, no dock/menu bar presence)
   - Manages FloatingWindowController instance

2. **Floating Window System (FloatingWindowController)**
   - Creates and manages borderless floating window
   - Handles window positioning, sizing, and display properties
   - Implements transparent adaptive background using NSVisualEffectView

3. **User Interface Controls**
   - **Settings Button**: Top-right gear icon for configuration access
   - **Resize Handle**: Bottom-right corner for manual window resizing
   - **Text Display**: Centered text field for prompt content

4. **Menu System**
   - Context menu with predefined window sizes (Small, Medium, Large)
   - Position reset functionality
   - Hierarchical menu structure with size presets

## Key Features

### Window Behavior
- **Floating**: Always stays above other applications (NSWindow.Level.floating)
- **Non-Focus**: Never steals focus from active applications
- **Transparent**: Adaptive background that responds to underlying content
- **Draggable**: Click and drag anywhere to reposition
- **Resizable**: Manual resize via corner handle or preset sizes

### Visual Design
- **Adaptive Transparency**: Uses NSVisualEffectView with .hudWindow material
- **Rounded Corners**: 8px radius for modern appearance
- **Blur Effect**: Background blur for readability while maintaining transparency
- **Responsive Layout**: Auto Layout constraints for consistent appearance across sizes

### Interaction Model
- **Settings Access**: Click gear icon (top-right) for configuration menu
- **Quick Resize**: Select from Small (250x80), Medium (350x120), or Large (500x150)
- **Manual Resize**: Drag bottom-right corner handle
- **Position Reset**: Return to default position (50, 100)
- **Drag to Move**: Click anywhere on window background to reposition

## Technical Requirements

### Platform
- **Target**: macOS 14.0+
- **Architecture**: Apple Silicon (ARM64) primary
- **Framework**: AppKit (Cocoa)
- **Language**: Swift 5.0+

### Performance Characteristics
- **Startup**: Instant launch as background utility
- **Memory**: Minimal footprint (~5-10MB)
- **CPU**: Negligible usage when idle
- **Responsiveness**: Immediate response to user interactions

### Security & Permissions
- **Sandbox**: App Sandbox enabled
- **Entitlements**: Minimal required permissions
- **Code Signing**: Developer signed for distribution

## Integration Points

### Future Extensions
- **API Integration**: Text update methods for external prompt systems
- **Customization**: Theme and appearance preferences
- **Automation**: AppleScript/Shortcuts integration
- **Multi-Display**: Enhanced support for multiple monitors

### External Dependencies
- **System Frameworks**: AppKit, Foundation
- **Build System**: Xcode project with standard macOS app structure
- **Asset Management**: Xcassets for icons and resources

## Deployment Architecture
- **Distribution**: Standalone .app bundle
- **Installation**: Drag-and-drop to Applications
- **Updates**: Manual replacement or future auto-update system
- **Configuration**: Persistent settings in user defaults (future)

## Success Criteria
1. Window remains consistently above other applications
2. Transparent background adapts to underlying content
3. Smooth resize and drag operations without performance issues
4. Zero focus stealing from active applications
5. Minimal resource consumption
6. Intuitive user interaction model