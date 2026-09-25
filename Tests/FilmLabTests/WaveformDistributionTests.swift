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

  func testRGBChannelsKeepIndependentLevelsAndImagePosition() {
    let pixels: [UInt8] = [
      255, 0, 0, 255,
      0, 128, 255, 255,
    ]
    let red = WaveformDistribution.make(from: pixels, width: 2, height: 1, component: 0)
    let green = WaveformDistribution.make(from: pixels, width: 2, height: 1, component: 1)
    let blue = WaveformDistribution.make(from: pixels, width: 2, height: 1, component: 2)
    let columns = WaveformDistribution.columns
    XCTAssertEqual(red.intensities[63 * columns], 1)
    XCTAssertEqual(red.intensities[32], 1)
    XCTAssertEqual(green.intensities[0], 1)
    XCTAssertEqual(green.intensities[32 * columns + 32], 1)
    XCTAssertEqual(blue.intensities[0], 1)
    XCTAssertEqual(blue.intensities[63 * columns + 32], 1)
    XCTAssertEqual(red.intensities[63 * columns + 32], 0)
  }
}
