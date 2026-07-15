import AppKit
import SwiftUI
import DropThingsAudioControlKit
import DropThingsDesignSystem
import DropThingsPlatform

struct AudioControlMenuBarView: View {
    @ObservedObject var module: AudioControlModule

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusHeader
                .padding(.horizontal, DTSpace.lg)
                .padding(.vertical, DTSpace.md)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    sectionTitle("Outputs", count: module.availableOutputs.count)
                    outputContent

                    Divider().padding(.horizontal, DTSpace.lg)

                    if let media = module.observedState?.mediaPlayback {
                        nowPlaying(media)
                        Divider().padding(.horizontal, DTSpace.lg)
                    }

                    sectionTitle("Apps", count: module.visibleApps.count)
                    appContent
                }
            }

            if let error = module.outputControlError {
                Divider()
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

    private var statusHeader: some View {
        HStack(spacing: DTSpace.sm) {
            Image(systemName: module.menuBarIconName)
                .foregroundStyle(DTColor.accent)
                .frame(width: DTSize.iconButton, height: DTSize.iconButton)

            Text(module.defaultOutput?.name ?? "No system output")
                .font(DTTypography.body.weight(.semibold))
                .lineLimit(1)

            if let source = module.observedState?.mediaPlayback?.sourceDisplayName {
                Text("·")
                    .foregroundStyle(DTColor.textTertiary)
                Image(systemName: "music.note")
                    .foregroundStyle(DTColor.textSecondary)
                Text(source)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DTSpace.sm)

            if case .starting = module.state {
                ProgressView().controlSize(.small)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: DTSize.statusDot, height: DTSize.statusDot)
                    .accessibilityLabel(statusLabel)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("System output, \(module.defaultOutput?.name ?? "unavailable"). \(statusLabel)")
    }

    @ViewBuilder
    private var outputContent: some View {
        if module.availableOutputs.isEmpty {
            compactMessage(
                icon: "speaker.slash",
                title: "No audio outputs",
                detail: "Connect speakers or headphones and they will appear here."
            )
        } else {
            ForEach(module.availableOutputs) { device in
                AudioOutputRow(module: module, device: device)
                if device.id != module.availableOutputs.last?.id {
                    Divider().padding(.leading, DTSpace.lg + DTSize.previewSmall + DTSpace.md)
                }
            }
        }
    }

    private func nowPlaying(_ media: MediaPlaybackState) -> some View {
        HStack(spacing: DTSpace.md) {
            Image(systemName: media.isPlaying ? "waveform" : "pause.fill")
                .foregroundStyle(DTColor.accent)
                .frame(width: DTSize.previewSmall, height: DTSize.previewSmall)
                .background(DTColor.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DTRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(media.title)
                    .font(DTTypography.body.weight(.semibold))
                    .lineLimit(1)
                Text(mediaDetail(media))
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: DTSpace.sm)

            mediaButton("backward.fill", label: "Previous") { module.sendMediaCommand(.previousTrack) }
            mediaButton(media.isPlaying ? "pause.fill" : "play.fill", label: media.isPlaying ? "Pause" : "Play") {
                module.sendMediaCommand(.togglePlayPause)
            }
            mediaButton("forward.fill", label: "Next") { module.sendMediaCommand(.nextTrack) }
        }
        .padding(.horizontal, DTSpace.lg)
        .padding(.vertical, DTSpace.md)
    }

    @ViewBuilder
    private var appContent: some View {
        switch module.state {
        case .starting:
            compactMessage(icon: "waveform", title: "Finding audio apps", detail: "Apps appear as soon as they produce audio.")
        case .failed(let reason, _), .degraded(let reason), .unavailable(let reason):
            compactMessage(icon: "exclamationmark.triangle", title: "Audio controls need attention", detail: reason)
        default:
            if module.visibleApps.isEmpty {
                compactMessage(
                    icon: "waveform.slash",
                    title: "No apps are playing audio",
                    detail: "Start playback and the real application will appear automatically."
                )
            } else {
                ForEach(module.visibleApps) { row in
                    AudioAppMixerRow(module: module, row: row)
                    if row.id != module.visibleApps.last?.id {
                        Divider().padding(.leading, DTSpace.lg + DTSize.previewSmall + DTSpace.md)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack {
            Text(title.uppercased())
                .font(DTTypography.sectionTitle)
                .foregroundStyle(DTColor.textSecondary)
            Spacer()
            Text("\(count)")
                .font(DTTypography.caption.monospacedDigit())
                .foregroundStyle(DTColor.textTertiary)
        }
        .padding(.horizontal, DTSpace.lg)
        .padding(.top, DTSpace.md)
        .padding(.bottom, DTSpace.xs)
        .accessibilityElement(children: .combine)
    }

    private func compactMessage(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: DTSpace.md) {
            Image(systemName: icon)
                .foregroundStyle(DTColor.textTertiary)
                .frame(width: DTSize.previewSmall, height: DTSize.previewSmall)
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(title).font(DTTypography.body.weight(.semibold))
                Text(detail).font(DTTypography.caption).foregroundStyle(DTColor.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, DTSpace.lg)
        .padding(.vertical, DTSpace.md)
    }

    private func mediaButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: DTSize.iconButton, height: DTSize.iconButton)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }

    private func mediaDetail(_ media: MediaPlaybackState) -> String {
        [media.artist, media.album, media.sourceDisplayName]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " · ")
    }

    private var statusColor: Color {
        switch module.state {
        case .running: return DTColor.success
        case .degraded: return DTColor.warning
        case .failed, .unavailable: return DTColor.danger
        default: return DTColor.textTertiary
        }
    }

    private var statusLabel: String {
        switch module.state {
        case .running: return "Audio controls ready"
        case .degraded(let reason), .unavailable(let reason): return reason
        case .failed(let reason, _): return reason
        case .needsPermission: return "Audio permission required"
        case .starting: return "Starting audio controls"
        case .off: return "Audio controls off"
        }
    }
}

private struct AudioOutputRow: View {
    @ObservedObject var module: AudioControlModule
    let device: AudioDeviceIdentity

    private var state: SystemAudioOutputState? { module.outputState(for: device.uid) }
    private var isActive: Bool { module.activeOutputUID == device.uid }

    var body: some View {
        HStack(spacing: DTSpace.md) {
            Button { module.setDefaultOutput(deviceUID: device.uid) } label: {
                Image(systemName: deviceIcon)
                    .font(DTTypography.moduleIcon)
                    .foregroundStyle(isActive ? Color.white : DTColor.textSecondary)
                    .frame(width: DTSize.previewSmall, height: DTSize.previewSmall)
                    .background(isActive ? DTColor.accent : DTColor.surfaceRaised)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isActive ? "\(device.name), current system output" : "Use \(device.name) as system output")

            VStack(alignment: .leading, spacing: DTSpace.xs) {
                HStack(spacing: DTSpace.xs) {
                    Text(device.name)
                        .font(DTTypography.body.weight(isActive ? .semibold : .regular))
                        .lineLimit(1)
                    if isActive {
                        Text("SYSTEM")
                            .font(DTTypography.badgeLabel)
                            .foregroundStyle(DTColor.accent)
                    }
                    Spacer()
                    Text(volumeLabel)
                        .font(DTTypography.caption.monospacedDigit())
                        .foregroundStyle(DTColor.textSecondary)
                        .frame(width: DTSize.utilityIcon, alignment: .trailing)
                }

                HStack(spacing: DTSpace.sm) {
                    Button { module.toggleOutputMute(deviceUID: device.uid) } label: {
                        Image(systemName: outputIcon)
                            .frame(width: DTSize.iconButton, height: DTSize.iconButton)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(state?.isMuted == true ? DTColor.danger : DTColor.textSecondary)
                    .disabled(state?.canSetMute != true)
                    .accessibilityLabel(state?.isMuted == true ? "Unmute \(device.name)" : "Mute \(device.name)")

                    if state?.canSetVolume == true, state?.volume != nil {
                        Slider(
                            value: Binding(
                                get: { state?.volume ?? 0 },
                                set: { module.setOutputVolume($0, deviceUID: device.uid) }
                            ),
                            in: 0...1
                        )
                        .accessibilityLabel("Volume for \(device.name)")
                        .accessibilityValue(volumeLabel)
                    } else {
                        Text("Use the device controls to change volume")
                            .font(DTTypography.caption)
                            .foregroundStyle(DTColor.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(.horizontal, DTSpace.lg)
        .padding(.vertical, DTSpace.sm)
        .contentShape(Rectangle())
    }

    private var volumeLabel: String {
        guard let volume = state?.volume else { return "—" }
        return "\(Int((volume * 100).rounded()))%"
    }

    private var outputIcon: String {
        guard state?.isMuted != true else { return "speaker.slash.fill" }
        switch state?.volume ?? 0 {
        case ..<0.01: return "speaker.slash"
        case ..<0.34: return "speaker.wave.1"
        case ..<0.67: return "speaker.wave.2"
        default: return "speaker.wave.3"
        }
    }

    private var deviceIcon: String {
        switch device.transport {
        case "Bluetooth": return "headphones"
        case "USB": return "cable.connector"
        case "Display": return "display"
        case "AirPlay": return "airplayaudio"
        default: return "hifispeaker.fill"
        }
    }
}

private struct AudioAppMixerRow: View {
    @ObservedObject var module: AudioControlModule
    let row: AudioControlAppRow

    private var identity: AudioAppIdentity { row.settings.identity }

    var body: some View {
        VStack(spacing: DTSpace.xs) {
            HStack(spacing: DTSpace.md) {
                appIcon

                VStack(alignment: .leading, spacing: DTSpace.xs) {
                    HStack(spacing: DTSpace.xs) {
                        Text(identity.displayName)
                            .font(DTTypography.body.weight(.semibold))
                            .lineLimit(1)
                        if !row.isProducingAudio {
                            Text("IDLE")
                                .font(DTTypography.badgeLabel)
                                .foregroundStyle(DTColor.textTertiary)
                        }
                        Spacer()
                        Text("\(volumePercent)%")
                            .font(DTTypography.caption.monospacedDigit())
                            .foregroundStyle(DTColor.textSecondary)
                            .frame(width: DTSize.utilityIcon, alignment: .trailing)
                    }

                    HStack(spacing: DTSpace.sm) {
                        Button { module.toggleMute(for: identity) } label: {
                            Image(systemName: row.settings.isMuted ? "speaker.slash.fill" : "speaker.wave.2")
                                .frame(width: DTSize.iconButton, height: DTSize.iconButton)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(row.settings.isMuted ? DTColor.danger : DTColor.textSecondary)
                        .accessibilityLabel(row.settings.isMuted ? "Unmute \(identity.displayName)" : "Mute \(identity.displayName)")

                        Slider(
                            value: Binding(
                                get: { row.settings.volume },
                                set: { module.setVolume($0, for: identity) }
                            ),
                            in: 0...1
                        )
                        .accessibilityLabel("Volume for \(identity.displayName)")
                        .accessibilityValue("\(volumePercent) percent")

                        routeMenu
                        appActions
                    }
                }
            }

            if module.settings.showMeters, row.isProducingAudio {
                levelMeter
                    .padding(.leading, DTSize.previewSmall + DTSpace.md)
            }

            if case .degraded(let reason) = row.observed?.health {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, DTSize.previewSmall + DTSpace.md)
            }
        }
        .padding(.horizontal, DTSpace.lg)
        .padding(.vertical, DTSpace.sm)
    }

    private var appIcon: some View {
        Group {
            if let bundleID = identity.bundleID,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
            } else {
                Image(systemName: "app.fill").resizable().scaledToFit().padding(DTSpace.sm)
            }
        }
        .frame(width: DTSize.previewSmall, height: DTSize.previewSmall)
        .accessibilityHidden(true)
    }

    private var routeMenu: some View {
        Menu {
            Button { module.setRouteDeviceUID(nil, for: identity) } label: {
                Label("Follow system output", systemImage: row.settings.routeDeviceUID == nil ? "checkmark" : "speaker.wave.2")
            }
            Divider()
            ForEach(module.availableOutputs) { device in
                Button { module.setRouteDeviceUID(device.uid, for: identity) } label: {
                    Label(device.name, systemImage: row.settings.routeDeviceUID == device.uid ? "checkmark" : "hifispeaker")
                }
            }
        } label: {
            Image(systemName: "arrow.triangle.branch")
                .frame(width: DTSize.iconButton, height: DTSize.iconButton)
                .foregroundStyle(row.settings.routeDeviceUID == nil ? DTColor.textSecondary : DTColor.accent)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Output route for \(identity.displayName)")
        .help(routeHelp)
    }

    private var appActions: some View {
        Menu {
            Button(row.settings.isSoloed ? "Turn off Solo" : "Solo this app") { module.toggleSolo(for: identity) }
            Button(row.settings.isPinned ? "Unpin" : "Keep in mixer") { module.togglePin(for: identity) }
            Button("Reset volume and route") { module.reset(identity) }
            Divider()
            Button("Hide app from mixer") { module.setIgnored(true, for: identity) }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .frame(width: DTSize.iconButton, height: DTSize.iconButton)
                .foregroundStyle(row.settings.isSoloed ? DTColor.warning : DTColor.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("More controls for \(identity.displayName)")
    }

    private var levelMeter: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(DTColor.border)
                Capsule()
                    .fill((row.observed?.peakLevel ?? 0) >= AudioSafetyPolicy.limiterCeiling ? DTColor.danger : DTColor.success)
                    .frame(width: proxy.size.width * CGFloat(max(0, min(1, row.observed?.peakLevel ?? 0))))
            }
        }
        .frame(height: DTSpace.xs)
        .accessibilityLabel("Audio level for \(identity.displayName)")
    }

    private var routeHelp: String {
        guard let uid = row.settings.routeDeviceUID,
              let device = module.availableOutputs.first(where: { $0.uid == uid }) else {
            return "Follows the system output"
        }
        return "Routed to \(device.name)"
    }

    private var volumePercent: Int { Int((row.settings.volume * 100).rounded()) }
}
