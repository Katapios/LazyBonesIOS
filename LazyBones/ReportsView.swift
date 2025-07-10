import SwiftUI

/// Вкладка 'Отчёты': список всех постов с датами и чеклистами
struct ReportsView: View {
    @EnvironmentObject var store: PostStore
    var body: some View {
        NavigationView {
            List {
                ForEach(store.posts) { post in
                    Section(header: Text(post.date, style: .date)) {
                        if !post.goodItems.isEmpty {
                            Text("Я молодец:").font(.headline)
                            ForEach(post.goodItems, id: \.self) { item in
                                Text("• " + item)
                            }
                        }
                        if !post.badItems.isEmpty {
                            Text("Я не молодец:").font(.headline)
                            ForEach(post.badItems, id: \.self) { item in
                                Text("• " + item)
                            }
                        }
                        Text(post.published ? "Опубликовано" : "Сохранено")
                            .font(.caption)
                            .foregroundColor(post.published ? .green : .gray)
                    }
                }
            }
            .navigationTitle("Отчёты")
        }
    }
}

#Preview {
    let store = PostStore()
    store.posts = [
        Post(id: UUID(), date: Date(), goodItems: ["Пункт 1", "Пункт 2"], badItems: ["Пункт 3"], published: true),
        Post(id: UUID(), date: Date().addingTimeInterval(-86400), goodItems: ["Пункт 4"], badItems: [], published: false)
    ]
    return ReportsView().environmentObject(store)
} 