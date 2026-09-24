/// One geometric light adjustment, evaluated before the selected film response.
struct RadialAdjustment: Codable, Equatable {
  var exposure = 0.0
  var centerX = 0.5
  var centerY = 0.5
  var radius = 0.35
  var feather = 0.5
  var inverted = false
}
