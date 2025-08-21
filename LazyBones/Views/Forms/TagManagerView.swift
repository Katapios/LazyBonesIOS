import SwiftUI

struct TagManagerView: View {
    @StateObject private var viewModel: TagManagerViewModel
    
    init(store: PostStore) {
        self._viewModel = StateObject(wrappedValue: TagManagerViewModel(store: store))
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
                Button(action: viewModel.addTag) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }.disabled(viewModel.isNewTagEmpty)
            }
            List {
                ForEach(Array(viewModel.currentTags.enumerated()), id: \.offset) { idx, tag in
                    HStack {
                        if viewModel.editingTagIndex == idx {
                            TextField("Тег", text: $viewModel.editingTagText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button("OK") {
                                viewModel.finishEditTag()
                                viewModel.editingTagIndex = nil
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Text(tag)
                            Spacer()
                            Button(action: { viewModel.startEditTag(idx) }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if viewModel.editingTagIndex != idx {
                            Button(action: { viewModel.prepareDeleteTag(tag) }) {
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
        .alert("Удалить тег?", isPresented: $viewModel.showDeleteTagAlert) {
            Button("Удалить", role: .destructive) { viewModel.deleteTag() }
            Button("Отмена", role: .cancel) { viewModel.cancelDeleteTag() }
        }
    }
}

#Preview {
    TagManagerView(store: PostStore())
} 