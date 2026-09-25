struct BrushPoint: Codable, Equatable {
  var x: Double
  var y: Double
}

struct BrushStroke: Codable, Equatable {
  var points: [BrushPoint]
  var size: Double
  var erasing: Bool

  init(points: [BrushPoint], size: Double = 0.03, erasing: Bool = false) {
    self.points = points
    self.size = size
    self.erasing = erasing
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    points = try values.decode([BrushPoint].self, forKey: .points)
    size = try values.decodeIfPresent(Double.self, forKey: .size) ?? 0.03
    erasing = try values.decodeIfPresent(Bool.self, forKey: .erasing) ?? false
  }
}

/// One geometric scene adjustment, evaluated before the selected film response.
struct RadialAdjustment: Codable, Equatable {
  var exposure: Double
  var warmth: Double
  var tint: Double
  var centerX: Double
  var centerY: Double
  var radius: Double
  var feather: Double
  var inverted: Bool
  var shape: Int
  var angle: Double
  var brushSize: Double
  var strokes: [BrushStroke]
  var toneRangeEnabled: Bool
  var toneCenter: Double
  var toneWidth: Double
  var toneFeather: Double
  var hueRangeEnabled: Bool
  var hueCenter: Double
  var hueWidth: Double
  var hueFeather: Double

  init(
    exposure: Double = 0, warmth: Double = 0, tint: Double = 0,
    centerX: Double = 0.5, centerY: Double = 0.5,
    radius: Double = 0.35, feather: Double = 0.5, inverted: Bool = false,
    shape: Int = 0, angle: Double = 90,
    brushSize: Double = 0.03, strokes: [BrushStroke] = [],
    toneRangeEnabled: Bool = false, toneCenter: Double = 0,
    toneWidth: Double = 4, toneFeather: Double = 1,
    hueRangeEnabled: Bool = false, hueCenter: Double = 210,
    hueWidth: Double = 45, hueFeather: Double = 20
  ) {
    self.exposure = exposure
    self.warmth = warmth
    self.tint = tint
    self.centerX = centerX
    self.centerY = centerY
    self.radius = radius
    self.feather = feather
    self.inverted = inverted
    self.shape = shape
    self.angle = angle
    self.brushSize = brushSize
    self.strokes = strokes
    self.toneRangeEnabled = toneRangeEnabled
    self.toneCenter = toneCenter
    self.toneWidth = toneWidth
    self.toneFeather = toneFeather
    self.hueRangeEnabled = hueRangeEnabled
    self.hueCenter = hueCenter
    self.hueWidth = hueWidth
    self.hueFeather = hueFeather
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    exposure = try values.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
    warmth = try values.decodeIfPresent(Double.self, forKey: .warmth) ?? 0
    tint = try values.decodeIfPresent(Double.self, forKey: .tint) ?? 0
    centerX = try values.decodeIfPresent(Double.self, forKey: .centerX) ?? 0.5
    centerY = try values.decodeIfPresent(Double.self, forKey: .centerY) ?? 0.5
    radius = try values.decodeIfPresent(Double.self, forKey: .radius) ?? 0.35
    feather = try values.decodeIfPresent(Double.self, forKey: .feather) ?? 0.5
    inverted = try values.decodeIfPresent(Bool.self, forKey: .inverted) ?? false
    shape = try values.decodeIfPresent(Int.self, forKey: .shape) ?? 0
    angle = try values.decodeIfPresent(Double.self, forKey: .angle) ?? 90
    brushSize = try values.decodeIfPresent(Double.self, forKey: .brushSize) ?? 0.03
    strokes = try values.decodeIfPresent([BrushStroke].self, forKey: .strokes) ?? []
    toneRangeEnabled = try values.decodeIfPresent(Bool.self, forKey: .toneRangeEnabled) ?? false
    toneCenter = try values.decodeIfPresent(Double.self, forKey: .toneCenter) ?? 0
    toneWidth = try values.decodeIfPresent(Double.self, forKey: .toneWidth) ?? 4
    toneFeather = try values.decodeIfPresent(Double.self, forKey: .toneFeather) ?? 1
    hueRangeEnabled = try values.decodeIfPresent(Bool.self, forKey: .hueRangeEnabled) ?? false
    hueCenter = try values.decodeIfPresent(Double.self, forKey: .hueCenter) ?? 210
    hueWidth = try values.decodeIfPresent(Double.self, forKey: .hueWidth) ?? 45
    hueFeather = try values.decodeIfPresent(Double.self, forKey: .hueFeather) ?? 20
  }
}
