import SwiftUI

struct ChatView: View {

    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var workoutsVM: WorkoutsViewModel
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            Group {
                if let conv = chatVM.activeConversation {
                    ConversationView(conversation: conv)
                } else {
                    welcomeScreen
                }
            }
            .navigationTitle("Coach Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        chatVM.newConversation(workouts: workoutsVM.workouts)
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                ConversationHistorySheet()
            }
        }
    }

    private var welcomeScreen: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.blue.gradient)
                    Text("Frag deinen Coach")
                        .font(.title2).fontWeight(.bold)
                    Text("Stelle Fragen zu Training, Ernährung, Planung oder deiner Leistung. Claude kennt deine Trainingsdaten.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Schnellzugriff")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(QuickPrompt.suggestions) { prompt in
                            QuickPromptButton(prompt: prompt) {
                                chatVM.newConversation(workouts: workoutsVM.workouts)
                                Task {
                                    await chatVM.send(quickPrompt: prompt, workouts: workoutsVM.workouts)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Aktive Konversation

struct ConversationView: View {

    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var workoutsVM: WorkoutsViewModel
    let conversation: Conversation

    @FocusState private var inputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            // Nachrichtenliste
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if conversation.messages.isEmpty {
                            quickPromptsInline
                        }
                        ForEach(conversation.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                        if chatVM.isTyping {
                            TypingIndicator()
                                .id("typing")
                        }
                        if let err = chatVM.error {
                            ErrorBanner(message: err)
                        }
                    }
                    .padding()
                }
                .onAppear { scrollProxy = proxy }
                .onChange(of: conversation.messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: chatVM.isTyping) { _, typing in
                    if typing { scrollToBottom(proxy) }
                }
            }

            Divider()

            // Eingabezeile
            inputBar
        }
        .onTapGesture { inputFocused = false }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if chatVM.isTyping {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = conversation.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var quickPromptsInline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Womit kann ich helfen?")
                .font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
            ForEach(QuickPrompt.suggestions.prefix(4)) { prompt in
                Button {
                    Task { await chatVM.send(quickPrompt: prompt, workouts: workoutsVM.workouts) }
                } label: {
                    HStack {
                        Image(systemName: prompt.icon)
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text(prompt.label)
                            .font(.callout)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 8)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Frage stellen…", text: $chatVM.inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($inputFocused)
                .onSubmit {
                    Task { await chatVM.send(workouts: workoutsVM.workouts) }
                }

            Button {
                Task { await chatVM.send(workouts: workoutsVM.workouts) }
            } label: {
                Image(systemName: chatVM.isTyping ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(chatVM.inputText.isEmpty ? .secondary : .blue)
            }
            .disabled(chatVM.inputText.isEmpty || chatVM.isTyping)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 50) }

            if !isUser {
                Image(systemName: "brain.filled.head.profile")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.blue.gradient)
                    .clipShape(Circle())
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if isUser {
                    Text(message.content)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    MarkdownTextView(text: message.content)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if !isUser { Spacer(minLength: 50) }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "brain.filled.head.profile")
                .font(.callout)
                .foregroundStyle(.white)
                .padding(6)
                .background(.blue.gradient)
                .clipShape(Circle())

            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.3 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Spacer(minLength: 50)
        }
        .onAppear { phase = 1 }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message).font(.caption)
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(.red.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Prompt Button

struct QuickPromptButton: View {
    let prompt: QuickPrompt
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: prompt.icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text(prompt.label)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Konversations-History

struct ConversationHistorySheet: View {

    @EnvironmentObject var chatVM: ChatViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if chatVM.conversations.isEmpty {
                    ContentUnavailableView("Noch keine Chats", systemImage: "clock.arrow.circlepath")
                } else {
                    List {
                        ForEach(chatVM.conversations) { conv in
                            Button {
                                chatVM.activeConversation = conv
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conv.title)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(conv.preview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    Text(conv.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete { idxs in
                            idxs.forEach { chatVM.delete(chatVM.conversations[$0]) }
                        }
                    }
                }
            }
            .navigationTitle("Chat-Verlauf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !chatVM.conversations.isEmpty {
                        Button("Alle löschen", role: .destructive) {
                            chatVM.clearAll()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
