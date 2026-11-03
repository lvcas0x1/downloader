import SwiftUI

/// Compact flat button used in list rows (design/interface.png style: 3pt corners, 13pt text).
struct ActionButton: View {
    enum Style { case primary, secondary }

    let title: String
    let systemImage: String
    var style: Style = .secondary
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 10))
                Text(title)
            }
            .font(.system(size: 13))
            .foregroundStyle(style == .primary ? Color.white : Color.primary)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(background, in: RoundedRectangle(cornerRadius: 3))
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        style == .primary ? Color.accentColor : Color.secondary.opacity(0.12)
    }
}

/// Square icon-only variant (remove / delete).
struct IconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
                .frame(width: 24, height: 24)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
