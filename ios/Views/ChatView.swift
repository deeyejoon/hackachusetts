//  ChatView.swift
//  Sage's primary screen: the journaling chatbot.

import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var store: SignalStore
    @StateObject private var vm: ChatViewModel

    /// Drives the keyboard for the input field so we can dismiss it on demand
    /// (tap/scroll the message list, or after sending).
    @FocusState private var inputFocused: Bool

    /// The view model is created lazily with the injected store. We can't read the
    /// environment in a property initializer, so `ChatView` takes an optional store
    /// at init: the app passes it through `RootTabView`, and previews supply their own.
    init(store: SignalStore? = nil) {
        _vm = StateObject(wrappedValue: ChatViewModel(store: store))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().background(Color.sageBorder)

            messageList

            inputBar
        }
        .background(Color.sageBackground.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sage")
                    .font(SageFont.serif(26, weight: .semibold))
                    .foregroundColor(.sageText)
                Text("Your journaling companion")
                    .font(SageFont.body(13))
                    .foregroundColor(.sageMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.sageBackground)
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(vm.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    if vm.isSending {
                        TypingIndicatorView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("typing-indicator")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            // Dismiss the keyboard when the user drags the conversation.
            .scrollDismissesKeyboard(.interactively)
            // Tapping anywhere in the message area also dismisses the keyboard.
            .contentShape(Rectangle())
            .onTapGesture {
                inputFocused = false
            }
            .onChange(of: vm.messages) { _ in
                scrollToBottom(proxy)
            }
            .onChange(of: vm.isSending) { _ in
                scrollToBottom(proxy)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            if vm.isSending {
                proxy.scrollTo("typing-indicator", anchor: .bottom)
            } else if let last = vm.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.sageBorder)

            HStack(spacing: 10) {
                TextField("Share what's on your mind", text: $vm.draft, axis: .vertical)
                    .font(SageFont.body(16))
                    .foregroundColor(.sageText)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.sageSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.sageBorder, lineWidth: 1)
                    )
                    .submitLabel(.send)
                    .onSubmit { send() }

                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.sageSurface)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(sendEnabled ? Color.sageMoss : Color.sageMuted))
                }
                .disabled(!sendEnabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.sageBackground)
        }
    }

    private var sendEnabled: Bool {
        !vm.isSending &&
        !vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Send the draft and dismiss the keyboard so the conversation is visible again.
    private func send() {
        inputFocused = false
        vm.send()
    }
}

/// Simple animated three-dot typing indicator shown while a reply is pending.
struct TypingIndicatorView: View {
    @State private var phase = 0

    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.sageMuted)
                    .frame(width: 7, height: 7)
                    .opacity(phase == index ? 1.0 : 0.3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            BubbleShape(tail: .bottomLeft).fill(Color.sageSurface)
        )
        .overlay(
            BubbleShape(tail: .bottomLeft).stroke(Color.sageBorder, lineWidth: 1)
        )
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}

#Preview {
    let store = SignalStore()
    return ChatView(store: store)
        .environmentObject(store)
}
