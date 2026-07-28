import SwiftUI

/// The AI companion chat. Messages go to the backend, which runs deterministic
/// crisis detection first and then the Claude-backed companion (or the rules
/// engine when no key is configured) — the Anthropic key never touches the app.
/// Risk language routes straight to crisis resources.
struct CompanionView: View {
    @Environment(Backend.self) private var backend
    @State private var messages: [ChatMessageDTO] = []
    @State private var conversationId: String?
    @State private var input = ""
    @State private var sending = false
    @State private var loaded = false
    @State private var showCrisis = false
    @State private var showMemory = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                if !backend.isAuthenticated {
                    signedOut
                } else {
                    chat
                }
            }
            .navigationTitle("Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if backend.isAuthenticated {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showCrisis = true } label: { Text("Help").foregroundStyle(Color.support) }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showMemory = true } label: { Image(systemName: "brain") }
                    }
                }
            }
            .sheet(isPresented: $showCrisis) { NavigationStack { CrisisView() } }
            .sheet(isPresented: $showMemory) { MemoryView() }
        }
        .task { if backend.isAuthenticated && !loaded { await load() } }
    }

    private var signedOut: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 40)).foregroundStyle(Color.sageDeep)
            Text("Your companion lives in your account").serifTitle(22)
            Text("Sign in from Settings to chat with a companion that remembers what helps you.")
                .font(.subheadline).foregroundStyle(Color.olive).multilineTextAlignment(.center)
        }.padding(40)
    }

    private var chat: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if messages.isEmpty && loaded {
                            Text("Say hello, or tell your companion how today is going.")
                                .font(.subheadline).foregroundStyle(Color.olive)
                                .frame(maxWidth: .infinity).padding(.top, 40)
                        }
                        ForEach(messages) { m in bubble(m) }
                        if sending {
                            HStack { ProgressView().padding(.leading, 8); Spacer() }
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
            if let error { Text(error).font(.caption).foregroundStyle(Color.support).padding(.horizontal) }
            inputBar
        }
    }

    private func bubble(_ m: ChatMessageDTO) -> some View {
        let mine = m.sender == "member"
        return HStack {
            if mine { Spacer(minLength: 40) }
            Text(m.text)
                .font(.system(size: 16))
                .foregroundStyle(mine ? Color.ground : Color.ground.opacity(0.95))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(mine ? Color.sage.opacity(0.5) : (m.riskFlag ? Color.pauseSoft : Color.linen),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.ground.opacity(0.08)))
            if !mine { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Color.linen, in: Capsule())
                .overlay(Capsule().stroke(Color.ground.opacity(0.12)))
            Button { Task { await send() } } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 30))
                    .foregroundStyle(canSend ? Color.sageDeep : Color.olive.opacity(0.4))
            }.disabled(!canSend)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool { !input.trimmingCharacters(in: .whitespaces).isEmpty && !sending }

    private func load() async {
        loaded = true
        do {
            let conv = try await backend.companionConversation()
            conversationId = conv.conversationId
            messages = conv.messages
        } catch { /* start fresh silently */ }
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        input = ""; error = nil
        messages.append(ChatMessageDTO(sender: "member", text: text, riskFlag: false))
        sending = true; defer { sending = false }
        do {
            let res = try await backend.sendCompanionMessage(conversationId: conversationId, text: text)
            conversationId = res.conversationId
            messages.append(ChatMessageDTO(sender: "companion", text: res.reply, riskFlag: res.riskFlag))
            if res.riskFlag { showCrisis = true }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Message didn't send. Try again."
        }
    }
}

/// Member-controlled companion memory: what it remembers, on/off, and delete.
struct MemoryView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.dismiss) private var dismiss
    @State private var mem: MemoryListResponse?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                Form {
                    Section {
                        Text("Your companion can remember what grounds you, your triggers, and where you left off — always yours to view, edit, or delete.")
                            .font(.caption).foregroundStyle(Color.olive)
                        Picker("Memory", selection: Binding(
                            get: { mem?.enabled ?? "yes" },
                            set: { v in Task { @MainActor in await act("toggle", enabled: v) } })) {
                            Text("On").tag("yes")
                            Text("Ask each time").tag("ask")
                            Text("Off").tag("no")
                        }
                    } header: { Text("Companion memory") }

                    if let items = mem?.items, !items.isEmpty {
                        Section("What it remembers (\(items.count))") {
                            ForEach(items) { item in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.key).font(.subheadline.weight(.medium))
                                    Text(item.value).font(.caption).foregroundStyle(Color.olive)
                                }
                                .swipeActions {
                                    Button(role: .destructive) { Task { await act("delete", itemId: item.id) } } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                            Button(role: .destructive) { Task { await act("clear") } } label: { Text("Forget everything") }
                        }
                    } else if mem != nil {
                        Section { Text("Nothing remembered yet.").font(.subheadline).foregroundStyle(Color.olive) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .task { await reload() }
    }

    private func reload() async { mem = try? await backend.getMemory() }
    private func act(_ action: String, enabled: String? = nil, itemId: String? = nil) async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        mem = try? await backend.memoryAction(action, enabled: enabled, itemId: itemId)
    }
}
