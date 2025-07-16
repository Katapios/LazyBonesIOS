import SwiftUI

/// Главная вкладка: таймер, статус и кнопка создания/редактирования отчёта
struct MainView: View {
    @State private var showPostForm = false
    @EnvironmentObject var store: PostStore
    @Environment(\.colorScheme) var colorScheme

    var postForToday: Post? {
        store.posts.first(where: {
            Calendar.current.isDateInToday($0.date) && !$0.published
        })
    }

    var body: some View {
        VStack(spacing: 14) {
            // --- Приветственный блок теперь первым ---
            VStack(spacing: 10) {
                Text("Здорово,")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .font(.title2)
                VStack {
                    Text("𝕷𝖆𝖇: 🅞’𝖙𝖗𝟗𝖈")
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
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            // --- Таймер, статус и кнопка теперь ниже ---
            GradientRingTimerView(
                progress: timerProgress,
                timeText: timerTimeTextOnly,
                label: timerLabel,
                ringSize: 150,
                ringLineWidth: 15,
                timeFontSize: 24
            )
            HStack(spacing: 32) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                        .frame(width: 100, height: 100)
                    Text("\(goodCountToday)")
                        .font(.system(size: 100, weight: .bold, design: .serif))
                        .foregroundColor(Color.green)
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                        .frame(width: 100, height: 100)
                    Text("\(badCountToday)")
                        .font(.system(size: 100, weight: .bold, design: .serif))
                        .foregroundColor(Color.pink)
                }
            }
            LargeButtonView(
                title: postForToday != nil
                    ? "Редактировать отчёт" : "Создать отчёт",
                icon: postForToday != nil
                    ? "pencil.circle.fill" : "plus.circle.fill",
                color: store.reportStatus == .done ? .gray : .accentColor,
                action: { showPostForm = true },
                isEnabled: store.reportStatus != .done
            )
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .frame(maxHeight: .infinity, alignment: .center)
        .sheet(isPresented: $showPostForm) {
            PostFormView(
                title: postForToday != nil
                    ? "Редактировать отчёт" : "Создать отчёт",
                post: postForToday,
                onSave: {
                    store.updateReportStatus()
                    store.updateTimeLeft()
                },
                onPublish: {
                    store.updateReportStatus()
                    store.updateTimeLeft()
                    store.load()  // обновляем список постов
                }
            )
            .environmentObject(store)
        }
        .padding()
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

    // MARK: - Таймер для кольца
    var timerProgress: Double {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(
            bySettingHour: 8,
            minute: 0,
            second: 0,
            of: now
        )!
        let end = calendar.date(
            bySettingHour: 20,
            minute: 0,
            second: 0,
            of: now
        )!
        if now < start { return 0 }
        if now > end { return 1 }
        let total = end.timeIntervalSince(start)
        let passed = now.timeIntervalSince(start)
        return min(max(passed / total, 0), 1)
    }
    var timerTimeText: String {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(
            bySettingHour: 8,
            minute: 0,
            second: 0,
            of: now
        )!
        let end = calendar.date(
            bySettingHour: 20,
            minute: 0,
            second: 0,
            of: now
        )!
        if store.reportStatus == .done {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            let nextStart = calendar.date(
                bySettingHour: 8,
                minute: 0,
                second: 0,
                of: tomorrow
            )!
            let diff = calendar.dateComponents(
                [.hour, .minute, .second],
                from: now,
                to: nextStart
            )
            return String(
                format: "%02d:%02d:%02d",
                diff.hour ?? 0,
                diff.minute ?? 0,
                diff.second ?? 0
            )
        } else if now < start {
            let diff = calendar.dateComponents(
                [.hour, .minute, .second],
                from: now,
                to: start
            )
            return String(
                format: "%02d:%02d:%02d",
                diff.hour ?? 0,
                diff.minute ?? 0,
                diff.second ?? 0
            )
        } else if now >= start && now <= end {
            let diff = calendar.dateComponents(
                [.hour, .minute, .second],
                from: now,
                to: end
            )
            return String(
                format: "%02d:%02d:%02d",
                diff.hour ?? 0,
                diff.minute ?? 0,
                diff.second ?? 0
            )
        } else {
            return "00:00:00"
        }
    }
    var timerLabel: String {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(
            bySettingHour: 8,
            minute: 0,
            second: 0,
            of: now
        )!
        let end = calendar.date(
            bySettingHour: 20,
            minute: 0,
            second: 0,
            of: now
        )!
        if store.reportStatus == .done {
            return "До старта"
        } else if now < start {
            return "До старта"
        } else if now >= start && now <= end {
            return "До конца"
        } else {
            return "Время истекло"
        }
    }

    // Количество good и bad пунктов за сегодня
    var goodCountToday: Int {
        postForToday?.goodItems.filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }.count ?? 0
    }
    var badCountToday: Int {
        postForToday?.badItems.filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }.count ?? 0
    }

    // Новый геттер: только время без подписи
    var timerTimeTextOnly: String {
        let value = store.timeLeft
        if let range = value.range(of: ": ") {
            return String(value[range.upperBound...])
        }
        return value
    }
}

// Модный анимированный градиентный таймер-кольцо (ещё компактнее)
struct GradientRingTimerView: View {
    var progress: Double  // 0.0 ... 1.0
    var timeText: String
    var label: String?
    var ringSize: CGFloat = 90
    var ringLineWidth: CGFloat = 10
    var timeFontSize: CGFloat = 14
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: ringLineWidth)
                .frame(width: ringSize, height: ringSize)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.blue, Color.purple, Color.pink, Color.blue,
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: ringLineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)
                .animation(.easeInOut(duration: 0.7), value: progress)
            VStack(spacing: 2) {
                Text(timeText)
                    .font(
                        .system(
                            size: timeFontSize,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .minimumScaleFactor(0.5)
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: ringSize * 0.8)
                if let label = label {
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: ringSize * 0.8)
                }
            }
            .frame(width: ringSize * 0.85)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let store: PostStore = {
        let s = PostStore()
        s.posts = [
            Post(
                id: UUID(),
                date: Date(),
                goodItems: ["Пункт 1"],
                badItems: ["Пункт 2"],
                published: true,
                voiceNotes: []
            )
        ]
        return s
    }()
    MainView().environmentObject(store)
}
