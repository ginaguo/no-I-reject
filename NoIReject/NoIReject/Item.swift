//
//  Item.swift
//  NoIReject
//
//  Moment data model (Supabase-backed; schema mirrors the web app).
//

import Foundation

enum MomentType: String, Codable, CaseIterable {
    case uncomfortable
    case excited
}

struct Moment: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date          // local-day Date (noon on the recorded day)
    var typeRaw: String
    var intensity: Int      // 1–20
    var tags: [String]
    var note: String

    var type: MomentType {
        get { MomentType(rawValue: typeRaw) ?? .uncomfortable }
        set { typeRaw = newValue.rawValue }
    }

    var score: Int {
        type == .excited ? intensity : -intensity
    }

    init(id: UUID = UUID(),
         date: Date = Date(),
         type: MomentType,
         intensity: Int,
         tags: [String] = [],
         note: String = "") {
        self.id = id
        self.date = date
        self.typeRaw = type.rawValue
        self.intensity = intensity
        self.tags = tags
        self.note = note
    }
}

// MARK: - Schema mapping (Supabase row <-> Moment)

extension Moment {
    /// "YYYY-MM-DD" for the Supabase `date` column, in the user's local calendar.
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private struct Row: Codable {
        let id: String
        let date: String
        let type: String
        let intensity: Int
        let tags: [String]?
        let note: String?
    }

    static func decodeArray(_ data: Data) throws -> [Moment] {
        let rows = try JSONDecoder().decode([Row].self, from: data)
        return rows.compactMap { row in
            guard let uuid = UUID(uuidString: row.id) else { return nil }
            let day = dayFormatter.date(from: row.date) ?? Date()
            // Anchor at noon local time so day comparisons are stable.
            let cal = Calendar.current
            let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
            return Moment(
                id: uuid,
                date: noon,
                type: MomentType(rawValue: row.type) ?? .uncomfortable,
                intensity: row.intensity,
                tags: row.tags ?? [],
                note: row.note ?? ""
            )
        }
    }

    func encodeForInsert(userId: String) throws -> Data {
        let body: [String: Any] = [
            "id": id.uuidString.lowercased(),
            "user_id": userId,
            "date": Moment.dayFormatter.string(from: date),
            "type": typeRaw,
            "intensity": intensity,
            "tags": tags,
            "note": note
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }
}

// MARK: - Constants & helpers

let predefinedTags = ["Work", "Family", "Friend", "Gym", "Health", "Social", "Study", "Travel", "Food"]

func dailyEmoji(for score: Int) -> String {
    if score < -20 { return "😰" }
    if score <  -5 { return "😔" }
    if score <=  5 { return "😐" }
    if score <  20 { return "😊" }
    return "🤩"
}
