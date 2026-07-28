import Foundation

/// Codable mirror of the lessons API (/api/mobile/v1/lessons).
struct LessonDTO: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let readMinutes: Int
    let tags: [String]
    let relatedModuleIds: [String]
    let body: String
}

struct LessonsResponse: Codable {
    let lessons: [LessonDTO]
    let read: [String]
}
