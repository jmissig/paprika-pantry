import Foundation

public struct PaprikaRecipeTarget: Codable, Equatable, Sendable {
    public let kind: String
    public let uid: String
    public let name: String
    public let sourceName: String?
    public let hasNotes: Bool?

    public init(uid: String, name: String, sourceName: String?, hasNotes: Bool? = nil) {
        self.kind = "paprika.recipe"
        self.uid = uid
        self.name = name
        self.sourceName = sourceName
        self.hasNotes = hasNotes
    }
}

public struct PaprikaMealTarget: Codable, Equatable, Sendable {
    public let kind: String
    public let uid: String
    public let name: String
    public let scheduledAt: String?
    public let recipeTarget: PaprikaRecipeTarget?

    public init(uid: String, name: String, scheduledAt: String?, recipeTarget: PaprikaRecipeTarget? = nil) {
        self.kind = "paprika.meal"
        self.uid = uid
        self.name = name
        self.scheduledAt = scheduledAt
        self.recipeTarget = recipeTarget
    }
}

public struct PaprikaSourceTarget: Codable, Equatable, Sendable {
    public let kind: String
    public let sourceName: String?
    public let isUnlabeled: Bool

    public init(sourceName: String?, isUnlabeled: Bool) {
        self.kind = "paprika.source"
        self.sourceName = sourceName
        self.isUnlabeled = isUnlabeled
    }
}

func hasNonEmptyNotes(_ notes: String?) -> Bool {
    guard let notes else {
        return false
    }

    return !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

func renderedTargetHandle(_ target: PaprikaRecipeTarget) -> String {
    "\(target.kind):\(target.uid)"
}

func renderedTargetHandle(_ target: PaprikaMealTarget) -> String {
    "\(target.kind):\(target.uid)"
}

func renderedTargetHandle(_ target: PaprikaSourceTarget) -> String {
    if target.isUnlabeled {
        return "\(target.kind):unlabeled"
    }

    return "\(target.kind):\(target.sourceName ?? "unknown")"
}
