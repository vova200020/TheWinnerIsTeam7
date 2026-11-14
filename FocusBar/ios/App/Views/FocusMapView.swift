import CoreLocation
import MapKit
import SwiftUI

/// Community focus map (spec §6.3), backed by mock data for the MVP.
struct FocusMapView: View {
    @Environment(AppModel.self) private var model
    @State private var locator = Locator()
    @State private var mySpot: SharedSpot?
    @State private var camera: MapCameraPosition = .automatic
    @State private var tag: String?
    @State private var selected: FocusCell?
    @State private var showSpots = false

    private static let fallback = CLLocationCoordinate2D(latitude: 37.7793, longitude: -122.4193)
    private var center: CLLocationCoordinate2D { locator.coordinate ?? Self.fallback }
    private var cells: [FocusCell] {
        MockCommunity.cells(around: center).filter { tag == nil || $0.tags.contains(tag!) }
    }

    var body: some View {
        NavigationStack {
            Map(position: $camera) {
                UserAnnotation()
                ForEach(model.sharedSpots) { spot in
                    MapPolygon(coordinates: Geohash.corners(spot.cell))
                        .foregroundStyle(Color.blue.opacity(0.18))
                        .stroke(Color.blue, lineWidth: 2)
                    Annotation("You · \(spot.tag)", coordinate: spot.center) {
                        Button { mySpot = spot } label: {
                            Label("\(spot.score)", systemImage: "person.fill")
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(Color.blue, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                }
                ForEach(cells) { cell in
                    MapCircle(center: cell.coordinate, radius: 90)
                        .foregroundStyle(color(cell.avgScore).opacity(0.35))
                    Annotation(cell.name, coordinate: cell.coordinate) {
                        Button { selected = cell } label: {
                            Text("\(cell.avgScore)")
                                .font(.caption.bold())
                                .padding(8)
                                .background(color(cell.avgScore), in: Circle())
                                .foregroundStyle(.black)
                        }
                    }
                }
            }
            .mapControls { MapUserLocationButton() }
            .safeAreaInset(edge: .bottom) { controls }
            .navigationTitle("Focus spots")
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selected) { CellCard(cell: $0).presentationDetents([.fraction(0.35)]) }
            .sheet(item: $mySpot) { MySpotCard(spot: $0).presentationDetents([.fraction(0.32)]) }
            .sheet(isPresented: $showSpots) { spotList.presentationDetents([.medium, .large]) }
            .onAppear { locator.request() }
            .onChange(of: locator.coordinate?.latitude) { _, _ in
                camera = .region(MKCoordinateRegion(center: center, latitudinalMeters: 2600, longitudinalMeters: 2600))
            }
            .task {
                camera = .region(MKCoordinateRegion(center: center, latitudinalMeters: 2600, longitudinalMeters: 2600))
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    chip("All", selected: tag == nil) { tag = nil }
                    ForEach(CalendarSync.tags, id: \.self) { t in
                        chip(t.capitalized, selected: tag == t) { tag = t }
                    }
                }
                .padding(.horizontal)
            }
            Button {
                showSpots = true
            } label: {
                Label("Find me a spot", systemImage: "sparkle.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.good)
            .foregroundStyle(Theme.bg)
            .padding(.horizontal)
            Text("Cells are ~150 m. A cell appears only after 5+ people focused there. Exact locations never leave your phone.")
                .font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 10)
        .background(Theme.panel)
    }

    private var spotList: some View {
        NavigationStack {
            List(cells.sorted { $0.rank(for: tag) > $1.rank(for: tag) }) { cell in
                Button { showSpots = false; selected = cell } label: {
                    HStack {
                        Text("\(cell.avgScore)")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .background(color(cell.avgScore).opacity(0.3), in: Circle())
                        VStack(alignment: .leading) {
                            Text(cell.name).foregroundStyle(.primary)
                            Text("\(cell.avgMinutes) min typical · best \(cell.bestHours.lowerBound)–\(cell.bestHours.upperBound + 1)h")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if cell.isOpenNow {
                            Text("Good now").font(.caption.bold()).foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle(tag.map { "Best for \($0)" } ?? "Best spots nearby")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(selected ? Theme.good : Theme.muted)
                .background(selected ? Theme.good.opacity(0.15) : Theme.panel2, in: Capsule())
                .overlay(Capsule().stroke(selected ? Theme.good.opacity(0.6) : Theme.line, lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }

    private func color(_ score: Int) -> Color {
        Theme.level(score)
    }
}

private struct MySpotCard: View {
    let spot: SharedSpot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Your focus spot", systemImage: "person.fill").font(.title3.bold()).foregroundStyle(.blue)
            Text("\(spot.tag.capitalized) · \(spot.minutes) min · focus \(spot.score)")
            if let note = spot.note { Text("“\(note)”").italic() }
            Text("Others see this area once 5+ people have focused here. Cell \(spot.cell), ~150 m.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CellCard: View {
    let cell: FocusCell

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(cell.name) area").font(.title3.bold())
            HStack(spacing: 24) {
                stat("\(cell.avgScore)", "avg focus")
                stat("\(cell.avgMinutes)m", "typical session")
                stat("\(cell.bestHours.lowerBound)–\(cell.bestHours.upperBound + 1)h", "best time")
            }
            Text("Tags: " + cell.tags.joined(separator: ", ")).foregroundStyle(.secondary)
            Text("\(cell.users) people · \(cell.sessions) sessions · cell \(cell.id)")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading) {
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// When-in-use location just to center the map; nothing is stored or uploaded.
@Observable
final class Locator: NSObject, CLLocationManagerDelegate {
    var coordinate: CLLocationCoordinate2D?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse { manager.requestLocation() }
    }
}
