import SwiftUI

extension View {
    /// Скрывает клавиатуру по тапу вне поля ввода, не блокируя кнопки
    func hideKeyboardOnTap() -> some View {
        modifier(HideKeyboardOnTapModifier())
    }
}

private struct HideKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(BackgroundTapToDismiss())
    }
}

private struct BackgroundTapToDismiss: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        tap.cancelsTouchesInView = false // Не блокировать нажатия на кнопки
        view.addGestureRecognizer(tap)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator: NSObject {
        @objc func handleTap() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
} 