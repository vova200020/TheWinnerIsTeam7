import ConnectIQ
import Foundation
import Observation

/// Bridge to the FocusBar watch app through Garmin Connect Mobile (Connect IQ iOS SDK 1.8).
/// Pairing works by bouncing to Garmin Connect, which calls back on our URL scheme.
@MainActor
@Observable
final class WatchLink: NSObject {
    static let urlScheme = "focusbar-ciq"
    /// `id` from FocusBar/app/manifest.xml.
    static let watchAppId = UUID(uuidString: "dc899e3c-9dfc-4556-a06c-7bfa0b9aa303")!
    private static let devicesKey = "ciq.devices"

    struct DeviceInfo: Identifiable {
        let id: UUID
        let name: String
        var status: IQDeviceStatus
        var appInstalled: Bool?
    }

    var devices: [DeviceInfo] = []
    var lastEvent: String?
    var needsGarminConnect = false

    /// Called with every dictionary the watch sends.
    @ObservationIgnored var onMessage: (([String: Any]) -> Void)?

    @ObservationIgnored private var iqDevices: [UUID: IQDevice] = [:]
    @ObservationIgnored private var apps: [UUID: IQApp] = [:]

    var isConnected: Bool { devices.contains { $0.status == .connected } }

    func start() {
        ConnectIQ.sharedInstance().initialize(withUrlScheme: Self.urlScheme, uiOverrideDelegate: self)
        restoreDevices()
    }

    // MARK: Pairing

    func selectWatch() {
        ConnectIQ.sharedInstance().showDeviceSelection()
    }

    func installGarminConnect() {
        ConnectIQ.sharedInstance().showAppStoreForConnectMobile()
    }

    /// Returns true if the URL was Garmin Connect's device-selection callback.
    @discardableResult
    func handle(url: URL) -> Bool {
        guard url.scheme == Self.urlScheme else { return false }
        let list = (ConnectIQ.sharedInstance().parseDeviceSelectionResponse(from: url) as? [IQDevice]) ?? []
        guard !list.isEmpty else { return true }
        ConnectIQ.sharedInstance().unregister(forAllDeviceEvents: self)
        ConnectIQ.sharedInstance().unregister(forAllAppMessages: self)
        iqDevices = [:]
        apps = [:]
        devices = []
        list.forEach(register)
        saveDevices(list)
        return true
    }

    private func register(_ device: IQDevice) {
        let ciq = ConnectIQ.sharedInstance()!
        iqDevices[device.uuid] = device
        ciq.register(forDeviceEvents: device, delegate: self)
        let app = IQApp(uuid: Self.watchAppId, store: Self.watchAppId, device: device)!
        apps[device.uuid] = app
        ciq.register(forAppMessages: app, delegate: self)
        devices.append(DeviceInfo(id: device.uuid, name: device.friendlyName ?? device.modelName ?? "Garmin",
                                  status: ciq.getDeviceStatus(device)))
        refreshAppStatus(device.uuid)
    }

    private func refreshAppStatus(_ id: UUID) {
        guard let app = apps[id] else { return }
        ConnectIQ.sharedInstance().getAppStatus(app) { [weak self] status in
            Task { @MainActor in
                guard let self, let i = self.devices.firstIndex(where: { $0.id == id }) else { return }
                self.devices[i].appInstalled = status?.isInstalled
            }
        }
    }

    private func saveDevices(_ list: [IQDevice]) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: list, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: Self.devicesKey)
        }
    }

    private func restoreDevices() {
        guard let data = UserDefaults.standard.data(forKey: Self.devicesKey),
              let list = try? NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClass: IQDevice.self, from: data)
        else { return }
        list.forEach(register)
    }

    func forgetWatches() {
        ConnectIQ.sharedInstance().unregister(forAllDeviceEvents: self)
        ConnectIQ.sharedInstance().unregister(forAllAppMessages: self)
        iqDevices = [:]
        apps = [:]
        devices = []
        UserDefaults.standard.removeObject(forKey: Self.devicesKey)
    }

    // MARK: Messaging

    /// Sends to every connected watch. If the watch app isn't open, asks the
    /// watch to open it, then retries a few times (messages only reach a running app).
    func send(_ message: [String: Any], attempt: Int = 0) {
        for (id, app) in apps where devices.first(where: { $0.id == id })?.status == .connected {
            ConnectIQ.sharedInstance().sendMessage(message, to: app, progress: nil) { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    if result == .success {
                        self.lastEvent = "Sent \(message["t"] ?? "message")"
                    } else if attempt < 3 {
                        self.lastEvent = "Watch busy (\(NSStringFromSendMessageResult(result) ?? "?")), retrying…"
                        if attempt == 0 {
                            ConnectIQ.sharedInstance().openAppRequest(app) { _ in }
                        }
                        try? await Task.sleep(for: .seconds(4))
                        self.send(message, attempt: attempt + 1)
                    } else {
                        self.lastEvent = "Couldn't reach the watch app"
                    }
                }
            }
        }
    }
}

// MARK: - SDK delegates (called on arbitrary threads → hop to main)

extension WatchLink: IQUIOverrideDelegate, IQDeviceEventDelegate, IQAppMessageDelegate {
    nonisolated func needsToInstallConnectMobile() {
        Task { @MainActor in self.needsGarminConnect = true }
    }

    nonisolated func deviceStatusChanged(_ device: IQDevice, status: IQDeviceStatus) {
        let id = device.uuid
        Task { @MainActor in
            guard let id, let i = self.devices.firstIndex(where: { $0.id == id }) else { return }
            self.devices[i].status = status
            if status == .connected { self.refreshAppStatus(id) }
        }
    }

    nonisolated func receivedMessage(_ message: Any, from app: IQApp) {
        guard let dict = message as? [String: Any] else { return }
        let box = MessageBox(dict)
        Task { @MainActor in
            self.lastEvent = "Received \(box.value["t"] ?? "message")"
            self.onMessage?(box.value)
        }
    }
}

/// Carries a plist-type dictionary across the actor hop.
private struct MessageBox: @unchecked Sendable {
    let value: [String: Any]
    init(_ value: [String: Any]) { self.value = value }
}

extension IQDeviceStatus {
    var label: String {
        switch self {
        case .connected: "Connected"
        case .notConnected: "Not connected"
        case .notFound: "Not found"
        case .bluetoothNotReady: "Bluetooth off"
        case .invalidDevice: "Invalid device"
        @unknown default: "Unknown"
        }
    }
}
