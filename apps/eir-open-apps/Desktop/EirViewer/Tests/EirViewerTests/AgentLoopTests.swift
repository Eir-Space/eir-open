import XCTest
@testable import EirViewer

// MARK: - Conversation History Reconstruction Tests
//
// These tests verify that when building LLM messages from stored conversation
// history, tool messages are merged into the preceding assistant message as
// plain text. This keeps tool results (e.g. medical records) in context for
// follow-up turns, while avoiding Anthropic API errors from orphaned
// tool_result blocks.

final class ConversationHistoryTests: XCTestCase {

    // MARK: - Core: Tool Results Merged Into Assistant

    /// Tool results should be merged into the preceding assistant message
    /// so the data persists in context for follow-up questions
    func testToolResultsMergedIntoAssistantMessage() {
        let messages: [ChatMessage] = [
            ChatMessage(role: .user, content: "Find dental notes"),
            ChatMessage(role: .assistant, content: "Let me look that up."),
            ChatMessage(role: .tool, content: "Found 18 dental records for Birger...", toolCallId: "toolu_abc"),
            ChatMessage(role: .user, content: "Tell me about the most recent one"),
            ChatMessage(role: .assistant, content: ""), // Current turn
        ]

        let history = buildLLMHistory(from: messages, systemPrompt: "System")

        // system + user + assistant(with merged tool) + user = 4
        XCTAssertEqual(history.count, 4)

        // No raw tool_result blocks
        for msg in history {
            if case .toolResult = msg {
                XCTFail("History must not contain tool_result — they should be merged into assistant")
            }
        }

        // The assistant message should contain both the original text AND the tool result
        if case .assistant(let content) = history[2] {
            XCTAssertTrue(content.contains("Let me look that up."), "Should contain original assistant text")
            XCTAssertTrue(content.contains("Found 18 dental records"), "Should contain merged tool result")
        } else {
            XCTFail("Expected assistant message at index 2")
        }
    }

    /// Assistant messages with toolCalls should be replayed as plain text
    func testHistoryStripsToolCallsFromAssistantMessages() {
        var assistantMsg = ChatMessage(role: .assistant, content: "I searched your records and found...")
        assistantMsg.toolCalls = [ToolCall(id: "toolu_xyz", name: "get_medical_records", arguments: "{}")]

        let messages: [ChatMessage] = [
            ChatMessage(role: .user, content: "Get records"),
            assistantMsg,
            ChatMessage(role: .tool, content: "All records...", toolCallId: "toolu_xyz"),
            ChatMessage(role: .user, content: "Thanks"),
            ChatMessage(role: .assistant, content: ""),
        ]

        let history = buildLLMHistory(from: messages, systemPrompt: "System")

        for msg in history {
            if case .assistantToolCalls = msg {
                XCTFail("History must not contain assistantToolCalls — they cause API errors on replay")
            }
        }
    }

    // MARK: - Simple Conversation (No Tools)

    func testHistoryPreservesSimpleConversation() {
        let messages: [ChatMessage] = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi there!"),
            ChatMessage(role: .user, content: "How are you?"),
            ChatMessage(role: .assistant, content: ""), // Current turn
        ]

        let history = buildLLMHistory(from: messages, systemPrompt: "System prompt")

        // system + user + assistant + user = 4
        XCTAssertEqual(history.count, 4)

        if case .system(let prompt) = history[0] {
            XCTAssertEqual(prompt, "System prompt")
        } else {
            XCTFail("First message should be system prompt")
        }

        if case .user(let c) = history[1] { XCTAssertEqual(c, "Hello") } else { XCTFail("Expected user") }
        if case .assistant(let c) = history[2] { XCTAssertEqual(c, "Hi there!") } else { XCTFail("Expected assistant") }
        if case .user(let c) = history[3] { XCTAssertEqual(c, "How are you?") } else { XCTFail("Expected user") }
    }

    // MARK: - Multiple Tool Results Merge

    /// Multiple tool results after one assistant message should all merge in
    func testMultipleToolResultsMergeIntoSameAssistant() {
        let messages: [ChatMessage] = [
            ChatMessage(role: .user, content: "Get all records"),
            ChatMessage(role: .assistant, content: "Fetching records for everyone."),
            ChatMessage(role: .tool, content: "Birger: 131 entries...", toolCallId: "t1"),
            ChatMessage(role: .tool, content: "Hedda: 45 entries...", toolCallId: "t2"),
            ChatMessage(role: .user, content: "Compare them"),
            ChatMessage(role: .assistant, content: ""),
        ]

        let history = buildLLMHistory(from: messages, systemPrompt: "S")

        // system + user + assistant(merged) + user = 4
        XCTAssertEqual(history.count, 4)

        if case .assistant(let content) = history[2] {
            XCTAssertTrue(content.contains("Fetching records"))
            XCTAssertTrue(content.contains("Birger: 131 entries"))
            XCTAssertTrue(content.contains("Hedda: 45 entries"))
        } else {
            XCTFail("Expected merged assistant message")
        }
    }

    // MARK: - Edge Cases

    func testHistoryFromEmptyConversation() {
        let messages: [ChatMessage] = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: ""),
        ]

        let history = buildLLMHistory(from: messages, systemPrompt: "S")

        XCTAssertEqual(history.count, 2) // system + user
        if case .system = history[0] {} else { XCTFail("Expected system") }
        if case .user(let c) = history[1] { XCTAssertEqual(c, "Hello") } else { XCTFail("Expected user") }
    }

    func testHistoryIgnoresStoredSystemMessages() {
        let messages: [ChatMessage] = [
            ChatMessage(role: .system, content: "Old system prompt"),
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: ""),
        ]

        let history = buildLLMHistory(from: messages, systemPrompt: "New system prompt")

        XCTAssertEqual(history.count, 2)
        if case .system(let prompt) = history[0] {
            XCTAssertEqual(prompt, "New system prompt")
        }
    }

    /// Records from a tool call should persist through multiple follow-up turns
    func testToolResultsPersistAcrossMultipleFollowUps() {
        let messages: [ChatMessage] = [
            // Turn 1: fetch records
            ChatMessage(role: .user, content: "Get my records"),
            ChatMessage(role: .assistant, content: "Here they are."),
            ChatMessage(role: .tool, content: "FULL RECORDS: entry_001 dental...", toolCallId: "t1"),
            // Turn 2: follow-up
            ChatMessage(role: .user, content: "What about dental?"),
            ChatMessage(role: .assistant, content: "You have 7 dental entries."),
            // Turn 3: another follow-up
            ChatMessage(role: .user, content: "And vaccines?"),
            ChatMessage(role: .assistant, content: ""), // Current
        ]

        let history = buildLLMHistory(from: messages, systemPrompt: "S")

        // system + user + assistant(merged) + user + assistant + user = 6
        XCTAssertEqual(history.count, 6)

        // The merged assistant message (index 2) should contain the records
        if case .assistant(let content) = history[2] {
            XCTAssertTrue(content.contains("FULL RECORDS"), "Records should persist in history")
        } else {
            XCTFail("Expected assistant with merged records")
        }
    }

    // MARK: - Helper

    private func buildLLMHistory(from messages: [ChatMessage], systemPrompt: String) -> [LLMMessage] {
        return ChatViewModel.buildLLMHistory(from: messages, systemPrompt: systemPrompt)
    }
}
