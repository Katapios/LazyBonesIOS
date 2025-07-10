import SwiftUI

struct MainView: View {
    @State private var showPostForm = false
    @State private var timeLeft: String = ""
    @State private var timer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            Text(timeLeft)
                .font(.largeTitle)
                .bold()
                .onAppear(perform: startTimer)
            Text("Отчёт не сделан")
                .font(.title2)
                .foregroundColor(.red)
            Button(action: { showPostForm = true }) {
                Text("Создать пост")
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
            PostFormView()
        }
        .padding()
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
        let midnight = calendar.nextDate(after: now, matching: DateComponents(hour:0, minute:0, second:0), matchingPolicy: .nextTime) ?? now
        let diff = calendar.dateComponents([.hour, .minute, .second], from: now, to: midnight)
        timeLeft = String(format: "%02d:%02d:%02d", diff.hour ?? 0, diff.minute ?? 0, diff.second ?? 0)
    }
}

#Preview {
    MainView()
} 