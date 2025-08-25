import SwiftUI

@available(*, deprecated, message: "Legacy. Use MainStatusBarViewNew or compose GreetingHeaderView + StatusTimerSection")
struct MainStatusBarView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var reportStatusText: String {
        viewModel.reportStatusText
    }
    
    var reportStatusColor: Color {
        viewModel.reportStatusColor
    }
    var timerLabel: String {
        viewModel.timerLabel
    }
    var timerTimeTextOnly: String {
        viewModel.timerTimeTextOnlyForStatus
    }
    var timerProgress: Double {
        viewModel.timerProgress
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
            // Проверяем новый день при появлении
            viewModel.checkForNewDay()
        }
        .onChange(of: Calendar.current.startOfDay(for: Date())) { oldDay, newDay in
            // Проверяем новый день при смене дня
            viewModel.checkForNewDay()
        }
    }
    

}

#Preview {
    let store = PostStore()
    let viewModel = MainViewModel(store: store)
    MainStatusBarView().environmentObject(viewModel)
} 
