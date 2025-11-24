//
//  MediaEditorView.swift
//  dilib
//
//  Created by 李凡 on 2025/11/03.
//

import AppKit
import PhotosUI
import SwiftUI
import SwiftData

struct MediaEditorView: View {
    enum Mode {
        case create
        case edit(MediaItem)
        
        var title: String {
            switch self {
            case .create: return "New Media"
            case .edit: return "Edit Media"
            }
        }
    }
    
    var mode: Mode
    var onSubmit: (MediaDraft) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MediaDraft
    @State private var photoItem: PhotosPickerItem?
    
    init(mode: Mode, onSubmit: @escaping (MediaDraft) -> Void) {
        self.mode = mode
        self.onSubmit = onSubmit
        switch mode {
        case .create:
            _draft = State(initialValue: MediaDraft())
        case .edit(let item):
            _draft = State(initialValue: MediaDraft(item: item))
        }
    }
    
    var body: some View {
        Form {
            Section("Basics") {
                TextField("Title", text: $draft.title)
                TextField("Creator", text: $draft.creator)
                Picker("Type", selection: $draft.mediaKind) {
                    ForEach(MediaKind.allCases) { kind in
                        Label(kind.displayName, systemImage: kind.iconName)
                            .tag(kind)
                    }
                }
            }
            
            Section("Metadata") {
                Toggle("Release Date", isOn: $draft.hasReleaseDate)
                if draft.hasReleaseDate {
                    DatePicker(" ", selection: $draft.releaseDate, displayedComponents: [.date])
                        .labelsHidden()
                }
                TextField("Platform", text: $draft.platform)
                TextField("Link", text: $draft.link)
                    .textContentType(.URL)
            }
            
            Section("Status & Tage") {
                Picker("Status", selection: $draft.status) {
                    ForEach(MediaStatus.allCases) { status in
                        Label(status.displayName, systemImage: status.symbolName)
                            .tag(status)
                    }
                }
                Stepper(value: $draft.rating, in: 0...5) {
                    HStack {
                        Text("Rating")
                        Text("\(draft.rating)")
                            .monospacedDigit()
                    }
                }
                Toggle("Favorite", isOn: $draft.isFavorite)
                TextField("Tags", text: $draft.tagInput, axis: .vertical)
            }
            
            Section("Notes") {
                TextEditor(text: $draft.note)
                    .frame(minHeight: 160)
            }
            
            Section("Artwork") {
                HStack(alignment: .center, spacing: 16) {
                    Group {
                        if let data = draft.coverImageData, let image = NSImage(data: data) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 4, y: 3)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose Image", systemImage: "photo.on.rectangle")
                    }
                    Button("Clear Image", role: .destructive) {
                        draft.coverImageData = nil
                    }
                    .disabled(draft.coverImageData == nil)
                }
                Spacer()
            }
        }
        .frame(minWidth:500)
        .navigationTitle(mode.title)
        .padding(10)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    submit()
                }
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onChange(of: photoItem) { oldValue, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        draft.coverImageData = data
                    }
                }
            }
        }
    }
    
    private func submit() {
        draft.rating = min(max(draft.rating, 0), 5)
        onSubmit(draft)
        dismiss()
    }
    
}

#Preview("Create") {
    NavigationStack {
        MediaEditorView(mode: .create) { _ in }
    }
    .modelContainer(for: MediaItem.self, inMemory: true)
}

#Preview("Edit") {
    NavigationStack {
        let sample = MediaItem(
            title: "arra",
            creator: "evan",
            mediaKind: .movie,
            releaseDate: Date(timeIntervalSinceReferenceDate: 12_345_678),
            platform: "blue-ray",
            externalLink: URL(string: "https://google.com"),
            rating: 5,
            status: .inProgress,
            tags: ["Sci-Fi", "drama"],
            note: "nice movie",
            isFavorite: true
        )
        MediaEditorView(mode: .edit(sample)) { _ in }
    }
    .modelContainer(for: MediaItem.self, inMemory: true)
}
