import SwiftUI

/// Форма создания/редактирования обычного отчета с полной функциональностью
struct RegularReportFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: PostStore
    @State private var goodItems: [ChecklistItem]
    @State private var badItems: [ChecklistItem]
    @State private var voiceNotes: [VoiceNote]
    @FocusState private var goodFocus: UUID?
    @FocusState private var badFocus: UUID?
    var title: String = "Создать отчёт"
    var post: Post? = nil
    var onSave: (() -> Void)? = nil
    var onPublish: (() -> Void)? = nil
    @State private var isSending: Bool = false
    @State private var sendStatus: String? = nil
    @State private var selectedTab: TabType = .good
    enum TabType { case good, bad }
    @State private var pickerIndexGood: Int = 0
    @State private var pickerIndexBad: Int = 0

    // MARK: - Глобальные теги
    private var goodTags: [TagItem] {
        store.goodTags.map { TagItem(text: $0, icon: "tag", color: .green) }
    }
    private var badTags: [TagItem] {
        store.badTags.map { TagItem(text: $0, icon: "tag", color: .red) }
    }

    init(
        title: String = "Создать отчёт",
        post: Post? = nil,
        onSave: (() -> Void)? = nil,
        onPublish: (() -> Void)? = nil
    ) {
        self.title = title
        self.post = post
        self.onSave = onSave
        self.onPublish = onPublish
        if let post = post {
            _goodItems = State(
                initialValue: post.goodItems.map {
                    ChecklistItem(id: UUID(), text: $0)
                }
            )
            _badItems = State(
                initialValue: post.badItems.map {
                    ChecklistItem(id: UUID(), text: $0)
                }
            )
            _voiceNotes = State(initialValue: post.voiceNotes)
            self.title = "Редактирование отчёта"
        } else {
            _goodItems = State(initialValue: [
                ChecklistItem(id: UUID(), text: "")
            ])
            _badItems = State(initialValue: [
                ChecklistItem(id: UUID(), text: "")
            ])
            _voiceNotes = State(initialValue: [])
            self.title = "Создание отчёта"
        }
    }

    var body: some View {
        if store.reportStatus == .sent || store.reportStatus == .notCreated || store.reportStatus == .notSent {
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
                                        selectedTab = .good
                                        pickerIndexGood = 0
                                    }) {
                                        HStack(spacing: 2) {
                                            Text("👍 молодец")
                                                .font(.system(size: 14.3, weight: .bold))
                                                .foregroundColor(selectedTab == .good ? .green : .primary)
                                            Text("(")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                            Text("\(goodItems.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count)")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                            Text(")")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(selectedTab == .good ? Color.green.opacity(0.12) : Color.clear)
                                        .cornerRadius(8)
                                    }
                                    Button(action: {
                                        selectedTab = .bad
                                        pickerIndexBad = 0
                                    }) {
                                        HStack(spacing: 2) {
                                            Text("👎 лаботряс")
                                                .font(.system(size: 14.3, weight: .bold))
                                                .foregroundColor(selectedTab == .bad ? .red : .primary)
                                            Text("(")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                            Text("\(badItems.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count)")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                            Text(")")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(selectedTab == .bad ? Color.red.opacity(0.12) : Color.clear)
                                        .cornerRadius(8)
                                    }
                                }
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.vertical, 2)
                                .contentShape(Rectangle())
                            }
                        }
                        .padding(.bottom, 32)

                        // --- ЗОНА WHEEL + КНОПКА + ТЕГИ ---
                        VStack(spacing: 0) {
                            let allTags: [TagItem] = selectedTab == .good ? goodTags : badTags
                            let pickerIndex: Binding<Int> = selectedTab == .good ? $pickerIndexGood : $pickerIndexBad
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
                                        .id(selectedTab)
                                        .clipped()
                                        
                                        let selectedTag = allTags[(selectedTab == .good ? pickerIndexGood : pickerIndexBad)]
                                        let isTagAdded = (selectedTab == .good ? goodItems : badItems).contains(where: { $0.text == selectedTag.text })
                                        Button(action: {
                                            if selectedTab == .good {
                                                if !isTagAdded {
                                                    addGoodTag(selectedTag)
                                                }
                                            } else {
                                                if !isTagAdded {
                                                    addBadTag(selectedTag)
                                                }
                                            }
                                        }) {
                                            Image(systemName: isTagAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                                                .resizable()
                                                .frame(width: 28, height: 28)
                                                .foregroundColor(isTagAdded ? .green : .blue)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.horizontal, 4)
                                    .contentShape(Rectangle())
                                }
                                .padding(.bottom, 8)
                            }
                        }
                        .padding(.vertical, 6)

                        // --- ЗОНА ЧЕКЛИСТА ---
                        VStack(spacing: 0) {
                            if selectedTab == .good {
                                ChecklistSectionView(
                                    title: "Я молодец:",
                                    items: $goodItems,
                                    focusPrefix: "good",
                                    focusField: _goodFocus,
                                    onAdd: addGoodItem,
                                    onRemove: removeGoodItem
                                )
                            } else {
                                ChecklistSectionView(
                                    title: "Я не молодец:",
                                    items: $badItems,
                                    focusPrefix: "bad",
                                    focusField: _badFocus,
                                    onAdd: addBadItem,
                                    onRemove: removeBadItem
                                )
                            }
                            
                            // --- Логика предложения сохранить тег ---
                            if let newText = (selectedTab == .good ? goodItems.last?.text : badItems.last?.text),
                               !newText.trimmingCharacters(in: .whitespaces).isEmpty,
                               !(selectedTab == .good ? store.goodTags : store.badTags).contains(newText) {
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
                                            if selectedTab == .good {
                                                goodItems[goodItems.count-1].text = ""
                                            } else {
                                                badItems[badItems.count-1].text = ""
                                            }
                                        }
                                        Button("Сохранить") {
                                            let tagText = newText
                                            Task { @MainActor in
                                                if let tagRepo = DependencyContainer.shared.resolve((any TagRepositoryProtocol).self) {
                                                    do {
                                                        if selectedTab == .good {
                                                            try await tagRepo.addGoodTag(tagText)
                                                            addGoodItem()
                                                        } else {
                                                            try await tagRepo.addBadTag(tagText)
                                                            addBadItem()
                                                        }
                                                    } catch {
                                                        Logger.error("Failed to save tag from RegularReportFormView: \(error)", log: Logger.ui)
                                                        // Fallback на legacy (не должно происходить)
                                                        if selectedTab == .good {
                                                            store.addGoodTag(tagText)
                                                            addGoodItem()
                                                        } else {
                                                            store.addBadTag(tagText)
                                                            addBadItem()
                                                        }
                                                    }
                                                } else {
                                                    // Fallback на legacy (не должно происходить)
                                                    if selectedTab == .good {
                                                        store.addGoodTag(tagText)
                                                        addGoodItem()
                                                    } else {
                                                        store.addBadTag(tagText)
                                                        addBadItem()
                                                    }
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
                        .padding(.vertical, 6)

                        // --- ЗОНА VOICE ---
                        VStack(spacing: 0) {
                            VoiceRecorderListView(voiceNotes: $voiceNotes)
                        }
                        .padding(.vertical, 6)

                        // --- ЗОНА СТАТУСА/КНОПОК ---
                        VStack(spacing: 0) {
                            if isSending {
                                ProgressView("Отправка в Telegram...")
                            }
                            // Сообщение статуса оставляем для совместимости,
                            // но наполнение теперь управляется новой архитектурой
                            if let status = sendStatus {
                                Text(status)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        HStack() {
                            LargeButtonView(
                                title: "Сохранить",
                                icon: "tray.and.arrow.down.fill",
                                color: .blue,
                                action: saveAndNotify,
                                isEnabled: canSave && !isSending,
                                compact: true
                            )
                            LargeButtonView(
                                title: "Опубликовать",
                                icon: "paperplane.fill",
                                color: .green,
                                action: publishAndNotify,
                                isEnabled: canPublish && !isSending,
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

    // MARK: - Actions
    func addGoodItem() {
        let new = ChecklistItem(id: UUID(), text: "")
        goodItems.append(new)
        print("[DEBUG] goodItems после добавления:", goodItems.map { $0.text })
        goodFocus = new.id
    }

    func addGoodTag(_ tag: TagItem) {
        if !goodItems.contains(where: { $0.text == tag.text }) {
            let new = ChecklistItem(id: UUID(), text: tag.text)
            goodItems.append(new)
        }
    }

    func addBadTag(_ tag: TagItem) {
        if !badItems.contains(where: { $0.text == tag.text }) {
            let new = ChecklistItem(id: UUID(), text: tag.text)
            badItems.append(new)
        }
    }

    func removeGoodItem(_ item: ChecklistItem) {
        guard goodItems.count > 1 else { return }
        if let idx = goodItems.firstIndex(of: item) {
            goodItems.remove(at: idx)
            if let current = goodFocus, current == item.id {
                let newIdx = min(idx, goodItems.count - 1)
                goodFocus = goodItems[newIdx].id
            }
        }
    }

    func addBadItem() {
        let new = ChecklistItem(id: UUID(), text: "")
        badItems.append(new)
        print("[DEBUG] badItems после добавления:", badItems.map { $0.text })
        badFocus = new.id
    }

    func removeBadItem(_ item: ChecklistItem) {
        guard badItems.count > 1 else { return }
        if let idx = badItems.firstIndex(of: item) {
            badItems.remove(at: idx)
            if let current = badFocus, current == item.id {
                let newIdx = min(idx, badItems.count - 1)
                badFocus = badItems[newIdx].id
            }
        }
    }

    var canSave: Bool {
        goodItems.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) ||
        badItems.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    var canPublish: Bool {
        goodItems.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) &&
        badItems.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    // MARK: - Icon Mapping
    private func getIconForItem(_ item: String, isGood: Bool) -> String {
        let lowercasedItem = item.lowercased()

        // Маппинг для "Я молодец"
        if isGood {
            if lowercasedItem.contains("не хлебил") { return "🚫" }
            if lowercasedItem.contains("не новостил") { return "📰" }
            if lowercasedItem.contains("не ел вредное") { return "🍴" }
            if lowercasedItem.contains("гулял") { return "🚶" }
            if lowercasedItem.contains("кодил") { return "💻" }
            if lowercasedItem.contains("рисовал") { return "🎨" }
            if lowercasedItem.contains("читал") { return "📚" }
            if lowercasedItem.contains("смотрел туториалы") { return "▶️" }
        }
        // Маппинг для "Я не молодец"
        else {
            if lowercasedItem.contains("хлебил") { return "❌" }
            if lowercasedItem.contains("новостил") { return "📰" }
            if lowercasedItem.contains("ел вредное") { return "🍴" }
            if lowercasedItem.contains("не гулял") { return "🚶" }
            if lowercasedItem.contains("не кодил") { return "💻" }
            if lowercasedItem.contains("не рисовал") { return "🎨" }
            if lowercasedItem.contains("не читал") { return "📚" }
            if lowercasedItem.contains("не смотрел туториалы") { return "▶️" }
        }

        // Дефолтные иконки для нераспознанных пунктов
        return isGood ? "✅" : "❌"
    }

    // MARK: - Save and Publish
    func saveAndNotify() {
        let filteredGood = goodItems.map { $0.text }.filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let filteredBad = badItems.map { $0.text }.filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let today = Calendar.current.startOfDay(for: Date())
        
        // Удалить все обычные отчёты за сегодня
        store.posts.removeAll {
            $0.type == .regular && Calendar.current.isDate($0.date, inSameDayAs: today)
        }
        
        // Добавить новый отчёт
        let newPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: filteredGood,
            badItems: filteredBad,
            published: false,
            voiceNotes: voiceNotes,
            type: .regular
        )
        store.add(post: newPost)
        onSave?()
        dismiss()
    }

    func publishAndNotify() {
        let filteredGood = goodItems.map { $0.text }.filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let filteredBad = badItems.map { $0.text }.filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let draftPost = Post(
            id: post?.id ?? UUID(),
            date: Date(),
            goodItems: filteredGood,
            badItems: filteredBad,
            published: false,
            voiceNotes: voiceNotes,
            type: .regular
        )

        // Сохраняем черновик в legacy store (для UI совместимости)
        if post != nil {
            store.update(post: draftPost)
        } else {
            store.add(post: draftPost)
        }

        // Отправляем через новую архитектуру
        isSending = true
        sendStatus = nil
        Task { @MainActor in
            guard
                let getUC = DependencyContainer.shared.resolve(GetReportsUseCase.self),
                let delUC = DependencyContainer.shared.resolve(DeleteReportUseCase.self),
                let updUC = DependencyContainer.shared.resolve(UpdateReportUseCase.self),
                let tagRepo = DependencyContainer.shared.resolve((any TagRepositoryProtocol).self),
                let postTg = DependencyContainer.shared.resolve(PostTelegramServiceProtocol.self)
            else {
                self.isSending = false
                self.sendStatus = "Ошибка DI: зависимости не найдены"
                return
            }

            let vm = ReportsViewModelNew(
                getReportsUseCase: getUC,
                deleteReportUseCase: delUC,
                updateReportUseCase: updUC,
                tagRepository: tagRepo,
                postTelegramService: postTg
            )

            let domainPost = PostAdapter.toDomain(draftPost)
            await vm.handle(.sendRegularReport(domainPost))

            // Обновление UI статуса: успешность/ошибка читаем из vm.state.error
            if vm.state.error == nil {
                self.sendStatus = "Успешно отправлено!"
                self.onPublish?()
                self.dismiss()
            } else {
                self.sendStatus = "Ошибка отправки"
            }
            self.isSending = false
        }
    }

    // Легаси отправка в Telegram удалена. Публикация производится через ReportsViewModelNew.
}

#Preview {
    RegularReportFormView(title: "Создать отчёт")
        .environmentObject(PostStore())
}

#Preview("RegularReportFormView - Status Done") {
    RegularReportFormView()
        .environmentObject(createStoreWithDoneStatus())
}

private func createStoreWithDoneStatus() -> PostStore {
    let store = PostStore()
    store.reportStatus = .sent
    return store
} 