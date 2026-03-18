import Foundation

struct MaskoCollection: Identifiable, Codable {
    let id: String
    let name: String
    let projectName: String?
    let animationCount: Int
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case projectName = "project_name"
        case animationCount = "animation_count"
        case updatedAt = "updated_at"
    }
}

struct MaskoCanvas: Identifiable, Codable {
    let id: String
    let name: String
    let nodeCount: Int
    let edgeCount: Int
    let completedEdgeCount: Int
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case nodeCount = "node_count"
        case edgeCount = "edge_count"
        case completedEdgeCount = "completed_edge_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Animation Config (from canvas export)

struct MaskoAnimationConfig: Codable {
    let version: String
    let name: String
    let initialNode: String
    let autoPlay: Bool
    let nodes: [MaskoAnimationNode]
    var edges: [MaskoAnimationEdge]
    let inputs: [MaskoAnimationInput]?
}

struct MaskoAnimationNode: Codable, Identifiable {
    let id: String
    let name: String
    let transparentThumbnailUrl: String?
}

struct MaskoAnimationEdge: Codable, Identifiable {
    let id: String
    let source: String
    let target: String
    let isLoop: Bool
    let duration: Double
    var conditions: [MaskoAnimationCondition]?
    let videos: MaskoAnimationVideos
}

struct MaskoAnimationCondition: Codable {
    let input: String
    let op: String         // defaults to "=="
    let value: ConditionValue  // defaults to .bool(true)

    enum CodingKeys: String, CodingKey {
        case input, op, value
    }

    init(input: String, op: String = "==", value: ConditionValue = .bool(true)) {
        self.input = input
        self.op = op
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        input = try container.decode(String.self, forKey: .input)
        op = try container.decodeIfPresent(String.self, forKey: .op) ?? "=="
        value = try container.decodeIfPresent(ConditionValue.self, forKey: .value) ?? .bool(true)
    }
}

enum ConditionValue: Codable {
    case bool(Bool)
    case number(Double)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else {
            throw DecodingError.typeMismatch(
                ConditionValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected Bool or Number")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let b): try container.encode(b)
        case .number(let n): try container.encode(n)
        }
    }

    var boolValue: Bool {
        switch self {
        case .bool(let b): b
        case .number(let n): n != 0
        }
    }

    var doubleValue: Double {
        switch self {
        case .bool(let b): b ? 1 : 0
        case .number(let n): n
        }
    }
}

struct MaskoAnimationInput: Codable {
    let name: String
    let type: String       // "boolean", "number", "trigger"
    let defaultValue: ConditionValue
    let system: Bool?

    enum CodingKeys: String, CodingKey {
        case name, type, system
        case defaultValue = "default"
    }
}

struct MaskoAnimationVideos: Codable {
    let webm: String?
    let hevc: String?
}

// MARK: - Single Animation

struct MaskoAnimation: Identifiable, Codable {
    let id: String
    let url: String?
    let itemName: String
    let itemId: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, url
        case itemName = "item_name"
        case itemId = "item_id"
        case createdAt = "created_at"
    }
}
