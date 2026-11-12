import PhotosUI
import AVFoundation
import SwiftUI
import UIKit

struct CreateFlowView: View {
    @EnvironmentObject private var store: CollectionStore
    let onSaved: () -> Void

    @State private var step: AddItemStep = .selectPhoto
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var croppedImageData: Data?
    @State private var isLoadingPhoto = false
    @State private var showPhotoError = false

    @State private var selectedCategory: CollectionCategory?
    @State private var selectedCollectionID: UUID?
    @State private var showingNewCollection = false
    @State private var cropScale: CGFloat = 1
    @State private var cropOffset: CGSize = .zero
    @State private var cropCanvasSize: CGSize = .zero

    @State private var brightness = 0.0
    @State private var contrast = 1.0
    @State private var saturation = 1.0

    @State private var title = ""
    @State private var creator = ""
    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var includesYear = false
    @AppStorage(CollectingPreferences.storageKey) private var collectsRaw = ""

    @State private var priceText = ""
    @State private var condition: ItemCondition?
    @State private var rarity: Rarity?
    @State private var meaning = ""
    @State private var meaningTag: MeaningTag?
    @State private var memory = MomentDraft()
    @State private var suggestedDate: Date?
    @State private var joinMomentID: UUID?
    @State private var includesMemory = true

    var body: some View {
        NavigationStack {
            ZStack {
                ArchiveTheme.ivory.ignoresSafeArea()

                switch step {
                case .selectPhoto: photoSelection
                case .cropAndCategory: cropAndCategory
                case .details: itemDetails
                case .memory: memoryStep
                case .preview: itemPreview
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .foregroundStyle(ArchiveTheme.ink)
        .environment(\.colorScheme, .light)
        .sheet(isPresented: $showingNewCollection) {
            NewPersonalCollectionSheet { collection in selectedCollectionID = collection.id }
        }
        .onAppear {
            if selectedCollectionID == nil { selectedCollectionID = store.onboardingPreferredCollectionID }
        }
        .onChange(of: selectedCollectionID) { _, id in
            if let id, let collection = store.personalCollection(id: id), selectedCategory == nil {
                selectedCategory = collection.layout
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            loadPhoto(newValue)
        }
        .alert("Couldn’t Load Photo", isPresented: $showPhotoError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please choose another image from your photo library.")
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ADD ITEM")
                    .font(ArchiveTheme.display(27))
                Text(step.subtitle)
                    .font(ArchiveTheme.label(10))
                    .tracking(1.1)
                    .foregroundStyle(ArchiveTheme.catalogGray)
            }
            Spacer()
            Text("STEP \(step.rawValue + 1) OF \(AddItemStep.allCases.count)")
                .font(ArchiveTheme.label(10))
                .foregroundStyle(ArchiveTheme.catalogGray)
        }
    }

    private var photoSelection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                pageHeader
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Save to collection", selection: $selectedCollectionID) {
                        Text("Unfiled").tag(nil as UUID?)
                        ForEach(store.activeCollections) { collection in
                            Text(collection.name).tag(Optional(collection.id))
                        }
                    }
                    Button("Create a custom collection") { showingNewCollection = true }
                        .disabled(!store.catalogReady)
                }
                .font(ArchiveTheme.body(14))

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    VStack(spacing: 18) {
                        Circle()
                            .fill(ArchiveTheme.collectedRed)
                            .frame(width: 62, height: 62)
                            .overlay {
                                if isLoadingPhoto {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundStyle(.white)
                                }
                            }

                        VStack(spacing: 7) {
                            Text(sourceImage == nil ? "SELECT A PHOTO" : "CHOOSE A DIFFERENT PHOTO")
                                .font(ArchiveTheme.heading(19))
                            Text("Choose an image, then choose its shape and position.")
                                .font(ArchiveTheme.body(13))
                                .foregroundStyle(ArchiveTheme.catalogGray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 75)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 24))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(ArchiveTheme.paperTan, style: StrokeStyle(lineWidth: 1, dash: [7]))
                            .allowsHitTesting(false)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoadingPhoto)

                if sourceImage != nil {
                    Button("CONTINUE") { go(to: .cropAndCategory) }
                        .buttonStyle(ArchivePrimaryButtonStyle())
                }

                Text("SUPPORTED: PHOTOCARDS · BJD · ALBUMS · POSTERS")
                    .font(ArchiveTheme.label(9))
                    .tracking(0.7)
                    .foregroundStyle(ArchiveTheme.catalogGray)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
            .padding(.bottom, 160)
        }
    }

    private var cropAndCategory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                pageHeader

                VStack(alignment: .leading, spacing: 12) {
                    fieldLabel("PHOTO SHAPE")
                    Text("Saving to: " + (selectedCollectionID.flatMap { store.personalCollection(id: $0)?.name } ?? "Unfiled"))
                        .font(ArchiveTheme.body(12))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                    categoryGrid
                }
                .padding(16)
                .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18))

                if let sourceImage {
                    PinchCropView(
                        image: sourceImage,
                        aspectRatio: activeCategory.artworkAspectRatio,
                        scale: $cropScale,
                        offset: $cropOffset,
                        canvasSize: $cropCanvasSize,
                        brightness: brightness,
                        contrast: contrast,
                        saturation: saturation
                    )
                    .id(activeCategory)
                }

                Text("PINCH TO ZOOM · DRAG TO REPOSITION")
                    .font(ArchiveTheme.label(9))
                    .tracking(0.7)
                    .foregroundStyle(ArchiveTheme.catalogGray)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 18) {
                    EditSlider(title: "BRIGHTNESS", value: $brightness, range: -0.5...0.5)
                    EditSlider(title: "CONTRAST", value: $contrast, range: 0.5...1.5)
                    EditSlider(title: "SATURATION", value: $saturation, range: 0...2)
                }
                .padding(18)
                .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 20))

                HStack(spacing: 12) {
                    Button("BACK") { go(to: .selectPhoto) }
                        .buttonStyle(ArchiveSecondaryButtonStyle())
                    Button("RESET") { resetCropAndAdjustments() }
                        .buttonStyle(ArchiveSecondaryButtonStyle())
                }

                Button("NEXT") {
                    prepareCroppedImage()
                    go(to: .details)
                }
                .buttonStyle(ArchivePrimaryButtonStyle())
                .disabled(selectedCategory == nil || cropCanvasSize == .zero)
                .opacity(selectedCategory == nil || cropCanvasSize == .zero ? 0.45 : 1)

                if selectedCategory == nil {
                    Text("Please select a photo shape before continuing.")
                        .font(ArchiveTheme.body(12))
                        .foregroundStyle(ArchiveTheme.collectedRed)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .padding(.bottom, 160)
        }
    }

    private func photoShapeName(_ category: CollectionCategory) -> String {
        switch category {
        case .vinyl: return "Square"
        case .bjd: return "Tall portrait"
        case .poster: return "Portrait"
        case .photocard: return "Card"
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(CollectionCategory.allCases) { category in
                Button {
                    if selectedCategory != category {
                        selectedCategory = category
                        cropScale = 1
                        cropOffset = .zero
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: category.systemImage)
                        Text(photoShapeName(category))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Spacer(minLength: 0)
                        if selectedCategory == category {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .font(ArchiveTheme.label(11))
                    .padding(.horizontal, 12)
                    .frame(height: 48)
                    .foregroundStyle(selectedCategory == category ? .white : ArchiveTheme.ink)
                    .background(
                        selectedCategory == category ? ArchiveTheme.collectedRed : ArchiveTheme.ivory,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var itemDetails: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                pageHeader

                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        fieldLabel("COLLECTION")
                        Spacer()
                        Text(selectedCollectionID.flatMap { store.personalCollection(id: $0)?.name } ?? "Unfiled")
                            .font(ArchiveTheme.heading(13))
                    }

                    ArchiveTextField(label: "OBJECT TITLE", placeholder: "Untitled object", text: $title)
                    ArchiveTextField(label: "CREATOR / ARTIST / BRAND", placeholder: "Creator", text: $creator)

                    Toggle("ADD YEAR", isOn: $includesYear)
                        .font(ArchiveTheme.label(9))
                        .tracking(0.8)
                        .tint(ArchiveTheme.collectedRed)

                    if includesYear {
                        Stepper(value: $year, in: 1900...Calendar.current.component(.year, from: .now)) {
                            Text(String(year)).font(ArchiveTheme.body(15))
                        }
                    }
                }
                .padding(18)
                .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))

                StandardDataFields(priceText: $priceText, condition: $condition, rarity: $rarity)
                    .padding(18)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))

                HStack(spacing: 12) {
                    Button("BACK") { go(to: .cropAndCategory) }
                        .buttonStyle(ArchiveSecondaryButtonStyle())
                    Button("NEXT") { go(to: .memory) }
                        .buttonStyle(ArchivePrimaryButtonStyle())
                        .disabled(cleanTitle.isEmpty)
                        .opacity(cleanTitle.isEmpty ? 0.45 : 1)
                }
            }
            .padding(20)
            .padding(.bottom, 160)
        }
    }

    // Personal data gets its own, skippable step so the object itself
    // can be saved quickly and the memory added later from its page.
    private var memoryStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                pageHeader

                HStack(alignment: .top) {
                    MemorySectionHeader(
                        title: "When, where, with whom?",
                        subtitle: "Every field is optional. You can add more later from the object's page."
                    )
                    Spacer(minLength: 12)
                    Button("SKIP FOR NOW") { showPreview(includingMemory: false) }
                        .font(ArchiveTheme.label(10))
                        .foregroundStyle(ArchiveTheme.collectedRed)
                }

                memoryCard

                HStack(spacing: 12) {
                    Button("BACK") { go(to: .details) }
                        .buttonStyle(ArchiveSecondaryButtonStyle())
                    Button("PREVIEW") { showPreview(includingMemory: true) }
                        .buttonStyle(ArchivePrimaryButtonStyle())
                }
            }
            .padding(20)
            .padding(.bottom, 160)
        }
    }

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            MeaningFields(meaning: $meaning, tag: $meaningTag)

            let recent = store.recentAcquisitions()
            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("PART OF A RECENT MOMENT?")
                    Picker("Moment", selection: $joinMomentID) {
                        Text("No, a new memory").tag(UUID?.none)
                        ForEach(recent) { moment in
                            Text("\(moment.summary) · \(moment.itemIDs.count) objects")
                                .tag(UUID?.some(moment.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(ArchiveTheme.ink)
                }
            }

            if joinMomentID == nil {
                MomentFields(draft: $memory, suggestedDate: suggestedDate)
            } else {
                Text("This object will share the date, place, people and photos of that moment.")
                    .font(ArchiveTheme.body(13))
                    .foregroundStyle(ArchiveTheme.catalogGray)
            }
        }
        .padding(18)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
    }

    private var itemPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                pageHeader

                if let croppedImageData, let image = UIImage(data: croppedImageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .brightness(brightness)
                        .contrast(contrast)
                        .saturation(saturation)
                        .aspectRatio(activeCategory.artworkAspectRatio, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(activeCategory.shelfLabel)
                        .font(ArchiveTheme.label(9))
                        .tracking(0.8)
                        .foregroundStyle(ArchiveTheme.collectedRed)
                    Text(cleanTitle)
                        .font(ArchiveTheme.display(28))
                    Text(previewMetadata)
                        .font(ArchiveTheme.heading(13))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                    if includesMemory, !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Divider()
                        Text(meaning)
                            .font(ArchiveTheme.body(14))
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))

                HStack(spacing: 12) {
                    Button("BACK") { go(to: .memory) }
                        .buttonStyle(ArchiveSecondaryButtonStyle())
                    Button("SAVE ITEM") { saveObject() }
                        .buttonStyle(ArchivePrimaryButtonStyle())
                }
            }
            .padding(20)
            .padding(.bottom, 160)
        }
    }

    /// The first collection type picked during setup, if any.
    private var preferredCategory: CollectionCategory? {
        CollectingPreferences.categories(from: collectsRaw).first
    }

    private var activeCategory: CollectionCategory { selectedCategory ?? .vinyl }
    private var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var cleanCreator: String {
        let value = creator.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Unknown" : value
    }
    private var previewMetadata: String {
        includesYear ? "\(cleanCreator) · \(String(year))" : cleanCreator
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(ArchiveTheme.label(9))
            .tracking(0.8)
            .foregroundStyle(ArchiveTheme.catalogGray)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isLoadingPhoto = true

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw PhotoLoadingError.invalidImage
                }
                await MainActor.run {
                    sourceImage = image
                    croppedImageData = nil
                    selectedCategory = preferredCategory
                    suggestedDate = PhotoMetadata.captureDate(from: data)
                    resetCropAndAdjustments()
                    isLoadingPhoto = false
                    go(to: .cropAndCategory)
                }
            } catch {
                await MainActor.run {
                    isLoadingPhoto = false
                    showPhotoError = true
                }
            }
        }
    }

    private func prepareCroppedImage() {
        guard let sourceImage, cropCanvasSize != .zero else { return }
        let cropped = ImageCropRenderer.crop(
            sourceImage,
            canvasSize: cropCanvasSize,
            scale: cropScale,
            offset: cropOffset
        )
        croppedImageData = cropped.jpegData(compressionQuality: 0.9)
    }

    private func showPreview(includingMemory: Bool) {
        includesMemory = includingMemory
        prepareCroppedImage()
        go(to: .preview)
    }

    private func saveObject() {
        guard let category = selectedCategory,
              let croppedImageData,
              !cleanTitle.isEmpty else { return }

        // Fall back to inline data only if the file could not be written.
        let imageFileName = ImageStore.save(croppedImageData)

        let item = CollectibleItem(
            title: cleanTitle,
            collectionID: selectedCollectionID.flatMap { id in store.activeCollections.contains(where: { $0.id == id }) ? id : nil } ?? CollectionStore.unfiledCollectionID,
            creator: cleanCreator,
            year: includesYear ? year : nil,
            category: category,
            note: "",
            colorA: "D5B99C",
            colorB: "706B63",
            imageData: imageFileName == nil ? croppedImageData : nil,
            imageFileName: imageFileName,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            isUserCreated: true,
            pricePaid: PriceText.parse(priceText),
            condition: condition,
            rarity: rarity,
            meaning: includesMemory ? meaning.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            meaningTag: includesMemory ? meaningTag : nil
        )

        store.addItem(item)
        store.onboardingPreferredCollectionID = nil

        if includesMemory {
            if let joinMomentID {
                store.attach(itemID: item.id, toMoment: joinMomentID)
            } else if !memory.isEmpty {
                var draft = memory
                draft.itemIDs = [item.id]
                store.addMoment(draft.makeMoment())
            }
        }
        ArchiveSoundPlayer.shared.play(for: category)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        resetFlow()
        onSaved()
    }

    private func go(to newStep: AddItemStep) {
        withAnimation(.easeInOut(duration: 0.22)) { step = newStep }
    }

    private func resetCropAndAdjustments() {
        cropScale = 1
        cropOffset = .zero
        brightness = 0
        contrast = 1
        saturation = 1
        croppedImageData = nil
    }

    private func resetFlow() {
        step = .selectPhoto
        selectedPhoto = nil
        sourceImage = nil
        croppedImageData = nil
        selectedCategory = nil
        selectedCollectionID = nil
        cropScale = 1
        cropOffset = .zero
        cropCanvasSize = .zero
        brightness = 0
        contrast = 1
        saturation = 1
        title = ""
        creator = ""
        year = Calendar.current.component(.year, from: .now)
        includesYear = false
        priceText = ""
        condition = nil
        rarity = nil
        meaning = ""
        meaningTag = nil
        memory = MomentDraft()
        suggestedDate = nil
        joinMomentID = nil
        includesMemory = true
    }
}

private enum AddItemStep: Int, CaseIterable {
    case selectPhoto
    case cropAndCategory
    case details
    case memory
    case preview

    var subtitle: String {
        switch self {
        case .selectPhoto: "SELECT A PHOTO"
        case .cropAndCategory: "CROP · ADJUST · CHOOSE CATEGORY"
        case .details: "ADD INFORMATION"
        case .memory: "ADD YOUR MEMORY"
        case .preview: "REVIEW BEFORE SAVING"
        }
    }
}

private enum PhotoLoadingError: Error { case invalidImage }

private struct PinchCropView: View {
    let image: UIImage
    let aspectRatio: CGFloat
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @Binding var canvasSize: CGSize
    let brightness: Double
    let contrast: Double
    let saturation: Double

    @State private var gestureStartScale: CGFloat?
    @State private var gestureStartOffset: CGSize?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                ArchiveTheme.ink.opacity(0.07)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .brightness(brightness)
                    .contrast(contrast)
                    .saturation(saturation)
                    .gesture(panGesture.simultaneously(with: zoomGesture))
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .contentShape(Rectangle())
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.95), lineWidth: 2)
                    .shadow(color: .black.opacity(0.2), radius: 2)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .onAppear { canvasSize = size }
            .onChange(of: size) { _, newSize in canvasSize = newSize }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: 390)
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if gestureStartOffset == nil { gestureStartOffset = offset }
                let start = gestureStartOffset ?? .zero
                offset = clampedOffset(CGSize(
                    width: start.width + value.translation.width,
                    height: start.height + value.translation.height
                ), at: scale)
            }
            .onEnded { _ in gestureStartOffset = nil }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if gestureStartScale == nil { gestureStartScale = scale }
                scale = max(1, min((gestureStartScale ?? 1) * value, 6))
                offset = clampedOffset(offset, at: scale)
            }
            .onEnded { _ in gestureStartScale = nil }
    }

    private func clampedOffset(_ proposed: CGSize, at scale: CGFloat) -> CGSize {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return proposed }

        let baseScale = max(
            canvasSize.width / image.size.width,
            canvasSize.height / image.size.height
        )
        let displayedWidth = image.size.width * baseScale * scale
        let displayedHeight = image.size.height * baseScale * scale
        let maxX = max(0, (displayedWidth - canvasSize.width) / 2)
        let maxY = max(0, (displayedHeight - canvasSize.height) / 2)

        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }
}

private enum ImageCropRenderer {
    static func crop(
        _ image: UIImage,
        canvasSize: CGSize,
        scale userScale: CGFloat,
        offset: CGSize
    ) -> UIImage {
        guard canvasSize.width > 0,
              canvasSize.height > 0,
              image.size.width > 0,
              image.size.height > 0 else { return image }

        let outputWidth: CGFloat = 1200
        let outputHeight = outputWidth * canvasSize.height / canvasSize.width
        let outputSize = CGSize(width: outputWidth, height: outputHeight)
        let outputFactor = outputWidth / canvasSize.width
        let baseScale = max(
            canvasSize.width / image.size.width,
            canvasSize.height / image.size.height
        )
        let displayedSize = CGSize(
            width: image.size.width * baseScale * userScale,
            height: image.size.height * baseScale * userScale
        )
        let origin = CGPoint(
            x: (canvasSize.width - displayedSize.width) / 2 + offset.width,
            y: (canvasSize.height - displayedSize.height) / 2 + offset.height
        )
        let drawRect = CGRect(
            x: origin.x * outputFactor,
            y: origin.y * outputFactor,
            width: displayedSize.width * outputFactor,
            height: displayedSize.height * outputFactor
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            UIColor.black.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: outputSize))
            image.draw(in: drawRect)
        }
    }
}

private struct EditSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(value.formatted(.number.precision(.fractionLength(1))))
            }
            .font(ArchiveTheme.label(9))
            .foregroundStyle(ArchiveTheme.catalogGray)
            Slider(value: $value, in: range)
                .tint(ArchiveTheme.collectedRed)
        }
    }
}

private struct ArchiveTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(ArchiveTheme.label(9))
                .tracking(0.8)
                .foregroundStyle(ArchiveTheme.catalogGray)
            TextField(placeholder, text: $text)
                .font(ArchiveTheme.body(15))
                .foregroundStyle(ArchiveTheme.ink)
                .tint(ArchiveTheme.collectedRed)
                .padding(14)
                .background(ArchiveTheme.ivory, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct ArchivePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ArchiveTheme.label(11))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                ArchiveTheme.collectedRed.opacity(configuration.isPressed ? 0.72 : 1),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct ArchiveSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ArchiveTheme.label(11))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(ArchiveTheme.ink)
            .background(.white.opacity(configuration.isPressed ? 0.55 : 0.82), in: Capsule())
    }
}



// Soft, original archive sounds bundled with this project.
private final class ArchiveSoundPlayer {
    static let shared = ArchiveSoundPlayer()
    private var player: AVAudioPlayer?

    func play(for category: CollectionCategory) {
        let filename: String
        switch category {
        case .vinyl: filename = "archive_vinyl"
        case .bjd: filename = "archive_bjd"
        case .poster: filename = "archive_poster"
        case .photocard: filename = "archive_photocard"
        }
        guard let url = Bundle.main.url(forResource: filename, withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 0.72
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("Archive sound unavailable: \(error)")
        }
    }
}
