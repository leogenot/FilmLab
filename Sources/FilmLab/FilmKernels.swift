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
          "filmResponse", "shapeSceneLight", "positiveFilmLight",
          "measuredNegative", "measuredNegativeSpectral", "portraPositive",
          "opticalPremierPositive", "multigradePositive",
          "grade", "selectiveColor", "colorMixerBand", "colorMixerBandV2", "applyGrain",
          "applyNegativeGrain",
          "preservingSelectiveColor",
          "highlightMask", "sceneHighlightMask", "applyHalation", "applyNeutralHalation",
          "applyAcutance",
          "renderedInputTone",
          "outputShoulder",
          "outputToneCurve", "channelToneCurves",
          "vibrance",
          "outputGamutWarning",
          "compressSRGBGamut",
          "localLuminanceMask",
          "localHueMask",
          "localSaturation",
        ])
        guard required.isSubset(of: Set(names)) else {
          throw KernelLoadError.incompleteLibrary
        }
        return try Dictionary(
          uniqueKeysWithValues: required.map { name in
            (name, try CIColorKernel(functionName: name, fromMetalLibraryData: data))
          })
      }
      let compiled =
        try CIKernel.kernels(withMetalString: source)
        + CIKernel.kernels(
          withMetalString: "#include <CoreImage/CoreImage.h>\nusing namespace metal;\n"
            + preservingMixerSource)
        + CIKernel.kernels(
          withMetalString: "#include <CoreImage/CoreImage.h>\nusing namespace metal;\n"
            + preservingSelectiveSource)
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
        float3 rgb = pixel.rgb;
        float luminance = dot(rgb, float3(0.2126, 0.7152, 0.0722));
        if (!all(isfinite(rgb)) || luminance <= 0.0) return pixel;
        // Continue linearly to black below the smallest modeled luminance.
        // Leaving that interval untouched creates a visible jump at the cutoff.
        if (luminance <= 0.000001) {
            float atFloor = 0.18 * pow(0.000001 / 0.18, slope);
            return float4(rgb * (atFloor / 0.000001), pixel.a);
        }
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
    [[stitchable]] float4 outputGamutWarning(coreimage::sample_t pixel) {
        float3 rgb = pixel.rgb;
        if (!all(isfinite(rgb))) return float4(1.0, 0.0, 1.0, pixel.a);
        if (any(rgb < float3(-0.0001))) {
            return float4(mix(clamp(rgb, 0.0, 1.0), float3(0.05, 0.25, 1.0), 0.8), pixel.a);
        }
        if (any(rgb > float3(1.0001))) {
            return float4(mix(clamp(rgb, 0.0, 1.0), float3(1.0, 0.12, 0.05), 0.8), pixel.a);
        }
        return pixel;
    }
    [[stitchable]] float4 compressSRGBGamut(coreimage::sample_t pixel) {
        float3 rgb = pixel.rgb;
        if (!all(isfinite(rgb))) return pixel;
        float luminance = dot(rgb, float3(0.2126, 0.7152, 0.0722));
        // Chroma compression can preserve luminance only while the neutral lies in sRGB.
        if (luminance <= 0.0 || luminance >= 1.0) return pixel;
        float3 chroma = rgb - luminance;
        float boundary = 1.0e20;
        for (int channel = 0; channel < 3; channel++) {
            if (chroma[channel] < 0.0) {
                boundary = min(boundary, luminance / -chroma[channel]);
            } else if (chroma[channel] > 0.0) {
                boundary = min(boundary, (1.0 - luminance) / chroma[channel]);
            }
        }
        float position = 1.0 / boundary;
        const float knee = 0.85;
        if (position <= knee) return pixel;
        // A matched-slope soft knee keeps distinct out-of-gamut chroma values ordered.
        float compressed = knee + (1.0 - knee)
            * (1.0 - exp(-(position - knee) / (1.0 - knee)));
        return float4(luminance + chroma * (compressed / position), pixel.a);
    }
    [[stitchable]] float4 vibrance(coreimage::sample_t pixel, float amount) {
        float3 rgb = pixel.rgb;
        float peak = max(rgb.r, max(rgb.g, rgb.b));
        float floor = min(rgb.r, min(rgb.g, rgb.b));
        if (floor < 0.0 || peak <= 0.000001 || peak - floor <= 0.000001) return pixel;
        float saturation = (peak - floor) / peak;
        float selectivity = 1.0 - smoothstep(0.0, 1.0, saturation);
        float luminance = dot(rgb, float3(0.2126, 0.7152, 0.0722));
        float scale = max(0.0, 1.0 + clamp(amount, -1.0, 1.0) * selectivity);
        if (scale > 1.0) {
            scale = min(scale, luminance / max(luminance - floor, 0.000001));
        }
        return float4(luminance + (rgb - luminance) * scale, pixel.a);
    }
    [[stitchable]] float4 localSaturation(coreimage::sample_t pixel, float amount) {
        float3 rgb = pixel.rgb;
        if (!all(isfinite(rgb)) || any(rgb < float3(0.0))) return pixel;
        float luminance = dot(rgb, float3(0.2126, 0.7152, 0.0722));
        float3 chroma = rgb - luminance;
        float scale = max(0.0, 1.0 + clamp(amount, -1.0, 1.0));
        if (scale > 1.0) {
            if (chroma.r < 0.0) scale = min(scale, luminance / -chroma.r);
            if (chroma.g < 0.0) scale = min(scale, luminance / -chroma.g);
            if (chroma.b < 0.0) scale = min(scale, luminance / -chroma.b);
        }
        return float4(max(luminance + chroma * scale, float3(0.0)), pixel.a);
    }
    [[stitchable]] float4 localLuminanceMask(coreimage::sample_t pixel,
                                            float center, float width, float feather) {
        float luminance = max(dot(pixel.rgb, float3(0.2126, 0.7152, 0.0722)), 0.000001);
        float stops = log2(luminance / 0.18);
        float distance = abs(stops - clamp(center, -6.0, 6.0));
        float halfWidth = clamp(width, 0.5, 8.0) * 0.5;
        float softness = clamp(feather, 0.1, 2.0) * 0.5;
        float selected = 1.0 - smoothstep(max(0.0, halfWidth - softness),
                                          halfWidth + softness, distance);
        return float4(selected, selected, selected, 1.0);
    }
    [[stitchable]] float4 localHueMask(coreimage::sample_t pixel,
                                      float center, float width, float feather) {
        float3 rgb = max(pixel.rgb, float3(0.0));
        float maximum = max(max(rgb.r, rgb.g), rgb.b);
        float minimum = min(min(rgb.r, rgb.g), rgb.b);
        float chroma = maximum - minimum;
        if (maximum < 0.002 || chroma < 0.000001) return float4(0.0, 0.0, 0.0, 1.0);
        float hue;
        if (maximum == rgb.r) hue = (rgb.g - rgb.b) / chroma;
        else if (maximum == rgb.g) hue = (rgb.b - rgb.r) / chroma + 2.0;
        else hue = (rgb.r - rgb.g) / chroma + 4.0;
        hue = fract(hue / 6.0 + 1.0) * 360.0;
        float selectedCenter = fract(center / 360.0 + 1.0) * 360.0;
        float distance = abs(hue - selectedCenter);
        distance = min(distance, 360.0 - distance);
        float outer = clamp(width, 5.0, 90.0);
        float inner = max(0.0, outer - clamp(feather, 5.0, 45.0));
        float hueWeight = 1.0 - smoothstep(inner, outer, distance);
        float saturationWeight = smoothstep(0.02, 0.12, chroma / maximum);
        float selected = hueWeight * saturationWeight;
        return float4(selected, selected, selected, 1.0);
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
        if (luminance <= 0.0) return pixel;
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
        // Follow the first segment's slope to black. The previous identity
        // cutoff caused a jump where near-black rendered pixels entered the curve.
        if (luminance <= 0.000001) {
            return float4(pixel.rgb * delta[0], pixel.a);
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
    inline float channelCurveAt(float input, float shadow, float midtone, float highlight) {
        if (input <= 0.0) return input;
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
        if (input >= 1.0) return 1.0 + tangent[4] * (input - 1.0);
        int segment = input < 0.2 ? 0 : (input < 0.5 ? 1 : (input < 0.8 ? 2 : 3));
        float width = position[segment + 1] - position[segment];
        float t = (input - position[segment]) / width;
        float t2 = t * t;
        float t3 = t2 * t;
        return (2.0 * t3 - 3.0 * t2 + 1.0) * value[segment]
             + (t3 - 2.0 * t2 + t) * width * tangent[segment]
             + (-2.0 * t3 + 3.0 * t2) * value[segment + 1]
             + (t3 - t2) * width * tangent[segment + 1];
    }
    [[stitchable]] float4 channelToneCurves(coreimage::sample_t pixel,
                                            float4 shadow, float4 midtone,
                                            float4 highlight) {
        return float4(
            channelCurveAt(pixel.r, shadow.r, midtone.r, highlight.r),
            channelCurveAt(pixel.g, shadow.g, midtone.g, highlight.g),
            channelCurveAt(pixel.b, shadow.b, midtone.b, highlight.b),
            pixel.a
        );
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

    [[stitchable]] float4 positiveFilmLight(coreimage::sample_t pixel) {
        float3 rgb = pixel.rgb;
        if (!all(isfinite(rgb))) return float4(0.0, 0.0, 0.0, pixel.a);
        if (all(rgb >= float3(0.0))) return pixel;
        float luminance = dot(rgb, float3(0.2126, 0.7152, 0.0722));
        if (luminance <= 0.0) return float4(0.0, 0.0, 0.0, pixel.a);
        float3 chroma = rgb - luminance;
        float scale = 1.0;
        if (chroma.r < 0.0) scale = min(scale, luminance / -chroma.r);
        if (chroma.g < 0.0) scale = min(scale, luminance / -chroma.g);
        if (chroma.b < 0.0) scale = min(scale, luminance / -chroma.b);
        return float4(max(luminance + chroma * scale, float3(0.0)), pixel.a);
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
    inline float3 paperDensityShoulder(float x, float endpoint,
                                       float3 density, float3 tangent) {
        // A provisional, bounded continuation with the fitted endpoint slope.
        // It avoids the kink from clamping a still-rising paper curve.
        float distance = max(x - endpoint, 0.0);
        return density + tangent * (0.5 * (1.0 - exp(-distance / 0.5)));
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
    // Kodak E-7022 June 2023 page 4: daylight Status M negative density.
    // Approximate plot readings in Research/gold200-density.csv (R/G/B order).
    constant float goldH[9] = {-2.8, -2.5, -2.0, -1.5, -1.0, -0.5, 0.0, 0.5, 0.85};
    constant float3 goldD[9] = {
        float3(0.260000, 0.670000, 0.980000),
        float3(0.290000, 0.720000, 1.010000),
        float3(0.460000, 0.910000, 1.190000),
        float3(0.730000, 1.180000, 1.490000),
        float3(0.990000, 1.460000, 1.810000),
        float3(1.270000, 1.750000, 2.110000),
        float3(1.550000, 2.020000, 2.420000),
        float3(1.720000, 2.200000, 2.620000),
        float3(1.830000, 2.300000, 2.730000)
    };
    // Monotone PCHIP tangents, density per log H.
    constant float3 goldTangent[9] = {
        float3(0.000000, 0.000000, 0.000000),
        float3(0.147826, 0.224409, 0.149481),
        float3(0.417273, 0.446087, 0.450000),
        float3(0.529811, 0.549818, 0.619355),
        float3(0.539259, 0.569825, 0.619355),
        float3(0.560000, 0.559286, 0.609836),
        float3(0.423111, 0.432000, 0.486275),
        float3(0.325884, 0.316443, 0.349533),
        float3(0.303697, 0.255126, 0.278992)
    };
    inline float3 goldDensityAt(float logH) {
        if (logH <= goldH[0]) return goldD[0];
        for (int i = 0; i < 8; i++) {
            if (logH <= goldH[i + 1]) {
                return smoothDensity(logH, goldH[i], goldH[i + 1],
                                     goldD[i], goldD[i + 1],
                                     goldTangent[i], goldTangent[i + 1]);
            }
        }
        // Provisional continuation beyond the published graph.
        return goldD[8] + goldTangent[8] * (logH - 0.85);
    }
    // Kodak F-4017 page 8: 400TX 35 mm, D-76 large tank, 20 C, 8 minutes.
    // Approximate diffuse-visual density readings in Research/trix400-density.csv.
    constant float trixH[9] = {-3.40, -3.00, -2.50, -2.00, -1.50, -1.00, -0.50, 0.00, 0.30};
    constant float trixD[9] = {0.290000, 0.290000, 0.450000, 0.720000, 1.030000, 1.330000, 1.650000, 1.930000, 2.090000};
    constant float trixTangent[9] = {0.000000, 0.000000, 0.401860, 0.577241, 0.609836, 0.619355, 0.597333, 0.545233, 0.523333};
    inline float trixDensityAt(float logH) {
        if (logH <= trixH[0]) return trixD[0];
        for (int i = 0; i < 8; i++) {
            if (logH <= trixH[i + 1]) {
                return smoothDensity(logH, trixH[i], trixH[i + 1],
                                     float3(trixD[i]), float3(trixD[i + 1]),
                                     float3(trixTangent[i]), float3(trixTangent[i + 1])).r;
            }
        }
        // Provisional continuation beyond the published graph.
        return trixD[8] + trixTangent[8] * (logH - 0.3);
    }
    // Kodak F-4016 page 8: 100TMX, D-76 small tank, 20 C, 7.5 minutes.
    // Approximate diffuse-visual density readings in Research/tmax100-density.csv.
    constant float tmaxH[10] = {-3.10, -3.00, -2.50, -2.00, -1.50, -1.00, -0.50, 0.00, 0.50, 0.65};
    constant float tmaxD[10] = {0.210000, 0.220000, 0.240000, 0.380000, 0.740000, 1.100000, 1.440000, 1.770000, 2.090000, 2.160000};
    constant float tmaxTangent[10] = {0.000000, 0.063158, 0.070000, 0.403200, 0.720000, 0.699429, 0.669851, 0.649846, 0.525000, 0.426667};
    inline float tmaxDensityAt(float logH) {
        if (logH <= tmaxH[0]) return tmaxD[0];
        for (int i = 0; i < 9; i++) {
            if (logH <= tmaxH[i + 1]) {
                return smoothDensity(logH, tmaxH[i], tmaxH[i + 1],
                                     float3(tmaxD[i]), float3(tmaxD[i + 1]),
                                     float3(tmaxTangent[i]), float3(tmaxTangent[i + 1])).r;
            }
        }
        // Provisional continuation beyond the published graph.
        return tmaxD[9] + tmaxTangent[9] * (logH - 0.65);
    }
    // BEGIN GENERATED STOCK LAYER SENSITIVITY
    inline float3 stockLayerLight(float3 light, float stock) {
        // Rows: cyan/red, magenta/green, yellow/blue layer light.
        if (stock < 1.5) {
            return float3(
                dot(light, float3(0.919517352, 0.075410661, 0.005071986)),
                dot(light, float3(0.027232368, 0.843760653, 0.129006980)),
                dot(light, float3(0.016804068, 0.074529504, 0.908666428))
            );
        } else if (stock < 2.5) {
            return float3(
                dot(light, float3(0.933257956, 0.062481212, 0.004260831)),
                dot(light, float3(0.032743275, 0.840952749, 0.126303977)),
                dot(light, float3(0.016792423, 0.070198490, 0.913009087))
            );
        } else {
            return float3(
                dot(light, float3(0.897729510, 0.089055251, 0.013215240)),
                dot(light, float3(0.015097722, 0.858965137, 0.125937142)),
                dot(light, float3(0.015504927, 0.077762838, 0.906732235))
            );
        }
    }
    // END GENERATED STOCK LAYER SENSITIVITY
    [[stitchable]] float4 measuredNegative(coreimage::sample_t pixel, float ev,
                                            float dev, float stock) {
        float3 light = max(pixel.rgb, float3(0.0));
        if (stock > 3.5) {
            // Camera RGB is not scene spectral radiance. This panchromatic
            // weighting and the -1.5 midgray anchor are modeling assumptions.
            float exposure = dot(light, float3(0.2126, 0.7152, 0.0722));
            float logH = log10(max(exposure, 0.000001) / 0.18)
                       - 1.5 + ev * 0.30103;
            float density = stock > 4.5 ? tmaxDensityAt(logH) : trixDensityAt(logH);
            return float4(float3(density), pixel.a);
        }
        // Approximate spectral-layer overlap from E-4050's broad sensitivity bands.
        // These RGB weights are a modeling assumption, not digitized Kodak measurements.
        float3 layerLight = float3(
            dot(light, float3(0.94, 0.06, 0.00)),
            dot(light, float3(0.10, 0.82, 0.08)),
            dot(light, float3(0.00, 0.12, 0.88))
        );
        bool ektar = stock > 1.5 && stock < 2.5;
        bool gold = stock > 2.5;
        float anchor = gold ? -1.14 : (ektar ? -0.84 : -1.44);
        float3 logH = log10(max(layerLight, float3(0.000001)) / 0.18)
                    + float3(anchor + ev * 0.30103);
        float3 density = gold
            ? float3(goldDensityAt(logH.r).r,
                     goldDensityAt(logH.g).g,
                     goldDensityAt(logH.b).b)
            : (ektar
                ? float3(ektarDensityAt(logH.r).r,
                         ektarDensityAt(logH.g).g,
                         ektarDensityAt(logH.b).b)
                : float3(portraDensityAt(logH.r).r,
                         portraDensityAt(logH.g).g,
                         portraDensityAt(logH.b).b));
        float3 reference = gold ? goldDensityAt(-1.14)
            : (ektar ? ektarDensityAt(-0.84) : portraDensityAt(-1.44));
        // Development behavior is provisional; the published chart gives one process condition.
        density = reference + (density - reference) * (1.0 + dev * 0.10);
        return float4(density, pixel.a);
    }
    [[stitchable]] float4 measuredNegativeSpectral(coreimage::sample_t pixel, float ev,
                                                   float dev, float stock) {
        float3 layerLight = stockLayerLight(max(pixel.rgb, float3(0.0)), stock);
        bool ektar = stock > 1.5 && stock < 2.5;
        bool gold = stock > 2.5;
        float anchor = gold ? -1.14 : (ektar ? -0.84 : -1.44);
        float3 logH = log10(max(layerLight, float3(0.000001)) / 0.18)
                    + float3(anchor + ev * 0.30103);
        float3 density = gold
            ? float3(goldDensityAt(logH.r).r,
                     goldDensityAt(logH.g).g,
                     goldDensityAt(logH.b).b)
            : (ektar
                ? float3(ektarDensityAt(logH.r).r,
                         ektarDensityAt(logH.g).g,
                         ektarDensityAt(logH.b).b)
                : float3(portraDensityAt(logH.r).r,
                         portraDensityAt(logH.g).g,
                         portraDensityAt(logH.b).b));
        float3 reference = gold ? goldDensityAt(-1.14)
            : (ektar ? ektarDensityAt(-0.84) : portraDensityAt(-1.44));
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
        if (stock > 3.5) {
            float density = dot(negative.rgb, float3(0.333333));
            float reference = stock > 4.5 ? tmaxDensityAt(-1.5) : trixDensityAt(-1.5);
            // Virtual monochrome scan/print transform, not a measured paper.
            float linear = 0.18 * exp2(clamp((density - reference) * (0.8 / 0.17),
                                              -20.0, 20.0));
            float positive = 1.08 * linear / (linear + 0.9);
            return float4(mix(max(original.rgb, float3(0.0)) * exp2(ev),
                              float3(positive), amount), original.a);
        }
        float3 reference = stock > 2.5 ? goldDensityAt(-1.14)
            : (stock > 1.5 ? ektarDensityAt(-0.84) : portraDensityAt(-1.44));
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
        return paperDensityShoulder(logH, enduraH[9], enduraD[9], enduraTangent[9]);
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
        return paperDensityShoulder(logH, premierH[11], premierD[11], premierTangent[11]);
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

    // E-4070 page 5, visually sampled at 25 nm from 400 to 700 nm. These
    // broad dye curves are approximate; Status A density is not a full spectrum.
    constant float premierCyan[13] = {
        0.00, 0.00, 0.00, 0.00, 0.01, 0.02, 0.04, 0.09, 0.20, 0.48, 0.82, 1.00, 0.92
    };
    constant float premierMagenta[13] = {
        0.01, 0.02, 0.04, 0.12, 0.35, 0.73, 1.00, 0.84, 0.44, 0.14, 0.03, 0.00, 0.00
    };
    constant float premierYellow[13] = {
        0.72, 1.00, 0.87, 0.50, 0.16, 0.04, 0.01, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00
    };
    // CIE 1931 2-degree observer and CIE D50, 400–700 nm / 25 nm.
    // Trapezoidal integration, normalized so a perfect reflector has Y = 1.
    // Source samples and derivation: Research/cie-d50-print-integration.csv.
    constant float3 cieD50XYZ[13] = {
        float3(0.000836683, 0.000023153, 0.003967082),
        float3(0.030013085, 0.001020140, 0.145202304),
        float3(0.069563626, 0.007862635, 0.366669833),
        float3(0.031421103, 0.024898073, 0.230384571),
        float3(0.001112368, 0.073325495, 0.061747786),
        float3(0.025891901, 0.187385547, 0.013524741),
        float3(0.105176741, 0.241424925, 0.002123190),
        float3(0.196459709, 0.213459012, 0.000419736),
        float3(0.246081878, 0.146184961, 0.000185338),
        float3(0.173532612, 0.074133575, 0.000023095),
        float3(0.064320459, 0.024276152, 0.000000000),
        float3(0.015244170, 0.005560767, 0.000000000),
        float3(0.001233847, 0.000445565, 0.000000000),
    };
    inline float3 premierSpectralReflectance(float3 dyeDensity) {
        float3 xyz = float3(0.0);
        for (int i = 0; i < 13; i++) {
            float density = dyeDensity.r * premierCyan[i]
                          + dyeDensity.g * premierMagenta[i]
                          + dyeDensity.b * premierYellow[i];
            xyz += cieD50XYZ[i] * pow(10.0, -clamp(density, 0.0, 6.0));
        }
        // Bradford D50 -> D65 adaptation, then IEC 61966-2-1 XYZ -> linear sRGB.
        float3 d65 = float3(
            dot(xyz, float3(0.9555766, -0.0230393, 0.0631636)),
            dot(xyz, float3(-0.0282895, 1.0099416, 0.0210077)),
            dot(xyz, float3(0.0122982, -0.0204830, 1.3299098)));
        // Keep signed wide-gamut values in the working space. Display/JPEG
        // conversion can map them later; clipping here discards print color
        // that may still fit in Display P3 or a floating-point TIFF.
        return float3(
            dot(d65, float3(3.2404542, -1.5371385, -0.4985314)),
            dot(d65, float3(-0.9692660, 1.8760108, 0.0415560)),
            dot(d65, float3(0.0556434, -0.2040259, 1.0572252)));
    }
    // BEGIN GENERATED OPTICAL PRINTER (Research/generate-optical-printer.py)
    constant float3 portraDensityGain[13] = {
        float3(0.002006498, 0.108735460, 0.621531049),
        float3(0.007132158, 0.244653819, 0.853282719),
        float3(0.019555016, 0.416042504, 0.862927617),
        float3(0.040887059, 0.528644639, 0.635539595),
        float3(0.078815887, 0.606792384, 0.412104554),
        float3(0.155283425, 0.697508975, 0.260826674),
        float3(0.322266926, 0.827539515, 0.166062761),
        float3(0.391311665, 0.562851803, 0.059075211),
        float3(0.360402872, 0.284516680, 0.015222748),
        float3(0.618252744, 0.262472448, 0.006977335),
        float3(0.994025526, 0.222363420, 0.002862438),
        float3(1.337042051, 0.154421929, 0.000938199),
        float3(1.484650512, 0.086743351, 0.000242428),
    };
    constant float3 portraPaperWeight[13] = {
        float3(0.000001515, 0.000000823, 0.031491768),
        float3(0.000001785, 0.001723845, 0.054876366),
        float3(0.000001793, 0.003876406, 0.117846414),
        float3(0.000003406, 0.016480250, 0.794055513),
        float3(0.000006474, 0.088293971, 0.001509448),
        float3(0.000007476, 0.114393140, 0.000004378),
        float3(0.000010048, 0.770651741, 0.000005885),
        float3(0.008101762, 0.004398837, 0.000015005),
        float3(0.076694185, 0.000052423, 0.000056547),
        float3(0.195902080, 0.000053309, 0.000057502),
        float3(0.214578213, 0.000036842, 0.000039740),
        float3(0.305056905, 0.000026251, 0.000028316),
        float3(0.199634356, 0.000012162, 0.000013118),
    };
    constant float3 ektarDensityGain[13] = {
        float3(0.002158109, 0.120259929, 0.691914798),
        float3(0.007716418, 0.272183475, 0.955526523),
        float3(0.020977091, 0.458922924, 0.958112397),
        float3(0.043669144, 0.580587388, 0.702564854),
        float3(0.075184183, 0.595206664, 0.406888223),
        float3(0.156884572, 0.724635966, 0.272748349),
        float3(0.316545698, 0.835842346, 0.168829341),
        float3(0.358740368, 0.530599049, 0.056055435),
        float3(0.376784041, 0.305862997, 0.016472227),
        float3(0.563871495, 0.246157323, 0.006586560),
        float3(0.892151167, 0.205219775, 0.002659084),
        float3(1.235807421, 0.146767419, 0.000897544),
        float3(1.413168852, 0.084902596, 0.000238840),
    };
    constant float3 ektarPaperWeight[13] = {
        float3(0.000001134, 0.000000627, 0.034708815),
        float3(0.000001191, 0.001170473, 0.053904881),
        float3(0.000001142, 0.002513579, 0.110550095),
        float3(0.000002324, 0.011450569, 0.798166715),
        float3(0.000006842, 0.095015470, 0.002349962),
        float3(0.000008273, 0.128903067, 0.000007137),
        float3(0.000009686, 0.756347602, 0.000008356),
        float3(0.007991340, 0.004417750, 0.000021801),
        float3(0.065887422, 0.000045855, 0.000071557),
        float3(0.202338779, 0.000056061, 0.000087484),
        float3(0.232073579, 0.000040570, 0.000063310),
        float3(0.307907974, 0.000026978, 0.000042099),
        float3(0.183770315, 0.000011399, 0.000017788),
    };
    constant float3 goldDensityGain[13] = {
        float3(0.001605402, 0.085761581, 0.590847612),
        float3(0.006150955, 0.207993581, 0.874343241),
        float3(0.014698631, 0.308271050, 0.770655856),
        float3(0.029909769, 0.381212688, 0.552379055),
        float3(0.067577642, 0.512868135, 0.419820928),
        float3(0.155244022, 0.687410112, 0.309819818),
        float3(0.299101765, 0.757126262, 0.183123001),
        float3(0.345093839, 0.489310804, 0.061899494),
        float3(0.328979994, 0.256014939, 0.016509796),
        float3(0.581272080, 0.243261547, 0.007794179),
        float3(0.883094459, 0.194737370, 0.003021434),
        float3(1.165943116, 0.132744825, 0.000972064),
        float3(1.233593400, 0.071049386, 0.000239330),
    };
    constant float3 goldPaperWeight[13] = {
        float3(0.000001476, 0.000000690, 0.022077120),
        float3(0.000001549, 0.001288381, 0.034287098),
        float3(0.000002099, 0.003908186, 0.099325727),
        float3(0.000005019, 0.020917498, 0.842551097),
        float3(0.000009540, 0.112066804, 0.001601635),
        float3(0.000010047, 0.132417663, 0.000004237),
        float3(0.000010977, 0.725110345, 0.000004629),
        float3(0.008850510, 0.004138889, 0.000011802),
        float3(0.074670874, 0.000043961, 0.000039642),
        float3(0.182149442, 0.000042692, 0.000038497),
        float3(0.208917308, 0.000030895, 0.000027860),
        float3(0.297009032, 0.000022013, 0.000019851),
        float3(0.228362128, 0.000011982, 0.000010805),
    };
    // END GENERATED OPTICAL PRINTER
    [[stitchable]] float4 opticalPremierPositive(coreimage::sample_t negative,
                                                   coreimage::sample_t original,
                                                   float ev, float amount,
                                                   float paperExposure,
                                                   float magentaFilterStops,
                                                   float yellowFilterStops,
                                                   float stock) {
        float3 reference = stock > 2.5 ? goldDensityAt(-1.14)
            : (stock > 1.5 ? ektarDensityAt(-0.84) : portraDensityAt(-1.44));
        float3 delta = negative.rgb - reference;
        // CIE A tungsten light through a stock-specific negative approximation,
        // integrated with E-4070 paper-layer sensitivities. Each weight set is
        // normalized at the assumed midscale negative; this absorbs a neutral
        // enlarger filter balance but does not identify a physical filter pack.
        float3 transmitted = float3(0.0);
        for (int i = 0; i < 13; i++) {
            float3 gain = stock > 2.5 ? goldDensityGain[i]
                : (stock > 1.5 ? ektarDensityGain[i] : portraDensityGain[i]);
            float3 weight = stock > 2.5 ? goldPaperWeight[i]
                : (stock > 1.5 ? ektarPaperWeight[i] : portraPaperWeight[i]);
            float relativeTransmission = pow(10.0, -clamp(dot(delta, gain), -6.0, 6.0));
            transmitted += weight * relativeTransmission;
        }
        // Virtual dichroic filtration: positive M/Y attenuates green/blue
        // paper-layer light. These stop offsets are not measured filter spectra.
        float3 filtration = float3(0.0, -magentaFilterStops, -yellowFilterStops);
        float3 logH = float3(-1.4 + paperExposure * 0.30103)
                    + log10(max(transmitted, float3(0.000001)))
                    + filtration * 0.30103;
        float3 density = float3(premierDensityAt(logH.r).r,
                                premierDensityAt(logH.g).g,
                                premierDensityAt(logH.b).b);
        // At zero paper exposure the reference negative is a neutral 0.18 print.
        density = clamp(density - premierDensityAt(-1.4) + 0.75,
                        float3(0.0), float3(3.0));
        float3 referencePrint = premierSpectralReflectance(float3(0.75));
        float3 positive = 0.18 * premierSpectralReflectance(density) / referencePrint;
        return float4(mix(max(original.rgb, float3(0.0)) * exp2(ev),
                          positive, amount), original.a);
    }

    // Ilford MG FB Classic publishes ISO R for grades 00, 0, 1, 2, 3, 4,
    // and 5 (170, 140, 110, 95, 80, 60, 50). The measured range informs
    // contrast; the smooth curve shape and 0.75-density gray aim are inferred.
    constant float multigradeRange[7] = {1.70, 1.40, 1.10, 0.95, 0.80, 0.60, 0.50};
    [[stitchable]] float4 multigradePositive(coreimage::sample_t negative,
                                              coreimage::sample_t original,
                                              float ev, float amount,
                                              float paperExposure,
                                              float gradeIndex, float stock) {
        int grade = clamp(int(round(gradeIndex)), 0, 6);
        float reference = stock > 4.5 ? tmaxDensityAt(-1.5) : trixDensityAt(-1.5);
        float negativeDensity = dot(negative.rgb, float3(0.333333));
        float relativeLogH = paperExposure * 0.30103 - (negativeDensity - reference);
        // Smoothstep reaches 0.75 paper density near 0.396 of its width.
        float u = clamp(0.396 + relativeLogH / multigradeRange[grade], 0.0, 1.0);
        float paperDensity = 0.04 + 2.06 * (u * u * (3.0 - 2.0 * u));
        float positive = 0.18 * pow(10.0, 0.75 - paperDensity);
        return float4(mix(max(original.rgb, float3(0.0)) * exp2(ev),
                          float3(positive), amount), original.a);
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
    // Density-domain texture is deliberately provisional: the Kodak curves do not
    // specify grain size or variance. The same spatial noise is used by preview/export.
    [[stitchable]] float4 applyNegativeGrain(coreimage::sample_t negative,
                                            float amount, float size, float seed, float stock,
                                            float textureVersion,
                                            coreimage::destination destination) {
        float2 coord = destination.coord();
        uint photoSeed = uint(seed);
        float fine = grainHash(int2(floor(coord)), 0xcb1ab31fu ^ photoSeed);
        float noise = fine;
        // Kodak describes Ektar as the finest-grained color negative. The
        // extra fine-grain choice is versioned because its exact scale is
        // not established by the public scanner-convolved reference scan.
        bool fineEktar = textureVersion >= 3.0 && stock > 1.5 && stock < 2.5;
        // The finer 100TMX texture is also a qualitative scale choice.
        float effectiveSize = (stock > 4.5 || fineEktar) ? size * 0.7 : size;
        if (effectiveSize > 0.001) {
            float2 lattice = coord / (2.5 * effectiveSize);
            int2 cell = int2(floor(lattice));
            float2 fraction = fract(lattice);
            float2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
            float4 weights = float4(
                (1.0 - blend.x) * (1.0 - blend.y),
                blend.x * (1.0 - blend.y),
                (1.0 - blend.x) * blend.y,
                blend.x * blend.y);
            float4 samples = float4(
                grainHash(cell, 0x61c88647u ^ photoSeed),
                grainHash(cell + int2(1, 0), 0x61c88647u ^ photoSeed),
                grainHash(cell + int2(0, 1), 0x61c88647u ^ photoSeed),
                grainHash(cell + int2(1, 1), 0x61c88647u ^ photoSeed));
            float coarse = dot(weights, samples)
                / sqrt(max(dot(weights, weights), 0.000001));
            noise = (coarse * 0.9 + fine * 0.1) / sqrt(0.82);
        }
        // One panchromatic layer gets one density field. Color negatives retain
        // shared structure plus restrained dye-layer variation.
        if (stock > 3.5) {
            float strength = stock > 4.5 ? 0.075 : 0.12;
            float variation = noise * clamp(amount, 0.0, 1.0) * strength;
            return float4(max(negative.rgb + float3(variation), float3(0.0)), negative.a);
        }
        // Shared spatial structure with restrained independent dye variation.
        float3 dyeNoise = float3(
            grainHash(int2(floor(coord)), 0x9e3779b9u ^ photoSeed),
            grainHash(int2(floor(coord)), 0x7f4a7c15u ^ photoSeed),
            grainHash(int2(floor(coord)), 0x94d049bbu ^ photoSeed));
        float strength = fineEktar ? 0.075 : 0.12;
        float3 variation = (float3(noise) * 0.85 + dyeNoise * 0.15)
            * clamp(amount, 0.0, 1.0) * strength;
        return float4(max(negative.rgb + variation, float3(0.0)), negative.a);
    }
    [[stitchable]] float4 applyGrain(coreimage::sample_t pixel,
                                    float amount, float size, float seed,
                                    coreimage::destination destination) {
                  // Signed channels can encode out-of-gamut detail for float TIFF.
                  // Output grain is not defined there; leave those pixels intact.
                  if (any(pixel.rgb < float3(0.0))) return pixel;
                  float2 coord = destination.coord();
                  uint photoSeed = uint(seed);
                  float fine = grainHash(int2(floor(coord)), 0xcb1ab31fu ^ photoSeed);
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
                          grainHash(cell, 0x61c88647u ^ photoSeed),
                          grainHash(cell + int2(1, 0), 0x61c88647u ^ photoSeed),
                          grainHash(cell + int2(0, 1), 0x61c88647u ^ photoSeed),
                          grainHash(cell + int2(1, 1), 0x61c88647u ^ photoSeed));
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

    [[stitchable]] float4 sceneHighlightMask(coreimage::sample_t pixel, float shotExposureEV) {
        float3 light = max(pixel.rgb, float3(0.0));
        float luminance = dot(light, float3(0.2126, 0.7152, 0.0722))
                        * exp2(clamp(shotExposureEV, -10.0, 10.0));
        float excess = max(luminance - 0.55, 0.0);
        // A soft onset and long shoulder retain differences between bright stops.
        // This is a provisional scattering model, not measured stock halation.
        float value = smoothstep(0.55, 0.90, luminance)
                    * (1.0 - exp(-excess / 2.0));
        return float4(value, value, value, 1.0);
    }

    [[stitchable]] float4 applyHalation(coreimage::sample_t pixel, coreimage::sample_t mask, coreimage::sample_t blurred, float amount) {
                  float spill = max(blurred.r - mask.r, 0.0) * amount * 0.24;
                  return float4(pixel.rgb + float3(spill, spill * 0.30, spill * 0.12), pixel.a);
              }

    [[stitchable]] float4 applyNeutralHalation(coreimage::sample_t pixel,
                                                coreimage::sample_t mask,
                                                coreimage::sample_t blurred,
                                                float amount) {
        float spill = max(blurred.r - mask.r, 0.0) * amount * 0.24;
        return float4(pixel.rgb + float3(spill), pixel.a);
    }

    [[stitchable]] float4 applyAcutance(coreimage::sample_t pixel,
                                       coreimage::sample_t blurred, float amount) {
        // Do not turn valid signed working-color values into black at an edge.
        if (any(pixel.rgb < float3(0.0))) return pixel;
        float3 source = max(pixel.rgb, float3(0.0));
        float3 lowPass = max(blurred.rgb, float3(0.0));
        float luma = dot(source, float3(0.2126, 0.7152, 0.0722));
        float lowLuma = dot(lowPass, float3(0.2126, 0.7152, 0.0722));
        float delta = clamp((luma - lowLuma) * amount * 0.65, -0.12, 0.12);
        float scale = max(luma + delta, 0.0) / max(luma, 0.000001);
        return float4(source * scale, pixel.a);
    }
    """#

  private static let preservingMixerSource = #"""
    [[stitchable]] float4 colorMixerBandV2(coreimage::sample_t pixel,
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

        if (abs(hueShift) < 0.000001 && abs(saturation) < 0.000001) {
            return float4(pixel.rgb * exp2(clamp(luminanceEV * mask, -2.0, 2.0)), pixel.a);
        }
        if (min(min(pixel.r, pixel.g), pixel.b) < 0.0) return pixel;

        float3 rgb = max(pixel.rgb, float3(0.0));
        float originalLuma = dot(rgb, float3(0.2126, 0.7152, 0.0722));
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
        float mixedLuma = dot(mixed, float3(0.2126, 0.7152, 0.0722));
        float3 centered = mixed - mixedLuma;
        float gamutScale = 1.0;
        if (centered.r < 0.0) gamutScale = min(gamutScale, originalLuma / -centered.r);
        if (centered.g < 0.0) gamutScale = min(gamutScale, originalLuma / -centered.g);
        if (centered.b < 0.0) gamutScale = min(gamutScale, originalLuma / -centered.b);
        float3 balanced = originalLuma + centered * clamp(gamutScale, 0.0, 1.0);
        return float4(balanced * exp2(clamp(luminanceEV * mask, -2.0, 2.0)), pixel.a);
    }

    """#

  private static let preservingSelectiveSource = #"""
    [[stitchable]] float4 preservingSelectiveColor(coreimage::sample_t pixel, float targetHue,
                                                 float range, float shift, float saturation) {
        float3 rgb = pixel.rgb;
        if (!all(isfinite(rgb)) || any(rgb < float3(0.0))) return pixel;
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
        float scale = max(0.0, 1.0 + saturation * mask);
        float newI = (i * cosine - q * sine) * scale;
        float newQ = (i * sine + q * cosine) * scale;
        float3 mixed = float3(
            y + 0.956 * newI + 0.621 * newQ,
            y - 0.272 * newI - 0.647 * newQ,
            y - 1.106 * newI + 1.703 * newQ
        );
        float originalLuma = dot(rgb, float3(0.2126, 0.7152, 0.0722));
        float mixedLuma = dot(mixed, float3(0.2126, 0.7152, 0.0722));
        float3 centered = mixed - mixedLuma;
        float gamutScale = 1.0;
        if (centered.r < 0.0) gamutScale = min(gamutScale, originalLuma / -centered.r);
        if (centered.g < 0.0) gamutScale = min(gamutScale, originalLuma / -centered.g);
        if (centered.b < 0.0) gamutScale = min(gamutScale, originalLuma / -centered.b);
        return float4(originalLuma + centered * clamp(gamutScale, 0.0, 1.0), pixel.a);
    }
    """#
}
