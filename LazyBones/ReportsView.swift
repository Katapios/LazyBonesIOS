import SwiftUI

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
    ReportsView().environmentObject(PostStore())
} 