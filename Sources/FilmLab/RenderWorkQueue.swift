import Foundation

/// Shares identical render requests and limits expensive decodes in a scrolling library.
actor RenderWorkQueue<Key: Hashable & Sendable, Value: Sendable> {
  private struct Job {
    let key: Key
    var waiters: [UUID: CheckedContinuation<Value?, Never>]
    var task: Task<Void, Never>?
  }

  private let maxConcurrent: Int
  private let render: @Sendable (Key) async -> Value?
  private var jobs: [UUID: Job] = [:]
  private var jobIDs: [Key: UUID] = [:]
  private var pending: [UUID] = []
  private var active: Set<UUID> = []

  init(maxConcurrent: Int, render: @escaping @Sendable (Key) async -> Value?) {
    precondition(maxConcurrent > 0)
    self.maxConcurrent = maxConcurrent
    self.render = render
  }

  /// Useful for diagnosing coalesced work and waiting for registration in tests.
  func waiterCount(for key: Key) -> Int {
    guard let jobID = jobIDs[key] else { return 0 }
    return jobs[jobID]?.waiters.count ?? 0
  }

  func value(for key: Key) async -> Value? {
    let waiterID = UUID()
    return await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        guard !Task.isCancelled else {
          continuation.resume(returning: nil)
          return
        }
        if let jobID = jobIDs[key] {
          jobs[jobID]?.waiters[waiterID] = continuation
        } else {
          let jobID = UUID()
          jobs[jobID] = Job(key: key, waiters: [waiterID: continuation], task: nil)
          jobIDs[key] = jobID
          pending.append(jobID)
          startPending()
        }
      }
    } onCancel: {
      Task { await self.cancel(key: key, waiterID: waiterID) }
    }
  }

  private func cancel(key: Key, waiterID: UUID) {
    guard let jobID = jobIDs[key], var job = jobs[jobID],
      let waiter = job.waiters.removeValue(forKey: waiterID)
    else { return }
    waiter.resume(returning: nil)
    if job.waiters.isEmpty {
      jobs.removeValue(forKey: jobID)
      jobIDs.removeValue(forKey: key)
      job.task?.cancel()
    } else {
      jobs[jobID] = job
    }
  }

  private func startPending() {
    while active.count < maxConcurrent && !pending.isEmpty {
      let jobID = pending.removeFirst()
      guard var job = jobs[jobID] else { continue }
      active.insert(jobID)
      let key = job.key
      let render = render
      job.task = Task.detached(priority: .utility) {
        let value = await render(key)
        await self.finish(jobID: jobID, value: value)
      }
      jobs[jobID] = job
    }
  }

  private func finish(jobID: UUID, value: Value?) {
    active.remove(jobID)
    if let job = jobs.removeValue(forKey: jobID) {
      if jobIDs[job.key] == jobID { jobIDs.removeValue(forKey: job.key) }
      for waiter in job.waiters.values { waiter.resume(returning: value) }
    }
    startPending()
  }
}
