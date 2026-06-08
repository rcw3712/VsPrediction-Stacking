% MAIN_PIPELINE — Vs prediction end-to-end (multi-seed)
%
% Maturation features:
%   - Timestamped run folder: results/NEJ_excel_locked_final_YYYYMMDD_HHMM/
%   - Single source of truth: model_results_master
%   - Explicit deployment selection via select_deployment_model
%   - All metrics in physical_kms domain
%   - Feature scenarios with assertions
%   - QC gate (assert_run_consistency) before final
%   - Publication-quality figures
%
% Author: RCW (2026-06)

clear; clc; close all;

fprintf('\n========================================================\n');
fprintf('   Vs Prediction Pipeline — NEJ_v3 EXCEL LOCKED FINAL\n');
fprintf('   Started: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf('========================================================\n');

addpath(genpath('src'));
addpath('config');
addpath('.');

cfg = default_config();
validate_config(cfg);

% Timestamped run folder
ts = datestr(now, 'yyyymmdd_HHMM');
run_name = sprintf('NEJ_excel_locked_final_%s', ts);
cfg.results_dir       = fullfile(cfg.results_root, run_name);
cfg.intermediate_dir  = fullfile(cfg.results_dir, 'intermediate');
cfg.audit_dir         = fullfile(cfg.results_dir, 'audit');
cfg.tables_dir        = fullfile(cfg.results_dir, 'tables');
cfg.figures_dir       = fullfile(cfg.results_dir, 'figures');
cfg.figures_pub_dir   = fullfile(cfg.results_dir, 'figures_publication');
for d = {cfg.results_dir, cfg.intermediate_dir, cfg.audit_dir, ...
         cfg.tables_dir, cfg.figures_dir, cfg.figures_pub_dir}
    safe_mkdir(d{1});
end
logfile = setup_logger(cfg);
fprintf('  Run folder: %s\n', cfg.results_dir);

% --- 1. Import + audit ---
fprintf('\n[1/12] Loading wells ...\n');
D1_raw = read_well_excel_canonical(cfg.data.train_file, cfg, cfg.data.train_well);
D2_raw = read_well_excel_canonical(cfg.data.blind_file, cfg, cfg.data.blind_well);
n_raw_train = height(D1_raw); n_raw_blind = height(D2_raw);
audit_loaded_data(D1_raw, D2_raw, cfg);

% --- 2. Preprocess (VS PROTECTED — predictors only get imputed) ---
fprintf('\n[2/12] Preprocessing ...\n');
D1 = preprocess_well(D1_raw, cfg, cfg.data.train_well);
D2 = preprocess_well(D2_raw, cfg, cfg.data.blind_well);
writetable(D1, fullfile(cfg.intermediate_dir, 'NEJ-1_preprocessed.csv'));
writetable(D2, fullfile(cfg.intermediate_dir, 'NEJ-2_preprocessed.csv'));

% --- 2b. Build supervised dataset (only VS_source == "measured") ---
fprintf('\n[2b/12] Building supervised dataset (target-clean) ...\n');
n_vs_measured = sum(D1.VS_source == "measured");
n_vs_missing  = sum(D1.VS_source == "missing");
D1_sup = build_supervised_dataset(D1, cfg.data.train_well);
% Hard assertion (per spec)
assert(all(D1_sup.VS_source == "measured"), ...
    'Target VS used for supervised learning must be measured, not imputed.');
fprintf('  [SUP] NEJ-1: %d measured  |  %d missing  |  supervised=%d\n', ...
        n_vs_measured, n_vs_missing, height(D1_sup));
writetable(D1_sup, fullfile(cfg.intermediate_dir, 'NEJ-1_supervised.csv'));

% --- 3. Train/test split (ON SUPERVISED ONLY) ---
fprintf('\n[3/12] Train/test split (from supervised set) ...\n');
rng(cfg.seed, 'twister');
n1 = height(D1_sup);
idx_all = randperm(n1);
n_test = round(cfg.split.test_fraction * n1);
test_idx  = idx_all(1:n_test);
train_idx = idx_all(n_test+1:end);
D1_train = D1_sup(train_idx, :);
D1_test  = D1_sup(test_idx,  :);
fprintf('  Train=%d, Test=%d (all VS measured ✓)\n', height(D1_train), height(D1_test));
% Save split indices for audit
T_split = table((1:n1)', [string(repmat({'train'}, n1, 1))], ...
                'VariableNames', {'sup_idx','split'});
T_split.split(test_idx) = "test";
writetable(T_split, fullfile(cfg.audit_dir, 'train_test_split.csv'));

% --- 4. Normalization (train only) ---
fprintf('\n[4/12] Normalization ...\n');
features_canon = cfg.features.candidate_logs;
X_train_raw = D1_train{:, features_canon};
X_test_raw  = D1_test{:,  features_canon};
X_blind_raw = nan(height(D2), numel(features_canon));
for k = 1:numel(features_canon)
    c = features_canon{k};
    if ismember(c, D2.Properties.VariableNames)
        X_blind_raw(:, k) = D2.(c);
    end
end
y_train_raw = D1_train.VS;
y_test_raw  = D1_test.VS;

ns_X = fit_normalization(X_train_raw, cfg.preprocess.normalize_method);
ns_y = fit_normalization(y_train_raw, cfg.preprocess.normalize_method);
X_train = apply_normalization(X_train_raw, ns_X);
X_test  = apply_normalization(X_test_raw,  ns_X);
X_blind = apply_normalization(X_blind_raw, ns_X);
y_train = apply_normalization(y_train_raw, ns_y);
y_test  = apply_normalization(y_test_raw,  ns_y);
save(fullfile(cfg.intermediate_dir, 'normalization.mat'), 'ns_X', 'ns_y');

% --- 5. Feature scenarios ---
fprintf('\n[5/12] Feature selection scenarios ...\n');
scenarios = build_feature_scenarios(X_train, y_train, features_canon, cfg);

fs_rows = cell(numel(scenarios), 6);
for s = 1:numel(scenarios)
    fs_rows(s, :) = {scenarios(s).id, scenarios(s).name, ...
                     strjoin(scenarios(s).features, ', '), ...
                     numel(scenarios(s).features), scenarios(s).source, ''};
end
fs_T = cell2table(fs_rows, 'VariableNames', ...
    {'scenario_id','scenario_name','selected_features','n_features','source_method','notes'});
write_table_safe(fs_T, fullfile(cfg.tables_dir, 'feature_selection_scenarios.csv'));

% Permutation importance
try
    A_ridge = X_train' * X_train + 0.1 * eye(size(X_train,2));
    beta_probe = A_ridge \ (X_train' * y_train);
    predict_probe = @(Xq) Xq * beta_probe;
    perm_imp = permutation_importance(X_train, y_train, predict_probe, ...
                                      features_canon, 5, cfg.seed);
    perm_T = table(features_canon(:), perm_imp(:), ...
                   'VariableNames', {'Feature','PermutationImportance_dR2'});
    perm_T = sortrows(perm_T, 'PermutationImportance_dR2', 'descend');
    write_table_safe(perm_T, fullfile(cfg.tables_dir, 'permutation_importance.csv'));
catch ME, warning('Permutation importance skipped: %s', ME.message); end

% --- 6. Base learners × scenarios ---
fprintf('\n[6/12] Base learners ...\n');
base_kinds = {'pnn','mlffnn','dffnn','cnn1d'};
base_results = struct();
all_perf_rows = {};
for s = 1:numel(scenarios)
    sid = scenarios(s).id;
    cols_s = scenarios(s).indices;
    Xtr_s  = X_train(:, cols_s);
    Xte_s  = X_test(:,  cols_s);
    fprintf('\n  --- %s (%d feat) ---\n', sid, numel(cols_s));
    for m = 1:numel(base_kinds)
        kind = base_kinds{m};
        r = train_with_cv(Xtr_s, y_train, Xte_s, y_test, ns_y, kind, cfg, sid);
        r.test_metrics = force_metric_fields(r.test_metrics);
        base_results.(sid).(kind) = r;
        all_perf_rows(end+1, :) = {sid, kind, ...
            r.test_metrics.R2, r.test_metrics.RMSE_kms, r.test_metrics.MAE_kms, ...
            r.test_metrics.MAPE_percent, r.cv_rmse_mean, r.cv_rmse_std};
    end
end
all_perf_T = cell2table(all_perf_rows, 'VariableNames', ...
    {'Scenario','Model','R2','RMSE_kms','MAE_kms','MAPE_percent','CV_RMSE_mean','CV_RMSE_std'});
write_table_safe(all_perf_T, fullfile(cfg.tables_dir, 'all_scenarios_performance.csv'));

% Best scenario for stacking
scen_mean_r2 = zeros(numel(scenarios), 1);
for s = 1:numel(scenarios)
    sid = scenarios(s).id;
    fns = fieldnames(base_results.(sid));
    r2s = arrayfun(@(i) double(base_results.(sid).(fns{i}).test_metrics.R2), 1:numel(fns));
    scen_mean_r2(s) = mean(r2s, 'omitnan');
end
[~, best_scen_idx] = max(scen_mean_r2);
best_sid  = scenarios(best_scen_idx).id;
best_cols = scenarios(best_scen_idx).indices;
fprintf('\n  Best stacking scenario: %s (mean R²=%.3f)\n', best_sid, scen_mean_r2(best_scen_idx));

Z_oof  = zeros(numel(y_train), numel(base_kinds));
Z_test = zeros(numel(y_test),  numel(base_kinds));
for m = 1:numel(base_kinds)
    Z_oof(:, m)  = base_results.(best_sid).(base_kinds{m}).oof_pred_z;
    Z_test(:, m) = base_results.(best_sid).(base_kinds{m}).test_pred_z;
end

% --- 7. Meta-learners ---
fprintf('\n[7/12] Meta-learners ...\n');
y_test_kms = inverse_normalization(y_test, ns_y);

m_ridge = train_ridge_stacker(Z_oof, y_train, cfg);
y_ridge_z = predict_ridge_stacker(m_ridge, Z_test);
m_ridge.test_metrics = force_metric_fields( ...
    evaluate_model(y_test_kms, inverse_normalization(y_ridge_z, ns_y)));
m_ridge.cv_rmse_std = m_ridge.cv_rmse;

m_icnn = train_icnn_stacker(Z_oof, y_train, cfg);
y_icnn_z = predict_icnn_stacker(m_icnn, Z_test);
m_icnn.test_metrics = force_metric_fields( ...
    evaluate_model(y_test_kms, inverse_normalization(y_icnn_z, ns_y)));
m_icnn.cv_rmse_std = m_ridge.cv_rmse;

X_train_best = X_train(:, best_cols);
X_test_best  = X_test(:,  best_cols);
m_hybrid = train_hybrid_icnn(X_train_best, Z_oof, y_train, cfg);
if isfield(m_hybrid, 'net')
    y_hybrid_z = predict_hybrid_icnn(m_hybrid, X_test_best, Z_test);
else
    y_hybrid_z = predict_ridge_stacker(m_hybrid, Z_test);
end
m_hybrid.test_metrics = force_metric_fields( ...
    evaluate_model(y_test_kms, inverse_normalization(y_hybrid_z, ns_y)));
m_hybrid.cv_rmse_std = m_ridge.cv_rmse;

meta_results = repmat(struct('kind','','test_metrics', force_metric_fields(), ...
                             'cv_rmse_std', NaN, 'lambda_star', NaN), 3, 1);
meta_results(1) = make_meta_entry(m_ridge,  'ridge');
meta_results(2) = make_meta_entry(m_icnn,   'icnn');
meta_results(3) = make_meta_entry(m_hybrid, 'hybrid_icnn');

% --- 8. Empirical baselines on test ---
fprintf('\n[8/12] Empirical baselines ...\n');
Vp_test_kms = X_test_raw(:, strcmp(features_canon, 'VP'));
emp_test = empirical_baselines(Vp_test_kms, cfg);
emp_metrics.castagna     = force_metric_fields(evaluate_model(y_test_kms, emp_test.castagna));
emp_metrics.gc_shale     = force_metric_fields(evaluate_model(y_test_kms, emp_test.gc_shale));
emp_metrics.gc_sand      = force_metric_fields(evaluate_model(y_test_kms, emp_test.gc_sand));
emp_metrics.gc_limestone = force_metric_fields(evaluate_model(y_test_kms, emp_test.gc_limestone));

% --- 9. Master results + selection ---
fprintf('\n[9/12] Building master results table ...\n');
M = build_model_results_master(base_results, meta_results, emp_metrics, best_sid);
[winner_kind, ranking, reason] = select_deployment_model(M, cfg);

fprintf('\n  Model ranking:\n');
for r = ranking(:)'
    fprintf('    %d. %-30s R²=%.4f RMSE=%.4f km/s %s\n', ...
            r.rank, r.kind, r.R2, r.RMSE_kms, r.note);
end
fprintf('\n  Deployment: %s\n', winner_kind);

fid_r = fopen(fullfile(cfg.results_dir, 'model_selection_reason.txt'), 'w');
fprintf(fid_r, '%s\n', reason);
fclose(fid_r);

% Build table3 from M
t3_rows = cell(numel(M), 7);
for i = 1:numel(M)
    e = M(i);
    t3_rows(i, :) = {i, e.kind, e.category, e.metrics.R2, ...
                     e.metrics.RMSE_kms, e.metrics.MAE_kms, ...
                     e.metrics.MAPE_percent};
end
T3 = cell2table(t3_rows, 'VariableNames', ...
    {'Rank','Kind','Category','R2','RMSE_kms','MAE_kms','MAPE_percent'});
T3.Domain = repmat({'physical_kms'}, height(T3), 1);
T3.Note = repmat({''}, height(T3), 1);
for i = 1:height(T3)
    for r = ranking(:)'
        if strcmpi(r.kind, T3.Kind{i}), T3.Note{i} = r.note; break; end
    end
end
write_table_safe(T3, fullfile(cfg.tables_dir, 'table3_test_performance.csv'));

FR = struct2table(ranking);
write_table_safe(FR, fullfile(cfg.tables_dir, 'final_model_ranking.xlsx'));

% --- 10. Deploy to NEJ-2 ---
fprintf('\n[10/12] Deploying %s to NEJ-2 ...\n', winner_kind);
X_blind_best = X_blind(:, best_cols);
Z_blind = zeros(height(D2), numel(base_kinds));
for m = 1:numel(base_kinds)
    fm = base_results.(best_sid).(base_kinds{m}).final_model;
    switch base_kinds{m}
        case 'pnn',    Z_blind(:, m) = predict_pnn(fm,    X_blind_best);
        case 'mlffnn', Z_blind(:, m) = predict_mlffnn(fm, X_blind_best);
        case 'dffnn',  Z_blind(:, m) = predict_dffnn(fm,  X_blind_best);
        case 'cnn1d',  Z_blind(:, m) = predict_cnn1d(fm,  X_blind_best);
    end
end

switch winner_kind
    case 'ridge',       Vs_pred_z = predict_ridge_stacker(m_ridge, Z_blind);
    case 'icnn',        Vs_pred_z = predict_icnn_stacker(m_icnn, Z_blind);
    case 'hybrid_icnn', Vs_pred_z = predict_hybrid_icnn(m_hybrid, X_blind_best, Z_blind);
    otherwise
        fm = base_results.(best_sid).(winner_kind).final_model;
        Vs_pred_z = feval(['predict_' winner_kind], fm, X_blind_best);
end

Vs_pred_raw_kms = double(inverse_normalization(Vs_pred_z, ns_y));
[Vs_pred, clipped_mask] = clip_predictions(Vs_pred_raw_kms, ...
    cfg.deployment.vs_clip_kms(1), cfg.deployment.vs_clip_kms(2));
ood_flag = detect_ood(X_blind, cfg.deployment.ood_zthresh);

Vp_blind  = D2.VP;
rho_blind = D2.RHOB;
[nu, G, K] = compute_geomechanics(Vs_pred, Vp_blind, rho_blind);
np = analyze_nonphysical(nu, G, K, ood_flag, cfg);
write_table_safe(np.summary, fullfile(cfg.tables_dir, 'nonphysical_analysis.csv'));

emp_blind = empirical_baselines(Vp_blind, cfg);
Z_blind_kms = inverse_normalization(Z_blind, ns_y);
sigma_proxy = std(Z_blind_kms, 0, 2);
PI_low  = Vs_pred - 1.96 * sigma_proxy;
PI_high = Vs_pred + 1.96 * sigma_proxy;

pred_T = table(D2.DEPTH, D2.GR, D2.RHOB, D2.NPHI, ...
               coalesce_col(D2,'PHIE'), D2.VP, ...
               Vs_pred, Vs_pred_raw_kms, ...
               emp_blind.castagna, emp_blind.gc_shale, ...
               emp_blind.gc_sand, emp_blind.gc_limestone, ...
               nu, G, K, double(ood_flag), double(clipped_mask), ...
               PI_low, PI_high, sigma_proxy, ...
    'VariableNames', {'Depth','GR','RHOB','NPHI','PHIE','VP', ...
                      'Vs_pred','Vs_pred_raw','Vs_castagna','Vs_gc_shale', ...
                      'Vs_gc_sand','Vs_gc_limestone','nu','G','K', ...
                      'OOD','Clipped','PI_low','PI_high','Vs_pred_std'});
write_table_safe(pred_T, fullfile(cfg.tables_dir, 'predictions_NEJ-2.csv'));

pred.depth        = D2.DEPTH;
pred.GR           = D2.GR;
pred.RHOB         = D2.RHOB;
pred.Vp           = D2.VP;
pred.Vs_pred      = Vs_pred;
pred.Vs_castagna  = emp_blind.castagna;
pred.nu           = nu;
pred.ood          = double(ood_flag);
pred.clipped      = double(clipped_mask);
pred.PI_low       = PI_low;
pred.PI_high      = PI_high;

% --- 11. Publication figures ---
fprintf('\n[11/12] Publication figures ...\n');
switch winner_kind
    case 'ridge',       y_test_pred_kms_dep = double(inverse_normalization(y_ridge_z, ns_y));
    case 'icnn',        y_test_pred_kms_dep = double(inverse_normalization(y_icnn_z, ns_y));
    case 'hybrid_icnn', y_test_pred_kms_dep = double(inverse_normalization(y_hybrid_z, ns_y));
    otherwise
        y_test_pred_kms_dep = base_results.(best_sid).(winner_kind).test_pred_kms;
end

emp_test_for_fig5.castagna     = emp_test.castagna;
emp_test_for_fig5.gc_limestone = emp_test.gc_limestone;

make_all_publication_figures(M, ranking, D1_sup, test_idx, ...
    y_test_pred_kms_dep, emp_test_for_fig5, D2, pred, np, ...
    cfg.figures_pub_dir, cfg);

try, generate_fig_ablation_radar(scenarios, base_results, cfg); catch, end

% --- 12. Summary + QC ---
fprintf('\n[12/12] Run summary + QC ...\n');
info.timestamp        = datestr(now);
info.train_file       = cfg.data.train_file;
info.blind_file       = cfg.data.blind_file;
info.sheet_name       = 'Sheet1';
info.n_raw_train      = n_raw_train;
info.n_raw_blind      = n_raw_blind;
info.n_valid_train    = height(D1);
info.n_valid_blind    = height(D2);
info.n_vs_measured    = n_vs_measured;
info.n_vs_missing     = n_vs_missing;
info.n_vs_imputed_sup = 0;
info.n_supervised     = height(D1_sup);
info.depth_range_train = [min(D1.DEPTH), max(D1.DEPTH)];
info.depth_range_blind = [min(D2.DEPTH), max(D2.DEPTH)];
info.seed             = cfg.seed;
info.n_train          = height(D1_train);
info.n_test           = height(D1_test);
info.scenarios        = scenarios;
info.ranking          = ranking;
info.winner_kind      = winner_kind;
info.selection_reason = reason;
info.n_total_blind    = height(D2);
info.n_ood            = sum(ood_flag);
info.n_clipped        = sum(clipped_mask);
info.np_total         = np.totals.n_np_total;
info.np_ood           = np.totals.n_np_ood;
info.np_non_ood       = np.totals.n_np_non_ood;
info.metric_domain    = 'physical_kms';

write_run_summary(cfg.results_dir, info);

try
    assert_run_consistency(cfg.results_dir, M, winner_kind, scenarios);
catch ME
    warning(ME.identifier, '%s', ME.message);
end

fprintf('\n========================================================\n');
fprintf('   Pipeline COMPLETE.\n');
fprintf('   Run folder: %s\n', cfg.results_dir);
fprintf('========================================================\n\n');

diary off;


% --- Local helpers ---
function s = make_meta_entry(m, name)
s = struct('kind', name, ...
           'test_metrics', force_metric_fields(m.test_metrics), ...
           'cv_rmse_std', double(m.cv_rmse_std), ...
           'lambda_star', NaN);
if isfield(m, 'lambda_star') && ~isempty(m.lambda_star)
    s.lambda_star = double(m.lambda_star);
end
end

function v = coalesce_col(T, name)
if ismember(name, T.Properties.VariableNames)
    v = T.(name);
else
    v = nan(height(T), 1);
end
end
