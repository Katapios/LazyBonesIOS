import SwiftUI

/// Кольцевой таймер с градиентной обводкой, используемый на главном экране
struct GradientRingTimerView: View {
    // 0.0 ... 1.0
    var progress: Double
    var timeText: String
    var label: String
    var ringSize: CGFloat
    var ringLineWidth: CGFloat
    var timeFontSize: CGFloat
    var labelFontSize: CGFloat

    private var clampedProgress: Double { min(max(progress, 0.0), 1.0) }

    var body: some View {
        ZStack {
            // Фон
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: ringLineWidth)
                .frame(width: ringSize, height: ringSize)

            // Прогресс с градиентом
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.green,
                            Color.blue,
                            Color.purple,
                            Color.pink,
                            Color.orange,
                            Color.green
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)
                .animation(.easeInOut(duration: 0.25), value: clampedProgress)

            VStack(spacing: 6) {
                Text(timeText)
                    .font(.system(size: timeFontSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: labelFontSize, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(timeText))
    }
}

#if DEBUG
struct GradientRingTimerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            GradientRingTimerView(
                progress: 0.65,
                timeText: "02:34:10",
                label: "Осталось",
                ringSize: 180,
                ringLineWidth: 16,
                timeFontSize: 28,
                labelFontSize: 14
            )
            GradientRingTimerView(
                progress: 0.1,
                timeText: "23:59",
                label: "До дедлайна",
                ringSize: 140,
                ringLineWidth: 12,
                timeFontSize: 22,
                labelFontSize: 12
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
