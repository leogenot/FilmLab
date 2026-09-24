import CoreImage

/// Metal Core Image kernels shared by preview and full-resolution export.
enum FilmKernels {
  private static let kernels: [String: CIColorKernel] = {
    do {
      let compiled = try CIKernel.kernels(withMetalString: source)
      return Dictionary(
        uniqueKeysWithValues: compiled.compactMap { kernel in
          (kernel as? CIColorKernel).map { (kernel.name, $0) }
        })
    } catch {
      assertionFailure("Could not compile FilmLab Metal kernels: \(error)")
      return [:]
    }
  }()

  static func kernel(_ name: String) -> CIColorKernel? { kernels[name] }

  private static let source = #"""
    #include <CoreImage/CoreImage.h>
    using namespace metal;

    inline float softplus(float x) {
                  return log(1.0 + exp(clamp(x, -30.0, 30.0)));
              }
              inline float response(float light, float ev, float dev, float toe, float shoulder) {
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
              [[stitchable]] float4 filmResponse(coreimage::sample_t pixel, float ev, float dev, float amount) {
                  float3 rgb = max(pixel.rgb, float3(0.0));
                  // Small layer differences create exposure-dependent color separation.
                  float3 film = float3(
                      response(rgb.r, ev, dev, 0.72, 1.10),
                      response(rgb.g, ev, dev, 0.82, 0.92),
                      response(rgb.b, ev, dev, 0.94, 0.78)
                  );
                  return float4(mix(rgb * exp2(ev), film, amount), pixel.a);
              }

    // Kodak E-4050 chart samples: Status M negative density, stored in R/G/B order.
    constant float portraH[9] = {-3.4, -3.0, -2.5, -2.0, -1.5, -1.0, -0.5, 0.0, 0.5};
    constant float3 portraD[9] = {
        float3(0.219, 0.648, 0.863), float3(0.234, 0.659, 0.893),
        float3(0.341, 0.780, 1.098), float3(0.595, 1.054, 1.410),
        float3(0.859, 1.332, 1.727), float3(1.127, 1.610, 2.044),
        float3(1.405, 1.883, 2.361), float3(1.688, 2.156, 2.683),
        float3(1.980, 2.429, 3.015)
    };
    inline float3 portraDensityAt(float logH) {
        if (logH <= portraH[0]) return portraD[0];
        for (int i = 0; i < 8; i++) {
            if (logH <= portraH[i + 1]) {
                float t = (logH - portraH[i]) / (portraH[i + 1] - portraH[i]);
                return mix(portraD[i], portraD[i + 1], t);
            }
        }
        // The measured chart ends at +0.5; continue its last slope without inventing a shoulder.
        return portraD[8] + (portraD[8] - portraD[7]) * ((logH - 0.5) / 0.5);
    }
    [[stitchable]] float4 portraNegative(coreimage::sample_t pixel, float ev, float dev) {
        float3 light = max(pixel.rgb, float3(0.0));
        // Approximate spectral-layer overlap from E-4050's broad sensitivity bands.
        // These RGB weights are a modeling assumption, not digitized Kodak measurements.
        float3 layerLight = float3(
            dot(light, float3(0.94, 0.06, 0.00)),
            dot(light, float3(0.10, 0.82, 0.08)),
            dot(light, float3(0.00, 0.12, 0.88))
        );
        float3 logH = log10(max(layerLight, float3(0.000001)) / 0.18)
                    + float3(-1.44 + ev * 0.30103);
        float3 density = float3(
            portraDensityAt(logH.r).r,
            portraDensityAt(logH.g).g,
            portraDensityAt(logH.b).b
        );
        float3 reference = portraDensityAt(-1.44);
        // Development behavior is provisional; the published chart gives one process condition.
        density = reference + (density - reference) * (1.0 + dev * 0.10);
        return float4(density, pixel.a);
    }
    inline float3 enduraPaperReflectance(float3 negativeDensity, float3 reference);
    [[stitchable]] float4 portraPositive(coreimage::sample_t negative,
                                          coreimage::sample_t original,
                                          float ev, float amount, float paperMix) {
        float3 reference = portraDensityAt(-1.44);
        // Provisional balanced print/scan transform; 0.18 remains 0.18 at the reference.
        float3 linear = 0.18 * exp2(clamp((negative.rgb - reference) * (0.8 / 0.17),
                                          float3(-20.0), float3(20.0)));
        float3 positive = 1.08 * linear / (linear + 0.9);
        return float4(mix(max(original.rgb, float3(0.0)) * exp2(ev),
                          mix(positive, enduraPaperReflectance(negative.rgb, reference), paperMix),
                          amount), original.a);
    }

    // Kodak E-4021 page-7 green Status A paper density, sampled from the graph.
    constant float enduraH[10] = {-3.0, -2.5, -2.0, -1.75, -1.5,
                                  -1.25, -1.0, -0.75, -0.5, -0.25};
    constant float enduraD[10] = {0.10, 0.11, 0.19, 0.45, 1.05,
                                  1.82, 2.37, 2.48, 2.49, 2.52};
    inline float enduraDensityAt(float logH) {
        if (logH <= enduraH[0]) return enduraD[0];
        for (int i = 0; i < 9; i++) {
            if (logH <= enduraH[i + 1]) {
                float t = (logH - enduraH[i]) / (enduraH[i + 1] - enduraH[i]);
                return mix(enduraD[i], enduraD[i + 1], t);
            }
        }
        return enduraD[9];
    }
    inline float3 enduraPaperReflectance(float3 negativeDensity, float3 reference) {
        float3 paperExposure = float3(-1.625) - (negativeDensity - reference);
        float3 paperDensity = float3(
            enduraDensityAt(paperExposure.r),
            enduraDensityAt(paperExposure.g),
            enduraDensityAt(paperExposure.b)
        );
        // Neutral enlarger balance and a 0.75-density mid-gray aim are assumptions.
        paperDensity = clamp(paperDensity - enduraDensityAt(-1.625) + 0.75,
                             float3(0.0), float3(3.0));
        return pow(float3(10.0), -paperDensity);
    }

    [[stitchable]] float4 grade(coreimage::sample_t pixel,
                                float4 shadowColor, float shadowStrength,
                                float4 midColor, float midStrength,
                                float4 highlightColor, float highlightStrength) {
                  float luma = dot(pixel.rgb, float3(0.2126, 0.7152, 0.0722));
                  float shadowWeight = 1.0 - smoothstep(0.06, 0.42, luma);
                  float highlightWeight = smoothstep(0.38, 0.88, luma);
                  float midWeight = smoothstep(0.06, 0.38, luma)
                                  * (1.0 - smoothstep(0.48, 0.88, luma));
                  float3 shift = shadowColor.rgb * shadowStrength * shadowWeight
                             + midColor.rgb * midStrength * midWeight
                             + highlightColor.rgb * highlightStrength * highlightWeight;
                  float density = clamp(luma + 0.18, 0.18, 1.0);
                  return float4(max(pixel.rgb + shift * density * 0.18, float3(0.0)), pixel.a);
              }

    [[stitchable]] float4 selectiveColor(coreimage::sample_t pixel, float targetHue,
                                         float range, float shift, float saturation) {
                  float3 rgb = max(pixel.rgb, float3(0.0));
                  float maximum = max(max(rgb.r, rgb.g), rgb.b);
                  float minimum = min(min(rgb.r, rgb.g), rgb.b);
                  float chroma = maximum - minimum;
                  if (chroma < 0.000001) return pixel;

                  float hue;
                  if (maximum == rgb.r) hue = (rgb.g - rgb.b) / chroma;
                  else if (maximum == rgb.g) hue = (rgb.b - rgb.r) / chroma + 2.0;
                  else hue = (rgb.r - rgb.g) / chroma + 4.0;
                  hue = fract(hue / 6.0 + 1.0);
                  float distance = abs(hue - targetHue / 360.0);
                  distance = min(distance, 1.0 - distance) * 360.0;
                  float mask = 1.0 - smoothstep(range * 0.55, range, distance);
                  mask *= smoothstep(0.02, 0.16, chroma / max(maximum, 0.000001));
                  if (mask <= 0.0) return pixel;

                  float angle = shift * 0.0174532925199433 * mask;
                  float y = dot(rgb, float3(0.299, 0.587, 0.114));
                  float i = dot(rgb, float3(0.596, -0.275, -0.321));
                  float q = dot(rgb, float3(0.212, -0.523, 0.311));
                  float cosine = cos(angle);
                  float sine = sin(angle);
                  float newI = (i * cosine - q * sine) * max(0.0, 1.0 + saturation * mask);
                  float newQ = (i * sine + q * cosine) * max(0.0, 1.0 + saturation * mask);
                  float3 adjusted = float3(
                      y + 0.956 * newI + 0.621 * newQ,
                      y - 0.272 * newI - 0.647 * newQ,
                      y - 1.106 * newI + 1.703 * newQ
                  );
                  return float4(max(adjusted, float3(0.0)), pixel.a);
              }

    [[stitchable]] float4 applyGrain(coreimage::sample_t pixel, coreimage::sample_t noise, float amount) {
                  float luminance = dot(pixel.rgb, float3(0.2126, 0.7152, 0.0722));
                  float weight = sqrt(clamp(luminance, 0.02, 1.0));
                  float grain = (noise.r - 0.5) * amount * 0.14 * weight;
                  return float4(max(pixel.rgb + float3(grain), float3(0.0)), pixel.a);
              }

    [[stitchable]] float4 highlightMask(coreimage::sample_t pixel) {
                  float luminance = dot(pixel.rgb, float3(0.2126, 0.7152, 0.0722));
                  float value = smoothstep(0.65, 1.15, luminance);
                  return float4(value, value, value, 1.0);
              }

    [[stitchable]] float4 applyHalation(coreimage::sample_t pixel, coreimage::sample_t mask, coreimage::sample_t blurred, float amount) {
                  float spill = max(blurred.r - mask.r, 0.0) * amount * 0.24;
                  return float4(pixel.rgb + float3(spill, spill * 0.30, spill * 0.12), pixel.a);
              }
    """#
}
