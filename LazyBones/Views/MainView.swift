import SwiftUI

/// Главная вкладка: таймер, статус и кнопка создания/редактирования отчёта
@available(*, deprecated, message: "Use MainViewNew instead")
struct MainView: View {
    @StateObject private var viewModel: MainViewModel
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    init(store: PostStore) {
        self._viewModel = StateObject(wrappedValue: MainViewModel(store: store))
    }

// Змейка по кругу, «съедающая» иконки часов. Пиксельная (прямоугольные концы), чёрная.
struct SnakeRingTimerView: View {
    var progress: Double  // 0.0 ... 1.0
    var timeText: String
    var label: String?
    var ringSize: CGFloat = 90
    var ringLineWidth: CGFloat = 10
    // Настройки «часиков» по окружности
    var clockCount: Int = 12
    var body: some View {
        ZStack {
            // База кольца
            Circle()
                .stroke(Color(.systemGray5), lineWidth: ringLineWidth)
                .frame(width: ringSize, height: ringSize)

            // Тело змеи: единая толщина по всей длине прогресса (как раньше — полноразмерная)
            let taper: Double = 0.12 // используем только для скрытия часиков на старте
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    Color.black,
                    style: StrokeStyle(
                        lineWidth: ringLineWidth,
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
                ringLineWidth: ringLineWidth,
                clockCount: clockCount
            )

            // Часики по окружности — рисуем поверх тела змеи, но под головой
            ClockMarksView(
                progress: progress,
                ringSize: ringSize,
                ringLineWidth: ringLineWidth,
                clockCount: clockCount
            )

            // Голова змейки
            SnakeHeadView(
                progress: progress,
                ringSize: ringSize,
                ringLineWidth: ringLineWidth
            )

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
        let normalized = ((angle + 90).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        return normalized <= progress // если точка попала в пройденную дугу — «съедена»
    }

    var body: some View {
        ZStack {
            ForEach(0..<clockCount, id: \.self) { i in
                let ang = angle(at: i)
                let rad = CGFloat(ang * .pi / 180)
                let radius = ringSize / 2
                let r = radius // ровно по пути змеи, без смещения внутрь
                let x = cos(rad) * r
                let y = sin(rad) * r

                Group {
                    let normalized = ((ang + 90).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
                    if clockCount == 12 && i == 0 {
                        // 12 часов: всегда показываем иконку
                        let iconSize = max(12, ringLineWidth * 1.6)
                        Image(systemName: "clock.fill")
                            .font(.system(size: iconSize))
                            .foregroundColor(.secondary)
                            .position(x: radius + x, y: radius + y)
                    } else if clockCount == 12 && i == 1 {
                        // Спец. случай: 1 час виден до момента, пока не будет "съеден"
                        if !isEaten(angle: ang, progress: progress) {
                            let iconSize = max(12, ringLineWidth * 1.6)
                            Image(systemName: "clock.fill")
                                .font(.system(size: iconSize))
                                .foregroundColor(.secondary)
                                .position(x: radius + x, y: radius + y)
                        }
                    } else if normalized >= hideStartFraction && !isEaten(angle: ang, progress: progress) {
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

private struct SnakeHeadView: View {
    let progress: Double
    let ringSize: CGFloat
    let ringLineWidth: CGFloat

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
            let headSize = ringLineWidth * 2.2 // голова ещё толще тела
            let headRotationOffset: Double = 90 // доп. поворот по часовой, градусы (было 45, добавил ещё 45)
            ZStack {
                // Вся голова в одном повороте по касательной, язык и глаза смещаются локально
                ZStack {
                    // Пиксельная голова (квадрат)
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: headSize, height: headSize)

                    // Язык — раздвоенный вперёд (вверх в локальных координатах)
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: max(1, headSize * 0.12), height: headSize * 0.6)
                        .offset(y: -headSize * 0.95)
                        .rotationEffect(.degrees(-12))
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: max(1, headSize * 0.12), height: headSize * 0.6)
                        .offset(y: -headSize * 0.95)
                        .rotationEffect(.degrees(12))

                    // Глаза — белые пиксели
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: max(1, headSize * 0.14), height: max(1, headSize * 0.14))
                        .offset(x: -headSize * 0.28, y: -headSize * 0.08)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: max(1, headSize * 0.14), height: max(1, headSize * 0.14))
                        .offset(x: headSize * 0.28, y: -headSize * 0.08)
                }
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
    let hideStartFraction: Double = 0.0

    private func angle(at index: Int) -> Double {
        let step = 360.0 / Double(max(clockCount, 1))
        return -90.0 + step * Double(index)
    }

    private func isEaten(angle: Double, progress: Double) -> Bool {
        let normalized = ((angle + 90).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        return normalized <= progress
    }

    var body: some View {
        ZStack {
            ForEach(0..<clockCount, id: \.self) { i in
                let ang = angle(at: i)
                let normalized = ((ang + 90).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
                // Не рисуем пуклу для 12 часов
                if !(clockCount == 12 && i == 0) && normalized >= hideStartFraction && isEaten(angle: ang, progress: progress) {
                    let rad = CGFloat(ang * .pi / 180)
                    let radius = ringSize / 2
                    let r = radius
                    let x = cos(rad) * r
                    let y = sin(rad) * r
                    // Утолщение заметно больше толщины тела
                    let bulge = ringLineWidth * 1.8
                    Circle()
                        .fill(Color.black)
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
                    style: StrokeStyle(lineWidth: ringLineWidth * 2.0, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)
        )
        .frame(width: ringSize, height: ringSize)
        .animation(.easeInOut(duration: 0.6), value: progress)
    }
}

// Preview вынесен в файл-скоуп ниже, вне объявления MainView

    var body: some View {
        VStack(spacing: 14) {
            // Таймер и статус — зависят от тиков времени
            MainStatusBarView().environmentObject(viewModel)
            // Действия и счётчики — не зависят от тиков времени
            MainActionsSectionView(
                goodCount: viewModel.goodCountToday,
                badCount: viewModel.badCountToday,
                buttonTitle: viewModel.buttonTitle,
                buttonIcon: viewModel.buttonIcon,
                buttonColor: viewModel.buttonColor,
                isEnabled: viewModel.canEditReport,
                onTap: { appCoordinator.switchToTab(.planning) }
            )
        }
        .padding(.vertical, 16)
        .frame(maxHeight: .infinity, alignment: .center)
        .padding()
        .onAppear {
            // Проверяем новый день при появлении экрана
            viewModel.checkForNewDay()
        }
        .onChange(of: Calendar.current.startOfDay(for: Date())) { oldDay, newDay in
            // Проверяем новый день при смене дня
            viewModel.checkForNewDay()
        }
    }


}

// Модный анимированный градиентный таймер-кольцо (ещё компактнее)
struct GradientRingTimerView: View {
    var progress: Double  // 0.0 ... 1.0
    var timeText: String
    var label: String?
    var ringSize: CGFloat = 90
    var ringLineWidth: CGFloat = 10
    var timeFontSize: CGFloat = 14
    var labelFontSize: CGFloat? = nil
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: ringLineWidth)
                .frame(width: ringSize, height: ringSize)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.gray, Color.black, Color.black, Color.gray,
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: ringLineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)
                .animation(.easeInOut(duration: 0.7), value: progress)
            VStack(spacing: 2) {
                Text(timeText)
                    .font(
                        .system(
                            size: timeFontSize,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .minimumScaleFactor(0.5)
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: ringSize * 0.8, height: timeFontSize * 1.2, alignment: .center)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: timeText)
                if let label = label {
                    Text(label)
                        .font(labelFontSize != nil ? .system(size: labelFontSize!, weight: .bold) : .caption2)
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
}

#Preview {
    let store: PostStore = {
        let s = PostStore()
        s.posts = [
            Post(
                id: UUID(),
                date: Date(),
                goodItems: ["Пункт 1"],
                badItems: ["Пункт 2"],
                published: true,
                voiceNotes: [],
                type: .regular
            )
        ]
        return s
    }()
    MainView(store: store)
}

#Preview("SnakeRingTimerView States") {
    VStack(spacing: 16) {
        let size: CGFloat = 150
        MainView.SnakeRingTimerView(progress: 0.0, timeText: "09:00", label: "до конца", ringSize: size, ringLineWidth: 14)
        MainView.SnakeRingTimerView(progress: 0.25, timeText: "06:00", label: "до конца", ringSize: size, ringLineWidth: 14)
        MainView.SnakeRingTimerView(progress: 0.5, timeText: "04:00", label: "до конца", ringSize: size, ringLineWidth: 14)
        MainView.SnakeRingTimerView(progress: 0.75, timeText: "02:00", label: "до конца", ringSize: size, ringLineWidth: 14)
        MainView.SnakeRingTimerView(progress: 0.99, timeText: "00:01", label: "до конца", ringSize: size, ringLineWidth: 14)
    }
    .padding()
}
