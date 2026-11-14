import FamilyControls
import SwiftUI

struct DetoxView: View {
    @Environment(AppModel.self) private var model
    @State private var pickingBlock = false
    @State private var pickingAllow = false

    var body: some View {
        @Bindable var detox = model.detox
        NavigationStack {
            List {
                Section {
                    if detox.authorized {
                        Label("Screen Time access granted", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Theme.good)
                    } else {
                        Button("Allow Screen Time access") {
                            Task { await detox.requestAuthorization() }
                        }
                        if let err = detox.authError {
                            Text(err).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("FocusBar uses Screen Time to block apps only while a watch session is running.")
                }

                Section("What each level does") {
                    ForEach(DetoxLevel.allCases) { level in
                        HStack(alignment: .top) {
                            LevelBadge(level: level)
                            Text(level.detail).font(.subheadline)
                        }
                    }
                    Text("Choose the level on the watch, under Settings → Detox level.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        pickingBlock = true
                    } label: {
                        LabeledContent("Distracting apps", value: "\(detox.blockedCount) selected")
                    }
                    .familyActivityPicker(isPresented: $pickingBlock, selection: $detox.blockSelection)
                    Button {
                        pickingAllow = true
                    } label: {
                        LabeledContent("Always allowed", value: "\(detox.allowedCount) apps")
                    }
                    .familyActivityPicker(isPresented: $pickingAllow, selection: $detox.allowSelection)
                } header: {
                    Text("Your lists")
                } footer: {
                    Text("Medium blocks the distracting list. Deep blocks everything except “Always allowed”. "
                        + "Put Phone, Maps, banking and anything you need in an emergency there. "
                        + "These apps are never blocked and never need a watch challenge.")
                }
                .disabled(!detox.authorized)

                Section {
                    Label("Open a blocked app, then tap “Unlock with watch”.", systemImage: "1.circle")
                    Label("Raise your heart rate on the watch and hold it for 45 s.", systemImage: "2.circle")
                    Label("The app unlocks for 5 minutes, then locks again.", systemImage: "3.circle")
                    Text("The watch caps the target at 60% of your max heart rate and offers a breathing alternative.")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: {
                    Chip(term: .earn, size: 11)
                }
            }
            .navigationTitle("Digital detox")
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .listRowBackground(Theme.panel)
            .toolbarBackground(Theme.bg, for: .navigationBar)
        }
    }
}
