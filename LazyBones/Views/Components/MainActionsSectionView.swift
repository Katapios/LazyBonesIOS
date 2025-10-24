import SwiftUI

/// Секция с индикатором good/bad и кнопкой действия (не зависит от тиков таймера)
@available(*, deprecated, message: "Legacy. Use PrimaryActionButtonSection + MoodProgressSection")
struct MainActionsSectionView: View {
    let goodCount: Int
    let badCount: Int
    let buttonTitle: String
    let buttonIcon: String
    let buttonColor: Color
    let isEnabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 14) {
            MercuryThermometerView(goodCount: goodCount, badCount: badCount)
            LargeButtonView(
                title: buttonTitle,
                icon: buttonIcon,
                color: buttonColor,
                action: onTap,
                isEnabled: isEnabled
            )
            .padding(.horizontal)
            .padding(.vertical, 40)
        }
        .padding(.vertical, 16)
    }
}

#Preview {
    VStack(spacing: 20) {
        PrimaryActionButtonSection(
            title: "Создать отчёт",
            icon: "plus.circle.fill",
            color: .black,
            isEnabled: true,
            action: {}
        )
        
        MoodProgressSection(
            goodCount: 3,
            badCount: 1
        )
    }
    .padding()
}
