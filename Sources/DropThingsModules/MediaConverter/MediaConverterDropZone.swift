import SwiftUI
import UniformTypeIdentifiers
import AppKit
import DropThingsCore
import DropThingsDesignSystem
import DropThingsMediaConverterKit

/// Drop/select zone with a full keyboard equivalent button (accessibility:
/// drag-only actions must have a button path). Selects the Simple preset when
/// in Simple mode; Advanced mode uses the persisted defaults.
struct MediaConverterDropZone: View {
    @ObservedObject var module: MediaConverterModule
    let advanced: Bool
    @State private var isTargeted = false
    @State private var selectedPreset: MediaPresetID
    @State private var selectedFormat: MediaFormatID
    @State private var selectedKind: MediaKind

    init(module: MediaConverterModule, advanced: Bool) {
        self.module = module
        self.advanced = advanced
        _selectedPreset = State(initialValue: module.settings.defaultPreset)
        _selectedFormat = State(initialValue: .jpeg)
        _selectedKind = State(initialValue: .image)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.md) {
            if !advanced {
                Picker("Preset", selection: $selectedPreset) {
                    ForEach(MediaPreset.shipped.filter { module.ffmpegAvailable || $0.applicableKinds == [.image] }) { preset in
                        Text(preset.title).tag(preset.id)
                    }
                }
            } else {
                Picker("Media type", selection: $selectedKind) {
                    Text("Image").tag(MediaKind.image)
                    if module.ffmpegAvailable {
                        Text("Audio").tag(MediaKind.audio)
                        Text("Video").tag(MediaKind.video)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedKind) { _, kind in
                    selectedFormat = defaultFormat(for: kind)
                }
                Picker("Output format", selection: $selectedFormat) {
                    ForEach(MediaCapabilityManifest.shipped.availableOutputs(for: selectedKind, ffmpegAvailable: module.ffmpegAvailable), id: \.rawValue) { format in
                        Text(label(for: format)).tag(format)
                    }
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous)
                    .fill(isTargeted ? DTColor.accent.opacity(0.08) : DTColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DTRadius.lg, style: .continuous)
                            .strokeBorder(
                                isTargeted ? DTColor.accent : DTColor.border,
                                lineWidth: isTargeted ? 2 : 1
                            )
                    )

                VStack(spacing: DTSpace.sm) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: DTSize.utilityIcon, weight: .regular))
                        .foregroundStyle(DTColor.textSecondary)
                    Text("Drop media files here, or")
                        .font(DTTypography.body)
                        .foregroundStyle(DTColor.textSecondary)
                    Button("Select Files") { selectFiles() }
                        .accessibilityLabel("Select media files to convert")
                }
                .padding(DTSpace.xl)
            }
            .frame(minHeight: 140)
            .onDrop(of: [.fileURL], delegate: self)
        }
    }

    private func label(for format: MediaFormatID) -> String {
        switch format {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .heic: return "HEIC"
        case .webp: return "WebP"
        case .tiff: return "TIFF"
        case .m4aAAC: return "M4A (AAC)"
        case .wav: return "WAV"
        case .flac: return "FLAC"
        case .opus: return "Opus"
        case .mp4H264: return "MP4 (H.264)"
        case .movH264: return "MOV (H.264)"
        case .mkvH264: return "MKV (H.264)"
        default: return format.rawValue
        }
    }

    private func defaultFormat(for kind: MediaKind) -> MediaFormatID {
        switch kind {
        case .image: return .jpeg
        case .audio: return .m4aAAC
        case .video: return .mp4H264
        }
    }

    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        // Allow images always; audio/video only when the FFmpeg backend is
        // packaged, so the picker never offers conversions that would fail.
        var types: [UTType] = [.png, .jpeg, .heic, .tiff, .image]
        if module.ffmpegAvailable {
            types.append(contentsOf: [.audio, .mp3, .mpeg4Audio, .movie, .video, .quickTimeMovie])
        }
        panel.allowedContentTypes = types
        if panel.runModal() == .OK {
            handle(urls: panel.urls)
        }
    }

    private func handle(urls: [URL]) {
        guard !urls.isEmpty else { return }
        let outputDir = module.settings.outputDirectory ?? urls.first!.deletingLastPathComponent()
        if advanced {
            module.enqueueConversion(sources: urls) { source in
                MediaConversionRequest(
                    source: source,
                    outputDirectory: outputDir,
                    outputFormat: selectedFormat,
                    resize: .none,
                    noUpscale: module.settings.noUpscaleByDefault,
                    quality: 82,
                    metadata: module.settings.metadata,
                    conflict: module.settings.conflict
                )
            }
        } else {
            // Simple mode: classify each source by kind and resolve the preset
            // against that kind so audio/video sources pick the right output.
            module.enqueueConversion(sources: urls) { source in
                let kind = MediaKindClassifier.kind(of: source)
                if let request = try? MediaPlanResolver.resolve(
                    presetID: selectedPreset,
                    source: source,
                    sourceKind: kind,
                    outputDirectory: outputDir,
                    manifest: .shipped,
                    ffmpegAvailable: module.ffmpegAvailable
                ) {
                    return request
                }
                let fallback = defaultFormat(for: kind)
                return MediaConversionRequest(
                    source: source, outputDirectory: outputDir,
                    outputFormat: fallback, resize: kind == .image ? .maxEdge(maxEdge: 1600) : .none,
                    quality: 82, metadata: module.settings.metadata,
                    conflict: module.settings.conflict
                )
            }
        }
    }
}

extension MediaConverterDropZone: DropDelegate {
    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.15)) { isTargeted = true }
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.15)) { isTargeted = false }
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        let providers = info.itemProviders(for: [.fileURL])
        guard !providers.isEmpty else { return false }

        Task {
            var collected: [URL] = []
            for provider in providers {
                if let url = await loadURL(from: provider) {
                    collected.append(url)
                }
            }
            await MainActor.run { handle(urls: collected) }
        }
        return true
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }
}
