import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var floatingWindowController: FloatingWindowController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        floatingWindowController = FloatingWindowController()
        floatingWindowController?.showWindow(nil)
        
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}