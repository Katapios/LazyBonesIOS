import SwiftUI

struct TagManagerView: View {
    @StateObject private var viewModel: TagManagerViewModelNew
    
    init() {
        let repo = DependencyContainer.shared.resolve(TagRepositoryProtocol.self)!
        self._viewModel = StateObject(wrappedValue: TagManagerViewModelNew(tagRepository: repo))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Категория тегов", selection: $viewModel.tagCategory) {
                Text("Хорошие").tag(0)
                Text("Плохие").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            HStack {
                TextField("Добавить тег", text: $viewModel.newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: { Task { await viewModel.addTag() } }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }.disabled(viewModel.isNewTagEmpty)
            }
            List {
                ForEach(viewModel.currentTags.indices, id: \.self) { idx in
                    HStack {
                        if viewModel.editingTagIndex == idx {
                            TextField("Тег", text: $viewModel.editingTagText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .submitLabel(.done)
                                .onSubmit {
                                    Task { await viewModel.finishEditTag() }
                                }
                            Button("OK") {
                                Task { await viewModel.finishEditTag() }
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Text(viewModel.currentTags[idx])
                            Spacer()
                            Button(action: { viewModel.startEditTag(idx) }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if viewModel.editingTagIndex != idx {
                            Button(action: { viewModel.prepareDeleteTag(viewModel.currentTags[idx]) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .navigationTitle("Теги")
        .hideKeyboardOnTap()
        .onDisappear {
            if viewModel.editingTagIndex != nil {
                Task { await viewModel.finishEditTag() }
            }
        }
        .alert("Удалить тег?", isPresented: $viewModel.showDeleteTagAlert) {
            Button("Удалить", role: .destructive) { Task { await viewModel.deleteTag() } }
            Button("Отмена", role: .cancel) { viewModel.cancelDeleteTag() }
        }
        .task { await viewModel.loadTags() }
    }
}

#Preview {
    TagManagerView()
}
 