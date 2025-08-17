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
        // Инициализируем кэшированные значения
        context.coordinator.lastRowsCount = tags.count
        context.coordinator.lastSelectedRow = selectedIndex
        // Добавим tap gesture только если тег один
        if tags.count == 1 {
            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTapOnPicker))
            picker.addGestureRecognizer(tap)
            picker.isUserInteractionEnabled = true
        }
        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        // Обновляем данные только при необходимости (используем кэш counts)
        let rowsChanged = context.coordinator.lastRowsCount != tags.count
        if rowsChanged {
            uiView.reloadAllComponents()
            context.coordinator.lastRowsCount = tags.count
        }

        // Безопасно обрабатываем selectedIndex
        var safeIndex = selectedIndex
        let needsCorrection = tags.isEmpty || selectedIndex < 0 || selectedIndex >= tags.count
        if needsCorrection {
            safeIndex = 0
        }

        // Устанавливаем выбранную строку только если реально отличается
        let currentlySelected = uiView.selectedRow(inComponent: 0)
        if (rowsChanged || needsCorrection), tags.indices.contains(safeIndex), currentlySelected != safeIndex {
            // Подавляем обратный вызов didSelectRow на время программного выбора
            context.coordinator.isProgrammaticSelection = true
            uiView.selectRow(safeIndex, inComponent: 0, animated: false)
            DispatchQueue.main.async {
                context.coordinator.isProgrammaticSelection = false
            }
            context.coordinator.lastSelectedRow = safeIndex
        }

        // Не трогаем binding без необходимости. Корректируем только в случае выхода за границы/пустых тегов.
        if needsCorrection, selectedIndex != safeIndex {
            if Thread.isMainThread {
                self.selectedIndex = safeIndex
            } else {
                DispatchQueue.main.async { self.selectedIndex = safeIndex }
            }
        }

        // Обновляем жесты для одиночного тега только если изменилось количество строк
        if rowsChanged {
            updateGestureRecognizers(for: uiView, context: context)
        }
    }
    
    private func updateGestureRecognizers(for uiView: UIPickerView, context: Context) {
        if tags.count == 1 {
            // Добавляем жест только если его еще нет
            if uiView.gestureRecognizers?.first(where: { $0 is UITapGestureRecognizer }) == nil {
                let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTapOnPicker))
                uiView.addGestureRecognizer(tap)
                uiView.isUserInteractionEnabled = true
            }
        } else {
            // Удаляем все tap жесты
            uiView.gestureRecognizers?.forEach { gr in
                if gr is UITapGestureRecognizer {
                    uiView.removeGestureRecognizer(gr)
                }
            }
        }
    }

    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: TagPickerUIKitWheel
        var lastSelectedRow: Int?
        var isProgrammaticSelection: Bool = false
        var lastRowsCount: Int = 0
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
            // Игнорируем колбэк, если выбор инициирован программно
            if isProgrammaticSelection { return }
            // Проверяем, что индекс в пределах массива тегов
            guard parent.tags.indices.contains(row) else {
                Logger.debug("Selected row \(row) is out of bounds for tags array with \(parent.tags.count) items", log: Logger.general)
                return
            }
            
            // Избегаем лишних обновлений, если индекс не меняется
            guard lastSelectedRow != row else { return }
            lastSelectedRow = row
            if parent.selectedIndex != row {
                parent.selectedIndex = row
            }
            // Небольшой дебаунс, чтобы избежать "скачков" при частых обновлениях данных
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [parent] in
                parent.onSelect(parent.tags[row])
            }
            // Не переустанавливаем selectRow здесь, чтобы не запускать лишнюю анимацию/обновления
        }
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            44
        }
        // --- Новый метод для обработки тапа по колесу, если тег один ---
        @objc func handleTapOnPicker() {
            guard parent.tags.count == 1 else { return }
            
            // Дополнительная проверка безопасности
            guard parent.tags.indices.contains(0) else {
                Logger.warning("Cannot access tag at index 0, tags array is empty", log: Logger.general)
                return
            }
            
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