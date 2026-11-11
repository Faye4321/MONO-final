import PhotosUI
import SwiftUI

// MARK: - Options

protocol TitledOption: CaseIterable, Identifiable, Hashable where AllCases: RandomAccessCollection {
    var title: String { get }
}

extension ItemCondition: TitledOption {}
extension Rarity: TitledOption {}
extension MeaningTag: TitledOption {}
extension Moment.PlaceKind: TitledOption {}
extension Moment.Kind: TitledOption {}
extension Moment.DatePrecision: TitledOption {}

/// A menu picker for an optional value, with "Not set" as the empty choice.
struct OptionalOptionPicker<Option: TitledOption>: View {
    let label: String
    @Binding var selection: Option?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            MemoryFieldLabel(label)
            Picker(label, selection: $selection) {
                Text("Not set").tag(Option?.none)
                ForEach(Option.allCases) { option in
                    Text(option.title).tag(Option?.some(option))
                }
            }
            .pickerStyle(.menu)
            .tint(ArchiveTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .background(ArchiveTheme.ivory, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Fields

struct MemoryFieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(ArchiveTheme.label(9))
            .tracking(0.8)
            .foregroundStyle(ArchiveTheme.catalogGray)
    }
}

struct MemoryTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var multiline = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            MemoryFieldLabel(label)
            Group {
                if multiline {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(3...6)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboard)
                }
            }
            .font(ArchiveTheme.body(15))
            .padding(14)
            .background(ArchiveTheme.ivory, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct MemorySectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(ArchiveTheme.heading(15))
                .foregroundStyle(ArchiveTheme.ink)
            Text(subtitle)
                .font(ArchiveTheme.body(12))
                .foregroundStyle(ArchiveTheme.catalogGray)
        }
    }
}

// MARK: - Standard Data

struct StandardDataFields: View {
    @Binding var priceText: String
    @Binding var condition: ItemCondition?
    @Binding var rarity: Rarity?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MemorySectionHeader(
                title: "Object Details",
                subtitle: "Price, condition and rarity. All optional."
            )
            MemoryTextField(
                label: "PRICE PAID (USD)",
                placeholder: "0.00",
                text: $priceText,
                keyboard: .decimalPad
            )
            HStack(spacing: 12) {
                OptionalOptionPicker(label: "CONDITION", selection: $condition)
                OptionalOptionPicker(label: "RARITY", selection: $rarity)
            }
        }
    }
}

// MARK: - Meaning

struct MeaningFields: View {
    @Binding var meaning: String
    @Binding var tag: MeaningTag?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MemoryFieldLabel("WHY IT MATTERS")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(MeaningTag.allCases) { option in
                        Button {
                            tag = tag == option ? nil : option
                        } label: {
                            Text(option.title.uppercased())
                                .font(ArchiveTheme.label(9))
                                .tracking(0.4)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(tag == option ? .white : ArchiveTheme.ink)
                                .background(
                                    tag == option ? ArchiveTheme.collectedRed : ArchiveTheme.ivory,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)

            TextField("One line on why you keep it", text: $meaning, axis: .vertical)
                .lineLimit(1...3)
                .font(ArchiveTheme.body(15))
                .padding(14)
                .background(ArchiveTheme.ivory, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Moment Fields

struct MomentFields: View {
    @Binding var draft: MomentDraft
    var suggestedDate: Date?

    @State private var pickerItems: [PhotosPickerItem] = []

    private let maxPhotos = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            dateSection
            placeSection

            MemoryTextField(
                label: "WITH",
                placeholder: "Names, separated by commas",
                text: $draft.companionsText
            )

            photoSection

            MemoryTextField(
                label: "NOTE",
                placeholder: "What happened? What do you want to remember?",
                text: $draft.note,
                multiline: true
            )
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $draft.includesDate) {
                MemoryFieldLabel("WHEN")
            }
            .tint(ArchiveTheme.collectedRed)

            if let suggestedDate, !draft.includesDate || draft.date != suggestedDate {
                Button {
                    draft.includesDate = true
                    draft.date = suggestedDate
                    draft.datePrecision = .day
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("USE PHOTO DATE · \(suggestedDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(ArchiveTheme.label(10))
                        Text("This is when the photo was taken. Check it matches when you got the object.")
                            .font(ArchiveTheme.body(11))
                            .foregroundStyle(ArchiveTheme.catalogGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(ArchiveTheme.paperTan.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(ArchiveTheme.ink)
            }

            if draft.includesDate {
                Picker("Precision", selection: $draft.datePrecision) {
                    ForEach(Moment.DatePrecision.allCases) { precision in
                        Text(precision.title).tag(precision)
                    }
                }
                .pickerStyle(.segmented)

                DatePicker(
                    "Date",
                    selection: $draft.date,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .font(ArchiveTheme.body(14))
                .tint(ArchiveTheme.collectedRed)
            }
        }
    }

    private var placeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MemoryTextField(
                label: "WHERE",
                placeholder: "Fansign in Seoul, a record store, eBay…",
                text: $draft.placeName
            )

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Moment.PlaceKind.allCases) { kind in
                        Button {
                            draft.placeKind = draft.placeKind == kind ? nil : kind
                        } label: {
                            Label(kind.title.uppercased(), systemImage: kind.systemImage)
                                .font(ArchiveTheme.label(9))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .foregroundStyle(draft.placeKind == kind ? .white : ArchiveTheme.ink)
                                .background(
                                    draft.placeKind == kind ? ArchiveTheme.ink : ArchiveTheme.ivory,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MemoryFieldLabel("PHOTOS · \(draft.photoCount)/\(maxPhotos)")

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Array(draft.existingPhotoFileNames.enumerated()), id: \.element) { index, name in
                        thumbnail(ImageStore.thumbnail(named: name)) {
                            draft.existingPhotoFileNames.remove(at: index)
                        }
                    }

                    ForEach(Array(draft.newPhotos.enumerated()), id: \.offset) { index, data in
                        thumbnail(UIImage(data: data)) {
                            draft.newPhotos.remove(at: index)
                        }
                    }

                    if draft.photoCount < maxPhotos {
                        PhotosPicker(
                            selection: $pickerItems,
                            maxSelectionCount: maxPhotos - draft.photoCount,
                            matching: .images
                        ) {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(ArchiveTheme.paperTan, style: StrokeStyle(lineWidth: 1, dash: [5]))
                                .frame(width: 72, height: 72)
                                .overlay {
                                    Image(systemName: "plus")
                                        .foregroundStyle(ArchiveTheme.catalogGray)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                var loaded: [Data] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        loaded.append(data)
                    }
                }
                await MainActor.run {
                    draft.newPhotos.append(contentsOf: loaded)
                    pickerItems = []
                }
            }
        }
    }

    private func thumbnail(_ image: UIImage?, remove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ArchiveTheme.paperTan.opacity(0.4)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, ArchiveTheme.ink.opacity(0.7))
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
            .accessibilityLabel("Remove photo")
        }
    }
}

// MARK: - Moment Card

struct MomentCard: View {
    let moment: Moment
    /// Other objects in the same moment, shown as "Also from this moment".
    var relatedTitles: [String] = []

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(moment.kind == .farewell ? ArchiveTheme.catalogGray : ArchiveTheme.collectedRed)
                    .frame(width: 9, height: 9)
                    .padding(.top, 5)
                Rectangle()
                    .fill(ArchiveTheme.paperTan.opacity(0.6))
                    .frame(width: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(moment.kind.title.uppercased())
                        .font(ArchiveTheme.label(9))
                        .tracking(0.8)
                        .foregroundStyle(ArchiveTheme.collectedRed)
                    Spacer()
                    Text(moment.formattedDate)
                        .font(ArchiveTheme.label(10))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                }

                if !moment.placeName.isEmpty || moment.placeKind != nil {
                    Label(
                        moment.placeName.isEmpty ? (moment.placeKind?.title ?? "") : moment.placeName,
                        systemImage: moment.placeKind?.systemImage ?? "mappin"
                    )
                    .font(ArchiveTheme.heading(15))
                    .foregroundStyle(ArchiveTheme.ink)
                }

                if !moment.companions.isEmpty {
                    Text("With \(moment.companions.formatted(.list(type: .and)))")
                        .font(ArchiveTheme.body(13))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                }

                if !moment.photoFileNames.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(moment.photoFileNames, id: \.self) { name in
                                if let image = ImageStore.thumbnail(named: name) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 92, height: 92)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                if !moment.note.isEmpty {
                    Text(moment.note)
                        .font(ArchiveTheme.body(14))
                        .foregroundStyle(ArchiveTheme.ink)
                        .lineSpacing(4)
                }

                if !relatedTitles.isEmpty {
                    Text("Also from this moment: \(relatedTitles.joined(separator: ", "))")
                        .font(ArchiveTheme.body(12))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                        .lineLimit(2)
                }
            }
            .padding(.bottom, 18)
        }
        .contentShape(Rectangle())
    }
}
