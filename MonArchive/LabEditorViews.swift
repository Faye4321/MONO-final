import PhotosUI
import SwiftUI
import UIKit

private enum LabEditorPanel: String, Identifiable {
    case add, layers, brush, palette, export, collection
    var id: String { rawValue }
}

struct LabEditorView: View {
    @StateObject private var store: LabEditorStore
    let collectionProvider: any LabCollectionProviding
    let onClose: () -> Void

    @State private var panel: LabEditorPanel?
    @State private var showSaved = false

    init(project: LabProject, collectionProvider: any LabCollectionProviding, onClose: @escaping () -> Void) {
        _store = StateObject(wrappedValue: LabEditorStore(project: project))
        self.collectionProvider = collectionProvider
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            GeometryReader { proxy in
                let available = CGSize(width: proxy.size.width - 28, height: proxy.size.height - 18)
                let canvasSize = fittedCanvas(in: available, ratio: store.project.format.aspectRatio)

                ZStack {
                    Color(hex: 0xD8D4CC)
                    LabCanvasSurface(store: store, canvasSize: canvasSize, interactive: true)
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
                }
            }
            editorToolbar
        }
        .background(BrandColor.archiveIvory.ignoresSafeArea())
        .sheet(item: $panel) { panel in
            switch panel {
            case .add:
                LabAddPanel(store: store)
                    .presentationDetents([.medium])
            case .layers:
                LabLayersPanel(store: store)
                    .presentationDetents([.medium, .large])
            case .brush:
                LabBrushPanel(store: store)
                    .presentationDetents([.height(330)])
            case .palette:
                LabPalettePanel(store: store)
                    .presentationDetents([.height(280)])
            case .export:
                LabExportPanel(store: store)
                    .presentationDetents([.medium, .large])
            case .collection:
                NavigationStack {
                    LabCollectionPickerView(provider: collectionProvider, onBack: { self.panel = nil }) { items in
                        Task { await addCollectionItems(items) }
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if showSaved {
                Text("DRAFT SAVED")
                    .monoLabel(10, tracking: 1)
                    .foregroundStyle(BrandColor.archiveIvory)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(BrandColor.inkBlack, in: Capsule())
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var editorHeader: some View {
        HStack(spacing: 14) {
            Button(action: onClose) { Image(systemName: "xmark") }
            Spacer()
            TextField("Untitled Collage", text: $store.project.title)
                .monoHeading(15)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                var draft = store.project
                if let preview = LabExportService.render(project: draft, transparent: false, scale: 1) {
                    draft.previewData = preview.jpegData(compressionQuality: 0.72)
                }
                LabDraftStore.save(draft)
                withAnimation { showSaved = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { withAnimation { showSaved = false } }
            } label: { Image(systemName: "square.and.arrow.down") }
        }
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(BrandColor.inkBlack)
        .padding(.horizontal, 20)
        .frame(height: 58)
    }

    private var editorToolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                toolButton("ADD", "plus", panel: .add)
                toolButton("OBJECTS", "rectangle.stack.badge.plus", panel: .collection)
                toolButton("LAYERS", "square.3.layers.3d", panel: .layers)
                toolButton("DRAW", "pencil.tip", panel: .brush)
                toolButton("COLOR", "paintpalette", panel: .palette)
                toolButton("EXPORT", "square.and.arrow.up", panel: .export)
            }
            HStack(spacing: 22) {
                Button { store.undo() } label: { Label("UNDO", systemImage: "arrow.uturn.backward") }
                    .disabled(!store.canUndo)
                Button { store.redo() } label: { Label("REDO", systemImage: "arrow.uturn.forward") }
                    .disabled(!store.canRedo)
                Button {
                    store.mutate { project in
                        LabRemixEngine.remix(&project.elements)
                    }
                } label: { Label("REMIX", systemImage: "shuffle") }
                if store.selectedElementID != nil {
                    Button(role: .destructive) { store.deleteSelected() } label: { Label("DELETE", systemImage: "trash") }
                }
            }
            .monoLabel(8, tracking: 0.5)
            .frame(height: 28)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 7)
        .background(.ultraThinMaterial)
    }

    private func toolButton(_ title: String, _ icon: String, panel: LabEditorPanel) -> some View {
        Button {
            store.isDrawing = false
            self.panel = panel
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18))
                Text(title).monoLabel(7, tracking: 0.2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
        .buttonStyle(.plain)
    }

    private func addCollectionItems(_ items: [LabCollectionItem]) async {
        for item in items {
            let output = (try? await LabCutoutService.removeBackground(from: item.image)) ?? item.image
            let element = LabElement(type: .image, name: item.name, imageData: output.pngData(), detail: item.archiveLabel)
            store.addElement(element)
        }
        store.project.palette = LabPaletteExtractor.colors(from: items.map(\.image))
        panel = nil
    }

    private func fittedCanvas(in available: CGSize, ratio: CGFloat) -> CGSize {
        let widthFromHeight = available.height * ratio
        if widthFromHeight <= available.width {
            return CGSize(width: widthFromHeight, height: available.height)
        }
        return CGSize(width: available.width, height: available.width / ratio)
    }
}

struct LabCanvasSurface: View {
    @ObservedObject var store: LabEditorStore
    let canvasSize: CGSize
    let interactive: Bool

    @State private var activeStroke: [CGPoint] = []

    var body: some View {
        ZStack {
            LabCanvasBackground(background: store.project.background)

            LabDrawingLayer(strokes: store.project.strokes, canvasSize: canvasSize)

            ForEach($store.project.elements) { $element in
                if !element.isHidden {
                    LabInteractiveElement(
                        element: $element,
                        canvasSize: canvasSize,
                        selected: store.selectedElementID == element.id,
                        interactive: interactive && !store.isDrawing,
                        store: store
                    )
                }
            }

            if interactive, store.selectedElementID != nil, !store.isDrawing {
                VStack {
                    Spacer()
                    Label("DRAG HERE TO DELETE", systemImage: "trash")
                        .monoLabel(8, tracking: 0.6)
                        .foregroundStyle(BrandColor.archiveIvory)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(BrandColor.collectedRed.opacity(0.92), in: Capsule())
                        .padding(.bottom, 8)
                }
                .allowsHitTesting(false)
            }

            if store.isDrawing {
                Canvas { context, size in
                    guard activeStroke.count > 1 else { return }
                    var path = Path()
                    path.move(to: activeStroke[0])
                    for point in activeStroke.dropFirst() { path.addLine(to: point) }
                    context.stroke(
                        path,
                        with: strokeShading,
                        style: StrokeStyle(lineWidth: store.brushSize, lineCap: .round, lineJoin: .round, dash: store.brushTool == .texture ? [3, 6] : [])
                    )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { activeStroke.append($0.location) }
                        .onEnded { _ in finishStroke() }
                )
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { if !store.isDrawing { store.selectedElementID = nil } }
    }

    private var strokeShading: GraphicsContext.Shading {
        .color(Color(labHex: store.brushColorHex).opacity(store.brushOpacity))
    }

    private func finishStroke() {
        guard activeStroke.count > 1 else { activeStroke.removeAll(); return }
        let points = activeStroke.map { LabPoint(x: Double($0.x / canvasSize.width), y: Double($0.y / canvasSize.height)) }
        let stroke = LabStroke(tool: store.brushTool, points: points, colorHex: store.brushColorHex, size: store.brushSize / canvasSize.width, opacity: store.brushOpacity)
        store.mutate { $0.strokes.append(stroke) }
        activeStroke.removeAll()
    }
}

private struct LabInteractiveElement: View {
    @Binding var element: LabElement
    let canvasSize: CGSize
    let selected: Bool
    let interactive: Bool
    @ObservedObject var store: LabEditorStore

    @State private var initialProject: LabProject?
    @State private var startPosition = CGPoint.zero
    @State private var startScale = 1.0
    @State private var startRotation = 0.0

    var body: some View {
        LabElementContent(element: element)
            .frame(width: max(54, canvasSize.width * CGFloat(element.scale)))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(BrandColor.collectedRed, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .padding(-5)
                        .allowsHitTesting(false)
                }
            }
            .opacity(element.opacity)
            .rotationEffect(.degrees(element.rotation))
            .position(x: CGFloat(element.positionX) * canvasSize.width, y: CGFloat(element.positionY) * canvasSize.height)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { if interactive { store.selectedElementID = element.id } }
            .onTapGesture { if interactive { store.selectedElementID = element.id } }
            .gesture(dragGesture, including: interactive && !element.isLocked ? .all : .none)
            .simultaneousGesture(scaleGesture, including: interactive && !element.isLocked ? .all : .none)
            .simultaneousGesture(rotationGesture, including: interactive && !element.isLocked ? .all : .none)
            .contextMenu {
                Button("Duplicate") { store.selectedElementID = element.id; store.duplicateSelected() }
                Button(element.isLocked ? "Unlock" : "Lock") { element.isLocked.toggle() }
                Button("Delete", role: .destructive) { store.selectedElementID = element.id; store.deleteSelected() }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                beginMutationIfNeeded()
                if startPosition == .zero { startPosition = CGPoint(x: CGFloat(element.positionX), y: CGFloat(element.positionY)) }
                element.positionX = Double(min(1, max(0, startPosition.x + value.translation.width / canvasSize.width)))
                element.positionY = Double(min(1, max(0, startPosition.y + value.translation.height / canvasSize.height)))
            }
            .onEnded { _ in
                let shouldDelete = element.positionY > 0.94
                let id = element.id
                endMutation()
                startPosition = .zero
                if shouldDelete {
                    store.selectedElementID = id
                    store.deleteSelected()
                }
            }
    }

    private var scaleGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                beginMutationIfNeeded()
                if startScale == 1 { startScale = element.scale }
                element.scale = min(1.8, max(0.12, startScale * Double(value)))
            }
            .onEnded { _ in endMutation(); startScale = 1 }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { value in
                beginMutationIfNeeded()
                if startRotation == 0 { startRotation = element.rotation }
                element.rotation = startRotation + value.degrees
            }
            .onEnded { _ in endMutation(); startRotation = 0 }
    }

    private func beginMutationIfNeeded() {
        if initialProject == nil { initialProject = store.snapshot() }
        store.selectedElementID = element.id
    }

    private func endMutation() {
        if let previous = initialProject { store.registerUndo(previous) }
        initialProject = nil
    }
}

struct LabElementContent: View {
    let element: LabElement

    var body: some View {
        Group {
            switch element.type {
            case .image:
                if let data = element.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit()
                } else { Image(systemName: "photo").resizable().scaledToFit() }
            case .text:
                Text(element.text)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(element.detail == "light" ? Color.white : BrandColor.inkBlack)
                    .fixedSize(horizontal: false, vertical: true)
            case .sticker:
                Image(systemName: element.symbolName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(BrandColor.collectedRed)
                    .padding(8)
            case .archiveLabel:
                VStack(alignment: .leading, spacing: 5) {
                    Text("MONO ARCHIVE").monoLabel(8).foregroundStyle(BrandColor.collectedRed)
                    Text(element.text).monoBody(11).lineLimit(4)
                }
                .padding(12)
                .background(BrandColor.archiveIvory.opacity(0.94))
                .overlay { Rectangle().stroke(BrandColor.inkBlack, lineWidth: 1) }
            }
        }
    }
}

struct LabCanvasBackground: View {
    let background: LabBackground
    var body: some View {
        ZStack {
            if background.kind == .transparent {
                LabTransparentGrid()
            } else if background.kind == .photo, let data = background.imageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color(labHex: background.colorHex)
            }
        }
        .clipped()
    }
}

private struct LabDrawingLayer: View {
    let strokes: [LabStroke]
    let canvasSize: CGSize
    var body: some View {
        Canvas { context, size in
            for stroke in strokes where stroke.points.count > 1 {
                var path = Path()
                path.move(to: CGPoint(x: CGFloat(stroke.points[0].x) * size.width, y: CGFloat(stroke.points[0].y) * size.height))
                for point in stroke.points.dropFirst() { path.addLine(to: CGPoint(x: CGFloat(point.x) * size.width, y: CGFloat(point.y) * size.height)) }
                context.stroke(
                    path,
                    with: .color(Color(labHex: stroke.colorHex).opacity(stroke.opacity)),
                    style: StrokeStyle(lineWidth: CGFloat(stroke.size) * size.width, lineCap: .round, lineJoin: .round, dash: stroke.tool == .texture ? [3, 6] : [])
                )
            }
        }
    }
}

private struct LabTransparentGrid: View {
    var body: some View {
        Canvas { context, size in
            let unit: CGFloat = 16
            var background = Path()
            background.addRect(CGRect(origin: .zero, size: size))
            context.fill(background, with: .color(.white))
            for row in 0...Int(size.height / unit) {
                for col in 0...Int(size.width / unit) where (row + col).isMultiple(of: 2) {
                    var path = Path()
                    path.addRect(CGRect(x: CGFloat(col) * unit, y: CGFloat(row) * unit, width: unit, height: unit))
                    context.fill(path, with: .color(.gray.opacity(0.14)))
                }
            }
        }
    }
}

struct LabExportCanvasView: View {
    let project: LabProject
    let transparent: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if !transparent { LabCanvasBackground(background: project.background) }
                LabDrawingLayer(strokes: project.strokes, canvasSize: proxy.size)
                ForEach(project.elements) { element in
                    if !element.isHidden {
                        LabElementContent(element: element)
                            .frame(width: max(54, proxy.size.width * CGFloat(element.scale)))
                            .opacity(element.opacity)
                            .rotationEffect(.degrees(element.rotation))
                            .position(x: CGFloat(element.positionX) * proxy.size.width, y: CGFloat(element.positionY) * proxy.size.height)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

private struct LabAddPanel: View {
    @ObservedObject var store: LabEditorStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = "YOUR TEXT"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    TextField("Write something", text: $text)
                        .monoBody(16)
                        .padding(15)
                        .background(BrandColor.softCard, in: RoundedRectangle(cornerRadius: 14))
                    Button("ADD TEXT") {
                        store.addElement(LabElement(type: .text, name: "Text", text: text, scale: 0.55))
                        dismiss()
                    }.buttonStyle(LabPanelButtonStyle())

                    Text("ARCHIVE TOOLS").monoLabel().foregroundStyle(BrandColor.catalogGray)
                    Button("SMART ARCHIVE LABEL") {
                        let detail = store.project.elements.first(where: { !$0.detail.isEmpty })?.detail ?? "MONO · OBJECT · UNDATED"
                        store.addElement(LabElement(type: .archiveLabel, name: "Archive Label", text: detail, scale: 0.58))
                        dismiss()
                    }.buttonStyle(LabPanelButtonStyle())

                    Text("DECORATIONS").monoLabel().foregroundStyle(BrandColor.catalogGray)
                    HStack {
                        ForEach(["mappin", "paperclip", "calendar", "tag", "sparkles"], id: \.self) { symbol in
                            Button {
                                store.addElement(LabElement(type: .sticker, name: symbol, symbolName: symbol, scale: 0.25))
                                dismiss()
                            } label: {
                                Image(systemName: symbol).font(.system(size: 25)).frame(maxWidth: .infinity).frame(height: 54)
                                    .background(BrandColor.softCard, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Add to Canvas")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct LabLayersPanel: View {
    @ObservedObject var store: LabEditorStore
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(store.project.elements.enumerated()).reversed(), id: \.element.id) { index, element in
                    HStack {
                        Image(systemName: icon(for: element.type)).frame(width: 26)
                        VStack(alignment: .leading) {
                            Text(element.name).monoHeading(14)
                            Text(element.type.rawValue.uppercased()).monoLabel(8).foregroundStyle(BrandColor.catalogGray)
                        }
                        Spacer()
                        Button { store.project.elements[index].isHidden.toggle() } label: {
                            Image(systemName: element.isHidden ? "eye.slash" : "eye")
                        }
                        Button { store.project.elements[index].isLocked.toggle() } label: {
                            Image(systemName: element.isLocked ? "lock.fill" : "lock.open")
                        }
                        Menu {
                            Button("Move Forward") { move(index, by: 1) }
                            Button("Move Backward") { move(index, by: -1) }
                            Button("Duplicate") { store.selectedElementID = element.id; store.duplicateSelected() }
                            Button("Delete", role: .destructive) { store.selectedElementID = element.id; store.deleteSelected() }
                        } label: { Image(systemName: "ellipsis") }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { store.selectedElementID = element.id }
                }

                if let id = store.selectedElementID,
                   let selectedIndex = store.project.elements.firstIndex(where: { $0.id == id }) {
                    Section("Selected layer") {
                        LabLayerSlider(
                            title: "Opacity",
                            value: binding(for: selectedIndex, keyPath: \.opacity),
                            range: 0.05...1
                        )
                        LabLayerSlider(
                            title: "Scale",
                            value: binding(for: selectedIndex, keyPath: \.scale),
                            range: 0.12...1.8
                        )
                        LabLayerSlider(
                            title: "Rotation",
                            value: binding(for: selectedIndex, keyPath: \.rotation),
                            range: -180...180
                        )
                    }
                }
            }
            .navigationTitle("Layers")
        }
    }

    private func icon(for type: LabElementType) -> String {
        switch type { case .image: return "photo"; case .text: return "textformat"; case .sticker: return "seal"; case .archiveLabel: return "tag" }
    }

    private func move(_ index: Int, by offset: Int) {
        let target = min(store.project.elements.count - 1, max(0, index + offset))
        guard target != index else { return }
        store.mutate { project in
            let item = project.elements.remove(at: index)
            project.elements.insert(item, at: target)
        }
    }

    private func binding(for index: Int, keyPath: WritableKeyPath<LabElement, Double>) -> Binding<Double> {
        Binding(
            get: { store.project.elements[index][keyPath: keyPath] },
            set: { store.project.elements[index][keyPath: keyPath] = $0 }
        )
    }
}

private struct LabLayerSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text(title).monoBody(13).frame(width: 70, alignment: .leading)
            Slider(value: $value, in: range)
            Text(value.formatted(.number.precision(.fractionLength(1))))
                .monoLabel(8)
                .frame(width: 34, alignment: .trailing)
        }
    }
}

private struct LabBrushPanel: View {
    @ObservedObject var store: LabEditorStore
    @Environment(\.dismiss) private var dismiss
    @State private var color = Color(labHex: 0x171714)

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Brush", selection: $store.brushTool) {
                    ForEach(LabBrushTool.allCases) { tool in Label(tool.rawValue, systemImage: tool.icon).tag(tool) }
                }
                .pickerStyle(.segmented)
                HStack { Text("SIZE").monoLabel(9); Slider(value: $store.brushSize, in: 1...32) }
                HStack { Text("OPACITY").monoLabel(9); Slider(value: $store.brushOpacity, in: 0.1...1) }
                HStack {
                    Text("COLOR").monoLabel(9)
                    Spacer()
                    ColorPicker("Brush Color", selection: $color, supportsOpacity: false).labelsHidden()
                }
                MonoPrimaryButton(title: "DRAW ON CANVAS") {
                    store.brushColorHex = color.labUInt32
                    store.isDrawing = true
                    dismiss()
                }
            }
            .padding(20)
            .navigationTitle("Brush & Texture")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct LabPalettePanel: View {
    @ObservedObject var store: LabEditorStore
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Text("COLORS EXTRACTED FROM YOUR COLLECTION")
                    .monoLabel(10, tracking: 1)
                    .foregroundStyle(BrandColor.catalogGray)
                HStack(spacing: 14) {
                    ForEach(store.project.palette, id: \.self) { hex in
                        Button {
                            store.mutate { $0.background = LabBackground(kind: .solid, colorHex: hex) }
                        } label: {
                            Circle().fill(Color(labHex: hex)).frame(width: 54, height: 54)
                                .overlay { Circle().stroke(BrandColor.inkBlack.opacity(0.15)) }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Tap a color to apply it to the background. Palette colors can also be selected in the brush tool.")
                    .monoBody(13).foregroundStyle(BrandColor.catalogGray)
                Spacer()
            }
            .padding(22)
            .navigationTitle("Collection Palette")
        }
    }
}

private struct LabExportPanel: View {
    @ObservedObject var store: LabEditorStore
    @State private var transparent = false
    @State private var format = "PNG"
    @State private var output: UIImage?
    @State private var shareItems: [Any] = []
    @State private var showsShare = false
    @State private var status: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Format", selection: $format) {
                        Text("PNG").tag("PNG")
                        Text("JPG").tag("JPG")
                    }.pickerStyle(.segmented)
                    Toggle("Transparent background", isOn: $transparent)
                        .disabled(format == "JPG")
                    LabExportCanvasView(project: store.project, transparent: transparent)
                        .aspectRatio(store.project.format.aspectRatio, contentMode: .fit)
                        .frame(maxHeight: 330)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                    HStack(spacing: 10) {
                        exportButton("SAVE", "square.and.arrow.down") { save() }
                        exportButton("COPY", "doc.on.doc") { copy() }
                        exportButton("SHARE", "square.and.arrow.up") { share() }
                    }
                    if let status { Text(status).monoBody(12).foregroundStyle(BrandColor.catalogGray) }
                }
                .padding(20)
            }
            .navigationTitle("Export & Share")
            .sheet(isPresented: $showsShare) { LabShareSheet(items: shareItems) }
        }
    }

    private func exportButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).monoLabel(9).frame(maxWidth: .infinity).frame(height: 50)
                .background(BrandColor.inkBlack, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(BrandColor.archiveIvory)
        }.buttonStyle(.plain)
    }

    private func rendered() -> UIImage? {
        let shouldBeTransparent = transparent && format == "PNG"
        return LabExportService.render(project: store.project, transparent: shouldBeTransparent)
    }

    private func save() {
        guard let image = rendered() else { status = "Export failed."; return }
        LabExportService.saveToPhotos(image) { status = $0 ? "Saved to Photos." : "Photo access was not granted." }
    }

    private func copy() {
        guard let image = rendered() else { status = "Export failed."; return }
        UIPasteboard.general.image = image
        status = "Copied to clipboard."
    }

    private func share() {
        guard let image = rendered() else { status = "Export failed."; return }
        if let file = LabExportService.temporaryFile(for: image, format: format) {
            shareItems = [file]
        } else {
            shareItems = [image]
        }
        showsShare = true
    }
}

private struct LabPanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .monoLabel(10)
            .foregroundStyle(BrandColor.archiveIvory)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(BrandColor.inkBlack.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
}

private extension Color {
    var labUInt32: UInt32 {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (UInt32(red * 255) << 16) | (UInt32(green * 255) << 8) | UInt32(blue * 255)
    }
}
