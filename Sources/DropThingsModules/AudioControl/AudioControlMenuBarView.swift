import AppKit
import SwiftUI
import DropThingsAudioControlKit
import DropThingsDesignSystem

struct AudioControlMenuBarView: View {
    @ObservedObject var module: AudioControlModule

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            outputPicker
                .padding(.horizontal, DTSpace.lg)
                .padding(.vertical, DTSpace.md)

            Divider()

            masterVolume
                .padding(DTSpace.lg)

            Divider()

            if let media = module.observedState?.mediaPlayback {
                nowPlaying(media)
                    .padding(.horizontal, DTSpace.lg)
                    .padding(.vertical, DTSpace.md)
                Divider()
            }

            appsHeader
                .padding(.horizontal, DTSpace.lg)
                .padding(.top, DTSpace.md)
                .padding(.bottom, DTSpace.sm)

            appContent

            if let error = module.outputControlError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.warning)
                    .lineLimit(2)
                    .padding(.horizontal, DTSpace.lg)
                    .padding(.vertical, DTSpace.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
    }

    private var outputPicker: some View {
        Menu {
            if module.availableOutputs.isEmpty {
                Text("No outputs available")
            } else {
                ForEach(module.availableOutputs) { device in
                    Button {
                        module.setDefaultOutput(deviceUID: device.uid)
                    } label: {
                        Label {
                            Text(device.name)
                        } icon: {
                            if device.uid == module.observedState?.defaultOutputUID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DTSpace.sm) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(DTColor.accent)
                VStack(alignment: .leading, spacing: DTSpace.xxs) {
                    Text(module.defaultOutput?.name ?? "Output unavailable")
                        .font(DTTypography.body.weight(.semibold))
                        .foregroundStyle(DTColor.textPrimary)
                        .lineLimit(1)
                    Text(module.defaultOutput.map(outputDetail) ?? "Waiting for Core Audio")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textSecondary)
                }
                Spacer(minLength: DTSpace.sm)
                Image(systemName: "chevron.up.chevron.down")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .accessibilityLabel("System audio output")
        .accessibilityValue(module.defaultOutput?.name ?? "Unavailable")
    }

    private var masterVolume: some View {
        HStack(spacing: DTSpace.md) {
            outputDeviceIcon

            VStack(alignment: .leading, spacing: DTSpace.sm) {
                HStack {
                    Text(module.defaultOutput?.name ?? "System output")
                        .font(DTTypography.body.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(masterVolumeLabel)
                        .font(DTTypography.caption.monospacedDigit())
                        .foregroundStyle(DTColor.textSecondary)
                }

                HStack(spacing: DTSpace.sm) {
                    Button {
                        module.toggleSystemOutputMute()
                    } label: {
                        Image(systemName: masterVolumeIcon)
                            .frame(width: DTSize.iconButton, height: DTSize.iconButton)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(module.systemOutputState?.isMuted == true ? DTColor.danger : DTColor.textSecondary)
                    .disabled(module.systemOutputState?.canSetMute != true)
                    .accessibilityLabel(module.systemOutputState?.isMuted == true ? "Unmute system output" : "Mute system output")

                    Slider(
                        value: Binding(
                            get: { module.systemOutputState?.volume ?? 0 },
                            set: { module.setSystemOutputVolume($0) }
                        ),
                        in: 0...1
                    )
                    .disabled(module.systemOutputState?.canSetVolume != true)
                    .accessibilityLabel("System output volume")
                    .accessibilityValue(masterVolumeLabel)
                }
            }
        }
    }

    private var outputDeviceIcon: some View {
        Image(systemName: "hifispeaker.fill")
            .font(DTTypography.moduleIcon)
            .foregroundStyle(DTColor.accent)
            .frame(width: DTSize.utilityIcon, height: DTSize.utilityIcon)
            .background(DTColor.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous))
            .accessibilityHidden(true)
    }

    private var appsHeader: some View {
        HStack {
            Text("Apps")
                .font(DTTypography.sectionTitle)
                .foregroundStyle(DTColor.textSecondary)
                .textCase(.uppercase)
            Spacer()
            if !module.visibleApps.isEmpty {
                Text("\(module.visibleApps.count)")
                    .font(DTTypography.caption.monospacedDigit())
                    .foregroundStyle(DTColor.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func nowPlaying(_ media: MediaPlaybackState) -> some View {
        HStack(spacing: DTSpace.sm) {
            Image(systemName: media.isPlaying ? "waveform" : "pause.circle")
                .foregroundStyle(DTColor.accent)
                .frame(width: DTSize.utilityIcon, height: DTSize.utilityIcon)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(media.title)
                    .font(DTTypography.body.weight(.semibold))
                    .lineLimit(1)
                Text(mediaDetail(media))
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: DTSpace.xs)
            Button { module.sendMediaCommand(.previousTrack) } label: {
                Image(systemName: "backward.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous item")
            Button { module.sendMediaCommand(.togglePlayPause) } label: {
                Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(media.isPlaying ? "Pause" : "Play")
            Button { module.sendMediaCommand(.nextTrack) } label: {
                Image(systemName: "forward.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next item")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now playing in \(media.sourceDisplayName)")
    }

    private func mediaDetail(_ media: MediaPlaybackState) -> String {
        [media.artist, media.album, media.sourceDisplayName]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " · ")
    }

    @ViewBuilder
    private var appContent: some View {
        switch module.state {
        case .starting:
            VStack(spacing: DTSpace.sm) {
                ProgressView().controlSize(.small)
                Text("Finding apps that are playing audio…")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let reason, _), .degraded(let reason), .unavailable(let reason):
            AudioControlPopoverMessage(
                icon: "exclamationmark.triangle",
                title: "Audio controls need attention",
                detail: reason
            )
        default:
            if module.visibleApps.isEmpty {
                AudioControlPopoverMessage(
                    icon: "speaker.slash",
                    title: "No apps are playing audio",
                    detail: "Start playback in an app and it will appear here automatically."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(module.visibleApps) { row in
                            AudioControlPopoverAppRow(module: module, row: row)
                            if row.id != module.visibleApps.last?.id { Divider() }
                        }
                    }
                }
            }
        }
    }

    private var masterVolumeLabel: String {
        guard let volume = module.systemOutputState?.volume else { return "—" }
        return "\(Int((volume * 100).rounded()))%"
    }

    private var masterVolumeIcon: String {
        module.menuBarIconName
    }

    private func outputDetail(_ device: AudioDeviceIdentity) -> String {
        let rate = device.sampleRate > 0 ? String(format: "%.1f kHz", device.sampleRate / 1_000) : "rate unavailable"
        return "System default · \(device.transport) · \(rate)"
    }
}

private struct AudioControlPopoverAppRow: View {
    @ObservedObject var module: AudioControlModule
    let row: AudioControlAppRow

    private var identity: AudioAppIdentity { row.settings.identity }

    var body: some View {
        VStack(spacing: DTSpace.sm) {
            HStack(spacing: DTSpace.sm) {
                appIcon
                Text(identity.displayName)
                    .font(DTTypography.body.weight(.medium))
                    .lineLimit(1)
                if !row.isProducingAudio {
                    Text("Idle")
                        .font(DTTypography.caption)
                        .foregroundStyle(DTColor.textTertiary)
                }
                Spacer(minLength: DTSpace.sm)
                routeMenu
                Button {
                    module.toggleSolo(for: identity)
                } label: {
                    Text("S")
                        .font(DTTypography.caption.weight(.bold))
                        .frame(width: DTSize.iconButton, height: DTSize.iconButton)
                        .background(row.settings.isSoloed ? DTColor.warning.opacity(0.18) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: DTRadius.sm))
                }
                .buttonStyle(.plain)
                .foregroundStyle(row.settings.isSoloed ? DTColor.warning : DTColor.textSecondary)
                .accessibilityLabel("\(row.settings.isSoloed ? "Disable solo for" : "Solo") \(identity.displayName)")
            }

            HStack(spacing: DTSpace.sm) {
                Button {
                    module.toggleMute(for: identity)
                } label: {
                    Image(systemName: row.settings.isMuted ? "speaker.slash.fill" : "speaker.wave.2")
                        .frame(width: DTSize.iconButton, height: DTSize.iconButton)
                }
                .buttonStyle(.plain)
                .foregroundStyle(row.settings.isMuted ? DTColor.danger : DTColor.textSecondary)
                .accessibilityLabel("\(row.settings.isMuted ? "Unmute" : "Mute") \(identity.displayName)")

                Slider(
                    value: Binding(
                        get: { row.settings.volume },
                        set: { module.setVolume($0, for: identity) }
                    ),
                    in: 0...1
                )
                .accessibilityLabel("Volume for \(identity.displayName)")
                .accessibilityValue("\(volumePercent) percent")

                Text("\(volumePercent)%")
                    .font(DTTypography.caption.monospacedDigit())
                    .foregroundStyle(DTColor.textSecondary)
                    .frame(width: DTSize.utilityIcon, alignment: .trailing)

                appActions
            }

            if module.settings.showMeters, row.isProducingAudio {
                AudioControlPopoverMeter(level: row.observed?.peakLevel ?? 0)
            }
        }
        .padding(.horizontal, DTSpace.lg)
        .padding(.vertical, DTSpace.md)
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

    private var routeMenu: some View {
        Menu {
            Button {
                module.setRouteDeviceUID(nil, for: identity)
            } label: {
                Label("Follow system output", systemImage: row.settings.routeDeviceUID == nil ? "checkmark" : "speaker.wave.2")
            }
            Divider()
            ForEach(module.availableOutputs) { device in
                Button {
                    module.setRouteDeviceUID(device.uid, for: identity)
                } label: {
                    Label(device.name, systemImage: row.settings.routeDeviceUID == device.uid ? "checkmark" : "hifispeaker")
                }
            }
        } label: {
            Image(systemName: row.settings.routeDeviceUID == nil ? "hifispeaker" : "hifispeaker.fill")
                .frame(width: DTSize.iconButton, height: DTSize.iconButton)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Output for \(identity.displayName)")
    }

    private var appActions: some View {
        Menu {
            Button(row.settings.isPinned ? "Unpin" : "Pin") { module.togglePin(for: identity) }
            Button("Reset controls") { module.reset(identity) }
            Divider()
            Button("Ignore app") { module.setIgnored(true, for: identity) }
        } label: {
            Image(systemName: "ellipsis.circle")
                .frame(width: DTSize.iconButton, height: DTSize.iconButton)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("More controls for \(identity.displayName)")
    }

    private var volumePercent: Int {
        Int((row.settings.volume * 100).rounded())
    }
}

private struct AudioControlPopoverMessage: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: DTSpace.sm) {
            Image(systemName: icon)
                .font(DTTypography.emptyStateGlyph)
                .foregroundStyle(DTColor.textTertiary)
            Text(title)
                .font(DTTypography.body.weight(.semibold))
            Text(detail)
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: DTSize.compactMessageWidth)
        }
        .padding(DTSpace.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AudioControlPopoverMeter: View {
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
        .accessibilityLabel("Audio level")
        .accessibilityValue(level >= 0.98 ? "Clipping" : "\(Int(level * 100)) percent")
    }
}
