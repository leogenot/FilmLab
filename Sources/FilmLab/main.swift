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
  var filmAmount = 1.0
  var stockIndex = 0
  var enduraPaperTone = false
  var paperStrength = 0.5
  var paperExposure = 0.0
  var shotExposure = 0.0
  var shadowLight = 0.0
  var highlightLight = 0.0
  var development = 0.0
  var grain = 0.0
  var halation = 0.0
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
  var frameAspect = 0
  var frameOffsetX = 0.0
  var frameOffsetY = 0.0
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
    filmAmount = try values.decodeIfPresent(Double.self, forKey: .filmAmount) ?? 1.0
    stockIndex = try values.decodeIfPresent(Int.self, forKey: .stockIndex) ?? 0
    enduraPaperTone = try values.decodeIfPresent(Bool.self, forKey: .enduraPaperTone) ?? false
    paperStrength = try values.decodeIfPresent(Double.self, forKey: .paperStrength) ?? 0.5
    paperExposure = try values.decodeIfPresent(Double.self, forKey: .paperExposure) ?? 0
    shotExposure = try values.decodeIfPresent(Double.self, forKey: .shotExposure) ?? 0
    shadowLight = try values.decodeIfPresent(Double.self, forKey: .shadowLight) ?? 0
    highlightLight = try values.decodeIfPresent(Double.self, forKey: .highlightLight) ?? 0
    development = try values.decodeIfPresent(Double.self, forKey: .development) ?? 0
    grain = try values.decodeIfPresent(Double.self, forKey: .grain) ?? 0
    halation = try values.decodeIfPresent(Double.self, forKey: .halation) ?? 0
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
    frameAspect = try values.decodeIfPresent(Int.self, forKey: .frameAspect) ?? 0
    frameOffsetX = try values.decodeIfPresent(Double.self, forKey: .frameOffsetX) ?? 0
    frameOffsetY = try values.decodeIfPresent(Double.self, forKey: .frameOffsetY) ?? 0
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
  var filmAmount = 1.0
  var stockIndex = 0
  var enduraPaperTone = false
  var paperStrength = 0.5
  var paperExposure = 0.0
  var shotExposure = 0.0
  var shadowLight = 0.0
  var highlightLight = 0.0
  var development = 0.0
  var grain = 0.0
  var halation = 0.0
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
  var frameAspect = 0
  var frameOffsetX = 0.0
  var frameOffsetY = 0.0
  var flatRAW = false
  var rawHighlightRecovery = true
  var rawHighlightRecoverySupported = false
  var rawTemperature = 6500.0
  var rawTint = 0.0
  var error: String?
  var showOriginal = false
  var zoom100 = false
  var isRendering = false
  var isExporting = false

  private var source: CIImage?
  private var didAttemptResume = false
  private let lastPhotoKey = "FilmLab.lastPhotoPath"
  private var decodedFlatRAW = false
  private var decodedHighlightRecovery = true
  private var decodedRawTemperature = 6500.0
  private var decodedRawTint = 0.0
  private var cameraRawTemperature = 6500.0
  private var cameraRawTint = 0.0
  private var sourceIsRAW = false
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
    rawDecodeTask?.cancel()
    rawDecodeVersion += 1
    saveTask?.cancel()
    if sourceURL != nil { saveEdits() }
    let access = url.startAccessingSecurityScopedResource()
    do {
      let isRAW = isRAWFile(url)
      let saved = savedEdits(for: url, isRAW: isRAW)
      let decoded = try decodeImage(
        from: url, isRAW: isRAW, flatRAW: saved.flatRAW,
        highlightRecovery: saved.rawHighlightRecovery, temperature: saved.rawTemperature,
        tint: saved.rawTint
      )
      let image = decoded.image
      guard image.extent.width.isFinite, image.extent.height.isFinite,
        image.extent.width > 0, image.extent.height > 0
      else {
        throw EditorError.unsupported
      }
      previewTask?.cancel()
      renderVersion += 1
      if let scopedURL { scopedURL.stopAccessingSecurityScopedResource() }
      scopedURL = access ? url : nil
      source = image
      sourceURL = url
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
    } catch {
      if access { url.stopAccessingSecurityScopedResource() }
      self.error = error.localizedDescription
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

  private func savedEdits(for url: URL, isRAW: Bool) -> PhotoEdits {
    if let data = try? Data(contentsOf: editsURL(for: url)),
      let saved = try? JSONDecoder().decode(PhotoEdits.self, from: data)
    {
      return saved
    }
    return PhotoEdits.defaults(forRAW: isRAW)
  }

  private func isRAWFile(_ url: URL) -> Bool {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let identifier = CGImageSourceGetType(source) as String?,
      let type = UTType(identifier)
    else { return false }
    return type.conforms(to: .rawImage)
  }

  private func decodeImage(
    from url: URL, isRAW: Bool, flatRAW: Bool, highlightRecovery: Bool,
    temperature: Double?, tint: Double?
  ) throws -> (
    image: CIImage, cameraTemperature: Double?, cameraTint: Double?,
    highlightRecoverySupported: Bool
  ) {
    if isRAW {
      guard let raw = CIRAWFilter(imageURL: url) else { throw EditorError.unsupported }
      let cameraTemperature = Double(raw.neutralTemperature)
      let cameraTint = Double(raw.neutralTint)
      var highlightRecoverySupported = false
      if #available(macOS 26.0, *) {
        highlightRecoverySupported = raw.isHighlightRecoverySupported
        if highlightRecoverySupported { raw.isHighlightRecoveryEnabled = highlightRecovery }
      }
      if let temperature { raw.neutralTemperature = Float(temperature) }
      if let tint { raw.neutralTint = Float(tint) }
      if flatRAW {
        raw.boostAmount = 0
        raw.boostShadowAmount = 0
        raw.localToneMapAmount = 0
      }
      guard let image = raw.outputImage else { throw EditorError.unsupported }
      return (image, cameraTemperature, cameraTint, highlightRecoverySupported)
    }
    let data = try Data(contentsOf: url)
    guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
      throw EditorError.unsupported
    }
    return (image, nil, nil, false)
  }

  private func restoreEdits(_ saved: PhotoEdits) {
    exposure = saved.exposure
    contrast = saved.contrast
    saturation = saved.saturation
    warmth = saved.warmth
    filmAmount = saved.filmAmount
    stockIndex = saved.stockIndex
    enduraPaperTone = saved.enduraPaperTone
    paperStrength = saved.paperStrength
    paperExposure = saved.paperExposure
    shotExposure = saved.shotExposure
    shadowLight = saved.shadowLight
    highlightLight = saved.highlightLight
    development = saved.development
    grain = saved.grain
    halation = saved.halation
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
    frameAspect = saved.frameAspect
    frameOffsetX = saved.frameOffsetX
    frameOffsetY = saved.frameOffsetY
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
        let decoded = try decodeImage(
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
    edits.filmAmount = filmAmount
    edits.stockIndex = stockIndex
    edits.enduraPaperTone = enduraPaperTone
    edits.paperStrength = paperStrength
    edits.paperExposure = paperExposure
    edits.shotExposure = shotExposure
    edits.shadowLight = shadowLight
    edits.highlightLight = highlightLight
    edits.development = development
    edits.grain = grain
    edits.halation = halation
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
    edits.frameAspect = frameAspect
    edits.frameOffsetX = frameOffsetX
    edits.frameOffsetY = frameOffsetY
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
    let edits = currentEdits()
    let url = editsURL(for: sourceURL)
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true
      )
      try JSONEncoder().encode(edits).write(to: url, options: .atomic)
    } catch {
      self.error = "Could not save edits: \(error.localizedDescription)"
    }
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
    filmAmount = defaults.filmAmount
    stockIndex = defaults.stockIndex
    enduraPaperTone = defaults.enduraPaperTone
    paperStrength = defaults.paperStrength
    paperExposure = defaults.paperExposure
    shotExposure = defaults.shotExposure
    shadowLight = defaults.shadowLight
    highlightLight = defaults.highlightLight
    development = defaults.development
    grain = defaults.grain
    halation = defaults.halation
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
    frameAspect = defaults.frameAspect
    frameOffsetX = defaults.frameOffsetX
    frameOffsetY = defaults.frameOffsetY
    flatRAW = defaults.flatRAW
    rawHighlightRecovery = defaults.rawHighlightRecovery
    rawTemperature = cameraRawTemperature
    rawTint = cameraRawTint
    showOriginal = false
    compareEnabled = false
    editsChanged()
  }

  func toggleBeforeAfter() {
    compareEnabled = false
    showOriginal.toggle()
    renderPreview()
  }

  func toggleZoom() {
    compareEnabled = false
    zoom100.toggle()
    renderPreview()
  }

  func toggleCompare() {
    compareEnabled.toggle()
    showOriginal = false
    zoom100 = false
    renderPreview()
  }

  private func developedImage() -> CIImage? {
    guard var image = source else { return nil }
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
            stockIndex == 1 && enduraPaperTone ? paperStrength : 0.0, paperExposure,
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
    return framedImage(FilmEffects.apply(to: mixed, grain: grain, halation: halation))
  }

  private func framedImage(_ image: CIImage) -> CIImage {
    let turns = ((frameRotation % 4) + 4) % 4
    var framed = image
    if turns != 0 {
      framed = framed.transformed(by: CGAffineTransform(rotationAngle: CGFloat(turns) * .pi / 2))
      framed = framed.transformed(
        by: CGAffineTransform(translationX: -framed.extent.minX, y: -framed.extent.minY))
    }
    let extent = framed.extent
    let ratio: CGFloat? =
      switch frameAspect {
      case 1: 1
      case 2: 4.0 / 5.0
      case 3: 3.0 / 2.0
      case 4: 16.0 / 9.0
      default: nil
      }
    guard let ratio, extent.width > 0, extent.height > 0 else { return framed }
    let width = min(extent.width, floor(extent.height * ratio))
    let height = min(extent.height, floor(extent.width / ratio))
    let x = extent.minX + (extent.width - width) * CGFloat(min(max(frameOffsetX, -1), 1) + 1) / 2
    let y = extent.minY + (extent.height - height) * CGFloat(min(max(frameOffsetY, -1), 1) + 1) / 2
    return framed.cropped(to: CGRect(x: floor(x), y: floor(y), width: width, height: height))
  }

  func rotateFrame(_ steps: Int) {
    frameRotation = ((frameRotation + steps) % 4 + 4) % 4
    editsChanged()
  }

  func renderPreview() {
    renderVersion += 1
    let version = renderVersion
    previewTask?.cancel()
    guard let image = showOriginal ? source.map(framedImage) : developedImage() else {
      isRendering = false
      return
    }
    isRendering = true
    let scale = zoom100 ? 1 : min(1, 1800 / max(image.extent.width, image.extent.height))
    let request = PreviewRequest(
      image: image, scale: scale, sourceURL: scopedURL,
      originalImage: compareEnabled ? source.map(framedImage) : nil
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
        histogram = result.histogram
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
    beginExport(ExportRequest(image: image, url: url, format: .jpeg, sourceURL: scopedURL))
  }

  func exportTIFF() {
    guard let image = developedImage() else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.tiff]
    panel.nameFieldStringValue =
      (sourceURL?.deletingPathExtension().lastPathComponent ?? "Photo") + "-FilmLab.tiff"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    beginExport(ExportRequest(image: image, url: url, format: .tiff16, sourceURL: scopedURL))
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
  case texture = "Texture"
  case framing = "Framing"

  var id: Self { self }
  var symbol: String {
    switch self {
    case .film: "camera.filters"
    case .develop: "slider.horizontal.3"
    case .color: "circle.lefthalf.filled"
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
    .onChange(of: scenePhase) {
      if scenePhase != .active { editor.flushEdits() }
    }
    .onChange(of: editor.exposure) { editor.editsChanged() }
    .onChange(of: editor.contrast) { editor.editsChanged() }
    .onChange(of: editor.saturation) { editor.editsChanged() }
    .onChange(of: editor.warmth) { editor.editsChanged() }
    .onChange(of: editor.filmAmount) { editor.editsChanged() }
    .onChange(of: editor.stockIndex) { editor.editsChanged() }
    .onChange(of: editor.enduraPaperTone) { editor.editsChanged() }
    .onChange(of: editor.paperStrength) { editor.editsChanged() }
    .onChange(of: editor.paperExposure) { editor.editsChanged() }
    .onChange(of: editor.shotExposure) { editor.editsChanged() }
    .onChange(of: editor.shadowLight) { editor.editsChanged() }
    .onChange(of: editor.highlightLight) { editor.editsChanged() }
    .onChange(of: editor.development) { editor.editsChanged() }
    .onChange(of: editor.grain) { editor.editsChanged() }
    .onChange(of: editor.halation) { editor.editsChanged() }
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
    .onChange(of: editor.frameAspect) { editor.editsChanged() }
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
      if editor.isRendering || editor.isExporting {
        ProgressView(editor.isExporting ? "Exporting photo…" : "Rendering preview…")
          .padding(10)
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 7))
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
          .padding(16)
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
          Image(nsImage: preview)
            .resizable()
            .scaledToFit()
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
            if editor.enduraPaperTone {
              control("Paper exposure (EV)", value: $editor.paperExposure, range: -2...2)
              control("Paper strength", value: $editor.paperStrength, range: 0...1)
              Text("More paper exposure makes the print darker.")
                .font(.caption).foregroundStyle(.secondary)
            }
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
                ? "Kodak Ektar negative-density curves with provisional positive rendering."
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
        case .framing:
          HStack {
            Button("Rotate left", systemImage: "rotate.left") { editor.rotateFrame(-1) }
            Button("Rotate right", systemImage: "rotate.right") { editor.rotateFrame(1) }
          }
          Picker("Crop ratio", selection: $editor.frameAspect) {
            Text("Original").tag(0)
            Text("Square 1:1").tag(1)
            Text("Portrait 4:5").tag(2)
            Text("Landscape 3:2").tag(3)
            Text("Wide 16:9").tag(4)
          }
          .pickerStyle(.menu)
          if editor.frameAspect != 0 {
            control("Horizontal position", value: $editor.frameOffsetX, range: -1...1)
            control("Vertical position", value: $editor.frameOffsetY, range: -1...1)
          }
          Text("Framing is saved with this photo and applied at full resolution on export.")
            .font(.caption).foregroundStyle(.secondary)
        case .texture:
          control("Grain", value: $editor.grain, range: 0...1)
          control("Halation", value: $editor.halation, range: 0...1)
          Text("Inspect texture at 100% zoom.")
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
