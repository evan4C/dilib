//
//  MediaGridView.swift
//  dilib
//
//  Created by 李凡 on 2025/11/03.
//

import AppKit
import SwiftUI
import SwiftData

struct MediaGridView: View {
    let items: [MediaItem]
    @Binding var selectedItem: MediaItem?
    var onEdit: (MediaItem) -> Void
    var onDelete: (MediaItem) -> Void
    
    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 24)]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 28) {
                if items.isEmpty {
                    MediaGridEmptyView()
                } else {
                    ForEach(items) { item in
                        MediaCardView(item: item, isSelected: isSelected(item))
                            .onTapGesture {
                                selectedItem = item
                            }
                            .contextMenu {
                                Button(item.isFavorite ? "Remove Favorite" : "Mark Favorite", systemImage: item.isFavorite ? "star.slash" : "star.fill") {
                                    toggleFavorite(item)
                                }
                                Button("Edit", systemImage: "pencil") {
                                    onEdit(item)
                                }
                                Divider()
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    onDelete(item)
                                }
                            }
                    }
                    
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .background(
            LinearGradient(colors: [Color(nsColor: .windowBackgroundColor), .clear], startPoint: .top, endPoint: .bottom)
        )
    }
    
    private func isSelected(_ item: MediaItem) -> Bool {
        guard let selectedItem else { return false }
        return selectedItem.persistentModelID == item.persistentModelID
    }
    
    private func toggleFavorite(_ item: MediaItem) {
        withAnimation(.easeInOut(duration: 0.25)) {
            item.isFavorite.toggle()
            item.updatedAt = .now
        }
    }
}

private struct MediaGridEmptyView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .symbolRenderingMode(.hierarchical)
            Text("Start building your media library")
                .font(.title3)
            Text("Add books, movies, music, podcasts, and more to see them here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

struct MediaCardView: View {
    let item: MediaItem
    let isSelected: Bool
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if  let cover = item.coverImage {
                    Image(nsImage: cover)
                        .resizable()
                        .scaledToFill()
                } else {
                    item.accentGradient
                }
            }
            .frame(height: 260)
            .clipped()
            
            LinearGradient(colors: [.black.opacity(0.75), .black.opacity(0.0)], startPoint: .bottom, endPoint: .top)
                .frame(height: 130)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: item.mediaKind.iconName)
                    Text(item.mediaKind.displayName.uppercased())
                        .font(.caption.weight(.semibold))
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(Capsule())
                
                Text(item.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .padding(.horizontal, 2)

                HStack(spacing: 10) {
                    if !item.creator.isEmpty {
                        Label(item.displayCreator, systemImage: "person.fill")
                    }
                    if let year = item.year {
                        Label(String(year), systemImage: "calendar")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(18)
            .foregroundStyle(.secondary)
            
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
        }
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 10)
        .overlay(alignment: .topTrailing) {
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .symbolRenderingMode(.multicolor)
                    .padding(12)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isSelected)
    }
}

#Preview("Grid") {
    let items: [MediaItem] = [
        MediaItem(title: "Sample 1", creator: "Author A", mediaKind: .book, releaseDate: Date(timeIntervalSince1970: 1609459200), isFavorite: true),
        MediaItem(title: "Sample 2", creator: "Author B", mediaKind: .movie, releaseDate: Date(timeIntervalSince1970: 1612137600), note: "A great movie to watch on weekends."),
        MediaItem(title: "Sample 3", creator: "Author C", mediaKind: .album, isFavorite: false),
        MediaItem(title: "Sample 4", creator: "Author D", mediaKind: .podcast, releaseDate: Date(timeIntervalSince1970: 1614556800), rating: 4, status: .completed, isFavorite: true)
    ]
    MediaGridView(items: items, selectedItem: .constant(items.first), onEdit: { _ in }, onDelete: { _ in })
        .frame(width: 960, height: 720)
        .modelContainer(for: MediaItem.self, inMemory: true)
}

#Preview("Empty Grid") {
    MediaGridView(items: [], selectedItem: .constant(nil), onEdit: { _ in }, onDelete: { _ in })
        .frame(width: 960, height: 720)
        .modelContainer(for: MediaItem.self, inMemory: true)
}
