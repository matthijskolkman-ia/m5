import SwiftUI

struct UnlockView: View {
    @ObservedObject var viewModel: VaultViewModel
    @State private var code: String = ""
    @FocusState private var isFocused: Bool

    private let codeLength = 14

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.purple)
            }
            .padding(.bottom, 24)

            Text("Authorization Required")
                .font(.title2).bold()
                .foregroundColor(.white)
            Text("Enter a valid code to unlock this catalog.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 4)

            // Code input
            HStack(spacing: 8) {
                TextField("XXXX-XXXX-XXXX", text: $code)
                    .font(.system(.body, design: .monospaced))
                    .textCase(.uppercase)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isFocused ? Color.purple : Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .onChange(of: code) { newValue in
                        code = formatCode(newValue)
                    }

                Button(action: submit) {
                    Text(viewModel.isUnlocking ? "..." : "Unlock")
                        .fontWeight(.semibold)
                        .frame(width: 90)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(viewModel.isUnlocking || code.count < 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            // Message
            if let message = viewModel.message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(viewModel.messageIsError ? .red : .green)
                    .padding(.top, 12)
                    .transition(.opacity)
            }

            // Remaining
            HStack(spacing: 4) {
                Image(systemName: "ticket.fill")
                    .font(.caption2)
                Text("\(viewModel.remaining) of \(viewModel.totalAuthorizations) authorizations left")
                    .font(.caption2)
            }
            .foregroundColor(viewModel.remaining == 0 ? .red : .orange)
            .padding(.top, 8)

            Spacer()

            Text("Powered by Song Vault on M5")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.bottom, 32)
        }
        .padding()
        .background(Color(hex: "0a0a0f").ignoresSafeArea())
        .onAppear { isFocused = true }
    }

    private func formatCode(_ input: String) -> String {
        let cleaned = input.uppercased().filter { $0.isLetter || $0.isNumber }
        let capped = String(cleaned.prefix(12))
        var result = ""
        for (i, ch) in capped.enumerated() {
            if i == 4 || i == 8 { result.append("-") }
            result.append(ch)
        }
        return result
    }

    private func submit() {
        Task { await viewModel.unlock(code: code) }
    }
}
