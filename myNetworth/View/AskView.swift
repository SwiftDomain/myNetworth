//
//  AskView.swift
//  myNetworth
//

import SwiftUI

// MARK: - Ask

/// Questions about the user's own numbers. Suggested questions are answered by the app; with
/// Apple Intelligence, typed questions are answered on the device from facts the app writes.
struct AskView: View {
    var viewModel: NetWorthViewModel
    @AppStorage(DebtPayoffView.strategyKey) private var strategy = PayoffStrategy.snowball
    @AppStorage(DebtPayoffView.extraPaymentKey) private var extraText = ""
    @State private var exchanges: [Exchange] = []
    @State private var questionText = ""
    @FocusState private var isFieldFocused: Bool

    /// Checked once, so the screen doesn't change shape while it's open.
    @State private var canAskAnything = MoneyAssistant.isAvailable

    private struct Exchange: Identifiable {
        let id = UUID()
        let question: String
        /// Nil while the answer is being written.
        var answer: String?
        var isWrittenByModel = false
    }

    private var extraPayment: Int {
        max((try? Int(extraText, format: .number)) ?? 0, 0)
    }

    private var isAnswering: Bool {
        exchanges.contains { $0.answer == nil }
    }

    var body: some View {
        ZStack {
            Background(bgColor1: Theme.mainGradient1, bgColor2: Theme.mainGradient2)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(canAskAnything
                            ? "Ask about your net worth, accounts, debts or goals. Answers are written on your iPhone from your own numbers, and nothing leaves your phone."
                            : "Pick a question and the app answers it from your numbers. Typing your own questions needs Apple Intelligence, which isn't available on this iPhone.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)

                        suggestions

                        ForEach(exchanges) { exchange in
                            exchangeView(exchange)
                                .id(exchange.id)
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: exchanges.count) {
                    if let last = exchanges.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .navigationTitle("Ask")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if canAskAnything {
                inputBar
            }
        }
    }

    // MARK: Suggestions

    private var suggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SuggestedQuestion.allCases) { question in
                    Button(question.title) {
                        ask(question)
                    }
                    .font(.subheadline)
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            }
        }
    }

    private func ask(_ question: SuggestedQuestion) {
        let answer = viewModel.answer(to: question, strategy: strategy, extraPayment: extraPayment)
        exchanges.append(Exchange(question: question.title, answer: answer))
    }

    // MARK: Typed Questions

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask a question", text: $questionText, axis: .vertical)
                .lineLimit(1...4)
                .focused($isFieldFocused)
                .submitLabel(.send)
                .onSubmit(askTyped)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.15), in: .rect(cornerRadius: 20))

            Button("Ask", systemImage: "arrow.up.circle.fill", action: askTyped)
                .labelStyle(.iconOnly)
                .font(.title)
                .disabled(trimmedQuestion.isEmpty || isAnswering)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var trimmedQuestion: String {
        questionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func askTyped() {
        let question = trimmedQuestion
        guard !question.isEmpty, !isAnswering else { return }
        questionText = ""

        let exchange = Exchange(question: question)
        exchanges.append(exchange)
        let facts = viewModel.assistantFacts(strategy: strategy, extraPayment: extraPayment)

        Task {
            let reply = await MoneyAssistant.answer(question, facts: facts)
            guard let index = exchanges.firstIndex(where: { $0.id == exchange.id }) else { return }
            switch reply {
            case .answer(let text):
                exchanges[index].answer = text
                exchanges[index].isWrittenByModel = true
            case .unreliable:
                exchanges[index].answer = "I couldn't answer that reliably from your numbers. Try asking it another way, or pick one of the questions above."
            case .failed:
                exchanges[index].answer = "Something went wrong answering that. Try a shorter question, or pick one of the questions above."
            }
        }
    }

    // MARK: Conversation

    private func exchangeView(_ exchange: Exchange) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer(minLength: 40)
                Text(exchange.question)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue, in: .rect(cornerRadius: 18))
            }

            if let answer = exchange.answer {
                VStack(alignment: .leading, spacing: 6) {
                    Text(answer)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .privacySensitive()

                    if exchange.isWrittenByModel {
                        Label("Written on this iPhone by Apple Intelligence", systemImage: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(14)
                .background(Theme.cardBackground, in: .rect(cornerRadius: 18))
                .padding(.trailing, 40)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Thinking…")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(14)
            }
        }
    }
}
