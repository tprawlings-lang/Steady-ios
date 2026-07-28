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
                acknowledgment.tag(1)
                details.tag(2)
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
            Text("A calm, private, self-guided wellness program built on the EMDR method. Guided sessions, daily readiness check-ins, grounding tools, and safety rails a clinician would recognize.")
                .multilineTextAlignment(.center).foregroundStyle(Color.olive).padding(.horizontal, 28)
            Spacer()
            PrimaryButton(title: "Get started") { withAnimation { page = 1 } }.padding(.horizontal, 40)
            Spacer().frame(height: 40)
        }.padding()
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
            PrimaryButton(title: "Continue") { withAnimation { page = 2 } }
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
