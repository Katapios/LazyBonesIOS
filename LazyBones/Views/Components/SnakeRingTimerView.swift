import SwiftUI

// Змейка по кругу, «съедающая» иконки часов. Пиксельная (прямоугольные концы), чёрная.
public struct SnakeRingTimerView: View {
    public var progress: Double  // 0.0 ... 1.0
    public var timeText: String
    public var label: String?
    public var ringSize: CGFloat = 90
    public var ringLineWidth: CGFloat = 10
    // Настройки «часиков» по окружности
    public var clockCount: Int = 12

    @Environment(\.colorScheme) private var colorScheme

    public init(
        progress: Double,
        timeText: String,
        label: String? = nil,
        ringSize: CGFloat = 90,
        ringLineWidth: CGFloat = 10,
        clockCount: Int = 12
    ) {
        self.progress = progress
        self.timeText = timeText
        self.label = label
        self.ringSize = ringSize
        self.ringLineWidth = ringLineWidth
        self.clockCount = clockCount
    }

    public var body: some View {
        ZStack {
            // База кольца
            Circle()
                .stroke(Color(.systemGray5), lineWidth: ringLineWidth)
                .frame(width: ringSize, height: ringSize)

            // Цвета в зависимости от темы: в тёмной теме — белая змея с красными глазами
            let isDark = colorScheme == .dark
            let snakeColor: Color = isDark ? .gray : .black
            let eyeColor: Color = .white

            // Тело змеи: толщина равна толщине круга
            let bodyLineWidth = ringLineWidth
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    snakeColor,
                    style: StrokeStyle(
                        lineWidth: bodyLineWidth,
                        lineCap: .butt
                    )
                )
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)
                .animation(.easeInOut(duration: 0.6), value: progress)

            // Утолщения в местах «съеденных» часиков — внутри змеи
            EatenBulgesView(
                progress: progress,
                ringSize: ringSize,
                ringLineWidth: bodyLineWidth,
                clockCount: clockCount,
                snakeColor: snakeColor
            )

            // Часики по окружности — рисуем поверх тела змеи, но под головой
            ClockMarksView(
                progress: progress,
                ringSize: ringSize,
                ringLineWidth: ringLineWidth,
                clockCount: clockCount
            )

            // Специальный слой для 12 часов: поверх хвоста/пукл, но под головой
            TwelveOClockMarkView(
                ringSize: ringSize,
                ringLineWidth: bodyLineWidth
            )

            // Голова змейки
            SnakeHeadView(
                progress: progress,
                ringSize: ringSize,
                ringLineWidth: bodyLineWidth,
                snakeColor: snakeColor,
                eyeColor: eyeColor
            )
            .zIndex(10)

            // Центральные тексты
            VStack(spacing: 2) {
                Text(timeText)
                    .font(
                        .system(
                            size: max(10, ringSize * 0.16),
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .minimumScaleFactor(0.5)
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: ringSize * 0.8)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: timeText)
                if let label = label {
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: ringSize * 0.8)
                }
            }
            .frame(width: ringSize * 0.85)
            .drawingGroup()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Subviews

    private struct ClockMarksView: View {
        let progress: Double
        let ringSize: CGFloat
        let ringLineWidth: CGFloat
        let clockCount: Int
        // Скрываем метки на первых N% пути (узкий хвост без часиков)
        let hideStartFraction: Double = 0.06

        private func angle(at index: Int) -> Double {
            // Старт вверху (-90deg), равномерно по кругу
            let step = 360.0 / Double(max(clockCount, 1))
            return -90.0 + step * Double(index)
        }

        private func isEaten(angle: Double, progress: Double) -> Bool {
            // Нормализуем угол в диапазон [0, 1) как долю круга, начиная с -90deg
            let normalized =
                ((angle + 90).truncatingRemainder(dividingBy: 360) + 360)
                .truncatingRemainder(dividingBy: 360) / 360
            return normalized <= progress  // если точка попала в пройденную дугу — «съедена»
        }

        var body: some View {
            ZStack {
                ForEach(0..<clockCount, id: \.self) { i in
                    let ang = angle(at: i)
                    let rad = CGFloat(ang * .pi / 180)
                    let radius = ringSize / 2
                    let r = radius  // ровно по пути змеи, без смещения внутрь
                    let x = cos(rad) * r
                    let y = sin(rad) * r

                    Group {
                        let normalized =
                            ((ang + 90).truncatingRemainder(dividingBy: 360)
                            + 360).truncatingRemainder(dividingBy: 360) / 360
                        if clockCount == 12 && i == 0 {
                            // 12 часов выводится отдельным слоем (TwelveOClockMarkView)
                            EmptyView()
                        } else if clockCount == 12 && i == 1 {
                            // 1 час виден до момента, пока не будет "съеден"
                            if !isEaten(angle: ang, progress: progress) {
                                let iconSize = max(12, ringLineWidth * 1.6)
                                Image(systemName: "clock.fill")
                                    .font(.system(size: iconSize))
                                    .foregroundColor(.secondary)
                                    .position(x: radius + x, y: radius + y)
                            }
                        } else if normalized >= hideStartFraction
                            && !isEaten(angle: ang, progress: progress)
                        {
                            // Часики заметно шире тела змеи
                            let iconSize = max(12, ringLineWidth * 1.6)
                            Image(systemName: "clock.fill")
                                .font(.system(size: iconSize))
                                .foregroundColor(.secondary)
                                .position(x: radius + x, y: radius + y)
                        }
                    }
                }
            }
            .frame(width: ringSize, height: ringSize)
        }
    }

    // Отдельная метка на 12 часов: всегда иконка, позиция строго наверху, слой — между хвостом/пуклами и головой
    private struct TwelveOClockMarkView: View {
        let ringSize: CGFloat
        let ringLineWidth: CGFloat

        var body: some View {
            ZStack {
                let angle: Double = -90.0  // 12 часов наверху
                let rad = CGFloat(angle * .pi / 180)
                let radius = ringSize / 2
                let r = radius
                let x = cos(rad) * r
                let y = sin(rad) * r
                let iconSize = max(12, ringLineWidth * 1.6)
                // Фон под иконкой, чтобы перекрывать хвост змеи
                let coverSize = max(iconSize, ringLineWidth * 1.9)

                // Непрозрачный круг под иконкой, чтобы перекрыть чёрный штрих змеи (цвет базы кольца)
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: coverSize, height: coverSize)
                    .position(x: radius + x, y: radius + y)

                Image(systemName: "clock.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(.secondary)
                    .position(x: radius + x, y: radius + y)
            }
            .frame(width: ringSize, height: ringSize)
        }
    }

    // Форма головы змеи: сужающийся к носу верх и скруглённый затылок
    private struct SnakeHeadShape: Shape {
        let headWidth: CGFloat  // поперечная толщина
        let headLength: CGFloat  // продольная длина (вверх в локальных координатах)
        let tipWidthRatio: CGFloat = 0.65
        let backRadiusRatio: CGFloat = 0.55  // чуть выпуклее полукруга, чтобы полностью перекрывать края головы

        func path(in rect: CGRect) -> Path {
            var p = Path()
            let midX = rect.midX
            let tipY = rect.minY
            let baseY = rect.maxY
            let tipWidth = headWidth * tipWidthRatio
            let r = min(headWidth * backRadiusRatio, headLength * 0.55)
            let backCenter = CGPoint(x: midX, y: baseY - r)

            // Точка носа (верх)
            let tip = CGPoint(x: midX, y: tipY)
            // Правый край у носа
            let tipRight = CGPoint(
                x: midX + tipWidth / 2,
                y: tipY + max(1, headLength * 0.02)
            )
            // Левый край у носа
            let tipLeft = CGPoint(
                x: midX - tipWidth / 2,
                y: tipY + max(1, headLength * 0.02)
            )
            // Точки начала дуги затылка
            let arcStartRight = CGPoint(x: backCenter.x + r, y: backCenter.y)
            let arcStartLeft = CGPoint(x: backCenter.x - r, y: backCenter.y)
            // Контрольные точки для выпуклого наружу скругления морды (выше кончика носа)
            let noseCtrlRight = CGPoint(
                x: midX + tipWidth * 0.22,
                y: tipY - headLength * 0.08
            )
            let noseCtrlLeft = CGPoint(
                x: midX - tipWidth * 0.22,
                y: tipY - headLength * 0.08
            )

            p.move(to: tip)
            // Мягкий скруглённый переход к правому краю носа
            p.addQuadCurve(to: tipRight, control: noseCtrlRight)
            p.addLine(to: arcStartRight)
            // Дуга затылка по часовой из правой точки в левую (180 градусов)
            p.addArc(
                center: backCenter,
                radius: r,
                startAngle: .degrees(0),
                endAngle: .degrees(180),
                clockwise: true
            )
            p.addLine(to: tipLeft)
            // Мягкий скруглённый переход обратно к носу
            p.addQuadCurve(to: tip, control: noseCtrlLeft)
            p.closeSubpath()
            return p
        }
    }

    private struct SnakeHeadView: View {
        let progress: Double
        let ringSize: CGFloat
        let ringLineWidth: CGFloat
        let snakeColor: Color
        let eyeColor: Color

        private func headPosition() -> (CGPoint, Double) {
            // Конец дуги на угле (-90 + progress*360)
            let angle = -90.0 + 360.0 * max(0, min(1, progress))
            let rad = angle * .pi / 180
            let radius = ringSize / 2
            let r = radius
            let x = cos(rad) * r
            let y = sin(rad) * r
            let center = CGPoint(x: radius, y: radius)
            return (CGPoint(x: center.x + x, y: center.y + y), angle)
        }

        var body: some View {
            GeometryReader { _ in
                let (pos, ang) = headPosition()
                let headWidth = ringLineWidth * 2.0  // вариант M: умеренно больше
                let headLength = ringLineWidth * 3.1  // вариант M: умеренно длиннее
                let headRotationOffset: Double = 90  // доп. поворот по часовой
                ZStack {
                    // Вся голова в одном повороте по касательной, язык и глаза смещаются локально
                    ZStack {
                        // Чёрный круг-затылок: центр в точке backCenter формы головы
                        // backCenter.y относительно центра локальных координат: (headLength/2 - r)
                        // где r ≈ headWidth * backRadiusRatio (используем 0.55 как в SnakeHeadShape)
                        Circle()
                            .fill(snakeColor)
                            .frame(
                                width: headWidth * 1.10,
                                height: headWidth * 1.10
                            )
                            .offset(y: (headLength / 2) - (headWidth * 0.55))

                        // Форма головы: сужение к носу и скруглённый затылок
                        SnakeHeadShape(
                            headWidth: headWidth,
                            headLength: headLength
                        )
                        .fill(snakeColor)
                        .frame(width: headWidth, height: headLength)

                        // Глаза — белые пиксели
                        Rectangle()
                            .fill(eyeColor)
                            .frame(
                                width: max(1, headWidth * 0.16),
                                height: max(1, headWidth * 0.16)
                            )
                            .offset(x: -headWidth * 0.30, y: -headLength * 0.18)
                        Rectangle()
                            .fill(eyeColor)
                            .frame(
                                width: max(1, headWidth * 0.16),
                                height: max(1, headWidth * 0.16)
                            )
                            .offset(x: headWidth * 0.30, y: -headLength * 0.18)
                    }
                    .compositingGroup()
                    .drawingGroup()
                    .zIndex(10)
                    .rotationEffect(.degrees(ang + 90 + headRotationOffset))
                    .position(pos)

                    // Отдельный слой языка — поверх головы, без композиционной группы
                    ZStack {
                        Rectangle()
                            .fill(Color.red)
                            .frame(
                                width: max(2, headWidth * 0.089),
                                height: headLength * 0.35
                            )
                            .offset(x: -headWidth * 0.02, y: -headLength * 0.66)
                            .rotationEffect(.degrees(-12))
                        Rectangle()
                            .fill(Color.red)
                            .frame(
                                width: max(2, headWidth * 0.089),
                                height: headLength * 0.35
                            )
                            .offset(x: headWidth * 0.02, y: -headLength * 0.66)
                            .rotationEffect(.degrees(12))
                    }
                    .zIndex(20)
                    .rotationEffect(.degrees(ang + 90 + headRotationOffset))
                    .position(pos)
                }
                .animation(.easeInOut(duration: 0.6), value: progress)
            }
            .frame(width: ringSize, height: ringSize)
        }
    }

    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
            return p
        }
    }

    // Круглые утолщения на местах «съеденных» часиков, вписанные в толщину змеи
    private struct EatenBulgesView: View {
        let progress: Double
        let ringSize: CGFloat
        let ringLineWidth: CGFloat
        let clockCount: Int
        let snakeColor: Color
        let hideStartFraction: Double = 0.0

        private func angle(at index: Int) -> Double {
            let step = 360.0 / Double(max(clockCount, 1))
            return -90.0 + step * Double(index)
        }

        private func isEaten(angle: Double, progress: Double) -> Bool {
            let normalized =
                ((angle + 90).truncatingRemainder(dividingBy: 360) + 360)
                .truncatingRemainder(dividingBy: 360) / 360
            return normalized <= progress
        }

        var body: some View {
            ZStack {
                ForEach(0..<clockCount, id: \.self) { i in
                    let ang = angle(at: i)
                    let normalized =
                        ((ang + 90).truncatingRemainder(dividingBy: 360) + 360)
                        .truncatingRemainder(dividingBy: 360) / 360
                    // Не рисуем пуклу для 12 часов
                    if !(clockCount == 12 && i == 0)
                        && normalized >= hideStartFraction
                        && isEaten(angle: ang, progress: progress)
                    {
                        let rad = CGFloat(ang * .pi / 180)
                        let radius = ringSize / 2
                        let r = radius
                        let x = cos(rad) * r
                        let y = sin(rad) * r
                        // Утолщение заметно больше толщины тела
                        let bulge = ringLineWidth * 1.8
                        Circle()
                            .fill(snakeColor)
                            .frame(width: bulge, height: bulge)
                            .position(x: radius + x, y: radius + y)
                    }
                }
            }
            // Маска по дуге змеи, чтобы утолщения были частью тела (не выступали наружу)
            .mask(
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(
                        Color.white,
                        style: StrokeStyle(
                            lineWidth: ringLineWidth * 2.0,
                            lineCap: .butt
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: ringSize, height: ringSize)
            )
            .frame(width: ringSize, height: ringSize)
            .animation(.easeInOut(duration: 0.6), value: progress)
        }
    }

}

// MARK: - Previews
#if DEBUG
struct SnakeRingTimerView_Previews: PreviewProvider {
    static var previews: some View {
        let ringSize: CGFloat = 120
        let ringLineWidth: CGFloat = 10
        let progresses: [Double] = [
            0.00, 0.15, 0.30, 0.45, 0.60, 0.75, 0.90, 0.99,
        ]

        return Group {
            PreviewGrid(
                progresses: progresses,
                ringSize: ringSize,
                ringLineWidth: ringLineWidth
            )
            .preferredColorScheme(.light)
            .previewDisplayName("Light")

            PreviewGrid(
                progresses: progresses,
                ringSize: ringSize,
                ringLineWidth: ringLineWidth
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark")
        }
    }
}

private struct PreviewGrid: View {
    let progresses: [Double]
    let ringSize: CGFloat
    let ringLineWidth: CGFloat

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140), spacing: 16)],
                spacing: 16
            ) {
                ForEach(progresses, id: \.self) { p in
                    SnakeRingTimerView(
                        progress: p,
                        timeText: "00:30",
                        label: "Focus",
                        ringSize: ringSize,
                        ringLineWidth: ringLineWidth,
                        clockCount: 12
                    )
                }
            }
            .padding()
        }
    }
}
#endif
