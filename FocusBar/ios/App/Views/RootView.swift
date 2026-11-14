import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    /// `-tab map` (etc.) opens a tab directly: handy for demo screenshots.
    @State private var tab = UserDefaults.standard.string(forKey: "tab") ?? "today"

    var body: some View {
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("Focus", systemImage: "scope") }.tag("today")
            #if LITE
            LitePhoneView()
                .tabItem { Label("Phone", systemImage: "iphone") }.tag("detox")
            #else
            DetoxView()
                .tabItem { Label("Detox", systemImage: "lock.shield") }.tag("detox")
            #endif
            FocusMapView()
                .tabItem { Label("Map", systemImage: "map") }.tag("map")
            SocialView()
                .tabItem { Label("Friends", systemImage: "person.3") }.tag("friends")
        }
        .tint(Theme.good)
        .preferredColorScheme(.dark)
        .toolbarBackground(Theme.panel, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(Theme.bg)
        .overlay(alignment: .top) {
            if let banner = model.banner {
                Text(banner)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .foregroundStyle(Theme.fg)
                    .background(Theme.panel2, in: Capsule())
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: banner) {
                        try? await Task.sleep(for: .seconds(4))
                        withAnimation { model.banner = nil }
                    }
            }
        }
        .animation(.spring, value: model.banner)
    }
}
