import SwiftUI

struct MercuryThermometerView: View {
    let goodCount: Int
    let badCount: Int
    
    var total: Int { goodCount + badCount }
    var badRatio: CGFloat { total > 0 ? CGFloat(badCount) / CGFloat(total) : 0 }
    
    // Размеры
    let barHeight: CGFloat = 18
    let barWidth: CGFloat = 220
    let bulbDiameter: CGFloat = 38
    let tipDiameter: CGFloat = 32
    
    @State private var wavePhase: CGFloat = 0
    @State private var animatedBadRatio: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .bottom, spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(goodCount)")
                        .font(.custom("Georgia-Bold", size: 45))
                        .foregroundColor(.green)
                    Text("молодец")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                VStack(spacing: 2) {
                    Text("\(badCount)")
                        .font(.custom("Georgia-Bold", size: 45))
                        .foregroundColor(.red)
                    Text("лаботряс")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            ZStack(alignment: .leading) {
                // Серый фон: Capsule + круг справа
                HStack(spacing: 0) {
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(.systemGray4), Color(.systemGray3)]), startPoint: .top, endPoint: .bottom))
                        .frame(width: barWidth, height: barHeight)
                        .shadow(color: .gray.opacity(0.10), radius: 2, x: 0, y: 1)
                    Circle()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(.systemGray4), Color(.systemGray3)]), startPoint: .top, endPoint: .bottom))
                        .frame(width: tipDiameter, height: tipDiameter)
                        .shadow(color: .gray.opacity(0.18), radius: 6, x: 0, y: 2)
                        .offset(x: -10)
                }
                // Красная "ртуть" (Capsule справа налево)
                if badCount > 0 {
                    HStack(spacing: 0) {
                        Spacer().frame(width: barWidth * (1 - animatedBadRatio) - 10)
                        Capsule()
                            .fill(LinearGradient(gradient: Gradient(colors: [Color.red.opacity(0.85), Color.red]), startPoint: .top, endPoint: .bottom))
                            .frame(width: barWidth * animatedBadRatio + 10, height: barHeight)
                            .shadow(color: Color.red.opacity(0.18), radius: 2, x: 0, y: 1)
                        Spacer().frame(width: tipDiameter)
                    }
                }
                // Красный набалдашник всегда справа
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(badCount > 0 ? LinearGradient(gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]), startPoint: .top, endPoint: .bottom) : LinearGradient(gradient: Gradient(colors: [Color(.systemGray4), Color(.systemGray3)]), startPoint: .top, endPoint: .bottom))
                            .frame(width: tipDiameter, height: tipDiameter)
                            .shadow(color: badCount > 0 ? Color.red.opacity(0.25) : .gray.opacity(0.18), radius: 4, x: 0, y: 2)
                            .offset(x: -10)
                        if badCount > 0 {
                            MercuryWaveShape(phase: wavePhase)
                                .fill(Color.white.opacity(0.25))
                                .frame(width: tipDiameter * 0.7, height: tipDiameter * 0.25)
                                .offset(y: tipDiameter * 0.18)
                                .blur(radius: 0.5)
                        }
                    }
                }
            }
            .frame(width: barWidth + tipDiameter, height: tipDiameter)
            .padding(.top, 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7)) {
                animatedBadRatio = badRatio
            }
            animateWave()
        }
        .onChange(of: badRatio) { _, newValue in
            withAnimation(.easeInOut(duration: 0.7)) {
                animatedBadRatio = newValue
            }
        }
    }
    func animateWave() {
        withAnimation(Animation.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            wavePhase += .pi * 2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            animateWave()
        }
    }
}

struct MercuryWaveShape: Shape {
    var phase: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let amplitude: CGFloat = 2.5
        let waveLength: CGFloat = rect.width
        path.move(to: CGPoint(x: 0, y: rect.midY))
        for x in stride(from: 0, through: waveLength, by: 1) {
            let relativeX = x / waveLength
            let y = rect.midY + sin(relativeX * .pi * 2 + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 32) {
        MercuryThermometerView(goodCount: 0, badCount: 0)
        MercuryThermometerView(goodCount: 10, badCount: 12)
        MercuryThermometerView(goodCount: 0, badCount: 0)
        MercuryThermometerView(goodCount: 20, badCount: 8)
    }
    .padding()
    .background(Color(.systemGray6))
} 
