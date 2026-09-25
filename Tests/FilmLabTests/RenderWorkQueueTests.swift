import XCTest

@testable import FilmLab

private actor RenderCounts {
  private(set) var starts: [Int: Int] = [:]
  private(set) var active = 0
  private(set) var peak = 0

  func started(_ key: Int) {
    starts[key, default: 0] += 1
    active += 1
    peak = max(peak, active)
  }

  func finished() { active -= 1 }
}

final class RenderWorkQueueTests: XCTestCase {
  func testSharesRequestsAndBoundsConcurrency() async {
    let counts = RenderCounts()
    let queue = RenderWorkQueue<Int, Int>(maxConcurrent: 2) { key in
      await counts.started(key)
      try? await Task.sleep(for: .milliseconds(100))
      await counts.finished()
      return key * 2
    }
    let first = Task { await queue.value(for: 1) }
    let duplicate = Task { await queue.value(for: 1) }
    let second = Task { await queue.value(for: 2) }
    let third = Task { await queue.value(for: 3) }
    let values = await [first.value, duplicate.value, second.value, third.value]
    let firstStarts = await counts.starts[1]
    let peak = await counts.peak
    XCTAssertEqual(values, [2, 2, 4, 6])
    XCTAssertEqual(firstStarts, 1)
    XCTAssertLessThanOrEqual(peak, 2)
  }

  func testCancelledPendingRequestNeverStarts() async {
    let counts = RenderCounts()
    let queue = RenderWorkQueue<Int, Int>(maxConcurrent: 1) { key in
      await counts.started(key)
      try? await Task.sleep(for: .milliseconds(200))
      await counts.finished()
      return key
    }
    let first = Task { await queue.value(for: 1) }
    for _ in 0..<100 {
      if await counts.starts[1] == 1 { break }
      try? await Task.sleep(for: .milliseconds(5))
    }
    let pending = Task { await queue.value(for: 2) }
    try? await Task.sleep(for: .milliseconds(10))
    pending.cancel()
    let cancelledValue = await pending.value
    let firstValue = await first.value
    let secondStarts = await counts.starts[2]
    XCTAssertNil(cancelledValue)
    XCTAssertEqual(firstValue, 1)
    XCTAssertNil(secondStarts)
  }

  func testCancellingOneSharedWaiterKeepsTheRender() async {
    let counts = RenderCounts()
    let queue = RenderWorkQueue<Int, Int>(maxConcurrent: 1) { key in
      await counts.started(key)
      try? await Task.sleep(for: .milliseconds(100))
      await counts.finished()
      return key
    }
    let cancelled = Task { await queue.value(for: 7) }
    for _ in 0..<100 {
      if await counts.starts[7] == 1 { break }
      try? await Task.sleep(for: .milliseconds(5))
    }
    let retained = Task { await queue.value(for: 7) }
    try? await Task.sleep(for: .milliseconds(10))
    cancelled.cancel()
    let cancelledValue = await cancelled.value
    let retainedValue = await retained.value
    let starts = await counts.starts[7]
    XCTAssertNil(cancelledValue)
    XCTAssertEqual(retainedValue, 7)
    XCTAssertEqual(starts, 1)
  }
}
