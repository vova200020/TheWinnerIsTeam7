import Charts
import SwiftUI

/// Focus tab, FocusPeak layout: brand header → ring "stage" → three term tiles → journal cards.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var showDemo = false
    @State private var path: [SessionRecord] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 14) {
                    BrandHeader(live: model.watch.isConnected)
                    stage
                    tiles
                    if !model.watch.isConnected { watchCard }
                    weekCard
                    recentCard
                    if model.calendar.accessGranted || !model.calendar.upcoming.isEmpty { plannedCard } else { calendarPrompt }
                    demoCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SessionRecord.self) { SessionDetailView(record: $0) }
            .task {
                // `-openLatest 1` opens the newest session (screenshots).
                if UserDefaults.standard.bool(forKey: "openLatest"), let r = model.history.first { path = [r] }
            }
        }
    }

    // MARK: Stage (the ring that follows the watch)

    @ViewBuilder
    private var stage: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let s = model.session
            let content = stageContent(s, now: ctx.date)
            VStack(spacing: 0) {
                ZStack {
                    Ring(fraction: content.fraction, color: content.color)
                    VStack(spacing: 4) {
                        Chip(term: content.term)
                        Text(content.big)
                            .font(.system(size: 76, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Theme.fg)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                        Muted(content.sub)
                    }
                    .padding(40)
                }
                .frame(maxWidth: 290)
                .padding(.top, 14)
                .padding(.bottom, 16)

                HStack(spacing: 8) {
                    Text(content.title).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.fg)
                    if let s { LevelBadge(level: s.level) }
                }
                .multilineTextAlignment(.center)
                Text(content.text)
                    .font(.system(size: 15)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 300)
                    .padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)

                if s != nil {
                    HoldButton(title: "Emergency: hold 3 s to stop blocking") { model.endBlockingNow() }
                        .padding(.top, 18)
                        .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
        }
    }

    private struct StageContent {
        var term: Term
        var big: String
        var sub: String
        var title: String
        var text: String
        var fraction: Double
        var color: Color
    }

    private func stageContent(_ s: SessionState?, now: Date) -> StageContent {
        guard let s else {
            // Idle: total focus time this week against the weekly goal.
            let goalMin = model.weeklyHoursGoal * 60
            let done = model.weekMinutes
            let left = max(0, goalMin - done)
            return StageContent(
                term: .custom("Focus time", Theme.good),
                big: done.hmm,
                sub: "of \(model.weeklyHoursGoal) h this week",
                title: done >= goalMin ? "Weekly goal reached" : "\(left.hmm) h to your weekly goal",
                text: "\(Int((100 * Double(done) / Double(goalMin)).rounded())) % done. Start a focus block on your watch; distracting apps lock until you earn them back.",
                fraction: Double(done) / Double(goalMin),
                color: Theme.good)
        }
        let elapsed = max(0, now.timeIntervalSince(s.startedAt))
        if s.plannedMinutes > 0 {
            let total = Double(s.plannedMinutes * 60)
            let left = max(0, total - elapsed)
            return StageContent(
                term: .focus, big: "\(Int((left / 60).rounded(.up)))", sub: "min left",
                title: s.level == .light ? "Focus on" : "Phone locked",
                text: textFor(s), fraction: min(1, elapsed / total), color: Theme.calm)
        }
        return StageContent(
            term: .focus, big: "\(Int(elapsed / 60))", sub: "min focused",
            title: s.level == .light ? "Focus on" : "Phone locked",
            text: textFor(s), fraction: (elapsed.truncatingRemainder(dividingBy: 3600)) / 3600, color: Theme.calm)
    }

    private func textFor(_ s: SessionState) -> String {
        s.level == .light
            ? "\(s.tag.capitalized). Turn on Do Not Disturb in Control Center: iOS doesn't let apps do it."
            : "\(s.tag.capitalized) on your watch. Put this phone face down. Blocked apps ask you to earn 5 minutes."
    }

    // MARK: Tiles

    private var tiles: some View {
        HStack(spacing: 10) {
            TermTile(value: "\(model.dayStreak)", unit: model.dayStreak == 1 ? "day" : "days", term: .streak, color: Theme.warn)
            TermTile(value: "\(model.weekRecords.count)/\(max(1, model.weeklyGoal))", unit: "this week", caption: "Sessions", color: Theme.good)
            TermTile(value: "\(model.nextBlockMinutes)", unit: "min", term: .block, color: Theme.calm)
        }
    }

    // MARK: Watch

    private var watchCard: some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.title2).foregroundStyle(Theme.calm)
                VStack(alignment: .leading, spacing: 2) {
                    CardTitle(text: model.watch.devices.isEmpty ? "Connect your Garmin" : "Watch not connected")
                    Muted(model.watch.devices.isEmpty
                          ? "Sessions, unlocks and your schedule sync through Garmin Connect."
                          : model.watch.devices.map { "\($0.name): \($0.status.label)" }.joined(separator: " · "))
                }
            }
            HStack {
                Button(model.watch.devices.isEmpty ? "Choose watch" : "Choose again") { model.watch.selectWatch() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.good)
                    .foregroundStyle(Theme.bg)
                if !model.watch.devices.isEmpty {
                    Button("Forget", role: .destructive) { model.watch.forgetWatches() }
                        .buttonStyle(.bordered)
                }
            }
            if model.watch.needsGarminConnect {
                Button("Install Garmin Connect") { model.watch.installGarminConnect() }.tint(Theme.calm)
            }
        }
    }

    // MARK: Week (FocusPeak journal card)

    private var weekCard: some View {
        let days = model.lastSevenDays
        let active = days.filter { $0.minutes > 0 }.count
        let mean = model.weekMeanScore
        return Card {
            CardTitle(text: "This week", trailing: "\(model.weekRecords.count)/\(max(1, model.weeklyGoal)) goal")
            HStack(alignment: .top) {
                fact(model.weekMinutes.hmm, "hours focused", Theme.good)
                fact(mean > 0 ? "\(mean)" : "–", "mean score", mean > 0 ? Theme.level(mean) : Theme.muted)
                fact("\(active) / 7", "active days", Theme.calm)
            }
            Chart(Array(days.enumerated()), id: \.offset) { i, d in
                BarMark(x: .value("Day", i), y: .value("Minutes", d.minutes), width: .ratio(0.6))
                    .foregroundStyle(d.minutes > 0 ? Theme.level(d.score) : Theme.line)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .annotation(position: .top, spacing: 3) {
                        if d.minutes > 0 { Text("\(d.minutes)").font(.system(size: 10)).foregroundStyle(Theme.muted) }
                    }
                    .accessibilityLabel(d.day.formatted(.dateTime.weekday(.wide)))
                    .accessibilityValue("\(d.minutes) minutes, score \(d.score)")
            }
            .chartYScale(domain: 0...max(30, (days.map(\.minutes).max() ?? 0) + 8))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: Array(0..<7)) { v in
                    AxisValueLabel {
                        if let i = v.as(Int.self) {
                            Text(i == 6 ? "Today" : days[i].day.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.system(size: 11, weight: i == 6 ? .bold : .regular))
                                .foregroundStyle(i == 6 ? Theme.fg : Theme.muted)
                        }
                    }
                }
            }
            .frame(height: 120)
            Muted("Minutes per day. Color shows the Focus Score.")
        }
    }

    private func fact(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.system(size: 26, weight: .heavy)).monospacedDigit().foregroundStyle(color)
            Muted(label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Sessions

    private var recentCard: some View {
        Card {
            HStack {
                CardTitle(text: "Sessions")
                Chip(term: .score, size: 11)
            }
            if model.history.isEmpty {
                Muted("Finished sessions show up here, with your focus curve, heart rate and rewards.")
            }
            VStack(spacing: 0) {
                ForEach(Array(model.history.prefix(6).enumerated()), id: \.element.id) { i, r in
                    NavigationLink(value: r) { SessionRow(record: r) }
                        .buttonStyle(.plain)
                        .padding(.vertical, 12)
                        .overlay(alignment: .top) { if i > 0 { Rectangle().fill(Theme.line).frame(height: 0.5) } }
                }
            }
        }
    }

    // MARK: Planned

    private var calendarPrompt: some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: "calendar.badge.clock").font(.title2).foregroundStyle(Theme.calm)
                VStack(alignment: .leading, spacing: 2) {
                    CardTitle(text: "Plan focus in your calendar")
                    Muted("Add #focus to an event, and it goes to your watch with a reminder.")
                }
            }
            Button("Use my calendar") { Task { await model.calendar.requestAccess() } }
                .buttonStyle(.bordered).tint(Theme.calm)
        }
    }

    private var plannedCard: some View {
        Card {
            HStack { CardTitle(text: "Planned"); Chip(term: .block, size: 11) }
            if model.calendar.upcoming.isEmpty {
                Muted("Nothing planned this week. Add #focus to an event's title or notes.")
            }
            ForEach(model.calendar.upcoming) { p in
                HStack(spacing: 12) {
                    TagIcon(tag: p.tag, size: 34)
                    VStack(alignment: .leading) {
                        Text(p.title.isEmpty ? p.tag.capitalized : p.title).foregroundStyle(Theme.fg).lineLimit(1)
                        Text(p.start.formatted(.dateTime.weekday().hour().minute()))
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text("\(p.minutes) min").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.fg)
                }
            }
            if !model.calendar.upcoming.isEmpty {
                Button("Send to watch") { model.sendSchedule() }
                    .buttonStyle(.bordered).tint(Theme.calm)
                    .disabled(!model.watch.isConnected)
            }
        }
    }

    // MARK: Demo

    private var demoCard: some View {
        Card {
            DisclosureGroup(isExpanded: $showDemo) {
                VStack(alignment: .leading, spacing: 10) {
                    Muted("Plays the watch's messages locally, for rehearsing without a watch.")
                    HStack {
                        ForEach(DetoxLevel.allCases) { level in
                            Button(level.title) { model.simulateStart(level: level) }
                                .buttonStyle(.bordered).tint(Term.level(level).color)
                        }
                    }
                    Button("End session with sample data") { model.simulateEnd() }
                        .buttonStyle(.bordered).tint(Theme.fg)
                        .disabled(model.session == nil)
                }
                .padding(.top, 8)
            } label: {
                Text("Watch simulator").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            .tint(Theme.muted)
            if let event = model.watch.lastEvent {
                Text(event).font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }
}

/// FocusPeak session row: title, muted details, big level-colored score.
struct SessionRow: View {
    let record: SessionRecord

    var body: some View {
        HStack(spacing: 12) {
            TagIcon(tag: record.tag, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.tag.capitalized).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.fg)
                    LevelBadge(level: record.level)
                }
                Text("\(record.date.formatted(.dateTime.weekday().hour().minute())) · \(record.minutes) min"
                     + ((record.breaks ?? 0) > 0 ? " · \(record.breaks ?? 0) break" : ""))
                    .font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            if let curve = record.curve, curve.count >= 2 {
                Sparkline(values: curve, color: Theme.level(record.avgScore)).frame(width: 56, height: 26)
            }
            Text("\(record.avgScore)")
                .font(.system(size: 27, weight: .bold)).monospacedDigit()
                .foregroundStyle(Theme.level(record.avgScore))
                .frame(minWidth: 40, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
