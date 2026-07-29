import SwiftUI

/// Create a new member account against the shared backend (18+ age gate +
/// wellness-lane acknowledgment), mirroring the web signup.
struct SignupView: View {
    @Environment(Backend.self) private var backend
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var server = ""
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var dob = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var ack = false
    @State private var busy = false
    @State private var error: String?

    private var dobString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: dob)
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create your account").serifTitle(30)
                    Text("Steady is a self-guided wellness program for adults, built on the EMDR method. Not therapy, not medical care, not for emergencies.")
                        .font(.subheadline).foregroundStyle(Color.olive)

                    // Tier preview — mirrors the web signup's ladder; the full
                    // picker is the next step (SubscribeView).
                    VStack(spacing: 8) {
                        ForEach(Marketing.tiers) { tier in
                            HStack(alignment: .firstTextBaseline) {
                                Text(tier.name).font(.serifDisplay(18)).foregroundStyle(Color.ground)
                                Text(tier.tagline).font(.caption).foregroundStyle(Color.olive)
                                Spacer()
                                Text(tier.price).font(.footnote.weight(.semibold)).foregroundStyle(Color.ground)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Color.linen, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ground.opacity(0.08)))
                        }
                        Text(Marketing.trialLine)
                            .font(.caption).foregroundStyle(Color.olive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SoftCard {
                        VStack(alignment: .leading, spacing: 12) {
                            if !backend.isConfigured {
                                field("Server URL", "https://your-steady.example.com", $server, url: true)
                            }
                            field("Name", "Your name", $name)
                            field("Email", "you@example.com", $email, email: true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Date of birth").font(.subheadline.weight(.medium))
                                DatePicker("", selection: $dob, in: ...Date(), displayedComponents: .date)
                                    .labelsHidden().datePickerStyle(.compact)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Password").font(.subheadline.weight(.medium))
                                SecureField("At least 8 characters", text: $password).textFieldStyle(.roundedBorder)
                            }
                        }
                    }

                    SoftCard(background: Color.pauseSoft) {
                        Toggle(isOn: $ack) {
                            Text("I'm 18 or older and I understand Steady is self-guided wellness, not therapy or emergency care.")
                                .font(.subheadline).foregroundStyle(Color.ground)
                        }.tint(Color.sageDeep)
                    }

                    if let error { Text(error).font(.subheadline).foregroundStyle(Color.support) }

                    PrimaryButton(title: busy ? "Creating…" : "Create account") { Task { await submit() } }
                        .disabled(busy)
                    OutlineButton(title: "I already have an account") { dismiss() }
                }
                .padding(24)
            }
        }
        .onAppear { server = backend.baseURLString }
    }

    private func field(_ label: String, _ ph: String, _ b: Binding<String>, email: Bool = false, url: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline.weight(.medium))
            TextField(ph, text: b)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(email || url ? .never : .words)
                .autocorrectionDisabled(email || url)
                .keyboardType(email ? .emailAddress : (url ? .URL : .default))
        }
    }

    private func submit() async {
        error = nil
        if !backend.isConfigured {
            let u = server.trimmingCharacters(in: .whitespaces)
            guard URL(string: u)?.scheme != nil else { error = "Enter a valid server URL."; return }
            backend.baseURLString = u
        }
        guard ack else { error = "Please acknowledge the wellness-lane terms."; return }
        busy = true; defer { busy = false }
        do {
            try await backend.signup(name: name.trimmingCharacters(in: .whitespaces),
                                     email: email.trimmingCharacters(in: .whitespaces),
                                     password: password, dob: dobString, wellnessAck: ack)
            if app.name.isEmpty { app.name = name.trimmingCharacters(in: .whitespaces) }
            app.hasOnboarded = true
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Could not create your account."
        }
    }
}
