import SwiftUI

/// Vector recreation of the MONO display-cabinet mark. It stays sharp at every
/// device size and does not require a bundled logo bitmap.
struct MonoLogoView: View {
    var size: CGFloat = 148
    var archProgress: CGFloat = 1
    var objectProgress: CGFloat = 1
    var dotProgress: CGFloat = 1
    var showsWordmark = false

    var body: some View {
        HStack(spacing: size * 0.18) {
            ZStack {
                ArchShape()
                    .trim(from: 0, to: archProgress)
                    .stroke(
                        BrandColor.inkBlack,
                        style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round, lineJoin: .round)
                    )

                Capsule()
                    .fill(BrandColor.inkBlack)
                    .frame(width: size * 0.92, height: size * 0.055)
                    .offset(y: size * 0.42)
                    .scaleEffect(x: archProgress, anchor: .leading)

                RoundedRectangle(cornerRadius: size * 0.025)
                    .fill(BrandColor.collectedRed)
                    .frame(width: size * 0.21, height: size * 0.28)
                    .rotationEffect(.degrees(-5))
                    .offset(x: -size * 0.23, y: size * 0.23 + (1 - objectProgress) * size * 0.32)
                    .opacity(objectProgress)

                Circle()
                    .fill(BrandColor.inkBlack)
                    .frame(width: size * 0.30)
                    .offset(y: size * 0.20 + (1 - objectProgress) * size * 0.32)
                    .opacity(objectProgress)

                Triangle()
                    .fill(BrandColor.paperTan)
                    .frame(width: size * 0.20, height: size * 0.29)
                    .offset(x: size * 0.26, y: size * 0.22 + (1 - objectProgress) * size * 0.32)
                    .opacity(objectProgress)

                Circle()
                    .fill(BrandColor.collectedRed)
                    .frame(width: size * 0.085)
                    .offset(
                        x: size * 0.265 * dotProgress,
                        y: -size * 0.02 * dotProgress
                    )
                    .scaleEffect(0.72 + 0.28 * dotProgress)
                    .shadow(color: BrandColor.collectedRed.opacity(0.22), radius: 12 * (1 - dotProgress))
            }
            .frame(width: size, height: size)

            if showsWordmark {
                MonoWordmark(size: size * 0.47)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("MONO")
    }
}

struct MonoWordmark: View {
    var size: CGFloat = 64

    var body: some View {
        HStack(spacing: size * 0.05) {
            Text("mon")
                .font(.system(size: size, weight: .regular, design: .rounded))
                .tracking(-size * 0.055)
            Circle()
                .fill(BrandColor.collectedRed)
                .frame(width: size * 0.67, height: size * 0.67)
                .offset(y: size * 0.06)
        }
        .foregroundStyle(BrandColor.inkBlack)
        .fixedSize()
    }
}

private struct ArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.12
        let bottom = rect.height * 0.89
        var path = Path()
        path.move(to: CGPoint(x: inset, y: bottom))
        path.addLine(to: CGPoint(x: inset, y: rect.height * 0.35))
        path.addCurve(
            to: CGPoint(x: rect.width - inset, y: rect.height * 0.35),
            control1: CGPoint(x: inset, y: rect.height * 0.04),
            control2: CGPoint(x: rect.width - inset, y: rect.height * 0.04)
        )
        path.addLine(to: CGPoint(x: rect.width - inset, y: bottom))
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    MonoLogoView(size: 190, showsWordmark: true)
        .padding(40)
        .background(BrandColor.archiveIvory)
}
