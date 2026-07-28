import SwiftUI

/// Steady brand kit — a native port of the web tokens in `globals.css`.
/// Palette names follow the brand guide: sage / ivory / sand / ground / mist /
/// clay / moss / linen / olive, plus the muted alert colors (support/pause/safe).
extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: Double
        if s.count == 6 {
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
        } else {
            r = 0; g = 0; b = 0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    static let sage      = Color(hex: "a8b8a1")
    static let sageDeep  = Color(hex: "93a58b")
    static let ivory     = Color(hex: "f7f1e8")
    static let sand      = Color(hex: "ded1be")
    static let ground    = Color(hex: "2f3a33")
    static let mist      = Color(hex: "a9bdc5")
    static let mistDeep  = Color(hex: "5c7884")
    static let clay      = Color(hex: "c9a98f")
    static let moss      = Color(hex: "dce4d4")
    static let linen     = Color(hex: "fbf8f2")
    static let olive     = Color(hex: "545e53")
    static let amberSoft = Color(hex: "e8c98a")
    static let support     = Color(hex: "9a4f42")
    static let supportDeep = Color(hex: "8a4335")
    static let pause     = Color(hex: "d7a85f")
    static let pauseSoft = Color(hex: "f3e4c8")
    static let safe      = Color(hex: "7fa37b")
    static let safeDeep  = Color(hex: "6d9069")
}

extension Font {
    /// Serif display face (stands in for Cormorant Garamond).
    static func serifDisplay(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

extension Text {
    /// Convenience for the serif headings used throughout the app.
    func serifTitle(_ size: CGFloat = 30) -> some View {
        self.font(.serifDisplay(size)).foregroundStyle(Color.ground)
    }
}

// MARK: - Reusable components

/// The soft rounded card used across the app (border + soft shadow on linen).
struct SoftCard<Content: View>: View {
    var background: Color = .linen
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.ground.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.ground.opacity(0.08), radius: 20, x: 0, y: 12)
    }
}

/// Primary action button — sage pill, ground text.
struct PrimaryButton: View {
    let title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.ground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.sage, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Secondary/outline button.
struct OutlineButton: View {
    let title: String
    var tint: Color = .ground
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(tint.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// The persistent, non-emergency honesty banner shown before/inside sessions.
struct NotForEmergenciesBanner: View {
    var body: some View {
        Text("**Not for emergencies.** Sessions are not monitored in real time. If you are in danger, call or text 988 or call 911.")
            .font(.footnote)
            .foregroundStyle(Color.ground)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pauseSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.pause.opacity(0.4), lineWidth: 1))
    }
}

/// App background wash.
struct ScreenBackground: View {
    var body: some View {
        LinearGradient(colors: [Color.ivory, Color.linen], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}
