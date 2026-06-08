# VsPrediction-Stacking

**Hybrid I-CNN Stacking Ensemble for Shear-Wave Velocity Prediction from Conventional Well Logs**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2024b-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![Paper](https://img.shields.io/badge/paper-AIIG%202026-orange.svg)](https://doi.org/)
[![DOI](https://img.shields.io/badge/DOI-pending-lightgrey.svg)](https://doi.org/)

A reproducible MATLAB pipeline for shear-wave velocity (V<sub>s</sub>) prediction from
conventional well logs (GR, RHOB, NPHI, PHIE, V<sub>p</sub>). The framework stacks four
heterogeneous base learners (PNN, MLFFNN, DFFNN, 1D-CNN) under three meta-learner
variants (Ridge stacker, I-CNN stacker, and a **Hybrid multi-scale feature-fusion CNN**),
with Monte-Carlo-Dropout uncertainty quantification and an out-of-distribution (OOD)
safety layer for auditable cross-formation deployment. Deployment-model selection is
assessed across **five random seeds** to quantify reproducibility.

This repository accompanies:

> Wibowo, R.C., Handoyo, Kumalasari, I.N., Winardhy, I.S., Amijaya, H., Normansyah, Aristoteles, Sarkowi, M. (2026).
> *Hybrid I-CNN Stacking Ensemble for Shear-Wave Velocity Prediction from Conventional
> Well Logs: A Multi-Seed Robustness Study.* **Artificial Intelligence in Geosciences**.
> DOI: *(pending — update on acceptance)*.

> ⚠️ **Verify before publishing:** confirm the author list, title, and DOI against the
> final accepted manuscript; update the badges and the `How to cite` block accordingly.

---

## 📋 Table of contents

- [Overview](#-overview)
- [Key results](#-key-results)
- [Repository structure](#-repository-structure)
- [Requirements](#-requirements)
- [Quick start](#-quick-start)
- [Configuration](#-configuration)
- [Reproducing paper results](#-reproducing-paper-results)
- [Data availability](#-data-availability)
- [Output structure](#-output-structure)
- [How to cite](#-how-to-cite)
- [License](#-license)
- [Contact](#-contact)

---

## 🌍 Overview

Reliable shear-wave velocity supports reservoir characterization, AVO inversion, and
geomechanical caprock assessment — workflows central to CCS/CCUS evaluation in mature
basins. Dipole-sonic logging is expensive and absent from most legacy onshore wells.
This pipeline closes that gap with machine learning while embedding uncertainty
quantification and OOD safeguards that make cross-formation deployment auditable.

The pipeline implements:

1. **Data ingestion & preprocessing** — Excel reader, IQR + z-score outlier detection,
   kNN imputation of **predictors only** (the V<sub>s</sub> target is never imputed),
   Savitzky-Golay denoising, z-score normalization, uniform depth resampling.
2. **Target-clean supervised set** — only rows with *measured* V<sub>s</sub> are used for
   training; a hard assertion guarantees the target is never synthetic.
3. **Feature selection** — mRMR (top-k) and LASSO (10-fold CV), SHAP attribution, and a
   four-scenario ablation (S1 intersection, S2 all-features, S3 mRMR-only, S4 LASSO-only).
4. **Base learners** — PNN, MLFFNN, DFFNN, CNN1D.
5. **Meta-learners** — Ridge stacker, I-CNN stacker, and the Hybrid multi-scale
   feature-fusion CNN (kernels 3/5/7 → fusion → dense → regression).
6. **Multi-seed robustness** — stages 3–9 repeated over seeds {7, 99, 123, 2026, 42};
   the canonical seed (42) supplies the deployed model and the figures.
7. **Safety layer** — MC-Dropout (T = 200), OOD detection (|z| > 3), physical clipping.
8. **Deployment & indirect validation** — Vp–Vs crossplot vs Castagna and
   Greenberg-Castagna, plus geomechanical post-processing (ν, G, K).

---

## 🎯 Key results

Applied to a North East Java Basin well pair — training well **NEJ-1** (Kujung carbonate,
1415–1993 m, measured V<sub>s</sub>) and blind well **NEJ-2** (Plio-Pleistocene clastic
overburden, no V<sub>s</sub>). Held-out test R² reported as **mean ± std across five seeds**
in the physical km/s domain:

| Model              | R² (mean ± std) | Note                                       |
| ------------------ | --------------- | ------------------------------------------ |
| **Hybrid I-CNN**   | **0.821 ± 0.031** | ⭐ **Deployment model** (wins 3/5 seeds)    |
| Ridge stacker      | 0.812 ± 0.029   | Operational alternative (tie-break, 2/5)   |
| PNN                | 0.811 ± 0.029   | Best base learner                          |
| I-CNN stacker      | 0.808 ± 0.022   | Most stable (lowest seed variance)         |
| DFFNN              | 0.790 ± 0.031   |                                            |
| MLFFNN             | 0.777 ± 0.031   |                                            |
| CNN1D              | 0.730 ± 0.041   | Highest seed sensitivity                   |
| GC limestone       | 0.549 ± 0.040   | Empirical (lithology-matched baseline)     |
| GC shale           | 0.513 ± 0.044   | Empirical baseline                         |
| Castagna mudrock   | 0.200 ± 0.052   | Empirical baseline                         |

**Three principal findings:**

1. **The Hybrid multi-scale feature-fusion CNN is the top deployment model** (mean
   R² = 0.821, winning outright in 3 of 5 seeds). The Ridge stacker and PNN are
   practically tied within seed-to-seed variability and serve as defensible operational
   alternatives; a ΔR² < 0.005 tie-break promotes the simpler Ridge stacker in the two
   remaining seeds.
2. **Retaining all five logs (no feature selection, S2) gives the strongest stacking.**
   LASSO assigns a zero coefficient only to RHOB, and because the mRMR top-3 set
   {GR, NPHI, V<sub>p</sub>} is a subset of the LASSO-retained set, the intersection
   scenario S1 coincides with mRMR-only S3 by construction.
3. **Cross-formation deployment is auditable but demanding.** 13.5% of NEJ-2 samples are
   OOD-flagged (up to ~30% in the shallowest bin); within non-OOD samples the predicted
   V<sub>s</sub> tracks Greenberg-Castagna shale within ~1% and lies 7.9% below Castagna
   mudrock — consistent with the clastic, shale-dominated lithology. A previously-reported
   +44% upward bias was traced to V<sub>s</sub> **target imputation** and **eliminated** by
   the target-clean protocol.

---

## 📁 Repository structure

```
.
├── main_pipeline.m                 ← end-to-end entry point (script)
├── make_all_publication_figures.m
├── write_run_summary.m
├── config/
│   └── default_config.m            ← single source of truth for all settings
├── src/
│   ├── io/                         ← Excel reader, data audit
│   ├── preprocessing/              ← outliers, imputation (predictors only), denoise, resample
│   ├── features/                   ← mRMR, LASSO, scenarios, permutation importance
│   ├── models/                     ← PNN, MLFFNN, DFFNN, CNN1D (train + predict)
│   ├── stacking/                   ← Ridge, I-CNN, Hybrid I-CNN (train + predict)
│   ├── evaluation/                 ← model-results master, deployment selection, QC gate
│   ├── uncertainty/                ← MC-Dropout
│   ├── deployment/                 ← OOD, clipping, geomechanics, empirical baselines
│   ├── figures/                    ← diagnostic figures
│   ├── figures_publication/        ← 300-DPI publication figures
│   └── utils/                      ← logging, safe I/O helpers
├── data/                           ← (confidential well data NOT committed; see data/README.md)
├── results/                        ← generated at runtime (timestamped)
└── docs/
    └── REVISION_NOTES.md           ← changelog of the target-clean revision
```

---

## 🔧 Requirements

- **MATLAB R2024b** or later.
- Toolboxes: **Statistics and Machine Learning** (mRMR, LASSO, kNN, CV),
  **Deep Learning** (CNN1D, I-CNN, Hybrid I-CNN, MC-Dropout),
  **Optimization** (grid/Bayesian search), **Signal Processing** (Savitzky-Golay,
  resampling). **Parallel Computing** is optional.

Verify with `ver` in MATLAB.

---

## 🚀 Quick start

```matlab
% From the repository root:
addpath(genpath('src'));
addpath('config');

% Place NEJ-1.xlsx and NEJ-2.xlsx under data/ (not distributed — see data/README.md)

% Run the full pipeline end-to-end (preprocessing → models → multi-seed → deployment)
main_pipeline

% Outputs are written to results/NEJ_excel_locked_final_<timestamp>/
```

`main_pipeline` is a **script** (not a function): it loads `default_config()` internally,
runs the five-seed robustness loop, and uses the canonical seed (42) for deployment and
figures.

---

## 🛠 Configuration

All settings live in `config/default_config.m`. Key fields:

```matlab
cfg.data.train_file        = fullfile('data','NEJ-1.xlsx');   % calibrated well (has VS)
cfg.data.blind_file        = fullfile('data','NEJ-2.xlsx');   % blind well (no VS)
cfg.features.candidate_logs = {'GR','RHOB','NPHI','PHIE','VP'};
cfg.features.target         = 'VS';
cfg.features.mrmr_top_k     = 3;                              % S3 = top-3
cfg.stacking.candidates     = {'ridge','icnn','hybrid_icnn'};
cfg.selection.tie_threshold = 0.005;                          % ΔR² practical-tie band
cfg.uncertainty.mc_dropout_T = 200;
cfg.deployment.ood_zthresh   = 3;
cfg.deployment.vs_clip_kms    = [0.20, 4.50];
```

The five robustness seeds are set in `main_pipeline.m`
(`cfg.robustness.seeds = [7 99 123 2026 42]`, canonical seed listed **last**).

---

## 🧪 Reproducing paper results

The reported numbers come from the configuration in `config/default_config.m` with the
five seeds above. Because the field data are confidential, reproduction without them uses
statistically-matched synthetic wells (see `data/README.md`). Expected outcomes:

- Hybrid I-CNN mean R² ≈ 0.82; Ridge and PNN within seed variability.
- All-feature configuration (S2) is the strongest scenario.
- ~13.5% of blind-well samples OOD-flagged; predicted V<sub>s</sub> tracking GC shale.

---

## 🔒 Data availability

The NEJ-1 / NEJ-2 well-log data cannot be redistributed (operator confidentiality) and are
excluded from version control. Templates, a synthetic generator, and the final result
tables under `results/tables/` are provided so the workflow remains reproducible. See
[`data/README.md`](data/README.md).

---

## 📂 Output structure

Each run creates a timestamped folder:

```
results/NEJ_excel_locked_final_<timestamp>/
├── intermediate/      ← preprocessed + supervised CSVs (gitignored)
├── tables/            ← multi_seed_robustness.csv, feature_selection_scenarios.csv,
│                        all_scenarios_performance.csv, predictions_NEJ-2.csv, per_seed/
├── figures/           ← diagnostic figures
├── figures_publication/ ← 300-DPI publication figures
├── audit/             ← QC artifacts (gitignored)
└── logs/              ← timestamped run log (gitignored)
```

---

## 📚 How to cite

```bibtex
@article{Wibowo2026Vs,
  author  = {Wibowo, Rahmat Catur and Handoyo and Kumalasari, Isti Nur and
             Winardhy, Ignatius Sonny and Amijaya, Hendra and Normansyah and Aristoteles and Sarkowi, Muh},
  title   = {Hybrid I-CNN Stacking Ensemble for Shear-Wave Velocity Prediction
             from Conventional Well Logs: A Multi-Seed Robustness Study},
  journal = {Artificial Intelligence in Geosciences},
  year    = {2026},
  doi     = {10.xxxx/xxxxx}
}
```

A `CITATION.cff` file is included for GitHub's citation widget — update its `title`
field to match the manuscript title above.

---

## 📄 License

MIT License — see [`LICENSE`](LICENSE).

---

## 📧 Contact

**Rahmat Catur Wibowo** — Geological Engineering, Universitas Lampung, Indonesia
· ORCID [0000-0003-2754-1803](https://orcid.org/0000-0003-2754-1803)
· Code issues: <https://github.com/rcw3712/VsPrediction-Stacking/issues>
