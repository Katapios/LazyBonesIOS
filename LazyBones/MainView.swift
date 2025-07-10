import SwiftUI

struct MainView: View {
    @State private var showPostForm = false
    @State private var timeLeft: String = ""
    @State private var timer: Timer? = nil
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
            PostFormView(title: "Создать отчёт")
                .environmentObject(store)
        }
        .padding()
        .onAppear {
            store.load()
        }
    }
    
    var todayStatus: String {
        if let _ = store.posts.first(where: { Calendar.current.isDateInToday($0.date) && $0.published }) {
            return "Отчёт сделан"
        } else {
            return "Отчёт не сделан"
        }
    }
    var todayStatusColor: Color {
        todayStatus == "Отчёт сделан" ? .green : .red
    }
    
    func startTimer() {
        updateTimeLeft()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateTimeLeft()
        }
    }
    
    func updateTimeLeft() {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
        let end = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)!
        if now < start {
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
    MainView()
} 