import CoreImage
import Foundation

/// Metal Core Image kernels shared by preview and full-resolution export.
enum FilmKernels {
  private static let kernels: [String: CIColorKernel] = {
    do {
      if let libraryURL = Bundle.main.url(forResource: "FilmKernels", withExtension: "metallib") {
        let data = try Data(contentsOf: libraryURL)
        let names = CIKernel.kernelNames(fromMetalLibraryData: data)
        let required = Set([
          "filmResponse", "shapeSceneLight", "measuredNegative", "portraPositive",
          "grade", "selectiveColor", "colorMixerBand", "applyGrain",
          "highlightMask", "applyHalation", "applyAcutance", "renderedInputTone",
          "outputShoulder",
          "outputToneCurve",
        ])
        guard required.isSubset(of: Set(names)) else {
          throw KernelLoadError.incompleteLibrary
        }
        return try Dictionary(
          uniqueKeysWithValues: required.map { name in
            (name, try CIColorKernel(functionName: name, fromMetalLibraryData: data))
          })
      }
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

  private enum KernelLoadError: Error {
    case incompleteLibrary
  }

  private static let source = #"""
    #include <CoreImage/CoreImage.h>
    using namespace metal;

    inline float softplus(float x) {
                  return log(1.0 + exp(clamp(x, -30.0, 30.0)));
              }
    [[stitchable]] float4 renderedInputTone(coreimage::sample_t pixel, float slope) {
        float3 rgb = max(pixel.rgb, float3(0.0));
        float luminance = dot(rgb, float3(0.2126, 0.7152, 0.0722));
        if (luminance <= 0.000001) return float4(rgb, pixel.a);
        float relative = clamp(luminance / 0.18, 0.000001, 1000000.0);
        float target = 0.18 * pow(relative, slope);
        return float4(rgb * (target / luminance), pixel.a);
    }
    [[stitchable]] float4 outputShoulder(coreimage::sample_t pixel, float amount) {
        float peak = max(pixel.r, max(pixel.g, pixel.b));
        if (peak <= 0.75 || amount <= 0.0) return pixel;
        float rolledPeak = 1.0 - 0.25 * exp(-(peak - 0.75) / 0.25);
        float scale = mix(1.0, rolledPeak / peak, clamp(amount, 0.0, 1.0));
        return float4(pixel.rgb * scale, pixel.a);
    }
    inline float toneCurveTangent(float previous, float next,
                                  float previousWidth, float nextWidth) {
        if (previous <= 0.0 || next <= 0.0) return 0.0;
        float a = 2.0 * nextWidth + previousWidth;
        float b = nextWidth + 2.0 * previousWidth;
        return (a + b) / (a / previous + b / next);
    }
    [[stitchable]] float4 outputToneCurve(coreimage::sample_t pixel,
                                          float shadow, float midtone, float highlight) {
        float luminance = dot(pixel.rgb, float3(0.2126, 0.7152, 0.0722));
        if (luminance <= 0.000001) return pixel;
        float position[5] = {0.0, 0.2, 0.5, 0.8, 1.0};
        float value[5] = {
            0.0,
            0.2 + clamp(shadow, -0.14, 0.14),
            0.5 + clamp(midtone, -0.14, 0.14),
            0.8 + clamp(highlight, -0.14, 0.14),
            1.0
        };
        float delta[4];
        for (int i = 0; i < 4; i++) {
            delta[i] = (value[i + 1] - value[i])
                     / (position[i + 1] - position[i]);
        }
        float tangent[5] = {
            delta[0],
            toneCurveTangent(delta[0], delta[1], 0.2, 0.3),
            toneCurveTangent(delta[1], delta[2], 0.3, 0.3),
            toneCurveTangent(delta[2], delta[3], 0.3, 0.2),
            delta[3]
        };
        float target;
        if (luminance >= 1.0) {
            target = 1.0 + tangent[4] * (luminance - 1.0);
        } else {
            int segment = luminance < 0.2 ? 0 : (luminance < 0.5 ? 1
                         : (luminance < 0.8 ? 2 : 3));
            float width = position[segment + 1] - position[segment];
            float t = (luminance - position[segment]) / width;
            float t2 = t * t;
            float t3 = t2 * t;
            target = (2.0 * t3 - 3.0 * t2 + 1.0) * value[segment]
                   + (t3 - 2.0 * t2 + t) * width * tangent[segment]
                   + (-2.0 * t3 + 3.0 * t2) * value[segment + 1]
                   + (t3 - t2) * width * tangent[segment + 1];
        }
        return float4(pixel.rgb * (target / luminance), pixel.a);
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

    [[stitchable]] float4 shapeSceneLight(coreimage::sample_t pixel,
                                          float shadowEV, float highlightEV) {
        float3 light = max(pixel.rgb, float3(0.0));
        float luminance = dot(light, float3(0.2126, 0.7152, 0.0722));
        float stops = log2(max(luminance, 0.000001) / 0.18);
        float shadowWeight = 1.0 - smoothstep(-4.0, -0.5, stops);
        float highlightWeight = smoothstep(0.5, 4.0, stops);
        float shift = shadowEV * shadowWeight + highlightEV * highlightWeight;
        return float4(light * exp2(shift), pixel.a);
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
    // PCHIP tangents from Research/portra400-density.csv, in density per log H.
    constant float3 portraTangent[9] = {
        float3(0.000000, 0.000000, 0.000000),
        float3(0.062200, 0.047974, 0.123641),
        float3(0.301141, 0.335737, 0.494855),
        float3(0.517807, 0.551971, 0.628960),
        float3(0.531970, 0.556000, 0.634000),
        float3(0.545817, 0.550955, 0.634000),
        float3(0.560955, 0.546000, 0.638961),
        float3(0.574859, 0.546000, 0.653847),
        float3(0.593000, 0.546000, 0.674000)
    };
    inline float3 smoothDensity(float x, float x0, float x1,
                                float3 y0, float3 y1, float3 m0, float3 m1) {
        float width = x1 - x0;
        float t = (x - x0) / width;
        float t2 = t * t;
        float t3 = t2 * t;
        return (2.0 * t3 - 3.0 * t2 + 1.0) * y0
             + (t3 - 2.0 * t2 + t) * width * m0
             + (-2.0 * t3 + 3.0 * t2) * y1
             + (t3 - t2) * width * m1;
    }
    inline float3 portraDensityAt(float logH) {
        if (logH <= portraH[0]) return portraD[0];
        for (int i = 0; i < 8; i++) {
            if (logH <= portraH[i + 1]) {
                return smoothDensity(logH, portraH[i], portraH[i + 1],
                                     portraD[i], portraD[i + 1],
                                     portraTangent[i], portraTangent[i + 1]);
            }
        }
        // Continue the fitted endpoint tangent beyond the published chart.
        // The extension is provisional, but avoids a slope jump at +0.5.
        return portraD[8] + portraTangent[8] * (logH - 0.5);
    }

    // Kodak E-4046 chart samples: Status M Ektar 100 negative density, R/G/B order.
    constant float ektarH[9] = {-2.8, -2.5, -2.0, -1.5, -1.0, -0.5, 0.0, 0.5, 1.0};
    constant float3 ektarD[9] = {
        float3(0.212, 0.636, 0.853), float3(0.221, 0.645, 0.870),
        float3(0.299, 0.723, 1.022), float3(0.537, 0.991, 1.342),
        float3(0.831, 1.281, 1.671), float3(1.121, 1.576, 2.004),
        float3(1.398, 1.848, 2.338), float3(1.654, 2.100, 2.632),
        float3(1.866, 2.338, 2.944)
    };
    constant float3 ektarTangent[9] = {
        float3(0.000000, 0.000000, 0.000000),
        float3(0.047634, 0.047634, 0.090363),
        float3(0.234987, 0.241665, 0.412203),
        float3(0.526105, 0.557133, 0.648875),
        float3(0.583973, 0.584957, 0.661976),
        float3(0.566702, 0.566067, 0.666999),
        float3(0.532173, 0.523237, 0.625452),
        float3(0.463863, 0.489600, 0.605465),
        float3(0.380000, 0.462000, 0.642000)
    };
    inline float3 ektarDensityAt(float logH) {
        if (logH <= ektarH[0]) return ektarD[0];
        for (int i = 0; i < 8; i++) {
            if (logH <= ektarH[i + 1]) {
                return smoothDensity(logH, ektarH[i], ektarH[i + 1],
                                     ektarD[i], ektarD[i + 1],
                                     ektarTangent[i], ektarTangent[i + 1]);
            }
        }
        // Continue the fitted endpoint tangent beyond the published chart.
        // The extension is provisional, but avoids a slope jump at +1.0.
        return ektarD[8] + ektarTangent[8] * (logH - 1.0);
    }
    [[stitchable]] float4 measuredNegative(coreimage::sample_t pixel, float ev,
                                            float dev, float stock) {
        float3 light = max(pixel.rgb, float3(0.0));
        // Approximate spectral-layer overlap from E-4050's broad sensitivity bands.
        // These RGB weights are a modeling assumption, not digitized Kodak measurements.
        float3 layerLight = float3(
            dot(light, float3(0.94, 0.06, 0.00)),
            dot(light, float3(0.10, 0.82, 0.08)),
            dot(light, float3(0.00, 0.12, 0.88))
        );
        bool ektar = stock > 1.5;
        float anchor = ektar ? -0.84 : -1.44;
        float3 logH = log10(max(layerLight, float3(0.000001)) / 0.18)
                    + float3(anchor + ev * 0.30103);
        float3 density = ektar
            ? float3(ektarDensityAt(logH.r).r,
                     ektarDensityAt(logH.g).g,
                     ektarDensityAt(logH.b).b)
            : float3(portraDensityAt(logH.r).r,
                     portraDensityAt(logH.g).g,
                     portraDensityAt(logH.b).b);
        float3 reference = ektar ? ektarDensityAt(-0.84) : portraDensityAt(-1.44);
        // Development behavior is provisional; the published chart gives one process condition.
        density = reference + (density - reference) * (1.0 + dev * 0.10);
        return float4(density, pixel.a);
    }
    inline float3 enduraPaperReflectance(float3 negativeDensity, float3 reference,
                                        float paperExposure);
    inline float3 premierPaperReflectance(float3 negativeDensity, float3 reference,
                                         float paperExposure);
    [[stitchable]] float4 portraPositive(coreimage::sample_t negative,
                                          coreimage::sample_t original,
                                          float ev, float amount, float paperMix,
                                          float paperExposure, float stock) {
        float3 reference = stock > 1.5 ? ektarDensityAt(-0.84) : portraDensityAt(-1.44);
        // Provisional balanced print/scan transform; 0.18 remains 0.18 at the reference.
        float3 linear = 0.18 * exp2(clamp((negative.rgb - reference) * (0.8 / 0.17),
                                          float3(-20.0), float3(20.0)));
        float3 positive = 1.08 * linear / (linear + 0.9);
        return float4(mix(max(original.rgb, float3(0.0)) * exp2(ev),
                          mix(positive,
                              stock > 1.5
                                  ? premierPaperReflectance(negative.rgb, reference, paperExposure)
                                  : enduraPaperReflectance(negative.rgb, reference, paperExposure),
                              paperMix),
                          amount), original.a);
    }

    // Kodak E-4021 page-7 Status A paper density, approximately sampled in RGB order.
    constant float enduraH[10] = {-3.0, -2.5, -2.0, -1.75, -1.5,
                                  -1.25, -1.0, -0.75, -0.5, -0.25};
    constant float3 enduraD[10] = {
        float3(0.10, 0.10, 0.10), float3(0.11, 0.11, 0.11),
        float3(0.19, 0.19, 0.19), float3(0.45, 0.45, 0.45),
        float3(1.05, 1.05, 1.05), float3(1.85, 1.82, 1.80),
        float3(2.44, 2.37, 2.34), float3(2.57, 2.51, 2.41),
        float3(2.62, 2.61, 2.43), float3(2.66, 2.63, 2.44)
    };
    // PCHIP tangents from Research/endura-paper-tone.csv.
    constant float3 enduraTangent[10] = {
        float3(0.000000, 0.000000, 0.000000),
        float3(0.035556, 0.035556, 0.035556),
        float3(0.301935, 0.301935, 0.301935),
        float3(1.451163, 1.451163, 1.451163),
        float3(2.742857, 2.697810, 2.666667),
        float3(2.716547, 2.566667, 2.511628),
        float3(0.852222, 0.892754, 0.495738),
        float3(0.288889, 0.466667, 0.124444),
        float3(0.177778, 0.133333, 0.053333),
        float3(0.140000, 0.000000, 0.020000)
    };
    inline float3 enduraDensityAt(float logH) {
        if (logH <= enduraH[0]) return enduraD[0];
        for (int i = 0; i < 9; i++) {
            if (logH <= enduraH[i + 1]) {
                return smoothDensity(logH, enduraH[i], enduraH[i + 1],
                                     enduraD[i], enduraD[i + 1],
                                     enduraTangent[i], enduraTangent[i + 1]);
            }
        }
        return enduraD[9];
    }
    inline float3 enduraPaperReflectance(float3 negativeDensity, float3 reference,
                                        float paperExposureStops) {
        float3 paperExposure = float3(-1.625 + paperExposureStops * 0.30103)
                             - (negativeDensity - reference);
        float3 paperDensity = float3(
            enduraDensityAt(paperExposure.r).r,
            enduraDensityAt(paperExposure.g).g,
            enduraDensityAt(paperExposure.b).b
        );
        // Neutral enlarger balance and a 0.75-density mid-gray aim are assumptions.
        paperDensity = clamp(paperDensity - enduraDensityAt(-1.625) + 0.75,
                             float3(0.0), float3(3.0));
        return pow(float3(10.0), -paperDensity);
    }

    // Kodak E-4070 page-4 Status A ENDURA Premier paper density, approximate RGB readings.
    constant float premierH[12] = {-3.0, -2.5, -2.0, -1.75, -1.5, -1.25,
                                   -1.0, -0.9, -0.8, -0.7, -0.5, -0.25};
    constant float3 premierD[12] = {
        float3(0.08, 0.07, 0.06), float3(0.10, 0.08, 0.06),
        float3(0.12, 0.10, 0.08), float3(0.18, 0.16, 0.13),
        float3(0.50, 0.48, 0.44), float3(1.38, 1.32, 1.25),
        float3(2.32, 2.22, 2.20), float3(2.53, 2.36, 2.33),
        float3(2.65, 2.44, 2.39), float3(2.70, 2.48, 2.42),
        float3(2.75, 2.51, 2.44), float3(2.76, 2.53, 2.45)
    };
    // Monotone PCHIP tangents from Research/endura-premier-paper-tone.csv.
    constant float3 premierTangent[12] = {
        float3(0.040000, 0.010000, 0.000000),
        float3(0.040000, 0.026667, 0.000000),
        float3(0.074483, 0.074483, 0.072000),
        float3(0.404211, 0.404211, 0.344444),
        float3(1.877333, 1.853793, 1.793571),
        float3(3.636044, 3.475862, 3.497727),
        float3(2.590066, 1.896774, 1.810471),
        float3(1.527273, 1.018182, 0.821053),
        float3(0.705882, 0.533333, 0.400000),
        float3(0.346154, 0.229787, 0.158824),
        float3(0.070866, 0.105537, 0.058065),
        float3(0.000000, 0.041111, 0.006667)
    };
    inline float3 premierDensityAt(float logH) {
        if (logH <= premierH[0]) return premierD[0];
        for (int i = 0; i < 11; i++) {
            if (logH <= premierH[i + 1]) {
                return smoothDensity(logH, premierH[i], premierH[i + 1],
                                     premierD[i], premierD[i + 1],
                                     premierTangent[i], premierTangent[i + 1]);
            }
        }
        return premierD[11];
    }
    inline float3 premierPaperReflectance(float3 negativeDensity, float3 reference,
                                         float paperExposureStops) {
        float3 paperExposure = float3(-1.4 + paperExposureStops * 0.30103)
                             - (negativeDensity - reference);
        float3 paperDensity = float3(
            premierDensityAt(paperExposure.r).r,
            premierDensityAt(paperExposure.g).g,
            premierDensityAt(paperExposure.b).b
        );
        // Enlarger balance and mid-gray aim remain assumptions, not Kodak measurements.
        paperDensity = clamp(paperDensity - premierDensityAt(-1.4) + 0.75,
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

    [[stitchable]] float4 colorMixerBand(coreimage::sample_t pixel,
                                         coreimage::sample_t original,
                                         float center, float hueShift,
                                         float saturation, float luminanceEV) {
        float3 source = max(original.rgb, float3(0.0));
        float maximum = max(max(source.r, source.g), source.b);
        float minimum = min(min(source.r, source.g), source.b);
        float chroma = maximum - minimum;
        if (chroma < 0.000001) return pixel;
        float hue;
        if (maximum == source.r) hue = (source.g - source.b) / chroma;
        else if (maximum == source.g) hue = (source.b - source.r) / chroma + 2.0;
        else hue = (source.r - source.g) / chroma + 4.0;
        hue = fract(hue / 6.0 + 1.0) * 360.0;
        float distance = abs(hue - center);
        distance = min(distance, 360.0 - distance);
        float mask = (1.0 - smoothstep(15.0, 48.0, distance))
                   * smoothstep(0.02, 0.12, chroma / max(maximum, 0.000001));
        if (mask <= 0.0) return pixel;
        float3 rgb = max(pixel.rgb, float3(0.0));
        float angle = hueShift * mask * 0.0174532925199433;
        float y = dot(rgb, float3(0.299, 0.587, 0.114));
        float i = dot(rgb, float3(0.596, -0.275, -0.321));
        float q = dot(rgb, float3(0.212, -0.523, 0.311));
        float cosine = cos(angle);
        float sine = sin(angle);
        float scale = max(0.0, 1.0 + saturation * mask);
        float newI = (i * cosine - q * sine) * scale;
        float newQ = (i * sine + q * cosine) * scale;
        float3 mixed = float3(
            y + 0.956 * newI + 0.621 * newQ,
            y - 0.272 * newI - 0.647 * newQ,
            y - 1.106 * newI + 1.703 * newQ
        );
        return float4(max(mixed, float3(0.0))
                      * exp2(clamp(luminanceEV * mask, -2.0, 2.0)), pixel.a);
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

    inline float grainHash(int2 location, uint seed) {
                  uint hash = uint(location.x) * 0x8da6b343u
                            ^ uint(location.y) * 0xd8163841u ^ seed;
                  hash ^= hash >> 16;
                  hash *= 0x7feb352du;
                  hash ^= hash >> 15;
                  hash *= 0x846ca68bu;
                  hash ^= hash >> 16;
                  return float(hash & 0x00ffffffu) / 16777216.0 - 0.5;
              }
    [[stitchable]] float4 applyGrain(coreimage::sample_t pixel,
                                    float amount, float size,
                                    coreimage::destination destination) {
                  float2 coord = destination.coord();
                  float fine = grainHash(int2(floor(coord)), 0xcb1ab31fu);
                  float noise = fine;
                  if (size > 0.001) {
                      float2 lattice = coord / (2.5 * size);
                      int2 cell = int2(floor(lattice));
                      float2 fraction = fract(lattice);
                      float2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
                      float4 weights = float4(
                          (1.0 - blend.x) * (1.0 - blend.y),
                          blend.x * (1.0 - blend.y),
                          (1.0 - blend.x) * blend.y,
                          blend.x * blend.y);
                      float4 samples = float4(
                          grainHash(cell, 0x61c88647u),
                          grainHash(cell + int2(1, 0), 0x61c88647u),
                          grainHash(cell + int2(0, 1), 0x61c88647u),
                          grainHash(cell + int2(1, 1), 0x61c88647u));
                      float coarse = dot(weights, samples)
                          / sqrt(max(dot(weights, weights), 0.000001));
                      noise = (coarse * 0.9 + fine * 0.1) / sqrt(0.82);
                  }
                  float luminance = dot(pixel.rgb, float3(0.2126, 0.7152, 0.0722));
                  float weight = sqrt(clamp(luminance, 0.02, 1.0));
                  float grain = noise * amount * 0.14 * weight;
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

    [[stitchable]] float4 applyAcutance(coreimage::sample_t pixel,
                                       coreimage::sample_t blurred, float amount) {
        float3 source = max(pixel.rgb, float3(0.0));
        float3 lowPass = max(blurred.rgb, float3(0.0));
        float luma = dot(source, float3(0.2126, 0.7152, 0.0722));
        float lowLuma = dot(lowPass, float3(0.2126, 0.7152, 0.0722));
        float delta = clamp((luma - lowLuma) * amount * 0.65, -0.12, 0.12);
        float scale = max(luma + delta, 0.0) / max(luma, 0.000001);
        return float4(source * scale, pixel.a);
    }
    """#
}
