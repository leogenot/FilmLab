#!/usr/bin/env python3
"""Measure scanner-convolved texture in a uniform negative scan.

Usage: python measure-flatfield-grain.py SCAN.tif --kind ektar
       python measure-flatfield-grain.py SCAN.png --kind bw

Requires numpy and Pillow; Ektar TIFF additionally requires tifffile.
Source images are kept outside the repository. Output is JSON on stdout.
These are log scanner-signal statistics, not calibrated film density.
"""

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


def read_scan(path: Path) -> np.ndarray:
    if path.suffix.lower() in {".tif", ".tiff"}:
        import tifffile

        image = tifffile.imread(path)
    else:
        image = np.asarray(Image.open(path))
    if image.dtype != np.uint16:
        raise ValueError(f"expected 16-bit scan; got {image.dtype}")
    return image


def measure_tile(tile: np.ndarray) -> dict:
    # Log scanner value tracks density only if the scanner output is linear.
    # We use its spatial correlations; no absolute density calibration is claimed.
    log_image = -np.log10(np.maximum(tile.astype(np.float64), 1) / 65535)
    height, width = log_image.shape
    fx, fy = np.meshgrid(np.fft.fftfreq(width), np.fft.fftfreq(height))
    spectrum = np.fft.fft2(log_image)
    low_pass = np.exp(-2 * np.pi**2 * 16**2 * (fx**2 + fy**2))
    residual = log_image - np.fft.ifft2(spectrum * low_pass).real
    median = np.median(residual)
    mad = np.median(np.abs(residual - median))
    # A few dust/scratch pixels must not dominate the texture spectrum.
    residual = np.clip(residual, median - 5 * mad, median + 5 * mad)
    residual -= residual.mean()
    variance = np.mean(residual**2)
    if variance == 0:
        raise ValueError("zero residual variance")
    horizontal = [
        float(np.mean(residual[:, :-lag] * residual[:, lag:]) / variance)
        for lag in range(1, 9)
    ]
    vertical = [
        float(np.mean(residual[:-lag, :] * residual[lag:, :]) / variance)
        for lag in range(1, 9)
    ]
    return {
        "log_signal_mean": float(log_image.mean()),
        "log_signal_std_highpass": float(np.sqrt(variance)),
        "acf_horizontal_lags_1_8": horizontal,
        "acf_vertical_lags_1_8": vertical,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scan", type=Path)
    parser.add_argument("--kind", choices=["ektar", "bw"], required=True)
    args = parser.parse_args()
    image = read_scan(args.scan)
    if args.kind == "ektar":
        if image.ndim != 3 or image.shape[2] != 4:
            raise ValueError("Ektar source must be RGBA, including infrared alpha")
        channels = {"red": 0, "green": 1, "blue": 2}
    else:
        if image.ndim != 2:
            raise ValueError("Tri-X source must be 16-bit grayscale")
        image = image[:, :, None]
        channels = {"gray": 0}

    size = 512
    height, width = image.shape[:2]
    if width < 2 * size or height < 2 * size:
        raise ValueError("scan must be at least 1024 pixels in each dimension")
    results = {}
    for channel, index in channels.items():
        measurements = []
        for y_fraction in (0.25, 0.5, 0.75):
            for x_fraction in (0.25, 0.5, 0.75):
                center_x = round(width * x_fraction)
                center_y = round(height * y_fraction)
                tile = image[
                    center_y - size // 2 : center_y + size // 2,
                    center_x - size // 2 : center_x + size // 2,
                    index,
                ]
                measurements.append(measure_tile(tile))
        results[channel] = {
            "median_log_signal_std_highpass": float(
                np.median([m["log_signal_std_highpass"] for m in measurements])
            ),
            "median_acf_horizontal_lags_1_8": np.median(
                [m["acf_horizontal_lags_1_8"] for m in measurements], axis=0
            ).tolist(),
            "median_acf_vertical_lags_1_8": np.median(
                [m["acf_vertical_lags_1_8"] for m in measurements], axis=0
            ).tolist(),
            "tiles": measurements,
        }
    print(
        json.dumps(
            {
                "kind": args.kind,
                "scan": args.scan.name,
                "dimensions": [width, height],
                "tile_size": size,
                "tile_centers": [0.25, 0.5, 0.75],
                "highpass_gaussian_sigma_pixels": 16,
                "channels": results,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
