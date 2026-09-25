import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CryptoKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

@main
struct FilmLabApp: App {
  @State private var editor = PhotoEditor()

  var body: some Scene {
    WindowGroup("FilmLab") {
      ContentView(editor: editor)
        .frame(minWidth: 960, minHeight: 600)
        .preferredColorScheme(.dark)
    }
  }
}

private struct PhotoEdits: Codable, Equatable {
  var exposure = 0.0
  var contrast = 1.0
  var saturation = 1.0
  var warmth = 0.0
  var inputWarmth = 0.0
  var inputTint = 0.0
  var filmAmount = 1.0
  var stockIndex = 0
  var enduraPaperTone = false
  var premierPaperTone = false
  var paperStrength = 0.5
  var paperExposure = 0.0
  var shotExposure = 0.0
  var shadowLight = 0.0
  var highlightLight = 0.0
  var localExposure = 0.0
  var localCenterX = 0.5
  var localCenterY = 0.5
  var localRadius = 0.35
  var localFeather = 0.5
  var radialLights = [RadialAdjustment()]
  var development = 0.0
  var grain = 0.0
  var halation = 0.0
  var acutance = 0.0
  var shadowHue = 210.0
  var shadowStrength = 0.0
  var midHue = 30.0
  var midStrength = 0.0
  var highlightHue = 35.0
  var highlightStrength = 0.0
  var selectiveHue = 30.0
  var selectiveRange = 35.0
  var selectiveShift = 0.0
  var selectiveSaturation = 0.0
  var mixer = Array(repeating: ColorMix(), count: 8)
  var frameRotation = 0
  var frameStraighten = 0.0
  var frameAspect = 0
  var frameOffsetX = 0.0
  var frameOffsetY = 0.0
  var frameFreeCrop = FreeCrop()
  var flatRAW = false
  var rawHighlightRecovery = true
  var rawTemperature: Double?
  var rawTint: Double?

  init() {}

  static func defaults(forRAW isRAW: Bool) -> PhotoEdits {
    var edits = PhotoEdits()
    edits.filmAmount = isRAW ? 1.0 : 0.7
    edits.flatRAW = isRAW
    return edits
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    exposure = try values.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
    contrast = try values.decodeIfPresent(Double.self, forKey: .contrast) ?? 1
    saturation = try values.decodeIfPresent(Double.self, forKey: .saturation) ?? 1
    warmth = try values.decodeIfPresent(Double.self, forKey: .warmth) ?? 0
    inputWarmth = try values.decodeIfPresent(Double.self, forKey: .inputWarmth) ?? 0
    inputTint = try values.decodeIfPresent(Double.self, forKey: .inputTint) ?? 0
    filmAmount = try values.decodeIfPresent(Double.self, forKey: .filmAmount) ?? 1.0
    stockIndex = try values.decodeIfPresent(Int.self, forKey: .stockIndex) ?? 0
    enduraPaperTone = try values.decodeIfPresent(Bool.self, forKey: .enduraPaperTone) ?? false
    premierPaperTone = try values.decodeIfPresent(Bool.self, forKey: .premierPaperTone) ?? false
    paperStrength = try values.decodeIfPresent(Double.self, forKey: .paperStrength) ?? 0.5
    paperExposure = try values.decodeIfPresent(Double.self, forKey: .paperExposure) ?? 0
    shotExposure = try values.decodeIfPresent(Double.self, forKey: .shotExposure) ?? 0
    shadowLight = try values.decodeIfPresent(Double.self, forKey: .shadowLight) ?? 0
    highlightLight = try values.decodeIfPresent(Double.self, forKey: .highlightLight) ?? 0
    localExposure = try values.decodeIfPresent(Double.self, forKey: .localExposure) ?? 0
    localCenterX = try values.decodeIfPresent(Double.self, forKey: .localCenterX) ?? 0.5
    localCenterY = try values.decodeIfPresent(Double.self, forKey: .localCenterY) ?? 0.5
    localRadius = try values.decodeIfPresent(Double.self, forKey: .localRadius) ?? 0.35
    localFeather = try values.decodeIfPresent(Double.self, forKey: .localFeather) ?? 0.5
    if let saved = try values.decodeIfPresent([RadialAdjustment].self, forKey: .radialLights),
      !saved.isEmpty
    {
      radialLights = Array(saved.prefix(8))
    } else {
      radialLights = [
        RadialAdjustment(
          exposure: localExposure, centerX: localCenterX, centerY: localCenterY,
          radius: localRadius, feather: localFeather)
      ]
    }
    development = try values.decodeIfPresent(Double.self, forKey: .development) ?? 0
    grain = try values.decodeIfPresent(Double.self, forKey: .grain) ?? 0
    halation = try values.decodeIfPresent(Double.self, forKey: .halation) ?? 0
    acutance = try values.decodeIfPresent(Double.self, forKey: .acutance) ?? 0
    shadowHue = try values.decodeIfPresent(Double.self, forKey: .shadowHue) ?? 210
    shadowStrength = try values.decodeIfPresent(Double.self, forKey: .shadowStrength) ?? 0
    midHue = try values.decodeIfPresent(Double.self, forKey: .midHue) ?? 30
    midStrength = try values.decodeIfPresent(Double.self, forKey: .midStrength) ?? 0
    highlightHue = try values.decodeIfPresent(Double.self, forKey: .highlightHue) ?? 35
    highlightStrength = try values.decodeIfPresent(Double.self, forKey: .highlightStrength) ?? 0
    selectiveHue = try values.decodeIfPresent(Double.self, forKey: .selectiveHue) ?? 30
    selectiveRange = try values.decodeIfPresent(Double.self, forKey: .selectiveRange) ?? 35
    selectiveShift = try values.decodeIfPresent(Double.self, forKey: .selectiveShift) ?? 0
    selectiveSaturation = try values.decodeIfPresent(Double.self, forKey: .selectiveSaturation) ?? 0
    let savedMixer = try values.decodeIfPresent([ColorMix].self, forKey: .mixer) ?? []
    mixer = Array((savedMixer + Array(repeating: ColorMix(), count: 8)).prefix(8))
    frameRotation = try values.decodeIfPresent(Int.self, forKey: .frameRotation) ?? 0
    frameStraighten = try values.decodeIfPresent(Double.self, forKey: .frameStraighten) ?? 0
    frameAspect = try values.decodeIfPresent(Int.self, forKey: .frameAspect) ?? 0
    frameOffsetX = try values.decodeIfPresent(Double.self, forKey: .frameOffsetX) ?? 0
    frameOffsetY = try values.decodeIfPresent(Double.self, forKey: .frameOffsetY) ?? 0
    frameFreeCrop = try values.decodeIfPresent(FreeCrop.self, forKey: .frameFreeCrop) ?? FreeCrop()
    flatRAW = try values.decodeIfPresent(Bool.self, forKey: .flatRAW) ?? false
    rawHighlightRecovery =
      try values.decodeIfPresent(Bool.self, forKey: .rawHighlightRecovery) ?? true
    rawTemperature = try values.decodeIfPresent(Double.self, forKey: .rawTemperature)
    rawTint = try values.decodeIfPresent(Double.self, forKey: .rawTint)
  }
}

@MainActor @Observable
final class PhotoEditor {
  var sourceURL: URL?
  var preview: NSImage?
  var comparisonPreview: NSImage?
  var histogram: PreviewHistogram?
  var compareEnabled = false
  var compareFraction = 0.5
  var exposure = 0.0
  var contrast = 1.0
  var saturation = 1.0
  var warmth = 0.0
  var inputWarmth = 0.0
  var inputTint = 0.0
  var filmAmount = 1.0
  var stockIndex = 0
  var enduraPaperTone = false
  var premierPaperTone = false
  var paperStrength = 0.5
  var paperExposure = 0.0
  var shotExposure = 0.0
  var shadowLight = 0.0
  var highlightLight = 0.0
  var radialLights = [RadialAdjustment()]
  var selectedLocalIndex = 0
  var placingLocalArea = false
  var paintingLocalArea = false
  var erasingLocalArea = false
  var development = 0.0
  var grain = 0.0
  var halation = 0.0
  var acutance = 0.0
  var shadowHue = 210.0
  var shadowStrength = 0.0
  var midHue = 30.0
  var midStrength = 0.0
  var highlightHue = 35.0
  var highlightStrength = 0.0
  var selectiveHue = 30.0
  var selectiveRange = 35.0
  var selectiveShift = 0.0
  var selectiveSaturation = 0.0
  var mixer = Array(repeating: ColorMix(), count: 8)
  var frameRotation = 0
  var frameStraighten = 0.0
  var frameAspect = 0
  var frameOffsetX = 0.0
  var frameOffsetY = 0.0
  var frameFreeCrop = FreeCrop()
  var showCropBounds = false
  var flatRAW = false
  var rawHighlightRecovery = true
  var rawHighlightRecoverySupported = false
  var rawTemperature = 6500.0
  var rawTint = 0.0
  var error: String?
  var editRecoveryNotice: String?
  var editRecoveryURL: URL?
  var showOriginal = false
  var showLocalMask = false
  var zoom100 = false
  var isRendering = false
  var isOpening = false
  var isExporting = false

  private var source: CIImage?
  private var didAttemptResume = false
  private let lastPhotoKey = "FilmLab.lastPhotoPath"
  private let settingsPasteboardType = NSPasteboard.PasteboardType("app.filmlab.edits+json")
  private var decodedFlatRAW = false
  private var decodedHighlightRecovery = true
  private var decodedRawTemperature = 6500.0
  private var decodedRawTint = 0.0
  private var cameraRawTemperature = 6500.0
  private var cameraRawTint = 0.0
  private var sourceIsRAW = false
  private var editSavingBlocked = false
  var isRAWSource: Bool { sourceURL != nil && sourceIsRAW }
  private var scopedURL: URL?
  private var saveTask: Task<Void, Never>?
  private var historyTask: Task<Void, Never>?
  private var historyOpen = false
  private var historyBaseline = PhotoEdits()
  private var undoStack: [PhotoEdits] = []
  private var redoStack: [PhotoEdits] = []
  var canUndo: Bool { !undoStack.isEmpty }
  var canRedo: Bool { !redoStack.isEmpty }
  private var previewTask: Task<Void, Never>?
  private var rawDecodeTask: Task<Void, Never>?
  private var openTask: Task<Void, Never>?
  private var openVersion = 0
  private let imageDecoder = ImageDecoder()
  private var rawDecodeVersion = 0
  private var renderVersion = 0
  private let previewRenderer = PreviewRenderer()
  private let exporter = ImageExporter()

  // Scene-linear RGB enters this kernel in the context's extended linear working space.
  // This is a provisional response model, not a measured emulsion profile.
  private let filmKernel = FilmKernels.kernel("filmResponse")
  private let sceneLightKernel = FilmKernels.kernel("shapeSceneLight")
  private let measuredNegativeKernel = FilmKernels.kernel("measuredNegative")
  private let portraPositiveKernel = FilmKernels.kernel("portraPositive")

  func open(_ url: URL) {
    openTask?.cancel()
    openVersion += 1
    let version = openVersion
    let access = url.startAccessingSecurityScopedResource()
    isOpening = true
    error = nil
    openTask = Task {
      var retainAccess = false
      defer {
        if access && !retainAccess { url.stopAccessingSecurityScopedResource() }
        if version == openVersion {
          isOpening = false
          openTask = nil
        }
      }
      do {
        let isRAW = await imageDecoder.isRAWFile(url)
        try Task.checkCancellation()
        let loaded = SavedEditStore.load(
          from: editsURL(for: url), defaultValue: PhotoEdits.defaults(forRAW: isRAW))
        let saved = loaded.value
        let decoded = try await imageDecoder.decode(
          from: url, isRAW: isRAW, flatRAW: saved.flatRAW,
          highlightRecovery: saved.rawHighlightRecovery, temperature: saved.rawTemperature,
          tint: saved.rawTint)
        try Task.checkCancellation()
        guard version == openVersion else { return }
        let image = decoded.image
        guard image.extent.width.isFinite, image.extent.height.isFinite,
          image.extent.width > 0, image.extent.height > 0
        else { throw EditorError.unsupported }
        rawDecodeTask?.cancel()
        rawDecodeVersion += 1
        saveTask?.cancel()
        if sourceURL != nil { saveEdits() }
        previewTask?.cancel()
        renderVersion += 1
        if let scopedURL { scopedURL.stopAccessingSecurityScopedResource() }
        scopedURL = access ? url : nil
        retainAccess = access
        source = image
        sourceURL = url
        editRecoveryNotice = loaded.notice
        editRecoveryURL = loaded.backupURL
        editSavingBlocked = !loaded.canSave
        UserDefaults.standard.set(url.standardizedFileURL.path, forKey: lastPhotoKey)
        sourceIsRAW = isRAW
        decodedFlatRAW = saved.flatRAW
        decodedHighlightRecovery = saved.rawHighlightRecovery
        rawHighlightRecoverySupported = decoded.highlightRecoverySupported
        cameraRawTemperature = decoded.cameraTemperature ?? 6500
        cameraRawTint = decoded.cameraTint ?? 0
        decodedRawTemperature = saved.rawTemperature ?? cameraRawTemperature
        decodedRawTint = saved.rawTint ?? cameraRawTint
        showOriginal = false
        showLocalMask = false
        placingLocalArea = false
        paintingLocalArea = false
        erasingLocalArea = false
        showCropBounds = false
        zoom100 = false
        compareEnabled = false
        comparisonPreview = nil
        histogram = nil
        restoreEdits(saved)
        historyTask?.cancel()
        historyOpen = false
        undoStack.removeAll()
        redoStack.removeAll()
        historyBaseline = currentEdits()
        preview = nil
        error = nil
        renderPreview()
      } catch is CancellationError {
        return
      } catch {
        guard version == openVersion else { return }
        self.error = "Could not open photo: \(error.localizedDescription)"
      }
    }
  }

  func resumeLastPhoto() {
    guard !didAttemptResume else { return }
    didAttemptResume = true
    guard let path = UserDefaults.standard.string(forKey: lastPhotoKey),
      FileManager.default.fileExists(atPath: path)
    else { return }
    open(URL(fileURLWithPath: path))
  }

  func flushEdits() {
    saveTask?.cancel()
    saveEdits()
  }

  private func editsURL(for url: URL) -> URL {
    let key = SHA256.hash(data: Data(url.standardizedFileURL.path.utf8))
      .map { String(format: "%02x", $0) }.joined()
    return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab/Edits", isDirectory: true)
      .appendingPathComponent(key + ".json")
  }

  private func restoreEdits(_ saved: PhotoEdits) {
    exposure = saved.exposure
    contrast = saved.contrast
    saturation = saved.saturation
    warmth = saved.warmth
    inputWarmth = saved.inputWarmth
    inputTint = saved.inputTint
    filmAmount = saved.filmAmount
    stockIndex = saved.stockIndex
    enduraPaperTone = saved.enduraPaperTone
    premierPaperTone = saved.premierPaperTone
    paperStrength = saved.paperStrength
    paperExposure = saved.paperExposure
    shotExposure = saved.shotExposure
    shadowLight = saved.shadowLight
    highlightLight = saved.highlightLight
    radialLights = saved.radialLights
    selectedLocalIndex = min(selectedLocalIndex, radialLights.count - 1)
    development = saved.development
    grain = saved.grain
    halation = saved.halation
    acutance = saved.acutance
    shadowHue = saved.shadowHue
    shadowStrength = saved.shadowStrength
    midHue = saved.midHue
    midStrength = saved.midStrength
    highlightHue = saved.highlightHue
    highlightStrength = saved.highlightStrength
    selectiveHue = saved.selectiveHue
    selectiveRange = saved.selectiveRange
    selectiveShift = saved.selectiveShift
    selectiveSaturation = saved.selectiveSaturation
    mixer = saved.mixer
    frameRotation = saved.frameRotation
    frameStraighten = saved.frameStraighten
    frameAspect = saved.frameAspect
    frameOffsetX = saved.frameOffsetX
    frameOffsetY = saved.frameOffsetY
    frameFreeCrop = saved.frameFreeCrop
    flatRAW = saved.flatRAW
    rawHighlightRecovery = saved.rawHighlightRecovery
    rawTemperature = saved.rawTemperature ?? cameraRawTemperature
    rawTint = saved.rawTint ?? cameraRawTint
  }

  func rawModeChanged() {
    guard isRAWSource, let url = sourceURL else { return }
    let requestedFlatRAW = flatRAW
    let requestedHighlightRecovery = rawHighlightRecovery
    let requestedTemperature = rawTemperature
    let requestedTint = rawTint
    let needsDecode =
      requestedFlatRAW != decodedFlatRAW
      || (rawHighlightRecoverySupported && requestedHighlightRecovery != decodedHighlightRecovery)
      || abs(requestedTemperature - decodedRawTemperature) > 0.01
      || abs(requestedTint - decodedRawTint) > 0.01
    guard needsDecode else {
      if rawDecodeTask != nil {
        rawDecodeTask?.cancel()
        rawDecodeTask = nil
        rawDecodeVersion += 1
        isRendering = false
      }
      return
    }
    rawDecodeTask?.cancel()
    rawDecodeVersion += 1
    previewTask?.cancel()
    renderVersion += 1
    let version = rawDecodeVersion
    isRendering = true
    rawDecodeTask = Task {
      do { try await Task.sleep(for: .milliseconds(90)) } catch { return }
      guard !Task.isCancelled, version == rawDecodeVersion, sourceURL == url else { return }
      do {
        let decoded = try await imageDecoder.decode(
          from: url, isRAW: true, flatRAW: requestedFlatRAW,
          highlightRecovery: requestedHighlightRecovery, temperature: requestedTemperature,
          tint: requestedTint
        )
        guard !Task.isCancelled, version == rawDecodeVersion, sourceURL == url else { return }
        previewTask?.cancel()
        renderVersion += 1
        source = decoded.image
        decodedFlatRAW = requestedFlatRAW
        decodedHighlightRecovery = requestedHighlightRecovery
        decodedRawTemperature = requestedTemperature
        decodedRawTint = requestedTint
        rawDecodeTask = nil
        editsChanged()
      } catch {
        guard version == rawDecodeVersion else { return }
        flatRAW = decodedFlatRAW
        rawHighlightRecovery = decodedHighlightRecovery
        rawTemperature = decodedRawTemperature
        rawTint = decodedRawTint
        isRendering = false
        self.error = "Could not update RAW input: \(error.localizedDescription)"
      }
    }
  }

  func editsChanged() {
    let latest = currentEdits()
    if latest != historyBaseline {
      if !historyOpen {
        undoStack.append(historyBaseline)
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack.removeAll()
        historyOpen = true
      }
      historyBaseline = latest
      historyTask?.cancel()
      historyTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }
        historyOpen = false
      }
    }
    renderPreview()
    saveTask?.cancel()
    saveTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled else { return }
      saveEdits()
    }
  }

  private func currentEdits() -> PhotoEdits {
    var edits = PhotoEdits()
    edits.exposure = exposure
    edits.contrast = contrast
    edits.saturation = saturation
    edits.warmth = warmth
    edits.inputWarmth = inputWarmth
    edits.inputTint = inputTint
    edits.filmAmount = filmAmount
    edits.stockIndex = stockIndex
    edits.enduraPaperTone = enduraPaperTone
    edits.premierPaperTone = premierPaperTone
    edits.paperStrength = paperStrength
    edits.paperExposure = paperExposure
    edits.shotExposure = shotExposure
    edits.shadowLight = shadowLight
    edits.highlightLight = highlightLight
    edits.radialLights = radialLights
    edits.development = development
    edits.grain = grain
    edits.halation = halation
    edits.acutance = acutance
    edits.shadowHue = shadowHue
    edits.shadowStrength = shadowStrength
    edits.midHue = midHue
    edits.midStrength = midStrength
    edits.highlightHue = highlightHue
    edits.highlightStrength = highlightStrength
    edits.selectiveHue = selectiveHue
    edits.selectiveRange = selectiveRange
    edits.selectiveShift = selectiveShift
    edits.selectiveSaturation = selectiveSaturation
    edits.mixer = mixer
    edits.frameRotation = frameRotation
    edits.frameStraighten = frameStraighten
    edits.frameAspect = frameAspect
    edits.frameOffsetX = frameOffsetX
    edits.frameOffsetY = frameOffsetY
    edits.frameFreeCrop = frameFreeCrop
    edits.flatRAW = flatRAW
    edits.rawHighlightRecovery = rawHighlightRecovery
    if isRAWSource {
      edits.rawTemperature = rawTemperature
      edits.rawTint = rawTint
    }
    return edits
  }

  private func saveEdits() {
    guard let sourceURL else { return }
    guard !editSavingBlocked else { return }
    let edits = currentEdits()
    let url = editsURL(for: sourceURL)
    do {
      try SavedEditStore.save(edits, to: url)
    } catch {
      self.error = "Could not save edits: \(error.localizedDescription)"
    }
  }

  func copySettings() {
    guard sourceURL != nil else { return }
    do {
      let data = try JSONEncoder().encode(currentEdits())
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setData(data, forType: settingsPasteboardType)
      error = nil
    } catch {
      self.error = "Could not copy settings: \(error.localizedDescription)"
    }
  }

  func pasteSettings() {
    guard sourceURL != nil else { return }
    guard let data = NSPasteboard.general.data(forType: settingsPasteboardType),
      let copied = try? JSONDecoder().decode(PhotoEdits.self, from: data)
    else {
      error = "Copy settings from a FilmLab photo first."
      return
    }
    applyTransferredSettings(copied)
  }

  func saveLook() {
    guard sourceURL != nil else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = "FilmLab Look.json"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    var settings = currentEdits()
    settings.flatRAW = false
    settings.rawHighlightRecovery = true
    settings.rawTemperature = nil
    settings.rawTint = nil
    settings.inputWarmth = 0
    settings.inputTint = 0
    do {
      try LookFile(settings: settings).write(to: url)
      error = nil
    } catch {
      self.error = "Could not save look: \(error.localizedDescription)"
    }
  }

  func applyLook() {
    guard sourceURL != nil else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    let accessing = url.startAccessingSecurityScopedResource()
    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
    do {
      let settings: PhotoEdits = try LookFile.read(from: url)
      applyTransferredSettings(settings)
      error = nil
    } catch {
      self.error = "Could not apply look: \(error.localizedDescription)"
    }
  }

  private func applyTransferredSettings(_ transferred: PhotoEdits) {
    var copied = transferred
    let current = currentEdits()
    copied.flatRAW = current.flatRAW
    copied.rawHighlightRecovery = current.rawHighlightRecovery
    copied.rawTemperature = current.rawTemperature
    copied.rawTint = current.rawTint
    copied.inputWarmth = current.inputWarmth
    copied.inputTint = current.inputTint
    restoreEdits(copied)
    showCropBounds = false
    showLocalMask = false
    placingLocalArea = false
    paintingLocalArea = false
    erasingLocalArea = false
    showOriginal = false
    compareEnabled = false
    editsChanged()
  }

  func undo() {
    guard let snapshot = undoStack.popLast() else { return }
    redoStack.append(historyBaseline)
    applyHistory(snapshot)
  }

  func redo() {
    guard let snapshot = redoStack.popLast() else { return }
    undoStack.append(historyBaseline)
    applyHistory(snapshot)
  }

  private func applyHistory(_ snapshot: PhotoEdits) {
    historyTask?.cancel()
    historyOpen = false
    restoreEdits(snapshot)
    historyBaseline = currentEdits()
    rawModeChanged()
    renderPreview()
    flushEdits()
  }

  func resetEdits() {
    let defaults = PhotoEdits.defaults(forRAW: isRAWSource)
    exposure = defaults.exposure
    contrast = defaults.contrast
    saturation = defaults.saturation
    warmth = defaults.warmth
    inputWarmth = defaults.inputWarmth
    inputTint = defaults.inputTint
    filmAmount = defaults.filmAmount
    stockIndex = defaults.stockIndex
    enduraPaperTone = defaults.enduraPaperTone
    premierPaperTone = defaults.premierPaperTone
    paperStrength = defaults.paperStrength
    paperExposure = defaults.paperExposure
    shotExposure = defaults.shotExposure
    shadowLight = defaults.shadowLight
    highlightLight = defaults.highlightLight
    radialLights = defaults.radialLights
    selectedLocalIndex = 0
    development = defaults.development
    grain = defaults.grain
    halation = defaults.halation
    acutance = defaults.acutance
    shadowHue = defaults.shadowHue
    shadowStrength = defaults.shadowStrength
    midHue = defaults.midHue
    midStrength = defaults.midStrength
    highlightHue = defaults.highlightHue
    highlightStrength = defaults.highlightStrength
    selectiveHue = defaults.selectiveHue
    selectiveRange = defaults.selectiveRange
    selectiveShift = defaults.selectiveShift
    selectiveSaturation = defaults.selectiveSaturation
    mixer = defaults.mixer
    frameRotation = defaults.frameRotation
    frameStraighten = defaults.frameStraighten
    frameAspect = defaults.frameAspect
    frameOffsetX = defaults.frameOffsetX
    frameOffsetY = defaults.frameOffsetY
    frameFreeCrop = defaults.frameFreeCrop
    showCropBounds = false
    paintingLocalArea = false
    flatRAW = defaults.flatRAW
    rawHighlightRecovery = defaults.rawHighlightRecovery
    rawTemperature = cameraRawTemperature
    rawTint = cameraRawTint
    showOriginal = false
    showLocalMask = false
    compareEnabled = false
    editsChanged()
  }

  func toggleBeforeAfter() {
    compareEnabled = false
    showLocalMask = false
    showCropBounds = false
    placingLocalArea = false
    paintingLocalArea = false
    showOriginal.toggle()
    renderPreview()
  }

  func toggleZoom() {
    placingLocalArea = false
    paintingLocalArea = false
    showCropBounds = false
    compareEnabled = false
    zoom100.toggle()
    renderPreview()
  }

  func toggleCompare() {
    compareEnabled.toggle()
    showLocalMask = false
    showCropBounds = false
    placingLocalArea = false
    paintingLocalArea = false
    showOriginal = false
    zoom100 = false
    renderPreview()
  }

  func addLocalArea() {
    guard radialLights.count < 8 else { return }
    radialLights.append(RadialAdjustment())
    selectedLocalIndex = radialLights.count - 1
    editsChanged()
  }

  func removeLocalArea() {
    guard radialLights.count > 1 else { return }
    radialLights.remove(at: min(selectedLocalIndex, radialLights.count - 1))
    selectedLocalIndex = min(selectedLocalIndex, radialLights.count - 1)
    if radialLights[selectedLocalIndex].shape != 2 { paintingLocalArea = false }
    editsChanged()
  }

  func selectLocalArea(_ index: Int) {
    guard radialLights.indices.contains(index) else { return }
    selectedLocalIndex = index
    if radialLights[index].shape != 2 { paintingLocalArea = false }
    if showLocalMask { renderPreview() }
  }

  func setLocalShape(_ shape: Int) {
    guard radialLights.indices.contains(selectedLocalIndex), shape == 0 || shape == 1 || shape == 2
    else {
      return
    }
    let previous = radialLights[selectedLocalIndex].shape
    guard previous != shape else { return }
    radialLights[selectedLocalIndex].shape = shape
    if shape != 2 { paintingLocalArea = false }
    if shape == 1 {
      var angle = 90 - Double(frameRotation) * 90 - frameStraighten
      if angle < -180 { angle += 360 }
      if angle > 180 { angle -= 360 }
      radialLights[selectedLocalIndex].angle = angle
    }
    editsChanged()
  }

  func setMaskPreview(_ visible: Bool) {
    placingLocalArea = false
    paintingLocalArea = false
    showCropBounds = false
    showLocalMask = visible
    if visible {
      showOriginal = false
      compareEnabled = false
    }
    renderPreview()
  }

  func setCropBoundsPreview(_ visible: Bool) {
    showCropBounds = visible && frameAspect == 5 && source != nil
    if showCropBounds {
      showOriginal = false
      showLocalMask = false
      placingLocalArea = false
      paintingLocalArea = false
      compareEnabled = false
      zoom100 = false
    }
    renderPreview()
  }

  func moveFreeCrop(dx: Double, dy: Double, from original: FreeCrop) {
    guard showCropBounds else { return }
    frameFreeCrop.centerX = min(
      max(original.centerX + dx, frameFreeCrop.width / 2), 1 - frameFreeCrop.width / 2)
    frameFreeCrop.centerY = min(
      max(original.centerY + dy, frameFreeCrop.height / 2), 1 - frameFreeCrop.height / 2)
    editsChanged()
  }

  func setPlacingLocalArea(_ placing: Bool) {
    placingLocalArea = placing && source != nil
    if placingLocalArea {
      paintingLocalArea = false
      showCropBounds = false
      showLocalMask = false
      showOriginal = false
      compareEnabled = false
      zoom100 = false
      renderPreview()
    }
  }

  func setPaintingLocalArea(_ painting: Bool) {
    paintingLocalArea =
      painting && source != nil
      && radialLights[selectedLocalIndex].shape == 2
    if paintingLocalArea {
      placingLocalArea = false
      showLocalMask = false
      showCropBounds = false
      showOriginal = false
      compareEnabled = false
      zoom100 = false
      renderPreview()
    }
  }

  func addPaintStroke(displayPoints: [CGPoint], canvasSize: CGSize, imageSize: CGSize) {
    guard paintingLocalArea, let source, !displayPoints.isEmpty else { return }
    guard radialLights[selectedLocalIndex].strokes.count < 100 else {
      error = "This painted area has reached 100 strokes. Add another area."
      return
    }
    let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
    let width = imageSize.width * scale
    let height = imageSize.height * scale
    let left = (canvasSize.width - width) / 2
    let top = (canvasSize.height - height) / 2
    let points = displayPoints.compactMap { point -> BrushPoint? in
      guard
        let sourcePoint = Framing.sourceLocation(
          displayX: (point.x - left) / width, displayY: (point.y - top) / height,
          sourceExtent: source.extent, quarterTurns: frameRotation,
          straightenDegrees: frameStraighten, aspect: frameAspect,
          offsetX: frameOffsetX, offsetY: frameOffsetY, freeCrop: frameFreeCrop)
      else { return nil }
      return BrushPoint(x: Double(sourcePoint.x), y: Double(sourcePoint.y))
    }
    guard !points.isEmpty else { return }
    radialLights[selectedLocalIndex].strokes.append(
      BrushStroke(
        points: points, size: radialLights[selectedLocalIndex].brushSize,
        erasing: erasingLocalArea))
    editsChanged()
  }

  func clearPaint() {
    guard !radialLights[selectedLocalIndex].strokes.isEmpty else { return }
    radialLights[selectedLocalIndex].strokes.removeAll()
    editsChanged()
  }

  func placeSelectedLocalArea(displayX: Double, displayY: Double) {
    guard placingLocalArea, let source,
      let location = Framing.sourceLocation(
        displayX: displayX, displayY: displayY, sourceExtent: source.extent,
        quarterTurns: frameRotation, straightenDegrees: frameStraighten,
        aspect: frameAspect, offsetX: frameOffsetX, offsetY: frameOffsetY,
        freeCrop: frameFreeCrop)
    else { return }
    radialLights[selectedLocalIndex].centerX = Double(location.x)
    radialLights[selectedLocalIndex].centerY = Double(location.y)
    placingLocalArea = false
    editsChanged()
  }

  private func localMaskImage() -> CIImage? {
    guard let source else { return nil }
    let area = radialLights[min(selectedLocalIndex, radialLights.count - 1)]
    guard
      let mask = LocalExposure.mask(
        for: source, centerX: area.centerX, centerY: area.centerY,
        radius: area.radius, feather: area.feather, inverted: area.inverted,
        shape: area.shape, angle: area.angle,
        brushSize: area.brushSize, strokes: area.strokes)
    else { return nil }
    return framedImage(mask)
  }

  private func developedImage(previewUncropped: Bool = false) -> CIImage? {
    guard var image = source else { return nil }
    if !sourceIsRAW && (abs(inputWarmth) > 0.001 || abs(inputTint) > 0.001) {
      let balance = CIFilter.temperatureAndTint()
      balance.inputImage = image
      balance.neutral = CIVector(x: 6500, y: 0)
      balance.targetNeutral = CIVector(x: 6500 - inputWarmth * 1000, y: inputTint * 100)
      guard let balanced = balance.outputImage else {
        error = "The rendered-image input balance could not be rendered."
        return nil
      }
      image = balanced
    }
    if abs(shadowLight) > 0.001 || abs(highlightLight) > 0.001 {
      guard let sceneLightKernel,
        let shaped = sceneLightKernel.apply(
          extent: image.extent, arguments: [image, shadowLight, highlightLight]
        )
      else {
        error = "The scene-light shaping stage could not be loaded."
        return nil
      }
      image = shaped
    }
    for area in radialLights
    where abs(area.exposure) > 0.001 || abs(area.warmth) > 0.001 || abs(area.tint) > 0.001 {
      image = LocalExposure.apply(
        to: image, ev: area.exposure, warmth: area.warmth, tint: area.tint,
        centerX: area.centerX,
        centerY: area.centerY, radius: area.radius, feather: area.feather,
        inverted: area.inverted, shape: area.shape, angle: area.angle,
        brushSize: area.brushSize, strokes: area.strokes)
    }
    if stockIndex == 1 || stockIndex == 2 {
      guard let measuredNegativeKernel,
        let portraPositiveKernel,
        let negative = measuredNegativeKernel.apply(
          extent: image.extent, arguments: [image, shotExposure, development, Double(stockIndex)]
        ),
        let positive = portraPositiveKernel.apply(
          extent: image.extent,
          arguments: [
            negative, image, shotExposure, filmAmount,
            (stockIndex == 1 && enduraPaperTone) || (stockIndex == 2 && premierPaperTone)
              ? paperStrength : 0.0, paperExposure,
            Double(stockIndex),
          ]
        )
      else {
        error = "The measured film density study could not be loaded."
        return nil
      }
      image = positive
    } else if let filmKernel,
      let film = filmKernel.apply(
        extent: image.extent,
        arguments: [image, shotExposure, development, filmAmount]
      )
    {
      image = film
    } else {
      error = "The film response could not be loaded."
      return nil
    }
    image = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: exposure])
    image = image.applyingFilter(
      "CIColorControls",
      parameters: [
        kCIInputContrastKey: contrast,
        kCIInputSaturationKey: saturation,
      ])
    let temperature = CIFilter.temperatureAndTint()
    temperature.inputImage = image
    temperature.neutral = CIVector(x: 6500, y: 0)
    temperature.targetNeutral = CIVector(x: 6500 - warmth * 1000, y: 0)
    let graded = ColorGrade.apply(
      to: temperature.outputImage ?? image,
      shadowHue: shadowHue, shadowStrength: shadowStrength,
      midHue: midHue, midStrength: midStrength,
      highlightHue: highlightHue, highlightStrength: highlightStrength
    )
    let selected = SelectiveColor.apply(
      to: graded, targetHue: selectiveHue, range: selectiveRange,
      hueShift: selectiveShift, saturation: selectiveSaturation
    )
    let mixed = ColorMixer.apply(to: selected, adjustments: mixer)
    return framedImage(
      FilmEffects.apply(to: mixed, grain: grain, halation: halation, acutance: acutance),
      aspectOverride: previewUncropped ? 0 : nil)
  }

  private func framedImage(_ image: CIImage, aspectOverride: Int? = nil) -> CIImage {
    Framing.apply(
      to: image, quarterTurns: frameRotation, straightenDegrees: frameStraighten,
      aspect: aspectOverride ?? frameAspect, offsetX: frameOffsetX, offsetY: frameOffsetY,
      freeCrop: frameFreeCrop)
  }

  func rotateFrame(_ steps: Int) {
    frameRotation = ((frameRotation + steps) % 4 + 4) % 4
    editsChanged()
  }

  func renderPreview() {
    renderVersion += 1
    let version = renderVersion
    previewTask?.cancel()
    let image =
      showLocalMask
      ? localMaskImage()
      : (showOriginal
        ? source.map { framedImage($0) } : developedImage(previewUncropped: showCropBounds))
    guard let image else {
      isRendering = false
      return
    }
    isRendering = true
    let scale = zoom100 ? 1 : min(1, 1800 / max(image.extent.width, image.extent.height))
    let request = PreviewRequest(
      image: image, scale: scale, sourceURL: scopedURL,
      originalImage: compareEnabled ? source.map { framedImage($0) } : nil
    )
    previewTask = Task {
      do { try await Task.sleep(for: .milliseconds(60)) } catch { return }
      let result = await previewRenderer.render(request)
      guard !Task.isCancelled, version == renderVersion else { return }
      if let result {
        let image = result.image
        preview = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        comparisonPreview = result.original.map {
          NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height))
        }
        histogram = showLocalMask || showCropBounds ? nil : result.histogram
        error = nil
      } else {
        error = "Could not render this photo."
      }
      isRendering = false
    }
  }

  func exportJPEG() {
    guard let image = developedImage() else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.jpeg]
    panel.nameFieldStringValue =
      (sourceURL?.deletingPathExtension().lastPathComponent ?? "Photo") + "-FilmLab.jpg"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    beginExport(ExportRequest(image: image, url: url, format: .jpeg, sourceURL: sourceURL))
  }

  func exportTIFF() {
    guard let image = developedImage() else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.tiff]
    panel.nameFieldStringValue =
      (sourceURL?.deletingPathExtension().lastPathComponent ?? "Photo") + "-FilmLab.tiff"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    beginExport(ExportRequest(image: image, url: url, format: .tiff16, sourceURL: sourceURL))
  }

  private func beginExport(_ request: ExportRequest) {
    isExporting = true
    error = nil
    Task {
      do {
        try await exporter.export(request)
      } catch {
        self.error = "Could not export photo: \(error.localizedDescription)"
      }
      isExporting = false
    }
  }

}

enum EditorError: LocalizedError {
  case unsupported
  var errorDescription: String? { "This image format is not supported by this Mac's decoder." }
}

private enum EditorPanel: String, CaseIterable, Identifiable {
  case film = "Film"
  case develop = "Develop"
  case color = "Color"
  case local = "Local"
  case texture = "Texture"
  case framing = "Framing"

  var id: Self { self }
  var symbol: String {
    switch self {
    case .film: "camera.filters"
    case .develop: "slider.horizontal.3"
    case .color: "circle.lefthalf.filled"
    case .local: "circle.dotted.circle"
    case .texture: "circle.hexagongrid"
    case .framing: "crop.rotate"
    }
  }
}

struct ContentView: View {
  @Bindable var editor: PhotoEditor
  @State private var showingImporter = false
  @State private var panel: EditorPanel = .film
  @State private var selectedColorBand = 0
  @State private var cropDragOrigin: FreeCrop?
  @State private var paintDragPoints: [CGPoint] = []
  @Environment(\.displayScale) private var displayScale
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    HStack(spacing: 0) {
      navigationRail
      photoCanvas
      inspector
    }
    .toolbar {
      Button(editor.zoom100 ? "Fit" : "100%", systemImage: "plus.magnifyingglass") {
        editor.toggleZoom()
      }
      .disabled(editor.preview == nil)
      Button(editor.showOriginal ? "After" : "Before", systemImage: "square.on.square") {
        editor.toggleBeforeAfter()
      }
      .disabled(editor.preview == nil)
      Button(
        editor.compareEnabled ? "Close Compare" : "Compare", systemImage: "rectangle.split.2x1"
      ) {
        editor.toggleCompare()
      }
      .disabled(editor.preview == nil)
      Button("Undo", systemImage: "arrow.uturn.backward") { editor.undo() }
        .keyboardShortcut("z", modifiers: .command)
        .disabled(!editor.canUndo)
      Button("Redo", systemImage: "arrow.uturn.forward") { editor.redo() }
        .keyboardShortcut("z", modifiers: [.command, .shift])
        .disabled(!editor.canRedo)
      Menu("Settings", systemImage: "square.on.square") {
        Button("Copy Settings") { editor.copySettings() }
          .keyboardShortcut("c", modifiers: [.command, .shift])
        Button("Paste Settings") { editor.pasteSettings() }
          .keyboardShortcut("v", modifiers: [.command, .shift])
        Divider()
        Button("Save Look…") { editor.saveLook() }
        Button("Apply Look…") { editor.applyLook() }
      }
      .accessibilityLabel("Settings")
      .help("Copy, save, or apply FilmLab edit settings")
      .disabled(editor.preview == nil)
      Button("Reset Edits", systemImage: "arrow.counterclockwise") { editor.resetEdits() }
        .disabled(editor.preview == nil)
      Button("Open…", systemImage: "folder") { showingImporter = true }
      Menu("Export…", systemImage: "square.and.arrow.up") {
        Button("JPEG (sRGB)…") { editor.exportJPEG() }
        Button("16-bit TIFF (Display P3)…") { editor.exportTIFF() }
      }
      .disabled(editor.preview == nil || editor.isExporting)
    }
    .fileImporter(
      isPresented: $showingImporter, allowedContentTypes: [.image, .rawImage],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls): if let url = urls.first { editor.open(url) }
      case .failure(let error): editor.error = error.localizedDescription
      }
    }
    .onAppear { editor.resumeLastPhoto() }
    .onDisappear { editor.flushEdits() }
    .onChange(of: panel) {
      if panel != .local {
        if editor.showLocalMask { editor.setMaskPreview(false) }
        editor.setPlacingLocalArea(false)
        editor.setPaintingLocalArea(false)
      }
      if panel != .framing && editor.showCropBounds { editor.setCropBoundsPreview(false) }
    }
    .onChange(of: editor.paintingLocalArea) {
      if !editor.paintingLocalArea { paintDragPoints.removeAll() }
    }
    .onChange(of: scenePhase) {
      if scenePhase != .active { editor.flushEdits() }
    }
    .onChange(of: editor.exposure) { editor.editsChanged() }
    .onChange(of: editor.contrast) { editor.editsChanged() }
    .onChange(of: editor.saturation) { editor.editsChanged() }
    .onChange(of: editor.warmth) { editor.editsChanged() }
    .onChange(of: editor.inputWarmth) { editor.editsChanged() }
    .onChange(of: editor.inputTint) { editor.editsChanged() }
    .onChange(of: editor.filmAmount) { editor.editsChanged() }
    .onChange(of: editor.stockIndex) { editor.editsChanged() }
    .onChange(of: editor.enduraPaperTone) { editor.editsChanged() }
    .onChange(of: editor.premierPaperTone) { editor.editsChanged() }
    .onChange(of: editor.paperStrength) { editor.editsChanged() }
    .onChange(of: editor.paperExposure) { editor.editsChanged() }
    .onChange(of: editor.shotExposure) { editor.editsChanged() }
    .onChange(of: editor.shadowLight) { editor.editsChanged() }
    .onChange(of: editor.highlightLight) { editor.editsChanged() }
    .onChange(of: editor.development) { editor.editsChanged() }
    .onChange(of: editor.grain) { editor.editsChanged() }
    .onChange(of: editor.halation) { editor.editsChanged() }
    .onChange(of: editor.acutance) { editor.editsChanged() }
    .onChange(of: editor.shadowHue) { editor.editsChanged() }
    .onChange(of: editor.shadowStrength) { editor.editsChanged() }
    .onChange(of: editor.midHue) { editor.editsChanged() }
    .onChange(of: editor.midStrength) { editor.editsChanged() }
    .onChange(of: editor.highlightHue) { editor.editsChanged() }
    .onChange(of: editor.highlightStrength) { editor.editsChanged() }
    .onChange(of: editor.selectiveHue) { editor.editsChanged() }
    .onChange(of: editor.selectiveRange) { editor.editsChanged() }
    .onChange(of: editor.selectiveShift) { editor.editsChanged() }
    .onChange(of: editor.selectiveSaturation) { editor.editsChanged() }
    .onChange(of: editor.frameAspect) {
      if editor.frameAspect != 5 && editor.showCropBounds { editor.setCropBoundsPreview(false) }
      editor.editsChanged()
    }
    .onChange(of: editor.frameOffsetX) { editor.editsChanged() }
    .onChange(of: editor.frameOffsetY) { editor.editsChanged() }
    .onChange(of: editor.flatRAW) { editor.rawModeChanged() }
    .onChange(of: editor.rawHighlightRecovery) { editor.rawModeChanged() }
    .onChange(of: editor.rawTemperature) { editor.rawModeChanged() }
    .onChange(of: editor.rawTint) { editor.rawModeChanged() }
  }

  private var navigationRail: some View {
    VStack(alignment: .leading, spacing: 24) {
      VStack(alignment: .leading, spacing: 5) {
        Text("FILMLAB")
          .font(.caption.weight(.semibold))
          .tracking(2)
          .foregroundStyle(.secondary)
        Text(editor.sourceURL?.lastPathComponent ?? "No photo")
          .font(.caption)
          .lineLimit(2)
      }
      VStack(spacing: 6) {
        ForEach(EditorPanel.allCases) { item in
          Button {
            panel = item
          } label: {
            Label(item.rawValue, systemImage: item.symbol)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.plain)
          .padding(.horizontal, 10)
          .padding(.vertical, 9)
          .background(panel == item ? Color.white.opacity(0.11) : Color.clear)
          .clipShape(RoundedRectangle(cornerRadius: 7))
        }
      }
      Spacer()
      Text("LOCAL EDITS")
        .font(.caption2.weight(.medium))
        .tracking(1)
        .foregroundStyle(.tertiary)
    }
    .padding(16)
    .frame(width: 160)
    .background(Color(white: 0.10))
  }

  private var photoCanvas: some View {
    ZStack {
      Color(white: 0.065)
      if editor.isOpening || editor.isRendering || editor.isExporting {
        ProgressView(
          editor.isExporting
            ? "Exporting photo…"
            : (editor.isOpening ? "Opening photo…" : "Rendering preview…")
        )
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(16)
        .zIndex(1)
      }
      if editor.paintingLocalArea {
        Text(
          "Drag on the photo to \(editor.erasingLocalArea ? "erase" : "paint") Area \(editor.selectedLocalIndex + 1)"
        )
        .font(.caption.weight(.semibold))
        .padding(9)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(16)
        .allowsHitTesting(false)
        .zIndex(1)
      }
      if editor.placingLocalArea {
        Text("Click the photo to place Area \(editor.selectedLocalIndex + 1)")
          .font(.caption.weight(.semibold))
          .padding(9)
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 7))
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .padding(16)
          .allowsHitTesting(false)
          .zIndex(1)
      }
      if let preview = editor.preview {
        if editor.compareEnabled, let original = editor.comparisonPreview {
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              Image(nsImage: preview)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width, height: geometry.size.height)
              Image(nsImage: original)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .mask(alignment: .leading) {
                  Rectangle().frame(width: geometry.size.width * editor.compareFraction)
                }
              Rectangle()
                .fill(.white.opacity(0.8))
                .frame(width: 2, height: geometry.size.height)
                .offset(x: geometry.size.width * editor.compareFraction)
              Text("BEFORE")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
              Text("AFTER")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .contentShape(Rectangle())
            .gesture(
              DragGesture(minimumDistance: 0).onChanged { value in
                editor.compareFraction = min(
                  max(value.location.x / geometry.size.width, 0.02), 0.98)
              })
          }
          .padding(24)
        } else if editor.zoom100 {
          ScrollView([.horizontal, .vertical]) {
            Image(nsImage: preview)
              .resizable()
              .interpolation(.none)
              .frame(
                width: preview.size.width / displayScale,
                height: preview.size.height / displayScale
              )
          }
        } else {
          GeometryReader { geometry in
            Image(nsImage: preview)
              .resizable()
              .scaledToFit()
              .frame(width: geometry.size.width, height: geometry.size.height)
              .contentShape(Rectangle())
              .overlay {
                if editor.showCropBounds {
                  let scale = min(
                    geometry.size.width / preview.size.width,
                    geometry.size.height / preview.size.height)
                  let imageWidth = preview.size.width * scale
                  let imageHeight = preview.size.height * scale
                  let left = (geometry.size.width - imageWidth) / 2
                  let top = (geometry.size.height - imageHeight) / 2
                  let bounds = editor.frameFreeCrop.normalizedBounds
                  Rectangle()
                    .fill(.clear)
                    .strokeBorder(.white, lineWidth: 2)
                    .background(Color.white.opacity(0.02))
                    .frame(width: imageWidth * bounds.width, height: imageHeight * bounds.height)
                    .position(
                      x: left + imageWidth * bounds.midX,
                      y: top + imageHeight * bounds.midY
                    )
                    .contentShape(Rectangle())
                    .gesture(
                      DragGesture().onChanged { value in
                        if cropDragOrigin == nil { cropDragOrigin = editor.frameFreeCrop }
                        guard let cropDragOrigin else { return }
                        editor.moveFreeCrop(
                          dx: value.translation.width / imageWidth,
                          dy: value.translation.height / imageHeight,
                          from: cropDragOrigin)
                      }.onEnded { _ in cropDragOrigin = nil })
                }
              }
              .overlay {
                if editor.paintingLocalArea && !paintDragPoints.isEmpty {
                  let scale = min(
                    geometry.size.width / preview.size.width,
                    geometry.size.height / preview.size.height)
                  let brushSize = editor.radialLights[editor.selectedLocalIndex].brushSize
                  Path { path in
                    path.addLines(paintDragPoints)
                  }
                  .stroke(
                    editor.erasingLocalArea ? .red.opacity(0.85) : .white.opacity(0.85),
                    style: StrokeStyle(
                      lineWidth: max(
                        2,
                        min(preview.size.width, preview.size.height) * scale
                          * brushSize), lineCap: .round, lineJoin: .round)
                  )
                  .allowsHitTesting(false)
                }
              }
              .simultaneousGesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                  guard editor.paintingLocalArea else { return }
                  let scale = min(
                    geometry.size.width / preview.size.width,
                    geometry.size.height / preview.size.height)
                  let width = preview.size.width * scale
                  let height = preview.size.height * scale
                  let left = (geometry.size.width - width) / 2
                  let top = (geometry.size.height - height) / 2
                  guard value.location.x >= left, value.location.x <= left + width,
                    value.location.y >= top, value.location.y <= top + height
                  else { return }
                  if paintDragPoints.isEmpty { paintDragPoints.append(value.startLocation) }
                  if paintDragPoints.count < 500,
                    let last = paintDragPoints.last,
                    hypot(last.x - value.location.x, last.y - value.location.y) >= 2
                  {
                    paintDragPoints.append(value.location)
                  }
                }.onEnded { value in
                  guard editor.paintingLocalArea else {
                    paintDragPoints.removeAll()
                    return
                  }
                  if paintDragPoints.isEmpty { paintDragPoints.append(value.location) }
                  editor.addPaintStroke(
                    displayPoints: paintDragPoints, canvasSize: geometry.size,
                    imageSize: preview.size)
                  paintDragPoints.removeAll()
                }
              )
              .gesture(
                SpatialTapGesture().onEnded { tap in
                  guard editor.placingLocalArea else { return }
                  let scale = min(
                    geometry.size.width / preview.size.width,
                    geometry.size.height / preview.size.height)
                  let imageWidth = preview.size.width * scale
                  let imageHeight = preview.size.height * scale
                  let left = (geometry.size.width - imageWidth) / 2
                  let top = (geometry.size.height - imageHeight) / 2
                  editor.placeSelectedLocalArea(
                    displayX: (tap.location.x - left) / imageWidth,
                    displayY: (tap.location.y - top) / imageHeight)
                })
          }
          .padding(24)
        }
      } else {
        ContentUnavailableView(
          "Open a photo", systemImage: "photo",
          description: Text("RAW and JPEG files are supported where macOS can decode them.")
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var inspector: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text(panel.rawValue).font(.title2.weight(.semibold))
        if let notice = editor.editRecoveryNotice {
          VStack(alignment: .leading, spacing: 6) {
            Text(notice).font(.caption).foregroundStyle(.orange)
            if let backupURL = editor.editRecoveryURL {
              Button("Reveal backup in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([backupURL])
              }
              .font(.caption)
            }
          }
        }
        if let histogram = editor.histogram {
          OutputHistogram(
            bins: histogram.bins,
            blackFraction: histogram.blackFraction,
            whiteFraction: histogram.whiteFraction
          )
        }
        switch panel {
        case .film:
          Picker("Stock", selection: $editor.stockIndex) {
            Text("Study stock").tag(0)
            Text("Portra 400 density study").tag(1)
            Text("Ektar 100 density study").tag(2)
          }
          .pickerStyle(.menu)
          if editor.stockIndex == 1 {
            Toggle("Endura paper response", isOn: $editor.enduraPaperTone)
          } else if editor.stockIndex == 2 {
            Toggle("Endura Premier paper response", isOn: $editor.premierPaperTone)
          }
          if (editor.stockIndex == 1 && editor.enduraPaperTone)
            || (editor.stockIndex == 2 && editor.premierPaperTone)
          {
            control("Paper exposure (EV)", value: $editor.paperExposure, range: -2...2)
            control("Paper strength", value: $editor.paperStrength, range: 0...1)
            Text("More paper exposure makes the print darker.")
              .font(.caption).foregroundStyle(.secondary)
          }
          control("Shot exposure (EV)", value: $editor.shotExposure, range: -3...3)
          control("Development", value: $editor.development, range: -2...2)
          control("Stock amount", value: $editor.filmAmount, range: 0...1)
          Text(
            editor.stockIndex == 1
              ? (editor.enduraPaperTone
                ? "Kodak negative and paper curves; color response is still approximate."
                : "Kodak negative-density curves with provisional positive rendering.")
              : (editor.stockIndex == 2
                ? (editor.premierPaperTone
                  ? "Kodak negative and Endura Premier paper curves; color balance is approximate."
                  : "Kodak Ektar negative-density curves with provisional positive rendering.")
                : "Exposure-dependent study stock. Film measurements will replace this model.")
          )
          .font(.caption).foregroundStyle(.secondary)
        case .develop:
          if editor.isRAWSource {
            Text("RAW white balance").font(.headline)
            control(
              "Temperature (K)", value: $editor.rawTemperature, range: 2000...12000,
              fractionDigits: 0)
            control("Tint", value: $editor.rawTint, range: -100...100)
            Divider()
            if editor.rawHighlightRecoverySupported {
              Toggle("Highlight recovery", isOn: $editor.rawHighlightRecovery)
            }
            Toggle("Linear RAW input", isOn: $editor.flatRAW)
            Text("Removes the decoder's global and shadow tone curves before film processing.")
              .font(.caption).foregroundStyle(.secondary)
            Divider()
          }
          if !editor.isRAWSource {
            Text("Rendered input balance").font(.headline)
            control("Input warmth", value: $editor.inputWarmth, range: -1...1)
            control("Input tint", value: $editor.inputTint, range: -1...1)
            Text(
              "Balances non-RAW color before film processing; clipped source detail stays lost."
            )
            .font(.caption).foregroundStyle(.secondary)
            Divider()
          }
          Text("Scene light before film").font(.headline)
          control("Shadow light (EV)", value: $editor.shadowLight, range: -2...2)
          control("Highlight light (EV)", value: $editor.highlightLight, range: -2...2)
          Text("Changes the light reaching the film model in each tonal region.")
            .font(.caption).foregroundStyle(.secondary)
          Divider()
          control("Output exposure (EV)", value: $editor.exposure, range: -3...3)
          control("Contrast", value: $editor.contrast, range: 0.5...1.5)
          control("Saturation", value: $editor.saturation, range: 0...1.5)
          control("Warmth", value: $editor.warmth, range: -1...1)
        case .color:
          Text("Color mixer").font(.headline)
          Picker("Color family", selection: $selectedColorBand) {
            ForEach(0..<ColorMixer.names.count, id: \.self) { index in
              Text(ColorMixer.names[index]).tag(index)
            }
          }
          .pickerStyle(.menu)
          control("Hue shift", value: mixerBinding(\.hue), range: -30...30)
          control("Saturation", value: mixerBinding(\.saturation), range: -1...1)
          control("Luminance (EV)", value: mixerBinding(\.luminance), range: -1...1)
          Text("The eight soft color ranges use the source pixel's hue.")
            .font(.caption).foregroundStyle(.secondary)
          Divider()
          Text("Shadows").font(.headline)
          control("Hue", value: $editor.shadowHue, range: 0...360)
          control("Strength", value: $editor.shadowStrength, range: 0...1)
          Divider()
          Text("Midtones").font(.headline)
          control("Hue", value: $editor.midHue, range: 0...360)
          control("Strength", value: $editor.midStrength, range: 0...1)
          Divider()
          Text("Highlights").font(.headline)
          control("Hue", value: $editor.highlightHue, range: 0...360)
          control("Strength", value: $editor.highlightStrength, range: 0...1)
          Divider()
          Text("Selective color").font(.headline)
          control("Target hue", value: $editor.selectiveHue, range: 0...360)
          control("Color range", value: $editor.selectiveRange, range: 10...90)
          control("Hue shift", value: $editor.selectiveShift, range: -45...45)
          control("Saturation", value: $editor.selectiveSaturation, range: -1...1)
        case .local:
          Text("Scene light areas").font(.headline)
          Picker(
            "Area",
            selection: Binding(
              get: { editor.selectedLocalIndex },
              set: { editor.selectLocalArea($0) }
            )
          ) {
            ForEach(editor.radialLights.indices, id: \.self) { index in
              Text("Area \(index + 1)").tag(index)
            }
          }
          .pickerStyle(.menu)
          HStack {
            Button("Add area", systemImage: "plus") { editor.addLocalArea() }
              .disabled(editor.radialLights.count >= 8)
            Button("Remove area", systemImage: "minus") { editor.removeLocalArea() }
              .disabled(editor.radialLights.count <= 1)
          }
          if editor.radialLights[editor.selectedLocalIndex].shape == 2 {
            HStack {
              Button(editor.paintingLocalArea ? "Stop brushing" : "Brush on photo") {
                editor.setPaintingLocalArea(!editor.paintingLocalArea)
              }
              .disabled(editor.preview == nil)
              Button("Clear strokes") { editor.clearPaint() }
                .disabled(editor.radialLights[editor.selectedLocalIndex].strokes.isEmpty)
            }
            Picker("Brush mode", selection: $editor.erasingLocalArea) {
              Text("Paint").tag(false)
              Text("Erase").tag(true)
            }
            .pickerStyle(.segmented)
          } else {
            Button(
              editor.placingLocalArea ? "Cancel placement" : "Place on photo",
              systemImage: "scope"
            ) { editor.setPlacingLocalArea(!editor.placingLocalArea) }
            .disabled(editor.preview == nil)
          }
          Toggle(
            "Show mask",
            isOn: Binding(
              get: { editor.showLocalMask },
              set: { editor.setMaskPreview($0) }))
          Picker(
            "Shape",
            selection: Binding(
              get: { editor.radialLights[editor.selectedLocalIndex].shape },
              set: { editor.setLocalShape($0) }
            )
          ) {
            Text("Radial").tag(0)
            Text("Linear gradient").tag(1)
            Text("Painted brush").tag(2)
          }
          .pickerStyle(.menu)
          Toggle("Invert area", isOn: localBoolBinding(\.inverted))
          control("Exposure (EV)", value: localBinding(\.exposure), range: -2...2)
          control("Warmth", value: localBinding(\.warmth), range: -1...1)
          control("Tint", value: localBinding(\.tint), range: -1...1)
          if editor.radialLights[editor.selectedLocalIndex].shape == 2 {
            control("Brush size", value: localBinding(\.brushSize), range: 0.003...0.15)
            control("Soft edge", value: localBinding(\.feather), range: 0...1)
          } else {
            control("Horizontal center", value: localBinding(\.centerX), range: 0...1)
            control("Vertical center", value: localBinding(\.centerY), range: 0...1)
            control(
              editor.radialLights[editor.selectedLocalIndex].shape == 1 ? "Transition" : "Size",
              value: localBinding(\.radius), range: 0.05...0.8)
            if editor.radialLights[editor.selectedLocalIndex].shape == 1 {
              control("Direction (source °)", value: localBinding(\.angle), range: -180...180)
            } else {
              control("Feather", value: localBinding(\.feather), range: 0.05...1)
            }
          }
          Text(
            "Each area changes light and color before film processing. Painted strokes follow source pixels through framing. A new linear area starts vertically in the displayed photo. Show mask is temporary; zero exposure, warmth, and tint disable the selected area."
          )
          .font(.caption).foregroundStyle(.secondary)
        case .framing:
          HStack {
            Button("Rotate left", systemImage: "rotate.left") { editor.rotateFrame(-1) }
            Button("Rotate right", systemImage: "rotate.right") { editor.rotateFrame(1) }
          }
          control("Straighten (°)", value: $editor.frameStraighten, range: -15...15)
          Picker("Crop ratio", selection: $editor.frameAspect) {
            Text("Original").tag(0)
            Text("Square 1:1").tag(1)
            Text("Portrait 4:5").tag(2)
            Text("Landscape 3:2").tag(3)
            Text("Wide 16:9").tag(4)
            Text("Freeform").tag(5)
          }
          .pickerStyle(.menu)
          if editor.frameAspect == 5 {
            Toggle(
              "Show crop bounds",
              isOn: Binding(
                get: { editor.showCropBounds },
                set: { editor.setCropBoundsPreview($0) }))
            control("Width", value: freeCropBinding(\.width), range: 0.1...1)
            control("Height", value: freeCropBinding(\.height), range: 0.1...1)
            control("Horizontal center", value: freeCropBinding(\.centerX), range: 0...1)
            control("Vertical center", value: freeCropBinding(\.centerY), range: 0...1)
            Text("Show bounds to move the rectangle on the photo. Export uses the selected crop.")
              .font(.caption).foregroundStyle(.secondary)
          } else if editor.frameAspect != 0 {
            control("Horizontal position", value: $editor.frameOffsetX, range: -1...1)
            control("Vertical position", value: $editor.frameOffsetY, range: -1...1)
          }
          Text("Framing is saved with this photo and applied at full resolution on export.")
            .font(.caption).foregroundStyle(.secondary)
        case .texture:
          control("Grain", value: $editor.grain, range: 0...1)
          control("Halation", value: $editor.halation, range: 0...1)
          control("Edge detail", value: $editor.acutance, range: 0...1)
          Text("Inspect texture and edge detail at 100% zoom.")
            .font(.caption).foregroundStyle(.secondary)
        }
        if let error = editor.error {
          Divider()
          Text(error).foregroundStyle(.red).font(.caption)
        }
      }
      .padding(22)
    }
    .frame(width: 310)
    .background(Color(white: 0.11))
  }

  private func freeCropBinding(_ keyPath: WritableKeyPath<FreeCrop, Double>) -> Binding<Double> {
    Binding(
      get: { editor.frameFreeCrop[keyPath: keyPath] },
      set: { value in
        editor.frameFreeCrop[keyPath: keyPath] = value
        editor.editsChanged()
      }
    )
  }

  private func localBinding(_ keyPath: WritableKeyPath<RadialAdjustment, Double>) -> Binding<Double>
  {
    Binding(
      get: { editor.radialLights[editor.selectedLocalIndex][keyPath: keyPath] },
      set: { value in
        editor.radialLights[editor.selectedLocalIndex][keyPath: keyPath] = value
        editor.editsChanged()
      }
    )
  }

  private func localBoolBinding(_ keyPath: WritableKeyPath<RadialAdjustment, Bool>) -> Binding<Bool>
  {
    Binding(
      get: { editor.radialLights[editor.selectedLocalIndex][keyPath: keyPath] },
      set: { value in
        editor.radialLights[editor.selectedLocalIndex][keyPath: keyPath] = value
        editor.editsChanged()
      }
    )
  }

  private func mixerBinding(_ keyPath: WritableKeyPath<ColorMix, Double>) -> Binding<Double> {
    Binding(
      get: { editor.mixer[selectedColorBand][keyPath: keyPath] },
      set: { value in
        editor.mixer[selectedColorBand][keyPath: keyPath] = value
        editor.editsChanged()
      }
    )
  }

  private func control(
    _ title: String, value: Binding<Double>, range: ClosedRange<Double>, fractionDigits: Int = 2
  ) -> some View {
    VStack(alignment: .leading) {
      HStack {
        Text(title)
        Spacer()
        Text(value.wrappedValue.formatted(.number.precision(.fractionLength(fractionDigits))))
          .monospacedDigit()
      }
      .font(.subheadline)
      Slider(value: value, in: range)
    }
  }
}
