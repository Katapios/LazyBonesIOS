import SwiftUI

struct DailyReportCAView: View {
    @EnvironmentObject var store: PostStore
    @StateObject private var viewModel = DailyReportCAViewModel()
    @State private var showVoiceRecorder: Bool = false
    @State private var editingIndex: Int? = nil
    @State private var editingText: String = ""
    @State private var tagsVersion: Int = 0
    @State private var showSaveAlert: Bool = false

    private func normalizeTag(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Источник тегов для колеса: используем TagProvider из DI (как в легаси)
    private var planTags: [TagItem] {
        let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
        if viewModel.selectedTab == 0 {
            return (provider?.goodTags ?? []).map { TagItem(text: $0, icon: "tag", color: .green) }
        } else {
            return (provider?.badTags ?? []).map { TagItem(text: $0, icon: "tag", color: .red) }
        }
    }

    var body: some View {
        Group {
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
                VStack(spacing: 16) {
                    // --- Список пунктов ---
                    List {
                        if viewModel.selectedTab == 0 {
                            ForEach(viewModel.goodItems.indices, id: \.self) { idx in
                                HStack {
                                    if editingIndex == idx {
                                        TextField("Пункт", text: $editingText)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                        Button("OK") {
                                            let t = editingText.trimmingCharacters(in: .whitespaces)
                                            guard !t.isEmpty else { editingIndex = nil; return }
                                            viewModel.goodItems[idx] = t
                                            editingIndex = nil
                                            editingText = ""
                                            viewModel.saveDraft()
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    } else {
                                        Text(viewModel.goodItems[idx])
                                        Spacer()
                                        Button(action: { editingIndex = idx; editingText = viewModel.goodItems[idx] }) {
                                            Image(systemName: "pencil")
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    Button(action: { viewModel.goodItems.remove(at: idx); viewModel.saveDraft() }) {
                                        Image(systemName: "trash").foregroundColor(.red)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        } else {
                            ForEach(viewModel.badItems.indices, id: \.self) { idx in
                                HStack {
                                    if editingIndex == idx {
                                        TextField("Пункт", text: $editingText)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                        Button("OK") {
                                            let t = editingText.trimmingCharacters(in: .whitespaces)
                                            guard !t.isEmpty else { editingIndex = nil; return }
                                            viewModel.badItems[idx] = t
                                            editingIndex = nil
                                            editingText = ""
                                            viewModel.saveDraft()
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    } else {
                                        Text(viewModel.badItems[idx])
                                        Spacer()
                                        Button(action: { editingIndex = idx; editingText = viewModel.badItems[idx] }) {
                                            Image(systemName: "pencil")
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    Button(action: { viewModel.badItems.remove(at: idx); viewModel.saveDraft() }) {
                                        Image(systemName: "trash").foregroundColor(.red)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }

                    // Поле ввода с иконками микрофона и тега
                    VStack(spacing: 8) {
                        HStack {
                            if viewModel.selectedTab == 0 {
                                TextField("Добавить пункт плана", text: $viewModel.newGoodText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            } else {
                                TextField("Добавить пункт плана", text: $viewModel.newBadText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }

                            HStack(spacing: 8) {
                                // Голосовой ввод (распознавание речи)
                                if viewModel.selectedTab == 0 {
                                    VoiceInputButton(
                                        text: $viewModel.newGoodText,
                                        isGood: true
                                    )
                                } else {
                                    VoiceInputButton(
                                        text: $viewModel.newBadText,
                                        isGood: false
                                    )
                                }
                                
                                // Запись аудио (старая кнопка)
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showVoiceRecorder.toggle()
                                        if showVoiceRecorder { viewModel.showTagPicker = false }
                                    }
                                }) {
                                    Image(systemName: "waveform.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(showVoiceRecorder ? .red : .accentColor)
                                }

                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        viewModel.showTagPicker.toggle()
                                        if viewModel.showTagPicker { showVoiceRecorder = false }
                                        // При открытии — обновляем провайдера и пересоздаем колесо
                                        if viewModel.showTagPicker {
                                            Task {
                                                let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                                                await provider?.refresh()
                                                await MainActor.run { tagsVersion &+= 1 }
                                            }
                                        }
                                    }
                                }) {
                                    Image(systemName: "tag.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(viewModel.showTagPicker ? .blue : .accentColor)
                                }
                            }

                            Button(action: {
                                if viewModel.selectedTab == 0 { viewModel.addGood() } else { viewModel.addBad() }
                            }) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 32))
                            }
                            .disabled(
                                viewModel.selectedTab == 0
                                ? viewModel.newGoodText.trimmingCharacters(in: .whitespaces).isEmpty
                                : viewModel.newBadText.trimmingCharacters(in: .whitespaces).isEmpty
                            )
                        }

                        // --- Переключатель good/bad с подсчетом ---
                        HStack {
                            Spacer()
                            HStack(spacing: 0) {
                                Button(action: {
                                    viewModel.selectedTab = 0
                                    viewModel.pickerIndex = 0
                                }) {
                                    HStack(spacing: 2) {
                                        Text("👍 молодец")
                                            .font(.system(size: 14.3, weight: .bold))
                                            .foregroundColor(viewModel.selectedTab == 0 ? .green : .primary)
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
                                    .background(viewModel.selectedTab == 0 ? Color.green.opacity(0.12) : Color.clear)
                                    .cornerRadius(8)
                                }
                                Button(action: {
                                    viewModel.selectedTab = 1
                                    viewModel.pickerIndex = 0
                                }) {
                                    HStack(spacing: 2) {
                                        Text("👎 лаботряс")
                                            .font(.system(size: 14.3, weight: .bold))
                                            .foregroundColor(viewModel.selectedTab == 1 ? .red : .primary)
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
                                    .background(viewModel.selectedTab == 1 ? Color.red.opacity(0.12) : Color.clear)
                                    .cornerRadius(8)
                                }
                            }
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                        }
                        .padding(.vertical, 6)

                        // TagPicker колесо
                        if viewModel.showTagPicker, !planTags.isEmpty {
                            HStack(alignment: .center, spacing: 6) {
                                TagPickerUIKitWheel(
                                    tags: planTags,
                                    selectedIndex: $viewModel.pickerIndex
                                ) { _ in }
                                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 160)
                                .clipped()

                                if let tag = currentSelectedPlanTag(from: planTags) {
                                    let added = isPlanTagAlreadyAdded(tag)
                                    Button(action: {
                                        if !added {
                                            if viewModel.selectedTab == 0 {
                                                viewModel.goodItems.append(tag.text)
                                            } else {
                                                viewModel.badItems.append(tag.text)
                                            }
                                            viewModel.saveDraft()
                                        }
                                    }) {
                                        Image(systemName: added ? "checkmark.circle.fill" : "plus.circle.fill")
                                            .resizable()
                                            .frame(width: 28, height: 28)
                                            .foregroundColor(added ? .green : .blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .id("\(viewModel.selectedTab)-\(tagsVersion)")
                        }

                        // VoiceRecorder блок
                        if showVoiceRecorder {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Голосовые заметки").font(.headline)
                                    Spacer()
                                    Button(action: { withAnimation(.easeInOut(duration: 0.3)) { showVoiceRecorder = false } }) {
                                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                    }
                                }
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
                                                    viewModel.saveDraft()
                                                },
                                                isFirst: viewModel.voiceNotes.first?.id == note.id
                                            )
                                        }
                                    }
                                    .padding(.vertical, 4)
                                } else {
                                    HStack {
                                        Image(systemName: "mic.slash").foregroundColor(.gray)
                                        Text("Создайте первую голосовую заметку на сегодня").foregroundColor(.gray).font(.subheadline)
                                    }
                                    .padding(.vertical, 8)
                                }
                                Button(action: {
                                    viewModel.voiceNotes.append(VoiceNote(id: UUID(), path: ""))
                                    viewModel.saveDraft()
                                }) {
                                    HStack { Image(systemName: "plus.circle.fill"); Text("Добавить голосовую заметку") }
                                        .foregroundColor(.blue)
                                }
                                .padding(.top, 4)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }

                    // Prompt «Сохранить тег?» как в легаси
                    Group {
                        let inputText = (viewModel.selectedTab == 0 ? viewModel.newGoodText : viewModel.newBadText).trimmingCharacters(in: .whitespacesAndNewlines)
                        let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                        let existing = viewModel.selectedTab == 0 ? (provider?.goodTags ?? []) : (provider?.badTags ?? [])
                        if !inputText.isEmpty && !existing.contains(inputText) {
                            HStack {
                                Text("Сохранить тег?")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Сохранить") {
                                    Task {
                                        let repo = DependencyContainer.shared.resolve(TagRepositoryProtocol.self)
                                        if viewModel.selectedTab == 0 {
                                            try? await repo?.addGoodTag(inputText)
                                        } else {
                                            try? await repo?.addBadTag(inputText)
                                        }
                                        let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                                        await provider?.refresh()
                                        await MainActor.run { tagsVersion &+= 1 }
                                        // Затем добавляем пункт
                                        if viewModel.selectedTab == 0 { viewModel.addGood() } else { viewModel.addBad() }
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                        }
                    }

                    // Кнопки действий
                    if !viewModel.goodItems.isEmpty || !viewModel.badItems.isEmpty {
                        HStack(spacing: 12) {
                            LargeButtonView(
                                title: "Сохранить",
                                icon: "tray.and.arrow.down.fill",
                                color: .blue,
                                action: { showSaveAlert = true },
                                isEnabled: true,
                                compact: true
                            )
                            LargeButtonView(
                                title: viewModel.isPublishing ? "Отправка..." : "Отправить",
                                icon: "paperplane.fill",
                                color: .green,
                                action: { viewModel.publishToTelegram() },
                                isEnabled: !viewModel.isPublishing,
                                compact: true
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                        if let status = viewModel.publishStatus {
                            Text(status).font(.caption).foregroundColor(status.contains("успешно") ? .green : (status.contains("ошибка") ? .red : .secondary))
                        }
                    }
                }
                .hideKeyboardOnTap()
                .padding()
                .alert("Сохранить план как отчет?", isPresented: $showSaveAlert) {
                    Button("Да") { viewModel.saveAsLocalReport() }
                    Button("Нет") { viewModel.saveDraft() }
                } message: {
                    Text("Сохранить текущий план как локальный отчет за сегодня?")
                }
                .onAppear {
                    viewModel.onAppear()
                    // 1:1 — сразу перезагружаем провайдер и пересоздаём колесо
                    Task {
                        let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                        await provider?.refresh()
                        await MainActor.run { tagsVersion &+= 1 }
                    }
                }
                .onChange(of: viewModel.selectedTab, initial: false) { _, _ in
                    // Переключение good/bad — пересоздаём колесо и сбрасываем индекс
                    viewModel.pickerIndex = 0
                    tagsVersion &+= 1
                }
            }
        }
    }

    // MARK: - Helpers to reduce type-checking complexity
    private var goodNonEmptyCount: Int {
        TagHelpers.nonEmptyCount(in: viewModel.goodItems)
    }

    private var badNonEmptyCount: Int {
        TagHelpers.nonEmptyCount(in: viewModel.badItems)
    }

    private func currentSelectedPlanTag(from tags: [TagItem]) -> TagItem? {
        TagHelpers.selectedTag(from: tags, pickerIndex: viewModel.pickerIndex)
    }

    private func isPlanTagAlreadyAdded(_ tag: TagItem) -> Bool {
        if viewModel.selectedTab == 0 {
            return TagHelpers.isTagTextAdded(tag, in: viewModel.goodItems)
        } else {
            return TagHelpers.isTagTextAdded(tag, in: viewModel.badItems)
        }
    }
}

// Простой FlowLayout для отображения тегов в строках
struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        _VariadicView.Tree(FlowLayoutRoot(spacing: spacing), content: content)
    }
}

private struct FlowLayoutRoot: _VariadicView_UnaryViewRoot {
    let spacing: CGFloat
    func body(children: _VariadicView.Children) -> some View {
        return GeometryReader { geometry in
            var x: CGFloat = 0
            var y: CGFloat = 0
            ZStack(alignment: .topLeading) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    child
                        .alignmentGuide(.leading) { d in
                            if (abs(x - d.width) > geometry.size.width) {
                                x = 0
                                y -= d.height + spacing
                            }
                            let result = x
                            if child.id == children.last?.id { x = 0 } else { x -= d.width + spacing }
                            return result
                        }
                        .alignmentGuide(.top) { d in
                            let result = y
                            if child.id == children.last?.id { y = 0 } else { }
                            return result
                        }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    DailyReportCAView().environmentObject(PostStore())
}
