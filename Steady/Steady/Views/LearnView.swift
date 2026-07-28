import SwiftUI

/// Psychoeducation library + reader (roadmap F11). Backend-served lessons with
/// read progress; reached from the Dashboard (inside its NavigationStack).
struct LearnView: View {
    @Environment(Backend.self) private var backend
    @State private var lessons: [LessonDTO] = []
    @State private var read: Set<String> = []
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Learn").serifTitle(34)
                Text("A few short reads to make sense of what you're working with — the window of tolerance, why the method works, understanding triggers. Two to four minutes each.")
                    .foregroundStyle(Color.olive)
                Text("\(read.count) of \(lessons.count) read")
                    .font(.subheadline).foregroundStyle(Color.olive)
                if let loadError { Text(loadError).font(.footnote).foregroundStyle(Color.support) }
                ForEach(lessons) { l in
                    NavigationLink {
                        LessonReaderView(lesson: l).onAppear { markRead(l) }
                    } label: {
                        SoftCard {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(l.title).font(.serifDisplay(22)).foregroundStyle(Color.ground)
                                    Spacer()
                                    Text(read.contains(l.id) ? "✓ read" : "\(l.readMinutes) min")
                                        .font(.caption).foregroundStyle(Color.olive)
                                }
                                Text(l.summary).font(.subheadline).foregroundStyle(Color.olive)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(ScreenBackground())
        .navigationTitle("Learn")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do {
            let r = try await backend.getLessons()
            lessons = r.lessons
            read = Set(r.read)
        } catch {
            loadError = "Couldn't load lessons."
        }
    }

    private func markRead(_ l: LessonDTO) {
        read.insert(l.id)
        Task { await backend.markLessonRead(lessonId: l.id) }
    }
}

struct LessonReaderView: View {
    let lesson: LessonDTO
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(lesson.title).serifTitle(30)
                Text("\(lesson.readMinutes) min read").font(.caption).foregroundStyle(Color.olive)
                LessonBodyView(markdown: lesson.body)
                Text("Educational information, not medical advice or a diagnosis. If you're in crisis, the Ground tab and crisis resources can help now.")
                    .font(.caption2).foregroundStyle(Color.olive).padding(.top, 8)
            }
            .padding(20)
        }
        .background(ScreenBackground())
    }
}

/// Minimal renderer for our lesson markdown subset (## headings, paragraphs,
/// - bullets, **bold**/*italic* inline).
struct LessonBodyView: View {
    let markdown: String

    private enum Block: Hashable { case h2(String), p(String), ul([String]) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(parse().enumerated()), id: \.offset) { _, block in
                switch block {
                case .h2(let t):
                    Text(inline(t)).font(.serifDisplay(20)).foregroundStyle(Color.ground)
                case .p(let t):
                    Text(inline(t)).foregroundStyle(Color.ground.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .ul(let items):
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(items, id: \.self) { it in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•").foregroundStyle(Color.sageDeep)
                                Text(inline(it)).foregroundStyle(Color.ground.opacity(0.9))
                            }
                        }
                    }
                }
            }
        }
    }

    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s)) ?? AttributedString(s)
    }

    private func parse() -> [Block] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [Block] = []
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { i += 1; continue }
            if line.hasPrefix("## ") {
                blocks.append(.h2(String(line.dropFirst(3))))
                i += 1
            } else if line.hasPrefix("- ") {
                var items: [String] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("- ") {
                    items.append(String(lines[i].trimmingCharacters(in: .whitespaces).dropFirst(2)))
                    i += 1
                }
                blocks.append(.ul(items))
            } else {
                var para: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if l.isEmpty || l.hasPrefix("## ") || l.hasPrefix("- ") { break }
                    para.append(l)
                    i += 1
                }
                blocks.append(.p(para.joined(separator: " ")))
            }
        }
        return blocks
    }
}
