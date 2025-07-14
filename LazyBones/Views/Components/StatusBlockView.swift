import SwiftUI

struct StatusBlockView: View {
    let status: ReportStatus
    let timerString: String
    var accentColor: Color = .accentColor
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(statusColor)
                .scaleEffect(status == .done ? 1.1 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: status)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.title3.bold())
                    .foregroundColor(statusColor)
                Text(timerString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(accentColor.opacity(0.10))
        )
        .shadow(color: accentColor.opacity(0.10), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(statusColor.opacity(0.5), lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Статус: \(statusText). \(timerString)")
    }
    private var statusText: String {
        switch status {
        case .notStarted: return "Отчёт не сделан"
        case .inProgress: return "Отчёт заполняется"
        case .done: return "Отчёт сделан"
        }
    }
    private var statusIcon: String {
        switch status {
        case .notStarted: return "hand.thumbsdown.fill"
        case .inProgress: return "gearshape.fill"
        case .done: return "hand.thumbsup.fill"
        }
    }
    private var statusColor: Color {
        switch status {
        case .notStarted: return .red
        case .inProgress: return .orange
        case .done: return .green
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StatusBlockView(status: .notStarted, timerString: "До старта: 01:23:45")
        StatusBlockView(status: .inProgress, timerString: "До конца: 05:00:00")
        StatusBlockView(status: .done, timerString: "Время отчёта истекло")
    }
    .padding()
    .background(.ultraThinMaterial)
} 