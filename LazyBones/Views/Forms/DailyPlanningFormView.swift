// DailyPlanningFormView.swift
// LazyBones
//
// Created by Денис Рюмин on 2025-07-10.

import SwiftUI

struct DailyPlanningFormView: View {
    @EnvironmentObject var store: PostStore
    @State private var selectedTab = 0 // По умолчанию открывается первый экран (третий экран)
    
    var postForToday: Post? {
        store.posts.first(where: { Calendar.current.isDateInToday($0.date) })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // --- Кастомный заголовок ---
            HStack {
                Text(getTitleForTab(selectedTab))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 4)
            // --- Индикаторы свайпа ---
            HStack(spacing: 8) {
                Circle()
                    .fill(selectedTab == 0 ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(selectedTab == 1 ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            .padding(.bottom, 4)
            // --- TabView ---
            TabView(selection: $selectedTab) {
                // Первый экран — отчет за день (с голосовыми заметками)
                DailyReportView()
                    .tag(0)
                // Второй экран — план на день
                PlanningContentView()
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
    
    private func getTitleForTab(_ tab: Int) -> String {
        switch tab {
        case 0: return "Отчет за день"
        case 1: return "План на день"
        default: return "Отчет за день"
        }
    }
}

// Весь старый функционал вынесен во вложенную вью
struct PlanningContentView: View {
    @EnvironmentObject var store: PostStore
    @State private var planItems: [String] = []
    @State private var newPlanItem: String = ""
    @State private var editingPlanIndex: Int? = nil
    @State private var editingPlanText: String = ""
    @State private var showSaveAlert = false
    @State private var showDeletePlanAlert = false
    @State private var planToDeleteIndex: Int? = nil
    @State private var lastPlanDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var publishStatus: String? = nil
    @State private var pickerIndex: Int = 0
    @State private var showTagPicker: Bool = false
    @State private var tagPickerOffset: CGFloat = 0
    
    var planTags: [TagItem] {
        store.goodTags.map { TagItem(text: $0, icon: "tag", color: .green) }
    }
    
    var body: some View {
        VStack {
            planSection
        }
        .hideKeyboardOnTap()
        .onAppear {
            loadPlan()
            lastPlanDate = Calendar.current.startOfDay(for: Date())
        }
        .onChange(of: Calendar.current.startOfDay(for: Date()), initial: false) { oldDay, newDay in
            if newDay != lastPlanDate {
                planItems = []
                savePlan()
                lastPlanDate = newDay
            }
        }
    }
    
    // MARK: - План
    var planSection: some View {
        VStack(spacing: 16) {
            // --- Список пунктов плана ---
            List {
                ForEach(planItems.indices, id: \.self) { idx in
                    HStack {
                        if editingPlanIndex == idx {
                            TextField("Пункт", text: $editingPlanText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button("OK") { finishEditPlanItem() }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Text(planItems[idx])
                            Spacer()
                            Button(action: { startEditPlanItem(idx) }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        Button(action: { planToDeleteIndex = idx; showDeletePlanAlert = true }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Поле ввода с TagPicker
            VStack(spacing: 8) {
                HStack {
                    TextField("Добавить пункт плана", text: $newPlanItem)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: { withAnimation(.easeInOut(duration: 0.3)) { showTagPicker.toggle() } }) {
                        Image(systemName: "tag")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    Button(action: addPlanItem) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }.disabled(newPlanItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                
                // TagPicker выезжает справа
                if showTagPicker, !planTags.isEmpty {
                    HStack(alignment: .center, spacing: 6) {
                        TagPickerUIKitWheel(
                            tags: planTags,
                            selectedIndex: $pickerIndex
                        ) { _ in }
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 120,
                            maxHeight: 160
                        )
                        .clipped()
                        
                        let selectedTag = planTags[pickerIndex]
                        let isTagAdded = planItems.contains(where: { $0 == selectedTag.text })
                        Button(action: {
                            if (!isTagAdded) {
                                planItems.append(selectedTag.text)
                                savePlan()
                            }
                        }) {
                            Image(systemName: isTagAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                                .resizable()
                                .frame(width: 28, height: 28)
                                .foregroundColor(isTagAdded ? .green : .blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                
                // Показываем prompt для сохранения тега
                if !newPlanItem.isEmpty && !store.goodTags.contains(newPlanItem) {
                    HStack {
                        Text("Сохранить тег?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Сохранить") {
                            store.goodTags.append(newPlanItem)
                            store.saveGoodTags(store.goodTags)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                }
            }
            
            // Кнопки действий
            if !planItems.isEmpty {
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
                        title: "Отправить",
                        icon: "paperplane.fill",
                        color: .green,
                        action: { publishCustomReportToTelegram() },
                        isEnabled: true,
                        compact: true
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
                if let status = publishStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(status.contains("успешно") ? .green : .red)
                }
            }
        }
        .padding()
        .alert("Сохранить план как отчет?", isPresented: $showSaveAlert) {
            Button("Сохранить", role: .none) { savePlanAsReport() }
            Button("Отмена", role: .cancel) { }
        }
        .alert("Удалить пункт плана?", isPresented: $showDeletePlanAlert) {
            Button("Удалить", role: .destructive) { deletePlanItem() }
            Button("Отмена", role: .cancel) { planToDeleteIndex = nil }
        }
    }
    
    // MARK: - Functions
    func addPlanItem() {
        let trimmed = newPlanItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        planItems.append(trimmed)
        newPlanItem = ""
        savePlan()
    }
    
    func startEditPlanItem(_ idx: Int) {
        editingPlanIndex = idx
        editingPlanText = planItems[idx]
    }
    
    func finishEditPlanItem() {
        guard let idx = editingPlanIndex else { return }
        let trimmed = editingPlanText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        planItems[idx] = trimmed
        editingPlanIndex = nil
        editingPlanText = ""
        savePlan()
    }
    
    func deletePlanItem() {
        guard let idx = planToDeleteIndex else { return }
        planItems.remove(at: idx)
        planToDeleteIndex = nil
        savePlan()
    }
    
    func savePlan() {
        let key = "plan_" + DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if let data = try? JSONEncoder().encode(planItems) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func loadPlan() {
        let key = "plan_" + DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            planItems = decoded
        } else {
            planItems = []
        }
    }
    
    func savePlanAsReport() {
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = store.posts.firstIndex(where: { $0.type == .custom && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            let updated = Post(
                id: store.posts[idx].id,
                date: Date(),
                goodItems: planItems,
                badItems: [],
                published: false,
                voiceNotes: [],
                type: .custom,
                authorUsername: nil,
                authorFirstName: nil,
                authorLastName: nil,
                isExternal: false,
                externalVoiceNoteURLs: nil,
                externalText: nil,
                externalMessageId: nil,
                authorId: nil
            )
            store.posts[idx] = updated
            store.save()
        } else {
            let post = Post(
                id: UUID(),
                date: Date(),
                goodItems: planItems,
                badItems: [],
                published: false,
                voiceNotes: [],
                type: .custom,
                authorUsername: nil,
                authorFirstName: nil,
                authorLastName: nil,
                isExternal: false,
                externalVoiceNoteURLs: nil,
                externalText: nil,
                externalMessageId: nil,
                authorId: nil
            )
            store.add(post: post)
        }
        savePlan()
    }
    
    func publishCustomReportToTelegram() {
        Task { @MainActor in
            let today = Calendar.current.startOfDay(for: Date())

            // Загружаем кастомный отчет на сегодня из репозитория, чтобы видеть актуальный isEvaluated
            var domainCustom: DomainPost?
            if let useCase = DependencyContainer.shared.resolve(GetReportsUseCase.self) {
                do {
                    let input = GetReportsInput(date: Date(), type: .custom, includeExternal: false)
                    let customs = try await useCase.execute(input: input)
                    domainCustom = customs.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
                } catch {
                    Logger.error("Failed to load custom reports for sending: \(error)", log: Logger.ui)
                }
            } else {
                // DI недоступен: используем legacy store
                if let idx = store.posts.firstIndex(where: { $0.type == .custom && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
                    let legacy = store.posts[idx]
                    domainCustom = legacy.toDomain()
                }
            }

            guard let customDomain = domainCustom else {
                publishStatus = "Сначала сохраните план как отчет!"
                return
            }
            guard customDomain.isEvaluated == true else {
                publishStatus = "Сначала оцените план!"
                return
            }
            guard !customDomain.goodItems.isEmpty else {
                publishStatus = "Сначала сохраните план как отчет!"
                return
            }

            // Формируем сообщение через интеграцию, используя legacy-модель
            let legacyPost = customDomain.toLegacy()
            let deviceName = store.getDeviceName()
            let message = store.telegramIntegrationService.formatCustomReportForTelegram(legacyPost, deviceName: deviceName)

            guard let postTelegramService = DependencyContainer.shared.resolve(PostTelegramServiceProtocol.self) else {
                self.publishStatus = "Ошибка: сервис Telegram не найден"
                return
            }

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                postTelegramService.sendToTelegram(text: message) { success in
                    DispatchQueue.main.async {
                        if success {
                            self.publishStatus = "План успешно опубликован!"
                        } else {
                            self.publishStatus = "Ошибка отправки: проверьте токен и chat_id в настройках"
                        }
                        continuation.resume()
                    }
                }
            }

            // При успехе — отмечаем как опубликованный через UseCase
            if publishStatus == "План успешно опубликован!" {
                if let updateUseCase = DependencyContainer.shared.resolve(UpdateReportUseCase.self) {
                    var updated = customDomain
                    updated.published = true
                    do {
                        let _ = try await updateUseCase.execute(input: UpdateReportInput(report: updated))
                    } catch {
                        Logger.error("Failed to mark custom report published: \(error)", log: Logger.ui)
                    }
                } else {
                    // Fallback: пометим в legacy store, чтобы UI обновился
                    if let idx = self.store.posts.firstIndex(where: { $0.id == legacyPost.id }) {
                        var lp = self.store.posts[idx]
                        lp.published = true
                        self.store.posts[idx] = lp
                        self.store.save()
                    }
                }
                NotificationCenter.default.post(name: .reportStatusDidChange, object: nil)
            }
        }
    }
}

#Preview {
    DailyPlanningFormView()
        .environmentObject(PostStore())
}
