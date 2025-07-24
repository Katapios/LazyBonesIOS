import SwiftUI

struct TagManagerView: View {
    @EnvironmentObject var store: PostStore
    @State private var tagCategory: Int = 0 // 0 — good, 1 — bad
    @State private var newTag: String = ""
    @State private var editingTagIndex: Int? = nil
    @State private var editingTagText: String = ""
    @State private var showDeleteTagAlert = false
    @State private var tagToDelete: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Категория тегов", selection: $tagCategory) {
                Text("Хорошие").tag(0)
                Text("Плохие").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            HStack {
                TextField("Добавить тег", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }.disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            List {
                ForEach(currentTags.indices, id: \ .self) { idx in
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
        .padding(.horizontal)
        .navigationTitle("Теги")
        .alert("Удалить тег?", isPresented: $showDeleteTagAlert) {
            Button("Удалить", role: .destructive) { deleteTag() }
            Button("Отмена", role: .cancel) { tagToDelete = nil }
        }
    }
    private var currentTags: [String] {
        tagCategory == 0 ? store.goodTags : store.badTags
    }
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
    TagManagerView().environmentObject(PostStore())
} 