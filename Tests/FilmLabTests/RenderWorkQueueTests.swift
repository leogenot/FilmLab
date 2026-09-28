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

private actor RenderGate {
  private var released: Set<Int> = []
  private var blocked: [Int: [CheckedContinuation<Void, Never>]] = [:]

  func wait(for key: Int) async {
    if released.contains(key) { return }
    await withCheckedContinuation { continuation in
      blocked[key, default: []].append(continuation)
    }
  }

  func release(_ key: Int) {
    released.insert(key)
    for continuation in blocked.removeValue(forKey: key) ?? [] {
      continuation.resume()
    }
  }
}

final class RenderWorkQueueTests: XCTestCase {
  func testSharesRequestsAndBoundsConcurrency() async {
    let counts = RenderCounts()
    let gate = RenderGate()
    let queue = RenderWorkQueue<Int, Int>(maxConcurrent: 2) { key in
      await counts.started(key)
      await gate.wait(for: key)
      await counts.finished()
      return key * 2
    }
    let first = Task { await queue.value(for: 1) }
    let duplicate = Task { await queue.value(for: 1) }
    let second = Task { await queue.value(for: 2) }
    let third = Task { await queue.value(for: 3) }
    await waitUntil { await queue.waiterCount(for: 1) == 2 }
    await waitUntil { await queue.waiterCount(for: 2) == 1 }
    await waitUntil { await queue.waiterCount(for: 3) == 1 }
    await gate.release(1)
    await gate.release(2)
    await gate.release(3)
    let values = await [first.value, duplicate.value, second.value, third.value]
    let firstStarts = await counts.starts[1]
    let peak = await counts.peak
    XCTAssertEqual(values, [2, 2, 4, 6])
    XCTAssertEqual(firstStarts, 1)
    XCTAssertLessThanOrEqual(peak, 2)
  }

  func testCancelledPendingRequestNeverStarts() async {
    let counts = RenderCounts()
    let gate = RenderGate()
    let queue = RenderWorkQueue<Int, Int>(maxConcurrent: 1) { key in
      await counts.started(key)
      await gate.wait(for: key)
      await counts.finished()
      return key
    }
    let first = Task { await queue.value(for: 1) }
    await waitUntil { await counts.starts[1] == 1 }
    let pending = Task { await queue.value(for: 2) }
    await waitUntil { await queue.waiterCount(for: 2) == 1 }
    pending.cancel()
    let cancelledValue = await pending.value
    await gate.release(1)
    let firstValue = await first.value
    let secondStarts = await counts.starts[2]
    XCTAssertNil(cancelledValue)
    XCTAssertEqual(firstValue, 1)
    XCTAssertNil(secondStarts)
  }

  func testCancellingOneSharedWaiterKeepsTheRender() async {
    let counts = RenderCounts()
    let gate = RenderGate()
    let queue = RenderWorkQueue<Int, Int>(maxConcurrent: 1) { key in
      await counts.started(key)
      await gate.wait(for: key)
      await counts.finished()
      return key
    }
    let cancelled = Task { await queue.value(for: 7) }
    await waitUntil { await counts.starts[7] == 1 }
    let retained = Task { await queue.value(for: 7) }
    await waitUntil { await queue.waiterCount(for: 7) == 2 }
    cancelled.cancel()
    let cancelledValue = await cancelled.value
    await gate.release(7)
    let retainedValue = await retained.value
    let starts = await counts.starts[7]
    XCTAssertNil(cancelledValue)
    XCTAssertEqual(retainedValue, 7)
    XCTAssertEqual(starts, 1)
  }

  private func waitUntil(_ condition: () async -> Bool) async {
    let deadline = ContinuousClock.now + .seconds(5)
    while !(await condition()) {
      if ContinuousClock.now >= deadline {
        XCTFail("Timed out waiting for render queue state")
        return
      }
      await Task.yield()
    }
  }
}
