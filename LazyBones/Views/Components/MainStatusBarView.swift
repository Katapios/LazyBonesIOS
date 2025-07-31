import SwiftUI

struct MainStatusBarView: View {
    @EnvironmentObject var store: PostStore
    @Environment(\.colorScheme) var colorScheme
    @State private var currentTime = Date()
    @State private var timer: Timer?
    
    var reportStatusText: String {
        switch store.reportStatus {
        case .done: return "Отчёт отправлен"
        case .inProgress: return "Отчет заполняется..."
        case .notStarted: return "Заполни отчет!"
        case .notCreated: return "Отчёт не создан"
        case .notSent: return "Отчёт не отправлен"
        case .sent: return "Отчет отправлен"
        }
    }
    var reportStatusColor: Color {
        switch store.reportStatus {
        case .done: return .black
        case .inProgress: return .black
        case .notStarted: return .gray
        case .notCreated: return .gray
        case .notSent: return .gray
        case .sent: return .black
        }
    }
    var timerLabel: String {
        let calendar = Calendar.current
        let now = currentTime
        let start = calendar.date(
            bySettingHour: store.notificationStartHour,
            minute: 0,
            second: 0,
            of: now
        )!
        let end = calendar.date(
            bySettingHour: store.notificationEndHour,
            minute: 0,
            second: 0,
            of: now
        )!
        
        // Проверяем, не наступил ли новый день
        let today = calendar.startOfDay(for: now)
        if !calendar.isDate(store.currentDay, inSameDayAs: today) {
            return "Новый день"
        }
        
        if store.reportStatus == .sent || store.reportStatus == .notCreated || store.reportStatus == .notSent {
            return "До старта"
        } else if now < start {
            return "До старта"
        } else if now >= start && now < end {
            return "До конца"
        } else {
            return "Время истекло"
        }
    }
    var timerTimeTextOnly: String {
        let calendar = Calendar.current
        let now = currentTime
        let start = calendar.date(
            bySettingHour: store.notificationStartHour,
            minute: 0,
            second: 0,
            of: now
        )!
        let end = calendar.date(
            bySettingHour: store.notificationEndHour,
            minute: 0,
            second: 0,
            of: now
        )!
        
        // Проверяем, не наступил ли новый день
        let today = calendar.startOfDay(for: now)
        if !calendar.isDate(store.currentDay, inSameDayAs: today) {
            return "00:00:00"
        }
        
        if store.reportStatus == .sent || store.reportStatus == .notCreated || store.reportStatus == .notSent {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            let nextStart = calendar.date(bySettingHour: store.notificationStartHour, minute: 0, second: 0, of: tomorrow)!
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: nextStart)
            return String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else if now < start {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: start)
            return String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else if now >= start && now < end {
            let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: end)
            return String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
        } else {
            return "00:00:00"
        }
    }
    var timerProgress: Double {
        // Логика из MainView
        let calendar = Calendar.current
        let now = currentTime
        let start = calendar.date(
            bySettingHour: store.notificationStartHour,
            minute: 0,
            second: 0,
            of: now
        )!
        let end = calendar.date(
            bySettingHour: store.notificationEndHour,
            minute: 0,
            second: 0,
            of: now
        )!
        
        // Проверяем, не наступил ли новый день
        let today = calendar.startOfDay(for: now)
        if !calendar.isDate(store.currentDay, inSameDayAs: today) {
            return 0.0 // Сбрасываем прогресс для нового дня
        }
        
        if now < start { return 0 }
        if now > end { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / end.timeIntervalSince(start)))
    }
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
                Text(reportStatusText)
                    .font(.title2)
                    .foregroundColor(reportStatusColor)
            }
            .font(.headline)
            .fontWeight(.semibold)
            .font(.title2)
            GradientRingTimerView(
                progress: timerProgress,
                timeText: timerTimeTextOnly,
                label: timerLabel,
                ringSize: 150,
                ringLineWidth: 15,
                timeFontSize: 24,
                labelFontSize: 15
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .onAppear {
            startTimer()
            // Проверяем новый день при появлении
            store.checkForNewDay()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: Calendar.current.startOfDay(for: Date())) { oldDay, newDay in
            // Проверяем новый день при смене дня
            store.checkForNewDay()
        }
    }
    
    private func startTimer() {
        stopTimer()
        currentTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    MainStatusBarView().environmentObject(PostStore())
} 
