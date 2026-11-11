import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject private var store: CollectionStore
    let item: CollectibleItem

    @State private var showingEdit = false
    @State private var showingNewMemory = false
    @State private var editingMoment: Moment?
    @State private var partingWith = false
    @State private var sharing = false
    @State private var journey: JourneyPresentation?
    @State private var journeyIndex = 0

    // Read the live copy so edits show immediately.
    private var current: CollectibleItem {
        store.item(id: item.id) ?? item
    }

    private var memories: [Moment] {
        store.moments(for: item.id)
    }

    var body: some View {
        ZStack {
            ArchiveTheme.ivory.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ArtworkView(item: current)
                        .aspectRatio(current.category == .poster || current.category == .photocard ? 0.72 : 1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.16), radius: 12, y: 7)

                    if let partedOn = current.partedOn {
                        Label(
                            "PAST COLLECTION · PARTED ON \(partedOn.formatted(date: .abbreviated, time: .omitted).uppercased())",
                            systemImage: "archivebox"
                        )
                        .font(ArchiveTheme.label(10))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ArchiveTheme.paperTan.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(current.category.shelfLabel)
                            .font(ArchiveTheme.label(10))
                            .tracking(1)
                            .foregroundStyle(ArchiveTheme.collectedRed)
                        Text(current.title)
                            .font(ArchiveTheme.display(34))
                        if !metadataLine.isEmpty {
                            Text(metadataLine)
                                .font(ArchiveTheme.heading(14))
                                .foregroundStyle(ArchiveTheme.catalogGray)
                        }
                    }

                    standardData

                    if !current.meaning.isEmpty || current.meaningTag != nil {
                        meaningBlock
                    }

                    if !current.note.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ARCHIVE NOTE")
                                .font(ArchiveTheme.label(10))
                                .tracking(1)
                            Text(current.note)
                                .font(ArchiveTheme.body(15))
                                .lineSpacing(5)
                        }
                    }

                    Divider()

                    memorySection

                    Button {
                        showingEdit = true
                    } label: {
                        HStack {
                            Text("EDIT OBJECT")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(ArchiveTheme.label(11))
                        .padding(16)
                        .foregroundStyle(.white)
                        .background(ArchiveTheme.ink, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: openJourney) {
                        HStack {
                            Text("SEE IN JOURNEY")
                            Spacer()
                            Image(systemName: "calendar")
                        }
                        .font(ArchiveTheme.label(11))
                        .padding(16)
                        .foregroundStyle(ArchiveTheme.ink)
                        .background(.white.opacity(0.8), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Group {
                        if current.partedOn == nil {
                            Button("PART WITH THIS OBJECT") { partingWith = true }
                        } else {
                            Button("RETURN TO COLLECTION") { store.restore(item.id) }
                        }
                    }
                    .font(ArchiveTheme.label(10))
                    .foregroundStyle(ArchiveTheme.catalogGray)
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
                // Scrollable clearance for the shared floating tab bar.
                .padding(.bottom, 160)
            }
        }
        .foregroundStyle(ArchiveTheme.ink)
        .environment(\.colorScheme, .light)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEdit) {
            ItemEditSheet(item: current)
        }
        .sheet(isPresented: $showingNewMemory) {
            MomentEditorView(
                moment: nil,
                initialItemIDs: [item.id],
                defaultKind: memories.isEmpty ? .acquired : .milestone
            )
        }
        .sheet(item: $editingMoment) { moment in
            MomentEditorView(moment: moment, initialItemIDs: moment.itemIDs)
        }
        .sheet(isPresented: $partingWith) {
            FarewellSheet(item: current)
        }
        .sheet(isPresented: $sharing) {
            ShareCardSheet(item: current, moments: memories)
        }
        // Carry the pages in the presentation itself; separate @State
        // set in the same tap can reach the cover still empty.
        .fullScreenCover(item: $journey) { journey in
            CalendarFlipView(pages: journey.pages, focusedIndex: $journeyIndex)
        }
    }

    // Opens the collection calendar on the month where this object sits:
    // its acquisition memory, otherwise the day it was added.
    private func openJourney() {
        let source = store.calendarSource
        let entry = source.moments
            .filter { $0.kind == .acquired && $0.itemIDs.contains(item.id) }
            .sorted(by: CollectionStore.chronological)
            .first

        let calendar = Calendar.current
        let year = entry?.date.map { calendar.component(.year, from: $0) }
            ?? calendar.component(.year, from: .now)
        let pages = MemoryCalendar.pages(for: year, source: source)

        journeyIndex = entry.flatMap { entry in
            pages.firstIndex { page in page.moments.contains { $0.id == entry.id } }
        } ?? MemoryCalendar.defaultIndex(in: pages)
        journey = JourneyPresentation(pages: pages)
    }

    // MARK: - Standard Data

    private var standardData: some View {
        HStack(spacing: 0) {
            dataCell("PRICE PAID", current.pricePaid.map { $0.formatted(.currency(code: "USD")) })
            dataDivider
            dataCell("CONDITION", current.condition?.title)
            dataDivider
            dataCell("RARITY", current.rarity?.title)
        }
        .padding(.vertical, 14)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
    }

    private func dataCell(_ label: String, _ value: String?) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(ArchiveTheme.label(8))
                .tracking(0.7)
                .foregroundStyle(ArchiveTheme.catalogGray)
            Text(value ?? "—")
                .font(ArchiveTheme.heading(14))
                .foregroundStyle(value == nil ? ArchiveTheme.catalogGray : ArchiveTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var dataDivider: some View {
        Rectangle()
            .fill(ArchiveTheme.catalogGray.opacity(0.15))
            .frame(width: 1, height: 30)
    }

    // MARK: - Meaning

    private var meaningBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHY IT MATTERS")
                .font(ArchiveTheme.label(10))
                .tracking(1)
                .foregroundStyle(ArchiveTheme.collectedRed)
            if let tag = current.meaningTag {
                Text(tag.title.uppercased())
                    .font(ArchiveTheme.label(9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(.white)
                    .background(ArchiveTheme.collectedRed, in: Capsule())
            }
            if !current.meaning.isEmpty {
                Text("“\(current.meaning)”")
                    .font(ArchiveTheme.display(20))
                    .foregroundStyle(ArchiveTheme.ink)
            }
        }
    }

    // MARK: - Memories

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("MY MEMORIES")
                    .font(ArchiveTheme.label(10))
                    .tracking(1)
                Spacer()
                Text("\(memories.count)")
                    .font(ArchiveTheme.label(10))
                    .foregroundStyle(ArchiveTheme.catalogGray)
            }

            if memories.isEmpty {
                Text("When did you get it, where, and with whom? Add what you remember — every field is optional.")
                    .font(ArchiveTheme.body(14))
                    .foregroundStyle(ArchiveTheme.catalogGray)
                    .lineSpacing(4)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(memories) { moment in
                        Button {
                            editingMoment = moment
                        } label: {
                            MomentCard(moment: moment, relatedTitles: relatedTitles(in: moment))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    showingNewMemory = true
                } label: {
                    Label("ADD A MEMORY", systemImage: "plus")
                        .font(ArchiveTheme.label(11))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(ArchiveTheme.ink)
                        .background(.white.opacity(0.8), in: Capsule())
                }
                .buttonStyle(.plain)

                if !memories.isEmpty {
                    Button {
                        sharing = true
                    } label: {
                        Label("SHARE", systemImage: "square.and.arrow.up")
                            .font(ArchiveTheme.label(11))
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                            .foregroundStyle(ArchiveTheme.ink)
                            .background(.white.opacity(0.8), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func relatedTitles(in moment: Moment) -> [String] {
        moment.itemIDs
            .filter { $0 != item.id }
            .compactMap { store.item(id: $0)?.title }
    }

    private var metadataLine: String {
        let creator = current.creator.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            creator.isEmpty ? nil : creator,
            current.year.map(String.init)
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

private struct JourneyPresentation: Identifiable {
    let id = UUID()
    let pages: [CalendarPage]
}

// MARK: - Edit Object

struct ItemEditSheet: View {
    @EnvironmentObject private var store: CollectionStore
    @Environment(\.dismiss) private var dismiss

    let item: CollectibleItem

    @State private var title: String
    @State private var creator: String
    @State private var includesYear: Bool
    @State private var year: Int
    @State private var category: CollectionCategory
    @State private var priceText: String
    @State private var condition: ItemCondition?
    @State private var rarity: Rarity?
    @State private var meaning: String
    @State private var meaningTag: MeaningTag?
    @State private var note: String
    @State private var hasAddedOn: Bool
    @State private var addedOn: Date
    @State private var confirmingDelete = false

    init(item: CollectibleItem) {
        self.item = item
        _title = State(initialValue: item.title)
        _creator = State(initialValue: item.creator)
        _includesYear = State(initialValue: item.year != nil)
        _year = State(initialValue: item.year ?? Calendar.current.component(.year, from: .now))
        _category = State(initialValue: item.category)
        _priceText = State(initialValue: PriceText.format(item.pricePaid))
        _condition = State(initialValue: item.condition)
        _rarity = State(initialValue: item.rarity)
        _meaning = State(initialValue: item.meaning)
        _meaningTag = State(initialValue: item.meaningTag)
        _note = State(initialValue: item.note)
        _hasAddedOn = State(initialValue: item.addedOn != nil)
        _addedOn = State(initialValue: item.addedOn ?? .now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    card {
                        MemoryTextField(label: "OBJECT TITLE", placeholder: "Untitled object", text: $title)
                        MemoryTextField(label: "CREATOR / ARTIST / BRAND", placeholder: "Creator", text: $creator)

                        Picker("Collection Type", selection: $category) {
                            ForEach(CollectionCategory.allCases) { category in
                                Text(category.title).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(ArchiveTheme.ink)

                        Toggle("ADD YEAR", isOn: $includesYear)
                            .font(ArchiveTheme.label(9))
                            .tint(ArchiveTheme.collectedRed)
                        if includesYear {
                            Stepper(value: $year, in: 1900...Calendar.current.component(.year, from: .now)) {
                                Text(String(year)).font(ArchiveTheme.body(15))
                            }
                        }

                        // Places the object on the collection calendar when it
                        // has no dated acquisition memory.
                        Toggle("ADDED TO COLLECTION", isOn: $hasAddedOn)
                            .font(ArchiveTheme.label(9))
                            .tint(ArchiveTheme.collectedRed)
                        if hasAddedOn {
                            DatePicker(
                                "Added on",
                                selection: $addedOn,
                                in: ...Date.now,
                                displayedComponents: .date
                            )
                            .font(ArchiveTheme.body(14))
                            .tint(ArchiveTheme.collectedRed)
                        }
                    }

                    card {
                        StandardDataFields(priceText: $priceText, condition: $condition, rarity: $rarity)
                    }

                    card {
                        MeaningFields(meaning: $meaning, tag: $meaningTag)
                        MemoryTextField(
                            label: "ARCHIVE NOTE",
                            placeholder: "Anything else about this object",
                            text: $note,
                            multiline: true
                        )
                    }

                    if item.isUserCreated {
                        Button("DELETE OBJECT", role: .destructive) {
                            confirmingDelete = true
                        }
                        .font(ArchiveTheme.label(11))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                    }
                }
                .padding(20)
            }
            .background(ArchiveTheme.ivory.ignoresSafeArea())
            .navigationTitle("Edit Object")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .confirmationDialog(
                "Delete this object and its memories?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    store.deleteItem(item)
                    dismiss()
                }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16, content: content)
            .padding(18)
            .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
    }

    private func save() {
        var updated = item
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.title = cleanedTitle.isEmpty ? "Untitled" : cleanedTitle
        updated.creator = creator.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.year = includesYear ? year : nil
        updated.category = category
        updated.pricePaid = PriceText.parse(priceText)
        updated.condition = condition
        updated.rarity = rarity
        updated.meaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.meaningTag = meaningTag
        updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.addedOn = hasAddedOn ? addedOn : nil
        store.updateItem(updated)
        dismiss()
    }
}

// MARK: - Farewell

// Records how an object left the collection and moves it to Past Collection.
struct FarewellSheet: View {
    @EnvironmentObject private var store: CollectionStore
    @Environment(\.dismiss) private var dismiss

    let item: CollectibleItem

    @State private var draft: MomentDraft

    init(item: CollectibleItem) {
        self.item = item
        var draft = MomentDraft(itemIDs: [item.id])
        draft.kind = .farewell
        draft.includesDate = true
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sold, traded or given away? \(item.title) moves to Past Collection. Its memories stay with you.")
                        .font(ArchiveTheme.body(14))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                        .lineSpacing(3)

                    VStack(alignment: .leading, spacing: 16) {
                        MomentFields(draft: $draft)
                    }
                    .padding(18)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
                }
                .padding(20)
            }
            .background(ArchiveTheme.ivory.ignoresSafeArea())
            .navigationTitle("Part With Object")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.partWith(item.id, farewell: draft.makeMoment())
                        dismiss()
                    }
                }
            }
        }
    }
}
