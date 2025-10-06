import SwiftUI

struct TagManagerViewClean: View {
    @StateObject private var viewModel: TagManagerViewModelNew
    
    init(viewModel: TagManagerViewModelNew) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Picker("Тип тегов", selection: $viewModel.selectedSegment) {
                Text(TagManagerViewModelNew.Segment.good.title)
                    .tag(TagManagerViewModelNew.Segment.good)
                Text(TagManagerViewModelNew.Segment.bad.title)
                    .tag(TagManagerViewModelNew.Segment.bad)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            HStack(spacing: 8) {
                TextField("Новый тег", text: $viewModel.newTagText)
                    .textFieldStyle(.roundedBorder)
                Button(action: { Task { await viewModel.addNewTag() } }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            
            List {
                Section(header: Text(currentHeader)) {
                    ForEach(currentTags, id: \.self) { tag in
                        HStack {
                            if let edit = viewModel.tagBeingEdited, edit.oldValue == tag {
                                TextField("Тег", text: Binding(
                                    get: { edit.newValue },
                                    set: { viewModel.tagBeingEdited?.newValue = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                Spacer()
                                Button("OK") { Task { await viewModel.applyEdit() } }
                            } else {
                                Text(tag)
                                Spacer()
                                Button(role: .none) {
                                    viewModel.startEditing(segment: viewModel.selectedSegment, oldValue: tag)
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                Button(role: .destructive) {
                                    viewModel.requestDelete(segment: viewModel.selectedSegment, value: tag)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Теги")
        .hideKeyboardOnTap()
        .task { await viewModel.load() }
        .alert(item: alertItem) { item in
            Alert(title: Text("Ошибка"), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog(
            "Удалить тег?",
            isPresented: Binding(
                get: { viewModel.tagToDelete != nil },
                set: { _ in }
            ),
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) { Task { await viewModel.confirmDelete() } }
            Button("Отмена", role: .cancel) { viewModel.tagToDelete = nil }
        }
    }
    
    private var currentTags: [String] {
        switch viewModel.selectedSegment {
        case .good: return viewModel.goodTags
        case .bad: return viewModel.badTags
        }
    }
    
    private var currentHeader: String {
        switch viewModel.selectedSegment {
        case .good: return "Список хороших тегов"
        case .bad: return "Список плохих тегов"
        }
    }
    
    // Simple wrapper to use with .alert(item:)
    private struct AlertWrapper: Identifiable { let id = UUID(); let message: String }
    private var alertItem: Binding<AlertWrapper?> {
        Binding<AlertWrapper?>(
            get: {
                if let msg = viewModel.alertMessage { return AlertWrapper(message: msg) }
                return nil
            },
            set: { _ in viewModel.alertMessage = nil }
        )
    }
}

struct TagManagerViewClean_Previews: PreviewProvider {
    static var previews: some View {
        let container = DependencyContainer.shared
        container.registerCoreServices()
        container.registerPresentationAdapters()
        let vm = TagManagerViewModelNew(tagRepository: container.resolve(TagRepositoryProtocol.self)!)
        return NavigationView { TagManagerViewClean(viewModel: vm) }
    }
}
