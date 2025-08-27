import Foundation
import SwiftUI

// MARK: - Общие утилиты для форм с TagPicker и списками строк

public enum TagHelpers {
    // Подсчёт непустых строк (только пробелы игнорируются)
    public static func nonEmptyCount(in items: [String]) -> Int {
        items.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    // Безопасный индекс с защёлкой в пределах массива
    public static func clampedIndex(_ index: Int, arrayCount: Int) -> Int {
        guard arrayCount > 0 else { return 0 }
        return min(max(0, index), arrayCount - 1)
    }

    // Выбор тега из массива по безопасному индексу
    public static func selectedTag(from tags: [TagItem], pickerIndex: Int) -> TagItem? {
        guard !tags.isEmpty else { return nil }
        let idx = clampedIndex(pickerIndex, arrayCount: tags.count)
        return tags[idx]
    }

    // Проверка, что тег уже добавлен в массив строк по совпадению текста
    public static func isTagTextAdded(_ tag: TagItem, in items: [String]) -> Bool {
        items.contains(where: { $0 == tag.text })
    }

    // Нужна ли подсказка «Сохранить тег?» для сырого ввода
    public static func shouldSuggestSave(rawText: String, existingRaw: [String]) -> Bool {
        let candidate = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return false }
        let normalized = existingRaw.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return !normalized.contains(candidate)
    }
}
