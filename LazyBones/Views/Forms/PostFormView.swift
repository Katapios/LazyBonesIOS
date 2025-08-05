import SwiftUI

// MARK: - Tag Brick Component
struct TagBrickView: View {
    let tag: TagItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: tag.icon)
                    .font(.system(size: 13, weight: .medium))
                Text(tag.text)
                    .font(.system(size: 13, weight: .medium))
            }
            .fixedSize()  // Не растягивать тег по ширине
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tag.color)
            .cornerRadius(16)
            .shadow(color: tag.color.opacity(0.2), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}



struct ChecklistSectionView: View {
    let title: String
    @Binding var items: [ChecklistItem]
    let focusPrefix: String
    @FocusState var focusField: UUID?
    let onAdd: () -> Void
    let onRemove: (ChecklistItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline)
            ForEach(items) { item in
                HStack(spacing: 4) {
                    TextField("Пункт...", text: binding(for: item))
                        .focused($focusField, equals: item.id)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                    Button(action: { onRemove(item) }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(items.count > 1 ? .red : .gray)
                    }
                    .disabled(items.count == 1)
                }
            }
            Button(action: onAdd) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("Добавить пункт")
                }
                .font(.subheadline)
            }
        }
    }

    private func binding(for item: ChecklistItem) -> Binding<String> {
        guard let idx = items.firstIndex(of: item) else {
            return .constant("")
        }
        return Binding(
            get: { items[idx].text },
            set: { items[idx].text = $0 }
        )
    }
}

struct PostFormView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: PostFormViewModel
    @FocusState private var goodFocus: UUID?
    @FocusState private var badFocus: UUID?

    init(
        store: PostStore,
        title: String = "Создать отчёт",
        post: Post? = nil,
        onSave: (() -> Void)? = nil,
        onPublish: (() -> Void)? = nil
    ) {
        self._viewModel = StateObject(wrappedValue: PostFormViewModel(
            store: store,
            title: title,
            post: post,
            onSave: onSave,
            onPublish: onPublish
        ))
    }

    var body: some View {
        if viewModel.isReportDone {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
                Text("Время создания локального отчета на сегодня подошло к концу.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Text("Ждите наступления следующего дня — тогда снова появится возможность создать или редактировать отчет.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
        } else {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // --- ЗОНА ЛОБ/БОЛ ---
                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                HStack(spacing: 0) {
                                    Button(action: {
                                        viewModel.selectedTab = .good
                                        viewModel.pickerIndexGood = 0
                                    }) {
                                        HStack(spacing: 2) {
                                            Text("👍 молодец")
                                                .font(
                                                    .system(
                                                        size: 14.3,
                                                        weight: .bold
                                                    )
                                                )
                                                .foregroundColor(
                                                    viewModel.selectedTab == .good
                                                        ? .green : .primary
                                                )
                                            Text("(")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                            Text(
                                                "\(viewModel.goodItems.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count)"
                                            )
                                            .font(.system(size: 14.3))
                                            .foregroundColor(.secondary)
                                            Text(")")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            viewModel.selectedTab == .good
                                                ? Color.green.opacity(0.12)
                                                : Color.clear
                                        )
                                        .cornerRadius(8)
                                    }
                                    Button(action: {
                                        viewModel.selectedTab = .bad
                                        viewModel.pickerIndexBad = 0
                                    }) {
                                        HStack(spacing: 2) {
                                            Text("👎 лаботряс")
                                                .font(
                                                    .system(
                                                        size: 14.3,
                                                        weight: .bold
                                                    )
                                                )
                                                .foregroundColor(
                                                    viewModel.selectedTab == .bad
                                                        ? .red : .primary
                                                )
                                            Text("(")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                            Text(
                                                "\(viewModel.badItems.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count)"
                                            )
                                            .font(.system(size: 14.3))
                                            .foregroundColor(.secondary)
                                            Text(")")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            viewModel.selectedTab == .bad
                                                ? Color.red.opacity(0.12)
                                                : Color.clear
                                        )
                                        .cornerRadius(8)
                                    }
                                }
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.vertical, 2)
                                .contentShape(Rectangle())
                            }
                        }
                        .padding(.bottom, 32)  // Ещё больший отступ
                        // --- ЗОНА WHEEL + КНОПКА + ТЕГИ ---
                        VStack(spacing: 0) {
                            let allTags: [TagItem] =
                                viewModel.selectedTab == .good ? viewModel.goodTags : viewModel.badTags
                            let pickerIndex: Binding<Int> =
                                viewModel.selectedTab == .good
                                ? $viewModel.pickerIndexGood : $viewModel.pickerIndexBad
                            if !allTags.isEmpty {
                                VStack(spacing: 0) {
                                    HStack(alignment: .center, spacing: 6) {
                                        TagPickerUIKitWheel(
                                            tags: allTags,
                                            selectedIndex: pickerIndex
                                        ) { _ in }
                                        .frame(
                                            maxWidth: .infinity,
                                            minHeight: 120,
                                            maxHeight: 120
                                        )
                                        .id(viewModel.selectedTab)
                                        .clipped()
                                        let selectedTag = allTags[
                                            (viewModel.selectedTab == .good
                                                ? viewModel.pickerIndexGood : viewModel.pickerIndexBad)
                                        ]
                                        let isTagAdded =
                                            (viewModel.selectedTab == .good
                                            ? viewModel.goodItems : viewModel.badItems).contains(
                                                where: {
                                                    $0.text == selectedTag.text
                                                })
                                        Button(action: {
                                            if viewModel.selectedTab == .good {
                                                if !isTagAdded {
                                                    viewModel.addGoodTag(selectedTag)
                                                }
                                            } else {
                                                if !isTagAdded {
                                                    viewModel.addBadTag(selectedTag)
                                                }
                                            }
                                        }) {
                                            Image(
                                                systemName: isTagAdded
                                                    ? "checkmark.circle.fill"
                                                    : "plus.circle.fill"
                                            )
                                            .resizable()
                                            .frame(width: 28, height: 28)
                                            .foregroundColor(
                                                isTagAdded ? .green : .blue
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.horizontal, 4)
                                    .contentShape(Rectangle())
                                }
                                .padding(.bottom, 8)
                            }
                            /*
                            // --- Показываем все теги кирпичиками выше поля ввода ---
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(allTags) { tag in
                                        TagBrickView(tag: tag) { }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            */
                        }
                        .padding(.vertical, 6)
                        // --- ЗОНА ЧЕКЛИСТА ---
                        VStack(spacing: 0) {
                            if viewModel.selectedTab == .good {
                                ChecklistSectionView(
                                    title: "Я молодец:",
                                    items: $viewModel.goodItems,
                                    focusPrefix: "good",
                                    focusField: _goodFocus,
                                    onAdd: viewModel.addGoodItem,
                                    onRemove: viewModel.removeGoodItem
                                )
                            } else {
                                ChecklistSectionView(
                                    title: "Я не молодец:",
                                    items: $viewModel.badItems,
                                    focusPrefix: "bad",
                                    focusField: _badFocus,
                                    onAdd: viewModel.addBadItem,
                                    onRemove: viewModel.removeBadItem
                                )
                            }
                            // Восстанавливаем старую логику: добавление/удаление good/bad пункта по + и - через TagPicker и кнопки, без отдельного поля ввода
                            // --- Логика предложения сохранить тег ---
                            if let newText = (viewModel.selectedTab == .good ? viewModel.goodItems.last?.text : viewModel.badItems.last?.text),
                               !newText.trimmingCharacters(in: .whitespaces).isEmpty,
                               !(viewModel.selectedTab == .good ? viewModel.store.goodTags : viewModel.store.badTags).contains(newText) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("Сохранить тег?")
                                            .font(.headline)
                                        Text("\"\(newText)\"")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    HStack {
                                        Button("Отмена") {
                                            if viewModel.selectedTab == .good {
                                                viewModel.goodItems[viewModel.goodItems.count-1].text = ""
                                            } else {
                                                viewModel.badItems[viewModel.badItems.count-1].text = ""
                                            }
                                        }
                                        Button("Сохранить") {
                                            if viewModel.selectedTab == .good {
                                                viewModel.store.addGoodTag(newText)
                                            } else {
                                                viewModel.store.addBadTag(newText)
                                            }
                                            if viewModel.selectedTab == .good {
                                                viewModel.addGoodItem()
                                            } else {
                                                viewModel.addBadItem()
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 6)
                        // --- ЗОНА VOICE ---
                        VStack(spacing: 0) {
                            VoiceRecorderListView(voiceNotes: $viewModel.voiceNotes)
                        }
                        .padding(.vertical, 6)
                        // --- ЗОНА СТАТУСА/КНОПОК ---
                        VStack(spacing: 0) {
                            if viewModel.isSending {
                                ProgressView("Отправка в Telegram...")
                            }
                            if let status = viewModel.sendStatus {
                                Text(status)
                                    .font(.caption)
                                    .foregroundColor(
                                        status == "Успешно отправлено!"
                                            ? .green : .red
                                    )
                            }
                        }
                        .padding(.vertical, 6)
                        Spacer()
                    }
                    .frame(maxWidth: 360)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .hideKeyboardOnTap()
                .navigationTitle(viewModel.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        HStack() {
                            LargeButtonView(
                                title: "Сохранить",
                                icon: "tray.and.arrow.down.fill",
                                color: .blue,
                                action: viewModel.saveAndNotify,
                                isEnabled: canSave && !viewModel.isSending,
                                compact: true
                            )
                            LargeButtonView(
                                title: "Опубликовать",
                                icon: "paperplane.fill",
                                color: .green,
                                action: viewModel.publishAndNotify,
                                isEnabled: canPublish && !viewModel.isSending,
                                compact: true
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties
    var canSave: Bool {
        viewModel.goodItems.contains(where: {
            !$0.text.trimmingCharacters(in: .whitespaces).isEmpty
        })
            || viewModel.badItems.contains(where: {
                !$0.text.trimmingCharacters(in: .whitespaces).isEmpty
            })
    }

    var canPublish: Bool {
        viewModel.goodItems.contains(where: {
            !$0.text.trimmingCharacters(in: .whitespaces).isEmpty
        })
            && viewModel.badItems.contains(where: {
                !$0.text.trimmingCharacters(in: .whitespaces).isEmpty
            })
    }










}

#Preview {
    PostFormView(store: PostStore(), title: "Создать отчёт")
}

#Preview("PostFormView - Status Done") {
    let store = PostStore()
    store.reportStatus = .done
    return PostFormView(store: store)
}
