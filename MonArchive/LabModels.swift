import Foundation
import SwiftUI
import UIKit

enum LabCanvasFormat: String, CaseIterable, Codable, Identifiable {
    case square = "1:1"
    case portrait = "4:5"
    case story = "9:16"
    case wallpaper = "WALLPAPER"
    case freeform = "FREEFORM"

    var id: Self { self }

    var title: String {
        switch self {
        case .square: return "Instagram Post"
        case .portrait: return "Instagram Portrait"
        case .story: return "Story / Reels Cover"
        case .wallpaper: return "Phone Wallpaper"
        case .freeform: return "Freeform"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .square: return 1
        case .portrait: return 4 / 5
        case .story: return 9 / 16
        case .wallpaper: return 9 / 19.5
        case .freeform: return 3 / 4
        }
    }
}

enum LabBackgroundKind: String, Codable, CaseIterable {
    case solid
    case photo
    case transparent
}

struct LabBackground: Codable, Equatable {
    var kind: LabBackgroundKind = .solid
    var colorHex: UInt32 = 0xF3F0E9
    var imageData: Data?
}

enum LabElementType: String, Codable {
    case image
    case text
    case sticker
    case archiveLabel
}

struct LabElement: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: LabElementType
    var name: String
    var imageData: Data?
    var text: String = ""
    var symbolName: String = "sparkles"
    var detail: String = ""
    var positionX: Double = 0.5
    var positionY: Double = 0.5
    var scale: Double = 0.65
    var rotation: Double = 0
    var opacity: Double = 1
    var isHidden = false
    var isLocked = false

    init(
        id: UUID = UUID(),
        type: LabElementType,
        name: String,
        imageData: Data? = nil,
        text: String = "",
        symbolName: String = "sparkles",
        detail: String = "",
        positionX: Double = 0.5,
        positionY: Double = 0.5,
        scale: Double = 0.65,
        rotation: Double = 0,
        opacity: Double = 1,
        isHidden: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.imageData = imageData
        self.text = text
        self.symbolName = symbolName
        self.detail = detail
        self.positionX = positionX
        self.positionY = positionY
        self.scale = scale
        self.rotation = rotation
        self.opacity = opacity
        self.isHidden = isHidden
        self.isLocked = isLocked
    }
}

enum LabBrushTool: String, Codable, CaseIterable, Identifiable {
    case pencil = "PENCIL"
    case marker = "MARKER"
    case texture = "TEXTURE"

    var id: Self { self }
    var icon: String {
        switch self {
        case .pencil: return "pencil.tip"
        case .marker: return "highlighter"
        case .texture: return "scribble.variable"
        }
    }
}

struct LabPoint: Codable, Equatable {
    var x: Double
    var y: Double
}

struct LabStroke: Identifiable, Codable, Equatable {
    var id = UUID()
    var tool: LabBrushTool
    var points: [LabPoint]
    var colorHex: UInt32
    var size: Double
    var opacity: Double
}

struct LabProject: Identifiable, Codable, Equatable {
    var id = UUID()
    var title = "Untitled Collage"
    var createdAt = Date()
    var updatedAt = Date()
    var format: LabCanvasFormat = .portrait
    var background = LabBackground()
    var elements: [LabElement] = []
    var strokes: [LabStroke] = []
    var palette: [UInt32] = [0xB84631, 0x171714, 0xD5B99C, 0x706B63]
    var previewData: Data?

    init(
        id: UUID = UUID(),
        title: String = "Untitled Collage",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        format: LabCanvasFormat = .portrait,
        background: LabBackground = LabBackground(),
        elements: [LabElement] = [],
        strokes: [LabStroke] = [],
        palette: [UInt32] = [0xB84631, 0x171714, 0xD5B99C, 0x706B63],
        previewData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.format = format
        self.background = background
        self.elements = elements
        self.strokes = strokes
        self.palette = palette
        self.previewData = previewData
    }
}

struct LabCollectionItem: Identifiable {
    let id: UUID
    let name: String
    let maker: String
    let year: String
    let category: String
    let image: UIImage

    init(id: UUID = UUID(), name: String, maker: String, year: String, category: String, image: UIImage) {
        self.id = id
        self.name = name
        self.maker = maker
        self.year = year
        self.category = category
        self.image = image
    }

    var archiveLabel: String {
        [maker.uppercased(), name.uppercased(), year, category.uppercased()]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

protocol LabCollectionProviding {
    func fetchCollectionItems() async -> [LabCollectionItem]
}

struct SampleLabCollectionProvider: LabCollectionProviding {
    func fetchCollectionItems() async -> [LabCollectionItem] {
        [
            makeItem("Suiseiseki", maker: "VOLKS", year: "2007", category: "BJD", symbol: "person.crop.circle", color: 0xB84631),
            makeItem("Blue Hour", maker: "MIRA VALE", year: "1987", category: "VINYL", symbol: "record.circle", color: 0x536D78),
            makeItem("Moon Garden", maker: "M. ITO", year: "2021", category: "POSTER", symbol: "moon.stars", color: 0x56746E),
            makeItem("Youth 02", maker: "BLUE ROOM", year: "2024", category: "PHOTOCARD", symbol: "rectangle.portrait", color: 0xA68E9A),
            makeItem("Heliot", maker: "SOOM", year: "2008", category: "BJD", symbol: "sparkles", color: 0x8A7B68)
        ]
    }

    private func makeItem(_ name: String, maker: String, year: String, category: String, symbol: String, color: UInt32) -> LabCollectionItem {
        let size = CGSize(width: 900, height: 1100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(red: 0.95, green: 0.93, blue: 0.89, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let tint = UIColor(
                red: CGFloat((color >> 16) & 0xFF) / 255,
                green: CGFloat((color >> 8) & 0xFF) / 255,
                blue: CGFloat(color & 0xFF) / 255,
                alpha: 1
            )
            tint.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 125, y: 160, width: 650, height: 650))

            if let icon = UIImage(systemName: symbol)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                icon.draw(in: CGRect(x: 270, y: 300, width: 360, height: 360))
            }
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            name.uppercased().draw(
                in: CGRect(x: 70, y: 885, width: 760, height: 100),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 50, weight: .semibold),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: style
                ]
            )
        }
        return LabCollectionItem(name: name, maker: maker, year: year, category: category, image: image)
    }
}

@MainActor
final class LabEditorStore: ObservableObject {
    @Published var project: LabProject
    @Published var selectedElementID: UUID?
    @Published var isDrawing = false
    @Published var brushTool: LabBrushTool = .pencil
    @Published var brushColorHex: UInt32 = 0x171714
    @Published var brushSize = 8.0
    @Published var brushOpacity = 1.0

    private var undoStack: [LabProject] = []
    private var redoStack: [LabProject] = []

    init(project: LabProject) {
        self.project = project
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func snapshot() -> LabProject { project }

    func registerUndo(_ previous: LabProject) {
        guard previous != project else { return }
        undoStack.append(previous)
        if undoStack.count > 40 { undoStack.removeFirst() }
        redoStack.removeAll()
        project.updatedAt = Date()
    }

    func mutate(_ action: (inout LabProject) -> Void) {
        let previous = project
        action(&project)
        registerUndo(previous)
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(project)
        project = previous
        selectedElementID = nil
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(project)
        project = next
        selectedElementID = nil
    }

    func addElement(_ element: LabElement) {
        mutate { $0.elements.append(element) }
        selectedElementID = element.id
    }

    func deleteSelected() {
        guard let id = selectedElementID else { return }
        mutate { $0.elements.removeAll { $0.id == id } }
        selectedElementID = nil
    }

    func duplicateSelected() {
        guard let id = selectedElementID, var copy = project.elements.first(where: { $0.id == id }) else { return }
        copy.id = UUID()
        copy.positionX = min(0.92, copy.positionX + 0.06)
        copy.positionY = min(0.92, copy.positionY + 0.06)
        addElement(copy)
    }
}

enum LabDraftStore {
    static func load() -> [LabProject] {
        guard let data = try? Data(contentsOf: fileURL),
              let projects = try? JSONDecoder().decode([LabProject].self, from: data) else { return [] }
        return projects.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func save(_ project: LabProject) {
        var projects = load().filter { $0.id != project.id }
        projects.insert(project, at: 0)
        projects = Array(projects.prefix(12))
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func delete(_ id: UUID) {
        let projects = load().filter { $0.id != id }
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("mono-lab-drafts.json")
    }
}

enum LabRemixEngine {
    static func remix(_ elements: inout [LabElement]) {
        let layouts: [(Double, Double, Double, Double)] = [
            (0.34, 0.34, 0.54, -8),
            (0.68, 0.42, 0.48, 7),
            (0.43, 0.69, 0.44, 4),
            (0.73, 0.72, 0.36, -11),
            (0.22, 0.72, 0.31, 10)
        ]
        for index in elements.indices {
            let layout = layouts[index % layouts.count]
            elements[index].positionX = layout.0
            elements[index].positionY = layout.1
            elements[index].scale = layout.2
            elements[index].rotation = layout.3
        }
    }
}

enum LabPaletteExtractor {
    static func colors(from images: [UIImage], count: Int = 5) -> [UInt32] {
        var buckets: [UInt32: Int] = [:]
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            let width = 28, height = 28, bytesPerPixel = 4
            var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
            guard let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * bytesPerPixel,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            for index in stride(from: 0, to: pixels.count, by: 16) {
                let r = pixels[index], g = pixels[index + 1], b = pixels[index + 2], a = pixels[index + 3]
                guard a > 100 else { continue }
                let brightness = (Int(r) + Int(g) + Int(b)) / 3
                guard brightness > 28 && brightness < 238 else { continue }
                let qr = UInt32(r / 32 * 32), qg = UInt32(g / 32 * 32), qb = UInt32(b / 32 * 32)
                let hex = (qr << 16) | (qg << 8) | qb
                buckets[hex, default: 0] += 1
            }
        }
        let result = buckets.sorted { $0.value > $1.value }.prefix(count).map(\.key)
        return result.isEmpty ? [0xB84631, 0x171714, 0xD5B99C, 0x706B63] : result
    }
}

extension Color {
    init(labHex: UInt32) {
        self.init(hex: UInt(labHex))
    }
}
