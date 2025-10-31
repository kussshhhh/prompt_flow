import SwiftUI
import Cocoa
import Foundation
import Combine

// MARK: - Data Models

struct Prompt: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var content: String
    var createdAt = Date()
    var updatedAt = Date()
    
    // Computed properties
    var variables: [String] {
        PromptParser.extractVariables(from: content)
    }
    
    var isWorkflow: Bool {
        !calledPrompts.isEmpty
    }
    
    var calledPrompts: [String] {
        PromptParser.extractPromptCalls(from: content)
    }
    
    mutating func updateContent(_ newContent: String) {
        content = newContent
        updatedAt = Date()
    }
}

struct ExecutionStep: Identifiable {
    var id = UUID()
    var stepId: Int
    var variables: [String]
    var context: String
    var scopedVarNames: [String: String]
    var filledValues: [String: String]?
    
    init(stepId: Int, variables: [String], context: String) {
        self.stepId = stepId
        self.variables = variables
        self.context = context
        
        var scopedNames: [String: String] = [:]
        for varName in variables {
            scopedNames[varName] = "step-\(stepId)-\(varName)"
        }
        self.scopedVarNames = scopedNames
    }
}

struct ExecutionLog: Identifiable, Codable {
    var id = UUID()
    var workflowName: String
    var timestamp = Date()
    var originalInput: String
    var finalOutput: String
}

enum ItemType {
    case prompt
    case variable
}

struct ItemWithPosition {
    let type: ItemType
    let name: String
    let position: Int
    let match: String
    let range: Range<String.Index>
}

// MARK: - Parser Utilities

class PromptParser {
    static func extractVariables(from text: String) -> [String] {
        let pattern = "\\{\\{(\\w+)\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var variables: [String] = []
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                variables.append(String(text[range]))
            }
        }
        
        return Array(Set(variables))
    }
    
    static func extractPromptCalls(from text: String) -> [String] {
        let pattern = "(\\w+)\\(\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var calls: [String] = []
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                calls.append(String(text[range]))
            }
        }
        
        return calls
    }
    
    static func findItemsWithPositions(_ text: String) -> [ItemWithPosition] {
        var items: [ItemWithPosition] = []
        
        // Find prompt calls
        let promptPattern = "(\\w+)\\(\\)"
        if let promptRegex = try? NSRegularExpression(pattern: promptPattern) {
            let matches = promptRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text),
                   let fullRange = Range(match.range, in: text) {
                    items.append(ItemWithPosition(
                        type: .prompt,
                        name: String(text[range]),
                        position: match.range.location,
                        match: String(text[fullRange]),
                        range: fullRange
                    ))
                }
            }
        }
        
        // Find variables
        let varPattern = "\\{\\{(\\w+)\\}\\}"
        if let varRegex = try? NSRegularExpression(pattern: varPattern) {
            let matches = varRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text),
                   let fullRange = Range(match.range, in: text) {
                    items.append(ItemWithPosition(
                        type: .variable,
                        name: String(text[range]),
                        position: match.range.location,
                        match: String(text[fullRange]),
                        range: fullRange
                    ))
                }
            }
        }
        
        return items.sorted { $0.position < $1.position }
    }
}

// MARK: - Execution Engine

class ExecutionEngine {
    static func buildExecutionQueue(from input: String, prompts: [Prompt]) -> [ExecutionStep] {
        var queue: [ExecutionStep] = []
        var stepCounter = 0
        
        func expandContent(_ text: String, parentContext: String = "") {
            let items = PromptParser.findItemsWithPositions(text)
            var callCounts: [String: Int] = [:]
            
            for item in items {
                if item.type == .prompt {
                    guard let prompt = prompts.first(where: { $0.name == item.name }) else { continue }
                    
                    callCounts[item.name, default: 0] += 1
                    let totalCalls = items.filter { $0.type == .prompt && $0.name == item.name }.count
                    var context = parentContext.isEmpty ? "" : "\(parentContext) → "
                    context += item.name
                    if totalCalls > 1 {
                        context += " (call \(callCounts[item.name]!))"
                    }
                    
                    expandContent(prompt.content, parentContext: context)
                    
                } else if item.type == .variable {
                    let context = parentContext.isEmpty ? "Main Input" : parentContext
                    
                    queue.append(ExecutionStep(
                        stepId: stepCounter,
                        variables: [item.name],
                        context: context
                    ))
                    
                    stepCounter += 1
                }
            }
        }
        
        expandContent(input)
        return queue
    }
    
    static func resolveContent(_ text: String, currentStepId: Int = 0, allValues: [String: String], prompts: [Prompt]) -> String {
        var resolved = text
        let items = PromptParser.findItemsWithPositions(text)
        
        // Process in REVERSE for string replacement
        for i in stride(from: items.count - 1, through: 0, by: -1) {
            let item = items[i]
            
            // Calculate stepId in FORWARD order
            let itemStepId = currentStepId + i
            
            if item.type == .prompt {
                guard let prompt = prompts.first(where: { $0.name == item.name }) else { continue }
                let promptResolved = resolveContent(prompt.content, currentStepId: itemStepId, allValues: allValues, prompts: prompts)
                resolved = resolved.replacingCharacters(in: item.range, with: promptResolved)
            } else if item.type == .variable {
                let scopedKey = "step-\(itemStepId)-\(item.name)"
                let value = allValues[scopedKey] ?? item.match
                resolved = resolved.replacingCharacters(in: item.range, with: value)
            }
        }
        
        return resolved
    }
}

// MARK: - PromptFlow Manager

class PromptFlowManager: ObservableObject {
    @Published var prompts: [Prompt] = []
    @Published var executionLog: [ExecutionLog] = []
    @Published var isExecuting = false
    @Published var currentExecutionSteps: [ExecutionStep] = []
    @Published var currentStepIndex = 0
    @Published var executionValues: [String: String] = [:]
    @Published var windowOpacity: Double = 0.95
    @Published var searchQuery = ""
    @Published var selectedTab = 0
    @Published var editingPrompt: Prompt?
    @Published var isShowingExecutionModal = false
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadData()
        loadSamplePrompts()
    }
    
    // MARK: - Prompt Management
    
    func addPrompt(name: String, content: String) -> Bool {
        guard !prompts.contains(where: { $0.name == name }) else { return false }
        
        let newPrompt = Prompt(name: name, content: content)
        prompts.append(newPrompt)
        saveData()
        return true
    }
    
    func updatePrompt(_ prompt: Prompt, name: String, content: String) -> Bool {
        guard !prompts.contains(where: { $0.name == name && $0.id != prompt.id }) else { return false }
        
        if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
            prompts[index].name = name
            prompts[index].updateContent(content)
            saveData()
            return true
        }
        return false
    }
    
    func deletePrompt(_ prompt: Prompt) {
        prompts.removeAll { $0.id == prompt.id }
        saveData()
    }
    
    var filteredPrompts: [Prompt] {
        guard !searchQuery.isEmpty else { return prompts }
        return prompts.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.content.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    // MARK: - Execution
    
    func executeContent(_ content: String) {
        let steps = ExecutionEngine.buildExecutionQueue(from: content, prompts: prompts)
        
        if steps.isEmpty {
            let resolvedContent = ExecutionEngine.resolveContent(content, allValues: [:], prompts: prompts)
            addExecutionLog(name: "Direct Execution", originalInput: content, finalOutput: resolvedContent)
        } else {
            currentExecutionSteps = steps
            currentStepIndex = 0
            executionValues = [:]
            isExecuting = true
            isShowingExecutionModal = true
        }
    }
    
    func submitCurrentStepValues() -> Bool {
        guard isExecuting, currentStepIndex < currentExecutionSteps.count else { return false }
        
        let currentStep = currentExecutionSteps[currentStepIndex]
        
        for variable in currentStep.variables {
            guard let value = executionValues[variable], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }
        }
        
        var scopedValues: [String: String] = [:]
        for variable in currentStep.variables {
            let scopedName = currentStep.scopedVarNames[variable] ?? variable
            scopedValues[scopedName] = executionValues[variable]
        }
        
        currentExecutionSteps[currentStepIndex].filledValues = scopedValues
        currentStepIndex += 1
        executionValues = [:]
        
        if currentStepIndex >= currentExecutionSteps.count {
            completeExecution()
        }
        
        return true
    }
    
    func cancelExecution() {
        isExecuting = false
        isShowingExecutionModal = false
        currentExecutionSteps = []
        currentStepIndex = 0
        executionValues = [:]
    }
    
    private func completeExecution() {
        var allScopedValues: [String: String] = [:]
        for step in currentExecutionSteps {
            if let filledValues = step.filledValues {
                allScopedValues.merge(filledValues) { _, new in new }
            }
        }
        
        let originalContent = "Workflow Execution"
        let resolvedContent = ExecutionEngine.resolveContent(originalContent, allValues: allScopedValues, prompts: prompts)
        
        addExecutionLog(name: "Workflow Complete", originalInput: originalContent, finalOutput: resolvedContent)
        
        isExecuting = false
        isShowingExecutionModal = false
        currentExecutionSteps = []
        currentStepIndex = 0
        executionValues = [:]
    }
    
    private func addExecutionLog(name: String, originalInput: String, finalOutput: String) {
        let log = ExecutionLog(workflowName: name, originalInput: originalInput, finalOutput: finalOutput)
        executionLog.insert(log, at: 0)
        
        if executionLog.count > 50 {
            executionLog = Array(executionLog.prefix(50))
        }
        
        saveData()
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        if let promptsData = try? JSONEncoder().encode(prompts) {
            userDefaults.set(promptsData, forKey: "prompts")
        }
        if let logsData = try? JSONEncoder().encode(executionLog) {
            userDefaults.set(logsData, forKey: "logs")
        }
        userDefaults.set(windowOpacity, forKey: "windowOpacity")
    }
    
    private func loadData() {
        if let promptsData = userDefaults.data(forKey: "prompts"),
           let savedPrompts = try? JSONDecoder().decode([Prompt].self, from: promptsData) {
            prompts = savedPrompts
        }
        
        if let logsData = userDefaults.data(forKey: "logs"),
           let savedLogs = try? JSONDecoder().decode([ExecutionLog].self, from: logsData) {
            executionLog = savedLogs
        }
        
        windowOpacity = userDefaults.double(forKey: "windowOpacity")
        if windowOpacity == 0 { windowOpacity = 0.95 }
    }
    
    private func loadSamplePrompts() {
        guard prompts.isEmpty else { return }
        
        prompts = [
            Prompt(name: "greet", content: "Hello {{name}}! Welcome to PromptFlow."),
            Prompt(name: "deployInfra", content: "Deploying infrastructure for {{environment}} with {{instanceType}} instances."),
            Prompt(name: "fullDeploy", content: "greet()\n\nStarting deployment process:\n1. deployInfra()\n2. Running tests on {{environment}}\n3. Deployment complete!")
        ]
        saveData()
    }
}

// MARK: - SwiftUI Views

struct PromptFlowApp: View {
    @StateObject private var manager = PromptFlowManager()
    @State private var inputText = "Enter your prompt here..."
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(manager: manager)
            
            // Main Content
            HStack(spacing: 0) {
                // Left Panel - Input Area
                VStack(spacing: 12) {
                    TextEditor(text: $inputText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                    
                    HStack(spacing: 8) {
                        Button("▶️ Execute") {
                            manager.executeContent(inputText)
                        }
                        .buttonStyle(ExecuteButtonStyle())
                        
                        Spacer()
                    }
                }
                .frame(width: 300)
                .padding(16)
                
                // Right Panel - Management Interface
                ManagementPanelView(manager: manager)
            }
        }
        .background(.regularMaterial)
        .sheet(isPresented: $manager.isShowingExecutionModal) {
            ExecutionModalView(manager: manager)
        }
        .onReceive(manager.$windowOpacity) { opacity in
            // Update window opacity when slider changes
            updateWindowOpacity(opacity)
        }
    }
    
    private func updateWindowOpacity(_ opacity: Double) {
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow {
                window.alphaValue = CGFloat(opacity)
            }
        }
    }
}

struct HeaderView: View {
    @ObservedObject var manager: PromptFlowManager
    
    var body: some View {
        HStack {
            Text("PromptFlow Manager")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.4, green: 0.494, blue: 0.918), Color(red: 0.463, green: 0.294, blue: 0.635)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Spacer()
            
            HStack(spacing: 8) {
                Text("\(Int(manager.windowOpacity * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: $manager.windowOpacity, in: 0.3...1.0)
                    .frame(width: 120)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color(red: 0.4, green: 0.494, blue: 0.918).opacity(0.2), Color(red: 0.463, green: 0.294, blue: 0.635).opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

struct ManagementPanelView: View {
    @ObservedObject var manager: PromptFlowManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            HStack(spacing: 0) {
                TabButton(title: "📚 Prompts", count: manager.prompts.count, isSelected: manager.selectedTab == 0) {
                    manager.selectedTab = 0
                }
                
                TabButton(title: "➕ Create/Edit", isSelected: manager.selectedTab == 1) {
                    manager.selectedTab = 1
                }
                
                TabButton(title: "📋 Logs", count: manager.executionLog.count, isSelected: manager.selectedTab == 2) {
                    manager.selectedTab = 2
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            // Tab Content
            ScrollView {
                switch manager.selectedTab {
                case 0:
                    PromptsTabView(manager: manager)
                case 1:
                    CreateEditTabView(manager: manager)
                case 2:
                    LogsTabView(manager: manager)
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 400)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
    }
}

struct TabButton: View {
    let title: String
    var count: Int?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if let count = count {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundForButton)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundForButton: some View {
        Group {
            if isSelected {
                LinearGradient(
                    colors: [Color(red: 0.4, green: 0.494, blue: 0.918), Color(red: 0.463, green: 0.294, blue: 0.635)],
                    startPoint: .leading,
                    endPoint: .trailing
                ).opacity(0.8)
            } else {
                Color.clear
            }
        }
    }
}

struct PromptsTabView: View {
    @ObservedObject var manager: PromptFlowManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search prompts...", text: $manager.searchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !manager.searchQuery.isEmpty {
                    Button("Clear") {
                        manager.searchQuery = ""
                    }
                    .font(.caption)
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Prompts List
            LazyVStack(spacing: 8) {
                ForEach(manager.filteredPrompts) { prompt in
                    PromptCardView(prompt: prompt, manager: manager)
                }
            }
            
            if manager.filteredPrompts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No prompts yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(40)
            }
            
            Spacer()
        }
        .padding(16)
    }
}

struct PromptCardView: View {
    let prompt: Prompt
    @ObservedObject var manager: PromptFlowManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(prompt.name)()")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.primary)
                
                if prompt.isWorkflow {
                    Text("workflow")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
            
            if !prompt.variables.isEmpty {
                HStack {
                    Text("requires:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    FlowLayout {
                        ForEach(prompt.variables, id: \.self) { variable in
                            Text(variable)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            Text(prompt.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Text("Updated \(prompt.updatedAt, formatter: DateFormatter.shortDateTime)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Button("Insert") {
                    // Insert prompt call into input
                }
                .font(.caption)
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Edit") {
                    manager.editingPrompt = prompt
                    manager.selectedTab = 1
                }
                .font(.caption)
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Delete") {
                    manager.deletePrompt(prompt)
                }
                .font(.caption)
                .buttonStyle(DangerButtonStyle())
            }
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CreateEditTabView: View {
    @ObservedObject var manager: PromptFlowManager
    @State private var promptName = ""
    @State private var promptContent = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Prompt Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt Name")
                    .font(.headline)
                
                TextField("Enter prompt name...", text: $promptName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Prompt Content
            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt Content")
                    .font(.headline)
                
                TextEditor(text: $promptContent)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
                    .frame(minHeight: 120)
            }
            
            // Variables Detected
            let variables = PromptParser.extractVariables(from: promptContent)
            if !variables.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Variables detected:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    FlowLayout {
                        ForEach(variables, id: \.self) { variable in
                            Text(variable)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Workflow Indicator
            let calledPrompts = PromptParser.extractPromptCalls(from: promptContent)
            if !calledPrompts.isEmpty {
                HStack {
                    Text("🔗")
                    Text("This is a workflow! Calls: \(calledPrompts.joined(separator: ", "))")
                        .font(.caption)
                }
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Buttons
            HStack(spacing: 12) {
                Button("Save") {
                    savePrompt()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(promptName.isEmpty || promptContent.isEmpty)
                
                Button("Cancel") {
                    clearForm()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            Spacer()
        }
        .padding(16)
        .onAppear {
            if let editing = manager.editingPrompt {
                promptName = editing.name
                promptContent = editing.content
            }
        }
        .onChange(of: manager.editingPrompt) { editing in
            if let editing = editing {
                promptName = editing.name
                promptContent = editing.content
            } else {
                clearForm()
            }
        }
    }
    
    private func savePrompt() {
        if let editing = manager.editingPrompt {
            _ = manager.updatePrompt(editing, name: promptName, content: promptContent)
        } else {
            _ = manager.addPrompt(name: promptName, content: promptContent)
        }
        clearForm()
    }
    
    private func clearForm() {
        promptName = ""
        promptContent = ""
        manager.editingPrompt = nil
    }
}

struct LogsTabView: View {
    @ObservedObject var manager: PromptFlowManager
    
    var body: some View {
        VStack(spacing: 12) {
            if manager.executionLog.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No executions yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(manager.executionLog) { log in
                        LogCardView(log: log)
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
    }
}

struct LogCardView: View {
    let log: ExecutionLog
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.workflowName)
                        .font(.headline)
                    Text(log.timestamp, formatter: DateFormatter.fullDateTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(isExpanded ? "Collapse" : "Expand") {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
                .font(.caption)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Result:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(log.finalOutput)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ExecutionModalView: View {
    @ObservedObject var manager: PromptFlowManager
    
    var body: some View {
        if manager.currentStepIndex < manager.currentExecutionSteps.count {
            let currentStep = manager.currentExecutionSteps[manager.currentStepIndex]
            ExecutionStepView(step: currentStep, manager: manager)
        } else {
            Text("No execution steps")
                .frame(width: 500, height: 600)
                .background(.regularMaterial)
        }
    }
}

struct ExecutionStepView: View {
    let step: ExecutionStep
    @ObservedObject var manager: PromptFlowManager
    
    var body: some View {
        VStack(spacing: 0) {
            ExecutionHeaderView(step: step, manager: manager)
            ExecutionInfoBanner(step: step)
            ExecutionVariableInputs(step: step, manager: manager)
            ExecutionFooterButtons(step: step, manager: manager)
        }
        .frame(width: 500, height: 600)
        .background(.regularMaterial)
    }
}

struct ExecutionHeaderView: View {
    let step: ExecutionStep
    @ObservedObject var manager: PromptFlowManager
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Step \(manager.currentStepIndex + 1) of \(manager.currentExecutionSteps.count)")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(Double(manager.currentStepIndex) / Double(manager.currentExecutionSteps.count) * 100))% complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(step.context)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.purple)
            
            Text("Provide values for this prompt's variables")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
    }
}

struct ExecutionInfoBanner: View {
    let step: ExecutionStep
    
    var body: some View {
        HStack {
            Image(systemName: "info.circle")
            Text("These variables are used in: \(step.context)")
                .font(.caption)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
    }
}

struct ExecutionVariableInputs: View {
    let step: ExecutionStep
    @ObservedObject var manager: PromptFlowManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(step.variables, id: \.self) { variable in
                    VariableInputRow(variable: variable, step: step, manager: manager)
                }
            }
            .padding(16)
        }
    }
}

struct VariableInputRow: View {
    let variable: String
    let step: ExecutionStep
    @ObservedObject var manager: PromptFlowManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(variable)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .clipShape(Capsule())
                
                Text("*")
                    .foregroundColor(.red)
                
                Spacer()
                
                if let value = manager.executionValues[variable], !value.isEmpty {
                    HStack {
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                        Text("provided")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            TextField("Value for \(variable) in \(step.context)...", text: Binding(
                get: { manager.executionValues[variable] ?? "" },
                set: { manager.executionValues[variable] = $0 }
            ))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        (manager.executionValues[variable]?.isEmpty ?? true) ? Color.gray : Color.green,
                        lineWidth: 1
                    )
            )
        }
    }
}

struct ExecutionFooterButtons: View {
    let step: ExecutionStep
    @ObservedObject var manager: PromptFlowManager
    
    var body: some View {
        VStack(spacing: 8) {
            let missingVars = step.variables.filter { manager.executionValues[$0]?.isEmpty ?? true }
            
            Button(action: {
                if manager.submitCurrentStepValues() {
                    // Continue to next step or complete
                }
            }) {
                HStack {
                    if !missingVars.isEmpty {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Missing: \(missingVars.joined(separator: ", "))")
                    } else {
                        Image(systemName: manager.currentStepIndex == manager.currentExecutionSteps.count - 1 ? "checkmark" : "arrow.right")
                        Text(manager.currentStepIndex == manager.currentExecutionSteps.count - 1 ? "Complete Workflow" : "Next Prompt")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(buttonBackground(missingVars: missingVars))
                .foregroundColor(missingVars.isEmpty ? .white : .gray)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!missingVars.isEmpty)
            
            Button("Cancel") {
                manager.cancelExecution()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(16)
    }
    
    private func buttonBackground(missingVars: [String]) -> some View {
        Group {
            if missingVars.isEmpty {
                LinearGradient(colors: [Color.green.opacity(0.8), Color.green], startPoint: .leading, endPoint: .trailing)
            } else {
                Color.gray.opacity(0.3)
            }
        }
    }
}

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.4, green: 0.494, blue: 0.918), Color(red: 0.463, green: 0.294, blue: 0.635)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .foregroundColor(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ExecuteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.133, green: 0.588, blue: 0.353), Color.green],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Helper Views

struct FlowLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews
        )
        return result.bounds
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews
        )
        for index in subviews.indices {
            let frame = result.frames[index]
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }
}

struct FlowResult {
    var frames: [CGRect] = []
    var bounds = CGSize.zero
    
    init(in maxWidth: CGFloat, subviews: LayoutSubviews) {
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if origin.x + size.width > maxWidth {
                origin.x = 0
                origin.y += rowHeight + 4
                rowHeight = 0
            }
            
            frames.append(CGRect(origin: origin, size: size))
            
            origin.x += size.width + 4
            rowHeight = max(rowHeight, size.height)
        }
        
        bounds = CGSize(width: maxWidth, height: origin.y + rowHeight)
    }
}

// MARK: - Date Formatters

extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - FloatingWindowController

@objc class FloatingWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 700, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.init(window: window)
        setupWindow()
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "PromptFlow"
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = true
        window.level = .floating
        
        // Set minimum and maximum sizes
        window.minSize = NSSize(width: 700, height: 600)
        window.maxSize = NSSize(width: 1000, height: 800)
        
        // Create the SwiftUI hosting view
        let hostingView = NSHostingView(rootView: PromptFlowApp())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set the content view
        window.contentView = hostingView
        
        // Add constraints to fill the window
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor)
        ])
    }
}