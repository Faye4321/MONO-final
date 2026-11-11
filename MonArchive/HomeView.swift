import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: CollectionStore
    let onProfileTapped: () -> Void
    let onOpenLab: () -> Void

    @AppStorage(CollectingPreferences.storageKey) private var collectsRaw = ""

    init(
        onProfileTapped: @escaping () -> Void = {},
        onOpenLab: @escaping () -> Void = {}
    ) {
        self.onProfileTapped = onProfileTapped
        self.onOpenLab = onOpenLab
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = HomeMetrics(width: proxy.size.width)

            ScrollView(.vertical) {
                LazyVStack(spacing: metrics.sectionSpacing) {
                    HeaderView {
                        Haptics.light()
                        onProfileTapped()
                    }

                    PickedForYouCarousel(
                        picks: ShopPicks.featured(
                            prioritizing: CollectingPreferences.categories(from: collectsRaw)
                        ),
                        height: metrics.heroHeight
                    )

                    HomeJourneySection()

                    // Collage Studio is the Lab tab.
                    CollageStudioCard(height: metrics.studioHeight) {
                        Haptics.light()
                        onOpenLab()
                    }
                }
                .frame(maxWidth: metrics.maxContentWidth)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 26)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(BrandColor.archiveIvory)
        }
    }
}

// MARK: - Responsive Layout

private struct HomeMetrics {
    let width: CGFloat

    var horizontalPadding: CGFloat {
        width < 375 ? 14 : 18
    }

    var sectionSpacing: CGFloat {
        width < 375 ? 24 : 30
    }

    var heroHeight: CGFloat {
        width < 375 ? 410 : 438
    }

    var studioHeight: CGFloat {
        width < 375 ? 320 : 344
    }

    var maxContentWidth: CGFloat {
        460
    }
}

// MARK: - Header

private struct HeaderView: View {
    let profileAction: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("EXPLORE")
                    .monoHeading(20, tracking: 0.6)
                    .foregroundStyle(BrandColor.inkBlack)

                Text("SUNDAY, OCTOBER 4")
                    .monoLabel(10, tracking: 0.7)
                    .foregroundStyle(BrandColor.catalogGray)
            }

            Spacer()

            Button(action: profileAction) {
                ZStack {
                    Circle()
                        .fill(BrandColor.collectedRed)

                    Image(systemName: "person.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(BrandColor.archiveIvory)
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open profile")
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
}

// MARK: - Picked for You

private struct PickedForYouCarousel: View {
    let picks: [ShopPick]
    let height: CGFloat

    @EnvironmentObject private var store: CollectionStore
    @Environment(\.openURL) private var openURL
    @State private var currentID: ShopPick.ID?

    private var currentIndex: Int {
        picks.firstIndex { $0.id == currentID } ?? 0
    }

    // How much of the next card shows at the trailing edge.
    private let peek: CGFloat = 22
    private let spacing: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            carousel(cardWidth: proxy.size.width - peek - spacing)
        }
        .frame(height: height)
    }

    private func carousel(cardWidth: CGFloat) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: spacing) {
                ForEach(picks) { pick in
                    Button {
                        Haptics.light()
                        // Ask "did you get it?" when the user comes back.
                        store.pendingPurchase = pick
                        openURL(pick.itemWebURL)
                    } label: {
                        PickedForYouCard(
                            pick: pick,
                            position: currentIndex + 1,
                            total: picks.count,
                            height: height
                        )
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityHint("Opens this listing on eBay")
                    .frame(width: cardWidth)
                }
            }
            .scrollTargetLayout()
        }
        // Cards are narrower than the row, so the next one peeks in at the
        // trailing edge; that is the cue that the row can be swiped.
        .contentMargins(.trailing, peek + spacing, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $currentID)
        .scrollIndicators(.hidden)
        .onChange(of: currentID) {
            Haptics.selection()
        }
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? 1 : -1
            let target = min(max(currentIndex + step, 0), picks.count - 1)
            withAnimation {
                currentID = picks[target].id
            }
        }
    }
}

private struct PickedForYouCard: View {
    let pick: ShopPick
    let position: Int
    let total: Int
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .topLeading) {
                RoundedRectangle(
                    cornerRadius: 27,
                    style: .continuous
                )
                .fill(BrandColor.heroStone)

                PickArtwork(pick: pick)
                    .frame(width: 150, height: 214)
                    .position(x: width - 96, y: height - 165)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("PICKED FOR YOU")

                        Spacer()

                        Text(
                            String(
                                format: "%02d / %02d",
                                position,
                                total
                            )
                        )
                    }
                    .monoLabel(10, tracking: 0.5)
                    .foregroundStyle(BrandColor.catalogGray)

                    Text(pick.title)
                        .font(
                            .system(
                                size: 38,
                                weight: .regular,
                                design: .serif
                            )
                        )
                        .foregroundStyle(BrandColor.inkBlack)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .padding(.top, 17)

                    Text(pick.priceText)
                        .monoBody(15)
                        .foregroundStyle(BrandColor.catalogGray)
                        .padding(.top, 5)

                    Text(pick.subtitle)
                        .monoLabel(10, tracking: 0.55)
                        .foregroundStyle(BrandColor.catalogGray)
                        .lineLimit(2)
                        .frame(
                            maxWidth: width - 192,
                            alignment: .leading
                        )
                        .padding(.top, 10)

                    Spacer()

                    HStack(spacing: 8) {
                        Text("SHOP ON EBAY")

                        Image(systemName: "arrow.up.right")
                    }
                    .monoLabel(11, tracking: 0.4)
                    .foregroundStyle(BrandColor.inkBlack)
                    .padding(.bottom, 5)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(BrandColor.inkBlack)
                            .frame(height: 1)
                    }
                }
                .padding(21)

                EditorNote(text: pick.note)
                    .frame(width: 150, height: 108)
                    .rotationEffect(.degrees(-3))
                    .position(x: 99, y: height - 142)
                    .accessibilityElement(children: .combine)
            }
        }
        .frame(height: height)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 27,
                style: .continuous
            )
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: 27,
                style: .continuous
            )
        )
    }
}

// MARK: - Pick Artwork

private struct PickArtwork: View {
    let pick: ShopPick

    var body: some View {
        Group {
            if let imageName = pick.imageName,
               let image = UIImage(named: imageName) {
                framed(Image(uiImage: image))
            } else if let imageURL = pick.imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        framed(image)
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .shadow(
            color: .black.opacity(0.12),
            radius: 10,
            y: 6
        )
    }

    // eBay photos vary in shape and background; a white mat keeps the
    // carousel consistent without cropping the listing photo.
    private func framed(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Color.white,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
    }

    private var placeholder: some View {
        RoundedRectangle(
            cornerRadius: 6,
            style: .continuous
        )
        .fill(BrandColor.softCard)
        .aspectRatio(
            pick.category.artworkAspectRatio,
            contentMode: .fit
        )
        .overlay {
            Image(systemName: pick.category.systemImage)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(BrandColor.catalogGray)
        }
    }
}

// MARK: - Editor Note

private struct EditorNote: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EDITOR’S NOTE")
                .monoLabel(9, tracking: 0.3)
                .foregroundStyle(BrandColor.collectedRed)

            Text(text)
                .monoBody(11)
                .foregroundStyle(BrandColor.inkBlack)
                .lineSpacing(2)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .padding(14)
        .background(
            Color(hex: 0xF8F4EC),
            in: RoundedRectangle(
                cornerRadius: 4,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.06),
            radius: 7,
            y: 4
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(BrandColor.paperTan.opacity(0.72))
                .frame(width: 54, height: 14)
                .offset(y: -7)
        }
    }
}

// MARK: - Collection Journey

// The collection calendar on Explore. Read-only: memories are added when
// creating an object or from an object's page. The ME page keeps its own copy.
private struct HomeJourneySection: View {
    @EnvironmentObject private var store: CollectionStore

    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var focusedIndex = 0
    @State private var hasPositioned = false
    @State private var showingFlip = false
    @State private var selectedMoment: Moment?

    private var years: [Int] {
        MemoryCalendar.years(in: store.calendarSource)
    }

    private var pages: [CalendarPage] {
        MemoryCalendar.pages(for: year, source: store.calendarSource)
    }

    private var yearSummary: String {
        let entries = pages.flatMap { page in page.moments.map { (page, $0) } }
        let objects = Set(entries.flatMap { $0.1.itemIDs }).count
        let memories = entries.filter { !$0.0.isAddedEntry($0.1) }.count
        guard objects > 0 else {
            return "Objects you add to your collection appear here, month by month."
        }
        let objectText = objects == 1 ? "1 object" : "\(objects) objects"
        let memoryText = memories == 1 ? "1 memory" : "\(memories) memories"
        return "\(objectText) · \(memoryText) this year"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR COLLECTION JOURNEY")
                .monoLabel(11, tracking: 0.45)
                .foregroundStyle(BrandColor.inkBlack)

            HStack(alignment: .firstTextBaseline) {
                Text(String(year))
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .foregroundStyle(BrandColor.inkBlack)

                Spacer()

                yearSwitcher
            }
            .padding(.top, 12)

            Text(yearSummary)
                .monoBody(13)
                .foregroundStyle(BrandColor.catalogGray)
                .padding(.top, 6)

            CalendarStack(
                pages: pages,
                focusedIndex: $focusedIndex,
                onOpen: { showingFlip = true },
                onTapMoment: { selectedMoment = $0 }
            )
            .padding(.top, 18)
        }
        .onAppear {
            guard !hasPositioned else { return }
            hasPositioned = true
            focusedIndex = MemoryCalendar.defaultIndex(in: pages)
        }
        .onChange(of: year) {
            focusedIndex = MemoryCalendar.defaultIndex(in: pages)
        }
        .onChange(of: pages.count) {
            focusedIndex = min(focusedIndex, pages.count - 1)
        }
        .sheet(item: $selectedMoment) { moment in
            MomentObjectsSheet(moment: moment)
        }
        .fullScreenCover(isPresented: $showingFlip) {
            CalendarFlipView(pages: pages, focusedIndex: $focusedIndex)
        }
    }

    private var yearSwitcher: some View {
        let index = years.firstIndex(of: year) ?? 0
        return HStack(spacing: 14) {
            Button {
                Haptics.selection()
                year = years[index - 1]
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(index == 0)
            .accessibilityLabel("Previous year")

            Button {
                Haptics.selection()
                year = years[index + 1]
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(index >= years.count - 1)
            .accessibilityLabel("Next year")
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(BrandColor.inkBlack)
        .buttonStyle(.plain)
    }
}

// MARK: - Collage Studio

private struct CollageStudioCard: View {
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(
                cornerRadius: 27,
                style: .continuous
            )
            .fill(Color(hex: 0x20231F))

            VStack(alignment: .leading, spacing: 0) {
                Text("COLLAGE STUDIO")
                    .monoLabel(10, tracking: 0.65)
                    .foregroundStyle(
                        Color.white.opacity(0.64)
                    )

                Text(
                    """
                    YOUR OBJECTS,
                    YOUR OWN
                    COMPOSITION.
                    """
                )
                .monoTitle(29, tracking: -0.4)
                .foregroundStyle(BrandColor.archiveIvory)
                .lineSpacing(-2)
                .padding(.top, 18)

                Text(
                    """
                    Turn your collection into a visual story
                    worth sharing.
                    """
                )
                .monoBody(11)
                .foregroundStyle(
                    Color.white.opacity(0.6)
                )
                .lineSpacing(5)
                .padding(.top, 20)

                Spacer()

                Button(action: action) {
                    Text("OPEN THE STUDIO  →")
                        .monoLabel(10, tracking: 0.35)
                        .foregroundStyle(
                            BrandColor.inkBlack
                        )
                        .padding(.horizontal, 18)
                        .frame(height: 42)
                        .background(
                            BrandColor.archiveIvory,
                            in: Capsule()
                        )
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding(21)

            CollageArtwork()
                .frame(width: 178, height: 188)
                .position(
                    x: 278,
                    y: height - 102
                )
                .accessibilityHidden(true)
        }
        .frame(height: height)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 27,
                style: .continuous
            )
        )
    }
}

// MARK: - Collage Artwork

private struct CollageArtwork: View {
    var body: some View {
        ZStack {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(BrandColor.collectedRed)

                Circle()
                    .fill(BrandColor.inkBlack)
                    .frame(width: 52, height: 52)
                    .offset(x: 17, y: 22)

                Circle()
                    .fill(BrandColor.paperTan)
                    .frame(width: 15, height: 15)
                    .offset(x: 35, y: 40)

                Text("FIRST LOVE")
                    .monoLabel(7)
                    .foregroundStyle(
                        BrandColor.archiveIvory
                    )
                    .offset(x: 12, y: 98)
            }
            .frame(width: 92, height: 126)
            .rotationEffect(.degrees(-8))
            .offset(x: -33, y: 6)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color(hex: 0xDCC7A6))

                Path { path in
                    path.move(
                        to: CGPoint(x: 0, y: 86)
                    )
                    path.addLine(
                        to: CGPoint(x: 105, y: 43)
                    )
                    path.addLine(
                        to: CGPoint(x: 105, y: 130)
                    )
                    path.addLine(
                        to: CGPoint(x: 0, y: 130)
                    )
                    path.closeSubpath()
                }
                .fill(Color(hex: 0x9B6C4D))

                Text("DUNE")
                    .font(
                        .system(
                            size: 19,
                            design: .serif
                        )
                    )
                    .foregroundStyle(BrandColor.inkBlack)
                    .offset(x: 12, y: 10)
            }
            .frame(width: 105, height: 130)
            .rotationEffect(.degrees(6))
            .offset(x: 38, y: 5)

            VStack(spacing: -3) {
                Circle()
                    .fill(Color(hex: 0xDCC5B3))
                    .frame(width: 42, height: 42)

                UnevenRoundedRectangle(
                    topLeadingRadius: 22,
                    bottomLeadingRadius: 7,
                    bottomTrailingRadius: 7,
                    topTrailingRadius: 22
                )
                .fill(BrandColor.olive)
                .frame(width: 58, height: 83)
            }
            .offset(x: -44, y: 62)

            Rectangle()
                .fill(
                    BrandColor.paperTan.opacity(0.75)
                )
                .frame(width: 64, height: 14)
                .rotationEffect(.degrees(5))
                .offset(y: -68)

            Path { path in
                path.move(
                    to: CGPoint(x: 8, y: 169)
                )

                path.addCurve(
                    to: CGPoint(x: 166, y: 163),
                    control1: CGPoint(x: 58, y: 182),
                    control2: CGPoint(x: 119, y: 177)
                )
            }
            .stroke(
                BrandColor.collectedRed,
                lineWidth: 2
            )
        }
    }
}

// MARK: - Button Style

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(
        configuration: Configuration
    ) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed
                    ? 0.96
                    : 1
            )
            .opacity(
                configuration.isPressed
                    ? 0.86
                    : 1
            )
            .animation(
                .easeOut(duration: 0.14),
                value: configuration.isPressed
            )
    }
}

// MARK: - Previews

#Preview("iPhone 15 Pro") {
    HomeView()
        .environmentObject(CollectionStore())
        .frame(width: 393, height: 852)
}

#Preview("iPhone SE") {
    HomeView()
        .environmentObject(CollectionStore())
        .frame(width: 375, height: 667)
}
