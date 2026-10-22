import SwiftUI

// MARK: - Avatar Button

/// The user's initial (or emoji) in a walnut circle; opens Profile on iPhone.
struct AvatarButton: View {
    let name: String?
    let emoji: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: emoji ?? String((name ?? "K").prefix(1)).uppercased())
                .font(KodaTypography.headline.weight(.heavy))
                .foregroundStyle(KodaColor.cream)
                .frame(width: KodaSize.avatar, height: KodaSize.avatar)
                .background(KodaColor.brand, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("profile.title"))
        .accessibilityIdentifier("avatar-button")
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Avatar") {
        HStack {
            AvatarButton(name: "Manu", emoji: nil) {}
            AvatarButton(name: nil, emoji: "🍋") {}
        }
        .padding()
        .kodaPreview()
    }

    #Preview("Avatar · dark") {
        AvatarButton(name: "Olga", emoji: nil) {}
            .padding()
            .kodaPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("Avatar · Mac", traits: .fixedLayout(width: 300, height: 200)) {
        AvatarButton(name: "Manu", emoji: nil) {}
            .kodaPreview()
    }
#endif
