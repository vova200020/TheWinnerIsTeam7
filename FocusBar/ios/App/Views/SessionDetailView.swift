import Charts
import MapKit
import SwiftUI
import UIKit

/// Everything one session recorded: focus curve, stats, body signals, rewards, and one takeaway.
struct SessionDetailView: View {
    @Environment(AppModel.self) private var model
    let initial: SessionRecord
    @State private var selectedMinute: Double?
    @State private var note = ""
    @State private var share: ShareItems?
    @State private var preparingShare = false
    @FocusState private var editingNote: Bool

    init(record: SessionRecord) {
        initial = record
    }

    /// Live copy (notes change after the view opens).
    private var record: SessionRecord { model.history.first { $0.id == initial.id } ?? initial }

    private var threshold: Int { record.threshold ?? 65 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if record.curvePoints.count >= 2 { focusChart }
                statsCard
                if record.hrAvg != nil || record.hrv != nil { bodyCard }
                rewardsCard
                if let insight { insightCard(insight) }
                locationCard
                notesCard
                shareButtons
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Theme.bg)
        .scrollDismissesKeyboard(.interactively)
        .onAppear { note = record.notes ?? "" }
        .onChange(of: editingNote) { _, editing in if !editing { model.updateNotes(record.id, note) } }
        .onDisappear { model.updateNotes(record.id, note) }
        .sheet(item: $share) { ActivityView(items: $0.items).presentationDetents([.medium, .large]) }
        .navigationTitle(record.tag.capitalized)
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private var header: some View {
        Card {
            HStack(spacing: 14) {
                TagIcon(tag: record.tag, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.date.formatted(.dateTime.weekday(.abbreviated).month().day().hour().minute()))
                        .font(.subheadline).foregroundStyle(Theme.muted)
                    Text(record.seconds.durationText).font(.system(size: 28, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(Theme.fg).lineLimit(1).minimumScaleFactor(0.7)
                    if let planned = record.plannedMinutes, planned > 0 {
                        Text("of \(planned) min planned").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(record.avgScore)").font(.system(size: 34, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(Theme.level(record.avgScore))
                    LevelBadge(level: record.level)
                }
            }
        }
    }

    // MARK: Focus chart

    private var focusChart: some View {
        let points = record.curvePoints.map { (minute: $0.minute, score: min(100, max(30, $0.score))) }
        let selected = selectedMinute.flatMap { m in points.min { abs($0.minute - m) < abs($1.minute - m) } }
        return Card {
            HStack { CardTitle(text: "Focus over time", trailing: "\(record.minutesInZone) min in the zone") }
            Chart {
                ForEach(points, id: \.minute) { p in
                    AreaMark(x: .value("Minute", p.minute), yStart: .value("Base", 30), yEnd: .value("Focus", p.score))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(LinearGradient(colors: [Theme.calm.opacity(0.30), Theme.calm.opacity(0.02)],
                                                        startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Minute", p.minute), y: .value("Focus", p.score))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .foregroundStyle(Theme.calm)
                }
                RuleMark(y: .value("Your focus line", threshold))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Theme.good)
                    .annotation(position: .bottom, alignment: .trailing, spacing: 2) {
                        Chip(term: .custom("Your focus line", Theme.good), size: 9)
                    }
                if let fade = record.fadeMinute, fade > 0 {
                    RuleMark(x: .value("Dip", Double(fade)))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
                if let s = selected {
                    RuleMark(x: .value("Minute", s.minute))
                        .foregroundStyle(Color.primary.opacity(0.25))
                    PointMark(x: .value("Minute", s.minute), y: .value("Focus", s.score))
                        .symbolSize(90)
                        .foregroundStyle(Theme.focus)
                        .annotation(position: .top, spacing: 6,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                            VStack(spacing: 0) {
                                Text("\(s.score)").font(.headline.monospacedDigit())
                                Text("min \(Int(s.minute.rounded()))").font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
                        }
                }
            }
            .chartYScale(domain: 30...100)
            .chartXScale(domain: 0...(points.last?.minute ?? 1))
            .chartPlotStyle { plot in plot.clipped() }
            .chartXSelection(value: $selectedMinute)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { v in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                    AxisValueLabel { if let m = v.as(Double.self) { Text("\(Int(m))m") } }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [40, 60, 80, 100]) { _ in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                    AxisValueLabel()
                }
            }
            .frame(height: 200)
            .accessibilityLabel("Focus over time. Average \(record.avgScore), peak \(record.peak ?? record.avgScore).")
            Text(chartCaption)
                .font(.caption).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chartCaption: String {
        if let fade = record.fadeMinute, fade > 0 {
            return "Drag to read any minute. The vertical line marks the break nudge (minute \(fade))."
        }
        return "Drag across the chart to read any minute."
    }

    // MARK: Stats

    private var statsCard: some View {
        Card {
            CardTitle(text: "Session")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 16) {
                StatTile(value: "\(record.avgScore)", label: "avg focus · " + Theme.levelWord(record.avgScore).lowercased())
                StatTile(value: record.peak.map(String.init) ?? "–", label: "peak")
                StatTile(value: record.low.map(String.init) ?? "–", label: "lowest")
                StatTile(value: record.selfReport > 0 ? "\(record.selfReport)/5" : "–", label: "how it felt")
                StatTile(value: record.breaks.map(String.init) ?? "–", label: "breaks")
                StatTile(value: record.dips.map(String.init) ?? "–", label: "focus dips")
            }
        }
    }

    private var bodyCard: some View {
        Card {
            CardTitle(text: "Body")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 16) {
                StatTile(value: record.hrAvg.map(String.init) ?? "–", label: "avg heart rate", unit: "bpm")
                StatTile(value: record.hrMax.map(String.init) ?? "–", label: "max heart rate", unit: "bpm")
                StatTile(value: record.hrv.map(String.init) ?? "–", label: "HRV (RMSSD)", unit: "ms")
            }
            Text("Higher HRV than your usual means a calm, alert state, and that's what the score rewards.")
                .font(.caption).foregroundStyle(Theme.muted)
        }
    }

    // MARK: Rewards

    private var rewardsCard: some View {
        Card {
            HStack {
                Image(systemName: "star.circle.fill").font(.title2).foregroundStyle(.yellow)
                Text("+\(record.xp ?? record.minutes) XP").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.warn)
                Spacer()
            }
            if let awards = record.awards, !awards.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(awards, id: \.self) { a in
                            Label(a, systemImage: "rosette")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .foregroundStyle(Theme.warn)
                                .background(Theme.warn.opacity(0.15), in: Capsule())
                                .overlay(Capsule().stroke(Theme.warn.opacity(0.6), lineWidth: 1.2))
                        }
                    }
                }
            }
        }
    }

    // MARK: Location, notes, sharing

    @ViewBuilder
    private var locationCard: some View {
        Card {
            CardTitle(text: "Where", trailing: record.locationSource)
            if let cell = record.cell {
                Map(initialPosition: .region(MKCoordinateRegion(center: Geohash.center(cell),
                                                                latitudinalMeters: 600, longitudinalMeters: 600)),
                    interactionModes: []) {
                    MapPolygon(coordinates: Geohash.corners(cell))
                        .foregroundStyle(Theme.focus.opacity(0.25))
                        .stroke(Theme.focus, lineWidth: 2)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Map of the area where you focused")
                Text("Shown and shared as a ~150 m area (cell \(cell)). Your exact location never leaves this phone.")
                    .font(.caption).foregroundStyle(Theme.muted)
            } else {
                Text("No location for this session. The watch had no GPS fix and the phone app wasn't running.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
    }

    private var notesCard: some View {
        Card {
            CardTitle(text: "Notes")
            TextField("What helped? What distracted you?", text: $note, axis: .vertical)
                .lineLimit(2...6)
                .focused($editingNote)
                .submitLabel(.done)
                .padding(10)
                .foregroundStyle(Theme.fg)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10))
            if editingNote {
                Button("Save note") { editingNote = false }.font(.subheadline.weight(.semibold))
            }
        }
    }

    private var shareButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    editingNote = false
                    model.updateNotes(record.id, note)
                    preparingShare = true
                    var items: [Any] = [ShareRenderer.text(for: record)]
                    if let img = await ShareRenderer.image(for: record) { items.insert(img, at: 0) }
                    preparingShare = false
                    share = ShareItems(items: items)
                }
            } label: {
                HStack {
                    if preparingShare { ProgressView().tint(.white) } else { Image(systemName: "square.and.arrow.up") }
                    Text("Share focus spot")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.good)
            .foregroundStyle(Theme.bg)
            .controlSize(.large)
            .disabled(preparingShare)

            if record.cell != nil {
                let onMap = model.isOnMap(record.id)
                Button {
                    model.updateNotes(record.id, note)
                    model.toggleOnMap(record)
                } label: {
                    Label(onMap ? "On the focus map. Remove" : "Add to focus map",
                          systemImage: onMap ? "mappin.slash" : "mappin.and.ellipse")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.calm)
                .controlSize(.large)
            }
        }
    }

    // MARK: Insight

    private var insight: String? {
        if let fade = record.fadeMinute, fade > 0 {
            return "Your focus started fading around minute \(fade). Next time, try a short break just before that."
        }
        if record.minutesInZone > 0, record.minutes > 0, record.minutesInZone * 10 >= record.minutes * 7 {
            return "\(record.minutesInZone) of \(record.minutes) minutes above your focus line: that's a strong session."
        }
        if record.selfReport >= 4, record.avgScore < threshold {
            return "You felt focused even though your body signals were average. Your ratings tune the score to you."
        }
        return nil
    }

    private func insightCard(_ text: String) -> some View {
        Card {
            Label {
                Text(text).font(.subheadline)
            } icon: {
                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
            }
        }
    }
}

/// Builds the shareable image: a map of the ~150 m area (never the exact point), the focus
/// score, duration, tag and the user's note.
enum ShareRenderer {
    @MainActor
    static func image(for r: SessionRecord) async -> UIImage? {
        let map = await mapSnapshot(cell: r.cell)
        let card = ShareCardView(record: r, map: map)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage
    }

    static func text(for r: SessionRecord) -> String {
        var t = "Focused \(r.seconds.durationText) on \(r.tag) · focus \(r.avgScore)/100"
        if let cell = r.cell { t += " · area \(cell) (~150 m)" }
        if let note = r.notes { t += "\n“\(note)”" }
        return t + "\nvia FocusBar"
    }

    /// Map image of the geohash cell with its outline drawn on top.
    static func mapSnapshot(cell: String?) async -> UIImage? {
        guard let cell else { return nil }
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: Geohash.center(cell), latitudinalMeters: 700, longitudinalMeters: 700)
        options.size = CGSize(width: 360, height: 200)
        options.pointOfInterestFilter = .excludingAll
        guard let snap = try? await MKMapSnapshotter(options: options).start() else { return nil }
        let corners = Geohash.corners(cell).map { snap.point(for: $0) }
        return UIGraphicsImageRenderer(size: options.size).image { ctx in
            snap.image.draw(at: .zero)
            let path = UIBezierPath()
            path.move(to: corners[0])
            corners.dropFirst().forEach { path.addLine(to: $0) }
            path.close()
            UIColor.systemGreen.withAlphaComponent(0.25).setFill()
            path.fill()
            UIColor.systemGreen.setStroke()
            path.lineWidth = 3
            path.stroke()
        }
    }
}

struct ShareCardView: View {
    let record: SessionRecord
    let map: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let map {
                Image(uiImage: map).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 360, height: 200).clipped()
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(record.avgScore)").font(.system(size: 44, weight: .bold, design: .rounded))
                    Text("focus").font(.headline).foregroundStyle(.secondary)
                    Spacer()
                    Text(record.seconds.durationText).font(.title3.weight(.semibold))
                }
                Text("\(record.tag.capitalized) · \(record.date.formatted(.dateTime.weekday().hour().minute()))")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                if let note = record.notes {
                    Text("“\(note)”").font(.body).italic().lineLimit(4)
                }
                HStack {
                    Image(systemName: "scope")
                    Text("FocusBar").fontWeight(.semibold)
                    Spacer()
                    if let cell = record.cell { Text("area \(cell) · ~150 m").font(.caption) }
                }
                .font(.footnote).foregroundStyle(.green)
            }
            .padding(16)
        }
        .frame(width: 360)
        .background(Color.white)
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
    }
}

/// UIKit share sheet (image + text).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct ShareItems: Identifiable {
    let id = UUID()
    let items: [Any]
}
