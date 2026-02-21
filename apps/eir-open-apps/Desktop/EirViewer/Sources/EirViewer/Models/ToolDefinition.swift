import Foundation

// MARK: - Tool Definition (JSON Schema for LLM)

struct ToolDefinition: Codable {
    let name: String
    let description: String
    let parameters: ToolParameters
}

struct ToolParameters: Codable {
    let type: String  // "object"
    let properties: [String: ToolProperty]
    let required: [String]?
}

struct ToolProperty: Codable {
    let type: String
    let description: String
    let `enum`: [String]?

    init(type: String, description: String, enum: [String]? = nil) {
        self.type = type
        self.description = description
        self.enum = `enum`
    }
}

// MARK: - Tool Call (from LLM response)

struct ToolCall: Codable {
    let id: String
    let name: String
    let arguments: String  // JSON string
}

// MARK: - Tool Result (sent back to LLM)

struct ToolResult: Codable {
    let toolCallId: String
    let content: String
}
