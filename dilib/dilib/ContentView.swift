//
//  ContentView.swift
//  dilib
//
//  Created by 李凡 on 2025/11/02.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MediaItem.updatedAt, order: .reverse) private var items: [MediaItem]
    
    @State private var selection: SidebarFilter = .all
    @State private var selectedItem: MediaItem?
    @State private var editorMode: MediaEditorView.Mode?
    @State private var showingReport = false
    
    private var filteredItems: [MediaItem] {
        switch selection {
        case .all:
            return items
        case .favorites:
            return items.filter { $0.isFavorite }
        case .kind(let kind):
            return items.filter { $0.mediaKind == kind }
        case .year(let year):
            return items.filter { $0.year == year }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(items: items, selection: $selection)
                .navigationTitle("dilib")
        } content: {
            MediaGridView(items: filteredItems, selectedItem: $selectedItem, onEdit: presentEditor, onDelete: deleteItem)
        } detail: {
            if  let item = selectedItem {
                MediaDetailView(item: item, onEdit: { presentEditor($0) }, onDelete: { deleteItem($0) })
                    .id(item.uuid)
            } else {
                ContentPlaceholderView()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { editorMode = .create } label: {
                    Label("Add Item", systemImage: "plus")
                }
                .help("Create a new media entry")
                
                if !items.isEmpty {
                    Button { showingReport = true } label: {
                        Label("Yearly Report", systemImage: "chart.bar.doc.horizontal")
                    }
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            NavigationStack {
                MediaEditorView(mode: mode) { draft in
                    handleDraft(draft: draft, mode: mode)
                }
            }
            .frame(minWidth: 520, minHeight: 680)
        }
        .sheet(isPresented: $showingReport) {
            YearlyReportSheet(items: items)
        }
        .onChange(of: selection) { _, _ in
            if let selectedItem, !filteredItems.contains(where: { $0.persistentModelID == selectedItem.persistentModelID }) {
                self.selectedItem = filteredItems.first
            }
        }
    }
    
    private func presentEditor(_ item: MediaItem?) {
        if let item {
            editorMode = .edit(item)
        } else {
            editorMode = .create
        }
    }
    
    private func deleteItem(_ item: MediaItem) {
        let removedCurrent = selectedItem?.persistentModelID == item.persistentModelID
        withAnimation(.easeInOut(duration: 0.25)) {
            modelContext.delete(item)
        }
        if removedCurrent {
            DispatchQueue.main.async {
                self.selectedItem = self.filteredItems.first
            }
        }
    }

    private struct ContentPlaceholderView: View {
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 48))
                    .symbolRenderingMode(.hierarchical)
                Text("Select an item to view details")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(colors: [.gray.opacity(0.1), .clear], startPoint: .top, endPoint: .bottom)
            )
        }
    }

    private func handleDraft(draft: MediaDraft, mode: MediaEditorView.Mode) {
        switch mode {
        case .create:
            let newItem = MediaItem(
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                creator: draft.creator.trimmingCharacters(in: .whitespacesAndNewlines),
                mediaKind: draft.mediaKind,
                createdAt: .now,
                updatedAt: .now,
                releaseDate: draft.hasReleaseDate ? draft.releaseDate : nil,
                platform: draft.platform.trimmingCharacters(in: .whitespacesAndNewlines),
                externalLink: draft.externalLink,
                rating: draft.rating,
                status: draft.status,
                tags: draft.tags,
                note: draft.note,
                isFavorite: draft.isFavorite,
                coverImageData: draft.coverImageData
            )
            modelContext.insert(newItem)
            selectedItem = newItem
        case .edit(let existingItem):
            existingItem.update(from: draft)
            selectedItem = existingItem
        }
        editorMode = nil
    }
    
}

enum SidebarFilter: Hashable {
    case all
    case favorites
    case kind(MediaKind)
    case year(Int)
}

private struct SidebarView: View {
    let items: [MediaItem]
    @Binding var selection: SidebarFilter
    
    private var years: [Int] {
        Set(items.compactMap(\.year)).sorted(by: >)
    }

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                Label("All Media", systemImage: "square.grid.2x2.fill")
                    .tag(SidebarFilter.all)
                Label("Favorites", systemImage: "star.fill")
                    .tag(SidebarFilter.favorites)
            }

            Section("Formats") {
                ForEach(MediaKind.allCases) { kind in
                    Label(kind.displayName, systemImage: kind.iconName)
                        .tag(SidebarFilter.kind(kind))
                }
            }

            if !years.isEmpty {
                Section("Years") {
                    ForEach(years, id: \.self) { year in
                        Label(String(year), systemImage: "calendar")
                            .tag(SidebarFilter.year(year))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            if items.isEmpty {
                selection = .all
            }
        }
    }
}

extension MediaEditorView.Mode: Identifiable {
    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let item): return "edit-\(item.uuid.uuidString)"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MediaItem.self, inMemory: true)
}
