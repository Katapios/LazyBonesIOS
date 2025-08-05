import SwiftUI

/// Главная вкладка: таймер, статус и кнопка создания/редактирования отчёта
struct MainView: View {
    @StateObject private var viewModel: MainViewModel
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    init(store: PostStore) {
        self._viewModel = StateObject(wrappedValue: MainViewModel(store: store))
    }

    var body: some View {
        VStack(spacing: 14) {
            MainStatusBarView().environmentObject(viewModel)
            MercuryThermometerView(goodCount: viewModel.goodCountToday, badCount: viewModel.badCountToday)
            LargeButtonView(
                title: viewModel.buttonTitle,
                icon: viewModel.buttonIcon,
                color: viewModel.buttonColor,
                action: { 
                    appCoordinator.switchToTab(.planning)
                },
                isEnabled: viewModel.canEditReport
            )
            .padding(.horizontal)
            .padding(.vertical, 40)
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
                    .frame(maxWidth: ringSize * 0.8)
                if let label = label {
                    Text(label)
                        .font(labelFontSize != nil ? .system(size: labelFontSize!, weight: .bold) : .caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: ringSize * 0.8)
                }
            }
            .frame(width: ringSize * 0.85)
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
