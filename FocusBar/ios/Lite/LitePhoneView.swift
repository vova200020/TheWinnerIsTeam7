import SwiftUI

/// Demo "home screen": during a Medium/Deep session the distracting apps lock.
/// Tapping one shows the same shield as the Screen Time build, and "Unlock with watch"
/// sends a real `unlock_request` to the watch.
struct LitePhoneView: View {
    @Environment(AppModel.self) private var model
    @State private var shielded: MockApp?
    @State private var opened: MockApp?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 3)

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        status
                        LazyVGrid(columns: columns, spacing: 22) {
                            ForEach(MockApp.all) { app in
                                tile(app, locked: model.detox.isLocked(app, now: ctx.date), now: ctx.date)
                            }
                        }
                        Text("Phone, Maps and Bank are always allowed, so they're never blocked in an emergency.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .navigationTitle("Your phone")
            .background(Theme.bg)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .fullScreenCover(item: $shielded) { app in
                ShieldScreen(app: app) { shielded = nil }
                    .environment(model)
            }
            .alert(item: $opened) { app in
                Alert(title: Text("\(app.id) opened"), message: Text("This is where the app would open."))
            }
        }
    }

    private var status: some View {
        HStack {
            if let s = model.session {
                LevelBadge(level: s.level)
                Text(s.level == .light ? "Light focus: nothing blocked" : "Focus on: distractions locked")
                    .foregroundStyle(Theme.fg)
            } else {
                Image(systemName: "lock.open")
                Text("No session. Start one on your watch.")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func tile(_ app: MockApp, locked: Bool, now: Date) -> some View {
        Button {
            if locked { shielded = app } else { opened = app }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(locked ? Theme.panel2 : color(app))
                        .frame(width: 68, height: 68)
                        .overlay {
                            Image(systemName: app.symbol)
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(locked ? 0.5 : 1))
                        }
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.caption.bold())
                            .padding(5)
                            .background(.black, in: Circle())
                            .foregroundStyle(.white)
                            .offset(x: 6, y: -6)
                    }
                }
                Text(label(app, now: now))
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
    }

    private func label(_ app: MockApp, now: Date) -> String {
        if let until = model.detox.unlockedUntil[app.id], until > now {
            let s = Int(until.timeIntervalSince(now))
            return String(format: "%d:%02d left", s / 60, s % 60)
        }
        return app.id
    }

    private func color(_ app: MockApp) -> Color {
        if app.essential { return Theme.good.opacity(0.85) }
        return app.distracting ? Theme.bad.opacity(0.85) : Theme.calm.opacity(0.85)
    }
}

/// Mirrors ShieldConfigurationExtension: "Locked — earn it on your watch".
private struct ShieldScreen: View {
    @Environment(AppModel.self) private var model
    let app: MockApp
    let dismiss: () -> Void

    private var waiting: Bool { model.detox.waitingFor == app.id }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: waiting ? "applewatch.radiowaves.left.and.right" : "lock.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(waiting ? Theme.warn : Theme.calm)
                    .symbolEffect(.pulse, isActive: waiting)
                Chip(term: waiting ? .earn : .focus)
                Text(waiting ? "Check your watch" : "Locked for \(model.session?.tag ?? "focus")")
                    .font(.title.bold())
                Text(waiting
                     ? "Raise your heart rate and hold it until the ring fills."
                     : "\(app.id) is paused. Earn 5 minutes on your watch: raise your heart rate and hold it.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 32)
                if let event = model.watch.lastEvent, waiting {
                    Text(event).font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                if !waiting {
                    Button {
                        model.detox.requestUnlock(app)
                        model.forwardPendingUnlock()
                    } label: {
                        Text("Unlock with watch").font(.headline).frame(maxWidth: .infinity).padding()
                    }
                    .background(Theme.good, in: Capsule())
                    .foregroundStyle(.black)
                }
                Button(waiting ? "Cancel" : "Back to focus") {
                    if waiting { model.detox.cancelUnlock() }
                    dismiss()
                }
                .foregroundStyle(.white)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg)
            .foregroundStyle(.white)
            .onChange(of: model.detox.isLocked(app, now: ctx.date)) { _, locked in
                if !locked { dismiss() }   // unlock_granted arrived (or the session ended)
            }
        }
    }
}

