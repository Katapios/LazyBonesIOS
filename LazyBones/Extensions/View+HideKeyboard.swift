import SwiftUI

struct HideKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            )
    }
}

extension View {
    func hideKeyboardOnTap() -> some View {
        self.modifier(HideKeyboardOnTapModifier())
    }
} 