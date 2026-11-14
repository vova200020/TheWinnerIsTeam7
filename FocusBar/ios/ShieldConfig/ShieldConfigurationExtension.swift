import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen shown over a blocked app (spec §5.1 step 1: "Locked — earn it on your watch").
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        focusShield(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        focusShield(name: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        focusShield(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        focusShield(name: webDomain.domain)
    }

    private func focusShield(name: String?) -> ShieldConfiguration {
        let tag = SharedStore.session?.tag ?? "focus"
        let what = name ?? "This app"
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.04, green: 0.08, blue: 0.06, alpha: 1),
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(text: "Locked for \(tag.lowercased())", color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "\(what) is paused. Earn 5 minutes on your watch: raise your heart rate and hold it.",
                color: UIColor(white: 0.8, alpha: 1)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Unlock with watch", color: .black),
            primaryButtonBackgroundColor: UIColor(red: 0.3, green: 0.95, blue: 0.45, alpha: 1),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Back to focus", color: .white)
        )
    }
}
