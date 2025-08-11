import Foundation
import SwiftUI

// Shared lightweight UI models used across Views

public struct TagItem: Identifiable, Hashable {
    public let id: UUID = UUID()
    public var text: String
    public var icon: String
    public var color: Color

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: TagItem, rhs: TagItem) -> Bool {
        lhs.id == rhs.id
    }
}

public struct ChecklistItem: Identifiable, Equatable {
    public let id: UUID
    public var text: String

    public init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}
