import SwiftUI

struct StatusTimerSection: View {
    @ObservedObject var viewModel: MainViewModelNew
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(viewModel.state.reportStatusText)
                    .font(.title2)
                    .foregroundColor(viewModel.state.reportStatusColor)
            }
            .font(.headline)
            .fontWeight(.semibold)
            .font(.title2)
            
            SnakeRingTimerView(
                progress: viewModel.state.timeProgress,
                timeText: viewModel.state.timerTimeTextOnly,
                label: viewModel.state.timerLabel,
                ringSize: 150,
                ringLineWidth: 15
            )
        }
    }
}

#Preview {
    // Dummy preview; requires environment setup in app
    Text("Preview not available for StatusTimerSection without VM")
}
