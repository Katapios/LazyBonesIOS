// DailyPlanningFormView.swift
// LazyBones
//
// Created by Денис Рюмин on 2025-07-10.

import SwiftUI

struct DailyPlanningFormView: View {
    @EnvironmentObject var store: PostStore
    @State private var selectedTab = 0 // 0 — План, 1 — Теги
    @State private var planItems: [String] = []
    @State private var newPlanItem: String = ""
    @State private var editingPlanIndex: Int? = nil
    @State private var editingPlanText: String = ""
    @State private var newTag: String = ""
    @State private var editingTagIndex: Int? = nil
    @State private var editingTagText: String = ""
    @State private var showSaveAlert = false
    @State private var showDeletePlanAlert = false
    @State private var showDeleteTagAlert = false
    @State private var tagToDelete: String? = nil
    @State private var planToDeleteIndex: Int? = nil
    @State private var tagCategory: Int = 0 // 0 — good, 1 — bad
    @State private var lastPlanDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var publishStatus: String? = nil
    
    var body: some View {
        VStack {
            Picker("Раздел", selection: $selectedTab) {
                Text("План").tag(0)
                Text("Теги").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            if selectedTab == 0 {
                planSection
            } else {
                tagsSection
            }
        }
        .navigationTitle("Планирование")
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
        .alert("Сохранить план как отчет?", isPresented: $showSaveAlert) {
            Button("Сохранить", role: .none) { savePlanAsReport() }
            Button("Отмена", role: .cancel) { }
        }
        .alert("Удалить пункт плана?", isPresented: $showDeletePlanAlert) {
            Button("Удалить", role: .destructive) { deletePlanItem() }
            Button("Отмена", role: .cancel) { planToDeleteIndex = nil }
        }
        .alert("Удалить тег?", isPresented: $showDeleteTagAlert) {
            Button("Удалить", role: .destructive) { deleteTag() }
            Button("Отмена", role: .cancel) { tagToDelete = nil }
        }
    }
    
    // MARK: - План
    var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Добавить пункт плана", text: $newPlanItem)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: addPlanItem) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }.disabled(newPlanItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
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
            if !planItems.isEmpty {
                HStack(spacing: 12) {
                    Button("Сохранить как отчет") {
                        showSaveAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Опубликовать в Telegram") {
                        publishCustomReportToTelegram()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top)
                if let status = publishStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(status.contains("успешно") ? .green : .red)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Теги
    var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Категория тегов", selection: $tagCategory) {
                Text("Хорошие").tag(0)
                Text("Плохие").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.bottom, 8)
            .onChange(of: tagCategory, initial: false) {
                editingTagIndex = nil
                editingTagText = ""
            }
            HStack {
                TextField("Добавить тег", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }.disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            List {
                ForEach(currentTags.indices, id: \.self) { idx in
                    HStack {
                        if editingTagIndex == idx {
                            TextField("Тег", text: $editingTagText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button("OK") {
                                finishEditTag()
                                editingTagIndex = nil
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Text(currentTags[idx])
                            Spacer()
                            Button(action: { startEditTag(idx) }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if editingTagIndex != idx {
                            Button(action: { tagToDelete = currentTags[idx]; showDeleteTagAlert = true }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding()
    }
    private var currentTags: [String] {
        tagCategory == 0 ? store.goodTags : store.badTags
    }
    // MARK: - План CRUD
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
    func loadPlan() {
        // План сбрасывается каждый день, можно хранить в UserDefaults по дате
        let key = "plan_" + DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            planItems = decoded
        } else {
            planItems = []
        }
    }
    func savePlan() {
        let key = "plan_" + DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if let data = try? JSONEncoder().encode(planItems) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    func savePlanAsReport() {
        // Найти существующий кастомный отчет за сегодня
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = store.posts.firstIndex(where: { $0.type == .custom && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            // Перезаписать существующий отчет
            let updated = Post(
                id: store.posts[idx].id,
                date: Date(),
                goodItems: planItems,
                badItems: [],
                published: true,
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
            // Создать новый отчет
            let post = Post(
                id: UUID(),
                date: Date(),
                goodItems: planItems,
                badItems: [],
                published: true,
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
        let today = Calendar.current.startOfDay(for: Date())
        guard let custom = store.posts.first(where: { $0.type == .custom && Calendar.current.isDate($0.date, inSameDayAs: today) }) else {
            publishStatus = "Сначала сохраните план как отчет!"
            return
        }
        if custom.isEvaluated != true {
            publishStatus = "Сначала оцените план!"
            return
        }
        guard let token = store.telegramToken, let chatId = store.telegramChatId, !token.isEmpty, !chatId.isEmpty else {
            publishStatus = "Заполните токен и chat_id в настройках"
            return
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateStyle = .full
        let dateStr = dateFormatter.string(from: custom.date)
        let deviceName = store.getDeviceName()
        var message = "\u{1F4C5} <b>План на день за \(dateStr)</b>\n"
        message += "\u{1F4F1} <b>Устройство: \(deviceName)</b>\n\n"
        if !custom.goodItems.isEmpty {
            message += "<b>✅ План:</b>\n"
            for (index, item) in custom.goodItems.enumerated() {
                message += "\(index + 1). \(item)\n"
            }
        }
        let urlString = "https://api.telegram.org/bot\(token)/sendMessage"
        let params = [
            "chat_id": chatId,
            "text": message,
            "parse_mode": "HTML"
        ]
        var urlComponents = URLComponents(string: urlString)!
        urlComponents.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = urlComponents.url else {
            publishStatus = "Ошибка формирования URL"
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    publishStatus = "Ошибка отправки: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    publishStatus = "План успешно опубликован!"
                } else {
                    publishStatus = "Ошибка отправки: неверный токен или chat_id"
                }
            }
        }
        task.resume()
    }
    // MARK: - Теги CRUD
    func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if tagCategory == 0 {
            store.addGoodTag(trimmed)
        } else {
            store.addBadTag(trimmed)
        }
        newTag = ""
    }
    func startEditTag(_ idx: Int) {
        editingTagIndex = idx
        editingTagText = currentTags[idx]
    }
    func finishEditTag() {
        guard let idx = editingTagIndex else { return }
        let trimmed = editingTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let old = currentTags[idx]
        if tagCategory == 0 {
            store.updateGoodTag(old: old, new: trimmed)
        } else {
            store.updateBadTag(old: old, new: trimmed)
        }
        editingTagIndex = nil
        editingTagText = ""
    }
    func deleteTag() {
        guard let tag = tagToDelete else { return }
        if tagCategory == 0 {
            store.removeGoodTag(tag)
        } else {
            store.removeBadTag(tag)
        }
        tagToDelete = nil
    }
}

#Preview {
    DailyPlanningFormView()
        .environmentObject(PostStore())
}
