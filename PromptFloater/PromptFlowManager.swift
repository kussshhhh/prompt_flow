import Foundation
import Cocoa

class PromptFlowManager: ObservableObject {
    static let shared = PromptFlowManager()
    
    // MARK: - Published Properties
    @Published var prompts: [Prompt] = []
    @Published var executionLog: [ExecutionLog] = []
    @Published var isExecuting: Bool = false
    @Published var currentExecutionSteps: [ExecutionStep] = []
    @Published var currentStepIndex: Int = 0
    @Published var executionValues: [String: String] = [:]
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let promptsKey = "SavedPrompts"
    private let logsKey = "ExecutionLogs"
    
    private init() {
        loadPrompts()
        loadExecutionLog()
    }
    
    // MARK: - Prompt Management
    
    func addPrompt(name: String, content: String) -> Bool {
        // Check for duplicate names
        if prompts.contains(where: { $0.name == name }) {
            return false
        }
        
        let newPrompt = Prompt(name: name, content: content)
        prompts.append(newPrompt)
        savePrompts()
        return true
    }
    
    func updatePrompt(_ prompt: Prompt, name: String, content: String) -> Bool {
        // Check for duplicate names (excluding current prompt)
        if prompts.contains(where: { $0.name == name && $0.id != prompt.id }) {
            return false
        }
        
        if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
            prompts[index].name = name
            prompts[index].updateContent(content)
            savePrompts()
            return true
        }
        return false
    }
    
    func deletePrompt(_ prompt: Prompt) {
        prompts.removeAll { $0.id == prompt.id }
        savePrompts()
    }
    
    func getAutocompleteSuggestions(for query: String) -> [AutocompleteSuggestion] {
        guard !query.isEmpty else { return [] }
        
        let filteredPrompts = prompts.filter { prompt in
            prompt.name.lowercased().contains(query.lowercased())
        }
        
        return filteredPrompts.map { prompt in
            let allVariables = PromptParser.getAllVariablesRecursive(for: prompt, in: prompts)
            return AutocompleteSuggestion(prompt: prompt, allVariables: allVariables)
        }
    }
    
    // MARK: - Execution
    
    func executeContent(_ content: String) {
        guard !isExecuting else { return }
        
        let steps = PromptExecutionEngine.createExecutionSteps(from: content, prompts: prompts)
        
        if steps.isEmpty {
            // No variables needed, execute directly
            let resolvedContent = PromptExecutionEngine.resolveContent(content, with: [:], prompts: prompts)
            addExecutionLog(name: "Direct Execution", originalContent: content, filledContent: resolvedContent)
        } else {
            // Start step-by-step execution
            currentExecutionSteps = steps
            currentStepIndex = 0
            executionValues = [:]
            isExecuting = true
        }
    }
    
    func submitCurrentStepValues() -> Bool {
        guard isExecuting, currentStepIndex < currentExecutionSteps.count else { return false }
        
        let currentStep = currentExecutionSteps[currentStepIndex]
        
        // Validate all variables have values
        for variable in currentStep.variables {
            if executionValues[variable]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                return false
            }
        }
        
        // Save scoped values for this step
        var scopedValues: [String: String] = [:]
        for variable in currentStep.variables {
            let scopedName = currentStep.scopedVarNames[variable] ?? variable
            scopedValues[scopedName] = executionValues[variable]
        }
        
        currentExecutionSteps[currentStepIndex].filledValues = scopedValues
        
        // Move to next step or complete execution
        currentStepIndex += 1
        executionValues = [:]
        
        if currentStepIndex >= currentExecutionSteps.count {
            completeExecution()
        }
        
        return true
    }
    
    func cancelExecution() {
        isExecuting = false
        currentExecutionSteps = []
        currentStepIndex = 0
        executionValues = [:]
    }
    
    private func completeExecution() {
        // Collect all scoped values
        var allScopedValues: [String: String] = [:]
        for step in currentExecutionSteps {
            if let filledValues = step.filledValues {
                allScopedValues.merge(filledValues) { _, new in new }
            }
        }
        
        // Get the original content that was being executed
        // For now, we'll need to track this separately or reconstruct it
        let originalContent = "Workflow Execution" // TODO: Store original content
        
        // Resolve the final content
        let resolvedContent = PromptExecutionEngine.resolveContent(originalContent, with: allScopedValues, prompts: prompts)
        
        // Add to execution log
        addExecutionLog(name: "Workflow Complete", originalContent: originalContent, filledContent: resolvedContent)
        
        // Clean up
        isExecuting = false
        currentExecutionSteps = []
        currentStepIndex = 0
        executionValues = [:]
    }
    
    private func addExecutionLog(name: String, originalContent: String, filledContent: String) {
        let log = ExecutionLog(name: name, originalContent: originalContent, filledContent: filledContent)
        executionLog.insert(log, at: 0) // Add to beginning
        
        // Keep only last 50 logs
        if executionLog.count > 50 {
            executionLog = Array(executionLog.prefix(50))
        }
        
        saveExecutionLog()
    }
    
    // MARK: - Persistence
    
    private func savePrompts() {
        if let data = try? JSONEncoder().encode(prompts) {
            userDefaults.set(data, forKey: promptsKey)
        }
    }
    
    private func loadPrompts() {
        guard let data = userDefaults.data(forKey: promptsKey),
              let savedPrompts = try? JSONDecoder().decode([Prompt].self, from: data) else {
            // Load sample prompts for first time
            loadSamplePrompts()
            return
        }
        prompts = savedPrompts
    }
    
    private func saveExecutionLog() {
        if let data = try? JSONEncoder().encode(executionLog) {
            userDefaults.set(data, forKey: logsKey)
        }
    }
    
    private func loadExecutionLog() {
        guard let data = userDefaults.data(forKey: logsKey),
              let savedLog = try? JSONDecoder().decode([ExecutionLog].self, from: data) else {
            return
        }
        executionLog = savedLog
    }
    
    private func loadSamplePrompts() {
        let samplePrompts = [
            Prompt(name: "greet", content: "Hello {{name}}! Welcome to PromptFlow."),
            Prompt(name: "deployInfra", content: "Deploying infrastructure for {{environment}} with {{instanceType}} instances."),
            Prompt(name: "fullDeploy", content: "greet() \n\nStarting deployment process:\n1. deployInfra()\n2. Running tests on {{environment}}\n3. Deployment complete!")
        ]
        
        prompts = samplePrompts
        savePrompts()
    }
}

// MARK: - Search and Filter Extensions

extension PromptFlowManager {
    func searchPrompts(query: String) -> [Prompt] {
        guard !query.isEmpty else { return prompts }
        
        return prompts.filter { prompt in
            prompt.name.lowercased().contains(query.lowercased()) ||
            prompt.content.lowercased().contains(query.lowercased())
        }
    }
    
    func getWorkflowPrompts() -> [Prompt] {
        return prompts.filter { $0.isWorkflow }
    }
    
    func getSimplePrompts() -> [Prompt] {
        return prompts.filter { !$0.isWorkflow }
    }
}