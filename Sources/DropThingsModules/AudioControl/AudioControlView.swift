import AppKit
import SwiftUI
import UniformTypeIdentifiers
import DropThingsAudioControlKit
import DropThingsCore
import DropThingsDesignSystem

struct AudioControlSettingsView: View {
    @ObservedObject var module: AudioControlModule

    var body: some View {
        SettingsSection(
            title: "Audio Control",
            caption: "Per-app audio is processed locally in an isolated helper. DropThings never records, saves, or transmits audio."
        ) {
            VStack(alignment: .leading, spacing: DTSpace.md) {
                outputHeader
                engineAlert
                HStack {
                    Text("Apps").font(DTTypography.sectionTitle)
                    Spacer()
                    Button("Pin app…") { chooseApplication() }.controlSize(.small)
                }
                appList
                Divider()
                diagnosticsControls
            }
        }
    }

    private var outputHeader: some View {
        HStack(spacing: DTSpace.sm) {
            Image(systemName: "hifispeaker")
                .foregroundStyle(DTColor.accent)
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(module.defaultOutput?.name ?? "Loading output device…")
                    .font(DTTypography.body.weight(.semibold))
                if let device = module.defaultOutput {
                    Text("System default · \(device.transport) · \(sampleRate(device.sampleRate))")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                }
            }
            Spacer()
            Button("Restore normal audio") { module.restoreNormalAudio() }
                .controlSize(.small)
                .disabled(module.isRestoringNormalAudio)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Default output, \(module.defaultOutput?.name ?? "loading")")
    }

    @ViewBuilder
    private var engineAlert: some View {
        switch module.state {
        case .failed(let reason, _):
            InlineAlert(style: .error, message: reason)
            HStack {
                Button("Restore normal audio") { module.restoreNormalAudio() }
                Button("Restart engine") { module.restartEngine() }
            }
            .controlSize(.small)
        case .degraded(let reason):
            InlineAlert(style: .warning, message: reason)
        case .unavailable(let reason):
            InlineAlert(style: .warning, message: reason)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var appList: some View {
        if module.state == .starting {
            HStack(spacing: DTSpace.sm) {
                ProgressView().controlSize(.small)
                Text("Finding apps that are producing audio…")
                    .font(DTTypography.body)
                    .foregroundStyle(DTColor.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: DTSize.utilityIcon, alignment: .leading)
        } else if module.visibleApps.isEmpty {
            VStack(alignment: .leading, spacing: DTSpace.xs) {
                Text("No apps are producing audio")
                    .font(DTTypography.body.weight(.semibold))
                Text("Start playback in any app. It will appear here without being modified until you change one of its controls.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: DTSize.previewLarge, alignment: .leading)
        } else {
            VStack(spacing: 0) {
                ForEach(module.visibleApps) { row in
                    AudioControlAppRowView(module: module, row: row)
                    if row.id != module.visibleApps.last?.id { Divider() }
                }
            }
            .background(DTColor.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: DTRadius.md))
            .overlay(RoundedRectangle(cornerRadius: DTRadius.md).stroke(DTColor.border))
        }
    }

    private var diagnosticsControls: some View {
        VStack(alignment: .leading, spacing: DTSpace.sm) {
            Toggle("Show live level meters", isOn: Binding(
                get: { module.settings.showMeters },
                set: { module.setShowMeters($0) }
            ))
            Toggle("Show system and helper processes", isOn: Binding(
                get: { module.settings.showSystemProcesses },
                set: { module.setShowSystemProcesses($0) }
            ))
            Text("Meters are visual diagnostics only and never drive gain. System Audio Recording is requested by macOS only when you first change an app control.")
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
            if !module.ignoredApps.isEmpty {
                Divider()
                Text("Ignored apps").font(DTTypography.sectionTitle)
                ForEach(module.ignoredApps, id: \.identity.stableID) { app in
                    HStack {
                        Text(app.identity.displayName).font(DTTypography.body)
                        Spacer()
                        Button("Stop ignoring") { module.setIgnored(false, for: app.identity) }
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Pin"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        module.pinApplication(at: url)
    }

    private func sampleRate(_ value: Double) -> String {
        value > 0 ? String(format: "%.1f kHz", value / 1_000) : "rate unavailable"
    }
}

private struct AudioControlAppRowView: View {
    @ObservedObject var module: AudioControlModule
    let row: AudioControlAppRow

    private var identity: AudioAppIdentity { row.settings.identity }

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.sm) {
            HStack(spacing: DTSpace.sm) {
                appIcon
                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    HStack(spacing: DTSpace.xs) {
                        Text(identity.displayName).font(DTTypography.body.weight(.semibold))
                        if row.settings.isPinned {
                            Image(systemName: "pin.fill").font(DTTypography.badgeLabel).foregroundStyle(DTColor.textSecondary)
                        }
                        if !row.isProducingAudio {
                            Text("Idle").font(DTTypography.caption).foregroundStyle(DTColor.textTertiary)
                        }
                    }
                    healthText
                }
                Spacer()
                Button { module.toggleMute(for: identity) } label: {
                    Image(systemName: row.settings.isMuted ? "speaker.slash.fill" : "speaker.wave.2")
                        .frame(width: DTSize.iconButton, height: DTSize.iconButton)
                }
                .buttonStyle(.plain)
                .foregroundStyle(row.settings.isMuted ? DTColor.danger : DTColor.textSecondary)
                .accessibilityLabel("\(row.settings.isMuted ? "Unmute" : "Mute") \(identity.displayName)")

                Button("Solo") { module.toggleSolo(for: identity) }
                    .controlSize(.mini)
                    .foregroundStyle(row.settings.isSoloed ? DTColor.warning : DTColor.textPrimary)
            }

            HStack(spacing: DTSpace.sm) {
                Slider(
                    value: Binding(
                        get: { row.settings.volume },
                        set: { module.setVolume($0, for: identity) }
                    ),
                    in: 0...1
                )
                .accessibilityLabel("Volume for \(identity.displayName)")
                .accessibilityValue("\(Int(row.settings.volume * 100)) percent")
                Text("\(Int(row.settings.volume * 100))%")
                    .font(DTTypography.caption.monospacedDigit())
                    .frame(width: DTSize.utilityIcon, alignment: .trailing)
                Menu {
                    Button(row.settings.isPinned ? "Unpin" : "Pin") { module.togglePin(for: identity) }
                    Button("Reset") { module.reset(identity) }
                    Divider()
                    Button("Ignore app") { module.setIgnored(true, for: identity) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("More controls for \(identity.displayName)")
            }

            if module.settings.showMeters, row.isProducingAudio {
                AudioLevelMeter(level: row.observed?.peakLevel ?? 0)
                    .accessibilityLabel("Level for \(identity.displayName)")
                    .accessibilityValue(levelText)
            }
        }
        .padding(DTSpace.md)
    }

    private var appIcon: some View {
        Group {
            if let bundleID = identity.bundleID,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
            } else {
                Image(systemName: "waveform").resizable().scaledToFit().padding(DTSpace.sm)
            }
        }
        .frame(width: DTSize.previewSmall, height: DTSize.previewSmall)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var healthText: some View {
        switch row.observed?.health {
        case .degraded(let reason), .failed(let reason):
            Label(reason, systemImage: "exclamationmark.triangle.fill")
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.warning)
                .lineLimit(1)
        default:
            if let route = row.observed?.activeDeviceUID,
               route != module.observedState?.defaultOutputUID {
                Text("Custom output").font(DTTypography.caption).foregroundStyle(DTColor.textSecondary)
            }
        }
    }

    private var levelText: String {
        let level = row.observed?.peakLevel ?? 0
        return level >= 0.98 ? "Clipping" : "\(Int(level * 100)) percent"
    }
}

private struct AudioLevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(DTColor.border)
                Capsule()
                    .fill(level >= AudioSafetyPolicy.limiterCeiling ? DTColor.danger : DTColor.success)
                    .frame(width: proxy.size.width * CGFloat(max(0, min(1, level))))
            }
        }
        .frame(height: DTSpace.xs)
    }
}
