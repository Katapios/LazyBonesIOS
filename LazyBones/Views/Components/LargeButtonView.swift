import SwiftUI

struct LargeButtonView: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    var isEnabled: Bool = true
    var compact: Bool = false // Новый параметр для компактного режима
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? 6 : 12) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 20 : 28, weight: .bold))
                Text(title)
                    .font(compact ? .body.bold() : .title2.bold())
            }
            .frame(minWidth: 120, minHeight: compact ? 40 : 56)
            .padding(.vertical, compact ? 4 : 8)
            .padding(.horizontal, compact ? 16 : 24)
            .background(
                RoundedRectangle(cornerRadius: compact ? 14 : 20, style: .continuous)
                    .fill(color.opacity(isEnabled ? 0.85 : 0.4))
            )
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 14 : 20)
                    .stroke(color.opacity(isEnabled ? 0.35 : 0.15), lineWidth: compact ? 1 : 1.5)
            )
            .shadow(color: color.opacity(isEnabled ? 0.10 : 0.03), radius: compact ? 3 : 8, x: 0, y: compact ? 2 : 4)
            .opacity(isEnabled ? 1 : 0.6)
        }
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack(spacing: 20) {
        LargeButtonView(title: "Создать отчёт", icon: "plus.circle.fill", color: .accentColor, action: {})
        LargeButtonView(title: "Опубликовать", icon: "paperplane.fill", color: .green, action: {}, compact: true)
        LargeButtonView(title: "Сохранить", icon: "tray.and.arrow.down.fill", color: .blue, action: {}, isEnabled: false, compact: true)
    }
    .padding()
    .background(.ultraThinMaterial)
} 