# VsPrediction-Stacking

**Hybrid Multi-Scale Feature-Fusion CNN with Ridge Stacking for Shear-Wave Velocity Prediction from Conventional Well Logs**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2024b-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![Paper](https://img.shields.io/badge/paper-AIIG%202026-orange.svg)](https://doi.org/10.xxxx/xxxxx)
[![DOI](https://img.shields.io/badge/DOI-pending-lightgrey.svg)](https://doi.org/)
[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/)

A reproducible MATLAB pipeline for shear-wave velocity ($V_s$) prediction from conventional well logs (GR, RHOB, NPHI, PHIE, $V_p$). The framework combines four heterogeneous base learners (PNN, MLFFNN, DFFNN, 1D-CNN) with three meta-learner variants (I-CNN stacker, **Ridge stacker**, Hybrid Multi-Scale Feature-Fusion CNN), integrated uncertainty quantification (Monte Carlo Dropout), and out-of-distribution (OOD) safeguards with physical clipping.

This repository accompanies the paper:

> Wibowo, R.C., Handoyo, Kumalasari, I.N., Winardhy, I.S., Amijaya, H., Sarkowi, M. (2026). *Hybrid Multi-Scale Feature-Fusion Convolutional Network with Ridge Stacking for Shear-Wave Velocity Prediction from Conventional Well Logs: An Out-of-Distribution-Aware Framework.* **Artificial Intelligence in Geosciences**. DOI: [pending].

-----

## 📋 Table of Contents

- [Overview](#-overview)
- [Key results](#-key-results)
- [How to cite](#-how-to-cite)
- [Repository structure](#-repository-structure)
- [Requirements](#-requirements)
- [Installation](#%EF%B8%8F-installation)
- [Quick start](#-quick-start)
- [Configuration](#-configuration)
- [Reproducing paper results](#-reproducing-paper-results)
- [Data availability](#-data-availability)
- [Output structure](#-output-structure)
- [Documentation](#-documentation)
- [Testing](#-testing)
- [License](#-license)
- [Contact](#-contact)
- [Acknowledgments](#-acknowledgments)

-----

## 🌍 Overview

Reliable shear-wave velocity logging supports reservoir characterization, AVO inversion, and geomechanical caprock assessment — essential workflows for CCS/CCUS prospect evaluation in mature hydrocarbon basins. However, dipole sonic measurement is expensive and absent from most legacy onshore wells. This pipeline closes that gap through machine learning, while embedding rigorous uncertainty quantification and OOD safeguards that make cross-formation deployment auditable.

<p align="center">
  <img src="docs/figures/Fig1_workflow.png" alt="Workflow diagram" width="650"/>
</p>

**The pipeline implements:**

1. **Data ingestion & preprocessing** — LAS / Excel reader, IQR + Z-score outlier detection, kNN imputation, Savitzky-Golay denoising, z-score normalization, depth resampling
1. **Feature selection** — mRMR (with target binning for regression), LASSO with 10-fold CV, SHAP attribution, and four-scenario ablation
1. **Base learners** — Probabilistic Neural Network (PNN), Multi-Layer Feedforward Neural Network (MLFFNN), Deep Feedforward Neural Network (DFFNN), 1D Convolutional Neural Network (CNN1D)
1. **Meta-learners** — I-CNN stacker (baseline), **Ridge stacker (deployment model)**, Hybrid Multi-Scale Feature-Fusion CNN (architectural novelty)
1. **Hyperparameter optimization** — Bayesian Optimization with Gaussian Process surrogate, 5-fold cross-validation, validation-loss early stopping
1. **Safety layer** — Monte Carlo Dropout uncertainty quantification (T = 200), OOD detection (|z| > 3), physical clipping ([0.2, 4.5] km/s)
1. **Deployment & indirect validation** — Vp–Vs crossplot vs Castagna & Greenberg-Castagna, geomechanical post-processing (ν, G, K)

-----

## 🎯 Key results

Applied to a well pair in the North East Java Basin (Indonesia) — training well **RCW-1** (Late Oligocene Kujung carbonate, 1415–1993 m) and blind well **RCW-2** (Pliocene–Pleistocene clastic overburden, 35–629 m):

|Model            |$R^2$ (test)|Domain |Note                              |
|:----------------|-----------:|:-----:|:---------------------------------|
|**Ridge stacker**|**0.886**   |z-score|⭐ **Deployment model**            |
|PNN              |0.879       |z-score|Best base learner                 |
|MLFFNN           |0.869       |z-score|                                  |
|DFFNN            |0.816       |z-score|                                  |
|I-CNN stacker    |0.726       |z-score|Baseline deep stacking            |
|Hybrid I-CNN     |0.544       |z-score|Proposed novelty (negative result)|
|CNN1D            |−0.066      |z-score|Catastrophic on small data        |

**Three principal findings:**

1. **Linear stacking beats deep meta-learning on small tabular data** — Ridge stacker ($R^2 = 0.886$) outperforms both deep meta-learner variants (I-CNN $R^2 = 0.726$; Hybrid I-CNN $R^2 = 0.544$). Consistent with [Grinsztajn et al., 2022](https://arxiv.org/abs/2207.08815).
1. **mRMR-only outperforms mRMR ∩ LASSO intersection** for feature selection ($R^2 = 0.739$ vs $0.727$ in ablation). The intersection rule discards gamma-ray, which carries lithology-discriminative information not subsumed by other logs.
1. **Statistical OOD detection is necessary but not sufficient for cross-formation transfer.** 52.8% of RCW-2 samples flagged as OOD; even within non-OOD samples, predicted $V_s$ shows **+44% systematic upward bias** vs Castagna baseline due to *rock-physics regime mismatch* (carbonate-trained model applied to clastics). Identifies a structural failure mode of conventional OOD safeguards.

-----

## 📚 How to cite

If you use this code in your research, please cite both the paper and the software:

### Paper

```bibtex
@article{Wibowo2026Vs,
  author    = {Wibowo, Rahmat Catur and Handoyo and Kumalasari, Isti Nur and 
               Winardhy, Ignatius Sonny and Amijaya, Hendra and Sarkowi, Muh},
  title     = {Hybrid Multi-Scale Feature-Fusion Convolutional Network with 
               Ridge Stacking for Shear-Wave Velocity Prediction from 
               Conventional Well Logs: An Out-of-Distribution-Aware Framework},
  journal   = {Artificial Intelligence in Geosciences},
  year      = {2026},
  volume    = {?},
  pages     = {???--???},
  doi       = {10.xxxx/xxxxx},
  publisher = {KeAi / Elsevier}
}
```

### Software

```bibtex
@software{VsPredictionStacking2026,
  author       = {Wibowo, Rahmat Catur and Handoyo and Kumalasari, Isti Nur and 
                  Winardhy, Ignatius Sonny and Amijaya, Hendra and Sarkowi, Muh},
  title        = {{VsPrediction-Stacking: MATLAB pipeline for Vs prediction with 
                   stacking ensemble and OOD safeguards}},
  year         = {2026},
  publisher    = {GitHub},
  url          = {https://github.com/rcw3712/VsPrediction-Stacking},
  version      = {1.0.0}
}
```

A `CITATION.cff` file is included for GitHub’s automatic citation widget.

-----

## 📁 Repository structure

```
VsPrediction-Stacking/
│
├── README.md                       ← this file
├── LICENSE                         ← MIT license
├── CITATION.cff                    ← citation metadata (GitHub auto-citation)
├── .gitignore                      ← MATLAB-aware ignore rules
│
├── main_pipeline.m                 ← end-to-end driver script
│
├── config/
│   └── default_config.m            ← all hyperparameters + paths + flags
│
├── data/
│   ├── README.md                   ← data confidentiality note
│   ├── RCW-1_template.csv           ← column structure template (empty)
│   ├── RCW-2_template.csv          ← column structure template (empty)
│   └── generate_synthetic_wells.m  ← synthetic data with RCW-1/RCW-2-like statistics
│
├── src/
│   ├── preprocessing/              ← Section 2.2 of paper
│   │   ├── preprocessLogs.m
│   │   ├── detectOutliers.m
│   │   ├── imputeMissing.m
│   │   ├── denoiseSavGol.m
│   │   ├── normalizeZScore.m
│   │   └── resampleDepth.m
│   │
│   ├── features/                   ← Section 2.3
│   │   ├── computeMRMR.m
│   │   ├── runLASSO.m
│   │   ├── computeSHAP.m
│   │   └── selectFeatures.m
│   │
│   ├── models/                     ← Sections 2.4 & 2.5
│   │   ├── trainPNN.m              ← Probabilistic Neural Network
│   │   ├── trainMLFFNN.m           ← Multi-Layer FFNN (2 hidden layers)
│   │   ├── trainDFFNN.m            ← Deep FFNN (3 hidden layers)
│   │   ├── trainCNN1D.m            ← 1D Convolutional Neural Network
│   │   ├── trainICNN.m             ← I-CNN stacker meta-learner
│   │   ├── trainRidgeStacker.m     ← ★ Ridge stacker (deployment)
│   │   └── trainHybridICNN.m       ← Hybrid Multi-Scale Feature-Fusion CNN
│   │
│   ├── evaluation/                 ← Section 2.8
│   │   ├── computeMetrics.m        ← R², RMSE, MAE, MAPE
│   │   ├── crossPlot.m
│   │   ├── residualAnalysis.m
│   │   ├── learningCurves.m
│   │   └── taylorDiagram.m
│   │
│   ├── uncertainty/                ← Section 2.7
│   │   ├── mcDropoutPredict.m      ← T = 200 stochastic passes
│   │   ├── detectOOD.m             ← |z| > 3 criterion
│   │   ├── physicalClipping.m      ← [0.2, 4.5] km/s envelope
│   │   └── computeGeomechanics.m   ← ν, G, K from Vs
│   │
│   ├── ablation/                   ← Section 3.3
│   │   └── runAblation.m           ← S1 / S2 / S3 / S4 scenarios
│   │
│   └── deployment/                 ← Section 3.5
│       ├── deployToBT1.m           ← inference + UQ + OOD on blind well
│       ├── castagnaCheck.m         ← Vp–Vs empirical overlay
│       └── plotDeployment.m        ← multitrack figure
│
├── docs/
│   ├── METHODOLOGY.md              ← detailed equations + design choices
│   ├── HYPERPARAMETERS.md          ← full Bayesian search ranges
│   └── figures/
│       ├── Fig1_workflow.png       ← pipeline workflow (paper Fig 1)
│       └── Fig2_architecture.png   ← Hybrid I-CNN architecture (paper Fig 2)
│
├── results/                        ← generated by main_pipeline
│   ├── .gitkeep
│   ├── preprocessing/
│   ├── feature_selection/
│   ├── base_models/
│   ├── meta_models/
│   ├── uncertainty/
│   ├── ablation/
│   ├── deployment/
│   ├── figures/                    ← all PNG/PDF outputs
│   ├── tables/                     ← XLSX summary tables
│   └── logs/                       ← timestamped run logs
│
└── tests/
    ├── runTests.m                  ← top-level test runner
    ├── testPreprocessing.m
    ├── testModels.m
    ├── testUncertainty.m
    └── testDeployment.m
```

-----

## 🔧 Requirements

### Software

- **MATLAB R2024b** or later (older releases untested; some neural-net syntax requires R2024a+)
- A standards-compliant `git` client for cloning

### MATLAB toolboxes

The following toolboxes are required:

|Toolbox                                    |Used for                                      |
|:------------------------------------------|:---------------------------------------------|
|**Statistics and Machine Learning Toolbox**|mRMR, LASSO, k-NN imputation, cross-validation|
|**Deep Learning Toolbox**                  |CNN1D, I-CNN, Hybrid I-CNN, MC-Dropout        |
|**Optimization Toolbox**                   |Bayesian Optimization (`bayesopt`)            |
|**Signal Processing Toolbox**              |Savitzky-Golay filter, depth resampling       |
|**Parallel Computing Toolbox** *(optional)*|Parallel hyperparameter search and ablation   |

To verify available toolboxes in MATLAB:

```matlab
ver
```

### Operating system

Tested on:

- ✅ macOS 14 (Sonoma) — Apple Silicon
- ✅ Windows 11 — x86_64
- ✅ Ubuntu 22.04 LTS

GPU is optional; pipeline runs on CPU in approximately 45 minutes for the full RCW-1 dataset (3530 samples, 5 features).

-----

## ⚙️ Installation

### 1. Clone the repository

```bash
git clone https://github.com/rcw3712/VsPrediction-Stacking.git
cd VsPrediction-Stacking
```

### 2. Add to MATLAB path

In MATLAB:

```matlab
cd /path/to/VsPrediction-Stacking
addpath(genpath('src'));
addpath('config');
savepath();   % optional, to persist the path
```

Or add this to your `startup.m`:

```matlab
addpath(genpath(fullfile(userpath, 'VsPrediction-Stacking', 'src')));
```

### 3. Verify installation

```matlab
runTests  % runs all unit tests; expect "All tests passed."
```

-----

## 🚀 Quick start

The pipeline is driven by a single configuration struct. The minimum working example:

```matlab
% 1. Load default configuration
cfg = default_config();

% 2. Point to your well-log files
cfg.training.dataPath  = 'data/your_training_well.csv';
cfg.deployment.dataPath = 'data/your_blind_well.csv';

% 3. Run the full pipeline (preprocessing → models → deployment)
results = main_pipeline(cfg);

% 4. Inspect key results
disp(results.meta.ridge.metrics)
%   R²:    0.886
%   RMSE:  0.342 (z-score) | 0.178 (km/s)
%   MAE:   0.199 (z-score) | 0.104 (km/s)
%   MAPE:  115

% 5. Deployment-well predictions
fprintf('OOD-flagged samples: %.1f%%\n', results.deployment.ood_pct);
fprintf('Mean predicted Vs (non-OOD): %.2f km/s\n', ...
        results.deployment.mean_vs_nonOOD);
```

After the run finishes, all outputs are saved under `results/` (see [Output structure](#-output-structure)).

-----

## 🛠 Configuration

All settings live in `config/default_config.m`. Key fields:

```matlab
function cfg = default_config()

    % ─── Data ──────────────────────────────────────────────
    cfg.training.dataPath  = 'data/RCW-1_logs.csv';
    cfg.deployment.dataPath = 'data/RCW-2_logs.csv';
    cfg.targetColumn       = 'Vs';
    cfg.featureColumns     = {'GR', 'RHOB', 'NPHI', 'PHIE', 'VP'};

    % ─── Preprocessing ────────────────────────────────────
    cfg.preproc.outlierIQR     = 1.5;
    cfg.preproc.outlierZ       = 3.0;
    cfg.preproc.imputerK       = 5;       % kNN imputation
    cfg.preproc.savgolOrder    = 2;
    cfg.preproc.savgolWindow   = 11;
    cfg.preproc.resampleDepth  = 0.15;    % meters

    % ─── Feature selection ───────────────────────────────
    cfg.fs.combineRule = 'mrmr_only';     % 'intersect' | 'mrmr_only' | 'lasso_only' | 'none'

    % ─── Train/test split ────────────────────────────────
    cfg.split.testFraction = 0.20;
    cfg.split.kfold        = 5;
    cfg.split.fixedSeed    = 7;

    % ─── Base learners ──────────────────────────────────
    cfg.base.PNN.spreadRange   = [0.05, 1.5];
    cfg.base.MLFFNN.hiddenRange = {[16 128], [16 128]};
    cfg.base.DFFNN.hiddenRange  = {[8 64], [8 64], [8 64]};
    cfg.base.CNN1D.windowSize   = 16;
    cfg.base.CNN1D.fixedSeed    = 7;

    % ─── Meta-learners ──────────────────────────────────
    cfg.meta.runRidge      = true;
    cfg.meta.runICNN       = true;
    cfg.meta.runHybridICNN = true;
    cfg.meta.deploymentChoice = 'ridge';   % 'ridge' | 'icnn' | 'hybrid'
    cfg.meta.ridge.lambdaGrid = logspace(-6, 2, 25);

    % ─── Hybrid I-CNN architecture ─────────────────────
    cfg.icnn.windowSize   = 16;
    cfg.icnn.kernelsMulti = [3 5 7];       % multi-scale branches
    cfg.icnn.fusion       = 'concat';      % 'concat' | 'attention'

    % ─── Hyperparameter optimization ──────────────────
    cfg.opt.maxObjEvals  = 30;
    cfg.opt.useGridSearch = true;
    cfg.opt.maxTimeSec   = 3600;

    % ─── Uncertainty + OOD ───────────────────────────
    cfg.uq.mcDropoutSamples = 200;
    cfg.uq.alphaPI          = 0.95;
    cfg.ood.zThreshold      = 3;
    cfg.ood.clipMin         = 0.2;        % km/s
    cfg.ood.clipMax         = 4.5;        % km/s

    % ─── Output ──────────────────────────────────────
    cfg.output.rootDir      = 'results';
    cfg.output.figureDPI    = 300;
    cfg.output.saveMatFiles = true;
    cfg.output.saveExcel    = true;
end
```

To customize, copy `default_config.m` to `config/my_config.m`, edit, then:

```matlab
cfg = my_config();
results = main_pipeline(cfg);
```

-----

## 🧪 Reproducing paper results

The paper results were generated with the configuration shipped in `config/default_config.m` and the fixed seed `rng(7)`. To reproduce:

```matlab
% 1. Generate synthetic data with the same statistical properties as the paper's
%    training and blind wells (since the original data are confidential)
generate_synthetic_wells('data/', 'RCW-1-like.csv', 'RCW-2-like.csv', 7);

% 2. Point config at the synthetic files
cfg = default_config();
cfg.training.dataPath  = 'data/RCW-1-like.csv';
cfg.deployment.dataPath = 'data/RCW-2-like.csv';

% 3. Run
results = main_pipeline(cfg);
```

Expected outcomes on the synthetic data (statistically equivalent within ± 2% to the paper):

- Ridge stacker $R^2 \approx 0.88$
- mRMR-only beats intersection
- Approximately 50% of blind-well samples flagged as OOD
- Systematic positive bias of predicted Vs relative to Castagna baseline (typically +30 to +50%)

The synthetic data preserves the cross-formation regime mismatch by design; this ensures the central scientific finding is reproducible even without access to the confidential field data.

-----

## 🔒 Data availability

The original well-log dataset (RCW-1 and RCW-2, Field RCW, North East Java Basin) cannot be publicly distributed due to operator confidentiality. To preserve scientific reproducibility, this repository includes:

- **Column-structure templates** (`data/RCW-1_template.csv`, `data/RCW-2_template.csv`) — empty headers showing the expected log names and depth-step convention
- **Synthetic data generator** (`data/generate_synthetic_wells.m`) — produces well-log sequences with statistical properties (means, variances, lag-1 correlations, cross-correlations) calibrated to match RCW-1 and RCW-2
- **Pre-computed result tables** (`results/tables/`) — the final $R^2$, RMSE, ablation, and deployment numbers reported in the paper, distributed as Excel files

Researchers seeking access to the original well-log data may contact the corresponding author with a formal data-sharing request, subject to operator approval.

-----

## 📂 Output structure

After running `main_pipeline`, the `results/` directory is populated as:

```
results/
├── logs/
│   └── run_20260515_143022.log    ← timestamped pipeline log
│
├── preprocessing/
│   ├── RCW-1_clean.mat
│   ├── RCW-2_clean.mat
│   └── preproc_summary.xlsx
│
├── feature_selection/
│   ├── FS_mRMR_scores.png
│   ├── FS_LASSO_path.png
│   ├── FS_SHAP_summary.png
│   └── feature_selection_summary.xlsx
│
├── base_models/
│   ├── PNN_model.mat
│   ├── MLFFNN_model.mat
│   ├── DFFNN_model.mat
│   ├── CNN1D_model.mat
│   ├── EVAL_learning_curves.png
│   └── base_learners_metrics.xlsx
│
├── meta_models/
│   ├── ICNN_stacker_model.mat
│   ├── Ridge_stacker_model.mat     ← ★ deployment model
│   ├── Hybrid_ICNN_model.mat
│   ├── META_ridge_pred_vs_actual.png
│   ├── META_icnn_pred_vs_actual.png
│   ├── META_hybrid_pred_vs_actual.png
│   └── meta_learners_metrics.xlsx
│
├── ablation/
│   ├── ablation_radar.png
│   └── ablation_summary.xlsx
│
├── uncertainty/
│   ├── UQ_band.png
│   ├── UQ_distribution.png
│   └── uncertainty_predictions.xlsx
│
├── deployment/
│   ├── BT1_deployment_multitrack.png
│   ├── BT1_vpvs_crossplot.png
│   ├── BT1_geomech.png
│   └── BT1_deployment_predictions.xlsx
│
└── tables/
    ├── final_model_ranking.xlsx     ← Table 3 of paper
    ├── best_hyperparameters.xlsx    ← Table 2 of paper
    └── icnn_metrics.xlsx
```

All figures are 300 DPI PNG by default. To also export PDF/SVG:

```matlab
cfg.output.figureFormats = {'png', 'pdf', 'svg'};
```

-----

## 📖 Documentation

- **[METHODOLOGY.md](docs/METHODOLOGY.md)** — full mathematical derivations, design-choice rationale, and pseudocode for each module
- **[HYPERPARAMETERS.md](docs/HYPERPARAMETERS.md)** — full Bayesian Optimization search ranges, prior justifications, and optimized values
- **Paper §2–§4** — comprehensive narrative description, equations, and discussion of results
- **In-source comments** — every `.m` file is documented with header block, parameter description, and references to relevant paper sections

-----

## ✅ Testing

```matlab
runTests
```

Runs unit tests covering preprocessing, model training, uncertainty estimation, and deployment modules on synthetic data. Expected runtime: ~3 minutes on a modern laptop.

Individual modules can be tested separately:

```matlab
testPreprocessing
testModels
testUncertainty
testDeployment
```

-----

## 🤝 Contributing

Contributions are welcome. If you find a bug, please open an issue with:

1. A minimal reproducible example
1. The MATLAB version and operating system
1. The full error message and stack trace

For feature additions (new base learners, alternative meta-learners, additional rock-physics constraints), please:

1. Open an issue to discuss before submitting a PR
1. Follow the existing code style (MATLAB capitalized verbNoun, header blocks, structured config)
1. Add a corresponding unit test
1. Update `docs/METHODOLOGY.md` if the change is methodological

-----

## 📄 License

This project is licensed under the MIT License — see <LICENSE> for the full text.

The MIT License is permissive: you may use, modify, and distribute this code for any purpose (academic or commercial), as long as the original copyright notice and license text are retained.

-----

## 📧 Contact

**Corresponding author**

Rahmat Catur Wibowo  
Geological Engineering Department, Universitas Lampung  
Bandar Lampung, Indonesia  
Email: [rahmat.caturwibowo@eng.unila.ac.id](mailto:rahmat.caturwibowo@eng.unila.ac.id)

For code-specific issues, the GitHub issues page is preferred:  
<https://github.com/rcw3712/VsPrediction-Stacking/issues>

-----

## 🙏 Acknowledgments

We thank the operators of Field RCW for providing well-log access under confidentiality terms, and the geophysics community for the foundational empirical relations [Castagna et al., 1985; Greenberg and Castagna, 1992] that underpin the indirect validation framework. The reviewers of *Artificial Intelligence in Geosciences* are gratefully acknowledged for their constructive feedback.

This work was supported by [insert funding source, grant number, year] *(please complete before final publication)*.

The open-source community is also acknowledged: the pipeline builds on MATLAB’s Deep Learning Toolbox, Statistics and Machine Learning Toolbox, and the SHAP attribution implementation inspired by [Lundberg and Lee, 2017](https://proceedings.neurips.cc/paper/2017/hash/8a20a8621978632d76c43dfd28b67767-Abstract.html).

-----

<p align="center">
  <em>If this code helps your research, please consider citing the paper above and starring ⭐ the repository.</em>
</p>
