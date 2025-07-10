import SwiftUI

extension View {
    /// Скрывает клавиатуру по тапу вне поля ввода
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
} 