import SwiftUI

// Creates or edits a memory (Moment) for one or more objects.
struct MomentEditorView: View {
    @EnvironmentObject private var store: CollectionStore
    @Environment(\.dismiss) private var dismiss

    private let existing: Moment?

    @State private var draft: MomentDraft
    @State private var confirmingDelete = false
    @State private var choosingObjects = false

    init(
        moment: Moment?,
        initialItemIDs: [UUID],
        defaultKind: Moment.Kind = .acquired
    ) {
        existing = moment
        if let moment {
            _draft = State(initialValue: MomentDraft(moment: moment))
        } else {
            var draft = MomentDraft(itemIDs: initialItemIDs)
            draft.kind = defaultKind
            _draft = State(initialValue: draft)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Kind", selection: $draft.kind) {
                            ForEach(Moment.Kind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)

                        MomentFields(draft: $draft)
                    }
                    .padding(18)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))

                    objectsSection

                    if existing != nil {
                        Button("DELETE MEMORY", role: .destructive) {
                            confirmingDelete = true
                        }
                        .font(ArchiveTheme.label(11))
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .background(ArchiveTheme.ivory.ignoresSafeArea())
            .navigationTitle(existing == nil ? "New Memory" : "Edit Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(draft.isEmpty || draft.itemIDs.isEmpty)
                }
            }
            .sheet(isPresented: $choosingObjects) {
                ObjectPickerView(selection: $draft.itemIDs)
            }
            .confirmationDialog(
                "Delete this memory? Its photos will be removed.",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let existing {
                        store.deleteMoment(existing)
                    }
                    dismiss()
                }
            }
        }
    }

    private var selectedItems: [CollectibleItem] {
        draft.itemIDs.compactMap(store.item(id:))
    }

    // One memory can cover many objects, e.g. every card from one fansign.
    private var objectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MemoryFieldLabel("OBJECTS IN THIS MEMORY · \(selectedItems.count)")
                Spacer()
                Button("CHOOSE") { choosingObjects = true }
                    .font(ArchiveTheme.label(10))
                    .tint(ArchiveTheme.collectedRed)
            }

            if selectedItems.isEmpty {
                Text("Choose at least one object.")
                    .font(ArchiveTheme.body(13))
                    .foregroundStyle(ArchiveTheme.catalogGray)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(selectedItems) { item in
                            VStack(spacing: 6) {
                                ArtworkView(item: item)
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                Text(item.title)
                                    .font(ArchiveTheme.label(8))
                                    .lineLimit(1)
                                    .frame(width: 64)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(18)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
    }

    private func save() {
        if let existing {
            store.updateMoment(draft.makeMoment(id: existing.id))
        } else {
            store.addMoment(draft.makeMoment())
        }
        dismiss()
    }
}

// MARK: - Object Picker

struct ObjectPickerView: View {
    @EnvironmentObject private var store: CollectionStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: [UUID]

    @State private var query = ""

    private var results: [CollectibleItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return store.items }
        return store.items.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.creator.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(CollectionCategory.allCases) { category in
                    let items = results.filter { $0.category == category }
                    if !items.isEmpty {
                        Section(category.title) {
                            ForEach(items) { item in
                                row(for: item)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search objects")
            .navigationTitle("\(selection.count) Selected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(for item: CollectibleItem) -> some View {
        let isSelected = selection.contains(item.id)
        return Button {
            if isSelected {
                selection.removeAll { $0 == item.id }
            } else {
                selection.append(item.id)
            }
        } label: {
            HStack(spacing: 12) {
                ArtworkView(item: item)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(ArchiveTheme.heading(14))
                        .foregroundStyle(ArchiveTheme.ink)
                    if !item.creator.isEmpty {
                        Text(item.creator)
                            .font(ArchiveTheme.body(12))
                            .foregroundStyle(ArchiveTheme.catalogGray)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? ArchiveTheme.collectedRed : ArchiveTheme.catalogGray)
            }
        }
        .buttonStyle(.plain)
    }
}
