# Data directory

This directory holds well-log inputs to the pipeline.

## Confidentiality notice

The original well-log dataset (Field RCW, North East Java Basin) used in the
accompanying paper is **not redistributable** due to confidentiality restrictions
imposed by the field operator. **Do not commit raw well-log files (`.csv`,
`.las`, `.xlsx`) to this repository.** The repository's `.gitignore` is
configured to ignore such files by default.

## What is provided

| File | Purpose |
|---|---|
| `BT-4_template.csv` | Header-only CSV showing the expected columns for the **training well** (with Vs target). Copy this file, rename to your own well name, and append your data rows below the header. |
| `BTS-1_template.csv` | Header-only CSV showing the expected columns for the **blind well** (no Vs). Same workflow as above. |
| `generate_synthetic_wells.m` | *(planned)* MATLAB script that generates statistically equivalent synthetic well-log sequences for both wells, preserving the cross-formation regime mismatch. |

## Expected file format

### Training well — `BT-4_template.csv`

```
Depth,GR,RHOB,NPHI,PHIE,VP,Vs
```

7 columns, one row per depth sample. **The training well must include Vs.**

### Blind well — `BTS-1_template.csv`

```
Depth,GR,RHOB,NPHI,PHIE,VP
```

6 columns, one row per depth sample. **The blind well must NOT include Vs**
(if present, it will be silently ignored by the deployment routine).

## Column specifications

| Column | Unit | Range (typical) | Description |
|:-|:-|:-|:-|
| `Depth` | meters | 0–6000 | True vertical depth below ground level (TVD), must be **monotonically increasing** |
| `GR`    | API   | 0–200    | Gamma-ray total count |
| `RHOB`  | g/cm³ | 1.5–3.0  | Bulk density |
| `NPHI`  | fraction (dimensionless) | 0–1 | Neutron porosity (1 = 100% porosity) |
| `PHIE`  | fraction (dimensionless) | 0–1 | Effective porosity |
| `VP`    | m/s   | 1500–6000 | Compressional-wave velocity (the pipeline auto-converts to km/s internally) |
| `Vs`    | m/s   | 700–4000  | Shear-wave velocity from dipole sonic (training well only) |

## Missing values

- Empty cells or `NaN` are both accepted
- The pipeline will impute missing values via k-NN (k = 5) using other features as predictors (Section 2.2 of paper)
- However, depth column must have no gaps — if depth row is missing entirely, drop the whole row

## Example data row (for illustration only)

The template files contain headers only. Below is what a single populated row would look like:

```
1415.00,42.31,2.45,0.18,0.12,3120,1820
```

(depth 1415 m, GR 42.31 API, RHOB 2.45 g/cm³, NPHI 0.18, PHIE 0.12, VP 3120 m/s, Vs 1820 m/s)

## Excel (XLSX) input

The pipeline also accepts `.xlsx` files with the same column structure. The first row must be the header. Place files at:

- `data/<your_training_well>.xlsx`
- `data/<your_blind_well>.xlsx`

The pipeline auto-detects file extension and dispatches the appropriate reader.

## Data sharing requests

Researchers seeking access to the original BT-4 and BTS-1 well-log data may
contact the corresponding author (`rahmat.caturwibowo@eng.unila.ac.id`) with
a formal data-sharing request. Approval is subject to the operator's
confidentiality terms.
