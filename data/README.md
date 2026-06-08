# Data directory

The original well-log dataset (**NEJ-1** and **NEJ-2**, North East Java Basin)
cannot be redistributed due to operator confidentiality. The raw `.xlsx`/`.las`
files are intentionally excluded from version control (see `.gitignore`).

## Expected files (provide locally, not committed)

| File          | Well   | Role             | Required columns                          |
| ------------- | ------ | ---------------- | ----------------------------------------- |
| `NEJ-1.xlsx`  | NEJ-1  | Training (cal.)  | DEPTH, GR, RHOB, NPHI, PHIE, VP, VS        |
| `NEJ-2.xlsx`  | NEJ-2  | Blind deployment | DEPTH, GR, RHOB, NPHI, PHIE, VP (no VS)    |

NEJ-1 is the calibrated well (measured dipole-sonic VS available); NEJ-2 is the
blind deployment well (no VS — validated indirectly via trend, Vp–Vs
consistency, and empirical relations).

## Reproducibility without the confidential data

Researchers without access to the field data can reproduce the central findings
using statistically-matched synthetic wells. Place a `generate_synthetic_wells.m`
generator here (preserving means, variances, lag-1 and cross-correlations of the
real logs) and point `default_config.m` at the generated files.

To request access to the original data, contact the corresponding author
(subject to operator approval).
