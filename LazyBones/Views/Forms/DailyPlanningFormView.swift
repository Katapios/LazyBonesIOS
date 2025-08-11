// DailyPlanningFormView.swift
// LazyBones
//
// Created by Денис Рюмин on 2025-07-10.

import SwiftUI

struct DailyPlanningFormView: View {
    @State private var selectedTab = 0 // По умолчанию открывается первый экран (третий экран)
    
    // postForToday больше не используется напрямую из PostStore в этом экране
    
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
    @StateObject private var vm: PlanningViewModelNew
    @State private var newPlanItem: String = ""
    @State private var editingPlanIndex: Int? = nil
    @State private var editingPlanText: String = ""
    @State private var showSaveAlert = false
    @State private var showDeletePlanAlert = false
    @State private var planToDeleteIndex: Int? = nil
    @State private var lastPlanDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var tagPickerOffset: CGFloat = 0

    init() {
        let dc = DependencyContainer.shared
        let tagRepo = dc.resolve(TagRepositoryProtocol.self)!
        let getUC = dc.resolve(GetReportsUseCase.self)!
        let delUC = dc.resolve(DeleteReportUseCase.self)!
        let updUC = dc.resolve(UpdateReportUseCase.self)!
        let tgSvc = dc.resolve(PostTelegramServiceProtocol.self)!
        _vm = StateObject(wrappedValue: PlanningViewModelNew(
            tagRepository: tagRepo,
            getReportsUseCase: getUC,
            deleteReportUseCase: delUC,
            updateReportUseCase: updUC,
            postTelegramService: tgSvc
        ))
    }

    var planTags: [TagItem] {
        vm.goodTags.map { TagItem(text: $0, icon: "tag", color: .green) }
    }
    
    var body: some View {
        VStack {
            planSection
        }
        .hideKeyboardOnTap()
        .onAppear {
            Task { await vm.load() }
            lastPlanDate = Calendar.current.startOfDay(for: Date())
        }
        .onChange(of: Calendar.current.startOfDay(for: Date()), initial: false) { oldDay, newDay in
            if newDay != lastPlanDate {
                vm.planItems = []
                // сохраняем новый пустой план
                // (vm сам пишет в UserDefaults)
                // Форсируем запись
                let _ = { vm.planItems = vm.planItems }()
                lastPlanDate = newDay
            }
        }
    }
    
    // MARK: - План
    var planSection: some View {
        VStack(spacing: 16) {
            // --- Список пунктов плана ---
            List {
                ForEach(vm.planItems.indices, id: \.self) { idx in
                    HStack {
                        if editingPlanIndex == idx {
                            TextField("Пункт", text: $editingPlanText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button("OK") { finishEditPlanItem() }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Text(vm.planItems[idx])
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
                    Button(action: { vm.toggleTagPicker() }) {
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
                if vm.showTagPicker, !planTags.isEmpty {
                    HStack(alignment: .center, spacing: 6) {
                        TagPickerUIKitWheel(
                            tags: planTags,
                            selectedIndex: $vm.pickerIndex
                        ) { _ in }
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 120,
                            maxHeight: 160
                        )
                        .clipped()
                        // Форсируем перерисовку колеса при изменении набора тегов
                        .id("planning_" + planTags.map { $0.text }.joined(separator: "|"))
                        
                        let safeIndex: Int = {
                            if planTags.isEmpty { return 0 }
                            if planTags.indices.contains(vm.pickerIndex) { return vm.pickerIndex }
                            return max(0, planTags.count - 1)
                        }()
                        if !planTags.isEmpty {
                            let selectedTag = planTags[safeIndex]
                            let isTagAdded = vm.planItems.contains(where: { $0 == selectedTag.text })
                            Button(action: {
                                if (!isTagAdded) {
                                    // синхронизируем индекс, если он вышел за границы
                                    if vm.pickerIndex != safeIndex { vm.pickerIndex = safeIndex }
                                    vm.addSelectedTag()
                                }
                            }) {
                                Image(systemName: isTagAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(isTagAdded ? .green : .blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            // Нет тегов: показываем неактивную кнопку
                            Image(systemName: "plus.circle")
                                .resizable()
                                .frame(width: 28, height: 28)
                                .foregroundColor(.gray)
                                .opacity(0.4)
                        }
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
                if !newPlanItem.isEmpty && !vm.goodTags.contains(newPlanItem) {
                    HStack {
                        Text("Сохранить тег?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Сохранить") {
                            let tagText = newPlanItem
                            Task { @MainActor in
                                await vm.addGoodTag(tagText)
                            }
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
            if !vm.planItems.isEmpty {
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
                        action: { Task { await vm.sendCustomReport() } },
                        isEnabled: true,
                        compact: true
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
                if let status = vm.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(status.contains("успешно") ? .green : .red)
                }
            }
        }
        .padding()
        .alert("Сохранить план как отчет?", isPresented: $showSaveAlert) {
            Button("Сохранить", role: .none) { vm.savePlanAsCustomReport(using: nil) }
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
        vm.addPlanItem(trimmed)
        newPlanItem = ""
    }
    
    func startEditPlanItem(_ idx: Int) {
        editingPlanIndex = idx
        editingPlanText = vm.planItems[idx]
    }
    
    func finishEditPlanItem() {
        guard let idx = editingPlanIndex else { return }
        let trimmed = editingPlanText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        vm.updatePlanItem(at: idx, with: trimmed)
        editingPlanIndex = nil
        editingPlanText = ""
    }
    
    func deletePlanItem() {
        guard let idx = planToDeleteIndex else { return }
        vm.removePlanItem(at: idx)
        planToDeleteIndex = nil
    }
}

#Preview {
    DailyPlanningFormView()
}
