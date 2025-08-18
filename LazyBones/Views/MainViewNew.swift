import SwiftUI

/// Новый MainView с Clean Architecture
struct MainViewNew: View {
    @StateObject private var viewModel: MainViewModelNew
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    init() {
        let container = DependencyContainer.shared
        
        // Получаем зависимости из DI контейнера
        let getReportsUseCase = container.resolve(GetReportsUseCase.self)!
        let updateStatusUseCase = container.resolve(UpdateStatusUseCase.self)!
        let settingsRepository = container.resolve(SettingsRepositoryProtocol.self)!
        let timerService = container.resolve(PostTimerServiceProtocol.self)!
        
        self._viewModel = StateObject(wrappedValue: MainViewModelNew(
            getReportsUseCase: getReportsUseCase,
            updateStatusUseCase: updateStatusUseCase,
            settingsRepository: settingsRepository,
            timerService: timerService
        ))
    }

    var body: some View {
        VStack(spacing: 14) {
            GreetingHeaderView()
            StatusTimerSection(viewModel: viewModel)
            MoodProgressSection(
                goodCount: viewModel.state.goodCountToday,
                badCount: viewModel.state.badCountToday
            )
            PrimaryActionButtonSection(
                title: viewModel.state.buttonTitle,
                icon: viewModel.state.buttonIcon,
                color: viewModel.state.buttonColor,
                isEnabled: viewModel.state.canEditReport,
                action: { appCoordinator.switchToTab(.planning) }
            )
        }
        .padding(.vertical, 16)
        .frame(maxHeight: .infinity, alignment: .center)
        .padding()
        .onAppear {
            // Загружаем данные при появлении экрана
            Task {
                await viewModel.handle(.loadData)
            }
            // Запускаем таймер-сервис при появлении экрана
            viewModel.startTimerService()
        }
        .onDisappear {
            // Останавливаем таймер-сервис при уходе с экрана
            viewModel.stopTimerService()
        }
        .onChange(of: Calendar.current.startOfDay(for: Date())) { oldDay, newDay in
            // Проверяем новый день при смене дня
            Task {
                await viewModel.handle(.checkForNewDay)
            }
        }
        .overlay {
            if viewModel.state.isLoading {
                ProgressView("Загрузка...")
                    .background(Color.black.opacity(0.3))
            }
        }
        .alert("Ошибка", isPresented: .constant(viewModel.state.error != nil)) {
            Button("OK") {
                Task {
                    await viewModel.handle(.clearError)
                }
            }
        } message: {
            Text(viewModel.state.error?.localizedDescription ?? "")
        }
    }
}

/// Новый MainStatusBarView, который принимает ViewModel как параметр
struct MainStatusBarViewNew: View {
    @ObservedObject var viewModel: MainViewModelNew
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Привет,")
                .font(.headline)
                .fontWeight(.semibold)
                .font(.title2)
            VStack {
                Text("𝕷𝖆𝖇: 🅞'𝖙𝖗𝟗𝖈")
                    .foregroundColor(colorScheme == .dark ? .black : .white)
            }
            .font(.custom("Georgia-Bold", size: 35))
            .kerning(1)
            .padding()
            .background(
                Capsule()
                    .fill(
                        colorScheme == .dark
                            ? Color.white : Color(.black).opacity(0.85)
                    )
            )
            .foregroundStyle(.white)
            HStack(spacing: 8) {
                Text(viewModel.state.reportStatusText)
                    .font(.title2)
                    .foregroundColor(viewModel.state.reportStatusColor)
            }
            .font(.headline)
            .fontWeight(.semibold)
            .font(.title2)
            GradientRingTimerView(
                progress: viewModel.state.timeProgress,
                timeText: viewModel.state.timerTimeTextOnly,
                label: viewModel.state.timerLabel,
                ringSize: 150,
                ringLineWidth: 15,
                timeFontSize: 24,
                labelFontSize: 15
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .onAppear {
            // Проверяем новый день при появлении
            Task {
                await viewModel.handle(.checkForNewDay)
            }
        }
        .onChange(of: Calendar.current.startOfDay(for: Date())) { oldDay, newDay in
            // Проверяем новый день при смене дня
            Task {
                await viewModel.handle(.checkForNewDay)
            }
        }
    }
}

#Preview {
    MainViewNew()
        .environmentObject(AppCoordinator(dependencyContainer: DependencyContainer.shared))
} 