import SwiftUI

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
