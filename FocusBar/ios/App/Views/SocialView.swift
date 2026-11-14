import SwiftUI

/// Friends (spec §7), FocusPeak layout: team goal bar, leaderboard with bars, challenges.
/// Ranked on focus *minutes* or consistency, never on raw score (scores are personal).
struct SocialView: View {
    @Environment(AppModel.self) private var model
    @State private var byConsistency = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    BrandHeader(live: model.watch.isConnected)
                    teamCard
                    leaderboardCard
                    challengesCard
                    youCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.bg)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var teamCard: some View {
        let total = MockSocial.teamMinutesWithoutYou + model.weekMinutes
        let goal = MockSocial.teamGoalHours * 60
        let pct = 100 * Double(total) / Double(goal)
        return Card {
            HStack {
                CardTitle(text: "Team goal this week")
                Text("\(total.hmm) / \(goal.hmm) h").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.fg)
            }
            ScoreBar(percent: pct, color: Theme.good)
            Muted(pct >= 100 ? "Goal reached. Well done, team."
                  : "\(max(0, goal - total).hmm) h to the team goal. You added \(model.weekMinutes) min.")
        }
    }

    private var leaderboardCard: some View {
        let board = MockSocial.leaderboard(yourMinutes: model.weekMinutes, yourSessions: model.weekRecords.count)
            .sorted { byConsistency ? $0.consistency > $1.consistency : $0.weekMinutes > $1.weekMinutes }
        let top = max(1, board.map { byConsistency ? $0.consistency : $0.weekMinutes }.max() ?? 1)
        let meIndex = board.firstIndex { $0.isYou }
        let rival = meIndex.flatMap { $0 > 0 ? board[$0 - 1] : nil }
        return Card {
            HStack {
                CardTitle(text: "Leaderboard")
                Picker("Rank by", selection: $byConsistency) {
                    Text("Minutes").tag(false)
                    Text("Sessions").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            VStack(spacing: 0) {
                ForEach(Array(board.enumerated()), id: \.element.id) { i, f in
                    let value = byConsistency ? f.consistency : f.weekMinutes
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(i + 1)").foregroundStyle(Theme.muted).frame(width: 22, alignment: .leading)
                            Text(f.name).fontWeight(.bold).foregroundStyle(f.isYou ? Theme.calm : Theme.fg)
                            Spacer()
                            Text(byConsistency ? "\(f.consistency) sessions" : "\(f.weekMinutes.hmm) h")
                                .monospacedDigit().foregroundStyle(Theme.fg)
                        }
                        .font(.system(size: 16))
                        ScoreBar(percent: 100 * Double(value) / Double(top), color: f.isYou ? Theme.calm : Theme.muted)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, f.isYou ? 10 : 0)
                    .background(f.isYou ? Theme.calm.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, f.isYou ? -10 : 0)
                    .overlay(alignment: .top) { if i > 0 && !f.isYou { Rectangle().fill(Theme.line).frame(height: 0.5) } }
                }
            }
            if let rival, !byConsistency {
                let gap = max(1, rival.weekMinutes - model.weekMinutes)
                Muted((gap >= 60 ? "\(gap.hmm) h" : "\(gap) min") + " more and you pass \(rival.name).")
            }
        }
    }

    private var challengesCard: some View {
        Card {
            CardTitle(text: "Weekly challenges")
            challenge("3 Deep sessions", done: model.weekRecords.filter { $0.level == .deep }.count, of: 3)
            challenge("Focus 5 days this week",
                      done: Set(model.weekRecords.map { Calendar.current.startOfDay(for: $0.date) }).count, of: 5)
            challenge("Share a focus spot", done: model.sharedSpots.isEmpty ? 0 : 1, of: 1)
        }
    }

    private func challenge(_ title: String, done: Int, of total: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: done >= total ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done >= total ? Theme.good : Theme.muted)
                Text(title).foregroundStyle(Theme.fg)
                Spacer()
                Text("\(min(done, total))/\(total)").monospacedDigit().foregroundStyle(Theme.muted)
            }
            ScoreBar(percent: 100 * Double(min(done, total)) / Double(total), color: Theme.warn)
        }
    }

    private var youCard: some View {
        Card {
            CardTitle(text: "You")
            HStack {
                StatTile(value: String(format: "%.1f", model.totalHours), label: "hours focused")
                StatTile(value: "\(model.history.count)", label: "sessions")
                StatTile(value: "\(model.totalXP)", label: "XP")
            }
            Muted("Friends see your minutes and a place area you chose to share. Never your exact location.")
        }
    }
}
