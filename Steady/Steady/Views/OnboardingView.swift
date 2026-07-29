import SwiftUI

/// A short, gentle first-run flow: wellness-lane acknowledgment, preferred name,
/// calm-place word, and the photosensitivity (audio-only) preference. In
/// production this is where signup / consent / screening would live against the
/// backend; here it captures just what the on-device experience needs.
struct OnboardingView: View {
    @Environment(AppState.self) private var app
    @State private var page = 0
    @State private var name = ""
    @State private var calm = ""
    @State private var audioOnly = false
    @State private var acknowledged = false

    var body: some View {
        ZStack {
            ScreenBackground()
            TabView(selection: $page) {
                welcome.tag(0)
                research.tag(1)
                everyDay.tag(2)
                acknowledgment.tag(3)
                details.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "leaf.fill").font(.system(size: 46)).foregroundStyle(Color.sageDeep)
            Text("Steady").font(.serifDisplay(48)).foregroundStyle(Color.ground)
            Text("A calm, private, self-guided wellness program built on the EMDR method. Guided eye-movement sessions, daily breathwork, meditation, movement, and sleep practices, a companion that remembers what helps you, and safety rails a clinician would recognize.")
                .multilineTextAlignment(.center).foregroundStyle(Color.olive).padding(.horizontal, 28)
            Text("7 days of Premium free · from $6.99/month after · cancel anytime")
                .font(.footnote).foregroundStyle(Color.olive)
            Spacer()
            PrimaryButton(title: "Get started") { withAnimation { page = 1 } }.padding(.horizontal, 40)
            Spacer().frame(height: 40)
        }.padding()
    }

    /// Research band — the same three RCT/meta-analysis cards + citations as
    /// the web landing page. Claims are about the method, never this product.
    private var research: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Backed by randomized trials, not testimonials").serifTitle(28)
                Text(Marketing.guidelinesLine)
                    .font(.subheadline).foregroundStyle(Color.olive)
                ForEach(Marketing.researchStats) { s in
                    SoftCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(s.stat).font(.serifDisplay(30)).foregroundStyle(Color.ground)
                            Text(s.text).font(.subheadline).foregroundStyle(Color.olive)
                            if let url = URL(string: s.url) {
                                Link("Source: \(s.source)", destination: url)
                                    .font(.caption).foregroundStyle(Color.sageDeep)
                            }
                        }
                    }
                }
                Text(Marketing.researchCaveat)
                    .font(.caption).foregroundStyle(Color.olive)
                PrimaryButton(title: "Continue") { withAnimation { page = 2 } }
                    .padding(.top, 4)
            }
            .padding(24)
        }
    }

    /// The daily toolkit + Autopilot — the shipped-product story, mirroring
    /// the web's "Every day, not just sessions" and Autopilot sections.
    private var everyDay: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Every day, not just sessions").serifTitle(28)
                Text("Healing mostly happens between the big moments. Steady gives you a daily toolkit — and \(Marketing.titrationLine.lowercased())")
                    .font(.subheadline).foregroundStyle(Color.olive)
                ForEach(Marketing.dailyToolkit) { t in
                    SoftCard {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t.name).font(.serifDisplay(20)).foregroundStyle(Color.ground)
                            Text(t.note).font(.footnote).foregroundStyle(Color.olive)
                        }
                    }
                }
                SoftCard(background: Color.moss) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Premium · Autopilot").font(.caption).foregroundStyle(Color.olive)
                        Text(Marketing.autopilotHeadline).font(.serifDisplay(22)).foregroundStyle(Color.ground)
                        Text(Marketing.autopilotBody).font(.footnote).foregroundStyle(Color.ground.opacity(0.9))
                    }
                }
                Text(Marketing.safetyAlwaysOpenLine)
                    .font(.caption).foregroundStyle(Color.olive)
                PrimaryButton(title: "Continue") { withAnimation { page = 3 } }
                    .padding(.top, 4)
            }
            .padding(24)
        }
    }

    private var acknowledgment: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("Before we begin").serifTitle(30)
            SoftCard(background: Color.pauseSoft) {
                Text("Steady is a wellness program, not therapy or medical care — no diagnosis, no treatment claims. It is not monitored in real time and is not for emergencies. If you are ever in danger, call or text 988 or call 911.")
                    .font(.subheadline).foregroundStyle(Color.ground)
            }
            Toggle(isOn: $acknowledged) {
                Text("I'm 18 or older and I understand this is self-guided wellness, not emergency care.")
                    .font(.subheadline).foregroundStyle(Color.ground)
            }.tint(Color.sageDeep)
            Spacer()
            PrimaryButton(title: "Continue") { withAnimation { page = 4 } }
                .opacity(acknowledged ? 1 : 0.5).disabled(!acknowledged)
            Spacer().frame(height: 40)
        }.padding(24)
    }

    private var details: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("A few gentle basics").serifTitle(28)
                SoftCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What should Steady call you? (optional)").font(.subheadline.weight(.medium))
                        TextField("Your name", text: $name).textFieldStyle(.roundedBorder)
                    }
                }
                SoftCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your calm-place word (optional)").font(.subheadline.weight(.medium))
                        Text("One word for a place you feel settled — shore, pines, kitchen. Steady returns you to it when things get hard.")
                            .font(.caption).foregroundStyle(Color.olive)
                        TextField("e.g. shore", text: $calm).textFieldStyle(.roundedBorder)
                    }
                }
                SoftCard {
                    Toggle(isOn: $audioOnly) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use audio-only bilateral stimulation").font(.subheadline.weight(.medium))
                            Text("Gentler for photosensitivity — no moving dot. You can change this any time.")
                                .font(.caption).foregroundStyle(Color.olive)
                        }
                    }.tint(Color.sageDeep)
                }
                PrimaryButton(title: "Enter Steady") { finish() }
            }.padding(24)
        }
    }

    private func finish() {
        app.name = name.trimmingCharacters(in: .whitespaces)
        app.calmPlace = calm.trimmingCharacters(in: .whitespaces)
        app.audioOnlyDefault = audioOnly
        app.hasOnboarded = true
    }
}
