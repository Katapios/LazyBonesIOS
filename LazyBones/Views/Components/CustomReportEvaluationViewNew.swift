import SwiftUI

struct CustomReportEvaluationViewNew: View {
    let post: DomainPost
    let onComplete: (_ checked: [Bool]) -> Void
    @State private var checked: [Bool]
    @State private var currentPost: DomainPost
    @Environment(\.dismiss) var dismiss
    
    init(post: DomainPost, onComplete: @escaping ([Bool]) -> Void) {
        self.post = post
        self.onComplete = onComplete
        // Инициализируем checked с правильным размером
        _checked = State(initialValue: Array(repeating: false, count: max(1, post.goodItems.count)))
        _currentPost = State(initialValue: post)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Оцените выполнение плана")
                .font(.headline)
            
            if currentPost.goodItems.isEmpty {
                // Показываем сообщение, если нет задач для оценки
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("Нет задач для оценки")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("В этом отчете нет задач, которые можно оценить.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Показываем список задач для оценки
                List {
                    ForEach(currentPost.goodItems.indices, id: \.self) { idx in
                        HStack {
                            Text(currentPost.goodItems[idx])
                            Spacer()
                            Toggle("", isOn: $checked[idx])
                                .labelsHidden()
                        }
                    }
                }
            }
            
            Button("Завершить отчет") {
                onComplete(checked)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .onAppear {
            // Обновляем currentPost и checked при появлении view
            currentPost = post
            if checked.count != post.goodItems.count {
                checked = Array(repeating: false, count: max(1, post.goodItems.count))
            }
        }
        .onChange(of: post.goodItems.count) { oldCount, newCount in
            // Обновляем checked при изменении количества элементов
            currentPost = post
            if checked.count != newCount {
                checked = Array(repeating: false, count: max(1, newCount))
            }
        }
    }
}

#Preview {
    let post = DomainPost(
        id: UUID(),
        date: Date(),
        goodItems: ["Пункт 1", "Пункт 2", "Пункт 3"],
        badItems: ["Пункт 4"],
        published: true,
        voiceNotes: [],
        type: .custom
    )
    CustomReportEvaluationViewNew(post: post) { checked in
        print("Оценка завершена: \(checked)")
    }
} 