import Charts
import SwiftUI

// Visual language shared with FocusPeak (FocusPeak/focuspeak-phone/src/theme.js + terms.js):
// always-dark palette, score colored by level, and "terms" drawn as the same pill on phone and watch.

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

enum Theme {
    static let bg = Color(hex: 0x080B10)
    static let panel = Color(hex: 0x131A23)
    static let panel2 = Color(hex: 0x1E2733)
    static let fg = Color(hex: 0xEEF1F5)
    static let muted = Color(hex: 0x93A0B2)
    static let line = Color(hex: 0x263140)
    static let good = Color(hex: 0x3DDC84)
    static let warn = Color(hex: 0xFFB020)
    static let bad = Color(hex: 0xFF6B5E)
    static let calm = Color(hex: 0x4DA3FF)

    static let focus = good          // accent
    static let corner: CGFloat = 20

    /// Same thresholds as the watch: ≥70 good, ≥40 fair, below that low.
    static func level(_ score: Int) -> Color { score >= 70 ? good : (score >= 40 ? warn : bad) }
    static func levelWord(_ score: Int) -> String { score >= 70 ? "Ready" : (score >= 40 ? "Fair" : "Low") }
}

/// One word, one color, one shape on both devices.
enum Term {
    case ready, focus, earn, rest, score, streak, block, level(DetoxLevel), custom(String, Color)

    var text: String {
        switch self {
        case .ready: "Ready"
        case .focus: "Focus"
        case .earn: "Move to unlock"
        case .rest: "Break"
        case .score: "Focus score"
        case .streak: "Streak"
        case .block: "Block"
        case .level(let l): l.title
        case .custom(let t, _): t
        }
    }

    var color: Color {
        switch self {
        case .ready, .score: Theme.fg
        case .focus, .block: Theme.calm
        case .earn, .streak: Theme.warn
        case .rest: Theme.good
        case .level(let l):
            switch l {
            case .light: Theme.good
            case .medium: Theme.warn
            case .deep: Theme.calm
            }
        case .custom(_, let c): c
        }
    }
}

struct Chip: View {
    let term: Term
    var size: CGFloat = 13

    var body: some View {
        Text(term.text)
            .font(.custom("AvenirNextCondensed-DemiBold", size: size))
            .tracking(size * 0.03)
            .foregroundStyle(term.color)
            .padding(.vertical, size * 0.28)
            .padding(.horizontal, size * 0.85)
            .background(term.color.opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(term.color.opacity(0.6), lineWidth: 1.2))
            .fixedSize()
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint ?? Theme.panel, in: RoundedRectangle(cornerRadius: Theme.corner))
    }
}

struct CardTitle: View {
    let text: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(.system(size: 17, weight: .heavy)).foregroundStyle(Theme.fg)
            Spacer()
            if let trailing {
                Text(trailing).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted)
            }
        }
    }
}

struct Muted: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Kept for existing call sites: a detox level drawn as a term chip.
struct LevelBadge: View {
    let level: DetoxLevel
    var body: some View { Chip(term: .level(level), size: 11) }
}

struct TagIcon: View {
    let tag: String
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: Self.symbol(for: tag))
            .font(.system(size: size * 0.42, weight: .semibold))
            .frame(width: size, height: size)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: size * 0.3))
            .foregroundStyle(Theme.calm)
    }

    static func symbol(for tag: String) -> String {
        switch tag.lowercased() {
        case "studying": "book.closed.fill"
        case "journaling": "pencil.line"
        case "book writing", "writing": "text.book.closed.fill"
        case "coding": "chevron.left.forwardslash.chevron.right"
        case "reading": "books.vertical.fill"
        default: "brain.head.profile"
        }
    }
}

/// 0–100 bar on a dark track (FocusPeak ScoreBar).
struct ScoreBar: View {
    let percent: Double
    let color: Color

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.panel2)
                Capsule().fill(color).frame(width: g.size.width * min(1, max(0, percent / 100)))
            }
        }
        .frame(height: 10)
    }
}

/// Thin progress ring starting at 12 o'clock, with a soft halo of the same color behind it.
struct Ring: View {
    let fraction: Double
    let color: Color
    var lineWidth: CGFloat = 0.06   // share of the size

    var body: some View {
        GeometryReader { g in
            let w = min(g.size.width, g.size.height) * lineWidth
            ZStack {
                Circle().fill(color.opacity(0.12)).padding(w * 3)
                Circle().stroke(Theme.panel2, lineWidth: w)
                Circle()
                    .trim(from: 0, to: min(1, max(0, fraction)))
                    .stroke(color, style: StrokeStyle(lineWidth: w, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(w / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// "Focus" + "Bar" brand line with the link state pill (FocusPeak header).
struct BrandHeader: View {
    let live: Bool

    var body: some View {
        HStack(spacing: 12) {
            (Text("Focus").foregroundStyle(Theme.fg) + Text("Bar").foregroundStyle(Theme.good))
                .font(.system(size: 26, weight: .heavy))
                .tracking(-0.3)
            HStack(spacing: 6) {
                Circle().fill(live ? Theme.good : Theme.warn).frame(width: 8, height: 8)
                Text(live ? "LIVE" : "NO WATCH")
                    .font(.system(size: 11.5, weight: .heavy)).tracking(1)
                    .foregroundStyle(live ? Theme.good : Theme.warn)
            }
            .padding(.vertical, 5).padding(.horizontal, 11)
            .background(Theme.panel, in: Capsule())
            Spacer()
        }
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(live ? "FocusBar, watch connected" : "FocusBar, no watch connected")
    }
}

/// Press and hold for `seconds` (FocusPeak emergency unlock): never a reflex tap.
struct HoldButton: View {
    let title: String
    var seconds: Double = 3
    var color: Color = Theme.bad
    let action: () -> Void
    @State private var progress: CGFloat = 0
    @State private var task: Task<Void, Never>?

    var body: some View {
        Text(title)
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(Theme.muted)
            .padding(.vertical, 14).padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(alignment: .leading) {
                GeometryReader { g in color.opacity(0.25).frame(width: g.size.width * progress) }
            }
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            .onLongPressGesture(minimumDuration: seconds, maximumDistance: 40) {
                action()
                progress = 0
            } onPressingChanged: { pressing in
                withAnimation(pressing ? .linear(duration: seconds) : .easeOut(duration: 0.2)) {
                    progress = pressing ? 1 : 0
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Press and hold for \(Int(seconds)) seconds")
    }
}

/// Tiny focus curve for list rows.
struct Sparkline: View {
    let values: [Int]
    var color: Color = Theme.calm

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { item in
            LineMark(x: .value("t", item.offset), y: .value("focus", item.element))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .foregroundStyle(color)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 30...100)
        .accessibilityHidden(true)
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 24, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.fg)
                if let unit { Text(unit).font(.caption).foregroundStyle(Theme.muted) }
            }
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// FocusPeak stat tile: term chip, big colored value, muted unit.
struct TermTile: View {
    let value: String
    let unit: String
    var term: Term?
    var caption: String?
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Group {
                if let term { Chip(term: term, size: 11) } else { Text(caption ?? "").font(.system(size: 14)).foregroundStyle(Theme.muted) }
            }
            .frame(height: 26)
            Text(value).font(.system(size: 30, weight: .heavy)).monospacedDigit().foregroundStyle(color)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(unit).font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14).padding(.horizontal, 6)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

extension Int {
    var durationText: String {
        let h = self / 3600, m = (self % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }

    /// FocusPeak "h:mm" for minute totals.
    var hmm: String { String(format: "%d:%02d", self / 60, self % 60) }
}
