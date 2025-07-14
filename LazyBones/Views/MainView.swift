import SwiftUI

/// Главная вкладка: таймер, статус и кнопка создания/редактирования отчёта
struct MainView: View {
    @State private var showPostForm = false
    @State private var timeLeft: String = ""
    @State private var timer: Timer? = nil
    @EnvironmentObject var store: PostStore
    
    var postForToday: Post? {
        store.posts.first(where: { Calendar.current.isDateInToday($0.date) && !$0.published })
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text(timeLeft)
                .font(.largeTitle)
                .bold()
                .onAppear(perform: startTimer)
            HStack(spacing: 8) {
                if store.reportStatus == .inProgress {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.orange)
                }
                Text(reportStatusText)
                    .font(.title2)
                    .foregroundColor(reportStatusColor)
            }
            Button(action: { showPostForm = true }) {
                Text(postForToday != nil ? "Редактировать отчёт" : "Создать отчёт")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(store.reportStatus == .done ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .disabled(store.reportStatus == .done)
            Spacer()
        }
        .sheet(isPresented: $showPostForm) {
            PostFormView(
                title: postForToday != nil ? "Редактировать отчёт" : "Создать отчёт",
                post: postForToday,
                onSave: {
                    store.updateReportStatus()
                    stopTimer()
                    updateTimeLeft()
                },
                onPublish: {
                    store.updateReportStatus()
                    stopTimer()
                    updateTimeLeft()
                    store.load() // обновляем список постов
                }
            )
            .environmentObject(store)
        }
        .padding()
        .onAppear {
            store.load()
            store.updateReportStatus()
        }
    }
    
    var reportStatusText: String {
        switch store.reportStatus {
        case .notStarted: return "Отчёт не сделан"
        case .inProgress: return "Отчёт заполняется"
        case .done: return "Отчёт сделан"
        }
    }
    var reportStatusColor: Color {
        switch store.reportStatus {
        case .notStarted: return .red
        case .inProgress: return .orange
        case .done: return .green
        }
    }
    
    /// Запуск и обновление таймера обратного отсчёта
    func startTimer() {
        updateTimeLeft()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateTimeLeft()
        }
    }
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func updateTimeLeft() {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
        let end = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)!
        if store.reportStatus == .done {
            // После публикации показываем время до 8:00 следующего дня
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            let nextStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow)!
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: nextStart)
            timeLeft = "До старта: " + String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else if now < start {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: start)
            timeLeft = "До старта: " + String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else if now >= start && now <= end {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: end)
            timeLeft = "До конца: " + String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else {
            timeLeft = "Время отчёта истекло"
        }
    }
}

#Preview {
    let store: PostStore = {
        let s = PostStore()
        s.posts = [
            Post(id: UUID(), date: Date(), goodItems: ["Пункт 1"], badItems: ["Пункт 2"], published: true, voiceNotes: [])
        ]
        return s
    }()
    MainView().environmentObject(store)
} 