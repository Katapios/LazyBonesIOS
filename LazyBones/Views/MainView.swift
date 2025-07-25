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
            MainStatusBarView()
            MercuryThermometerView(goodCount: goodCountToday, badCount: badCountToday)
            LargeButtonView(
                title: postForToday != nil
                    ? "Редактировать отчёт" : "Создать отчёт",
                icon: postForToday != nil
                    ? "pencil.circle.fill" : "plus.circle.fill",
                color: store.reportStatus == .done ? .gray : .black,
                action: { showPostForm = true },
                isEnabled: store.reportStatus != .done
            )
            .padding(.horizontal)
            .padding(.vertical, 40)
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

    // Количество good и bad пунктов за сегодня
    var goodCountToday: Int {
        var total = 0
        // Обычный отчет за сегодня
        if let regular = store.posts.first(where: { $0.type == .regular && Calendar.current.isDateInToday($0.date) }) {
            total += regular.goodItems.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        }
        // Кастомный оцененный отчет за сегодня
        if let custom = store.posts.first(where: { $0.type == .custom && Calendar.current.isDateInToday($0.date) && $0.isEvaluated == true }),
           let results = custom.evaluationResults {
            total += results.filter { $0 }.count
        }
        return total
    }
    var badCountToday: Int {
        var total = 0
        // Обычный отчет за сегодня
        if let regular = store.posts.first(where: { $0.type == .regular && Calendar.current.isDateInToday($0.date) }) {
            total += regular.badItems.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        }
        // Кастомный оцененный отчет за сегодня
        if let custom = store.posts.first(where: { $0.type == .custom && Calendar.current.isDateInToday($0.date) && $0.isEvaluated == true }),
           let results = custom.evaluationResults {
            total += results.filter { !$0 }.count
        }
        return total
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
    var labelFontSize: CGFloat? = nil
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
                            Color.gray, Color.black, Color.black, Color.gray,
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
                        .font(labelFontSize != nil ? .system(size: labelFontSize!, weight: .bold) : .caption2)
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
                voiceNotes: [],
                type: .regular
            )
        ]
        return s
    }()
    MainView().environmentObject(store)
}
