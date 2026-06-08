function T_out = preprocess_well(T_in, cfg, well_name)
% PREPROCESS_WELL — apply outlier → impute (PREDICTORS ONLY) → denoise → resample.
%
%   *** CRITICAL METHODOLOGICAL RULE ***
%   Target VS is NEVER imputed. Only the PREDICTOR logs (GR, RHOB, NPHI,
%   PHIE, VP) are imputed. VS values stay NaN where measurements are missing,
%   and a tag column VS_source ∈ {"measured","missing"} is added.
%
%   The supervised training/test set is built later by filtering on
%   VS_source == "measured" (see build_supervised_dataset.m).
%
%   Drops rows where most CANONICAL PREDICTORS are NaN BEFORE imputation
%   (e.g., NEJ-2 shallow zone 35-200 m has all -999.25).
%
%   Author: RCW (2026-06)

addpath(genpath(fullfile(cfg.matlab_root, 'src', 'preprocessing')));

predictor_cols = intersect({'GR','RHOB','NPHI','PHIE','VP'}, ...
                           T_in.Properties.VariableNames, 'stable');
has_VS = ismember('VS', T_in.Properties.VariableNames);
all_log_cols = predictor_cols;
if has_VS, all_log_cols = [predictor_cols, {'VS'}]; end

fprintf('  [PREP-%s] start: %d rows, predictors: %s%s\n', well_name, ...
        height(T_in), strjoin(predictor_cols, ', '), ...
        ternary(has_VS, ', target: VS (PROTECTED)', ''));

T = T_in;

% =========================================================================
% Stage 0: drop rows with mostly-NaN PREDICTORS (≥ 80% missing).
%          VS missingness does NOT cause row drop here.
% =========================================================================
n_preds = numel(predictor_cols);
nan_count = zeros(height(T), 1);
for k = 1:n_preds
    nan_count = nan_count + isnan(T.(predictor_cols{k}));
end
mostly_nan = nan_count >= ceil(0.8 * n_preds);
n_drop = sum(mostly_nan);
if n_drop > 0
    fprintf('  [PREP-%s] drop %d mostly-NaN-predictor rows (≥80%% preds missing)\n', ...
            well_name, n_drop);
    T(mostly_nan, :) = [];
end

% =========================================================================
% Stage 1: outlier detection (on all logs incl. VS)
%          Outlier-flagged VS becomes NaN → will be tagged "missing" later.
% =========================================================================
n_vs_outliers = 0;
for k = 1:numel(all_log_cols)
    c = all_log_cols{k};
    if ~ismember(c, T.Properties.VariableNames), continue; end
    bad = detect_outliers(T.(c), cfg);
    n_bad = sum(bad);
    if n_bad > 0
        T.(c)(bad) = NaN;
        fprintf('  [PREP-%s] %s: %d outliers marked NaN\n', well_name, c, n_bad);
        if strcmp(c, 'VS'), n_vs_outliers = n_bad; end
    end
end

% =========================================================================
% Stage 2: imputation — PREDICTORS ONLY (target VS untouched)
% =========================================================================
for k = 1:numel(predictor_cols)
    c = predictor_cols{k};
    if ~ismember(c, T.Properties.VariableNames), continue; end
    n_nan_before = sum(isnan(T.(c)));
    if n_nan_before > 0
        T.(c) = impute_missing(T.(c), cfg);
        n_after = sum(isnan(T.(c)));
        fprintf('  [PREP-%s] %s: imputed %d NaN (remaining %d)\n', ...
                well_name, c, n_nan_before - n_after, n_after);
    end
end

% VS is INTENTIONALLY skipped from imputation
if has_VS
    n_vs_missing = sum(~isfinite(T.VS) | T.VS <= 0);
    fprintf('  [PREP-%s] VS: PROTECTED from imputation (%d remain missing/invalid, %d outlier-flagged)\n', ...
            well_name, n_vs_missing, n_vs_outliers);
end

% =========================================================================
% Stage 3: drop rows still NaN in REQUIRED PREDICTORS (defensive).
%          Rows with missing VS are kept (their VS_source will be "missing").
% =========================================================================
required = intersect({'GR','RHOB','NPHI','VP'}, ...
                     T.Properties.VariableNames, 'stable');
mask_ok = true(height(T), 1);
for k = 1:numel(required)
    mask_ok = mask_ok & ~isnan(T.(required{k}));
end
n_drop = sum(~mask_ok);
if n_drop > 0
    T = T(mask_ok, :);
    fprintf('  [PREP-%s] dropped %d rows still NaN in required predictors\n', ...
            well_name, n_drop);
end

% =========================================================================
% Stage 4: denoise (Savitzky-Golay) — PREDICTORS ONLY
% =========================================================================
for k = 1:numel(predictor_cols)
    c = predictor_cols{k};
    if ismember(c, T.Properties.VariableNames) && ~any(isnan(T.(c)))
        T.(c) = denoise_savgol(T.(c), cfg);
    end
end
% VS is NOT denoised — keep raw measurements

% =========================================================================
% Stage 5: resample to uniform depth grid.
%   IMPORTANT: VS is resampled with nearest/measured-only logic in
%   resample_uniform; if not, the resampled VS may become weighted average
%   of measured + NaN neighbors. To be safe, we preserve VS via post-resample
%   nearest-measured assignment.
% =========================================================================
% Save VS-only sub-table BEFORE resample (preserve measured positions)
if has_VS
    vs_pre.depth = T.DEPTH;
    vs_pre.vs    = T.VS;
end

T_out = resample_uniform(T, cfg.preprocess.depth_step_m, predictor_cols);

% Re-assign VS by nearest measurement within ±dz/2 tolerance (NOT interpolation)
if has_VS
    measured_mask = isfinite(vs_pre.vs) & vs_pre.vs > 0;
    vs_meas_depth = vs_pre.depth(measured_mask);
    vs_meas_vals  = vs_pre.vs(measured_mask);
    tol = cfg.preprocess.depth_step_m * 0.51;   % half-step
    vs_resampled = nan(height(T_out), 1);
    for i = 1:height(T_out)
        d_i = T_out.DEPTH(i);
        [d_diff, j_near] = min(abs(vs_meas_depth - d_i));
        if d_diff <= tol
            vs_resampled(i) = vs_meas_vals(j_near);
        end
    end
    T_out.VS = vs_resampled;
end

% =========================================================================
% Stage 6: add VS_source flag (only if VS exists)
% =========================================================================
if has_VS
    vs_meas_final = isfinite(T_out.VS) & T_out.VS > 0;
    src = repmat("missing", height(T_out), 1);
    src(vs_meas_final) = "measured";
    T_out.VS_source = src;
    fprintf('  [PREP-%s] VS_source: measured=%d  missing=%d (total=%d)\n', ...
            well_name, sum(vs_meas_final), sum(~vs_meas_final), height(T_out));
else
    fprintf('  [PREP-%s] no VS column → blind deployment well\n', well_name);
end

fprintf('  [PREP-%s] FINAL: %d samples at dz=%.4f m, depth [%.2f, %.2f] m\n', ...
        well_name, height(T_out), cfg.preprocess.depth_step_m, ...
        min(T_out.DEPTH), max(T_out.DEPTH));
end


function s = ternary(cond, a, b)
if cond, s = a; else, s = b; end
end
