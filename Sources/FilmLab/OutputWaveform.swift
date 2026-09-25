import SwiftUI

/// Display-space luminance by horizontal position in the developed photo.
struct OutputWaveform: View {
  let distribution: WaveformDistribution

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        Text("OUTPUT WAVEFORM")
          .tracking(1)
        Spacer()
        Text("sRGB")
      }
      .font(.caption2.weight(.medium))
      .foregroundStyle(.secondary)
      Canvas { context, size in
        let columns = WaveformDistribution.columns
        let levels = WaveformDistribution.levels
        guard distribution.intensities.count == columns * levels else { return }
        for step in 1..<4 {
          let y = size.height * CGFloat(step) / 4
          var line = Path()
          line.move(to: CGPoint(x: 0, y: y))
          line.addLine(to: CGPoint(x: size.width, y: y))
          context.stroke(line, with: .color(.white.opacity(0.12)), lineWidth: 0.5)
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
            context.fill(Path(cell), with: .color(.white.opacity(0.12 + intensity * 0.8)))
          }
        }
      }
      .frame(height: 112)
      .background(Color.white.opacity(0.05))
      .clipShape(RoundedRectangle(cornerRadius: 5))
      HStack {
        Text("Black ↓ · White ↑")
        Spacer()
        Text("Image left → right")
      }
      .font(.caption2)
      .foregroundStyle(.secondary)
    }
  }
}
