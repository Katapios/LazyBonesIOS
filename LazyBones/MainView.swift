import SwiftUI

/// Главная вкладка: таймер, статус и кнопка создания отчёта
struct MainView: View {
    @State private var showPostForm = false
    @State private var timeLeft: String = ""
    @State private var timer: Timer? = nil
    @State private var isPublishedToday: Bool = false
    @EnvironmentObject var store: PostStore
    
    var body: some View {
        VStack(spacing: 24) {
            Text(timeLeft)
                .font(.largeTitle)
                .bold()
                .onAppear(perform: startTimer)
            Text(todayStatus)
                .font(.title2)
                .foregroundColor(todayStatusColor)
            Button(action: { showPostForm = true }) {
                Text("Создать отчёт")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            Spacer()
        }
        .sheet(isPresented: $showPostForm) {
            PostFormView(title: "Создать отчёт", onPublish: {
                isPublishedToday = true
                stopTimer()
                updateTimeLeft()
            })
            .environmentObject(store)
        }
        .padding()
        .onAppear {
            store.load()
            isPublishedToday = store.posts.contains { Calendar.current.isDateInToday($0.date) && $0.published }
        }
    }
    
    /// Статус отчёта за сегодня
    var todayStatus: String {
        if isPublishedToday || store.posts.first(where: { Calendar.current.isDateInToday($0.date) && $0.published }) != nil {
            return "Отчёт сделан"
        } else {
            return "Отчёт не сделан"
        }
    }
    var todayStatusColor: Color {
        todayStatus == "Отчёт сделан" ? .green : .red
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
        if isPublishedToday || store.posts.first(where: { Calendar.current.isDateInToday($0.date) && $0.published }) != nil {
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
    let store = PostStore()
    store.posts = [
        Post(id: UUID(), date: Date(), goodItems: ["Пункт 1"], badItems: ["Пункт 2"], published: true)
    ]
    return MainView().environmentObject(store)
} 