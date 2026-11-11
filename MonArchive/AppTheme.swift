import SwiftUI

enum ArchiveTheme {
    // Replace this single name after the licensed Natom Pro font file is added.
    static let fontFamily = "Avenir Next"

    static let ivory = Color(hex: "F3F0E9")
    static let ink = Color(hex: "171714")
    static let collectedRed = Color(hex: "B84631")
    static let paperTan = Color(hex: "D5B99C")
    static let catalogGray = Color(hex: "706B63")
    static let cabinet = Color(hex: "262624")

    static func display(_ size: CGFloat) -> Font {
        .custom(fontFamily, fixedSize: size).weight(.medium)
    }

    static func heading(_ size: CGFloat) -> Font {
        .custom(fontFamily, fixedSize: size).weight(.semibold)
    }

    static func body(_ size: CGFloat) -> Font {
        .custom(fontFamily, fixedSize: size)
    }

    static func label(_ size: CGFloat) -> Font {
        .custom(fontFamily, fixedSize: size).weight(.medium)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
