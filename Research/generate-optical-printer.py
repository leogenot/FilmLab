#!/usr/bin/env python3
"""Regenerate the declared tungsten / negative / Premier paper study constants.

Inputs are visually read Kodak E-4050, E-4046, E-7022, E-4070 plots at 25 nm,
plus CIE illuminant A samples. These are approximate graph readings, not a fit
for individual film batches or enlarger/filter combinations.
"""
import argparse
import csv
import io
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'Research/optical-printer-source.csv'
OUTPUT = ROOT / 'Research/optical-printer-integration.csv'
KERNEL = ROOT / 'Sources/FilmLab/FilmKernels.swift'
STOCKS = (
    ('portra', 'portra400-density.csv', -1.44),
    ('ektar', 'ektar100-density.csv', -0.84),
    ('gold', 'gold200-density.csv', -1.14),
)


def pchip_at(xs, ys, x):
    """Same interior PCHIP tangent and Hermite interpolation as the Metal curve."""
    slopes = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(len(xs) - 1)]
    i = next(i for i in range(len(xs) - 1) if xs[i] <= x <= xs[i + 1])
    def tangent(j):
        if j == 0 or j == len(xs) - 1:
            return slopes[min(j, len(slopes) - 1)]
        left, right = slopes[j - 1], slopes[j]
        if left * right <= 0:
            return 0.0
        h0, h1 = xs[j] - xs[j - 1], xs[j + 1] - xs[j]
        w0, w1 = 2 * h1 + h0, h1 + 2 * h0
        return (w0 + w1) / (w0 / left + w1 / right)
    h = xs[i + 1] - xs[i]
    t = (x - xs[i]) / h
    return ((2*t**3 - 3*t*t + 1)*ys[i]
            + (t**3 - 2*t*t + t)*h*tangent(i)
            + (-2*t**3 + 3*t*t)*ys[i + 1]
            + (t**3 - t*t)*h*tangent(i + 1))


def negative_reference_minus_min(filename, anchor):
    rows = list(csv.reader((ROOT / 'Research' / filename).open()))[1:]
    xs = [float(row[0]) for row in rows]
    # CSV is blue, green, red; kernel density is red, green, blue.
    return [pchip_at(xs, [float(row[j]) for row in rows], anchor) - float(rows[0][j])
            for j in (3, 2, 1)]


rows = list(csv.DictReader(SOURCE.open()))
assert [int(r['wavelength_nm']) for r in rows] == list(range(400, 701, 25))
result = {}
for stock, density_file, anchor in STOCKS:
    denom = negative_reference_minus_min(density_file, anchor)
    assert all(x > 0 for x in denom)
    unnormalized = []
    spectral = []
    for row in rows:
        wavelength = int(row['wavelength_nm'])
        mid = float(row[f'{stock}_midscale_density'])
        minimum = float(row[f'{stock}_dmin_density'])
        assert mid > minimum >= 0
        # Inferred CMY decomposition: positive smooth lobes partition the
        # measured neutral-minus-D-min spectrum at each wavelength.
        lobes = [math.exp(-0.5 * ((wavelength - center) / width) ** 2)
                 for center, width in ((650, 70), (540, 65), (450, 60))]
        fraction = [lobe / sum(lobes) for lobe in lobes]
        spectral.append([(mid - minimum) * fraction[j] / denom[j] for j in range(3)])
        endpoint = 0.5 if wavelength in (400, 700) else 1.0
        lamp = float(row['cie_illuminant_a'])
        unnormalized.append([
            endpoint * lamp * 10 ** float(row[f'paper_{color}_log_sensitivity'])
            * 10 ** -mid for color in ('red', 'green', 'blue')])
    totals = [sum(row[j] for row in unnormalized) for j in range(3)]
    weights = [[row[j] / totals[j] for j in range(3)] for row in unnormalized]
    assert all(abs(sum(row[j] for row in weights) - 1) < 1e-10 for j in range(3))
    result[stock] = (spectral, weights)

csv_output = io.StringIO(newline='')
writer = csv.writer(csv_output)
writer.writerow(['wavelength_nm'] + [f'{stock}_{kind}_{channel}'
                for stock, _, _ in STOCKS for kind in ('density_gain', 'paper_weight')
                for channel in ('red', 'green', 'blue')])
for i, row in enumerate(rows):
    writer.writerow([row['wavelength_nm']] + [f'{v:.9f}'
                    for stock, _, _ in STOCKS for vectors in result[stock]
                    for v in vectors[i]])

lines = ['    // BEGIN GENERATED OPTICAL PRINTER (Research/generate-optical-printer.py)']
for stock, _, _ in STOCKS:
    for name, values in zip(('DensityGain', 'PaperWeight'), result[stock]):
        lines.append(f'    constant float3 {stock}{name}[13] = {{')
        lines += ['        float3(' + ', '.join(f'{v:.9f}' for v in vector) + '),'
                  for vector in values]
        lines.append('    };')
lines.append('    // END GENERATED OPTICAL PRINTER')
text = KERNEL.read_text()
start = text.index('    // BEGIN GENERATED OPTICAL PRINTER')
end = text.index('    // END GENERATED OPTICAL PRINTER', start) + len('    // END GENERATED OPTICAL PRINTER')
generated_kernel = '\n'.join(lines)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true', help='fail if generated outputs differ')
args = parser.parse_args()
if args.check:
    if OUTPUT.read_bytes() != csv_output.getvalue().encode() or text[start:end] != generated_kernel:
        raise SystemExit('Optical printer data or Metal constants are out of date')
    print('Optical printer generated data matches source plots')
else:
    OUTPUT.write_text(csv_output.getvalue())
    KERNEL.write_text(text[:start] + generated_kernel + text[end:])
