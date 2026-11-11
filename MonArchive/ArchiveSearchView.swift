import SwiftUI

// Searches objects by their standard data and by the memories attached to them.
struct ArchiveSearchView: View {
    @EnvironmentObject private var store: CollectionStore

    @State private var query: String
    @State private var category: CollectionCategory?
    @State private var condition: ItemCondition?
    @State private var rarity: Rarity?
    @State private var onlyWithMemories = false

    init(initialQuery: String = "") {
        _query = State(initialValue: initialQuery)
    }

    private var results: [CollectibleItem] {
        let terms = query
            .lowercased()
            .split(separator: " ")
            .map(String.init)

        return store.items.filter { item in
            if let category, item.category != category { return false }
            if let condition, item.condition != condition { return false }
            if let rarity, item.rarity != rarity { return false }

            let memories = store.moments(for: item.id)
            if onlyWithMemories, memories.isEmpty { return false }
            guard !terms.isEmpty else { return true }

            let haystack = searchableText(for: item, memories: memories)
            return terms.allSatisfy { haystack.contains($0) }
        }
    }

    var body: some View {
        List {
            Section {
                filters
            }

            Section("\(results.count) \(results.count == 1 ? "OBJECT" : "OBJECTS")") {
                ForEach(results) { item in
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        row(for: item)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ArchiveTheme.ivory.ignoresSafeArea())
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Title, artist, place, person, note…"
        )
        .navigationTitle("Search Archive")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    chip("ALL", isSelected: category == nil) { category = nil }
                    ForEach(CollectionCategory.allCases) { option in
                        chip(option.title.uppercased(), isSelected: category == option) {
                            category = category == option ? nil : option
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 12) {
                OptionalOptionPicker(label: "CONDITION", selection: $condition)
                OptionalOptionPicker(label: "RARITY", selection: $rarity)
            }

            Toggle("ONLY OBJECTS WITH MEMORIES", isOn: $onlyWithMemories)
                .font(ArchiveTheme.label(9))
                .tint(ArchiveTheme.collectedRed)
        }
        .padding(.vertical, 4)
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ArchiveTheme.label(9))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : ArchiveTheme.ink)
                .background(isSelected ? ArchiveTheme.ink : ArchiveTheme.ivory, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func row(for item: CollectibleItem) -> some View {
        HStack(spacing: 12) {
            ArtworkView(item: item)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(ArchiveTheme.heading(14))
                    .foregroundStyle(ArchiveTheme.ink)
                Text(detailLine(for: item))
                    .font(ArchiveTheme.body(12))
                    .foregroundStyle(ArchiveTheme.catalogGray)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            MemoryBadge(itemID: item.id)
        }
    }

    private func detailLine(for item: CollectibleItem) -> String {
        let memory = store.moments(for: item.id).first?.summary
        return [item.creator.isEmpty ? nil : item.creator, memory]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func searchableText(for item: CollectibleItem, memories: [Moment]) -> String {
        var parts = [item.title, item.creator, item.note, item.meaning, item.category.title]
        if let year = item.year { parts.append(String(year)) }
        if let tag = item.meaningTag { parts.append(tag.title) }
        for memory in memories {
            parts.append(memory.placeName)
            parts.append(memory.note)
            parts.append(memory.formattedDate)
            parts.append(contentsOf: memory.companions)
        }
        return parts.joined(separator: " ").lowercased()
    }
}
