//
//  Item.swift
//  dilib
//
//  Created by 李凡 on 2025/11/02.
//
import AppKit
import Foundation
import SwiftData
import SwiftUI

enum MediaKind: String, CaseIterable, Codable, Identifiable {
    case book
    case movie
    case album
    case blog
    case video
    case podcast
    case other
    
    var id: String { rawValue }
    
    /// A user‑friendly name for each media kind.
    var displayName: String {
        switch self {
        case .book:   return "Book"
        case .movie:  return "Movie"
        case .album:  return "Album"
        case .blog:   return "Blog Post"
        case .video:  return "Video"
        case .podcast:return "Podcast"
        case .other:  return "Other"
        }
    }
    
    /// System icon name that best represents the media kind.
    var iconName: String {
        switch self {
        case .book:   return "book.closed.fill"
        case .movie:  return "film.fill"
        case .album:  return "music.note.house.fill"
        case .blog:   return "doc.text.fill"
        case .video:  return "play.rectangle.fill"
        case .podcast:return "mic.fill"
        case .other:  return "questionmark.circle.fill"
        }
    }
}

enum MediaStatus: String, CaseIterable, Codable, Identifiable {
    case backlog
    case inProgress
    case completed
    case archived
    
    var id: String { rawValue }
    
    /// A user‑friendly name for each status.
    var displayName: String {
        switch self {
        case .backlog:     return "Backlog"
        case .inProgress:  return "In Progress"
        case .completed:   return "Completed"
        case .archived:    return "Archived"
        }
    }
    
    /// SF‑Symbol name that best represents the status.
    var symbolName: String {
        switch self {
        case .backlog:     return "tray.fill"
        case .inProgress:  return "hourglass.circle.fill"
        case .completed:   return "checkmark.seal.fill"
        case .archived:    return "archivebox.fill"
        }
    }
}

@Model
final class MediaItem {
    @Attribute(.unique) var uuid: UUID
    var title: String
    var creator: String
    var mediaKind: MediaKind
    var createdAt: Date
    var updatedAt: Date
    var releaseDate: Date?
    var platform: String
    var externalLink: URL?
    var rating: Int
    var status: MediaStatus
    var tags: [String]
    var note: String
    var isFavorite: Bool
    @Attribute(.externalStorage) var coverImageData: Data?

    init(
        uuid: UUID = UUID(),
        title: String,
        creator: String,
        mediaKind: MediaKind,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        releaseDate: Date? = nil,
        platform: String = "",
        externalLink: URL? = nil,
        rating: Int = 0,
        status: MediaStatus = .backlog,
        tags: [String] = [],
        note: String = "",
        isFavorite: Bool = false,
        coverImageData: Data? = nil
    ) {
        self.uuid = uuid
        self.title = title
        self.creator = creator
        self.mediaKind = mediaKind
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.releaseDate = releaseDate
        self.platform = platform
        self.externalLink = externalLink
        self.rating = rating
        self.status = status
        self.tags = tags
        self.note = note
        self.isFavorite = isFavorite
        self.coverImageData = coverImageData
    }
}

extension MediaItem {
    var year: Int? {
        guard let releaseDate else { return nil}
        return Calendar.current.component(.year, from: releaseDate)
    }
    
    var displayCreator: String {
        creator.isEmpty ? "Unknown" : creator
    }
    
    var displayPlatform: String {
        platform.isEmpty ? "-" : platform
    }
    
    var coverImage: NSImage? {
        guard let data = coverImageData else { return nil }
        return NSImage(data: data)
    }
    
    var accentGradient: LinearGradient {
        let baseColor: Color
        switch mediaKind {
        case .book: baseColor = .purple
        case .movie: baseColor = .pink
        case .album: baseColor = .blue
        case .blog: baseColor = .green
        case .video: baseColor = .red
        case .podcast: baseColor = .mint
        case .other: baseColor = .gray
        }
        return LinearGradient(
            gradient: Gradient(colors: [baseColor.opacity(0.9), baseColor.opacity(0.4)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func update(from draft: MediaDraft) {
        title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        creator = draft.creator.trimmingCharacters(in: .whitespacesAndNewlines)
        mediaKind = draft.mediaKind
        releaseDate = draft.hasReleaseDate ? draft.releaseDate : nil
        platform = draft.platform.trimmingCharacters(in: .whitespacesAndNewlines)
        externalLink = draft.externalLink
        rating = draft.rating
        status = draft.status
        tags = draft.tags
        note = draft.note
        isFavorite = draft.isFavorite
        coverImageData = draft.coverImageData
        updatedAt = .now
    }
}

struct MediaDraft: Identifiable {
    var id: UUID = UUID()
    var title: String
    var creator: String
    var mediaKind: MediaKind
    var hasReleaseDate: Bool
    var releaseDate: Date
    var platform: String
    var link: String
    var rating: Int
    var status: MediaStatus
    var tagInput: String
    var note: String
    var isFavorite: Bool
    var coverImageData: Data?
    
    init(title: String = "", creator: String = "", mediaKind: MediaKind = .book) {
        self.title = title
        self.creator = creator
        self.mediaKind = mediaKind
        self.hasReleaseDate = false
        self.releaseDate = .now
        self.platform = ""
        self.link = ""
        self.rating = 0
        self.status = .backlog
        self.tagInput = ""
        self.note = ""
        self.isFavorite = false
        self.coverImageData = nil
    }

    init(item: MediaItem) {
        title = item.title
        creator = item.creator
        mediaKind = item.mediaKind
        if let releaseDate = item.releaseDate {
            hasReleaseDate = true
            self.releaseDate = releaseDate
        } else {
            hasReleaseDate = false
            releaseDate = .now
        }
        platform = item.platform
        link = item.externalLink?.absoluteString ?? ""
        rating = item.rating
        status = item.status
        tagInput = item.tags.joined(separator: ", ")
        note = item.note
        isFavorite = item.isFavorite
        coverImageData = item.coverImageData
    }

    var externalLink: URL? {
        guard let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)), !link.isEmpty else {
            return nil
        }
        return url
    }

    var tags: [String] {
        tagInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
