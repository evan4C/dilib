//
//  YearlyReportSheet.swift
//  dilib
//
//  Created by 李凡 on 2025/11/04.
//
import AppKit
import PDFKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct YearlyReportSheet: View {
    let items: [MediaItem]
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedYear: Int
    @State private var exporting = false
    @State private var exportMessage: String?
    
    private var availableYears: [Int] {
        let calendar = Calendar.current
        let years = Set(items.compactMap { item in
           item.year ?? calendar.component(.year, from: item.createdAt)
        })
        let sorted = years.sorted(by: >)
        if sorted.isEmpty {
            return [selectedYear]
        }
        return sorted
    }

    private var filteredItems: [MediaItem] {
        items.filter { item in 
            let calendar = Calendar.current
            if let year = item.year {
                return year == selectedYear
            }
            return calendar.component(.year, from: item.createdAt) == selectedYear
        }
    }

    init(items: [MediaItem]) {
        self.items = items
        let calendar = Calendar.current
        let fallbackYear = calendar.component(.year, from: .now)
        let years = Set(items.compactMap { $0.year ?? calendar.component(.year, from: $0.createdAt) })
        _selectedYear = State(initialValue: years.sorted(by: >).first ?? fallbackYear)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Picker("Year", selection: $selectedYear) {
                    ForEach(availableYears, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.segmented)
                
                ScrollView {
                    YearlyReportCard(items: filteredItems, year: selectedYear)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                }
                
                if let exportMessage {
                    Text(exportMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                Spacer(minLength: 0)
                
            }
            .padding()
            .navigationTitle("Yearly Highlights")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        _ = Task { await exportReport() }
                    } label: {
                        if exporting {
                            ProgressView()
                        } else {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(filteredItems.isEmpty || exporting)
                }
            }
        }
        .frame(minWidth: 640, minHeight: 720)
    }
    
    @MainActor
    private func exportReport() async {
        guard !filteredItems.isEmpty else { return }
        exporting = true
        defer { exporting = false }

        let report = YearlyReportCard(items: filteredItems, year: selectedYear)
            .frame(width: 900, height: 1200)
            .padding(40)
            .background(Color.white)

        let renderer = ImageRenderer(content: report)
        renderer.scale = 2

        guard let nsImage = renderer.nsImage else {
            exportMessage = "Failed to generate report image."
            return
        }

        let pdfDocument = PDFDocument()
        guard let pdfPage = PDFPage(image: nsImage) else {
            exportMessage = "Failed to create PDF page."
            return
        }
        pdfDocument.insert(pdfPage, at: 0)

        guard let data = pdfDocument.dataRepresentation() else {
            exportMessage = "Failed to create PDF data."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.nameFieldStringValue = "Yearly_Report_\(selectedYear).pdf"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                exportMessage = "Report exported successfully to \(url.lastPathComponent)."
            } catch {
                exportMessage = "Failed to save PDF: \(error.localizedDescription)"
            }
        } else {
            exportMessage = "Export cancelled."
        }
        
    }

}

private struct YearlyReportCard: View {
    let items: [MediaItem]
    let year: Int
    
    private var favoriteCount: Int {
        items.filter { $0.isFavorite }.count
    }
    
    // extract the 3 highest rating items
    private var topRated: [MediaItem] {
        items
            .filter { $0.rating > 0 }
            .sorted{ lhs, rhs in
                if lhs.rating == rhs.rating {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.rating > rhs.rating
            }
            .prefix(3)
            .map { $0 }
    }
    
    private var totalHours: Int {
        // Placeholder estimate: 2h per item
        items.count * 2
    }
    
    // count the media kind
    private var kindBreakDown: [(MediaKind, Int)] {
        MediaKind.allCases
            .map { kind in (kind, items.filter { $0.mediaKind == kind }.count) }
            .filter { $0.1 > 0}
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(year)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                Text("Year in Review - Digital Library")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(alignment: .center, spacing: 12) {
                StatBlock(title: "Total Items", value: "\(items.count)")
                StatBlock(title: "Favorite Items", value: "\(favoriteCount)")
                StatBlock(title: "Total Hours", value: "\(totalHours)h")
            }

            if !kindBreakDown.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Breakdown")
                        .font(.title3.weight(.semibold))
                    ForEach(kindBreakDown, id: \.0) { kind, count in
                        HStack {
                            Label(kind.displayName, systemImage: kind.iconName)
                            Spacer()
                            Text("\(count)")
                            .font(.title3.weight(.semibold))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }

            if !topRated.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Top Rated")
                        .font(.title2.weight(.bold))
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(topRated) { item in
                            VStack(alignment: .leading, spacing: 12) {
                                ReportCoverView(item: item)
                                    .frame(width: 180, height: 220)
                                Text(item.title)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text(item.displayCreator)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 4) {
                                    ForEach(0..<item.rating, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(.yellow)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(32)
        .background(
            LinearGradient(colors: [Color.cyan.opacity(0.2), Color.indigo.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
    }
}

private struct StatBlock: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)    
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct ReportCoverView: View {
    let item: MediaItem
    
    var body: some View {
        ZStack {
            if let cover = item.coverImage {
                Image(nsImage: cover)
                    .resizable()
                    .scaledToFill()
            } else {
                item.accentGradient
                Image(systemName: item.mediaKind.iconName)
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(radius: 12, y: 6)
    }
}

#Preview("Report - rich") {
    let items: [MediaItem] = [
        MediaItem(title: "Sample 1", creator: "Author A", mediaKind: .book, releaseDate: Date(timeIntervalSince1970: 1609459200), rating: 5, isFavorite: true),
        MediaItem(title: "Sample 2", creator: "Author B", mediaKind: .movie, releaseDate: Date(timeIntervalSince1970: 1612137600), rating: 2, note: "A great movie to watch on weekends."),
        MediaItem(title: "Sample 3", creator: "Author C", mediaKind: .album, isFavorite: false),
        MediaItem(title: "Sample 4", creator: "Author D", mediaKind: .podcast, releaseDate: Calendar.current.date(from: DateComponents(year: 2008)), rating: 4, status: .completed, isFavorite: true),
        MediaItem(title: "Sample 5", creator: "Author F", mediaKind: .other, releaseDate: .now, rating: 4, status: .completed, isFavorite: true)
    ]
    YearlyReportSheet(items: items)
        .modelContainer(for: MediaItem.self, inMemory: true)
}
