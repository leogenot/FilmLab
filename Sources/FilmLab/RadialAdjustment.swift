/// One geometric light adjustment, evaluated before the selected film response.
struct RadialAdjustment: Codable, Equatable {
  var exposure: Double
  var centerX: Double
  var centerY: Double
  var radius: Double
  var feather: Double
  var inverted: Bool
  var shape: Int
  var angle: Double

  init(
    exposure: Double = 0, centerX: Double = 0.5, centerY: Double = 0.5,
    radius: Double = 0.35, feather: Double = 0.5, inverted: Bool = false,
    shape: Int = 0, angle: Double = 90
  ) {
    self.exposure = exposure
    self.centerX = centerX
    self.centerY = centerY
    self.radius = radius
    self.feather = feather
    self.inverted = inverted
    self.shape = shape
    self.angle = angle
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    exposure = try values.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
    centerX = try values.decodeIfPresent(Double.self, forKey: .centerX) ?? 0.5
    centerY = try values.decodeIfPresent(Double.self, forKey: .centerY) ?? 0.5
    radius = try values.decodeIfPresent(Double.self, forKey: .radius) ?? 0.35
    feather = try values.decodeIfPresent(Double.self, forKey: .feather) ?? 0.5
    inverted = try values.decodeIfPresent(Bool.self, forKey: .inverted) ?? false
    shape = try values.decodeIfPresent(Int.self, forKey: .shape) ?? 0
    angle = try values.decodeIfPresent(Double.self, forKey: .angle) ?? 90
  }
}
