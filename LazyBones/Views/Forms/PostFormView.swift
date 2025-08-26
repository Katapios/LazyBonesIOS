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

@available(*, deprecated, message: "Legacy form. Use CA-based flows (DailyPlanCAView/DailyReportCAView) instead")
struct PostFormView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: PostFormViewModel
    @FocusState private var goodFocus: UUID?
    @FocusState private var badFocus: UUID?
    @State private var tagsVersion: Int = 0
    @State private var goodWheelTags: [TagItem] = []

    // Нормализация тега: убираем возможные префиксы эмодзи и пробелы
    private func normalizeTag(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("✅ ") { return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
        if trimmed.hasPrefix("❌ ") { return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
        return trimmed
    }

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
                                            Text("\(goodNonEmptyCount)")
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
                                            Text("\(badNonEmptyCount)")
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
                            let allTags: [TagItem] = goodWheelTags.isEmpty ? viewModel.goodTags : goodWheelTags
                            let pickerIndex: Binding<Int> = $viewModel.pickerIndexGood
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
                                        .id("\(tagsVersion)")
                                        .clipped()
                                        if let tag = currentSelectedGoodTag(allTags) {
                                            let added = isGoodTagAlreadyAdded(tag)
                                            Button(action: {
                                                if !added { viewModel.addGoodTag(tag) }
                                            }) {
                                                Image(
                                                    systemName: added
                                                        ? "checkmark.circle.fill"
                                                        : "plus.circle.fill"
                                                )
                                                .resizable()
                                                .frame(width: 28, height: 28)
                                                .foregroundColor(
                                                    added ? .green : .blue
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
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
                            if let newTextRaw = viewModel.goodItems.last?.text {
                                let newText = normalizeTag(newTextRaw)
                                let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                                let existsInProvider = provider?.goodTags.contains(newText) ?? false
                                if !newText.isEmpty, !existsInProvider {
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
                                            viewModel.goodItems[viewModel.goodItems.count-1].text = ""
                                        }
                                        Button("Сохранить") {
                                            let trimmed = newText.trimmingCharacters(in: .whitespaces)
                                            Task {
                                                let repo = DependencyContainer.shared.resolve(TagRepositoryProtocol.self)
                                                let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                                                try? await repo?.addGoodTag(trimmed)
                                                await provider?.refresh()
                                                await MainActor.run {
                                                    // Обновляем локальный источник колесика из провайдера
                                                    let arr = provider?.goodTags ?? []
                                                    goodWheelTags = arr.map { TagItem(text: $0, icon: "tag", color: .green) }
                                                    // Выбираем сохранённый тег, если он есть
                                                    if let idx = arr.firstIndex(of: trimmed) {
                                                        viewModel.pickerIndexGood = idx
                                                    } else {
                                                        viewModel.pickerIndexGood = 0
                                                    }
                                                    // Форс перерисовку и подготовить следующий пустой пункт
                                                    tagsVersion += 1
                                                    viewModel.addGoodItem()
                                                }
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
                        }
                        .padding(.vertical, 6)
                        // --- ЗОНА VOICE ---
                        VStack(spacing: 8) {
                            if !viewModel.voiceNotes.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(viewModel.voiceNotes) { note in
                                        VoiceRecorderRowClean(
                                            initialPath: note.path,
                                            onVoiceNoteChanged: { newPath in
                                                if let newPath = newPath {
                                                    if let idx = viewModel.voiceNotes.firstIndex(where: { $0.id == note.id }) {
                                                        viewModel.voiceNotes[idx].path = newPath
                                                    }
                                                } else {
                                                    if let idx = viewModel.voiceNotes.firstIndex(where: { $0.id == note.id }) {
                                                        viewModel.voiceNotes.remove(at: idx)
                                                    }
                                                }
                                            },
                                            isFirst: viewModel.voiceNotes.first?.id == note.id
                                        )
                                    }
                                }
                            } else {
                                HStack {
                                    Image(systemName: "mic.slash").foregroundColor(.gray)
                                    Text("Создайте первую голосовую заметку")
                                        .foregroundColor(.gray)
                                        .font(.subheadline)
                                }
                                .padding(.vertical, 8)
                            }
                            Button(action: {
                                viewModel.voiceNotes.append(VoiceNote(id: UUID(), path: ""))
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Добавить голосовую заметку")
                                }
                            }
                            .padding(.top, 4)
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
                .task {
                    // Инициализируем колесо актуальными тегами при открытии
                    let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                    await provider?.refresh()
                    await MainActor.run {
                        goodWheelTags = (provider?.goodTags ?? []).map { TagItem(text: $0, icon: "tag", color: .green) }
                        tagsVersion += 1
                        if let idx = provider?.goodTags.firstIndex(of: normalizeTag(viewModel.goodItems.last?.text ?? "")) {
                            viewModel.pickerIndexGood = idx
                        }
                    }
                }
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

    // MARK: - Simple counters to reduce inline complexity
    private var goodNonEmptyCount: Int {
        viewModel.goodItems.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    private var badNonEmptyCount: Int {
        viewModel.badItems.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    // MARK: - Helpers for TagPicker (good)
    private func currentSelectedGoodTag(_ allTags: [TagItem]) -> TagItem? {
        guard !allTags.isEmpty else { return nil }
        let idx = min(max(0, viewModel.pickerIndexGood), max(allTags.count - 1, 0))
        return allTags[idx]
    }

    private func isGoodTagAlreadyAdded(_ tag: TagItem) -> Bool {
        viewModel.goodItems.contains { normalizeTag($0.text) == tag.text }
    }








}

#Preview {
    PostFormView(store: PostStore(), title: "Создать отчёт")
}

#Preview("PostFormView - Status Done") {
    let store = PostStore()
    store.reportStatus = .sent
    return PostFormView(store: store)
}
