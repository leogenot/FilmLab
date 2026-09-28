import SwiftUI

/// Display-space luma by horizontal position in the developed photo.
struct OutputWaveform: View {
  let distribution: WaveformDistribution
  let displayP3: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      scopeHeading("OUTPUT WAVEFORM", displayP3: displayP3)
      WaveformCanvas(distribution: distribution, color: .primary)
        .frame(height: 112)
      scopeAxis
    }
  }
}

/// Three display-space color channels, each using the full image width.
struct OutputRGBParade: View {
  let red: WaveformDistribution
  let green: WaveformDistribution
  let blue: WaveformDistribution
  let displayP3: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      scopeHeading("OUTPUT RGB PARADE", displayP3: displayP3)
      HStack(spacing: 3) {
        channel("R", distribution: red, color: .red)
        channel("G", distribution: green, color: .green)
        channel("B", distribution: blue, color: .blue)
      }
      scopeAxis
    }
  }

  private func channel(_ label: String, distribution: WaveformDistribution, color: Color)
    -> some View
  {
    VStack(spacing: 3) {
      WaveformCanvas(distribution: distribution, color: color)
        .frame(height: 112)
      Text(label)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity)
  }
}

private struct WaveformCanvas: View {
  let distribution: WaveformDistribution
  let color: Color

  var body: some View {
    Canvas { context, size in
      let columns = WaveformDistribution.columns
      let levels = WaveformDistribution.levels
      guard distribution.intensities.count == columns * levels else { return }
      for step in 1..<4 {
        let y = size.height * CGFloat(step) / 4
        var line = Path()
        line.move(to: CGPoint(x: 0, y: y))
        line.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(line, with: .color(.primary.opacity(0.12)), lineWidth: 0.5)
      }
      let cellWidth = size.width / CGFloat(columns)
      let cellHeight = size.height / CGFloat(levels)
      for level in 0..<levels {
        for column in 0..<columns {
          let intensity = distribution.intensities[level * columns + column]
          guard intensity > 0 else { continue }
          let cell = CGRect(
            x: CGFloat(column) * cellWidth,
            y: size.height - CGFloat(level + 1) * cellHeight,
            width: cellWidth + 0.5,
            height: cellHeight + 0.5)
          context.fill(Path(cell), with: .color(color.opacity(0.12 + intensity * 0.8)))
        }
      }
    }
    .background(Color.primary.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: 5))
  }
}

private func scopeHeading(_ title: String, displayP3: Bool) -> some View {
  HStack {
    Text(title).tracking(1)
    Spacer()
    Text(displayP3 ? "Display P3" : "sRGB")
  }
  .font(.caption2.weight(.medium))
  .foregroundStyle(.secondary)
}

private var scopeAxis: some View {
  HStack {
    Text("Black ↓ · White ↑")
    Spacer()
    Text("Image left → right")
  }
  .font(.caption2)
  .foregroundStyle(.secondary)
}
