import SwiftUI

/// SOS panic button (roadmap F7). A persistent red button overlaid on every
/// tab; one tap opens immediate, member-initiated relief — a paced breath,
/// the member's own calm place, a one-tap call to the person they named, and
/// the crisis line. Mirrors the web SosButton. Distinct from CrisisView, which
/// is the escalation the safety gate forces; this is relief the member reaches
/// for. Opening it records a coded safety event server-side.
struct SosFloatingButton: View {
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            Text("SOS")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.support, in: Circle())
                .shadow(color: Color.black.opacity(0.2), radius: 6, y: 3)
        }
        .accessibilityLabel("Open immediate support")
        .fullScreenCover(isPresented: $show) { SosPanelView() }
    }
}

struct SosPanelView: View {
    @Environment(Backend.self) private var backend
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var panel: SosPanelDTO?
    @State private var phaseIn = true
    private let breath = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("You're not alone").serifTitle(30)
                        Spacer()
                        Button("Close") { dismiss() }
                            .foregroundStyle(Color.ground)
                    }
                    Text("Let's slow things down together. One breath at a time.")
                        .foregroundStyle(Color.olive)

                    breathCircle

                    if let phrase = reminderPhrase {
                        VStack(spacing: 6) {
                            Text("You asked Steady to remind you:").font(.caption).foregroundStyle(Color.olive)
                            Text("\u{201C}\(phrase)\u{201D}").font(.serifDisplay(22)).foregroundStyle(Color.ground)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(18)
                        .background(Color.moss, in: RoundedRectangle(cornerRadius: 22))
                    }

                    if let place = calmPlace {
                        SoftCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Your calm place").font(.headline).foregroundStyle(Color.ground)
                                Text(place).foregroundStyle(Color.ground.opacity(0.9))
                            }
                        }
                    }

                    if !groundingTools.isEmpty {
                        SoftCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("What has helped you before").font(.headline).foregroundStyle(Color.ground)
                                FlowChips(items: groundingTools)
                            }
                        }
                    }

                    actions

                    Text("Steady is not emergency care and this panel is not monitored. If you're in immediate danger, call 911 or your local emergency number.")
                        .font(.caption2).foregroundStyle(Color.olive)
                        .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .task {
            await backend.recordSosOpened()
            panel = try? await backend.getSos()
        }
    }

    private var breathCircle: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(Color.sage.opacity(0.45))
                .frame(width: phaseIn ? 190 : 120, height: phaseIn ? 190 : 120)
                .overlay(
                    Text(phaseIn ? "Breathe in" : "Breathe out")
                        .font(.serifDisplay(22)).foregroundStyle(Color.sageDeep)
                )
                .frame(maxWidth: .infinity)
            Text("In through the nose, slow out through the mouth.")
                .font(.footnote).foregroundStyle(Color.olive)
        }
        .padding(.vertical, 8)
        .onReceive(breath) { _ in withAnimation(.easeInOut(duration: 5)) { phaseIn.toggle() } }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if let name = supportContactName, let href = contactURL {
                Button { openURL(href) } label: {
                    Text("Reach \(name)")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.ground)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.sage, in: RoundedRectangle(cornerRadius: 22))
                }.buttonStyle(.plain)
            } else if let name = supportContactName {
                VStack(spacing: 2) {
                    Text("Your safe person").font(.caption).foregroundStyle(Color.olive)
                    Text(name).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.ground)
                    if let m = supportContactMethod { Text(m).font(.footnote).foregroundStyle(Color.olive) }
                }
                .frame(maxWidth: .infinity).padding(16)
                .background(Color.linen, in: RoundedRectangle(cornerRadius: 22))
            }

            Button { open(crisisHref) } label: {
                Text("\(crisisLabel) (US)")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.support, in: RoundedRectangle(cornerRadius: 22))
            }.buttonStyle(.plain)

            Button { open("tel:911") } label: {
                Text("Call 911 (immediate danger)")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.support)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.support, lineWidth: 2))
            }.buttonStyle(.plain)
        }
    }

    // MARK: - Derived values (panel, then account fallbacks)

    private var calmPlace: String? {
        if let p = panel?.calmPlace, !p.isEmpty { return p }
        return app.calmPlace.isEmpty ? nil : app.calmPlace
    }
    private var reminderPhrase: String? { nonEmpty(panel?.reminderPhrase) }
    private var groundingTools: [String] { panel?.groundingTools ?? [] }
    private var supportContactName: String? { nonEmpty(panel?.supportContactName) }
    private var supportContactMethod: String? { nonEmpty(panel?.supportContactMethod) }
    private var crisisLabel: String { nonEmpty(panel?.crisisLabel) ?? "988 Suicide & Crisis Lifeline" }
    private var crisisHref: String { nonEmpty(panel?.crisisHref) ?? "tel:988" }

    private var contactURL: URL? {
        guard let m = supportContactMethod?.trimmingCharacters(in: .whitespaces), !m.isEmpty else { return nil }
        if m.contains("@") && !m.contains(" ") { return URL(string: "mailto:\(m)") }
        let digits = m.filter { $0.isNumber || $0 == "+" }
        if digits.filter(\.isNumber).count >= 7 { return URL(string: "tel:\(digits)") }
        return nil
    }

    private func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return s
    }
    private func open(_ href: String) {
        guard let url = URL(string: href) else { return }
        openURL(url)
    }
}

/// Simple wrapping chip row for grounding tools.
struct FlowChips: View {
    let items: [String]
    var body: some View {
        // A lightweight wrap: vertical stack of horizontally-scrolling rows is
        // overkill; use a flexible HStack that wraps via fixed-size chips.
        WrapHStack(items: items) { t in
            Text(t)
                .font(.footnote)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Color.sage.opacity(0.3), in: Capsule())
                .foregroundStyle(Color.ground)
        }
    }
}

/// Minimal flow layout (iOS 16+): wraps chips to the next line as width runs out.
struct WrapHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { content($0) }
        }
    }
}

/// A tiny Layout that arranges subviews left-to-right, wrapping as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x - bounds.minX + size.width > maxWidth, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
