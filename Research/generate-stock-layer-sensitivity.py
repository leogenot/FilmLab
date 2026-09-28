#!/usr/bin/env python3
"""Integrate public Kodak plot readings against a D65 RGB spectral surrogate."""

import argparse
import csv
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Research/stock-layer-sensitivity-source.csv"
KERNEL = ROOT / "Sources/FilmLab/FilmKernels.swift"
START = "    // BEGIN GENERATED STOCK LAYER SENSITIVITY\n"
END = "    // END GENERATED STOCK LAYER SENSITIVITY\n"
STOCKS = ("portra", "ektar", "gold")
LAYERS = ("c", "m", "y")  # Output R/G/B density channels.


def generate():
    rows = list(csv.DictReader(SOURCE.open(newline="")))
    assert [int(row["wavelength_nm"]) for row in rows] == list(range(400, 701, 25))
    for row in rows:
        basis = [float(row[f"basis_{channel}"]) for channel in "rgb"]
        assert all(0 <= value <= 1 for value in basis)
        assert abs(sum(basis) - 1) < 1e-5

    # The D65-weighted surrogate reproduces the 1931 XYZ primaries of linear
    # sRGB at the 25 nm sampling precision. The basis itself is an assumption.
    xyz = []
    for component in ("x", "y", "z"):
        xyz.append([
            sum(
                float(row[f"cie_{component}"]) * float(row["d65"])
                * float(row[f"basis_{channel}"])
                * (0.5 if index in (0, len(rows) - 1) else 1)
                for index, row in enumerate(rows)
            )
            for channel in "rgb"
        ])
    target = ((.4124564, .3575761, .1804375),
              (.2126729, .7151522, .0721750),
              (.0193339, .1191920, .9503041))
    white_y = sum(xyz[1])
    for component in range(3):
        white_component = sum(xyz[component]) / white_y
        expected_total = sum(target[component])
        assert max(abs(xyz[component][channel] / white_y
                       - target[component][channel] * white_component / expected_total)
                   for channel in range(3)) < .002

    matrices = []
    for stock in STOCKS:
        matrix = []
        for layer in LAYERS:
            terms = []
            for index, row in enumerate(rows):
                log_s = row[f"{stock}_{layer}_log"]
                sensitivity = 10 ** float(log_s) if log_s else 0.0
                weight = 0.5 if index in (0, len(rows) - 1) else 1.0
                terms.append(sensitivity * float(row["d65"]) * weight)
            neutral = sum(terms)
            assert neutral > 0
            channels = [
                sum(term * float(row[f"basis_{channel}"])
                    for term, row in zip(terms, rows)) / neutral
                for channel in "rgb"
            ]
            assert math.isclose(sum(channels), 1, abs_tol=1e-12)
            matrix.append(channels)
        matrices.append(matrix)

    lines = [START, "    inline float3 stockLayerLight(float3 light, float stock) {\n",
             "        // Rows: cyan/red, magenta/green, yellow/blue layer light.\n",
             "        if (stock < 1.5) {\n"]
    for stock_index, matrix in enumerate(matrices):
        if stock_index == 1:
            lines.append("        } else if (stock < 2.5) {\n")
        elif stock_index == 2:
            lines.append("        } else {\n")
        lines.append("            return float3(\n")
        for row_index, channel in enumerate(matrix):
            suffix = "," if row_index < 2 else ""
            values = ", ".join(f"{value:.9f}" for value in channel)
            lines.append(f"                dot(light, float3({values})){suffix}\n")
        lines.append("            );\n")
    lines += ["        }\n", "    }\n", END]
    return "".join(lines), matrices


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    generated, matrices = generate()
    source = KERNEL.read_text()
    if START not in source or END not in source:
        raise SystemExit("Missing generated sensitivity markers in FilmKernels.swift")
    start = source.index(START)
    end = source.index(END, start) + len(END)
    updated = source[:start] + generated + source[end:]
    if args.check:
        if updated != source:
            raise SystemExit("Stock layer sensitivity shader is stale; regenerate it")
    else:
        KERNEL.write_text(updated)
    for stock, matrix in zip(STOCKS, matrices):
        print(stock, [[round(value, 5) for value in row] for row in matrix])


if __name__ == "__main__":
    main()
