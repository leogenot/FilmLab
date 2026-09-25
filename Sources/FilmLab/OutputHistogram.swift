import SwiftUI

/// Distribution of the current sRGB preview, from displayed black to white.
struct OutputHistogram: View {
  let bins: [Double]
  let redBins: [Double]
  let greenBins: [Double]
  let blueBins: [Double]
  let blackFraction: Double
  let whiteFraction: Double
  let redNearWhiteFraction: Double
  let greenNearWhiteFraction: Double
  let blueNearWhiteFraction: Double
  let outsideSRGBFraction: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        Text("OUTPUT HISTOGRAM")
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
        context.fill(path, with: .color(.white.opacity(0.22)))
        for (channel, color) in [
          (redBins, Color.red), (greenBins, Color.green), (blueBins, Color.blue),
        ] where channel.count == bins.count {
          var line = Path()
          for index in channel.indices {
            let x = CGFloat(index) / CGFloat(channel.count - 1) * size.width
            let y = size.height * (1 - CGFloat(channel[index]))
            if index == 0 {
              line.move(to: CGPoint(x: x, y: y))
            } else {
              line.addLine(to: CGPoint(x: x, y: y))
            }
          }
          context.stroke(line, with: .color(color.opacity(0.75)), lineWidth: 1)
        }
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
      HStack(spacing: 12) {
        Text("Channel near white")
        Spacer()
        Text("R \(redNearWhiteFraction.formatted(.percent.precision(.fractionLength(1))))")
          .foregroundStyle(.red.opacity(0.85))
        Text("G \(greenNearWhiteFraction.formatted(.percent.precision(.fractionLength(1))))")
          .foregroundStyle(.green.opacity(0.85))
        Text("B \(blueNearWhiteFraction.formatted(.percent.precision(.fractionLength(1))))")
          .foregroundStyle(.blue.opacity(0.85))
      }
      .font(.caption2)
      Text(
        "Outside sRGB before output: \(outsideSRGBFraction.formatted(.percent.precision(.fractionLength(1))))"
      )
      .font(.caption2)
      .foregroundStyle(.secondary)
    }
  }
}
