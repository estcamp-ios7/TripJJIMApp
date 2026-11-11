import SwiftUI

extension Color {
    static let tripAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.systemTeal.withAlphaComponent(0.6)
            : UIColor.systemTeal
    })
}

private struct ReadableSecondaryForegroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.foregroundStyle(
            colorScheme == .dark
                ? Color.primary.opacity(0.78)
                : Color.secondary
        )
    }
}

extension View {
    func readableSecondaryForeground() -> some View {
        modifier(ReadableSecondaryForegroundModifier())
    }
}
