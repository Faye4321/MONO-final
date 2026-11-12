import SwiftUI

// MARK: - Calendar Data

// One page of the collection calendar: a month, or the year's "Sometime"
// page for entries that are only dated to the year (or not dated at all).
// Entries are memories, plus "added" entries for objects without one.
struct CalendarPage: Identifiable {
    enum Kind: Hashable {
        case month(Int)
        case sometime
    }

    let year: Int
    let kind: Kind
    let moments: [Moment]
    var addedEntryIDs: Set<UUID> = []

    func isAddedEntry(_ moment: Moment) -> Bool {
        addedEntryIDs.contains(moment.id)
    }

    var id: String {
        switch kind {
        case .month(let month): "\(year)-\(month)"
        case .sometime: "\(year)-sometime"
        }
    }

    var month: Int? {
        if case .month(let month) = kind { return month }
        return nil
    }

    var title: String {
        guard let month else { return "Sometime" }
        return Calendar.current.standaloneMonthSymbols[month - 1]
    }

    var shortTitle: String {
        guard let month else { return "SOMETIME" }
        return Calendar.current.shortStandaloneMonthSymbols[month - 1].uppercased()
    }

    /// Days of the month with a memory dated to the exact day.
    var markedDays: Set<Int> {
        Set(moments.compactMap { moment in
            guard moment.datePrecision == .day, let date = moment.date else { return nil }
            return Calendar.current.component(.day, from: date)
        })
    }

    /// Muted card colours drawn from the app's paper, tan, olive and brick tones.
    var color: Color {
        let palette = [
            "E6DCCB", "D9CBB8", "CFD3C2", "E3D1C6", "C9D0BE", "D8C6A8",
            "C7CDD1", "E0CBB0", "BFC3AE", "D4B8A8", "C9C1B4", "B9BDB8"
        ]
        guard let month else { return Color(hex: "D5CEC2") }
        return Color(hex: palette[month - 1])
    }
}

enum MemoryCalendar {
    /// Twelve month pages for the year, plus a "Sometime" page when the year
    /// has memories without a day or month. Undated memories are shown on
    /// the current year's Sometime page.
    static func pages(for year: Int, source: CalendarSource) -> [CalendarPage] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: .now)
        let sorted = source.moments.sorted(by: CollectionStore.chronological)

        var byMonth: [Int: [Moment]] = [:]
        var sometime: [Moment] = []

        for moment in sorted {
            guard let date = moment.date else {
                if year == currentYear { sometime.append(moment) }
                continue
            }
            guard calendar.component(.year, from: date) == year else { continue }

            if moment.datePrecision == .year {
                sometime.append(moment)
            } else {
                byMonth[calendar.component(.month, from: date), default: []].append(moment)
            }
        }

        var pages = (1...12).map { month in
            CalendarPage(
                year: year,
                kind: .month(month),
                moments: byMonth[month] ?? [],
                addedEntryIDs: source.addedEntryIDs
            )
        }
        if !sometime.isEmpty {
            pages.append(
                CalendarPage(year: year, kind: .sometime, moments: sometime, addedEntryIDs: source.addedEntryIDs)
            )
        }
        return pages
    }

    /// Years that have dated entries, always including the current year.
    static func years(in source: CalendarSource) -> [Int] {
        let calendar = Calendar.current
        var years = Set(source.moments.compactMap { $0.date.map { calendar.component(.year, from: $0) } })
        years.insert(calendar.component(.year, from: .now))
        return years.sorted()
    }

    /// The page to open first: this month in the current year, otherwise the
    /// latest month that has memories.
    static func defaultIndex(in pages: [CalendarPage]) -> Int {
        let calendar = Calendar.current
        if pages.first?.year == calendar.component(.year, from: .now) {
            return calendar.component(.month, from: .now) - 1
        }
        return pages.lastIndex { !$0.moments.isEmpty && $0.month != nil } ?? 0
    }
}

// MARK: - Month Card

struct MonthCard: View {
    @EnvironmentObject private var store: CollectionStore

    let page: CalendarPage
    var expanded = false
    var highlightedDay: Int?
    var onTapDay: (Int) -> Void = { _ in }
    var onTapMoment: (Moment) -> Void = { _ in }
    /// VoiceOver swipe up/down on the month title changes month.
    var onAdjust: ((AccessibilityAdjustmentDirection) -> Void)?

    private var maxLines: Int { expanded ? 6 : 3 }
    private var maxGroups: Int { expanded ? 6 : 3 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(page.color)
                .shadow(color: .black.opacity(0.10), radius: 8, y: 4)

            // Content starts at the top and anything that doesn't fit is
            // clipped at the bottom. Letting it overflow made SwiftUI centre
            // the card and push it up over the section above.
            VStack(alignment: .leading, spacing: 14) {
                header

                if !page.moments.isEmpty {
                    notes
                    collage
                }
            }
            .padding(20)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .overlay(alignment: .bottom) {
            HStack {
                Text(page.shortTitle)
                Spacer()
                Text("MONARCHIVE")
            }
            .font(ArchiveTheme.label(8))
            .tracking(1.2)
            .foregroundStyle(ArchiveTheme.ink.opacity(0.55))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(page.title)
                    .font(.system(size: 40, weight: .regular, design: .serif))
                    .foregroundStyle(ArchiveTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(page.month == nil ? "IN \(String(page.year))" : String(page.year))
                    .font(ArchiveTheme.label(10))
                    .tracking(1)
                    .foregroundStyle(ArchiveTheme.ink.opacity(0.6))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityAddTraits(.isHeader)
            .accessibilityAdjustableAction { direction in
                onAdjust?(direction)
            }

            Spacer(minLength: 12)

            if let month = page.month {
                MiniMonthGrid(
                    year: page.year,
                    month: month,
                    markedDays: page.markedDays,
                    highlightedDay: highlightedDay,
                    onTapDay: onTapDay
                )
            }
        }
    }

    private var accessibilitySummary: String {
        let count = page.moments.count
        let entries = count == 1 ? "1 entry" : "\(count) entries"
        return "\(page.title) \(page.year), \(entries)"
    }

    // MARK: Notes

    private var notes: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(page.moments.prefix(maxLines)) { moment in
                Text("✱ \(line(for: moment))")
                    .font(ArchiveTheme.body(13))
                    .foregroundStyle(ArchiveTheme.ink)
                    .lineLimit(1)
                    .opacity(isDimmed(moment) ? 0.3 : 1)
            }
            if page.moments.count > maxLines {
                Text("+\(page.moments.count - maxLines) more")
                    .font(ArchiveTheme.label(9))
                    .foregroundStyle(ArchiveTheme.ink.opacity(0.55))
            }
        }
    }

    /// The memory's note, else the object's meaning, else a generated line.
    private func line(for moment: Moment) -> String {
        if page.isAddedEntry(moment), let item = moment.itemIDs.first.flatMap(store.item(id:)) {
            return "Added \(item.title) to \(item.category.shelfLabel.capitalized)"
        }

        if !moment.note.isEmpty {
            return moment.note.components(separatedBy: .newlines).first ?? moment.note
        }

        let objects = moment.itemIDs.compactMap(store.item(id:))
        if let meaning = objects.map(\.meaning).first(where: { !$0.isEmpty }) {
            return meaning
        }

        let title = objects.first?.title ?? "an object"
        let others = objects.count > 1 ? " +\(objects.count - 1)" : ""
        let place = moment.placeName.isEmpty ? "" : " at \(moment.placeName)"
        switch moment.kind {
        case .acquired: return "Got \(title)\(others)\(place)"
        case .milestone: return "\(title)\(others)\(place)"
        case .farewell: return "Parted with \(title)\(others)"
        }
    }

    // MARK: Collage

    private var collage: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
            spacing: 14
        ) {
            ForEach(page.moments.prefix(maxGroups)) { moment in
                Button {
                    onTapMoment(moment)
                } label: {
                    MomentCollage(moment: moment, label: dateLabel(for: moment))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(dateLabel(for: moment)), \(line(for: moment))")
                .accessibilityHint("Opens the objects from this memory")
                .opacity(isDimmed(moment) ? 0.3 : 1)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if page.moments.count > maxGroups {
                Text("+\(page.moments.count - maxGroups)")
                    .font(ArchiveTheme.label(10))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.8), in: Capsule())
                    .offset(x: 4, y: 4)
            }
        }
    }

    private func dateLabel(for moment: Moment) -> String {
        guard let date = moment.date else { return "UNDATED" }
        switch moment.datePrecision {
        case .day:
            let parts = Calendar.current.dateComponents([.month, .day], from: date)
            return String(format: "%02d·%02d", parts.month ?? 0, parts.day ?? 0)
        case .month: return date.formatted(.dateTime.month(.abbreviated)).uppercased()
        case .year: return date.formatted(.dateTime.year())
        }
    }

    private func isDimmed(_ moment: Moment) -> Bool {
        guard let highlightedDay else { return false }
        guard moment.datePrecision == .day, let date = moment.date else { return true }
        return Calendar.current.component(.day, from: date) != highlightedDay
    }
}

// MARK: - Mini Month Grid

struct MiniMonthGrid: View {
    let year: Int
    let month: Int
    let markedDays: Set<Int>
    var highlightedDay: Int?
    var onTapDay: (Int) -> Void = { _ in }

    private let cellSize = CGSize(width: 17, height: 15)

    private var layout: (leadingBlanks: Int, days: Int) {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month, day: 1)
        guard let first = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: first) else {
            return (0, 30)
        }
        let weekday = calendar.component(.weekday, from: first)
        let blanks = (weekday - calendar.firstWeekday + 7) % 7
        return (blanks, range.count)
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private var isCurrentMonth: Bool {
        let calendar = Calendar.current
        return calendar.component(.year, from: .now) == year
            && calendar.component(.month, from: .now) == month
    }

    var body: some View {
        let grid = layout
        let columns = Array(repeating: GridItem(.fixed(cellSize.width), spacing: 2), count: 7)

        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .frame(width: cellSize.width, height: cellSize.height)
                    .foregroundStyle(ArchiveTheme.ink.opacity(0.5))
                    .accessibilityHidden(true)
            }

            ForEach(0..<grid.leadingBlanks, id: \.self) { index in
                Color.clear
                    .frame(width: cellSize.width, height: cellSize.height)
                    .id("blank-\(index)")
            }

            ForEach(1...grid.days, id: \.self) { day in
                dayCell(day)
            }
        }
        .font(.system(size: 8, weight: .medium, design: .monospaced))
        .frame(width: cellSize.width * 7 + 12)
    }

    @ViewBuilder
    private func dayCell(_ day: Int) -> some View {
        let isMarked = markedDays.contains(day)
        let isToday = isCurrentMonth && Calendar.current.component(.day, from: .now) == day

        let label = Text("\(day)")
            .frame(width: cellSize.width, height: cellSize.height)
            .foregroundStyle(ArchiveTheme.ink)
            .overlay {
                if isMarked {
                    Circle()
                        .stroke(ArchiveTheme.collectedRed, lineWidth: highlightedDay == day ? 2 : 1.2)
                        .frame(width: 15, height: 15)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(ArchiveTheme.ink.opacity(0.4), lineWidth: 0.8)
                }
            }

        if isMarked {
            Button {
                onTapDay(day)
            } label: {
                label
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Day \(day), has memories")
            .accessibilityHint("Highlights that day's memories")
        } else {
            label
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Moment Collage

// One memory as a small taped stack of its photos (or its objects' photos).
struct MomentCollage: View {
    @EnvironmentObject private var store: CollectionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let moment: Moment
    let label: String

    private var objects: [CollectibleItem] {
        moment.itemIDs.compactMap(store.item(id:))
    }

    /// A stable small tilt per memory so the collage doesn't jitter between renders.
    private var tilt: Double {
        reduceMotion ? 0 : Double(Int(moment.id.uuid.0) % 7) - 3
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                let photos = Array(moment.photoFileNames.prefix(3))
                if photos.isEmpty {
                    ForEach(Array(objects.prefix(3).enumerated()), id: \.element.id) { index, item in
                        ArtworkView(item: item)
                            .frame(width: 62, height: 62)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .modifier(CollageOffset(index: index, tilt: tilt))
                    }
                } else {
                    ForEach(Array(photos.enumerated()), id: \.element) { index, name in
                        photo(named: name)
                            .modifier(CollageOffset(index: index, tilt: tilt))
                    }
                }
            }
            .frame(height: 84)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(ArchiveTheme.paperTan.opacity(0.75))
                    .frame(width: 38, height: 11)
                    .rotationEffect(.degrees(-tilt))
                    .offset(y: -4)
            }

            Text(label)
                .font(ArchiveTheme.label(8))
                .tracking(0.8)
                .foregroundStyle(ArchiveTheme.ink.opacity(0.65))
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func photo(named name: String) -> some View {
        if let image = ImageStore.thumbnail(named: name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(3)
                .background(.white, in: RoundedRectangle(cornerRadius: 5))
        }
    }
}

private struct CollageOffset: ViewModifier {
    let index: Int
    let tilt: Double

    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
            .rotationEffect(.degrees(tilt + Double(index) * 5 - 5))
            .offset(x: CGFloat(index) * 10 - 10, y: CGFloat(index) * 4)
            .zIndex(Double(-index))
    }
}

// MARK: - Calendar Stack

// Month cards stacked like a flip calendar: earlier months show their top
// edge above the open card, later months show their bottom edge below.
// Swipe sideways (or tap an edge) to change month; vertical drags are left
// to the surrounding scroll view.
struct CalendarStack: View {
    let pages: [CalendarPage]
    @Binding var focusedIndex: Int
    var cardHeight: CGFloat = 440
    var onOpen: () -> Void = {}
    var onTapMoment: (Moment) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragX: CGFloat = 0
    @State private var highlightedDay: Int?

    private let topStrip: CGFloat = 26
    private let bottomStrip: CGFloat = 12
    private let maxAbove = 3
    private let maxBelow = 5

    private var frontTop: CGFloat { CGFloat(maxAbove) * topStrip }

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                let distance = index - focusedIndex
                if distance >= -maxAbove && distance <= maxBelow {
                    card(page, at: index, distance: distance)
                }
            }
        }
        .frame(
            height: frontTop + cardHeight + CGFloat(maxBelow) * bottomStrip,
            alignment: .top
        )
        .simultaneousGesture(swipe)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: focusedIndex)
        .onChange(of: focusedIndex) {
            highlightedDay = nil
        }
    }

    @ViewBuilder
    private func card(_ page: CalendarPage, at index: Int, distance: Int) -> some View {
        if distance == 0 {
            MonthCard(
                page: page,
                highlightedDay: highlightedDay,
                onTapDay: { day in
                    highlightedDay = highlightedDay == day ? nil : day
                },
                onTapMoment: onTapMoment,
                onAdjust: { direction in
                    move(by: direction == .increment ? 1 : -1)
                }
            )
            .frame(height: cardHeight)
            .contentShape(Rectangle())
            .accessibilityAction(named: "Open full screen", onOpen)
            .onTapGesture(perform: onOpen)
            .offset(x: dragX, y: frontTop)
            .zIndex(100)
        } else {
            let steps = CGFloat(abs(distance))
            let isAbove = distance < 0

            MonthCard(page: page)
                .frame(height: cardHeight)
                .allowsHitTesting(false)
                .scaleEffect(1 - steps * (isAbove ? 0.03 : 0.035), anchor: isAbove ? .top : .bottom)
                .offset(y: isAbove
                    ? frontTop - steps * topStrip
                    : frontTop + steps * bottomStrip)
                .overlay {
                    // Tapping the visible edge brings that month to the front.
                    Color.clear
                        .contentShape(Rectangle())
                        .offset(y: isAbove
                            ? frontTop - steps * topStrip
                            : frontTop + steps * bottomStrip)
                        .onTapGesture {
                            Haptics.selection()
                            focusedIndex = index
                        }
                }
                .zIndex(50 - Double(abs(distance)))
                .accessibilityHidden(true)
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard !reduceMotion,
                      abs(value.translation.width) > abs(value.translation.height) else { return }
                dragX = value.translation.width * 0.6
            }
            .onEnded { value in
                let dx = value.translation.width
                if abs(dx) > abs(value.translation.height), abs(dx) > 60 {
                    move(by: dx < 0 ? 1 : -1)
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    dragX = 0
                }
            }
    }

    private func move(by step: Int) {
        let target = focusedIndex + step
        guard pages.indices.contains(target) else { return }
        Haptics.selection()
        focusedIndex = target
    }
}

// MARK: - Full-Screen Flip View

// The calendar opened full screen: one month per page, swiped left and right
// (matching the page dots), opening on the month it was asked for.
struct CalendarFlipView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let pages: [CalendarPage]
    @Binding var focusedIndex: Int

    @State private var currentIndex: Int
    @State private var highlightedDays: [CalendarPage.ID: Int] = [:]
    @State private var selectedMoment: Moment?

    /// `startIndex` is the month to open on. Pass it as a value: reading the
    /// binding while a full-screen cover builds its content returns a stale 0.
    init(pages: [CalendarPage], focusedIndex: Binding<Int>, startIndex: Int? = nil) {
        self.pages = pages
        _focusedIndex = focusedIndex
        let requested = startIndex ?? focusedIndex.wrappedValue
        let start = pages.indices.contains(requested) ? requested : 0
        _currentIndex = State(initialValue: start)
    }

    var body: some View {
        GeometryReader { proxy in
            let cardHeight = proxy.size.height * 0.8

            // A paged TabView swipes left/right and, unlike a lazy
            // ScrollView, reliably opens on the requested month.
            TabView(selection: $currentIndex) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    MonthCard(
                        page: page,
                        expanded: true,
                        highlightedDay: highlightedDays[page.id],
                        onTapDay: { day in
                            highlightedDays[page.id] = highlightedDays[page.id] == day ? nil : day
                        },
                        onTapMoment: { selectedMoment = $0 }
                    )
                    .frame(height: cardHeight)
                    .padding(.horizontal, 20)
                    .frame(maxHeight: .infinity)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(hex: "ECEADB").ignoresSafeArea())
        .overlay(alignment: .top) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ArchiveTheme.ink)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.7), in: Circle())
                }
                .accessibilityLabel("Close")

                Spacer()

                Text("\(currentIndex + 1) / \(pages.count)")
                    .font(ArchiveTheme.label(11))
                    .monospacedDigit()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.7), in: Capsule())
            }
            .padding(.horizontal, 20)
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 5) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? ArchiveTheme.collectedRed : ArchiveTheme.ink.opacity(0.2))
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.bottom, 6)
            .accessibilityHidden(true)
        }
        .onChange(of: currentIndex) {
            Haptics.selection()
            focusedIndex = currentIndex
        }
        .sheet(item: $selectedMoment) { moment in
            MomentObjectsSheet(moment: moment)
        }
    }
}

// MARK: - Objects in a Memory

// Opened from a collage: goes straight to the object, or lists them when
// the memory covers several.
struct MomentObjectsSheet: View {
    @EnvironmentObject private var store: CollectionStore
    @Environment(\.dismiss) private var dismiss

    let moment: Moment

    private var objects: [CollectibleItem] {
        moment.itemIDs.compactMap(store.item(id:))
    }

    var body: some View {
        NavigationStack {
            Group {
                if objects.count == 1, let item = objects.first {
                    ItemDetailView(item: item)
                } else {
                    List(objects) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            HStack(spacing: 12) {
                                ArtworkView(item: item)
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Text(item.title)
                                    .font(ArchiveTheme.heading(14))
                            }
                        }
                    }
                    .navigationTitle(moment.summary)
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
