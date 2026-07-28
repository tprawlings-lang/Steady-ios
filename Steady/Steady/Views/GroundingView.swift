import SwiftUI

/// Quick, always-available grounding tools — no session, no gating. A calm
/// place to land before or instead of processing.
struct GroundingView: View {
    @Environment(AppState.self) private var app
    @State private var breathPhase = "Breathe in…"
    @State private var breathing = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Settle your nervous system first. These are always open — no check-in needed.")
                            .font(.subheadline).foregroundStyle(Color.olive)

                        if !app.calmPlace.isEmpty {
                            SoftCard(background: Color.moss) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Your calm place").font(.caption).foregroundStyle(Color.olive)
                                    Text(app.calmPlace).serifTitle(28)
                                    Text("Bring it to mind. Notice the light, the sounds, the temperature.")
                                        .font(.subheadline).foregroundStyle(Color.ground.opacity(0.85))
                                }
                            }
                        }

                        breathCard

                        SoftCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("5-4-3-2-1").font(.headline)
                                grounding("5 things you can see")
                                grounding("4 things you can hear")
                                grounding("3 things you can touch")
                                grounding("2 things you can smell")
                                grounding("1 thing you can taste")
                            }
                        }

                        SoftCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Orient to now").font(.headline)
                                Text("Look around the room. Say where you are, today's date, and that you are here now. Press your feet into the floor.")
                                    .font(.subheadline).foregroundStyle(Color.ground.opacity(0.85))
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Ground")
        }
    }

    private var breathCard: some View {
        SoftCard(background: Color.ground) {
            VStack(spacing: 14) {
                Text(breathing ? breathPhase : "Longer out than in")
                    .font(.serifDisplay(26)).foregroundStyle(Color.ivory)
                Circle()
                    .fill(Color.sage.opacity(0.7))
                    .frame(width: breathing ? 150 : 80, height: breathing ? 150 : 80)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathing)
                Button(breathing ? "Stop" : "Start breathing") {
                    breathing.toggle()
                    if breathing { cycleBreath() }
                }
                .font(.subheadline.weight(.medium)).foregroundStyle(Color.ground)
                .padding(.horizontal, 20).padding(.vertical, 8)
                .background(Color.ivory, in: Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func cycleBreath() {
        guard breathing else { return }
        breathPhase = "Breathe in…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            guard breathing else { return }
            breathPhase = "Breathe out, slowly…"
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { cycleBreath() }
        }
    }

    private func grounding(_ t: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(Color.sage)
            Text(t).font(.system(size: 16)).foregroundStyle(Color.ground.opacity(0.9))
        }
    }
}
