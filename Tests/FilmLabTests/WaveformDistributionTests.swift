import XCTest

@testable import FilmLab

final class WaveformDistributionTests: XCTestCase {
  func testLuminanceTracksHorizontalPosition() {
    let pixels: [UInt8] = [
      0, 0, 0, 255,
      70, 70, 70, 255,
      130, 130, 130, 255,
      255, 255, 255, 255,
    ]
    let waveform = WaveformDistribution.make(from: pixels, width: 4, height: 1)
    let columns = WaveformDistribution.columns
    XCTAssertEqual(waveform.intensities.count, columns * WaveformDistribution.levels)
    XCTAssertEqual(waveform.intensities[0], 1)
    XCTAssertEqual(waveform.intensities[17 * columns + 16], 1)
    XCTAssertEqual(waveform.intensities[32 * columns + 32], 1)
    XCTAssertEqual(waveform.intensities[63 * columns + 48], 1)
    XCTAssertEqual(waveform.intensities[63 * columns], 0)
  }

  func testInvalidBufferProducesEmptyDistribution() {
    let waveform = WaveformDistribution.make(from: [], width: 4, height: 1)
    XCTAssertTrue(waveform.intensities.allSatisfy { $0 == 0 })
  }
}
