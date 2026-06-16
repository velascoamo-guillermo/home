import Foundation

struct Pet: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var type: String
    var breed: String
    var birthday: Date? = nil
    var photoUrl: String? = nil
    var updatedAt: Date = .now
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, type, breed, birthday
        case photoUrl   = "photo_url"
        case updatedAt  = "updated_at"
        case deletedAt  = "deleted_at"
    }

    init(id: UUID = UUID(), name: String, type: String, breed: String,
         birthday: Date? = nil, photoUrl: String? = nil,
         updatedAt: Date = .now, deletedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.breed = breed
        self.birthday = birthday
        self.photoUrl = photoUrl
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(UUID.self, forKey: .id)
        name     = try c.decode(String.self, forKey: .name)
        type     = try c.decode(String.self, forKey: .type)
        breed    = try c.decode(String.self, forKey: .breed)
        photoUrl = try c.decodeIfPresent(String.self, forKey: .photoUrl)
        if let raw = try c.decodeIfPresent(String.self, forKey: .birthday) {
            birthday = Self.dateFormatter.date(from: raw)
        }
        updatedAt = (try? c.decode(Date.self, forKey: .updatedAt)) ?? .now
        deletedAt = try? c.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,       forKey: .id)
        try c.encode(name,     forKey: .name)
        try c.encode(type,     forKey: .type)
        try c.encode(breed,    forKey: .breed)
        try c.encodeIfPresent(photoUrl, forKey: .photoUrl)
        if let birthday {
            try c.encode(Self.dateFormatter.string(from: birthday), forKey: .birthday)
        } else {
            try c.encodeNil(forKey: .birthday)
        }
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

extension Pet: SyncableEntity {
    static let tableName = "pets"
}
