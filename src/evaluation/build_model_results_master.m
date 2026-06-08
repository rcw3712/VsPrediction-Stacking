function M = build_model_results_master(base_results, meta_results, emp_metrics, best_sid)
% BUILD_MODEL_RESULTS_MASTER — single source of truth for all model results.
%
%   Returns a struct array M with one entry per model, containing:
%     M(k).kind        : model name (lowercase string)
%     M(k).category    : 'base_learner' | 'meta_learner' | 'empirical_baseline'
%     M(k).metrics     : canonical 7-field metric struct
%     M(k).cv_rmse_std : double; NaN for empirical
%     M(k).lambda_star : double; NaN for non-ridge
%     M(k).feature_set : 'best_scenario' | 'meta_input' | 'empirical'
%
%   ALL downstream artifacts (table3, final_ranking, model_selection_reason)
%   MUST be derived from this single M struct. This prevents ranking
%   inconsistency across files.
%
%   Inputs:
%     base_results : struct (with fields like .S1_intersection.pnn, ...)
%     meta_results : struct array (kind, test_metrics, cv_rmse_std, lambda_star)
%     emp_metrics  : struct (.castagna, .gc_shale, .gc_sand, .gc_limestone)
%     best_sid     : feature-scenario id selected for stacking base preds
%
%   Author: RCW (2026-06)

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..')));

M = repmat(struct('kind','','category','','metrics',[], ...
                  'cv_rmse_std',NaN,'lambda_star',NaN,'feature_set',''), 0, 0);

% ---- Base learners (from best scenario only — used for stacking) -------
base_kinds = {'pnn','mlffnn','dffnn','cnn1d'};
for k = 1:numel(base_kinds)
    kk = base_kinds{k};
    if isfield(base_results, best_sid) && isfield(base_results.(best_sid), kk)
        r = base_results.(best_sid).(kk);
        entry.kind        = kk;
        entry.category    = 'base_learner';
        entry.metrics     = force_metric_fields(r.test_metrics);
        entry.cv_rmse_std = double(r.cv_rmse_std);
        entry.lambda_star = NaN;
        entry.feature_set = best_sid;
        M(end+1, 1) = entry;
    end
end

% ---- Meta-learners ------------------------------------------------------
for k = 1:numel(meta_results)
    mr = meta_results(k);
    entry.kind        = mr.kind;
    entry.category    = 'meta_learner';
    entry.metrics     = force_metric_fields(mr.test_metrics);
    entry.cv_rmse_std = double(mr.cv_rmse_std);
    if isfield(mr, 'lambda_star') && ~isempty(mr.lambda_star)
        entry.lambda_star = double(mr.lambda_star);
    else
        entry.lambda_star = NaN;
    end
    entry.feature_set = 'meta_input';
    M(end+1, 1) = entry;
end

% ---- Empirical baselines ------------------------------------------------
emp_pretty_names = struct( ...
    'castagna',     'Castagna mudrock', ...
    'gc_shale',     'Greenberg-Castagna shale', ...
    'gc_sand',      'Greenberg-Castagna sand', ...
    'gc_limestone', 'Greenberg-Castagna limestone');
emp_keys = fieldnames(emp_metrics);
for k = 1:numel(emp_keys)
    key = emp_keys{k};
    if isfield(emp_pretty_names, key)
        pretty = emp_pretty_names.(key);
    else
        pretty = key;
    end
    entry.kind        = pretty;
    entry.category    = 'empirical_baseline';
    entry.metrics     = force_metric_fields(emp_metrics.(key));
    entry.cv_rmse_std = NaN;
    entry.lambda_star = NaN;
    entry.feature_set = 'empirical';
    M(end+1, 1) = entry;
end

% Sort by R² descending — this is the canonical order for ALL outputs
r2_all = arrayfun(@(x) x.metrics.R2, M);
[~, ord] = sort(r2_all, 'descend', 'MissingPlacement', 'last');
M = M(ord);
end
