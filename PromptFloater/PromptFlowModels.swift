import Foundation

// MARK: - Core Data Models

struct Prompt: Codable, Identifiable {
    let id: UUID
    var name: String
    var content: String
    var variables: [String]
    var isWorkflow: Bool
    let createdAt: Date
    var updatedAt: Date
    
    init(name: String, content: String) {
        self.id = UUID()
        self.name = name
        self.content = content
        self.variables = PromptParser.extractVariables(from: content)
        self.isWorkflow = PromptParser.extractPromptCalls(from: content).count > 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    mutating func updateContent(_ newContent: String) {
        self.content = newContent
        self.variables = PromptParser.extractVariables(from: newContent)
        self.isWorkflow = PromptParser.extractPromptCalls(from: newContent).count > 0
        self.updatedAt = Date()
    }
}

struct ExecutionStep {
    let id: UUID
    let type: StepType
    let variables: [String]
    let context: String
    let stepId: Int
    let scopedVarNames: [String: String]
    var filledValues: [String: String]?
    
    enum StepType {
        case variable
        case prompt(Prompt)
    }
    
    init(type: StepType, variables: [String], context: String, stepId: Int) {
        self.id = UUID()
        self.type = type
        self.variables = variables
        self.context = context
        self.stepId = stepId
        
        // Create scoped variable names
        var scopedNames: [String: String] = [:]
        for varName in variables {
            scopedNames[varName] = "step-\(stepId)-\(varName)"
        }
        self.scopedVarNames = scopedNames
        self.filledValues = nil
    }
}

struct ExecutionLog: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let name: String
    let originalContent: String
    let filledContent: String
    
    init(name: String, originalContent: String, filledContent: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.name = name
        self.originalContent = originalContent
        self.filledContent = filledContent
    }
}

struct AutocompleteSuggestion {
    let name: String
    let display: String
    let isWorkflow: Bool
    let variables: [String]
    let prompt: Prompt?
    
    init(prompt: Prompt, allVariables: [String]) {
        self.name = prompt.name
        self.display = "\(prompt.name)()"
        self.isWorkflow = prompt.isWorkflow
        self.variables = allVariables
        self.prompt = prompt
    }
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
        
        return Array(Set(variables)) // Remove duplicates
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
    
    static func getAllVariablesRecursive(for prompt: Prompt, in prompts: [Prompt], visited: Set<UUID> = Set()) -> [String] {
        // Prevent infinite recursion
        if visited.contains(prompt.id) {
            return []
        }
        
        var newVisited = visited
        newVisited.insert(prompt.id)
        
        // Get direct variables from this prompt
        var allVariables = prompt.variables
        
        // Get variables from called prompts
        let calledPromptNames = extractPromptCalls(from: prompt.content)
        
        for callName in calledPromptNames {
            if let calledPrompt = prompts.first(where: { $0.name == callName }) {
                let nestedVars = getAllVariablesRecursive(for: calledPrompt, in: prompts, visited: newVisited)
                allVariables.append(contentsOf: nestedVars)
            }
        }
        
        return Array(Set(allVariables)) // Remove duplicates
    }
}

// MARK: - Execution Engine

class PromptExecutionEngine {
    
    static func createExecutionSteps(from content: String, prompts: [Prompt]) -> [ExecutionStep] {
        var steps: [ExecutionStep] = []
        var stepCounter = 0
        
        func expandContent(_ text: String, parentContext: String = "") {
            // Find all items (prompts and variables) with positions
            let items = findItemsWithPositions(in: text)
            
            // Track call numbers for same prompt called multiple times
            var callCounts: [String: Int] = [:]
            
            // Process each item in sequential order
            for item in items {
                if item.type == .prompt {
                    let promptName = item.name
                    if let prompt = prompts.first(where: { $0.name == promptName }) {
                        // Track call number
                        callCounts[promptName] = (callCounts[promptName] ?? 0) + 1
                        let totalCalls = items.filter { $0.type == .prompt && $0.name == promptName }.count
                        
                        // Build context
                        var context = parentContext.isEmpty ? "" : "\(parentContext) → "
                        context += promptName
                        if totalCalls > 1 {
                            context += " (call \(callCounts[promptName]!))"
                        }
                        
                        // Recursively expand this prompt's content
                        expandContent(prompt.content, parentContext: context)
                    }
                } else if item.type == .variable {
                    // Add standalone variable
                    let context = parentContext.isEmpty ? "Main Input" : parentContext
                    let stepId = stepCounter
                    stepCounter += 1
                    
                    let step = ExecutionStep(
                        type: .variable,
                        variables: [item.name],
                        context: context,
                        stepId: stepId
                    )
                    
                    steps.append(step)
                }
            }
        }
        
        expandContent(content)
        return steps
    }
    
    private static func findItemsWithPositions(in text: String) -> [ItemWithPosition] {
        var items: [ItemWithPosition] = []
        
        // Find prompt calls
        let promptPattern = "(\\w+)\\(\\)"
        if let promptRegex = try? NSRegularExpression(pattern: promptPattern) {
            let matches = promptRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    items.append(ItemWithPosition(
                        type: .prompt,
                        name: String(text[range]),
                        position: match.range.location
                    ))
                }
            }
        }
        
        // Find variables
        let varPattern = "\\{\\{(\\w+)\\}\\}"
        if let varRegex = try? NSRegularExpression(pattern: varPattern) {
            let matches = varRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    items.append(ItemWithPosition(
                        type: .variable,
                        name: String(text[range]),
                        position: match.range.location
                    ))
                }
            }
        }
        
        // Sort by position
        return items.sorted { $0.position < $1.position }
    }
    
    private struct ItemWithPosition {
        enum ItemType {
            case prompt
            case variable
        }
        
        let type: ItemType
        let name: String
        let position: Int
    }
    
    static func resolveContent(_ text: String, with allScopedValues: [String: String], prompts: [Prompt], currentStepId: Int = 0) -> String {
        var resolved = text
        let items = findItemsWithPositions(in: text)
        
        // Track stepId as we process
        var stepIdCounter = currentStepId
        
        // Process in REVERSE for replacement (to maintain positions)
        for i in (0..<items.count).reversed() {
            let item = items[i]
            
            // Calculate stepId in FORWARD order
            let itemStepId = currentStepId + i
            
            if item.type == .prompt {
                if let prompt = prompts.first(where: { $0.name == item.name }) {
                    // Resolve this prompt's content with the correct stepId
                    let promptResolved = resolveContent(prompt.content, with: allScopedValues, prompts: prompts, currentStepId: itemStepId)
                    
                    // Replace the prompt call with resolved content
                    let pattern = "\(item.name)\\(\\)"
                    if let regex = try? NSRegularExpression(pattern: pattern) {
                        let range = NSRange(resolved.startIndex..., in: resolved)
                        resolved = regex.stringByReplacingMatches(in: resolved, range: range, withTemplate: promptResolved)
                    }
                }
            } else if item.type == .variable {
                // Use the correct stepId for this variable
                let scopedKey = "step-\(itemStepId)-\(item.name)"
                if let value = allScopedValues[scopedKey] {
                    // Replace the variable with its value
                    let pattern = "\\{\\{\(item.name)\\}\\}"
                    if let regex = try? NSRegularExpression(pattern: pattern) {
                        let range = NSRange(resolved.startIndex..., in: resolved)
                        resolved = regex.stringByReplacingMatches(in: resolved, range: range, withTemplate: value)
                    }
                }
            }
        }
        
        return resolved
    }
}