import SwiftUI

struct MainWatchView: View {
    @EnvironmentObject var viewModel: WatchMainViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Статус дня
                StatusIndicatorView(status: viewModel.status)
                    .padding(.top, 8)
                
                // Таймер
                TimerView(
                    timeLeft: viewModel.timeLeft,
                    progress: viewModel.progress
                )
                
                // Мотивационный лозунг
                if !viewModel.motivationalSlogan.isEmpty {
                    MotivationalSloganView(slogan: viewModel.motivationalSlogan)
                        .padding(.horizontal)
                }
                
                // Статистика
                StatsView(
                    goodCount: viewModel.goodItemsCount,
                    badCount: viewModel.badItemsCount
                )
                
                // Быстрые действия
                QuickActionsView()
                    .environmentObject(viewModel)
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("LazyBones")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadData()
        }
        .refreshable {
            await viewModel.refreshData()
        }
    }
}

// MARK: - Status Indicator
struct StatusIndicatorView: View {
    let status: String
    
    var statusColor: Color {
        switch status {
        case "notStarted":
            return .gray
        case "inProgress":
            return .orange
        case "sent":
            return .green
        default:
            return .red
        }
    }
    
    var statusText: String {
        switch status {
        case "notStarted":
            return "Не начат"
        case "inProgress":
            return "В процессе"
        case "sent":
            return "Отправлен"
        default:
            return "Ошибка"
        }
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Timer View
struct TimerView: View {
    let timeLeft: String
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text(timeLeft)
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
            
            // Круговой прогресс
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: progress)
            }
            .frame(width: 80, height: 80)
        }
        .padding()
    }
}

// MARK: - Motivational Slogan
struct MotivationalSloganView: View {
    let slogan: String
    
    var body: some View {
        Text(slogan)
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
}

// MARK: - Stats View
struct StatsView: View {
    let goodCount: Int
    let badCount: Int
    
    var body: some View {
        HStack(spacing: 16) {
            StatItemView(
                title: "Хорошее",
                count: goodCount,
                color: .green
            )
            
            StatItemView(
                title: "Плохое",
                count: badCount,
                color: .red
            )
        }
        .padding(.horizontal)
    }
}

struct StatItemView: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Quick Actions
struct QuickActionsView: View {
    @EnvironmentObject var viewModel: WatchMainViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            NavigationLink(destination: AddReportItemView(isGood: true)) {
                Label("Добавить хорошее", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            
            NavigationLink(destination: AddReportItemView(isGood: false)) {
                Label("Добавить плохое", systemImage: "minus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            
            NavigationLink(destination: PlanView()) {
                Label("План на день", systemImage: "list.bullet")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }
}

