import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsPlatform

struct NetworkPrioritySettingsView: View {
    @ObservedObject var module: NetworkPriorityModule

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.xl) {
            SettingsSection(
                title: "Preferred connection",
                caption: "Changes the service order for the current macOS network location."
            ) {
                VStack(alignment: .leading, spacing: DTSpace.md) {
                    Picker("Preferred connection", selection: preferenceBinding) {
                        Label("Ethernet First", systemImage: "cable.connector.horizontal")
                            .tag(NetworkServiceKind.ethernet)
                        Label("Wi-Fi First", systemImage: "wifi")
                            .tag(NetworkServiceKind.wifi)
                    }
                    .pickerStyle(.segmented)
                    .disabled(!canSwitch)

                    HStack(spacing: DTSpace.sm) {
                        if module.isApplying {
                            ProgressView()
                                .controlSize(.small)
                            Text("Waiting for macOS to apply the new order…")
                        } else {
                            Image(systemName: module.menuBarIconName)
                            Text(statusText)
                        }
                        Spacer()
                        Button("Refresh") {
                            Task { await module.refresh() }
                        }
                        .controlSize(.small)
                        .disabled(module.isApplying || module.state.isOff)
                    }
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)

                    if let error = module.lastError {
                        InlineAlert(style: alertStyle, message: error)
                    }
                }
            }

            SettingsSection(
                title: "Participating services",
                caption: "DropThings identifies interfaces through Apple's network type metadata, not their names."
            ) {
                VStack(alignment: .leading, spacing: DTSpace.md) {
                    serviceRow(for: .ethernet, icon: "cable.connector.horizontal")
                    Divider()
                    serviceRow(for: .wifi, icon: "wifi")
                }
            }

            SettingsSection(title: "Administrator authorization") {
                HStack(alignment: .top, spacing: DTSpace.sm) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(DTColor.textSecondary)
                    Text("macOS protects system network changes. It may ask for an administrator credential when you switch. DropThings never stores that credential, and canceling leaves the confirmed order unchanged.")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var preferenceBinding: Binding<NetworkServiceKind> {
        Binding(
            get: { module.currentSnapshot?.preferredKind ?? .ethernet },
            set: { kind in Task { await module.setPreferred(kind) } }
        )
    }

    private var canSwitch: Bool {
        !module.isApplying && module.currentSnapshot?.availabilityIssue == nil
            && module.currentSnapshot?.preferredKind != nil
    }

    private var statusText: String {
        guard let preferred = module.currentSnapshot?.preferredKind else {
            return "Waiting for a usable Ethernet and Wi-Fi service order."
        }
        return "Confirmed: \(preferred.displayName) is first for new connections."
    }

    private var alertStyle: InlineAlertStyle {
        if module.lastError == NetworkServiceOrderError.authorizationDenied.localizedDescription {
            return .info
        }
        return .error
    }

    @ViewBuilder
    private func serviceRow(for kind: NetworkServiceKind, icon: String) -> some View {
        let services = module.currentSnapshot?.enabledServices(of: kind) ?? []
        HStack(spacing: DTSpace.md) {
            Image(systemName: icon)
                .font(DTTypography.moduleIcon)
                .foregroundStyle(services.isEmpty ? DTColor.textTertiary : DTColor.accent)
                .frame(width: DTSize.iconButton, height: DTSize.iconButton)
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(kind.displayName)
                    .font(DTTypography.body.weight(.semibold))
                Text(serviceDescription(services))
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
            Spacer()
            Image(systemName: services.isEmpty ? "xmark.circle" : "checkmark.circle.fill")
                .foregroundStyle(services.isEmpty ? DTColor.warning : DTColor.success)
                .accessibilityLabel(services.isEmpty ? "Unavailable" : "Available")
        }
    }

    private func serviceDescription(_ services: [NetworkServiceDescriptor]) -> String {
        guard !services.isEmpty else { return "No enabled service in the current location" }
        return services.map { service in
            service.interfaceName.map { "\(service.name) (\($0))" } ?? service.name
        }.joined(separator: ", ")
    }
}
