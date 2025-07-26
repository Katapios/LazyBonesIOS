import SwiftUI

struct OnboardingStepView: View {
    let title: String
    let activeStep: Int // 0...3
    let onUp: () -> Void
    let onDown: () -> Void
    let goodProgress: CGFloat // 0...1
    let badProgress: CGFloat // 0...1
    
    var body: some View {
        ZStack {
            Color(.black).ignoresSafeArea()
            VStack(spacing: 0) {
                // Верхняя панель
                HStack(alignment: .center, spacing: 24) {
                    VStack(spacing: 8) {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemGray))
                                .frame(width: 110, height: 8)
                            Capsule()
                                .fill(Color.red)
                                .frame(width: 110 * badProgress, height: 8)
                        }
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemGray))
                                .frame(width: 110, height: 8)
                            Capsule()
                                .fill(Color.green)
                                .frame(width: 110 * goodProgress, height: 8)
                        }
                    }
                    Spacer()
                    PacManShape()
                        .fill(Color(.systemGray))
                        .frame(width: 35, height: 35)
                        .rotationEffect(.degrees(-20))
                        .padding(.trailing, 8)
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
                Spacer(minLength: 24)
                // Крупный текст
                Text(title)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                Spacer()
                // Кнопки
                HStack(spacing: 40) {
                    Button(action: onUp) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 90, height: 90)
                            .overlay(
                                Image(systemName: "arrow.up")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 44, height: 44)
                                    .foregroundColor(.black)
                            )
                    }
                    Button(action: onDown) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 90, height: 90)
                            .overlay(
                                Image(systemName: "arrow.down")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 44, height: 44)
                                    .foregroundColor(.black)
                            )
                    }
                }
                .padding(.vertical, 32)
                // Индикаторы шагов
                HStack(spacing: 24) {
                    ForEach(0..<4) { idx in
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(idx == activeStep ? Color.white : Color(.systemGray3), lineWidth: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(idx == activeStep ? Color.white.opacity(0.15) : Color.clear)
                            )
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }
}

struct PacManShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let startAngle = Angle(degrees: 40)
        let endAngle = Angle(degrees: 290)
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

#Preview {
    OnboardingStepView(
        title: "Продвинулся\nв создании\nприложения",
        activeStep: 1,
        onUp: {},
        onDown: {},
        goodProgress: 0.4,
        badProgress: 0.7
    )
} 
