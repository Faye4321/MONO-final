import SwiftUI

struct ArtworkView: View {
    let item: CollectibleItem

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let uiImage = item.uploadedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .brightness(item.brightness)
                        .contrast(item.contrast)
                        .saturation(item.saturation)
                } else if let imageName = item.imageName, UIImage(named: imageName) != nil {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                } else {
                    generatedArtwork
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }

    private var generatedArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: item.colorA), Color(hex: item.colorB)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: 70, height: 70)
                .offset(x: 28, y: -26)

            RoundedRectangle(cornerRadius: 2)
                .fill(ArchiveTheme.ink.opacity(0.2))
                .frame(width: 42, height: 85)
                .rotationEffect(.degrees(28))
                .offset(x: -35, y: 35)

            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                Text(item.title.uppercased())
                    .font(ArchiveTheme.heading(11))
                    .lineLimit(2)
                Text(item.creator.uppercased())
                    .font(ArchiveTheme.label(7))
                    .opacity(0.72)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
        .clipped()
    }
}
