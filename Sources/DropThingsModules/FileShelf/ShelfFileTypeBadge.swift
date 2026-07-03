import SwiftUI
import DropThingsDesignSystem

/// Compact uppercase type label ("PNG", "PDF", "FOLDER", "TEXT") shown on
/// a row/card so the user can tell formats apart at a glance. Colors are
/// derived from the format family and the design tokens; no raw colors.
struct ShelfFileTypeBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(DTTypography.badgeLabel)
            .foregroundStyle(foreground)
            .padding(.horizontal, DTSpace.xs)
            .padding(.vertical, 1)
            .background(background, in: RoundedRectangle(cornerRadius: DTRadius.xs, style: .continuous))
    }

    /// Pick a token-based tint by family so images, documents, code, and
    /// containers are visually distinct without inventing one-off colors.
    private var foreground: Color {
        switch family {
        case .image: return DTColor.accent
        case .document: return DTColor.warning
        case .code: return DTColor.success
        case .container, .text, .other: return DTColor.textSecondary
        }
    }

    private var background: Color {
        switch family {
        case .image: return DTColor.accent.opacity(0.12)
        case .document: return DTColor.warning.opacity(0.14)
        case .code: return DTColor.success.opacity(0.14)
        case .container, .text, .other: return DTColor.surface
        }
    }

    private enum Family {
        case image, document, code, container, text, other
    }

    private var family: Family {
        switch label {
        case "PNG", "JPG", "JPEG", "WEBP", "AVIF", "SVG", "GIF", "HEIC", "TIFF", "BMP", "HEIF":
            return .image
        case "PDF", "DOC", "DOCX", "PAGES", "XLSX", "KEY", "PPTX":
            return .document
        case "TXT", "MD", "TEXT":
            return .text
        case "JSON", "JS", "TS", "SWIFT", "PY", "GO", "RS", "CSS", "HTML", "YAML", "XML":
            return .code
        case "FOLDER":
            return .container
        default:
            return .other
        }
    }
}
