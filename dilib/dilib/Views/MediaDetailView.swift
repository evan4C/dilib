//
//  MediaDetailView.swift
//  dilib
//
//  Created by 李凡 on 2025/11/02.
//

import AppKit
import SwiftUI
import SwiftData

struct MediaDetailView: View {
    @Environment(\.openURL) private var openURL
    @Bindable private var item: MediaItem

    var onEdit: (MediaItem) -> Void
    var onDelete: (MediaItem) -> Void
    @State private var confirmingDelete: Bool = false

    init(item: MediaItem, onEdit: @escaping (MediaItem) -> Void, onDelete: @escaping (MediaItem) -> Void) {
        self._item = Bindable(item)
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                metaGrid
                noteSection
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(item.isFavorite ? "Unfavorite" : "Favorite", systemImage: item.isFavorite ? "star.slash" : "star.fill") {
                    item.isFavorite.toggle()
                    item.updatedAt = .now
                }
                Button("Edit", systemImage: "pencil") {
                    onEdit(item)
                }
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .help("Delete this media item")
            }
        }
        .alert("Delete \(item.title))", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                onDelete(item)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this media item? This action cannot be undone.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 24) {
            Group {
                if let cover = item.coverImage {
                    Image(nsImage: cover)
                        .resizable()
                        .scaledToFit()
                } else {
                    item.accentGradient
                }
            }
            .frame(width: 220, height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(radius: 12, y: 8)

            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                Text(item.displayCreator)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Label(item.mediaKind.displayName, systemImage: item.mediaKind.iconName)
                    if let year = item.year {
                        Label(String(year), systemImage: "calendar")
                    }
                    Label(item.status.displayName, systemImage: item.status.symbolName)
                }
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.secondary)
                .font(.callout)

                if !item.tags.isEmpty {
                    TagsView(tags: item.tags)
                }

                if let link = item.externalLink {
                    Button {
                        openURL(link)
                    } label: {
                        Label("Open in Browser", systemImage: "safari")
                    }
                }

                RatingView(rating: $item.rating)
                .padding(.top, 8)
            }
            Spacer()
        }
    }

    private var metaGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.title3.weight(.semibold))
            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                gridRow(label: "Platform", value: item.displayPlatform)
                gridRow(label: "Added", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
                gridRow(label: "Updated", value: item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                if let release = item.releaseDate {
                    gridRow(label: "Release Date", value: release.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
    }

    private func gridRow(label: String, value: String) -> some View {
        GridRow {
            Text(label)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "-" : value)
                .font(.body)
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("Autosaves")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    TextEditor(text: $item.note)
                        .scrollContentBackground(.hidden)
                        .padding(16)
                }
                .frame(minHeight: 200)
        }
    }
}

private struct TagsView: View {
        var tags: [String]

        var body: some View {
            TagFlow(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
            }
        }
    }

}

private struct RatingView: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 4) {
            Text("Rating:")
                .font(.callout.weight(.semibold))
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
                    .foregroundStyle(value <= rating ? .yellow : .secondary)
                    .onTapGesture {
                        rating = value == rating ? 0 : value
                    }
            }
        }
    }
}

private struct TagFlow<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        TagFlowLayout(spacing: spacing) {
            content
        }
    }
}

private struct TagFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var width: CGFloat = 0
        var height: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth && lineWidth > 0 {
                height += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + (lineWidth > 0 ? spacing : 0)
            lineHeight = max(lineHeight, size.height)
            width = max(width, lineWidth)
        }

        height += lineHeight
        let resolvedWidth = proposal.width ?? width
        let finalWidth = resolvedWidth.isFinite ? resolvedWidth : width
        return CGSize(width: finalWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.minX + maxWidth && origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(width: size.width, height: size.height))
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview("Detail - Rich") {
    let item = MediaItem(
        title: "The Great Adventure",
        creator: "John Doe",
        mediaKind: .book,
        releaseDate: Calendar.current.date(from: DateComponents(year: 2020, month: 5, day: 20)),
        platform: "Kindle",
        externalLink: URL(string: "https://www.google.com"),
        rating: 4,
        status: .completed,
        tags: ["xxxx", "Adventure", "Bestseller", "Bestseller", "Bestseller", "Bestseller", "Bestseller", "Bestseller", "Bestseller", "Bestseller", "Bestseller"],
        note: "An exhilarating journey through uncharted territories.",
        isFavorite: true,
        coverImageData: nil
    )
    return NavigationStack {
        MediaDetailView(item: item, onEdit: { _ in }, onDelete: { _ in })
    }
    .frame(width: 760, height: 820)
    .modelContainer(for: MediaItem.self, inMemory: true)
}
