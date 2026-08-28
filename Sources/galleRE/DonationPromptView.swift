import SwiftUI

struct DonationPromptView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "heart.fill")
                .font(.system(size: 46))
                .foregroundStyle(.pink)
                .padding(.top, 6)

            Text("Thanks for using galleRE!")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("galleRE is free and open source, built by one person — Clark Hess. If it's saving you time on your listings, please consider chipping in. Even a small tip helps keep it maintained and improving. 💜")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            Link(destination: Support.venmoURL) {
                Label("Donate via Venmo · @ClarkHess", systemImage: "heart.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).tint(.pink)

            Button("Maybe later") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Text("You'll only see this occasionally.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(26)
        .frame(width: 380)
    }
}
