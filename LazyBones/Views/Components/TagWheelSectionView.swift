import SwiftUI

/// Секция выбора тегов с колесом и кнопкой добавления
struct TagWheelSectionView: View {
    let allTags: [TagItem]
    @Binding var selectedIndex: Int
    let isTagAdded: (TagItem) -> Bool
    let onAddTag: (TagItem) -> Void
    let viewId: String
    var height: CGFloat = 120

    var body: some View {
        if !allTags.isEmpty {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 6) {
                    TagPickerUIKitWheel(
                        tags: allTags,
                        selectedIndex: $selectedIndex
                    ) { _ in }
                    .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                    .id(viewId)
                    .clipped()

                    // Кнопка добавления выбранного тега
                    let safeIndex: Int = {
                        if allTags.isEmpty { return 0 }
                        if allTags.indices.contains(selectedIndex) { return selectedIndex }
                        return max(0, allTags.count - 1)
                    }()

                    if !allTags.isEmpty {
                        let selectedTag = allTags[safeIndex]
                        let added = isTagAdded(selectedTag)
                        Button(action: {
                            if selectedIndex != safeIndex { selectedIndex = safeIndex }
                            if !added { onAddTag(selectedTag) }
                        }) {
                            Image(systemName: added ? "checkmark.circle.fill" : "plus.circle.fill")
                                .resizable()
                                .frame(width: 28, height: 28)
                                .foregroundColor(added ? .green : .blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Image(systemName: "plus.circle")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.gray)
                            .opacity(0.4)
                    }
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .padding(.bottom, 8)
        }
    }
}

#if DEBUG
struct TagWheelSectionView_Previews: PreviewProvider {
    @State static var idx = 0
    static var previews: some View {
        TagWheelSectionView(
            allTags: [
                TagItem(text: "гулял", icon: "figure.walk", color: .green),
                TagItem(text: "кодил", icon: "laptopcomputer", color: .blue)
            ],
            selectedIndex: $idx,
            isTagAdded: { _ in false },
            onAddTag: { _ in },
            viewId: "preview"
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
