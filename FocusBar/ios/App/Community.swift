import CoreLocation
import Foundation

/// Geohash encoder. Spec §6.2: sessions are snapped to a geohash-7 cell (~150 m)
/// on the phone; raw coordinates never leave the device.
enum Geohash {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    static func encode(_ c: CLLocationCoordinate2D, precision: Int = 7) -> String {
        var lat = (-90.0, 90.0), lon = (-180.0, 180.0)
        var hash = "", bit = 0, ch = 0, even = true
        while hash.count < precision {
            if even {
                let mid = (lon.0 + lon.1) / 2
                if c.longitude >= mid { ch |= 1 << (4 - bit); lon.0 = mid } else { lon.1 = mid }
            } else {
                let mid = (lat.0 + lat.1) / 2
                if c.latitude >= mid { ch |= 1 << (4 - bit); lat.0 = mid } else { lat.1 = mid }
            }
            even.toggle()
            if bit < 4 { bit += 1 } else { hash.append(base32[ch]); bit = 0; ch = 0 }
        }
        return hash
    }

    /// Bounds of a geohash cell: (south, west, north, east).
    static func bounds(_ hash: String) -> (s: Double, w: Double, n: Double, e: Double) {
        var lat = (-90.0, 90.0), lon = (-180.0, 180.0), even = true
        for ch in hash {
            guard let v = base32.firstIndex(of: ch) else { break }
            for bit in (0..<5).reversed() {
                let on = (v >> bit) & 1 == 1
                if even {
                    let mid = (lon.0 + lon.1) / 2
                    if on { lon.0 = mid } else { lon.1 = mid }
                } else {
                    let mid = (lat.0 + lat.1) / 2
                    if on { lat.0 = mid } else { lat.1 = mid }
                }
                even.toggle()
            }
        }
        return (lat.0, lon.0, lat.1, lon.1)
    }

    static func center(_ hash: String) -> CLLocationCoordinate2D {
        let b = bounds(hash)
        return CLLocationCoordinate2D(latitude: (b.s + b.n) / 2, longitude: (b.w + b.e) / 2)
    }

    static func corners(_ hash: String) -> [CLLocationCoordinate2D] {
        let b = bounds(hash)
        return [.init(latitude: b.s, longitude: b.w), .init(latitude: b.n, longitude: b.w),
                .init(latitude: b.n, longitude: b.e), .init(latitude: b.s, longitude: b.e)]
    }
}

/// A session the user chose to put on the community map: only the cell, never the exact point.
struct SharedSpot: Codable, Identifiable {
    var id: UUID           // = the session's id
    var cell: String       // geohash-7
    var tag: String
    var score: Int
    var minutes: Int
    var note: String?
    var date: Date
    var center: CLLocationCoordinate2D { Geohash.center(cell) }
}

/// A community map cell (spec §6.3). Mock data: no backend yet (MVP item 6).
struct FocusCell: Identifiable {
    let id: String          // geohash-7
    let name: String
    let coordinate: CLLocationCoordinate2D
    let avgScore: Int
    let avgMinutes: Int
    let bestHours: ClosedRange<Int>
    let tags: [String]
    let users: Int
    let sessions: Int

    var isOpenNow: Bool { bestHours.contains(Calendar.current.component(.hour, from: .now)) }

    /// "Find me a spot": score × tag match × open now.
    func rank(for tag: String?) -> Double {
        let tagMatch = (tag == nil || tags.contains(tag!)) ? 1.0 : 0.6
        return Double(avgScore) * tagMatch * (isOpenNow ? 1.0 : 0.8)
    }
}

enum MockCommunity {
    static let kAnonymity = 5

    /// Deterministic cells around `center`, so the demo looks the same every time.
    static func cells(around center: CLLocationCoordinate2D) -> [FocusCell] {
        let seeds: [(String, Double, Double, Int, Int, ClosedRange<Int>, [String], Int)] = [
            ("Central Library", 420, -310, 78, 64, 9...11, ["studying", "writing"], 41),
            ("Quiet café row", -280, 260, 71, 42, 8...10, ["writing", "journaling"], 23),
            ("Campus quad", 650, 520, 66, 38, 13...16, ["studying", "reading"], 57),
            ("Co-working loft", -540, -480, 74, 81, 10...12, ["coding", "writing"], 19),
            ("Riverside benches", 120, 860, 62, 27, 16...18, ["reading", "journaling"], 12),
            ("Bookshop upstairs", -820, 90, 80, 55, 14...17, ["reading", "writing"], 9),
            ("Tech hub", 900, -700, 69, 73, 19...22, ["coding"], 31),
            ("Park pavilion", -150, -900, 58, 24, 7...9, ["journaling"], 4),   // < k → hidden
        ]
        let mPerDegLat = 111_320.0
        let mPerDegLon = 111_320.0 * cos(center.latitude * .pi / 180)
        return seeds.map { s in
            let c = CLLocationCoordinate2D(latitude: center.latitude + s.2 / mPerDegLat,
                                           longitude: center.longitude + s.1 / mPerDegLon)
            return FocusCell(id: Geohash.encode(c), name: s.0, coordinate: c, avgScore: s.3,
                             avgMinutes: s.4, bestHours: s.5, tags: s.6, users: s.7, sessions: s.7 * 6)
        }
        .filter { $0.users >= kAnonymity }   // spec §6.2: show only cells with ≥ 5 distinct users
    }
}

/// Friends & challenges (spec §7). Mocked people; your own numbers are real.
struct Friend: Identifiable {
    let id = UUID()
    let name: String
    let weekMinutes: Int
    let consistency: Int   // sessions this week
    let isYou: Bool
}

enum MockSocial {
    static func leaderboard(yourMinutes: Int, yourSessions: Int) -> [Friend] {
        [
            Friend(name: "Maya", weekMinutes: 412, consistency: 6, isYou: false),
            Friend(name: "Jonas", weekMinutes: 298, consistency: 5, isYou: false),
            Friend(name: "Priya", weekMinutes: 251, consistency: 4, isYou: false),
            Friend(name: "Sam", weekMinutes: 140, consistency: 2, isYou: false),
            Friend(name: "You", weekMinutes: yourMinutes, consistency: yourSessions, isYou: true),
        ]
        .sorted { $0.weekMinutes > $1.weekMinutes }
    }

    static let teamGoalHours = 40
    static let teamMinutesWithoutYou = 1101
}
