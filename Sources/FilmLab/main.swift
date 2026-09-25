import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

@main
struct FilmLabApp: App {
  @State private var editor = PhotoEditor()
  @State private var showingImporter = false

  var body: some Scene {
    WindowGroup("FilmLab") {
      ContentView(editor: editor, showingImporter: $showingImporter)
        .frame(minWidth: 960, minHeight: 600)
        .preferredColorScheme(.dark)
    }
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("Open Photo…") { showingImporter = true }
          .keyboardShortcut("o", modifiers: .command)
      }
    }
  }
}

struct PhotoEdits: Codable, Equatable {
  var exposure = 0.0
  var contrast = 1.0
  var saturation = 1.0
  var vibrance = 0.0
  var warmth = 0.0
  var tint = 0.0
  var curveShadow = 0.0
  var curveMidtone = 0.0
  var curveHighlight = 0.0
  var outputShoulder = 0.0
  var inputWarmth = 0.0
  var inputTint = 0.0
  var inputTone = 1.0
  var inputNeutralBalance = InputNeutralBalance()
  var filmLightWarmth = 0.0
  var filmLightTint = 0.0
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
  var grainSize = 1.0
  var grainSeed = 0.0
  var halation = 0.0
  var acutance = 0.0
  var colorTimingVersion = 2
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
  var mixerVersion = 2
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

  static func defaults(forRAW isRAW: Bool, grainSeed: Double = 0) -> PhotoEdits {
    var edits = PhotoEdits()
    edits.filmAmount = isRAW ? 1.0 : 0.7
    edits.flatRAW = isRAW
    edits.grainSeed = grainSeed
    return edits
  }

  static func transferring(_ copied: PhotoEdits, onto destination: PhotoEdits) -> PhotoEdits {
    var result = copied
    result.flatRAW = destination.flatRAW
    result.rawHighlightRecovery = destination.rawHighlightRecovery
    result.rawTemperature = destination.rawTemperature
    result.rawTint = destination.rawTint
    result.inputWarmth = destination.inputWarmth
    result.inputTint = destination.inputTint
    result.inputTone = destination.inputTone
    result.inputNeutralBalance = destination.inputNeutralBalance
    result.grainSeed = destination.grainSeed
    return result
  }

  static func transferring(
    _ copied: PhotoEdits, panel: EditorPanel, onto destination: PhotoEdits
  ) -> PhotoEdits {
    let safeSource = transferring(copied, onto: destination)
    var result = destination.replacing(panel, with: safeSource)
    if panel == .color {
      result.colorTimingVersion = copied.colorTimingVersion
      result.mixerVersion = copied.mixerVersion
    }
    return result
  }

  func resetting(_ panel: EditorPanel, isRAW: Bool) -> PhotoEdits {
    replacing(panel, with: PhotoEdits.defaults(forRAW: isRAW))
  }

  func replacing(_ panel: EditorPanel, with source: PhotoEdits) -> PhotoEdits {
    var result = self
    switch panel {
    case .film:
      result.stockIndex = source.stockIndex
      result.enduraPaperTone = source.enduraPaperTone
      result.premierPaperTone = source.premierPaperTone
      result.paperStrength = source.paperStrength
      result.paperExposure = source.paperExposure
      result.shotExposure = source.shotExposure
      result.development = source.development
      result.filmAmount = source.filmAmount
    case .develop:
      result.inputNeutralBalance = source.inputNeutralBalance
      result.flatRAW = source.flatRAW
      result.rawHighlightRecovery = source.rawHighlightRecovery
      result.rawTemperature = source.rawTemperature
      result.rawTint = source.rawTint
      result.inputTone = source.inputTone
      result.inputWarmth = source.inputWarmth
      result.inputTint = source.inputTint
      result.shadowLight = source.shadowLight
      result.highlightLight = source.highlightLight
      result.filmLightWarmth = source.filmLightWarmth
      result.filmLightTint = source.filmLightTint
      result.exposure = source.exposure
      result.contrast = source.contrast
      result.saturation = source.saturation
      result.warmth = source.warmth
      result.tint = source.tint
      result.curveShadow = source.curveShadow
      result.curveMidtone = source.curveMidtone
      result.curveHighlight = source.curveHighlight
      result.outputShoulder = source.outputShoulder
    case .color:
      result.vibrance = source.vibrance
      result.shadowHue = source.shadowHue
      result.shadowStrength = source.shadowStrength
      result.midHue = source.midHue
      result.midStrength = source.midStrength
      result.highlightHue = source.highlightHue
      result.highlightStrength = source.highlightStrength
      result.selectiveHue = source.selectiveHue
      result.selectiveRange = source.selectiveRange
      result.selectiveShift = source.selectiveShift
      result.selectiveSaturation = source.selectiveSaturation
      result.mixer = source.mixer
    case .local:
      result.radialLights = source.radialLights
    case .texture:
      result.grain = source.grain
      result.grainSize = source.grainSize
      result.halation = source.halation
      result.acutance = source.acutance
    case .framing:
      result.frameRotation = source.frameRotation
      result.frameStraighten = source.frameStraighten
      result.frameAspect = source.frameAspect
      result.frameOffsetX = source.frameOffsetX
      result.frameOffsetY = source.frameOffsetY
      result.frameFreeCrop = source.frameFreeCrop
    }
    return result
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    exposure = try values.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
    contrast = try values.decodeIfPresent(Double.self, forKey: .contrast) ?? 1
    saturation = try values.decodeIfPresent(Double.self, forKey: .saturation) ?? 1
    vibrance = try values.decodeIfPresent(Double.self, forKey: .vibrance) ?? 0
    warmth = try values.decodeIfPresent(Double.self, forKey: .warmth) ?? 0
    tint = try values.decodeIfPresent(Double.self, forKey: .tint) ?? 0
    curveShadow = try values.decodeIfPresent(Double.self, forKey: .curveShadow) ?? 0
    curveMidtone = try values.decodeIfPresent(Double.self, forKey: .curveMidtone) ?? 0
    curveHighlight = try values.decodeIfPresent(Double.self, forKey: .curveHighlight) ?? 0
    outputShoulder = try values.decodeIfPresent(Double.self, forKey: .outputShoulder) ?? 0
    inputWarmth = try values.decodeIfPresent(Double.self, forKey: .inputWarmth) ?? 0
    inputTint = try values.decodeIfPresent(Double.self, forKey: .inputTint) ?? 0
    inputTone = try values.decodeIfPresent(Double.self, forKey: .inputTone) ?? 1
    inputNeutralBalance =
      try values.decodeIfPresent(InputNeutralBalance.self, forKey: .inputNeutralBalance)
      ?? InputNeutralBalance()
    filmLightWarmth = try values.decodeIfPresent(Double.self, forKey: .filmLightWarmth) ?? 0
    filmLightTint = try values.decodeIfPresent(Double.self, forKey: .filmLightTint) ?? 0
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
    grainSize = try values.decodeIfPresent(Double.self, forKey: .grainSize) ?? 0
    grainSeed = try values.decodeIfPresent(Double.self, forKey: .grainSeed) ?? 0
    halation = try values.decodeIfPresent(Double.self, forKey: .halation) ?? 0
    acutance = try values.decodeIfPresent(Double.self, forKey: .acutance) ?? 0
    colorTimingVersion = try values.decodeIfPresent(Int.self, forKey: .colorTimingVersion) ?? 1
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
    mixerVersion = try values.decodeIfPresent(Int.self, forKey: .mixerVersion) ?? 1
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

private struct BatchSettingsChange: Codable {
  let path: String
  let location: EditRecordLocation
  let before: PhotoEdits
  let after: PhotoEdits
}

private struct BatchSettingsHistory: Codable {
  var version = 1
  var changes: [BatchSettingsChange] = []

  init(changes: [BatchSettingsChange] = []) {
    self.changes = changes
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    version = try values.decode(Int.self, forKey: .version)
    guard version == 1 else {
      throw DecodingError.dataCorruptedError(
        forKey: .version, in: values, debugDescription: "Unsupported batch history version")
    }
    changes = try values.decode([BatchSettingsChange].self, forKey: .changes)
  }
}

private struct BatchSettingsBackup: Codable {
  let sourcePath: String
  let previous: PhotoEdits
}

private struct BatchSettingsResult {
  let applied: Int
  let skipped: Int
  let failures: [String]

  var summary: String {
    var parts = ["Applied settings to \(applied) photo\(applied == 1 ? "" : "s")."]
    if skipped > 0 { parts.append("Skipped \(skipped) unchanged or active photos.") }
    if !failures.isEmpty { parts.append("Could not update: \(failures.joined(separator: ", ")).") }
    return parts.joined(separator: " ")
  }
}

private struct BatchExportResult {
  var exported = 0
  var failed: [String] = []
  var cancelled = false

  var summary: String {
    var parts = ["Exported \(exported) photo\(exported == 1 ? "" : "s")."]
    if cancelled { parts.append("Export stopped.") }
    if !failed.isEmpty { parts.append("Could not export: \(failed.joined(separator: ", ")).") }
    return parts.joined(separator: " ")
  }
}

@MainActor @Observable
final class PhotoEditor {
  var sourceURL: URL?
  var preview: NSImage?
  var comparisonPreview: NSImage?
  var histogram: PreviewHistogram?
  var jpegChannelNearWhiteFraction: Double?
  var compareEnabled = false
  var compareFraction = 0.5
  var exposure = 0.0
  var contrast = 1.0
  var saturation = 1.0
  var vibrance = 0.0
  var warmth = 0.0
  var tint = 0.0
  var curveShadow = 0.0
  var curveMidtone = 0.0
  var curveHighlight = 0.0
  var outputShoulder = 0.0
  var inputWarmth = 0.0
  var inputTint = 0.0
  var inputTone = 1.0
  var inputNeutralBalance = InputNeutralBalance()
  var filmLightWarmth = 0.0
  var filmLightTint = 0.0
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
  var pickingLocalHue = false
  var localHueNotice: String?
  var pickingLocalTone = false
  var localToneNotice: String?
  var pickingNeutralArea = false
  var neutralNotice: String?
  var paintingLocalArea = false
  var erasingLocalArea = false
  var development = 0.0
  var grain = 0.0
  var grainSize = 1.0
  var grainSeed = 0.0
  var halation = 0.0
  var acutance = 0.0
  var colorTimingVersion = 2
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
  var mixerVersion = 2
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
  var showGamutWarning = false
  var highPrecisionPreview = UserDefaults.standard.bool(forKey: "FilmLab.highPrecisionPreview")
  var inspectPixel = false
  var pixelReadout: PixelReadout?
  var selectedPixel: CGPoint?
  var showLocalMask = false
  var zoom100 = false
  var isRendering = false
  var isOpening = false
  var isExporting = false
  var recentPaths: [String] =
    (UserDefaults.standard.stringArray(forKey: "FilmLab.recentPhotos") ?? [])
    .filter { FileManager.default.fileExists(atPath: $0) }

  private var source: CIImage?
  private var sourceEditLocation: EditRecordLocation?
  private var didAttemptResume = false
  private let lastPhotoKey = "FilmLab.lastPhotoPath"
  private let recentPhotosKey = "FilmLab.recentPhotos"
  private let settingsPasteboardType = NSPasteboard.PasteboardType("app.filmlab.edits+json")
  private var copiedSettings: PhotoEdits?
  private var copiedWorkspace: (panel: EditorPanel, edits: PhotoEdits)?
  private var decodedFlatRAW = false
  private var decodedHighlightRecovery = true
  private var decodedRawTemperature = 6500.0
  private var decodedRawTint = 0.0
  private var cameraRawTemperature = 6500.0
  private var cameraRawTint = 0.0
  private var sourceIsRAW = false
  private var editSavingBlocked = false
  private var lastBatchChanges: [BatchSettingsChange] = []
  private var batchHistorySavingBlocked = false
  var batchHistoryNotice: String?
  var canUndoBatch: Bool { !lastBatchChanges.isEmpty }
  var batchChangedPaths: [String] { lastBatchChanges.map(\.path) }
  var isRAWSource: Bool { sourceURL != nil && sourceIsRAW }
  var canExport: Bool {
    preview != nil && !isOpening && rawDecodeTask == nil && !isExporting
  }
  var canBatchExport: Bool { !isOpening && rawDecodeTask == nil && !isExporting }
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
  private let pixelSampler = PixelSampler()
  private let neutralPatchSampler = NeutralPatchSampler()
  private var pixelTask: Task<Void, Never>?
  private var neutralTask: Task<Void, Never>?
  private var localHueTask: Task<Void, Never>?
  private var localToneTask: Task<Void, Never>?
  private var pixelVersion = 0
  private var neutralVersion = 0
  private var localHueVersion = 0
  private var localToneVersion = 0
  private let exporter = ImageExporter()
  private static let thumbnailDecoder = ImageDecoder()

  private static var batchHistoryURL: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab/BatchHistory.json")
  }

  init() {
    let loaded = SavedEditStore.load(
      from: Self.batchHistoryURL, defaultValue: BatchSettingsHistory())
    lastBatchChanges = loaded.value.changes
    batchHistorySavingBlocked = !loaded.canSave
    batchHistoryNotice = loaded.notice
  }

  private func saveBatchHistory() -> Bool {
    guard !batchHistorySavingBlocked else {
      batchHistoryNotice = "Batch undo history could not be read. Saving it is paused."
      return false
    }
    do {
      try SavedEditStore.save(
        BatchSettingsHistory(changes: lastBatchChanges), to: Self.batchHistoryURL)
      batchHistoryNotice = nil
      return true
    } catch {
      batchHistoryNotice = "Could not save batch undo history: \(error.localizedDescription)"
      return false
    }
  }

  // Scene-linear RGB enters this kernel in the context's extended linear working space.
  // This is a provisional response model, not a measured emulsion profile.
  private let filmKernel = FilmKernels.kernel("filmResponse")
  private let sceneLightKernel = FilmKernels.kernel("shapeSceneLight")
  private let measuredNegativeKernel = FilmKernels.kernel("measuredNegative")
  private let portraPositiveKernel = FilmKernels.kernel("portraPositive")
  private let renderedInputToneKernel = FilmKernels.kernel("renderedInputTone")
  private let outputShoulderKernel = FilmKernels.kernel("outputShoulder")
  private let outputToneCurveKernel = FilmKernels.kernel("outputToneCurve")
  private let vibranceKernel = FilmKernels.kernel("vibrance")

  func open(_ url: URL) {
    didAttemptResume = true
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
        let editLocation = EditRecordLocator.locate(
          sourceURL: url, directory: editsDirectory)
        let loaded = SavedEditStore.load(
          from: editLocation.primaryURL, fallbackURL: editLocation.pathURL,
          defaultValue: PhotoEdits.defaults(
            forRAW: isRAW, grainSeed: EditRecordLocator.grainSeed(for: url)))
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
        saveTask?.cancel()
        guard sourceURL == nil || saveEdits() else { return }
        rawDecodeTask?.cancel()
        rawDecodeTask = nil
        rawDecodeVersion += 1
        previewTask?.cancel()
        renderVersion += 1
        pixelTask?.cancel()
        pixelVersion += 1
        pixelReadout = nil
        selectedPixel = nil
        neutralTask?.cancel()
        neutralVersion += 1
        pickingNeutralArea = false
        neutralNotice = nil
        setPickingLocalHue(false)
        localHueNotice = nil
        setPickingLocalTone(false)
        localToneNotice = nil
        if let scopedURL { scopedURL.stopAccessingSecurityScopedResource() }
        scopedURL = access ? url : nil
        retainAccess = access
        var notices = [loaded.notice, editLocation.migrationNotice].compactMap { $0 }
        if loaded.notice == nil, editLocation.primaryURL != editLocation.pathURL,
          !FileManager.default.fileExists(atPath: editLocation.pathURL.path)
        {
          do {
            try SavedEditStore.save(saved, to: editLocation.pathURL)
          } catch {
            notices.append(
              "Could not create a path backup for this photo's edits: \(error.localizedDescription)"
            )
          }
        }
        source = image
        sourceURL = url
        sourceEditLocation = editLocation
        jpegChannelNearWhiteFraction = decoded.jpegChannelNearWhiteFraction
        editRecoveryNotice = notices.isEmpty ? nil : notices.joined(separator: " ")
        editRecoveryURL = loaded.backupURL
        editSavingBlocked = !loaded.canSave
        UserDefaults.standard.set(url.standardizedFileURL.path, forKey: lastPhotoKey)
        rememberRecentPhoto(url)
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

  func resumeLastPhoto(in availablePaths: [String], remembered: String?) {
    guard !didAttemptResume else { return }
    didAttemptResume = true
    guard let lastPath = UserDefaults.standard.string(forKey: lastPhotoKey) else {
      closePhoto()
      return
    }
    let preferred = remembered.flatMap { availablePaths.contains($0) ? $0 : nil } ?? lastPath
    let selected = CatalogPhotoSelection.preferredPath(
      in: availablePaths, current: nil, remembered: preferred)
    if let selected {
      open(URL(fileURLWithPath: selected))
    } else {
      closePhoto()
    }
  }

  @discardableResult
  func closePhoto() -> Bool {
    saveTask?.cancel()
    guard flushEdits() else { return false }
    openTask?.cancel()
    openTask = nil
    openVersion += 1
    rawDecodeTask?.cancel()
    rawDecodeTask = nil
    rawDecodeVersion += 1
    previewTask?.cancel()
    previewTask = nil
    renderVersion += 1
    historyTask?.cancel()
    historyOpen = false
    undoStack.removeAll()
    redoStack.removeAll()
    pixelTask?.cancel()
    pixelVersion += 1
    neutralTask?.cancel()
    neutralVersion += 1
    localHueTask?.cancel()
    localHueVersion += 1
    localToneTask?.cancel()
    localToneVersion += 1
    if let scopedURL { scopedURL.stopAccessingSecurityScopedResource() }
    scopedURL = nil
    source = nil
    sourceURL = nil
    sourceEditLocation = nil
    preview = nil
    comparisonPreview = nil
    histogram = nil
    jpegChannelNearWhiteFraction = nil
    pixelReadout = nil
    selectedPixel = nil
    editRecoveryNotice = nil
    editRecoveryURL = nil
    editSavingBlocked = false
    isOpening = false
    isRendering = false
    compareEnabled = false
    showOriginal = false
    showLocalMask = false
    showCropBounds = false
    zoom100 = false
    placingLocalArea = false
    paintingLocalArea = false
    erasingLocalArea = false
    pickingNeutralArea = false
    pickingLocalHue = false
    pickingLocalTone = false
    error = nil
    return true
  }

  private func rememberRecentPhoto(_ url: URL) {
    let path = url.standardizedFileURL.path
    recentPaths.removeAll { $0 == path || !FileManager.default.fileExists(atPath: $0) }
    recentPaths.insert(path, at: 0)
    recentPaths = Array(recentPaths.prefix(10))
    UserDefaults.standard.set(recentPaths, forKey: recentPhotosKey)
  }

  func clearRecentPhotos() {
    recentPaths = []
    UserDefaults.standard.removeObject(forKey: recentPhotosKey)
    UserDefaults.standard.removeObject(forKey: lastPhotoKey)
  }

  @discardableResult
  func flushEdits() -> Bool {
    saveTask?.cancel()
    return saveEdits()
  }

  private var editsDirectory: URL {
    return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab/Edits", isDirectory: true)
  }

  private func restoreEdits(_ saved: PhotoEdits) {
    exposure = saved.exposure
    contrast = saved.contrast
    saturation = saved.saturation
    vibrance = saved.vibrance
    warmth = saved.warmth
    tint = saved.tint
    curveShadow = saved.curveShadow
    curveMidtone = saved.curveMidtone
    curveHighlight = saved.curveHighlight
    outputShoulder = saved.outputShoulder
    inputWarmth = saved.inputWarmth
    inputTint = saved.inputTint
    inputTone = saved.inputTone
    inputNeutralBalance = saved.inputNeutralBalance
    filmLightWarmth = saved.filmLightWarmth
    filmLightTint = saved.filmLightTint
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
    grainSize = saved.grainSize
    grainSeed = saved.grainSeed
    halation = saved.halation
    acutance = saved.acutance
    colorTimingVersion = saved.colorTimingVersion
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
    mixerVersion = saved.mixerVersion
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
    neutralTask?.cancel()
    neutralVersion += 1
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
    edits.vibrance = vibrance
    edits.warmth = warmth
    edits.tint = tint
    edits.curveShadow = curveShadow
    edits.curveMidtone = curveMidtone
    edits.curveHighlight = curveHighlight
    edits.outputShoulder = outputShoulder
    edits.inputWarmth = inputWarmth
    edits.inputTint = inputTint
    edits.inputTone = inputTone
    edits.inputNeutralBalance = inputNeutralBalance
    edits.filmLightWarmth = filmLightWarmth
    edits.filmLightTint = filmLightTint
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
    edits.grainSize = grainSize
    edits.grainSeed = grainSeed
    edits.halation = halation
    edits.acutance = acutance
    edits.colorTimingVersion = colorTimingVersion
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
    edits.mixerVersion = mixerVersion
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

  @discardableResult
  private func saveEdits() -> Bool {
    guard sourceURL != nil, let sourceEditLocation else { return true }
    guard !editSavingBlocked else { return false }
    let edits = currentEdits()
    do {
      try SavedEditStore.save(edits, to: sourceEditLocation.primaryURL)
      if sourceEditLocation.pathURL != sourceEditLocation.primaryURL {
        try SavedEditStore.save(edits, to: sourceEditLocation.pathURL)
      }
      return true
    } catch {
      self.error = "Could not save edits: \(error.localizedDescription)"
      return false
    }
  }

  func copySettings() {
    guard sourceURL != nil else { return }
    do {
      let settings = currentEdits()
      let data = try JSONEncoder().encode(settings)
      copiedSettings = settings
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setData(data, forType: settingsPasteboardType)
      error = nil
    } catch {
      self.error = "Could not copy settings: \(error.localizedDescription)"
    }
  }

  func pasteSettings() {
    guard sourceURL != nil else { return }
    guard let copied = settingsForPaste() else {
      error = "Copy settings from a FilmLab photo first."
      return
    }
    applyTransferredSettings(copied)
  }

  fileprivate func copyWorkspace(_ panel: EditorPanel) {
    guard sourceURL != nil else { return }
    copiedWorkspace = (panel, currentEdits())
  }

  fileprivate func canPasteWorkspace(_ panel: EditorPanel) -> Bool {
    sourceURL != nil && copiedWorkspace?.panel == panel
  }

  fileprivate var copiedWorkspaceName: String? { copiedWorkspace?.panel.rawValue }

  fileprivate func pasteWorkspace(_ panel: EditorPanel) {
    guard canPasteWorkspace(panel), let copied = copiedWorkspace?.edits else { return }
    historyTask?.cancel()
    historyOpen = false
    let current = currentEdits()
    let result = PhotoEdits.transferring(copied, panel: panel, onto: current)
    guard result != current else { return }
    restoreEdits(result)
    if panel == .local {
      selectedLocalIndex = 0
      showLocalMask = false
      placingLocalArea = false
      paintingLocalArea = false
      erasingLocalArea = false
    }
    if panel == .framing { showCropBounds = false }
    editsChanged()
  }

  private func settingsForPaste() -> PhotoEdits? {
    if let copiedSettings { return copiedSettings }
    guard let data = NSPasteboard.general.data(forType: settingsPasteboardType) else { return nil }
    return try? JSONDecoder().decode(PhotoEdits.self, from: data)
  }

  func pasteSettings(to paths: [String], workspaceOnly: Bool = false) async -> String {
    let workspace = workspaceOnly ? copiedWorkspace : nil
    if workspaceOnly && workspace == nil { return "Copy a workspace first." }
    guard let copied = workspace?.edits ?? settingsForPaste() else {
      return "Copy settings from a FilmLab photo first."
    }
    guard !paths.isEmpty else { return "Select photos in the catalog first." }
    let decoder = ImageDecoder()
    var changes: [BatchSettingsChange] = []
    var skipped = 0
    var failures: [String] = []
    for path in paths {
      if sourceURL?.standardizedFileURL.path == path {
        skipped += 1
        continue
      }
      guard FileManager.default.fileExists(atPath: path) else {
        failures.append(URL(fileURLWithPath: path).lastPathComponent)
        continue
      }
      let url = URL(fileURLWithPath: path)
      let access = url.startAccessingSecurityScopedResource()
      let isRAW = await decoder.isRAWFile(url)
      let location = EditRecordLocator.locate(sourceURL: url, directory: editsDirectory)
      let loaded = SavedEditStore.load(
        from: location.primaryURL, fallbackURL: location.pathURL,
        defaultValue: PhotoEdits.defaults(
          forRAW: isRAW, grainSeed: EditRecordLocator.grainSeed(for: url)))
      guard loaded.canSave, loaded.notice == nil else {
        if access { url.stopAccessingSecurityScopedResource() }
        failures.append(url.lastPathComponent)
        continue
      }
      let updated: PhotoEdits
      if let workspace {
        updated = PhotoEdits.transferring(copied, panel: workspace.panel, onto: loaded.value)
      } else {
        updated = PhotoEdits.transferring(copied, onto: loaded.value)
      }
      if updated == loaded.value {
        skipped += 1
      } else {
        do {
          let backupURL = editsDirectory.appendingPathComponent("BatchBackups", isDirectory: true)
            .appendingPathComponent("\(UUID().uuidString).json")
          try SavedEditStore.save(
            BatchSettingsBackup(sourcePath: path, previous: loaded.value), to: backupURL)
          try SavedEditStore.save(updated, to: location.pathURL)
          if location.primaryURL != location.pathURL {
            try SavedEditStore.save(updated, to: location.primaryURL)
          }
          changes.append(
            BatchSettingsChange(
              path: path, location: location, before: loaded.value, after: updated))
        } catch {
          try? SavedEditStore.save(loaded.value, to: location.pathURL)
          if location.primaryURL != location.pathURL {
            try? SavedEditStore.save(loaded.value, to: location.primaryURL)
          }
          failures.append(url.lastPathComponent)
        }
      }
      if access { url.stopAccessingSecurityScopedResource() }
      await Task.yield()
    }
    if !changes.isEmpty {
      lastBatchChanges = changes
    }
    var message = BatchSettingsResult(
      applied: changes.count, skipped: skipped, failures: failures
    ).summary
    if !changes.isEmpty, !saveBatchHistory() {
      message += " Undo is available now but may not survive an app restart."
    }
    return message
  }

  func undoLastBatch() -> String {
    guard !lastBatchChanges.isEmpty else { return "No batch edit to undo." }
    var restored = 0
    var failures: [String] = []
    var remaining: [BatchSettingsChange] = []
    for change in lastBatchChanges {
      let url = URL(fileURLWithPath: change.path)
      guard FileManager.default.fileExists(atPath: change.path) else {
        failures.append(url.lastPathComponent)
        remaining.append(change)
        continue
      }
      let currentLocation = EditRecordLocator.locate(sourceURL: url, directory: editsDirectory)
      guard currentLocation.primaryURL == change.location.primaryURL else {
        failures.append(url.lastPathComponent)
        remaining.append(change)
        continue
      }
      let current: PhotoEdits
      if sourceURL?.standardizedFileURL.path == change.path {
        current = currentEdits()
      } else {
        let loaded = SavedEditStore.load(
          from: change.location.primaryURL, fallbackURL: change.location.pathURL,
          defaultValue: change.after)
        guard loaded.canSave else {
          failures.append(url.lastPathComponent)
          remaining.append(change)
          continue
        }
        current = loaded.value
      }
      guard current == change.after else {
        failures.append(url.lastPathComponent)
        remaining.append(change)
        continue
      }
      do {
        try SavedEditStore.save(change.before, to: change.location.pathURL)
        if change.location.primaryURL != change.location.pathURL {
          try SavedEditStore.save(change.before, to: change.location.primaryURL)
        }
        if sourceURL?.standardizedFileURL.path == change.path {
          restoreEdits(change.before)
          editsChanged()
          flushEdits()
        }
        restored += 1
      } catch {
        failures.append(url.lastPathComponent)
        remaining.append(change)
      }
    }
    lastBatchChanges = remaining
    let historySaved = saveBatchHistory()
    var message = "Restored settings on \(restored) photo\(restored == 1 ? "" : "s")."
    if !failures.isEmpty {
      message += " Could not restore: \(failures.joined(separator: ", "))."
    }
    if !historySaved { message += " Undo history could not be saved." }
    return message
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
    settings.inputTone = 1
    settings.inputNeutralBalance = InputNeutralBalance()
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
    let copied = PhotoEdits.transferring(transferred, onto: currentEdits())
    restoreEdits(copied)
    showCropBounds = false
    showLocalMask = false
    placingLocalArea = false
    paintingLocalArea = false
    setPickingNeutralArea(false)
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
    vibrance = defaults.vibrance
    warmth = defaults.warmth
    tint = defaults.tint
    curveShadow = defaults.curveShadow
    curveMidtone = defaults.curveMidtone
    curveHighlight = defaults.curveHighlight
    outputShoulder = defaults.outputShoulder
    inputWarmth = defaults.inputWarmth
    inputTint = defaults.inputTint
    inputTone = defaults.inputTone
    inputNeutralBalance = defaults.inputNeutralBalance
    filmLightWarmth = defaults.filmLightWarmth
    filmLightTint = defaults.filmLightTint
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
    grainSize = defaults.grainSize
    grainSeed = sourceURL.map { EditRecordLocator.grainSeed(for: $0) } ?? 0
    halation = defaults.halation
    acutance = defaults.acutance
    colorTimingVersion = defaults.colorTimingVersion
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
    mixerVersion = defaults.mixerVersion
    frameRotation = defaults.frameRotation
    frameStraighten = defaults.frameStraighten
    frameAspect = defaults.frameAspect
    frameOffsetX = defaults.frameOffsetX
    frameOffsetY = defaults.frameOffsetY
    frameFreeCrop = defaults.frameFreeCrop
    showCropBounds = false
    paintingLocalArea = false
    setPickingNeutralArea(false)
    flatRAW = defaults.flatRAW
    rawHighlightRecovery = defaults.rawHighlightRecovery
    rawTemperature = cameraRawTemperature
    rawTint = cameraRawTint
    showOriginal = false
    showLocalMask = false
    compareEnabled = false
    editsChanged()
  }

  fileprivate func panelNeedsReset(_ panel: EditorPanel) -> Bool {
    let current = currentEdits()
    var reset = current.resetting(panel, isRAW: isRAWSource)
    if panel == .develop && isRAWSource {
      reset.rawTemperature = cameraRawTemperature
      reset.rawTint = cameraRawTint
    }
    return reset != current
  }

  fileprivate func resetPanel(_ panel: EditorPanel) {
    guard sourceURL != nil, panelNeedsReset(panel) else { return }
    historyTask?.cancel()
    historyOpen = false
    restoreEdits(currentEdits().resetting(panel, isRAW: isRAWSource))
    if panel == .local {
      selectedLocalIndex = 0
      showLocalMask = false
      placingLocalArea = false
      paintingLocalArea = false
      erasingLocalArea = false
    }
    if panel == .framing { showCropBounds = false }
    if panel == .develop { setPickingNeutralArea(false) }
    editsChanged()
    if panel == .develop { rawModeChanged() }
  }

  func toggleBeforeAfter() {
    setPickingNeutralArea(false)
    compareEnabled = false
    showLocalMask = false
    showCropBounds = false
    placingLocalArea = false
    paintingLocalArea = false
    showOriginal.toggle()
    renderPreview()
  }

  func toggleZoom() {
    setPickingNeutralArea(false)
    placingLocalArea = false
    paintingLocalArea = false
    showCropBounds = false
    compareEnabled = false
    zoom100.toggle()
    renderPreview()
  }

  func toggleCompare() {
    setPickingNeutralArea(false)
    compareEnabled.toggle()
    showLocalMask = false
    showCropBounds = false
    placingLocalArea = false
    paintingLocalArea = false
    showOriginal = false
    zoom100 = false
    renderPreview()
  }

  func setGamutWarning(_ visible: Bool) {
    showGamutWarning = visible
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
    setPickingLocalHue(false)
    setPickingLocalTone(false)
    selectedLocalIndex = index
    localHueNotice = nil
    localToneNotice = nil
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
    setPickingNeutralArea(false)
    setPickingLocalHue(false)
    setPickingLocalTone(false)
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
    setPickingNeutralArea(false)
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
    setPickingNeutralArea(false)
    setPickingLocalHue(false)
    setPickingLocalTone(false)
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
    setPickingNeutralArea(false)
    setPickingLocalHue(false)
    setPickingLocalTone(false)
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
    guard let image = imageBeforeLocalArea(selectedLocalIndex) else { return nil }
    let area = radialLights[selectedLocalIndex]
    guard
      let mask = LocalExposure.mask(
        for: image, centerX: area.centerX, centerY: area.centerY,
        radius: area.radius, feather: area.feather, inverted: area.inverted,
        shape: area.shape, angle: area.angle,
        brushSize: area.brushSize, strokes: area.strokes,
        toneRangeEnabled: area.toneRangeEnabled, toneCenter: area.toneCenter,
        toneWidth: area.toneWidth, toneFeather: area.toneFeather,
        hueRangeEnabled: area.hueRangeEnabled, hueCenter: area.hueCenter,
        hueWidth: area.hueWidth, hueFeather: area.hueFeather)
    else { return nil }
    return framedImage(mask)
  }

  private func developedImage(previewUncropped: Bool = false) -> CIImage? {
    guard var image = imageBeforeLocalArea(radialLights.count) else { return nil }
    if abs(filmLightWarmth) > 0.001 || abs(filmLightTint) > 0.001 {
      let balance = CIFilter.temperatureAndTint()
      balance.inputImage = image
      balance.neutral = CIVector(x: 6500, y: 0)
      balance.targetNeutral = CIVector(
        x: 6500 - filmLightWarmth * 1000, y: -filmLightTint * 100)
      guard let balanced = balance.outputImage else {
        error = "The film-light color balance could not be rendered."
        return nil
      }
      image = balanced
    }
    return finishDeveloping(image, previewUncropped: previewUncropped)
  }

  private func imageBeforeLocalArea(_ index: Int) -> CIImage? {
    guard var image = source else { return nil }
    image = inputNeutralBalance.apply(to: image)
    if !sourceIsRAW && abs(inputTone - 1) > 0.001 {
      guard let renderedInputToneKernel,
        let toned = renderedInputToneKernel.apply(
          extent: image.extent, arguments: [image, inputTone]
        )
      else {
        error = "The rendered-input tone stage could not be loaded."
        return nil
      }
      image = toned
    }
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
    for area in radialLights.prefix(index)
    where abs(area.exposure) > 0.001 || abs(area.warmth) > 0.001 || abs(area.tint) > 0.001 {
      image = LocalExposure.apply(
        to: image, ev: area.exposure, warmth: area.warmth, tint: area.tint,
        centerX: area.centerX,
        centerY: area.centerY, radius: area.radius, feather: area.feather,
        inverted: area.inverted, shape: area.shape, angle: area.angle,
        brushSize: area.brushSize, strokes: area.strokes,
        toneRangeEnabled: area.toneRangeEnabled, toneCenter: area.toneCenter,
        toneWidth: area.toneWidth, toneFeather: area.toneFeather,
        hueRangeEnabled: area.hueRangeEnabled, hueCenter: area.hueCenter,
        hueWidth: area.hueWidth, hueFeather: area.hueFeather)
    }
    return image
  }

  private func finishDeveloping(_ startingImage: CIImage, previewUncropped: Bool) -> CIImage? {
    var image = startingImage
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
    if abs(curveShadow) > 0.001 || abs(curveMidtone) > 0.001
      || abs(curveHighlight) > 0.001
    {
      guard let outputToneCurveKernel,
        let curved = outputToneCurveKernel.apply(
          extent: image.extent,
          arguments: [image, curveShadow, curveMidtone, curveHighlight])
      else {
        error = "The output tone curve could not be loaded."
        return nil
      }
      image = curved
    }
    let temperature = CIFilter.temperatureAndTint()
    temperature.inputImage = image
    temperature.neutral = CIVector(x: 6500, y: 0)
    temperature.targetNeutral = CIVector(x: 6500 - warmth * 1000, y: -tint * 100)
    let graded = ColorGrade.apply(
      to: temperature.outputImage ?? image,
      shadowHue: shadowHue, shadowStrength: shadowStrength,
      midHue: midHue, midStrength: midStrength,
      highlightHue: highlightHue, highlightStrength: highlightStrength,
      timingVersion: colorTimingVersion
    )
    var colored = graded
    if abs(vibrance) > 0.001 {
      guard let vibranceKernel,
        let adjusted = vibranceKernel.apply(extent: colored.extent, arguments: [colored, vibrance])
      else {
        error = "The vibrance stage could not be loaded."
        return nil
      }
      colored = adjusted
    }
    let selected = SelectiveColor.apply(
      to: colored, targetHue: selectiveHue, range: selectiveRange,
      hueShift: selectiveShift, saturation: selectiveSaturation
    )
    let mixed = ColorMixer.apply(to: selected, adjustments: mixer, version: mixerVersion)
    var finished = FilmEffects.apply(
      to: mixed, grain: grain, grainSize: grainSize, grainSeed: grainSeed, halation: halation,
      acutance: acutance)
    if outputShoulder > 0.001 {
      guard let outputShoulderKernel,
        let rolled = outputShoulderKernel.apply(
          extent: finished.extent, arguments: [finished, outputShoulder])
      else {
        error = "The output shoulder could not be loaded."
        return nil
      }
      finished = rolled
    }
    return framedImage(finished, aspectOverride: previewUncropped ? 0 : nil)
  }

  private func framedImage(_ image: CIImage, aspectOverride: Int? = nil) -> CIImage {
    let framed = Framing.apply(
      to: image, quarterTurns: frameRotation, straightenDegrees: frameStraighten,
      aspect: aspectOverride ?? frameAspect, offsetX: frameOffsetX, offsetY: frameOffsetY,
      freeCrop: frameFreeCrop)
    return framed.transformed(
      by: CGAffineTransform(translationX: -framed.extent.minX, y: -framed.extent.minY))
  }

  func rotateFrame(_ steps: Int) {
    frameRotation = ((frameRotation + steps) % 4 + 4) % 4
    editsChanged()
  }

  func renderPreview() {
    renderVersion += 1
    pixelTask?.cancel()
    pixelVersion += 1
    pixelReadout = nil
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
      originalImage: compareEnabled ? source.map { framedImage($0) } : nil,
      showGamutWarning: showGamutWarning && !showOriginal && !showLocalMask && !showCropBounds,
      highPrecision: highPrecisionPreview
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
        if inspectPixel, let selectedPixel {
          inspect(displayX: Double(selectedPixel.x), displayY: Double(selectedPixel.y))
        }
      } else {
        error = "Could not render this photo."
      }
      isRendering = false
    }
  }

  func inspect(displayX: Double, displayY: Double) {
    guard inspectPixel, let source,
      let location = Framing.sourceLocation(
        displayX: displayX, displayY: displayY, sourceExtent: source.extent,
        quarterTurns: frameRotation, straightenDegrees: frameStraighten,
        aspect: frameAspect, offsetX: frameOffsetX, offsetY: frameOffsetY,
        freeCrop: frameFreeCrop),
      let output = developedImage()
    else { return }
    selectedPixel = CGPoint(x: displayX, y: displayY)
    pixelTask?.cancel()
    pixelVersion += 1
    let version = pixelVersion
    let request = PixelSampleRequest(
      input: source, output: output, inputLocation: location,
      displayX: displayX, displayY: displayY, sourceURL: scopedURL)
    pixelTask = Task {
      let result = await pixelSampler.sample(request)
      guard !Task.isCancelled, version == pixelVersion else { return }
      pixelReadout = result
    }
  }

  func setPickingNeutralArea(_ picking: Bool) {
    if picking {
      setPickingLocalHue(false)
      setPickingLocalTone(false)
    }
    neutralTask?.cancel()
    neutralVersion += 1
    pickingNeutralArea = picking && source != nil
    if pickingNeutralArea {
      neutralNotice = nil
      placingLocalArea = false
      paintingLocalArea = false
      inspectPixel = false
      selectedPixel = nil
      pixelReadout = nil
      showCropBounds = false
      showLocalMask = false
      showOriginal = false
      compareEnabled = false
      zoom100 = false
      renderPreview()
    }
  }

  func setPickingLocalHue(_ picking: Bool) {
    localHueTask?.cancel()
    localHueVersion += 1
    pickingLocalHue = picking && source != nil
    if pickingLocalHue {
      setPickingNeutralArea(false)
      setPickingLocalTone(false)
      localHueNotice = nil
      placingLocalArea = false
      paintingLocalArea = false
      inspectPixel = false
      selectedPixel = nil
      pixelReadout = nil
      showCropBounds = false
      showLocalMask = false
      showOriginal = false
      compareEnabled = false
      zoom100 = false
      renderPreview()
    }
  }

  func setPickingLocalTone(_ picking: Bool) {
    localToneTask?.cancel()
    localToneVersion += 1
    pickingLocalTone = picking && source != nil
    if pickingLocalTone {
      setPickingNeutralArea(false)
      setPickingLocalHue(false)
      localToneNotice = nil
      placingLocalArea = false
      paintingLocalArea = false
      inspectPixel = false
      selectedPixel = nil
      pixelReadout = nil
      showCropBounds = false
      showLocalMask = false
      showOriginal = false
      compareEnabled = false
      zoom100 = false
      renderPreview()
    }
  }

  func pickLocalTone(displayX: Double, displayY: Double) {
    guard pickingLocalTone, let source, let sourceURL,
      let location = Framing.sourceLocation(
        displayX: displayX, displayY: displayY, sourceExtent: source.extent,
        quarterTurns: frameRotation, straightenDegrees: frameStraighten,
        aspect: frameAspect, offsetX: frameOffsetX, offsetY: frameOffsetY,
        freeCrop: frameFreeCrop),
      let input = imageBeforeLocalArea(selectedLocalIndex)
    else { return }
    pickingLocalTone = false
    localToneTask?.cancel()
    localToneVersion += 1
    let version = localToneVersion
    let areaIndex = selectedLocalIndex
    let request = LocalRangeRequest(image: input, location: location, sourceURL: scopedURL)
    localToneTask = Task {
      let sampled = await pixelSampler.sampleLocalRange(request)
      guard !Task.isCancelled, version == localToneVersion, self.sourceURL == sourceURL,
        selectedLocalIndex == areaIndex
      else { return }
      localToneTask = nil
      guard let sampled else {
        localToneNotice = "Could not read that pixel. Try another detailed area."
        return
      }
      radialLights[areaIndex].toneCenter = min(max(sampled.toneStops, -6), 6)
      radialLights[areaIndex].toneRangeEnabled = true
      localToneNotice = nil
      editsChanged()
    }
  }

  func pickLocalHue(displayX: Double, displayY: Double) {
    guard pickingLocalHue, let source, let sourceURL,
      let location = Framing.sourceLocation(
        displayX: displayX, displayY: displayY, sourceExtent: source.extent,
        quarterTurns: frameRotation, straightenDegrees: frameStraighten,
        aspect: frameAspect, offsetX: frameOffsetX, offsetY: frameOffsetY,
        freeCrop: frameFreeCrop),
      let input = imageBeforeLocalArea(selectedLocalIndex)
    else { return }
    pickingLocalHue = false
    localHueTask?.cancel()
    localHueVersion += 1
    let version = localHueVersion
    let areaIndex = selectedLocalIndex
    let request = LocalRangeRequest(image: input, location: location, sourceURL: scopedURL)
    localHueTask = Task {
      let sampled = await pixelSampler.sampleLocalRange(request)
      guard !Task.isCancelled, version == localHueVersion, self.sourceURL == sourceURL,
        selectedLocalIndex == areaIndex
      else { return }
      localHueTask = nil
      guard let hue = sampled?.hueDegrees else {
        localHueNotice = "Choose a colored area with visible detail."
        return
      }
      radialLights[areaIndex].hueCenter = hue
      radialLights[areaIndex].hueRangeEnabled = true
      localHueNotice = nil
      editsChanged()
    }
  }

  func pickNeutralArea(displayX: Double, displayY: Double) {
    guard pickingNeutralArea, let source, let sourceURL,
      let location = Framing.sourceLocation(
        displayX: displayX, displayY: displayY, sourceExtent: source.extent,
        quarterTurns: frameRotation, straightenDegrees: frameStraighten,
        aspect: frameAspect, offsetX: frameOffsetX, offsetY: frameOffsetY,
        freeCrop: frameFreeCrop)
    else { return }
    pickingNeutralArea = false
    neutralTask?.cancel()
    neutralVersion += 1
    let version = neutralVersion
    let request = NeutralSampleRequest(
      image: source, location: location, sourceURL: scopedURL)
    neutralTask = Task {
      let balance = await neutralPatchSampler.sample(request)
      guard !Task.isCancelled, version == neutralVersion, self.sourceURL == sourceURL else {
        return
      }
      neutralTask = nil
      guard let balance else {
        neutralNotice = "Choose an unclipped gray or white area with visible detail."
        return
      }
      inputNeutralBalance = balance
      neutralNotice = nil
      editsChanged()
    }
  }

  func clearNeutralBalance() {
    setPickingNeutralArea(false)
    inputNeutralBalance = InputNeutralBalance()
    neutralNotice = nil
    editsChanged()
  }

  func useConsistentColorTiming() {
    guard colorTimingVersion < 2 else { return }
    colorTimingVersion = 2
    editsChanged()
  }

  func useLuminancePreservingMixer() {
    guard mixerVersion < 2 else { return }
    mixerVersion = 2
    editsChanged()
  }

  func usePhotoGrainPattern() {
    guard grainSeed == 0, let sourceURL else { return }
    grainSeed = EditRecordLocator.grainSeed(for: sourceURL)
    editsChanged()
  }

  func exportJPEG() {
    guard canExport else { return }
    guard let image = developedImage() else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.jpeg]
    panel.nameFieldStringValue =
      (sourceURL?.deletingPathExtension().lastPathComponent ?? "Photo") + "-FilmLab.jpg"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    beginExport(ExportRequest(image: image, url: url, format: .jpeg, sourceURL: sourceURL))
  }

  func exportTIFF(format: ExportFormat) {
    guard canExport else { return }
    guard let image = developedImage() else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.tiff]
    panel.nameFieldStringValue =
      (sourceURL?.deletingPathExtension().lastPathComponent ?? "Photo") + "-FilmLab.tiff"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    beginExport(ExportRequest(image: image, url: url, format: format, sourceURL: sourceURL))
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

  static func renderedThumbnail(for url: URL) async -> CGImage? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    let accessing = url.startAccessingSecurityScopedResource()
    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
    let isRAW = await thumbnailDecoder.isRAWFile(url)
    guard !Task.isCancelled else { return nil }
    let editsDirectory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab/Edits", isDirectory: true)
    let location = EditRecordLocator.locate(sourceURL: url, directory: editsDirectory)
    let loaded = SavedEditStore.load(
      from: location.primaryURL, fallbackURL: location.pathURL,
      defaultValue: PhotoEdits.defaults(
        forRAW: isRAW, grainSeed: EditRecordLocator.grainSeed(for: url)))
    guard loaded.canSave, loaded.notice == nil else { return nil }
    guard
      let decoded = try? await thumbnailDecoder.decode(
        from: url, isRAW: isRAW, flatRAW: loaded.value.flatRAW,
        highlightRecovery: loaded.value.rawHighlightRecovery,
        temperature: loaded.value.rawTemperature, tint: loaded.value.rawTint,
        maxDimension: 1024)
    else { return nil }
    guard !Task.isCancelled else { return nil }
    let worker = PhotoEditor()
    worker.source = decoded.image
    worker.sourceIsRAW = isRAW
    worker.restoreEdits(loaded.value)
    guard let developed = worker.developedImage() else { return nil }
    return await EditedThumbnailRenderer.shared.render(developed)
  }

  func exportBatch(
    _ paths: [String], to directory: URL, format: ExportFormat,
    progress: @MainActor (Int, Int) -> Void
  ) async -> String {
    let currentPhotoSaved = flushEdits()
    var result = BatchExportResult()
    for (index, path) in paths.enumerated() {
      if Task.isCancelled {
        result.cancelled = true
        break
      }
      progress(index + 1, paths.count)
      let url = URL(fileURLWithPath: path)
      let access = url.startAccessingSecurityScopedResource()
      do {
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        if !currentPhotoSaved, url.standardizedFileURL == sourceURL?.standardizedFileURL {
          result.failed.append(url.lastPathComponent + " (current edits could not be saved)")
          continue
        }
        guard FileManager.default.fileExists(atPath: path) else {
          result.failed.append(url.lastPathComponent + " (missing original)")
          continue
        }
        let isRAW = await imageDecoder.isRAWFile(url)
        let location = EditRecordLocator.locate(sourceURL: url, directory: editsDirectory)
        let loaded = SavedEditStore.load(
          from: location.primaryURL, fallbackURL: location.pathURL,
          defaultValue: PhotoEdits.defaults(
            forRAW: isRAW, grainSeed: EditRecordLocator.grainSeed(for: url)))
        guard loaded.notice == nil else {
          result.failed.append(url.lastPathComponent + " (saved edits need review)")
          continue
        }
        let decoded = try await imageDecoder.decode(
          from: url, isRAW: isRAW, flatRAW: loaded.value.flatRAW,
          highlightRecovery: loaded.value.rawHighlightRecovery,
          temperature: loaded.value.rawTemperature, tint: loaded.value.rawTint)
        try Task.checkCancellation()
        let worker = PhotoEditor()
        worker.source = decoded.image
        worker.sourceIsRAW = isRAW
        worker.restoreEdits(loaded.value)
        guard let image = worker.developedImage() else {
          result.failed.append(url.lastPathComponent + " (render failed)")
          continue
        }
        let output = BatchExportDestination.availableURL(
          for: url, in: directory, format: format)
        try await exporter.export(
          ExportRequest(image: image, url: output, format: format, sourceURL: url))
        result.exported += 1
      } catch is CancellationError {
        result.cancelled = true
        break
      } catch {
        result.failed.append(url.lastPathComponent + " (\(error.localizedDescription))")
      }
    }
    return result.summary
  }

}

enum EditorError: LocalizedError {
  case unsupported
  var errorDescription: String? { "This image format is not supported by this Mac's decoder." }
}

enum EditorPanel: String, CaseIterable, Identifiable {
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

private enum LibrarySort: String, CaseIterable, Identifiable {
  case importOrder = "Import order"
  case newestFirst = "Newest imported first"
  case name = "Name"

  var id: Self { self }
}

private enum OutputScopeKind: String, CaseIterable {
  case histogram = "Histogram"
  case waveform = "Waveform"
  case rgbParade = "RGB"
}

struct ContentView: View {
  @Bindable var editor: PhotoEditor
  @Binding var showingImporter: Bool
  @State private var libraryLoad = PhotoLibraryStore.loadSafely(from: libraryURL)
  @State private var showingLibrary = false
  @State private var showingNewCatalog = false
  @State private var newCatalogName = ""
  @State private var catalogToRename: PhotoCatalog?
  @State private var renamedCatalogName = ""
  @State private var catalogToDelete: PhotoCatalog?
  @State private var pathToRelink: String?
  @State private var showingRelinkImporter = false
  @State private var libraryNotice: String?
  @State private var importingFolder = false
  @State private var folderImportTask: Task<Void, Never>?
  @State private var folderScanner = PhotoFolderScanner()
  @State private var selectingPhotos = false
  @State private var selectedPhotoPaths = Set<String>()
  @State private var selectionAnchor: String?
  @State private var thumbnailRefresh: [String: Int] = [:]
  @State private var lastActiveThumbnailPath: String?
  @State private var lastPhotoByCatalog = CatalogPhotoMemory.load()
  @State private var librarySearch = ""
  @State private var librarySort: LibrarySort = .importOrder
  @State private var showFavoritesOnly = false
  @State private var applyingBatch = false
  @State private var exportingBatch = false
  @State private var batchExportProgress = ""
  @State private var batchExportTask: Task<Void, Never>?
  @State private var panel: EditorPanel = .film
  @State private var outputScope: OutputScopeKind = .histogram
  @State private var selectedColorBand = 0
  @State private var cropDragOrigin: FreeCrop?
  @State private var paintDragPoints: [CGPoint] = []
  @Environment(\.displayScale) private var displayScale
  @Environment(\.scenePhase) private var scenePhase

  private static var libraryURL: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab/Library.json")
  }

  private var libraryURL: URL { Self.libraryURL }
  private var editsDirectory: URL {
    libraryURL.deletingLastPathComponent().appendingPathComponent("Edits", isDirectory: true)
  }
  private var visibleLibraryPaths: [String] {
    let paths = library.selectedCatalog?.photoPaths ?? []
    let query = librarySearch.trimmingCharacters(in: .whitespacesAndNewlines)
    let matching =
      query.isEmpty
      ? paths
      : paths.filter {
        URL(fileURLWithPath: $0).lastPathComponent.localizedStandardContains(query)
      }
    let filtered =
      showFavoritesOnly
      ? matching.filter { library.favoritePaths.contains($0) } : matching
    switch librarySort {
    case .importOrder: return filtered
    case .newestFirst: return filtered.reversed()
    case .name:
      return filtered.sorted {
        let comparison = URL(fileURLWithPath: $0).lastPathComponent.localizedStandardCompare(
          URL(fileURLWithPath: $1).lastPathComponent)
        return comparison == .orderedSame ? $0 < $1 : comparison == .orderedAscending
      }
    }
  }
  private var availableCatalogPaths: [String] {
    (library.selectedCatalog?.photoPaths ?? []).filter {
      FileManager.default.fileExists(atPath: $0)
    }
  }
  private var library: PhotoLibrary {
    get { libraryLoad.value }
    nonmutating set { libraryLoad.value = newValue }
  }

  var body: some View {
    HStack(spacing: 0) {
      navigationRail
      if showingLibrary {
        libraryView
      } else {
        VStack(spacing: 0) {
          HStack(spacing: 0) {
            photoCanvas
            if editor.sourceURL != nil { inspector }
          }
          photoStrip
        }
      }
    }
    .toolbar {
      Button("Previous Photo", systemImage: "chevron.left") {
        if let path = adjacentPhoto(step: -1) { selectPhoto(path) }
      }
      .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
      .disabled(adjacentPhoto(step: -1) == nil || !editor.canBatchExport)
      Button("Next Photo", systemImage: "chevron.right") {
        if let path = adjacentPhoto(step: 1) { selectPhoto(path) }
      }
      .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
      .disabled(adjacentPhoto(step: 1) == nil || !editor.canBatchExport)
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
        Button("Copy \(panel.rawValue) Workspace") { editor.copyWorkspace(panel) }
        Button("Paste \(panel.rawValue) Workspace") { editor.pasteWorkspace(panel) }
          .disabled(!editor.canPasteWorkspace(panel))
        Divider()
        Button("Save Look…") { editor.saveLook() }
        Button("Apply Look…") { editor.applyLook() }
      }
      .accessibilityLabel("Settings")
      .help("Copy, save, or apply FilmLab edit settings")
      .disabled(editor.preview == nil)
      Button("Reset Edits", systemImage: "arrow.counterclockwise") { editor.resetEdits() }
        .disabled(editor.preview == nil)
      Menu("Open", systemImage: "folder") {
        Button("Import Photos…") { showingImporter = true }
        Button("Import Folder…") { importFolder() }
        if !editor.recentPaths.isEmpty {
          Divider()
          ForEach(editor.recentPaths, id: \.self) { path in
            Button(URL(fileURLWithPath: path).lastPathComponent) {
              openRecentPhoto(path)
            }
            .help(path)
          }
          Divider()
          Button("Clear Recent Photos") {
            editor.clearRecentPhotos()
            lastPhotoByCatalog.removeAll()
            CatalogPhotoMemory.save(lastPhotoByCatalog)
          }
        }
      }
      .accessibilityLabel("Open photos")
      .help("Choose a photo or reopen a recent photo")
      Menu("Export…", systemImage: "square.and.arrow.up") {
        Button("JPEG (sRGB)…") { editor.exportJPEG() }
        Button("16-bit TIFF (sRGB)…") { editor.exportTIFF(format: .tiff16SRGB) }
        Button("16-bit TIFF (Display P3)…") { editor.exportTIFF(format: .tiff16DisplayP3) }
      }
      .accessibilityLabel("Export photo")
      .disabled(!editor.canExport)
    }
    .fileImporter(
      isPresented: $showingImporter, allowedContentTypes: [.image, .rawImage],
      allowsMultipleSelection: true
    ) { result in
      switch result {
      case .success(let urls):
        if updateLibrary({ $0.importPhotos(urls) }), let url = urls.first {
          showingLibrary = false
          editor.open(url)
        }
      case .failure(let error): editor.error = error.localizedDescription
      }
    }
    .fileImporter(
      isPresented: $showingRelinkImporter,
      allowedContentTypes: [.image, .rawImage], allowsMultipleSelection: false
    ) { result in
      let oldPath = pathToRelink
      pathToRelink = nil
      guard let oldPath else { return }
      switch result {
      case .success(let urls):
        if let url = urls.first { relinkPhoto(from: oldPath, to: url) }
      case .failure(let error): editor.error = error.localizedDescription
      }
    }
    .alert("New Catalog", isPresented: $showingNewCatalog) {
      TextField("Catalog name", text: $newCatalogName)
      Button("Create") {
        if updateLibrary({ $0.createCatalog(named: newCatalogName) }) {
          showingLibrary = true
        }
        newCatalogName = ""
      }
      Button("Cancel", role: .cancel) { newCatalogName = "" }
    } message: {
      Text("Catalogs organize references to your photos. Original files stay in place.")
    }
    .alert(
      "Rename Catalog",
      isPresented: Binding(
        get: { catalogToRename != nil },
        set: { if !$0 { catalogToRename = nil } })
    ) {
      TextField("Catalog name", text: $renamedCatalogName)
      Button("Rename") {
        if let catalogToRename {
          updateLibrary { $0.renameCatalog(catalogToRename.id, to: renamedCatalogName) }
        }
        catalogToRename = nil
      }
      Button("Cancel", role: .cancel) { catalogToRename = nil }
    }
    .alert(
      "Remove Catalog?",
      isPresented: Binding(
        get: { catalogToDelete != nil },
        set: { if !$0 { catalogToDelete = nil } })
    ) {
      Button("Remove Catalog", role: .destructive) {
        if let catalogToDelete {
          if library.selectedCatalogID != catalogToDelete.id || editor.flushEdits() {
            if updateLibrary({ $0.deleteCatalog(catalogToDelete.id) }),
              !library.catalogs.contains(where: { $0.id == catalogToDelete.id })
            {
              lastPhotoByCatalog.removeValue(forKey: catalogToDelete.id)
              CatalogPhotoMemory.save(lastPhotoByCatalog)
            }
          } else {
            libraryNotice = "Current edits could not be saved. The catalog was kept."
          }
        }
        catalogToDelete = nil
      }
      Button("Cancel", role: .cancel) { catalogToDelete = nil }
    } message: {
      Text(
        "This removes the catalog and its photo references. Original photos and edits stay in place."
      )
    }
    .onAppear {
      editor.resumeLastPhoto(
        in: availableCatalogPaths,
        remembered: lastPhotoByCatalog[library.selectedCatalogID])
    }
    .onDisappear { editor.flushEdits() }
    .onChange(of: panel) {
      if panel != .develop { editor.setPickingNeutralArea(false) }
      if panel != .local {
        if editor.showLocalMask { editor.setMaskPreview(false) }
        editor.setPlacingLocalArea(false)
        editor.setPaintingLocalArea(false)
      }
      if panel != .framing && editor.showCropBounds { editor.setCropBoundsPreview(false) }
    }
    .onChange(of: library.selectedCatalogID) { oldCatalogID, _ in
      selectedPhotoPaths.removeAll()
      selectionAnchor = nil
      selectingPhotos = false
      if !alignEditorToCatalog() {
        updateLibrary { $0.selectedCatalogID = oldCatalogID }
        libraryNotice = "Current edits could not be saved. The previous catalog is still selected."
      }
    }
    .onChange(of: editor.paintingLocalArea) {
      if !editor.paintingLocalArea { paintDragPoints.removeAll() }
    }
    .onChange(of: editor.sourceURL) {
      if let lastActiveThumbnailPath {
        thumbnailRefresh[lastActiveThumbnailPath, default: 0] += 1
      }
      lastActiveThumbnailPath = editor.sourceURL?.standardizedFileURL.path
      if let path = lastActiveThumbnailPath,
        library.selectedCatalog?.photoPaths.contains(path) == true
      {
        lastPhotoByCatalog[library.selectedCatalogID] = path
        CatalogPhotoMemory.save(lastPhotoByCatalog)
      }
    }
    .onChange(of: scenePhase) {
      if scenePhase != .active { editor.flushEdits() }
    }
    .onChange(of: editor.highPrecisionPreview) {
      UserDefaults.standard.set(editor.highPrecisionPreview, forKey: "FilmLab.highPrecisionPreview")
      editor.renderPreview()
    }
    .onChange(of: editor.exposure) { editor.editsChanged() }
    .onChange(of: editor.contrast) { editor.editsChanged() }
    .onChange(of: editor.saturation) { editor.editsChanged() }
    .onChange(of: editor.vibrance) { editor.editsChanged() }
    .onChange(of: editor.warmth) { editor.editsChanged() }
    .onChange(of: editor.tint) { editor.editsChanged() }
    .onChange(of: editor.curveShadow) { editor.editsChanged() }
    .onChange(of: editor.curveMidtone) { editor.editsChanged() }
    .onChange(of: editor.curveHighlight) { editor.editsChanged() }
    .onChange(of: editor.outputShoulder) { editor.editsChanged() }
    .onChange(of: editor.inputWarmth) { editor.editsChanged() }
    .onChange(of: editor.inputTint) { editor.editsChanged() }
    .onChange(of: editor.filmLightWarmth) { editor.editsChanged() }
    .onChange(of: editor.filmLightTint) { editor.editsChanged() }
    .onChange(of: editor.inputTone) { editor.editsChanged() }
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
    .onChange(of: editor.grainSize) { editor.editsChanged() }
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
        Button {
          showingLibrary = true
        } label: {
          Label("Library", systemImage: "square.grid.2x2")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(showingLibrary ? Color.white.opacity(0.11) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        Button {
          showingLibrary = false
        } label: {
          Label("Editor", systemImage: "slider.horizontal.3")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(!showingLibrary ? Color.white.opacity(0.11) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        Divider()
        ForEach(EditorPanel.allCases) { item in
          Button {
            panel = item
            showingLibrary = false
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
      Text(library.selectedCatalog?.name ?? "")
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Text("LOCAL EDITS")
        .font(.caption2.weight(.medium))
        .tracking(1)
        .foregroundStyle(.tertiary)
    }
    .padding(16)
    .frame(width: 160)
    .background(Color(white: 0.10))
  }

  @discardableResult
  private func saveLibrary() -> Bool {
    guard libraryLoad.canSave else {
      libraryNotice = "Library saving is paused to protect its unreadable index."
      return false
    }
    do {
      try PhotoLibraryStore.save(library, to: libraryURL)
      return true
    } catch {
      libraryNotice = "Could not save library: \(error.localizedDescription)"
      return false
    }
  }

  @discardableResult
  private func updateLibrary(_ change: (inout PhotoLibrary) -> Void) -> Bool {
    guard libraryLoad.canSave else {
      libraryNotice = "Library saving is paused to protect its unreadable index."
      return false
    }
    do {
      let updated = try PhotoLibraryStore.updating(library, at: libraryURL, change: change)
      libraryNotice = nil
      library = updated
      return true
    } catch {
      libraryNotice = "Could not save library: \(error.localizedDescription)"
      return false
    }
  }

  private func selectPhoto(_ path: String) {
    guard FileManager.default.fileExists(atPath: path) else {
      libraryNotice = "Photo is missing: \(path)"
      return
    }
    showingLibrary = false
    editor.open(URL(fileURLWithPath: path))
  }

  private func openRecentPhoto(_ path: String) {
    guard FileManager.default.fileExists(atPath: path) else {
      libraryNotice = "Photo is missing: \(path)"
      return
    }
    if let catalog = library.catalogs.first(where: { $0.photoPaths.contains(path) }),
      catalog.id != library.selectedCatalogID
    {
      let previous = lastPhotoByCatalog[catalog.id]
      lastPhotoByCatalog[catalog.id] = path
      CatalogPhotoMemory.save(lastPhotoByCatalog)
      if updateLibrary({ $0.selectedCatalogID = catalog.id }) {
        showingLibrary = false
      } else {
        lastPhotoByCatalog[catalog.id] = previous
        CatalogPhotoMemory.save(lastPhotoByCatalog)
      }
    } else {
      let url = URL(fileURLWithPath: path)
      if updateLibrary({ $0.importPhotos([url]) }) { selectPhoto(path) }
    }
  }

  @discardableResult
  private func alignEditorToCatalog() -> Bool {
    let currentPath = editor.sourceURL?.standardizedFileURL.path
    let selectedPath = CatalogPhotoSelection.preferredPath(
      in: availableCatalogPaths, current: currentPath,
      remembered: lastPhotoByCatalog[library.selectedCatalogID])
    if selectedPath == currentPath, !editor.isOpening { return true }
    guard editor.closePhoto() else {
      libraryNotice = "Current edits could not be saved. The previous photo is still open."
      return false
    }
    if let selectedPath { editor.open(URL(fileURLWithPath: selectedPath)) }
    return true
  }

  private func importFolder() {
    guard !importingFolder else { return }
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Import Folder"
    guard panel.runModal() == .OK, let folder = panel.url else { return }
    let catalogID = library.selectedCatalogID
    let catalogName = library.selectedCatalog?.name ?? "catalog"
    showingLibrary = true
    importingFolder = true
    libraryNotice = nil
    folderImportTask = Task { @MainActor in
      let access = folder.startAccessingSecurityScopedResource()
      defer { if access { folder.stopAccessingSecurityScopedResource() } }
      do {
        let photos = try await folderScanner.scan(folder)
        try Task.checkCancellation()
        guard library.catalogs.contains(where: { $0.id == catalogID }) else {
          libraryNotice = "The destination catalog was removed before import finished."
          importingFolder = false
          folderImportTask = nil
          return
        }
        let previousLibrary = library
        let added = library.importPhotos(photos, into: catalogID)
        let tracked = library.trackImportedFolder(folder, in: catalogID)
        if (added > 0 || tracked) && !saveLibrary() {
          library = previousLibrary
        } else if added == 0 {
          libraryNotice =
            photos.isEmpty
            ? "Folder linked to \(catalogName). No supported photos found yet."
            : "All \(photos.count) photos are already in \(catalogName). Folder linked for refresh."
        } else {
          libraryNotice =
            "Imported \(added) photo\(added == 1 ? "" : "s") from \(folder.lastPathComponent) into \(catalogName)."
        }
      } catch is CancellationError {
        libraryNotice = "Folder import cancelled."
      } catch {
        libraryNotice = "Could not import folder: \(error.localizedDescription)"
      }
      importingFolder = false
      folderImportTask = nil
    }
  }

  private func refreshImportedFolders() {
    guard !importingFolder, let catalog = library.selectedCatalog,
      !catalog.importedFolderPaths.isEmpty
    else { return }
    importingFolder = true
    libraryNotice = nil
    folderImportTask = Task { @MainActor in
      var found: [URL] = []
      var failed: [String] = []
      do {
        for path in catalog.importedFolderPaths {
          try Task.checkCancellation()
          let folder = URL(fileURLWithPath: path)
          let access = folder.startAccessingSecurityScopedResource()
          do {
            found += try await folderScanner.scan(folder)
          } catch is CancellationError {
            if access { folder.stopAccessingSecurityScopedResource() }
            throw CancellationError()
          } catch {
            failed.append(folder.lastPathComponent)
          }
          if access { folder.stopAccessingSecurityScopedResource() }
        }
        try Task.checkCancellation()
        guard library.catalogs.contains(where: { $0.id == catalog.id }) else {
          libraryNotice = "The catalog was removed before refresh finished."
          importingFolder = false
          folderImportTask = nil
          return
        }
        guard updateLibrary({ $0.importPhotos(found, into: catalog.id) }) else {
          importingFolder = false
          folderImportTask = nil
          return
        }
        let added = max(
          0,
          (library.catalogs.first { $0.id == catalog.id }?.photoPaths.count ?? 0)
            - catalog.photoPaths.count)
        libraryNotice =
          "Added \(added) photo\(added == 1 ? "" : "s") from \(catalog.importedFolderPaths.count) folder\(catalog.importedFolderPaths.count == 1 ? "" : "s")."
        if !failed.isEmpty {
          libraryNotice =
            (libraryNotice ?? "") + " Could not scan: \(failed.joined(separator: ", "))."
        }
      } catch is CancellationError {
        libraryNotice = "Folder refresh cancelled."
      } catch {
        libraryNotice = "Could not refresh folders: \(error.localizedDescription)"
      }
      importingFolder = false
      folderImportTask = nil
    }
  }

  private func adjacentPhoto(step: Int) -> String? {
    let paths = library.selectedCatalog?.photoPaths ?? []
    guard !paths.isEmpty else { return nil }
    let current = editor.sourceURL?.standardizedFileURL.path
    var index = paths.firstIndex(of: current ?? "") ?? (step > 0 ? -1 : paths.count)
    while true {
      index += step
      guard paths.indices.contains(index) else { return nil }
      if FileManager.default.fileExists(atPath: paths[index]) { return paths[index] }
    }
  }

  private func selectOrOpenPhoto(_ path: String) {
    if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
      selectRange(through: path)
    } else if selectingPhotos {
      if !selectedPhotoPaths.insert(path).inserted {
        selectedPhotoPaths.remove(path)
      }
      selectionAnchor = path
    } else {
      selectionAnchor = path
      selectPhoto(path)
    }
  }

  private func liveThumbnail(for path: String) -> NSImage? {
    guard editor.sourceURL?.standardizedFileURL.path == path,
      !editor.showOriginal, !editor.showLocalMask,
      !editor.showGamutWarning, !editor.showCropBounds
    else { return nil }
    return editor.preview
  }

  private func selectRange(through path: String) {
    let range = LibrarySelection.range(
      in: visibleLibraryPaths, from: selectionAnchor, through: path)
    guard !range.isEmpty else { return }
    selectedPhotoPaths.formUnion(range)
    selectingPhotos = true
    selectionAnchor = path
  }

  private func applySettingsToSelection(workspaceOnly: Bool = false) {
    let paths = library.selectedCatalog?.photoPaths.filter { selectedPhotoPaths.contains($0) } ?? []
    applyingBatch = true
    Task {
      libraryNotice = await editor.pasteSettings(to: paths, workspaceOnly: workspaceOnly)
      for path in paths { thumbnailRefresh[path, default: 0] += 1 }
      applyingBatch = false
      selectedPhotoPaths.removeAll()
      selectionAnchor = nil
      selectingPhotos = false
    }
  }

  private func exportSelection(format: ExportFormat) {
    let paths = library.selectedCatalog?.photoPaths.filter { selectedPhotoPaths.contains($0) } ?? []
    guard !paths.isEmpty, !exportingBatch, editor.canBatchExport else { return }
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.prompt = "Export Here"
    guard panel.runModal() == .OK, let directory = panel.url else { return }
    exportingBatch = true
    batchExportProgress = "Preparing exports…"
    batchExportTask = Task {
      libraryNotice = await editor.exportBatch(paths, to: directory, format: format) {
        current, total in
        batchExportProgress = "Exporting \(current) of \(total)…"
      }
      exportingBatch = false
      batchExportProgress = ""
      batchExportTask = nil
    }
  }

  private func transferPhotos(_ paths: [String], to destination: PhotoCatalog, move: Bool) {
    if move, let openPath = editor.sourceURL?.standardizedFileURL.path,
      paths.contains(openPath), !editor.flushEdits()
    {
      libraryNotice = "Current edits could not be saved. The photo was not moved."
      return
    }
    let previousLibrary = library
    let transferred = library.transferPhotos(paths, to: destination.id, removeFromSource: move)
    guard transferred > 0 else {
      libraryNotice = "These photos are already in \(destination.name)."
      return
    }
    if saveLibrary() {
      selectedPhotoPaths.subtract(paths)
      if move { alignEditorToCatalog() }
      libraryNotice =
        "\(move ? "Moved" : "Copied") \(transferred) photo reference\(transferred == 1 ? "" : "s") to \(destination.name)."
    } else {
      library = previousLibrary
    }
  }

  @ViewBuilder
  private func catalogTransferMenu(for paths: [String]) -> some View {
    Menu("Copy to Catalog") {
      ForEach(library.catalogs.filter { $0.id != library.selectedCatalogID }) { catalog in
        Button(catalog.name) { transferPhotos(paths, to: catalog, move: false) }
      }
    }
    Menu("Move to Catalog") {
      ForEach(library.catalogs.filter { $0.id != library.selectedCatalogID }) { catalog in
        Button(catalog.name) { transferPhotos(paths, to: catalog, move: true) }
      }
    }
  }

  private func relinkPhoto(from oldPath: String, to url: URL) {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
      !isDirectory.boolValue
    else {
      libraryNotice = "The selected original is unavailable."
      return
    }
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    let candidates = library.movedFolderRelinkCandidates(from: oldPath, to: url)
    let previousLibrary = library
    var relinked = [(String, URL)]()
    var missingEdits = 0
    var failures = [String]()
    for (previousPath, replacementURL) in candidates {
      do {
        let result = try PhotoEditRelinker.transferSavedEdits(
          from: URL(fileURLWithPath: previousPath), to: replacementURL,
          directory: editsDirectory, as: PhotoEdits.self)
        if result == .unavailable { missingEdits += 1 }
        library.relinkPhoto(from: previousPath, to: replacementURL)
        relinked.append((previousPath, replacementURL))
      } catch {
        if previousPath == oldPath {
          library = previousLibrary
          libraryNotice = "Could not relink the selected original: \(error.localizedDescription)"
          return
        }
        failures.append(URL(fileURLWithPath: previousPath).lastPathComponent)
      }
    }
    guard !relinked.isEmpty else {
      library = previousLibrary
      libraryNotice = "Could not relink the selected original. Its saved edits were left untouched."
      return
    }
    guard saveLibrary() else {
      library = previousLibrary
      return
    }
    selectedPhotoPaths.subtract(relinked.map(\.0))
    if let selectionAnchor, relinked.contains(where: { $0.0 == selectionAnchor }) {
      self.selectionAnchor = nil
    }
    if let openPath = editor.sourceURL?.standardizedFileURL.path,
      let replacement = relinked.first(where: { $0.0 == openPath })?.1
    {
      editor.open(replacement)
    }
    let count = relinked.count
    var notice = "Relinked \(count) original\(count == 1 ? "" : "s")."
    if missingEdits > 0 {
      notice += " \(missingEdits) had no valid saved edit backup."
    }
    if !failures.isEmpty {
      notice += " Could not relink: \(failures.joined(separator: ", "))."
    }
    libraryNotice = notice
  }

  private var libraryView: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("CATALOGS")
            .font(.caption2.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(.secondary)
          Spacer()
          Button("New Catalog", systemImage: "plus") { showingNewCatalog = true }
            .labelStyle(.iconOnly)
        }
        ForEach(library.catalogs) { catalog in
          Button {
            updateLibrary { $0.selectedCatalogID = catalog.id }
          } label: {
            HStack {
              Image(systemName: "folder")
              Text(catalog.name).lineLimit(1)
              Spacer()
              Text("\(catalog.photoPaths.count)")
                .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(9)
            .background(
              library.selectedCatalogID == catalog.id ? Color.white.opacity(0.11) : .clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
          }
          .buttonStyle(.plain)
          .contextMenu {
            Button("Rename Catalog") {
              catalogToRename = catalog
              renamedCatalogName = catalog.name
            }
            if library.catalogs.count > 1 {
              Button("Remove Catalog", role: .destructive) {
                catalogToDelete = catalog
              }
            }
          }
        }
        Spacer()
      }
      .padding(16)
      .frame(width: 210)
      .background(Color(white: 0.085))

      VStack(alignment: .leading, spacing: 18) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(library.selectedCatalog?.name ?? "Library")
              .font(.title2.weight(.medium))
            Text(
              "\(library.selectedCatalog?.photoPaths.count ?? 0) photo\((library.selectedCatalog?.photoPaths.count ?? 0) == 1 ? "" : "s") · Originals stay in place"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }
          Spacer()
          Button(selectingPhotos ? "Done" : "Select Photos") {
            selectingPhotos.toggle()
            if !selectingPhotos {
              selectedPhotoPaths.removeAll()
              selectionAnchor = nil
            }
          }
          .disabled(applyingBatch || exportingBatch)
          Menu("Import…", systemImage: "plus") {
            Button("Photos…") { showingImporter = true }
            Button("Folder…") { importFolder() }
            if library.selectedCatalog?.importedFolderPaths.isEmpty == false {
              Divider()
              Menu("Linked Folders") {
                ForEach(library.selectedCatalog?.importedFolderPaths ?? [], id: \.self) { path in
                  Button("Stop Refreshing \(URL(fileURLWithPath: path).lastPathComponent)") {
                    if updateLibrary({
                      $0.untrackImportedFolder(path, in: library.selectedCatalogID)
                    }) {
                      libraryNotice =
                        "Stopped refreshing \(path). Existing photos remain in the catalog."
                    }
                  }
                  .help(path)
                }
              }
            }
          }
          .disabled(importingFolder)
          Button("Refresh Folders", systemImage: "arrow.clockwise") {
            refreshImportedFolders()
          }
          .labelStyle(.iconOnly)
          .disabled(
            importingFolder || library.selectedCatalog?.importedFolderPaths.isEmpty != false
          )
          .help("Add newly found photos from folders imported into this catalog")
        }
        HStack(spacing: 10) {
          TextField("Search filenames", text: $librarySearch)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Search catalog photos")
          Picker("Sort", selection: $librarySort) {
            ForEach(LibrarySort.allCases) { option in
              Text(option.rawValue).tag(option)
            }
          }
          .frame(width: 190)
          Toggle("Favorites", isOn: $showFavoritesOnly)
            .toggleStyle(.button)
            .accessibilityLabel("Show favorites only")
        }
        Text("Shift-click a photo to select a range in the visible order.")
          .font(.caption2).foregroundStyle(.secondary)
        if selectingPhotos || editor.canUndoBatch {
          HStack(spacing: 10) {
            if selectingPhotos {
              Button("Select All") {
                selectedPhotoPaths.formUnion(visibleLibraryPaths)
                selectionAnchor = nil
              }
              .disabled(applyingBatch || exportingBatch)
              Button("Paste to \(selectedPhotoPaths.count) Photos") {
                applySettingsToSelection()
              }
              .disabled(selectedPhotoPaths.isEmpty || applyingBatch || exportingBatch)
              if let workspace = editor.copiedWorkspaceName {
                Button("Paste \(workspace) to \(selectedPhotoPaths.count) Photos") {
                  applySettingsToSelection(workspaceOnly: true)
                }
                .disabled(selectedPhotoPaths.isEmpty || applyingBatch || exportingBatch)
              }
              Menu("Export Selected…") {
                Button("JPEG (sRGB)") { exportSelection(format: .jpeg) }
                Button("16-bit TIFF (sRGB)") { exportSelection(format: .tiff16SRGB) }
                Button("16-bit TIFF (Display P3)") {
                  exportSelection(format: .tiff16DisplayP3)
                }
              }
              .disabled(
                selectedPhotoPaths.isEmpty || applyingBatch || exportingBatch
                  || !editor.canBatchExport)
              if library.catalogs.count > 1, !selectedPhotoPaths.isEmpty {
                catalogTransferMenu(for: Array(selectedPhotoPaths))
              }
            }
            Spacer()
            if editor.canUndoBatch {
              Button("Undo Last Batch", systemImage: "arrow.uturn.backward") {
                let paths = editor.batchChangedPaths
                libraryNotice = editor.undoLastBatch()
                for path in paths { thumbnailRefresh[path, default: 0] += 1 }
              }
              .disabled(applyingBatch)
            }
          }
        }
        if applyingBatch { ProgressView("Applying copied settings…") }
        if importingFolder {
          HStack {
            ProgressView("Scanning photo folders…")
            Spacer()
            Button("Cancel Scan") { folderImportTask?.cancel() }
          }
        }
        if exportingBatch {
          HStack {
            ProgressView(batchExportProgress)
            Spacer()
            Button("Cancel Export") { batchExportTask?.cancel() }
          }
        }
        if let notice = libraryLoad.notice {
          Text(notice)
            .font(.caption)
            .foregroundStyle(.orange)
        }
        if let notice = editor.batchHistoryNotice {
          Text(notice)
            .font(.caption)
            .foregroundStyle(.orange)
        }
        if let libraryNotice {
          Text(libraryNotice)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if !visibleLibraryPaths.isEmpty {
          ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 14) {
              ForEach(visibleLibraryPaths, id: \.self) { path in
                VStack(alignment: .leading, spacing: 8) {
                  Button {
                    selectOrOpenPhoto(path)
                  } label: {
                    VStack(alignment: .leading, spacing: 8) {
                      PhotoThumbnail(
                        path: path, refreshToken: thumbnailRefresh[path, default: 0],
                        activePreview: liveThumbnail(for: path)
                      )
                      .frame(height: 135)
                      .frame(maxWidth: .infinity)
                      .background(Color(white: 0.13))
                      .clipShape(RoundedRectangle(cornerRadius: 7))
                      .overlay {
                        RoundedRectangle(cornerRadius: 7)
                          .strokeBorder(
                            selectedPhotoPaths.contains(path)
                              ? Color.white.opacity(0.85) : .clear,
                            lineWidth: 2)
                      }
                      Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                      if !FileManager.default.fileExists(atPath: path) {
                        Text("Missing original")
                          .font(.caption2)
                          .foregroundStyle(.orange)
                      }
                      if selectingPhotos {
                        Label(
                          selectedPhotoPaths.contains(path) ? "Selected" : "Select",
                          systemImage: selectedPhotoPaths.contains(path)
                            ? "checkmark.circle.fill" : "circle"
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                      }
                    }
                  }
                  .buttonStyle(.plain)
                  .disabled(applyingBatch || exportingBatch)
                  .contextMenu {
                    if let selectionAnchor, selectionAnchor != path,
                      visibleLibraryPaths.contains(selectionAnchor)
                    {
                      Button("Select Range Through This Photo") {
                        selectRange(through: path)
                      }
                    }
                    Button(
                      library.favoritePaths.contains(path) ? "Remove Favorite" : "Add Favorite"
                    ) {
                      updateLibrary { $0.toggleFavorite(path) }
                    }
                    if library.catalogs.count > 1 {
                      catalogTransferMenu(for: [path])
                    }
                    if !FileManager.default.fileExists(atPath: path) {
                      Button("Locate Original…") {
                        pathToRelink = path
                        showingRelinkImporter = true
                      }
                    }
                    Button("Remove from Catalog") {
                      if editor.sourceURL?.standardizedFileURL.path == path,
                        !editor.flushEdits()
                      {
                        libraryNotice = "Current edits could not be saved. The photo was kept."
                      } else if updateLibrary({ $0.removePhoto(path) }) {
                        alignEditorToCatalog()
                      }
                    }
                  }
                  Button {
                    updateLibrary { $0.toggleFavorite(path) }
                  } label: {
                    Label(
                      library.favoritePaths.contains(path) ? "Remove Favorite" : "Add Favorite",
                      systemImage: library.favoritePaths.contains(path) ? "star.fill" : "star"
                    )
                    .font(.caption)
                  }
                  .buttonStyle(.plain)
                  .foregroundStyle(library.favoritePaths.contains(path) ? .yellow : .secondary)
                  .disabled(applyingBatch || exportingBatch)
                  if !FileManager.default.fileExists(atPath: path) {
                    Button("Locate Original…") {
                      pathToRelink = path
                      showingRelinkImporter = true
                    }
                    .font(.caption)
                  }
                }
              }
            }
            .padding(.bottom, 16)
          }
        } else {
          ContentUnavailableView(
            librarySearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              && !showFavoritesOnly
              ? "No photos in this catalog" : "No matching photos",
            systemImage: "photo.on.rectangle.angled",
            description: Text(
              librarySearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !showFavoritesOnly
                ? "Import RAW or rendered photos to begin editing."
                : "Try another filename or turn off the Favorites filter."
            )
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .padding(22)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(white: 0.065))
    }
  }

  private var photoStrip: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        Text(library.selectedCatalog?.name.uppercased() ?? "PHOTOS")
          .font(.caption2.weight(.semibold))
          .tracking(1.2)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Import", systemImage: "plus") { showingImporter = true }
          .labelStyle(.iconOnly)
          .help("Import photos into this catalog")
      }
      ScrollViewReader { proxy in
        ScrollView(.horizontal) {
          HStack(spacing: 8) {
            ForEach(library.selectedCatalog?.photoPaths ?? [], id: \.self) { path in
              Button {
                selectPhoto(path)
              } label: {
                VStack(alignment: .leading, spacing: 5) {
                  PhotoThumbnail(
                    path: path, refreshToken: thumbnailRefresh[path, default: 0],
                    activePreview: liveThumbnail(for: path)
                  )
                  .frame(width: 90, height: 62)
                  .background(Color(white: 0.14))
                  .clipShape(RoundedRectangle(cornerRadius: 5))
                  .overlay {
                    RoundedRectangle(cornerRadius: 5)
                      .strokeBorder(
                        editor.sourceURL?.standardizedFileURL.path == path
                          ? Color.white.opacity(0.8) : .clear, lineWidth: 1.5)
                  }
                  Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 90, alignment: .leading)
                }
              }
              .buttonStyle(.plain)
              .help(path)
              .id(path)
            }
          }
        }
        .onChange(of: editor.sourceURL?.standardizedFileURL.path) { _, path in
          if let path { proxy.scrollTo(path, anchor: .center) }
        }
        .onAppear {
          if let path = editor.sourceURL?.standardizedFileURL.path {
            proxy.scrollTo(path, anchor: .center)
          }
        }
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .frame(height: 118)
    .background(Color(white: 0.095))
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
      if editor.pickingNeutralArea {
        Text("Click a neutral gray or white area with visible detail")
          .font(.caption.weight(.semibold))
          .padding(9)
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 7))
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .padding(16)
          .allowsHitTesting(false)
          .zIndex(1)
      }
      if editor.pickingLocalHue {
        Text("Click a colored detail to target its pre-film hue")
          .font(.caption.weight(.semibold))
          .padding(9)
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 7))
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .padding(16)
          .allowsHitTesting(false)
          .zIndex(1)
      }
      if editor.pickingLocalTone {
        Text("Click a detail to target its pre-film brightness")
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
                if editor.inspectPixel, let point = editor.selectedPixel {
                  let scale = min(
                    geometry.size.width / preview.size.width,
                    geometry.size.height / preview.size.height)
                  let imageWidth = preview.size.width * scale
                  let imageHeight = preview.size.height * scale
                  let left = (geometry.size.width - imageWidth) / 2
                  let top = (geometry.size.height - imageHeight) / 2
                  Circle()
                    .strokeBorder(.white, lineWidth: 1.5)
                    .background(Circle().fill(.black.opacity(0.35)))
                    .frame(width: 13, height: 13)
                    .position(
                      x: left + imageWidth * point.x,
                      y: top + imageHeight * point.y
                    )
                    .allowsHitTesting(false)
                }
              }
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
                  if editor.inspectPixel || editor.placingLocalArea
                    || editor.pickingNeutralArea || editor.pickingLocalHue
                    || editor.pickingLocalTone
                  {
                    let scale = min(
                      geometry.size.width / preview.size.width,
                      geometry.size.height / preview.size.height)
                    let imageWidth = preview.size.width * scale
                    let imageHeight = preview.size.height * scale
                    let left = (geometry.size.width - imageWidth) / 2
                    let top = (geometry.size.height - imageHeight) / 2
                    let x = (value.location.x - left) / imageWidth
                    let y = (value.location.y - top) / imageHeight
                    if editor.pickingNeutralArea {
                      editor.pickNeutralArea(displayX: x, displayY: y)
                    } else if editor.pickingLocalHue {
                      editor.pickLocalHue(displayX: x, displayY: y)
                    } else if editor.pickingLocalTone {
                      editor.pickLocalTone(displayX: x, displayY: y)
                    } else if editor.inspectPixel {
                      editor.inspect(displayX: x, displayY: y)
                    } else {
                      editor.placeSelectedLocalArea(displayX: x, displayY: y)
                    }
                    return
                  }
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
        HStack {
          Text(panel.rawValue).font(.title2.weight(.semibold))
          Spacer()
          Button("Reset \(panel.rawValue)", systemImage: "arrow.counterclockwise") {
            editor.resetPanel(panel)
          }
          .labelStyle(.iconOnly)
          .help("Reset \(panel.rawValue) controls; Undo restores them")
          .disabled(editor.preview == nil || !editor.panelNeedsReset(panel))
        }
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
          Picker("Output scope", selection: $outputScope) {
            ForEach(OutputScopeKind.allCases, id: \.self) { scope in
              Text(scope.rawValue).tag(scope)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          switch outputScope {
          case .histogram:
            OutputHistogram(
              bins: histogram.bins,
              redBins: histogram.redBins,
              greenBins: histogram.greenBins,
              blueBins: histogram.blueBins,
              blackFraction: histogram.blackFraction,
              whiteFraction: histogram.whiteFraction,
              redNearWhiteFraction: histogram.redNearWhiteFraction,
              greenNearWhiteFraction: histogram.greenNearWhiteFraction,
              blueNearWhiteFraction: histogram.blueNearWhiteFraction,
              outsideSRGBFraction: histogram.outsideSRGBFraction
            )
          case .waveform:
            OutputWaveform(distribution: histogram.waveform)
          case .rgbParade:
            OutputRGBParade(
              red: histogram.redWaveform,
              green: histogram.greenWaveform,
              blue: histogram.blueWaveform)
          }
        }
        Toggle("Float preview", isOn: $editor.highPrecisionPreview)
          .font(.caption)
          .help(
            "Develop previews with the 32-bit float working format used for export. Display remains sRGB; full-size previews use more memory."
          )
          .disabled(editor.preview == nil)
        if editor.preview != nil {
          Toggle(
            "Inspect pixel",
            isOn: Binding(
              get: { editor.inspectPixel },
              set: { enabled in
                editor.inspectPixel = enabled
                editor.pixelReadout = nil
                editor.selectedPixel = nil
                if enabled {
                  editor.setPickingNeutralArea(false)
                  editor.zoom100 = false
                  editor.compareEnabled = false
                  editor.placingLocalArea = false
                  editor.paintingLocalArea = false
                  editor.showCropBounds = false
                  editor.renderPreview()
                }
              }
            )
          )
          .font(.caption)
          if editor.inspectPixel {
            if let sample = editor.pixelReadout {
              VStack(alignment: .leading, spacing: 4) {
                Text("EXTENDED LINEAR RGB").font(.caption2.weight(.semibold))
                  .tracking(1).foregroundStyle(.secondary)
                Text(
                  "Input  R \(sample.input.red.formatted(.number.precision(.fractionLength(4))))  G \(sample.input.green.formatted(.number.precision(.fractionLength(4))))  B \(sample.input.blue.formatted(.number.precision(.fractionLength(4))))"
                )
                Text(
                  "Output R \(sample.output.red.formatted(.number.precision(.fractionLength(4))))  G \(sample.output.green.formatted(.number.precision(.fractionLength(4))))  B \(sample.output.blue.formatted(.number.precision(.fractionLength(4))))"
                )
                Text(
                  "Luminance \(sample.input.luminance.formatted(.number.precision(.fractionLength(4)))) → \(sample.output.luminance.formatted(.number.precision(.fractionLength(4))))"
                )
              }
              .font(.system(.caption2, design: .monospaced))
              .textSelection(.enabled)
            } else {
              Text(
                "Click a point on the Fit preview to compare decoded input and developed output."
              )
              .font(.caption2).foregroundStyle(.secondary)
            }
            Text(
              "Linear values can exceed 1 or fall below 0. RAW input is after macOS demosaic and white balance; JPEG input is already rendered."
            )
            .font(.caption2).foregroundStyle(.secondary)
          }
          Toggle(
            "Show sRGB gamut warning",
            isOn: Binding(
              get: { editor.showGamutWarning },
              set: { editor.setGamutWarning($0) }
            )
          )
          .font(.caption)
          Text(
            "Red: above sRGB. Blue: below zero. Preview only; Display P3 TIFF may retain some flagged color."
          )
          .font(.caption2).foregroundStyle(.secondary)
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
          Text("Input neutral correction").font(.headline)
          HStack {
            Button(editor.pickingNeutralArea ? "Cancel pick" : "Pick neutral area") {
              editor.setPickingNeutralArea(!editor.pickingNeutralArea)
            }
            Button("Clear") { editor.clearNeutralBalance() }
              .disabled(editor.inputNeutralBalance.isNeutral)
          }
          Text(
            "R \(editor.inputNeutralBalance.red.formatted(.number.precision(.fractionLength(2))))×  G \(editor.inputNeutralBalance.green.formatted(.number.precision(.fractionLength(2))))×  B \(editor.inputNeutralBalance.blue.formatted(.number.precision(.fractionLength(2))))×"
          )
          .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
          if let notice = editor.neutralNotice {
            Text(notice).font(.caption).foregroundStyle(.orange)
          }
          Text("Balances decoded RGB before film. RAW decoder white balance stays separate.")
            .font(.caption).foregroundStyle(.secondary)
          Divider()
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
            Text("Rendered input").font(.headline)
            control("Input tone", value: $editor.inputTone, range: 0.5...1.5)
            control("Input warmth", value: $editor.inputWarmth, range: -1...1)
            control("Input tint", value: $editor.inputTint, range: -1...1)
            if let nearWhite = editor.jpegChannelNearWhiteFraction, nearWhite >= 0.01 {
              Text(
                "JPEG input: \(nearWhite.formatted(.percent.precision(.fractionLength(1)))) of sampled pixels have a display RGB channel near white. Check bright detail; this does not prove clipping."
              )
              .font(.caption).foregroundStyle(.secondary)
            }
            Text(
              "Input tone below 1 softens contrast; above 1 expands it. Middle gray stays fixed before film processing."
            )
            .font(.caption).foregroundStyle(.secondary)
            Divider()
          }
          Text("Scene light before film").font(.headline)
          control("Shadow light (EV)", value: $editor.shadowLight, range: -2...2)
          control("Highlight light (EV)", value: $editor.highlightLight, range: -2...2)
          Text("Changes the light reaching the film model in each tonal region.")
            .font(.caption).foregroundStyle(.secondary)
          control("Film light warmth", value: $editor.filmLightWarmth, range: -1...1)
          control("Film light tint (magenta +)", value: $editor.filmLightTint, range: -1...1)
          Text(
            "Balances light before the stock response, so color separation changes with exposure."
          )
          .font(.caption).foregroundStyle(.secondary)
          Divider()
          control("Output exposure (EV)", value: $editor.exposure, range: -3...3)
          control("Contrast", value: $editor.contrast, range: 0.5...1.5)
          control("Saturation", value: $editor.saturation, range: 0...1.5)
          control("Warmth", value: $editor.warmth, range: -1...1)
          control("Output tint (magenta +)", value: $editor.tint, range: -1...1)
          Divider()
          Text("Output tone curve").font(.headline)
          control("Shadow point", value: $editor.curveShadow, range: -0.14...0.14)
          control("Midtone point", value: $editor.curveMidtone, range: -0.14...0.14)
          control("Highlight point", value: $editor.curveHighlight, range: -0.14...0.14)
          Text(
            "These points reshape output brightness after film processing while scaling RGB together."
          )
          .font(.caption).foregroundStyle(.secondary)
          Divider()
          control("Output shoulder", value: $editor.outputShoulder, range: 0...1)
          Text(
            "Rolls bright output toward white while preserving linear RGB ratios. The film and paper models still respond before this finishing control."
          )
          .font(.caption).foregroundStyle(.secondary)
        case .color:
          Text("Master color").font(.headline)
          if editor.colorTimingVersion < 2 {
            Button("Use consistent color timing") { editor.useConsistentColorTiming() }
            Text(
              "Updates this older grade to hue timing that is consistent across Macs. Existing shadow, midtone, or highlight color may shift; Undo restores it."
            )
            .font(.caption).foregroundStyle(.secondary)
            Divider()
          }
          control("Vibrance", value: $editor.vibrance, range: -1...1)
          Text("Changes muted colors more than already saturated colors while retaining luminance.")
            .font(.caption).foregroundStyle(.secondary)
          Divider()
          Text("Color mixer").font(.headline)
          if editor.mixerVersion < 2 {
            Button("Use luminance-preserving mixer") {
              editor.useLuminancePreservingMixer()
            }
            Text(
              "Updates this older grade's Color Mixer. Active hue or saturation adjustments may shift; Undo restores the previous rendering."
            )
            .font(.caption).foregroundStyle(.secondary)
          }
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
          Toggle("Limit by brightness", isOn: localBoolBinding(\.toneRangeEnabled))
          if editor.radialLights[editor.selectedLocalIndex].toneRangeEnabled {
            Button(
              editor.pickingLocalTone ? "Cancel pick" : "Pick brightness on photo",
              systemImage: "eyedropper"
            ) { editor.setPickingLocalTone(!editor.pickingLocalTone) }
            .disabled(editor.preview == nil)
            if let notice = editor.localToneNotice {
              Text(notice).font(.caption).foregroundStyle(.orange)
            }
            control("Brightness center (stops)", value: localBinding(\.toneCenter), range: -6...6)
            control("Brightness width (stops)", value: localBinding(\.toneWidth), range: 0.5...8)
            control("Brightness softness", value: localBinding(\.toneFeather), range: 0.1...2)
            Text(
              "Selects pre-film luminance relative to 18% linear gray. JPEG tone is already baked in. Use Show mask to inspect the affected pixels."
            )
            .font(.caption).foregroundStyle(.secondary)
          }
          Toggle("Limit by color", isOn: localBoolBinding(\.hueRangeEnabled))
          if editor.radialLights[editor.selectedLocalIndex].hueRangeEnabled {
            Button(
              editor.pickingLocalHue ? "Cancel pick" : "Pick color on photo",
              systemImage: "eyedropper"
            ) {
              editor.setPickingLocalHue(!editor.pickingLocalHue)
            }
            .disabled(editor.preview == nil)
            if let notice = editor.localHueNotice {
              Text(notice).font(.caption).foregroundStyle(.orange)
            }
            control("Hue center (°)", value: localBinding(\.hueCenter), range: 0...360)
            control("Hue reach (°)", value: localBinding(\.hueWidth), range: 5...90)
            control("Hue softness (°)", value: localBinding(\.hueFeather), range: 5...45)
            Text(
              "Selects colored pixels by pre-film RGB hue; grays and very dark pixels are excluded. Use Show mask to inspect the selection."
            )
            .font(.caption).foregroundStyle(.secondary)
          }
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
            Text("Portrait 2:3").tag(6)
            Text("Tall 9:16").tag(7)
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
          control("Grain size", value: $editor.grainSize, range: 0...2)
          if editor.grainSeed == 0 {
            Button("Use unique grain pattern") { editor.usePhotoGrainPattern() }
            Text(
              "Older grades keep their original grain pattern until you choose this change. Undo restores the earlier pattern."
            )
            .font(.caption).foregroundStyle(.secondary)
          }
          control("Halation", value: $editor.halation, range: 0...1)
          control("Edge detail", value: $editor.acutance, range: 0...1)
          Text(
            "Grain size 0 keeps the earlier fine noise; 1 adds roughly 2–3 source-pixel structure. Inspect texture and edge detail at 100% zoom."
          )
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
    return VStack(alignment: .leading) {
      HStack {
        Text(title)
        Spacer()
        NumericControlField(
          title: title, value: value, range: range, fractionDigits: fractionDigits)
      }
      .font(.subheadline)
      Slider(value: value, in: range)
    }
  }
}
