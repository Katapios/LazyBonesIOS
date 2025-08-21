import SwiftUI

public struct TagItem: Identifiable, Hashable {
    public let id = UUID()
    public let text: String
    public let icon: String
    public let color: Color

    public init(text: String, icon: String, color: Color) {
        self.text = text
        self.icon = icon
        self.color = color
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: TagItem, rhs: TagItem) -> Bool {
        lhs.id == rhs.id
    }
}
