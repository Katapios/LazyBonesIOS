import SwiftUI

struct TagPickerUIKitWheel: UIViewRepresentable {
    var tags: [TagItem]
    @Binding var selectedIndex: Int
    var onSelect: (TagItem) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.selectRow(selectedIndex, inComponent: 0, animated: false)
        context.coordinator.pickerView = picker
        // Добавим tap gesture только если тег один
        if tags.count == 1 {
            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTapOnPicker))
            picker.addGestureRecognizer(tap)
            picker.isUserInteractionEnabled = true
        }
        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        uiView.reloadAllComponents()
        // Если selectedIndex вне диапазона — сбросить в 0
        var safeIndex = selectedIndex
        if tags.isEmpty {
            safeIndex = 0
        } else if selectedIndex >= tags.count {
            safeIndex = 0
        }
        if tags.indices.contains(safeIndex) {
            uiView.selectRow(safeIndex, inComponent: 0, animated: true)
        }
        // Если был сброс, обновить binding
        if selectedIndex != safeIndex {
            DispatchQueue.main.async {
                self.selectedIndex = safeIndex
            }
        }
        // Обновим жесты: если тегов один — добавить, иначе убрать
        if tags.count == 1 {
            if uiView.gestureRecognizers?.first(where: { $0 is UITapGestureRecognizer }) == nil {
                let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTapOnPicker))
                uiView.addGestureRecognizer(tap)
                uiView.isUserInteractionEnabled = true
            }
        } else {
            uiView.gestureRecognizers?.forEach { gr in
                if gr is UITapGestureRecognizer {
                    uiView.removeGestureRecognizer(gr)
                }
            }
        }
    }

    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: TagPickerUIKitWheel
        private var lastSelectedRow: Int?
        weak var pickerView: UIPickerView?
        init(_ parent: TagPickerUIKitWheel) {
            self.parent = parent
        }
        func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            parent.tags.count
        }
        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = UILabel()
            let tag = parent.tags[row]
            let icon = UIImage(systemName: tag.icon)?.withTintColor(UIColor(tag.color), renderingMode: .alwaysOriginal)
            let attachment = NSTextAttachment()
            attachment.image = icon
            attachment.bounds = CGRect(x: 0, y: -2, width: 20, height: 20)
            let iconString = NSAttributedString(attachment: attachment)
            let textString = NSAttributedString(string: "  " + tag.text, attributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: UIColor(tag.color)
            ])
            let result = NSMutableAttributedString()
            result.append(iconString)
            result.append(textString)
            label.attributedText = result
            label.textAlignment = .center
            return label
        }
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            if parent.tags.indices.contains(row) {
                parent.selectedIndex = row
                parent.onSelect(parent.tags[row])
                pickerView.selectRow(row, inComponent: 0, animated: true)
            }
        }
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            44
        }
        // --- Новый метод для обработки тапа по колесу, если тег один ---
        @objc func handleTapOnPicker() {
            guard parent.tags.count == 1 else { return }
            parent.selectedIndex = 0
            parent.onSelect(parent.tags[0])
        }
    }
}

#if DEBUG
struct TagPickerUIKitWheel_Previews: PreviewProvider {
    @State static var selected = 0
    static var previews: some View {
        TagPickerUIKitWheel(
            tags: [
                TagItem(text: "не хлебил", icon: "xmark.circle.fill", color: .green),
                TagItem(text: "не новостил", icon: "newspaper.fill", color: .blue),
                TagItem(text: "не ел вредное", icon: "fork.knife", color: .orange),
                TagItem(text: "гулял", icon: "figure.walk", color: .mint),
                TagItem(text: "кодил", icon: "laptopcomputer", color: .purple),
                TagItem(text: "рисовал", icon: "paintbrush.fill", color: .pink),
                TagItem(text: "читал", icon: "book.fill", color: .indigo),
                TagItem(text: "смотрел туториалы", icon: "play.rectangle.fill", color: .red)
            ],
            selectedIndex: $selected,
            onSelect: { _ in }
        )
        .frame(height: 180)
    }
}
#endif 