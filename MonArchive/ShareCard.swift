import SwiftUI

// Exports one memory as an image. Personal fields are opt-in: every toggle
// starts off, so nothing private leaves the phone unless the user picks it.
struct ShareCardSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: CollectibleItem
    let moments: [Moment]

    @State private var selectedMomentID: Moment.ID?
    @State private var options = ShareCardOptions()
    @State private var rendered: UIImage?

    private var moment: Moment? {
        moments.first { $0.id == selectedMomentID } ?? moments.last
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let moment {
                        ShareCardContent(item: item, moment: moment, options: options)
                            .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        if moments.count > 1 {
                            Picker("Memory", selection: $selectedMomentID) {
                                ForEach(moments) { moment in
                                    Text(moment.summary).tag(Moment.ID?.some(moment.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(ArchiveTheme.ink)
                        }

                        MemoryFieldLabel("CHOOSE WHAT TO INCLUDE")
                        Toggle("Date", isOn: $options.date)
                        Toggle("Place", isOn: $options.place)
                        Toggle("People", isOn: $options.people)
                        Toggle("Photo", isOn: $options.photo)
                        Toggle("Note", isOn: $options.note)
                        Toggle("Why it matters", isOn: $options.meaning)
                    }
                    .font(ArchiveTheme.body(14))
                    .tint(ArchiveTheme.collectedRed)
                    .padding(18)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))

                    if let rendered {
                        ShareLink(
                            item: Image(uiImage: rendered),
                            preview: SharePreview(item.title, image: Image(uiImage: rendered))
                        ) {
                            Label("SHARE IMAGE", systemImage: "square.and.arrow.up")
                                .font(ArchiveTheme.label(11))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(.white)
                                .background(ArchiveTheme.ink, in: Capsule())
                        }
                    }
                }
                .padding(20)
            }
            .background(ArchiveTheme.ivory.ignoresSafeArea())
            .navigationTitle("Share a Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task(id: RenderKey(momentID: moment?.id, options: options)) {
                await MainActor.run { render() }
            }
        }
    }

    private func render() {
        guard let moment else {
            rendered = nil
            return
        }
        let renderer = ImageRenderer(
            content: ShareCardContent(item: item, moment: moment, options: options)
                .frame(width: 360)
        )
        renderer.scale = 3
        rendered = renderer.uiImage
    }

    private struct RenderKey: Equatable {
        let momentID: Moment.ID?
        let options: ShareCardOptions
    }
}

struct ShareCardOptions: Equatable {
    var date = false
    var place = false
    var people = false
    var photo = false
    var note = false
    var meaning = false
}

struct ShareCardContent: View {
    let item: CollectibleItem
    let moment: Moment
    let options: ShareCardOptions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if options.photo, let name = moment.photoFileNames.first,
               let photo = ImageStore.image(named: name) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                ArtworkView(item: item)
                    .aspectRatio(item.category.artworkAspectRatio, contentMode: .fit)
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Text(moment.kind.title.uppercased())
                .font(ArchiveTheme.label(9))
                .tracking(1)
                .foregroundStyle(ArchiveTheme.collectedRed)

            Text(item.title)
                .font(ArchiveTheme.display(26))
                .foregroundStyle(ArchiveTheme.ink)

            if !item.creator.isEmpty {
                Text(item.creator)
                    .font(ArchiveTheme.heading(13))
                    .foregroundStyle(ArchiveTheme.catalogGray)
            }

            VStack(alignment: .leading, spacing: 6) {
                if options.date, moment.date != nil {
                    Label(moment.formattedDate, systemImage: "calendar")
                }
                if options.place, !moment.placeName.isEmpty {
                    Label(moment.placeName, systemImage: moment.placeKind?.systemImage ?? "mappin")
                }
                if options.people, !moment.companions.isEmpty {
                    Label(moment.companions.formatted(.list(type: .and)), systemImage: "person.2")
                }
            }
            .font(ArchiveTheme.body(13))
            .foregroundStyle(ArchiveTheme.ink)

            if options.note, !moment.note.isEmpty {
                Text(moment.note)
                    .font(ArchiveTheme.body(13))
                    .foregroundStyle(ArchiveTheme.ink)
                    .lineSpacing(3)
            }

            if options.meaning, !item.meaning.isEmpty {
                Text("“\(item.meaning)”")
                    .font(ArchiveTheme.display(17))
                    .foregroundStyle(ArchiveTheme.ink)
            }

            Text("MONARCHIVE")
                .font(ArchiveTheme.label(8))
                .tracking(1.4)
                .foregroundStyle(ArchiveTheme.catalogGray)
                .padding(.top, 4)
        }
        .padding(20)
        .background(ArchiveTheme.ivory)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
