import AppKit
import SwiftUI
import DropThingsCore
import DropThingsDesignSystem
import DropThingsModules

/// One-shot welcome window shown the first time the app launches. Tracks
/// completion in a small `UserDefaults` flag; never shows again after the
/// user dismisses it.
@MainActor
final class OnboardingWindowController {
    static let completedKey = "app.dropthings.onboarding.completed"

    let window: NSWindow
    var onEnableFileShelf: (() -> Void)?
    var onComplete: (() -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to DropThings"
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
    }

    func setContent<V: View>(_ view: V) {
        window.contentView = NSHostingView(rootView: AnyView(view))
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        window.orderOut(nil)
        onComplete?()
    }

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }
}

struct OnboardingView: View {
    let onEnableFileShelf: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DTSpace.lg) {
            VStack(alignment: .leading, spacing: DTSpace.sm) {
                Image("DropThingsLogoTransparent")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                Text("Welcome to DropThings")
                    .font(DTTypography.windowTitle)
                Text("A native macOS utility hub. One app, many small tools.")
                    .font(DTTypography.body)
                    .foregroundStyle(DTColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: DTSpace.sm) {
                suggestion(
                    icon: "tray.and.arrow.down",
                    title: "File Shelf",
                    body: "Drop files here. Pick them up in any app. Pin items to keep them across restarts."
                )
                suggestion(
                    icon: "scroll",
                    title: "Scroll Control",
                    body: "Natural scroll on the trackpad, Windows-style wheel on the mouse."
                )
                suggestion(
                    icon: "menubar.rectangle",
                    title: "Menu Bar Cleaner",
                    body: "Hide icons you don't need. Reveal them with one click."
                )
            }

            Spacer(minLength: 0)

            HStack {
                Button("Skip for now", action: onSkip)
                    .controlSize(.regular)
                Spacer()
                Button {
                    onEnableFileShelf()
                    onSkip()
                } label: {
                    Label("Enable File Shelf and continue", systemImage: "tray.and.arrow.down")
                }
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(DTSpace.xl)
        .frame(width: 480, height: 360)
        .background(DTColor.background)
    }

    private func suggestion(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: DTSpace.sm) {
            Image(systemName: icon)
                .foregroundStyle(DTColor.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(DTTypography.body.weight(.semibold))
                Text(body)
                    .font(DTTypography.caption)
                    .foregroundStyle(DTColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
