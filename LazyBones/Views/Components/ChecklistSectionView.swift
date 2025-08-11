import SwiftUI

/// Универсальный список для пунктов отчёта с поддержкой фокуса и удаления
struct ChecklistSectionView: View {
    let title: String
    @Binding var items: [ChecklistItem]
    let focusPrefix: String
    // Пробрасываем фокус из родителя для автопереключения на добавленный пункт
    var focusField: FocusState<UUID?>.Binding
    let onAdd: () -> Void
    let onRemove: (ChecklistItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(action: onAdd) {
                    Label("Добавить", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 4)

            // Список пунктов
            ForEach($items) { $item in
                HStack(spacing: 8) {
                    // Маркер
                    Image(systemName: "circlebadge.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 10))

                    // Поле ввода
                    TextField("Введите пункт", text: $item.text)
                        .textFieldStyle(.roundedBorder)
                        .focused(focusField, equals: item.id)
                        .submitLabel(.next)

                    // Кнопка удаления
                    if items.count > 1 {
                        Button(role: .destructive) {
                            onRemove(item)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#if DEBUG
struct ChecklistSectionView_Previews: PreviewProvider {
    struct Wrapper: View {
        @State var items: [ChecklistItem] = [
            ChecklistItem(text: "гулял"),
            ChecklistItem(text: "кодил")
        ]
        @FocusState var focus: UUID?
        var body: some View {
            ChecklistSectionView(
                title: "Я молодец:",
                items: $items,
                focusPrefix: "good",
                focusField: $focus,
                onAdd: { items.append(ChecklistItem(text: "")); focus = items.last?.id },
                onRemove: { item in if let i = items.firstIndex(of: item), items.count > 1 { items.remove(at: i) } }
            )
            .padding()
        }
    }
    static var previews: some View { Wrapper() }
}
#endif
