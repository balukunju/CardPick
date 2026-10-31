import Foundation

public struct CardCatalog: Codable, Equatable, Sendable {
    public var version: Int
    public var cards: [Card]

    public init(version: Int = 1, cards: [Card]) {
        self.version = version
        self.cards = cards
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case cards
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        cards = try container.decode([Card].self, forKey: .cards)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(cards, forKey: .cards)
    }
}

public enum CardCatalogError: Error, Equatable, CustomStringConvertible {
    case resourceMissing
    case unreadable
    case invalidJSON(String)

    public var description: String {
        switch self {
        case .resourceMissing:
            return "The bundled cards.json file is missing."
        case .unreadable:
            return "The bundled cards.json file could not be read."
        case .invalidJSON(let detail):
            return "cards.json is invalid. \(detail)"
        }
    }
}

extension CardCatalog {
    /// The card list shipped inside this package. Edit
    /// `Sources/CardPickCore/Resources/cards.json` and rebuild to change it.
    public static func bundled() throws -> CardCatalog {
        let url = Bundle.module.url(forResource: "cards", withExtension: "json", subdirectory: "Resources")
            ?? Bundle.module.url(forResource: "cards", withExtension: "json")
        guard let url else { throw CardCatalogError.resourceMissing }
        return try load(from: url)
    }

    public static func load(from url: URL) throws -> CardCatalog {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CardCatalogError.unreadable
        }
        return try decode(data)
    }

    public static func decode(_ data: Data) throws -> CardCatalog {
        do {
            return try JSONDecoder().decode(CardCatalog.self, from: data)
        } catch let error as CardCatalogError {
            throw error
        } catch {
            throw CardCatalogError.invalidJSON(String(describing: error))
        }
    }
}
