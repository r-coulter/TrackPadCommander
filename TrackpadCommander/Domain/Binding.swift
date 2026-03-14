import Foundation

struct Binding: Codable, Identifiable, Hashable {
    var id: UUID
    var gesture: GestureID
    var action: ActionSpec
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        gesture: GestureID = .threeFingerTap,
        action: ActionSpec = ActionSpec(),
        isEnabled: Bool = true
    ) {
        self.id = id
        self.gesture = gesture
        self.action = action
        self.isEnabled = isEnabled
    }
}
