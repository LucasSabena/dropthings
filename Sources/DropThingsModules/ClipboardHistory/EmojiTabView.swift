import SwiftUI
import DropThingsCore
import DropThingsDesignSystem

/// The Emojis tab: a grouped, scrollable grid of emojis filtered by the panel
/// search query. Selection and pick are driven by the parent's keyboard nav.
struct EmojiTabView: View {
    let query: String
    @Binding var selection: EmojiEntry?
    let onPick: (EmojiEntry) -> Void

    private var grouped: [(EmojiCategory, [EmojiEntry])] {
        EmojiCatalog.grouped(EmojiCatalog.search(query))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DTSpace.lg) {
                ForEach(grouped, id: \.0) { category, entries in
                    VStack(alignment: .leading, spacing: DTSpace.sm) {
                        Text(category.rawValue)
                            .font(DTTypography.caption.weight(.semibold))
                            .foregroundStyle(DTColor.textSecondary)
                            .padding(.horizontal, DTSpace.xs)
                        LazyVGrid(columns: gridColumns, spacing: DTSpace.xs) {
                            ForEach(entries) { entry in
                                emojiCell(entry)
                            }
                        }
                    }
                }
                if grouped.isEmpty {
                    Text("No emojis match \"\(query)\".")
                        .font(DTTypography.body)
                        .foregroundStyle(DTColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, DTSpace.xxl)
                }
            }
            .padding(DTSpace.lg)
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: DTSpace.xs), count: 10)
    }

    private func emojiCell(_ entry: EmojiEntry) -> some View {
        let isSelected = selection == entry
        return Button {
            onPick(entry)
        } label: {
            Text(entry.glyph)
                .font(.system(size: 22))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: DTRadius.sm, style: .continuous)
                        .fill(isSelected ? DTColor.accent.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(entry.name)
        .onHover { hovering in
            if hovering { selection = entry }
        }
    }
}
