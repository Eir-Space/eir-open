import Foundation

enum LLMError: LocalizedError {
    case noProvider
    case noAPIKey
    case requestFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noProvider: return "No LLM provider configured"
        case .noAPIKey: return "No API key set for this provider"
        case .requestFailed(let msg): return "Request failed: \(msg)"
        case .invalidResponse: return "Invalid response from LLM"
        }
    }
}

// MARK: - LLM Message (tool-aware)

enum LLMMessage {
    case system(String)
    case user(String)
    case assistant(String)
    case assistantToolCalls(String, [ToolCall])  // content + tool calls
    case toolResult(ToolResult)
}

// MARK: - Stream Result

enum StreamResult {
    case text(String)                    // Final accumulated text
    case toolCalls(String, [ToolCall])   // Accumulated text before tool calls + the tool calls
}

actor LLMService {
    private let config: LLMProviderConfig
    private let apiKey: String

    init(config: LLMProviderConfig, apiKey: String) {
        self.config = config
        self.apiKey = apiKey
    }

    // MARK: - Existing methods (backward compat)

    func completeChat(
        messages: [(role: String, content: String)]
    ) async throws -> String {
        nonisolated(unsafe) var result = ""
        try await streamChat(messages: messages) { token in
            result += token
        }
        return result
    }

    func streamChat(
        messages: [(role: String, content: String)],
        onToken: @Sendable @escaping (String) -> Void
    ) async throws {
        if config.type.usesOpenAICompat {
            try await streamOpenAICompat(messages: messages, onToken: onToken)
        } else {
            try await streamAnthropic(messages: messages, onToken: onToken)
        }
    }

    // MARK: - Tool-aware streaming

    func streamChatWithTools(
        messages: [LLMMessage],
        tools: [ToolDefinition],
        onToken: @Sendable @escaping (String) -> Void
    ) async throws -> StreamResult {
        if config.type.usesOpenAICompat {
            return try await streamOpenAICompatWithTools(messages: messages, tools: tools, onToken: onToken)
        } else {
            return try await streamAnthropicWithTools(messages: messages, tools: tools, onToken: onToken)
        }
    }

    // MARK: - OpenAI Compatible (plain)

    private func streamOpenAICompat(
        messages: [(role: String, content: String)],
        onToken: @Sendable @escaping (String) -> Void
    ) async throws {
        let url = URL(string: "\(config.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": config.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            throw LLMError.requestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }

            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                continue
            }

            onToken(content)
        }
    }

    // MARK: - OpenAI Compatible (with tools)

    private func streamOpenAICompatWithTools(
        messages: [LLMMessage],
        tools: [ToolDefinition],
        onToken: @Sendable @escaping (String) -> Void
    ) async throws -> StreamResult {
        let url = URL(string: "\(config.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let formattedMessages = formatOpenAIMessages(messages)
        let formattedTools = formatOpenAITools(tools)

        var body: [String: Any] = [
            "model": config.model,
            "messages": formattedMessages,
            "stream": true,
        ]
        if !formattedTools.isEmpty {
            body["tools"] = formattedTools
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            throw LLMError.requestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        nonisolated(unsafe) var accumulatedContent = ""
        nonisolated(unsafe) var toolCallsMap: [Int: (id: String, name: String, arguments: String)] = [:]

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }

            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any] else {
                continue
            }

            // Text content
            if let content = delta["content"] as? String {
                accumulatedContent += content
                onToken(content)
            }

            // Tool calls (streamed incrementally)
            if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                for tc in toolCalls {
                    guard let index = tc["index"] as? Int else { continue }
                    if let id = tc["id"] as? String {
                        toolCallsMap[index] = (id: id, name: "", arguments: "")
                    }
                    if let function = tc["function"] as? [String: Any] {
                        if let name = function["name"] as? String {
                            toolCallsMap[index]?.name = name
                        }
                        if let args = function["arguments"] as? String {
                            toolCallsMap[index]?.arguments += args
                        }
                    }
                }
            }
        }

        if !toolCallsMap.isEmpty {
            let calls = toolCallsMap.sorted { $0.key < $1.key }.map { (_, v) in
                ToolCall(id: v.id, name: v.name, arguments: v.arguments)
            }
            return .toolCalls(accumulatedContent, calls)
        }

        return .text(accumulatedContent)
    }

    // MARK: - Anthropic (plain)

    private func streamAnthropic(
        messages: [(role: String, content: String)],
        onToken: @Sendable @escaping (String) -> Void
    ) async throws {
        let url = URL(string: "\(config.baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAnthropicAuth(to: &request)
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let systemMessage = messages.first(where: { $0.role == "system" })?.content ?? ""
        let chatMessages = messages.filter { $0.role != "system" }

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": 4096,
            "system": systemMessage,
            "messages": chatMessages.map { ["role": $0.role, "content": $0.content] },
            "stream": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            throw LLMError.requestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))

            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let eventType = json["type"] as? String
            if eventType == "content_block_delta",
               let delta = json["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                onToken(text)
            } else if eventType == "message_stop" {
                break
            }
        }
    }

    // MARK: - Anthropic (with tools)

    private func streamAnthropicWithTools(
        messages: [LLMMessage],
        tools: [ToolDefinition],
        onToken: @Sendable @escaping (String) -> Void
    ) async throws -> StreamResult {
        let url = URL(string: "\(config.baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAnthropicAuth(to: &request)
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (systemPrompt, formattedMessages) = formatAnthropicMessages(messages)
        let formattedTools = formatAnthropicTools(tools)

        var body: [String: Any] = [
            "model": config.model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": formattedMessages,
            "stream": true,
        ]
        if !formattedTools.isEmpty {
            body["tools"] = formattedTools
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Debug: dump the request body
        if let requestBody = request.httpBody,
           let jsonObj = try? JSONSerialization.jsonObject(with: requestBody),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObj, options: []),
           let bodyStr = String(data: prettyData, encoding: .utf8) {
            DebugLog.log("[Anthropic] Request URL: \(url)")
            DebugLog.log("[Anthropic] Request body (\(bodyStr.count) chars): messages=\(formattedMessages.count), tools=\(formattedTools.count)")
            // Dump messages summary
            for (i, msg) in formattedMessages.enumerated() {
                let role = msg["role"] as? String ?? "?"
                if let content = msg["content"] as? String {
                    DebugLog.log("[Anthropic]   msg[\(i)] \(role): \(content.prefix(150))")
                } else if let content = msg["content"] as? [[String: Any]] {
                    DebugLog.log("[Anthropic]   msg[\(i)] \(role): \(content.count) blocks — types: \(content.compactMap { $0["type"] as? String })")
                }
            }
        }

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        DebugLog.log("[Anthropic] Response status: \(httpResponse.statusCode)")

        if httpResponse.statusCode != 200 {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            DebugLog.log("[Anthropic] ERROR body: \(errorBody)")
            throw LLMError.requestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        nonisolated(unsafe) var accumulatedContent = ""
        nonisolated(unsafe) var currentToolUse: (id: String, name: String, inputJson: String)?
        nonisolated(unsafe) var toolCalls: [ToolCall] = []
        nonisolated(unsafe) var eventCount = 0

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))

            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let eventType = json["type"] as? String
            eventCount += 1

            switch eventType {
            case "content_block_start":
                if let contentBlock = json["content_block"] as? [String: Any],
                   let blockType = contentBlock["type"] as? String {
                    DebugLog.log("[Anthropic] content_block_start: type=\(blockType)")
                    if blockType == "tool_use" {
                        let id = contentBlock["id"] as? String ?? UUID().uuidString
                        let name = contentBlock["name"] as? String ?? ""
                        DebugLog.log("[Anthropic]   tool_use: id=\(id) name=\(name)")
                        currentToolUse = (id: id, name: name, inputJson: "")
                    }
                }

            case "content_block_delta":
                if let delta = json["delta"] as? [String: Any] {
                    let deltaType = delta["type"] as? String
                    if deltaType == "text_delta", let text = delta["text"] as? String {
                        accumulatedContent += text
                        onToken(text)
                    } else if deltaType == "input_json_delta", let partial = delta["partial_json"] as? String {
                        currentToolUse?.inputJson += partial
                    }
                }

            case "content_block_stop":
                if let tu = currentToolUse {
                    DebugLog.log("[Anthropic] content_block_stop: tool_use \(tu.name) args=\(tu.inputJson.prefix(200))")
                    toolCalls.append(ToolCall(id: tu.id, name: tu.name, arguments: tu.inputJson))
                    currentToolUse = nil
                }

            case "message_stop":
                DebugLog.log("[Anthropic] message_stop after \(eventCount) events, text=\(accumulatedContent.count) chars, toolCalls=\(toolCalls.count)")
                break

            case "message_start":
                if let message = json["message"] as? [String: Any] {
                    let stopReason = message["stop_reason"] as? String ?? "nil"
                    DebugLog.log("[Anthropic] message_start: stop_reason=\(stopReason)")
                }

            case "message_delta":
                if let delta = json["delta"] as? [String: Any] {
                    let stopReason = delta["stop_reason"] as? String ?? "nil"
                    DebugLog.log("[Anthropic] message_delta: stop_reason=\(stopReason)")
                }

            case "error":
                let errorInfo = json["error"] as? [String: Any]
                let errorMsg = errorInfo?["message"] as? String ?? "unknown"
                DebugLog.log("[Anthropic] SSE error event: \(errorMsg)")

            default:
                break
            }
        }

        DebugLog.log("[Anthropic] Stream ended: \(eventCount) events, text=\(accumulatedContent.count) chars, toolCalls=\(toolCalls.count)")

        if !toolCalls.isEmpty {
            return .toolCalls(accumulatedContent, toolCalls)
        }

        return .text(accumulatedContent)
    }

    // MARK: - Message Formatting (OpenAI)

    private func formatOpenAIMessages(_ messages: [LLMMessage]) -> [[String: Any]] {
        var result: [[String: Any]] = []
        for msg in messages {
            switch msg {
            case .system(let content):
                result.append(["role": "system", "content": content])
            case .user(let content):
                result.append(["role": "user", "content": content])
            case .assistant(let content):
                result.append(["role": "assistant", "content": content])
            case .assistantToolCalls(let content, let calls):
                var m: [String: Any] = ["role": "assistant"]
                if !content.isEmpty { m["content"] = content }
                m["tool_calls"] = calls.map { call -> [String: Any] in
                    [
                        "id": call.id,
                        "type": "function",
                        "function": [
                            "name": call.name,
                            "arguments": call.arguments,
                        ] as [String: Any],
                    ]
                }
                result.append(m)
            case .toolResult(let tr):
                result.append([
                    "role": "tool",
                    "tool_call_id": tr.toolCallId,
                    "content": tr.content,
                ])
            }
        }
        return result
    }

    private func formatOpenAITools(_ tools: [ToolDefinition]) -> [[String: Any]] {
        tools.map { tool -> [String: Any] in
            [
                "type": "function",
                "function": [
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": encodeToolParameters(tool.parameters),
                ] as [String: Any],
            ]
        }
    }

    // MARK: - Message Formatting (Anthropic)

    private func formatAnthropicMessages(_ messages: [LLMMessage]) -> (String, [[String: Any]]) {
        var systemPrompt = ""
        var result: [[String: Any]] = []

        for msg in messages {
            switch msg {
            case .system(let content):
                systemPrompt = content
            case .user(let content):
                result.append(["role": "user", "content": content])
            case .assistant(let content):
                result.append(["role": "assistant", "content": content])
            case .assistantToolCalls(let content, let calls):
                var contentBlocks: [[String: Any]] = []
                if !content.isEmpty {
                    contentBlocks.append(["type": "text", "text": content])
                }
                for call in calls {
                    var inputObj: Any = [String: Any]()
                    if let data = call.arguments.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: data) {
                        inputObj = parsed
                    }
                    contentBlocks.append([
                        "type": "tool_use",
                        "id": call.id,
                        "name": call.name,
                        "input": inputObj,
                    ])
                }
                result.append(["role": "assistant", "content": contentBlocks])
            case .toolResult(let tr):
                let block: [String: Any] = [
                    "type": "tool_result",
                    "tool_use_id": tr.toolCallId,
                    "content": tr.content,
                ]
                // Anthropic requires all tool results in a single user message after an assistant message.
                // Merge consecutive tool results into the previous user message if it already has tool_result blocks.
                if let lastIndex = result.indices.last,
                   let lastRole = result[lastIndex]["role"] as? String,
                   lastRole == "user",
                   let lastContent = result[lastIndex]["content"] as? [[String: Any]],
                   lastContent.first?["type"] as? String == "tool_result" {
                    var merged = lastContent
                    merged.append(block)
                    result[lastIndex]["content"] = merged
                } else {
                    result.append([
                        "role": "user",
                        "content": [block],
                    ])
                }
            }
        }

        return (systemPrompt, result)
    }

    private func formatAnthropicTools(_ tools: [ToolDefinition]) -> [[String: Any]] {
        tools.map { tool -> [String: Any] in
            [
                "name": tool.name,
                "description": tool.description,
                "input_schema": encodeToolParameters(tool.parameters),
            ]
        }
    }

    // MARK: - Auth

    /// OAuth tokens (sk-ant-oat) use Bearer auth with beta headers; regular API keys use x-api-key
    private func applyAnthropicAuth(to request: inout URLRequest) {
        if apiKey.hasPrefix("sk-ant-oat") {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            request.setValue("true", forHTTPHeaderField: "anthropic-dangerous-direct-browser-access")
        } else {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
    }

    // MARK: - Helpers

    private func encodeToolParameters(_ params: ToolParameters) -> [String: Any] {
        var props: [String: Any] = [:]
        for (key, prop) in params.properties {
            var p: [String: Any] = [
                "type": prop.type,
                "description": prop.description,
            ]
            if let enumVals = prop.enum {
                p["enum"] = enumVals
            }
            props[key] = p
        }
        var result: [String: Any] = [
            "type": params.type,
            "properties": props,
        ]
        if let required = params.required, !required.isEmpty {
            result["required"] = required
        }
        return result
    }
}
