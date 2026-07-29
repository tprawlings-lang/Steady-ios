import Foundation

/// Codable mirrors for the companion endpoints.

struct ChatMessageDTO: Codable, Identifiable, Equatable {
    var id = UUID()
    let sender: String        // "member" | "companion"
    let text: String
    let riskFlag: Bool

    private enum CodingKeys: String, CodingKey { case sender, text, riskFlag }
}

struct DailyChatResponse: Codable {
    let conversationId: String
    let messages: [ChatMessageDTO]
}

struct ConversationResponse: Codable {
    let conversationId: String?
    let messages: [ChatMessageDTO]
}

struct SendMessageResponse: Codable {
    let conversationId: String
    let reply: String
    let riskFlag: Bool
    let aiEnabled: Bool
    /// Earned membership suggestion (pricing Phase B). Optional so older
    /// servers still decode; shown as a distinct card, never companion speech.
    let suggestion: String?
}

struct MemoryItemDTO: Codable, Identifiable, Equatable {
    let id: String
    let type: String
    let key: String
    let value: String
}

struct MemoryListResponse: Codable {
    let enabled: String       // yes | no | ask
    let items: [MemoryItemDTO]
}
