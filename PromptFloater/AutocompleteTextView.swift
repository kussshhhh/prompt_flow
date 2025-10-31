import Cocoa

protocol AutocompleteTextViewDelegate: AnyObject {
    func textViewDidChangeCursor(_ textView: AutocompleteTextView, position: Int)
    func textViewDidChangeText(_ textView: AutocompleteTextView, text: String)
    func textViewShouldShowSuggestions(_ textView: AutocompleteTextView, for query: String, at position: Int) -> [AutocompleteSuggestion]
    func textViewDidSelectSuggestion(_ textView: AutocompleteTextView, suggestion: AutocompleteSuggestion)
}

class AutocompleteTextView: NSTextView {
    
    weak var autocompleteDelegate: AutocompleteTextViewDelegate?
    
    private var suggestions: [AutocompleteSuggestion] = []
    private var selectedSuggestionIndex: Int = 0
    private var suggestionWindow: NSWindow?
    private var suggestionTableView: NSTableView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTextView()
    }
    
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupTextView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }
    
    private func setupTextView() {
        font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isRichText = false
        allowsUndo = true
    }
    
    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        
        let currentText = string
        let cursorPosition = selectedRange().location
        
        autocompleteDelegate?.textViewDidChangeText(self, text: currentText)
        autocompleteDelegate?.textViewDidChangeCursor(self, position: cursorPosition)
        
        updateAutocomplete()
    }
    
    override func textViewDidChangeSelection(_ notification: Notification) {
        super.textViewDidChangeSelection(notification)
        
        let cursorPosition = selectedRange().location
        autocompleteDelegate?.textViewDidChangeCursor(self, position: cursorPosition)
        
        updateAutocomplete()
    }
    
    private func updateAutocomplete() {
        let text = string
        let cursorPosition = selectedRange().location
        
        // Get the word before cursor
        let textBeforeCursor = String(text.prefix(cursorPosition))
        let lastWord = textBeforeCursor.components(separatedBy: CharacterSet.whitespacesAndNewlines).last ?? ""
        
        if lastWord.count > 0 {
            if let suggestions = autocompleteDelegate?.textViewShouldShowSuggestions(self, for: lastWord, at: cursorPosition) {
                showSuggestions(suggestions)
            } else {
                hideSuggestions()
            }
        } else {
            hideSuggestions()
        }
    }
    
    private func showSuggestions(_ newSuggestions: [AutocompleteSuggestion]) {
        suggestions = newSuggestions
        selectedSuggestionIndex = 0
        
        if suggestions.isEmpty {
            hideSuggestions()
            return
        }
        
        if suggestionWindow == nil {
            createSuggestionWindow()
        }
        
        suggestionTableView?.reloadData()
        
        // Position the suggestion window
        positionSuggestionWindow()
        
        suggestionWindow?.orderFront(nil)
    }
    
    private func hideSuggestions() {
        suggestionWindow?.orderOut(nil)
        suggestions = []
    }
    
    private func createSuggestionWindow() {
        let windowFrame = NSRect(x: 0, y: 0, width: 300, height: 200)
        
        suggestionWindow = NSWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        suggestionWindow?.level = NSWindow.Level.popUpMenu
        suggestionWindow?.isOpaque = false
        suggestionWindow?.backgroundColor = NSColor.clear
        suggestionWindow?.hasShadow = true
        
        // Create visual effect view for backdrop
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 8
        
        // Create table view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        suggestionTableView = NSTableView()
        suggestionTableView?.headerView = nil
        suggestionTableView?.selectionHighlightStyle = .regular
        suggestionTableView?.backgroundColor = NSColor.clear
        suggestionTableView?.delegate = self
        suggestionTableView?.dataSource = self
        suggestionTableView?.target = self
        suggestionTableView?.doubleAction = #selector(suggestionDoubleClicked)
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("suggestion"))
        column.width = 280
        suggestionTableView?.addTableColumn(column)
        
        scrollView.documentView = suggestionTableView
        
        visualEffect.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -4),
            scrollView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor, constant: -4)
        ])
        
        suggestionWindow?.contentView = visualEffect
    }
    
    private func positionSuggestionWindow() {
        guard let window = self.window,
              let suggestionWindow = suggestionWindow else { return }
        
        // Get cursor position in text view
        let cursorRect = firstRect(forCharacterRange: selectedRange(), actualRange: nil)
        
        // Position suggestion window below cursor
        var windowFrame = suggestionWindow.frame
        windowFrame.origin.x = cursorRect.origin.x
        windowFrame.origin.y = cursorRect.origin.y - windowFrame.height - 5
        
        suggestionWindow.setFrame(windowFrame, display: true)
    }
    
    @objc private func suggestionDoubleClicked() {
        applySuggestion()
    }
    
    private func applySuggestion() {
        guard selectedSuggestionIndex < suggestions.count else { return }
        
        let suggestion = suggestions[selectedSuggestionIndex]
        autocompleteDelegate?.textViewDidSelectSuggestion(self, suggestion: suggestion)
        hideSuggestions()
    }
    
    override func keyDown(with event: NSEvent) {
        if !suggestions.isEmpty {
            switch event.keyCode {
            case 125: // Down arrow
                selectedSuggestionIndex = min(selectedSuggestionIndex + 1, suggestions.count - 1)
                suggestionTableView?.selectRowIndexes(IndexSet(integer: selectedSuggestionIndex), byExtendingSelection: false)
                suggestionTableView?.scrollRowToVisible(selectedSuggestionIndex)
                return
                
            case 126: // Up arrow
                selectedSuggestionIndex = max(selectedSuggestionIndex - 1, 0)
                suggestionTableView?.selectRowIndexes(IndexSet(integer: selectedSuggestionIndex), byExtendingSelection: false)
                suggestionTableView?.scrollRowToVisible(selectedSuggestionIndex)
                return
                
            case 48, 36: // Tab or Enter
                applySuggestion()
                return
                
            case 53: // Escape
                hideSuggestions()
                return
                
            default:
                break
            }
        }
        
        super.keyDown(with: event)
    }
    
    func insertSuggestion(_ suggestion: AutocompleteSuggestion) {
        let text = string
        let cursorPosition = selectedRange().location
        let textBeforeCursor = String(text.prefix(cursorPosition))
        let textAfterCursor = String(text.suffix(text.count - cursorPosition))
        
        // Find the start of the current word
        let lastWordStart = textBeforeCursor.lastIndex { character in
            CharacterSet.whitespacesAndNewlines.contains(character.unicodeScalars.first!)
        }
        
        let wordStartIndex = lastWordStart.map { textBeforeCursor.index(after: $0) } ?? textBeforeCursor.startIndex
        let textBeforeWord = String(textBeforeCursor[..<wordStartIndex])
        
        let newText = textBeforeWord + suggestion.display + textAfterCursor
        string = newText
        
        // Position cursor after inserted suggestion
        let newCursorPosition = textBeforeWord.count + suggestion.display.count
        setSelectedRange(NSRange(location: newCursorPosition, length: 0))
        
        autocompleteDelegate?.textViewDidChangeText(self, text: newText)
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate

extension AutocompleteTextView: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return suggestions.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let suggestion = suggestions[row]
        
        let cellView = NSView()
        cellView.wantsLayer = true
        
        // Main label
        let nameLabel = NSTextField(labelWithString: suggestion.display)
        nameLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = NSColor.labelColor
        
        // Type indicator
        let typeLabel = NSTextField(labelWithString: suggestion.isWorkflow ? "workflow" : "prompt")
        typeLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        typeLabel.textColor = suggestion.isWorkflow ? NSColor.systemBlue : NSColor.secondaryLabelColor
        
        // Variables label
        let variablesText = suggestion.variables.isEmpty ? "" : "\(suggestion.variables.count) vars"
        let variablesLabel = NSTextField(labelWithString: variablesText)
        variablesLabel.font = NSFont.systemFont(ofSize: 10)
        variablesLabel.textColor = NSColor.tertiaryLabelColor
        
        cellView.addSubview(nameLabel)
        cellView.addSubview(typeLabel)
        cellView.addSubview(variablesLabel)
        
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        variablesLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
            nameLabel.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 4),
            
            typeLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            typeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            
            variablesLabel.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
            variablesLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            
            cellView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 24
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        selectedSuggestionIndex = row
        return true
    }
}