import SwiftUI

struct PrimaryActionButtonSection: View {
    let title: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        LargeButtonView(
            title: title,
            icon: icon,
            color: color,
            action: action,
            isEnabled: isEnabled
        )
        .padding(.horizontal)
        .padding(.vertical, 40)
    }
}

#Preview {
    PrimaryActionButtonSection(
        title: "Создать отчёт",
        icon: "plus.circle.fill",
        color: .black,
        isEnabled: true,
        action: {}
    )
}
