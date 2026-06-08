# Vs Prediction Pipeline — v3 (Target-Clean + Figure-Safe)

End-to-end pipeline for shear-wave velocity prediction in NEJ-1/NEJ-2.
This revision fixes the **methodological flaw** where VS target was imputed
and rebuilds the publication figures.

---

## 🚨 What changed in this revision (vs previous v3 run)

| # | Issue | Fix |
|---|---|---|
| 1 | **VS target imputed 3,317×** (47% of training) | `preprocess_well.m` rewritten — imputes predictors ONLY; VS protected. New `VS_source` column ∈ {measured, missing}. New `build_supervised_dataset.m` filters to measured-VS rows + hard assert. |
| 2 | Fig4 failed (YTick non-monotonic) | Use `y_idx = 1:n` (strictly increasing) + `YDir='reverse'` so best stays on top |
| 3 | Fig6 failed (length mismatch ood vs depth) | Length-safe extraction block: column-vector cast, truncate to min length, joint finite filter |
| 4 | QC false positive on degenerate scenarios | Use scenarios struct directly (not CSV re-read); all `readtable` calls use `'VariableNamingRule','preserve'` |
| 5 | "Predicted (deployment)" label on NEJ-1 plot | Renamed to "Predicted (test)" (NEJ-1 is held-out test, not deployment) |
| 6 | Fig7 bias caption hard-coded sign | Dynamic `'above'/'below'` based on bias sign |
| 7 | Fig8 PI extending below 0 km/s | Clipping for visualization only (raw bounds kept in CSV) + explicit caption |
| 8 | FigS shows "Non-physical diagnostic" when NP=0 | Conditional title: "Geomechanical plausibility diagnostic" if NP=0 |

---

## 📁 Pipeline architecture (post-revision)

```
data_load           [NEJ-1.xlsx, NEJ-2.xlsx]
       ↓
preprocess_well     [outlier → impute PREDICTORS → denoise → resample]
       ↓             ↳ VS untouched, VS_source tagged
                    ↳ post-resample: VS re-attached via nearest-measured only
       ↓
build_supervised_dataset    ← NEW: filter to VS_source=="measured"
       ↓                     ← hard assert: all measured ✓
train_test_split            [80/20 of supervised set only]
       ↓
feature_scenarios   [S1 mRMR∩LASSO | S2 all | S3 mRMR | S4 LASSO]
       ↓
base_learners × scenarios   [pnn / mlffnn / dffnn / cnn1d]
       ↓
meta_learners               [ridge / icnn / hybrid_icnn]
       ↓
build_model_results_master  ← single source of truth
       ↓
select_deployment_model     ← explicit tie threshold + narrative
       ↓
deploy_NEJ-2                [OOD detection, clipping, geomechanics]
       ↓
publication_figures         [Fig4-8 + FigS, Arial 300 DPI + PDF]
       ↓
assert_run_consistency      ← QC gate (hard + soft checks)
```

---

## 🚀 Running

```matlab
cd matlab_v3
clear; clc;
main_pipeline
```

Output → `results/NEJ_excel_locked_final_YYYYMMDD_HHMM/`

Expected runtime: ~25-35 min (less data → faster than previous v3 run).

---

## ✅ Manuscript-readiness checklist

After the run, verify the following in `audit/run_summary.txt`:

### Critical methodology
- [ ] `VS imputed for supervised learning: 0` ← MUST be exactly 0
- [ ] `Supervised samples` is roughly equal to `VS measured` count
- [ ] Train + Test = Supervised samples

### Files generated
- [ ] `tables/table3_test_performance.csv` exists, has `Domain=physical_kms`
- [ ] `tables/final_model_ranking.xlsx` rank-1 matches table3 rank-1
- [ ] `tables/feature_selection_scenarios.csv` has 4 rows, ≥2 distinct sets
- [ ] `figures_publication/Fig4_model_ranking_pub.png` exists
- [ ] `figures_publication/Fig6_NEJ-2_multitrack_pub.png` exists
- [ ] `model_selection_reason.txt` is multi-line narrative

### QC gate output
- [ ] Console shows: `✓ All HARD checks passed`
- [ ] If warnings present, review each one

---

## 📜 Manuscript guidance (per RCW spec)

**Critical**: Do NOT revise manuscript conclusions before this target-clean rerun.

After the run, the new ranking will reveal one of three scenarios:

| Scenario | Action |
|---|---|
| Hybrid I-CNN unggul melewati tie threshold (ΔR² > 0.005) **AND** CV stable | Revise to make Hybrid the primary model |
| Ridge atau PNN re-emerges as best (more likely with smaller measured-VS dataset) | Keep simple-model narrative — easier to defend |
| Top models tied (ΔR² < 0.005) | Practically-tied conclusion; deploy by simplicity/stability |

The dataset shrinking from 6,964 → ~3,799 measured samples likely changes the
optimal model. Deep models (CNN1D, I-CNN) may suffer; simpler models (Ridge,
PNN) may now have an edge.

---

Author: Ir. Rahmat Catur Wibowo · Universitas Lampung · 2026-06
