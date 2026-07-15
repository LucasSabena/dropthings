import AppKit
import SwiftUI
import UniformTypeIdentifiers
import DropThingsDesignSystem
import DropThingsTranscriptionKit

struct LocalTranscriptionWorkspaceView: View {
    @ObservedObject var module: LocalTranscriptionModule

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let notice = module.notice {
                InlineAlert(style: .info, message: notice)
                    .padding(DTSpace.md)
            }
            queueContent
            Divider()
            footer
        }
        .background(DTColor.background)
        .onDrop(of: [.fileURL], isTargeted: nil, perform: acceptDrop)
    }

    private var header: some View {
        HStack(spacing: DTSpace.md) {
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text("Local Transcription").font(DTTypography.pageTitle)
                Text("Audio and transcript content stay on this Mac.")
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
            }
            Spacer()
            Button { module.chooseAudioFiles() } label: {
                Label("Add WAV Files…", systemImage: "plus")
            }
            Button("Clear Finished") { module.clearFinished() }
                .disabled(!module.hasFinishedItems)
        }
        .padding(DTSpace.lg)
    }

    @ViewBuilder
    private var queueContent: some View {
        if module.queue.isEmpty {
            ContentUnavailableView {
                Label("Drop WAV files here", systemImage: "waveform")
            } description: {
                Text("Or choose one or more 16 kHz mono PCM WAV files.")
            } actions: {
                Button("Choose Files…") { module.chooseAudioFiles() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(module.queue) { item in
                QueueItemRow(module: module, item: item)
            }
            .listStyle(.inset)
        }
    }

    private var footer: some View {
        HStack(spacing: DTSpace.md) {
            let descriptor = CuratedTranscriptionModels.descriptor(for: module.settings.selectedModel)
            Text("\(descriptor.displayName) · \(module.settings.language.displayName) · \(outputLabel)")
                .font(DTTypography.caption)
                .foregroundStyle(DTColor.textSecondary)
            Spacer()
            if module.isProcessing {
                Button("Cancel Current") { module.cancelActiveJob() }
            } else {
                Button("Start Queue") { module.startQueue() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!module.hasWaitingItems)
            }
        }
        .padding(DTSpace.lg)
    }

    private var outputLabel: String {
        module.settings.outputFormats.map(\.fileExtension).sorted().joined(separator: " + ").uppercased()
    }

    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }
        for provider in fileProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else { url = item as? URL }
                guard let url, url.pathExtension.lowercased() == "wav" else { return }
                Task { @MainActor in module.addFiles([url]) }
            }
        }
        return true
    }
}

private struct QueueItemRow: View {
    @ObservedObject var module: LocalTranscriptionModule
    let item: TranscriptionQueueItem

    var body: some View {
        HStack(spacing: DTSpace.md) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: DTSize.iconButton)
            VStack(alignment: .leading, spacing: DTSpace.xxs) {
                Text(item.sourceURL.lastPathComponent).lineLimit(1).truncationMode(.middle)
                Text(statusText)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            if case .completed(let urls) = item.status, let first = urls.first {
                Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([first]) }
            }
            if case .waiting = item.status {
                Button { module.removeQueueItem(id: item.id) } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(item.sourceURL.lastPathComponent)")
            }
        }
        .padding(.vertical, DTSpace.xs)
    }

    private var statusText: String {
        switch item.status {
        case .waiting: "Waiting"
        case .active(let progress): progress.phase.displayName
        case .completed(let urls): "Completed · \(urls.count) output file\(urls.count == 1 ? "" : "s")"
        case .failed(let message): message
        case .cancelled: "Cancelled"
        }
    }

    private var iconName: String {
        switch item.status {
        case .waiting: "clock"
        case .active: "waveform"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "xmark.circle"
        }
    }

    private var iconColor: Color {
        switch item.status {
        case .completed: DTColor.success
        case .failed: DTColor.danger
        case .active: DTColor.accent
        case .waiting, .cancelled: DTColor.textSecondary
        }
    }
}

private extension TranscriptionPhase {
    var displayName: String {
        switch self {
        case .inspect: "Inspecting audio"
        case .modelLoad: "Loading model"
        case .transcribe: "Transcribing"
        case .finalize: "Finalizing outputs"
        }
    }
}
