import SwiftUI

/// Distribution of the current sRGB preview, from displayed black to white.
struct OutputHistogram: View {
  let bins: [Double]
  let blackFraction: Double
  let whiteFraction: Double
  let outsideSRGBFraction: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        Text("OUTPUT LUMINANCE")
          .tracking(1)
        Spacer()
        Text("sRGB")
      }
      .font(.caption2.weight(.medium))
      .foregroundStyle(.secondary)
      Canvas { context, size in
        guard bins.count > 1 else { return }
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        for index in bins.indices {
          let x = CGFloat(index) / CGFloat(bins.count - 1) * size.width
          let y = size.height * (1 - CGFloat(bins[index]))
          path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        context.fill(path, with: .color(.white.opacity(0.55)))
      }
      .frame(height: 68)
      .background(Color.white.opacity(0.05))
      .clipShape(RoundedRectangle(cornerRadius: 5))
      HStack {
        Text("Near black \(blackFraction.formatted(.percent.precision(.fractionLength(1))))")
        Spacer()
        Text("Near white \(whiteFraction.formatted(.percent.precision(.fractionLength(1))))")
      }
      .font(.caption2)
      .foregroundStyle(.secondary)
      Text(
        "Outside sRGB before output: \(outsideSRGBFraction.formatted(.percent.precision(.fractionLength(1))))"
      )
      .font(.caption2)
      .foregroundStyle(.secondary)
    }
  }
}
