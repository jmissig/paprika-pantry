import Foundation
import GRDB

/// Independent of both the CLI release and SQLite migration versions.
public struct IndexSourceContract: Codable, Equatable, Sendable {
    public let identity: String
    public let layout: String
    public let schemaSignature: String
    public var adapterVersion: Int = 2
    public var derivationVersion: Int = 2

    var encoded: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // All fields are primitive, non-failing JSON values.
        return String(decoding: try! encoder.encode(self), as: UTF8.self)
    }
}

public enum IndexCompatibilityError: Error, LocalizedError {
    case rebuildRequired(String)
    case concurrentUpdate
    case futureSidecar
    public var errorDescription: String? {
        switch self {
        case .rebuildRequired(let reason):
            return "Sidecar rebuild required: \(reason). Run `paprika-pantry index rebuild` with the same source and --home."
        case .concurrentUpdate:
            return "The sidecar changed while this update was being prepared. Retry the index operation."
        case .futureSidecar:
            return "This sidecar has migrations from a newer paprika-pantry. Use that version; no migrations were applied."
        }
    }
}

public struct IndexBuildProvenance: Codable, Equatable, Sendable {
    public let family: String
    public let contract: String
    public let generation: String
    public let builtAt: String
    public let dependencySignature: String?
}

extension PantrySidecarStore {
    public static let routineFamilies = ["recipe-search", "recipe-features", "recipe-ingredients", "recipe-usage"]
    public static let allFamilies = routineFamilies + ["ingredient-pairs"]

    public func indexProvenance() throws -> [IndexBuildProvenance] {
        try dbQueue.read(Self.indexProvenance)
    }

    static func indexProvenance(_ db: Database) throws -> [IndexBuildProvenance] {
        try Row.fetchAll(db, sql: "SELECT * FROM index_provenance ORDER BY family").map {
            IndexBuildProvenance(family: $0["family"], contract: $0["contract"], generation: $0["generation"], builtAt: $0["built_at"], dependencySignature: $0["dependency_signature"])
        }
    }

    public func requireCompatible(_ contract: IndexSourceContract, families: [String] = PantrySidecarStore.allFamilies) throws {
        try dbQueue.read { try Self.requireCompatible(contract, families: families, db: $0) }
    }

    static func requireCompatible(_ contract: IndexSourceContract, families: [String], db: Database) throws {
        for family in families {
            guard let builtContract = try String.fetchOne(db, sql: "SELECT contract FROM index_provenance WHERE family=?", arguments: [family]) else {
                throw IndexCompatibilityError.rebuildRequired("\(family) has no verified build provenance")
            }
            guard builtContract == contract.encoded else {
                throw IndexCompatibilityError.rebuildRequired("\(family) was built for a different source, layout, or interpretation contract")
            }
        }
    }

    /// Validation and evidence read share one SQLite read transaction.
    func readCompatible<T>(_ families: [String], _ body: (Database) throws -> T) throws -> T {
        try dbQueue.read { db in
            if let expectedContract { try Self.requireCompatible(expectedContract, families: families, db: db) }
            return try body(db)
        }
    }

    func requireBoundCompatibility(_ families: [String]) throws {
        if let expectedContract { try requireCompatible(expectedContract, families: families) }
    }

    func writeProvenance(contract: IndexSourceContract, families: [String], generation: String, at: String, dependencies: String?, db: Database) throws {
        for family in families {
            try db.execute(sql: "INSERT OR REPLACE INTO index_provenance (family, contract, generation, built_at, dependency_signature) VALUES (?, ?, ?, ?, ?)", arguments: [family, contract.encoded, generation, at, dependencies])
        }
    }
}

/// Captured before source extraction; successful run IDs also cover fixture sources
/// that deliberately have no Paprika contract/provenance.
struct IndexBuildBaseline: Equatable, Sendable {
    let provenance: [IndexBuildProvenance]
    let successfulRuns: [Int64]

    static func capture(_ db: Database) throws -> Self {
        Self(provenance: try PantrySidecarStore.indexProvenance(db),
             successfulRuns: try Int64.fetchAll(db, sql: "SELECT MAX(id) FROM index_runs WHERE status='success' GROUP BY index_name ORDER BY index_name"))
    }
    func requireUnchanged(_ db: Database) throws {
        guard try self == Self.capture(db) else { throw IndexCompatibilityError.concurrentUpdate }
    }
    func requireCompatible(_ contract: IndexSourceContract) throws {
        for family in PantrySidecarStore.allFamilies {
            guard provenance.contains(where: { $0.family == family && $0.contract == contract.encoded }) else {
                throw IndexCompatibilityError.rebuildRequired("\(family) baseline has no compatible provenance")
            }
        }
    }
}

/// Internal deterministic test seams; production callers use empty hooks.
struct IndexBuildHooks: Sendable {
    var afterBaseline: (@Sendable () async throws -> Void)?
    var beforePublication: (@Sendable () async throws -> Void)?
}
