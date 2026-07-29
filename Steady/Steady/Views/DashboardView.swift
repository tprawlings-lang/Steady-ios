import SwiftUI
import SwiftData

/// The member's home: a warm greeting, today's check-in prompt, the module
/// program, and a distress trend across recent sessions.
struct DashboardView: View {
    @Environment(AppState.self) private var app
    @Environment(Backend.self) private var backend
    @Query(sort: \SessionRecord.startedAt, order: .reverse) private var sessions: [SessionRecord]
    @Query(sort: \CheckinRecord.date, order: .reverse) private var checkins: [CheckinRecord]
    @State private var autopilot: AutopilotPlanDTO?

    private func available(_ module: TherapyModule) -> Bool {
        backend.serverAllows(module.id) ?? app.isModuleAvailable(module)
    }

    private var modulesByOrder: [TherapyModule] { ModuleCatalog.all.sorted { $0.order < $1.order } }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        checkinCard
                        if let autopilot { autopilotCard(autopilot) }
                        breatheCard
                        meditateCard
                        moveCard
                        sleepCard
                        learnCard
                        if !sessions.isEmpty { trendCard }
                        programSection
                        Text("Steady is a self-guided wellness program built on the EMDR method — not therapy, not medical care. Not for emergencies.")
                            .font(.caption2).foregroundStyle(Color.olive)
                            .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Steady")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: backend.gating?.tier) {
                // Autopilot is Premium-only; the server returns null otherwise.
                if backend.isAuthenticated, backend.gating?.tier == "premium" {
                    autopilot = try? await backend.getAutopilotToday()
                } else {
                    autopilot = nil
                }
            }
        }
    }

    // MARK: - Autopilot (Premium)

    private func autopilotCard(_ plan: AutopilotPlanDTO) -> some View {
        SoftCard(background: Color.moss) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Autopilot · today's plan").font(.caption).foregroundStyle(Color.olive)
                        Text(plan.headline).font(.serifDisplay(22)).foregroundStyle(Color.ground)
                    }
                    Spacer()
                    Text(plan.date).font(.caption2).foregroundStyle(Color.olive)
                }
                if let outreach = plan.outreach {
                    Text(outreach)
                        .font(.footnote).foregroundStyle(Color.ground.opacity(0.9))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.ivory.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                }
                ForEach(plan.items, id: \.self) { item in
                    autopilotRow(item)
                }
                if let note = plan.pacingNote {
                    Text(note).font(.caption2).foregroundStyle(Color.olive)
                }
            }
        }
    }

    @ViewBuilder private func autopilotRow(_ item: AutopilotItemDTO) -> some View {
        NavigationLink {
            autopilotDestination(item)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.ground)
                    Text(item.detail).font(.caption).foregroundStyle(Color.olive)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.olive).padding(.top, 4)
            }
            .padding(12)
            .background(Color.linen, in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
    }

    /// Map a plan item to its native screen (hrefs are the web's routes).
    @ViewBuilder private func autopilotDestination(_ item: AutopilotItemDTO) -> some View {
        switch item.kind {
        case "checkin":
            CheckinView()
        case "practice":
            if item.href.contains("meditate") { MeditateView() }
            else if item.href.contains("sleep") { MeditateView(copy: .sleep) }
            else if item.href.contains("move") { MeditateView(copy: .movement) }
            else { BreatheView() }
        case "session":
            if let module = ModuleCatalog.all.first(where: { item.href.hasSuffix("/\($0.id)") }) {
                ModuleDetailView(module: module)
            } else {
                GroundingView()
            }
        case "lesson":
            LearnView()
        default:
            GroundingView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting).font(.caption).foregroundStyle(Color.olive)
            Text(app.name.isEmpty ? "Welcome back" : "Hello, \(app.name)").serifTitle(30)
        }
    }

    private var breatheCard: some View {
        NavigationLink {
            BreatheView()
        } label: {
            SoftCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prepare & regulate").font(.caption).foregroundStyle(Color.olive)
                    Text("Breathe").font(.serifDisplay(24)).foregroundStyle(Color.ground)
                    Text("A few minutes of paced breathing to settle — before a session, or any time.")
                        .font(.subheadline).foregroundStyle(Color.olive)
                }
            }
        }.buttonStyle(.plain)
    }

    private var meditateCard: some View {
        NavigationLink {
            MeditateView()
        } label: {
            SoftCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prepare & regulate").font(.caption).foregroundStyle(Color.olive)
                    Text("Meditate").font(.serifDisplay(24)).foregroundStyle(Color.ground)
                    Text("Short guided practices — grounding, calm-place, self-compassion. Read aloud or as text.")
                        .font(.subheadline).foregroundStyle(Color.olive)
                }
            }
        }.buttonStyle(.plain)
    }

    private var moveCard: some View {
        NavigationLink {
            MeditateView(copy: .movement)
        } label: {
            SoftCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prepare & regulate").font(.caption).foregroundStyle(Color.olive)
                    Text("Move").font(.serifDisplay(24)).foregroundStyle(Color.ground)
                    Text("Gentle guided movement — orienting turns, rooting down, easy stretches, shaking it off.")
                        .font(.subheadline).foregroundStyle(Color.olive)
                }
            }
        }.buttonStyle(.plain)
    }

    private var sleepCard: some View {
        NavigationLink {
            MeditateView(copy: .sleep)
        } label: {
            SoftCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wind down").font(.caption).foregroundStyle(Color.olive)
                    Text("Sleep").font(.serifDisplay(24)).foregroundStyle(Color.ground)
                    Text("Guided wind-downs to do lying down — slow breathing, melting into rest, putting the day down.")
                        .font(.subheadline).foregroundStyle(Color.olive)
                }
            }
        }.buttonStyle(.plain)
    }

    private var learnCard: some View {
        NavigationLink {
            LearnView()
        } label: {
            SoftCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Understand the method").font(.caption).foregroundStyle(Color.olive)
                    Text("Learn").font(.serifDisplay(24)).foregroundStyle(Color.ground)
                    Text("Short, trauma-informed reads — the window of tolerance, why it works, understanding triggers.")
                        .font(.subheadline).foregroundStyle(Color.olive)
                }
            }
        }.buttonStyle(.plain)
    }

    private var checkinCard: some View {
        SoftCard(background: Color.moss) {
            VStack(alignment: .leading, spacing: 8) {
                if let latest = checkins.first, Calendar.current.isDateInToday(latest.date),
                   let action = RecommendedAction(rawValue: latest.action) {
                    Text("Today's check-in").font(.caption).foregroundStyle(Color.olive)
                    Text(action.headline).font(.headline).foregroundStyle(Color.ground)
                    Text(action.detail).font(.subheadline).foregroundStyle(Color.ground.opacity(0.85))
                } else {
                    Text("Start with a check-in").font(.headline).foregroundStyle(Color.ground)
                    Text("90 seconds. It decides what's safe to do today.")
                        .font(.subheadline).foregroundStyle(Color.ground.opacity(0.85))
                }
            }
        }
    }

    private var trendCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Distress across recent sessions").font(.headline)
                SudsTrendChart(sessions: Array(sessions.prefix(10)).reversed())
                    .frame(height: 90)
                Text("Lower is calmer. Each point is a session's ending distress rating.")
                    .font(.caption).foregroundStyle(Color.olive)
            }
        }
    }

    private var programSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your program").font(.headline).foregroundStyle(Color.ground)
            ForEach(modulesByOrder) { module in
                NavigationLink {
                    ModuleDetailView(module: module)
                } label: {
                    moduleRow(module)
                }.buttonStyle(.plain)
            }
        }
    }

    private func moduleRow(_ module: TherapyModule) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.sage.opacity(0.25)).frame(width: 40, height: 40)
                Text("\(module.order)").font(.subheadline.weight(.semibold)).foregroundStyle(Color.sageDeep)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(module.name).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.ground)
                Text(module.objective).font(.caption).foregroundStyle(Color.olive).lineLimit(1)
            }
            Spacer()
            if available(module) {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.olive)
            } else {
                Image(systemName: "lock.fill").font(.caption).foregroundStyle(Color.mistDeep)
            }
        }
        .padding(14)
        .background(Color.linen, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.ground.opacity(0.08)))
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

/// Minimal line chart of ending SUDS per session (0–10), no dependencies.
struct SudsTrendChart: View {
    let sessions: [SessionRecord]
    var body: some View {
        GeometryReader { geo in
            let points = sessions.compactMap { $0.postSuds }
            let w = geo.size.width, h = geo.size.height
            if points.count < 2 {
                Text("Complete a couple of sessions to see your trend.")
                    .font(.caption).foregroundStyle(Color.olive)
            } else {
                let maxV = 10.0
                let step = points.count > 1 ? w / CGFloat(points.count - 1) : w
                ZStack {
                    Path { p in
                        for (i, v) in points.enumerated() {
                            let x = CGFloat(i) * step
                            let y = h - (CGFloat(v) / maxV) * h
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                            else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }.stroke(Color.sageDeep, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    ForEach(Array(points.enumerated()), id: \.offset) { i, v in
                        let x = CGFloat(i) * step
                        let y = h - (CGFloat(v) / maxV) * h
                        Circle().fill(Color.sageDeep).frame(width: 6, height: 6).position(x: x, y: y)
                    }
                }
            }
        }
    }
}
