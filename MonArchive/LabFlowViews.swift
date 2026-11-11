import PhotosUI
import SwiftUI
import UIKit

private enum LabFlowStep {
    case home
    case setup
    case collection
    case cutout
    case editor
}

struct LabRootView: View {
    var collectionProvider: any LabCollectionProviding = SampleLabCollectionProvider()

    @State private var step: LabFlowStep = .home
    @State private var project = LabProject()
    @State private var selectedItems: [LabCollectionItem] = []

    // Explicit so other files can pass a provider; the synthesized
    // memberwise init is private because of the private state above.
    init(collectionProvider: any LabCollectionProviding = SampleLabCollectionProvider()) {
        self.collectionProvider = collectionProvider
    }

    var body: some View {
        Group {
            switch step {
            case .home:
                LabHomeView(
                    onNew: {
                        project = LabProject()
                        withAnimation { step = .setup }
                    },
                    onOpenDraft: { draft in
                        project = draft
                        withAnimation { step = .editor }
                    },
                    onUseTemplate: { template in
                        project = template
                        withAnimation { step = .editor }
                    }
                )
            case .setup:
                LabCanvasSetupView(project: $project, onBack: { step = .home }) {
                    withAnimation { step = .collection }
                }
            case .collection:
                LabCollectionPickerView(provider: collectionProvider, onBack: { step = .setup }) { items in
                    selectedItems = items
                    project.palette = LabPaletteExtractor.colors(from: items.map(\.image))
                    withAnimation { step = .cutout }
                }
            case .cutout:
                LabCutoutQueueView(items: selectedItems, onBack: { step = .collection }) { elements in
                    project.elements = elements
                    LabRemixEngine.remix(&project.elements)
                    withAnimation { step = .editor }
                }
            case .editor:
                LabEditorView(project: project, collectionProvider: collectionProvider) {
                    withAnimation { step = .home }
                }
            }
        }
        .background(BrandColor.archiveIvory.ignoresSafeArea())
    }
}

private struct LabHomeView: View {
    let onNew: () -> Void
    let onOpenDraft: (LabProject) -> Void
    let onUseTemplate: (LabProject) -> Void
    @State private var drafts: [LabProject] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MONO LAB")
                            .monoLabel(11, tracking: 1.4)
                            .foregroundStyle(BrandColor.collectedRed)
                        Text("Make from\nwhat you keep.")
                            .monoTitle(44, tracking: -1.1)
                    }
                    Spacer()
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 29, weight: .light))
                }

                Button(action: onNew) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NEW COLLAGE").monoLabel(11, tracking: 1.1)
                            Text("Start with a format, background, and objects from your archive.")
                                .monoBody(14)
                                .foregroundStyle(BrandColor.archiveIvory.opacity(0.72))
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .light))
                    }
                    .foregroundStyle(BrandColor.archiveIvory)
                    .padding(22)
                    .frame(minHeight: 142)
                    .background(BrandColor.inkBlack, in: RoundedRectangle(cornerRadius: 26))
                }
                .buttonStyle(.plain)

                LabSectionHeader(title: "DRAFTS", count: drafts.count)
                if drafts.isEmpty {
                    LabEmptyRow(icon: "square.and.pencil", text: "Your works in progress will appear here.")
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 14) {
                            ForEach(drafts) { draft in
                                Button { onOpenDraft(draft) } label: {
                                    LabProjectThumbnail(project: draft)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                LabSectionHeader(title: "TEMPLATES", count: 3)
                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ForEach(Array(LabTemplateFactory.templates.enumerated()), id: \.offset) { _, template in
                            Button { onUseTemplate(template) } label: {
                                LabProjectThumbnail(project: template)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)

                LabSectionHeader(title: "RECENT CREATIONS", count: drafts.filter { $0.previewData != nil }.count)
                LabEmptyRow(icon: "clock.arrow.circlepath", text: "Saved exports remain available from Drafts.")
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
        .task { drafts = LabDraftStore.load() }
    }
}

private struct LabCanvasSetupView: View {
    @Binding var project: LabProject
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var backgroundPhoto: PhotosPickerItem?
    @State private var customColor = Color(labHex: 0xF3F0E9)

    private let brandColors: [UInt32] = [0xFFFFFF, 0x000000, 0xF3F0E9, 0xB84631, 0xD5B99C]

    var body: some View {
        VStack(spacing: 0) {
            LabNavigationHeader(title: "NEW COLLAGE", onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Choose a canvas.")
                        .monoTitle(38)

                    Text("FORMAT").monoLabel().foregroundStyle(BrandColor.catalogGray)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(LabCanvasFormat.allCases) { format in
                            Button {
                                project.format = format
                                Haptics.selection()
                            } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(format.rawValue).monoHeading(18)
                                    Text(format.title).monoBody(11).foregroundStyle(BrandColor.catalogGray)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(
                                    project.format == format ? BrandColor.inkBlack.opacity(0.08) : Color.white.opacity(0.62),
                                    in: RoundedRectangle(cornerRadius: 18)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(project.format == format ? BrandColor.collectedRed : .clear, lineWidth: 1.5)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("BACKGROUND").monoLabel().foregroundStyle(BrandColor.catalogGray)
                    HStack(spacing: 13) {
                        ForEach(brandColors, id: \.self) { hex in
                            Button {
                                project.background = LabBackground(kind: .solid, colorHex: hex)
                                customColor = Color(labHex: hex)
                            } label: {
                                Circle()
                                    .fill(Color(labHex: hex))
                                    .frame(width: 44, height: 44)
                                    .overlay { Circle().stroke(BrandColor.inkBlack.opacity(0.2), lineWidth: 1) }
                                    .overlay {
                                        if project.background.kind == .solid && project.background.colorHex == hex {
                                            Circle().stroke(BrandColor.collectedRed, lineWidth: 3).padding(-4)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                        ColorPicker("", selection: $customColor, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 44, height: 44)
                            .onChange(of: customColor) { _, color in
                                project.background = LabBackground(kind: .solid, colorHex: color.labUInt32)
                            }
                    }

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $backgroundPhoto, matching: .images) {
                            Label("UPLOAD PHOTO", systemImage: "photo")
                                .monoLabel(10)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)

                        Button {
                            project.background = LabBackground(kind: .transparent, colorHex: 0)
                        } label: {
                            Label("TRANSPARENT", systemImage: "checkerboard.rectangle")
                                .monoLabel(10)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }

            MonoPrimaryButton(title: "CHOOSE FROM COLLECTION", action: onContinue)
                .padding(20)
        }
        .task(id: backgroundPhoto) {
            guard let data = try? await backgroundPhoto?.loadTransferable(type: Data.self) else { return }
            project.background = LabBackground(kind: .photo, colorHex: 0, imageData: data)
        }
    }
}

struct LabCollectionPickerView: View {
    let provider: any LabCollectionProviding
    let onBack: () -> Void
    let onContinue: ([LabCollectionItem]) -> Void

    @State private var items: [LabCollectionItem] = []
    @State private var selected: Set<UUID> = []
    @State private var query = ""

    private var filtered: [LabCollectionItem] {
        guard !query.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.category.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            LabNavigationHeader(title: "YOUR COLLECTION", onBack: onBack)
            TextField("Search objects or categories", text: $query)
                .monoBody(15)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 22)
                .padding(.bottom, 12)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(filtered) { item in
                        Button {
                            if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
                            Haptics.selection()
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(uiImage: item.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 190)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                Text(item.name).monoHeading(15).lineLimit(1)
                                Text("\(item.maker) · \(item.year)")
                                    .monoLabel(8)
                                    .foregroundStyle(BrandColor.catalogGray)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))
                            .overlay {
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(selected.contains(item.id) ? BrandColor.collectedRed : .clear, lineWidth: 2)
                            }
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: selected.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(selected.contains(item.id) ? BrandColor.collectedRed : .white)
                                    .padding(17)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }

            MonoPrimaryButton(title: selected.isEmpty ? "SELECT OBJECTS" : "CUT OUT \(selected.count) OBJECT\(selected.count == 1 ? "" : "S")") {
                onContinue(items.filter { selected.contains($0.id) })
            }
            .disabled(selected.isEmpty)
            .opacity(selected.isEmpty ? 0.42 : 1)
            .padding(20)
        }
        .task { items = await provider.fetchCollectionItems() }
    }
}

private struct LabCutoutQueueView: View {
    let items: [LabCollectionItem]
    let onBack: () -> Void
    let onComplete: ([LabElement]) -> Void

    @State private var index = 0
    @State private var cutout: UIImage?
    @State private var isProcessing = true
    @State private var errorMessage: String?
    @State private var showsOriginal = false
    @State private var showsRefine = false
    @State private var completed: [LabElement] = []

    private var item: LabCollectionItem { items[index] }

    var body: some View {
        VStack(spacing: 0) {
            LabNavigationHeader(title: "CUTOUT \(index + 1) / \(items.count)", onBack: onBack)

            VStack(spacing: 18) {
                ZStack {
                    LabCheckerboard()
                    if isProcessing {
                        ProgressView("Finding your object…")
                            .monoBody(13)
                            .tint(BrandColor.collectedRed)
                    } else {
                        Image(uiImage: showsOriginal ? item.image : (cutout ?? item.image))
                            .resizable()
                            .scaledToFit()
                            .padding(16)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .frame(maxHeight: .infinity)

                Picker("Preview", selection: $showsOriginal) {
                    Text("ORIGINAL").tag(true)
                    Text("CUTOUT PREVIEW").tag(false)
                }
                .pickerStyle(.segmented)

                if let errorMessage {
                    Text(errorMessage + " You can continue with the original or try another photo later.")
                        .monoBody(12)
                        .foregroundStyle(BrandColor.collectedRed)
                }

                HStack(spacing: 12) {
                    Button { showsRefine = true } label: {
                        Label("REFINE", systemImage: "paintbrush")
                            .monoLabel(10)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(cutout == nil)

                    Button(action: addCurrent) {
                        Label(index == items.count - 1 ? "ADD TO CANVAS" : "ADD & NEXT", systemImage: "plus")
                            .monoLabel(10)
                            .foregroundStyle(BrandColor.archiveIvory)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(BrandColor.inkBlack, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                }
            }
            .padding(22)
        }
        .task(id: index) { await processCurrent() }
        .sheet(isPresented: $showsRefine) {
            if let cutout {
                LabManualRefineView(original: item.image, cutout: cutout) { refined in
                    self.cutout = refined
                    showsRefine = false
                }
            }
        }
    }

    private func processCurrent() async {
        isProcessing = true
        errorMessage = nil
        cutout = nil
        do {
            cutout = try await LabCutoutService.removeBackground(from: item.image)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    private func addCurrent() {
        let image = cutout ?? item.image
        completed.append(LabElement(
            type: .image,
            name: item.name,
            imageData: image.pngData(),
            detail: item.archiveLabel
        ))
        if index == items.count - 1 {
            onComplete(completed)
        } else {
            index += 1
        }
    }
}

private struct LabManualRefineView: View {
    let original: UIImage
    let cutout: UIImage
    let onDone: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var strokes: [LabMaskStroke] = []
    @State private var redoStrokes: [LabMaskStroke] = []
    @State private var activePoints: [CGPoint] = []
    @State private var mode: LabMaskMode = .erase
    @State private var brushSize = 0.035
    @State private var softness = 0.15
    @State private var preview: UIImage
    @State private var showsOriginal = false

    init(original: UIImage, cutout: UIImage, onDone: @escaping (UIImage) -> Void) {
        self.original = original
        self.cutout = cutout
        self.onDone = onDone
        _preview = State(initialValue: cutout)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                GeometryReader { proxy in
                    ZStack {
                        LabCheckerboard()
                        Image(uiImage: showsOriginal ? original : preview)
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)

                        Canvas { context, size in
                            guard activePoints.count > 1 else { return }
                            var path = Path()
                            path.move(to: CGPoint(x: activePoints[0].x * size.width, y: activePoints[0].y * size.height))
                            for point in activePoints.dropFirst() {
                                path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                            }
                            context.stroke(path, with: .color(mode == .erase ? .red : .green), style: StrokeStyle(lineWidth: brushSize * max(size.width, size.height), lineCap: .round))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                activePoints.append(CGPoint(
                                    x: min(1, max(0, value.location.x / proxy.size.width)),
                                    y: min(1, max(0, value.location.y / proxy.size.height))
                                ))
                            }
                            .onEnded { _ in
                                guard activePoints.count > 1 else { activePoints.removeAll(); return }
                                strokes.append(LabMaskStroke(mode: mode, points: activePoints, size: brushSize, softness: softness))
                                redoStrokes.removeAll()
                                activePoints.removeAll()
                                preview = LabMaskRenderer.render(original: original, cutout: cutout, strokes: strokes)
                            }
                    )
                }

                Picker("Mode", selection: $mode) {
                    ForEach(LabMaskMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 10) {
                    HStack { Text("SIZE").monoLabel(9); Slider(value: $brushSize, in: 0.008...0.12) }
                    HStack { Text("SOFTNESS").monoLabel(9); Slider(value: $softness, in: 0...1) }
                }

                HStack {
                    Button { showsOriginal.toggle() } label: { Label("BEFORE / AFTER", systemImage: "square.split.2x1") }
                    Spacer()
                    Button {
                        guard let last = strokes.popLast() else { return }
                        redoStrokes.append(last)
                        preview = LabMaskRenderer.render(original: original, cutout: cutout, strokes: strokes)
                    } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(strokes.isEmpty)
                    Button {
                        guard let stroke = redoStrokes.popLast() else { return }
                        strokes.append(stroke)
                        preview = LabMaskRenderer.render(original: original, cutout: cutout, strokes: strokes)
                    } label: { Image(systemName: "arrow.uturn.forward") }
                    .disabled(redoStrokes.isEmpty)
                    Button {
                        strokes.removeAll(); redoStrokes.removeAll(); preview = cutout
                    } label: { Image(systemName: "arrow.counterclockwise") }
                }
                .monoLabel(9)
            }
            .padding()
            .background(BrandColor.archiveIvory.ignoresSafeArea())
            .navigationTitle("Refine Cutout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { onDone(preview) } }
            }
        }
    }
}

private struct LabNavigationHeader: View {
    let title: String
    let onBack: () -> Void
    var body: some View {
        HStack {
            MonoBackButton(action: onBack)
            Spacer()
            Text(title).monoLabel(11, tracking: 1.1)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

private struct LabSectionHeader: View {
    let title: String
    let count: Int
    var body: some View {
        HStack {
            Text(title).monoLabel(10, tracking: 1.1)
            Spacer()
            Text(String(format: "%02d", count)).monoLabel(9).foregroundStyle(BrandColor.catalogGray)
        }
    }
}

private struct LabEmptyRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 20, weight: .light))
            Text(text).monoBody(13).foregroundStyle(BrandColor.catalogGray)
            Spacer()
        }
        .padding(18)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct LabProjectThumbnail: View {
    let project: LabProject
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabExportCanvasView(project: project, transparent: false)
                .frame(width: 150, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            Text(project.title).monoHeading(13).lineLimit(1)
            Text(project.format.rawValue).monoLabel(8).foregroundStyle(BrandColor.catalogGray)
        }
        .frame(width: 150, alignment: .leading)
    }
}

private struct LabCheckerboard: View {
    var body: some View {
        Canvas { context, size in
            let unit: CGFloat = 18
            for row in 0...Int(size.height / unit) {
                for column in 0...Int(size.width / unit) where (row + column).isMultiple(of: 2) {
                    var cell = Path()
                    cell.addRect(CGRect(x: CGFloat(column) * unit, y: CGFloat(row) * unit, width: unit, height: unit))
                    context.fill(cell, with: .color(BrandColor.inkBlack.opacity(0.055)))
                }
            }
        }
        .background(Color.white)
    }
}

private enum LabTemplateFactory {
    static var templates: [LabProject] {
        var archive = LabProject(title: "Archive Study", format: .portrait)
        archive.background.colorHex = 0xF3F0E9
        archive.elements = [
            LabElement(type: .text, name: "Title", text: "OBJECT STUDY", positionX: 0.5, positionY: 0.18, scale: 0.7),
            LabElement(type: .sticker, name: "Mark", symbolName: "circle.fill", positionX: 0.78, positionY: 0.72, scale: 0.3)
        ]

        var collected = LabProject(title: "Collected", format: .square)
        collected.background.colorHex = 0x171714
        collected.elements = [LabElement(type: .text, name: "Title", text: "COLLECTED", detail: "light", positionX: 0.5, positionY: 0.5, scale: 0.75)]

        var journal = LabProject(title: "Paper Journal", format: .story)
        journal.background.colorHex = 0xD5B99C
        journal.elements = [LabElement(type: .sticker, name: "Pin", symbolName: "mappin", positionX: 0.5, positionY: 0.22, scale: 0.32)]
        return [archive, collected, journal]
    }
}

private extension Color {
    var labUInt32: UInt32 {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (UInt32(r * 255) << 16) | (UInt32(g * 255) << 8) | UInt32(b * 255)
    }
}
