import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CryptoKit
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

private struct PhotoEdits: Codable {
  var exposure = 0.0
  var contrast = 1.0
  var saturation = 1.0
  var warmth = 0.0
  var filmAmount = 0.7
  var shotExposure = 0.0
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

  init() {}

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    exposure = try values.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
    contrast = try values.decodeIfPresent(Double.self, forKey: .contrast) ?? 1
    saturation = try values.decodeIfPresent(Double.self, forKey: .saturation) ?? 1
    warmth = try values.decodeIfPresent(Double.self, forKey: .warmth) ?? 0
    filmAmount = try values.decodeIfPresent(Double.self, forKey: .filmAmount) ?? 0.7
    shotExposure = try values.decodeIfPresent(Double.self, forKey: .shotExposure) ?? 0
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
  }
}

@MainActor @Observable
final class PhotoEditor {
  var sourceURL: URL?
  var preview: NSImage?
  var exposure = 0.0
  var contrast = 1.0
  var saturation = 1.0
  var warmth = 0.0
  var filmAmount = 0.7
  var shotExposure = 0.0
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
  var error: String?
  var showOriginal = false
  var zoom100 = false
  var isRendering = false
  var isExporting = false

  private var source: CIImage?
  private var scopedURL: URL?
  private var saveTask: Task<Void, Never>?
  private var previewTask: Task<Void, Never>?
  private var renderVersion = 0
  private let previewRenderer = PreviewRenderer()
  private let exporter = ImageExporter()

  // Scene-linear RGB enters this kernel in the context's extended linear working space.
  // This is a provisional response model, not a measured emulsion profile.
  private let filmKernel = CIColorKernel(
    source: """
          float softplus(float x) {
              return log(1.0 + exp(clamp(x, -30.0, 30.0)));
          }
          float response(float light, float ev, float dev, float toe, float shoulder) {
              float stops = log2(max(light, 0.000001) / 0.18) + ev;
              float slope = 1.0 + dev * 0.18;
              float low = toe * softplus((-stops - 4.5) / toe);
              float high = shoulder * softplus((stops - 2.0) / shoulder);
              float densityStops = slope * (stops + low - high);
              float zeroLow = toe * softplus(-4.5 / toe);
              float zeroHigh = shoulder * softplus(-2.0 / shoulder);
              densityStops -= slope * (zeroLow - zeroHigh);
              return 0.18 * exp2(densityStops);
          }
          kernel vec4 filmResponse(__sample pixel, float ev, float dev, float amount) {
              vec3 rgb = max(pixel.rgb, vec3(0.0));
              // Small layer differences create exposure-dependent color separation.
              vec3 film = vec3(
                  response(rgb.r, ev, dev, 0.72, 1.10),
                  response(rgb.g, ev, dev, 0.82, 0.92),
                  response(rgb.b, ev, dev, 0.94, 0.78)
              );
              return vec4(mix(rgb * exp2(ev), film, amount), pixel.a);
          }
      """)

  func open(_ url: URL) {
    saveTask?.cancel()
    if sourceURL != nil { saveEdits() }
    let access = url.startAccessingSecurityScopedResource()
    do {
      let rawExtensions: Set<String> = ["arw", "cr2", "cr3", "dng", "nef", "raf", "rw2"]
      let image: CIImage?
      if rawExtensions.contains(url.pathExtension.lowercased()) {
        image = CIRAWFilter(imageURL: url)?.outputImage
      } else {
        let data = try Data(contentsOf: url)
        image = CIImage(data: data, options: [.applyOrientationProperty: true])
      }
      guard let image, image.extent.width.isFinite, image.extent.height.isFinite,
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
      showOriginal = false
      zoom100 = false
      restoreEdits(for: url)
      preview = nil
      error = nil
      renderPreview()
    } catch {
      if access { url.stopAccessingSecurityScopedResource() }
      self.error = error.localizedDescription
    }
  }

  private func editsURL(for url: URL) -> URL {
    let key = SHA256.hash(data: Data(url.standardizedFileURL.path.utf8))
      .map { String(format: "%02x", $0) }.joined()
    return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("FilmLab/Edits", isDirectory: true)
      .appendingPathComponent(key + ".json")
  }

  private func restoreEdits(for url: URL) {
    let saved =
      (try? Data(contentsOf: editsURL(for: url))).flatMap {
        try? JSONDecoder().decode(PhotoEdits.self, from: $0)
      } ?? PhotoEdits()
    exposure = saved.exposure
    contrast = saved.contrast
    saturation = saved.saturation
    warmth = saved.warmth
    filmAmount = saved.filmAmount
    shotExposure = saved.shotExposure
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
  }

  func editsChanged() {
    renderPreview()
    saveTask?.cancel()
    saveTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled else { return }
      saveEdits()
    }
  }

  private func saveEdits() {
    guard let sourceURL else { return }
    var edits = PhotoEdits()
    edits.exposure = exposure
    edits.contrast = contrast
    edits.saturation = saturation
    edits.warmth = warmth
    edits.filmAmount = filmAmount
    edits.shotExposure = shotExposure
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

  func resetEdits() {
    let defaults = PhotoEdits()
    exposure = defaults.exposure
    contrast = defaults.contrast
    saturation = defaults.saturation
    warmth = defaults.warmth
    filmAmount = defaults.filmAmount
    shotExposure = defaults.shotExposure
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
    showOriginal = false
    editsChanged()
  }

  func toggleBeforeAfter() {
    showOriginal.toggle()
    renderPreview()
  }

  func toggleZoom() {
    zoom100.toggle()
    renderPreview()
  }

  private func developedImage() -> CIImage? {
    guard var image = source else { return nil }
    image = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: exposure])
    image = image.applyingFilter(
      "CIColorControls",
      parameters: [
        kCIInputContrastKey: contrast,
        kCIInputSaturationKey: saturation,
      ])
    if let filmKernel,
      let film = filmKernel.apply(
        extent: image.extent,
        arguments: [
          image, shotExposure, development, filmAmount,
        ])
    {
      image = film
    } else {
      error = "The film response could not be loaded."
    }
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
    return FilmEffects.apply(to: selected, grain: grain, halation: halation)
  }

  func renderPreview() {
    renderVersion += 1
    let version = renderVersion
    previewTask?.cancel()
    guard let image = showOriginal ? source : developedImage() else {
      isRendering = false
      return
    }
    isRendering = true
    let scale = zoom100 ? 1 : min(1, 1800 / max(image.extent.width, image.extent.height))
    let request = PreviewRequest(image: image, scale: scale, sourceURL: scopedURL)
    previewTask = Task {
      do { try await Task.sleep(for: .milliseconds(60)) } catch { return }
      let result = await previewRenderer.render(request)
      guard !Task.isCancelled, version == renderVersion else { return }
      if let result {
        let image = result.image
        preview = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
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

  var id: Self { self }
  var symbol: String {
    switch self {
    case .film: "camera.filters"
    case .develop: "slider.horizontal.3"
    case .color: "circle.lefthalf.filled"
    case .texture: "circle.hexagongrid"
    }
  }
}

struct ContentView: View {
  @Bindable var editor: PhotoEditor
  @State private var showingImporter = false
  @State private var panel: EditorPanel = .film
  @Environment(\.displayScale) private var displayScale

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
    .onChange(of: editor.exposure) { editor.editsChanged() }
    .onChange(of: editor.contrast) { editor.editsChanged() }
    .onChange(of: editor.saturation) { editor.editsChanged() }
    .onChange(of: editor.warmth) { editor.editsChanged() }
    .onChange(of: editor.filmAmount) { editor.editsChanged() }
    .onChange(of: editor.shotExposure) { editor.editsChanged() }
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
        if editor.zoom100 {
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
        switch panel {
        case .film:
          control("Shot exposure (EV)", value: $editor.shotExposure, range: -3...3)
          control("Development", value: $editor.development, range: -2...2)
          control("Stock amount", value: $editor.filmAmount, range: 0...1)
          Text("Exposure-dependent study stock. Film measurements will replace this model.")
            .font(.caption).foregroundStyle(.secondary)
        case .develop:
          control("Exposure correction", value: $editor.exposure, range: -3...3)
          control("Contrast", value: $editor.contrast, range: 0.5...1.5)
          control("Saturation", value: $editor.saturation, range: 0...1.5)
          control("Warmth", value: $editor.warmth, range: -1...1)
        case .color:
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

  private func control(_ title: String, value: Binding<Double>, range: ClosedRange<Double>)
    -> some View
  {
    VStack(alignment: .leading) {
      HStack {
        Text(title)
        Spacer()
        Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
          .monospacedDigit()
      }
      .font(.subheadline)
      Slider(value: value, in: range)
    }
  }
}
