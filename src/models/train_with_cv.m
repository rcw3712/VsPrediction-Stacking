function results = train_with_cv(X_train, y_train, X_test, y_test, ...
                                  train_stats_y, model_kind, cfg, feature_set_id)
% TRAIN_WITH_CV — k-fold CV + held-out test evaluation for one base learner.
%   Returns:
%     results.kind           : model name
%     results.oof_pred_z     : n × 1 OOF predictions on TRAIN set (z-score)
%     results.test_pred_z    : n × 1 prediction on TEST set (z-score)
%     results.test_pred_kms  : same, de-standardized to km/s
%     results.cv_metrics_kms : k × 1 struct with per-fold metrics
%     results.test_metrics   : metrics on held-out test (km/s)
%     results.best_hyperparams : grid-search winner
%     results.feature_set    : id of scenario
%   Author: RCW (2026-06)

addpath(genpath(fullfile(cfg.matlab_root, 'src', 'models')));
addpath(genpath(fullfile(cfg.matlab_root, 'src', 'preprocessing')));

% -------------------------------------------------------------------------
% Hyperparameter grid
% -------------------------------------------------------------------------
if cfg.optimization.enabled
    grid = expand_grid_for(model_kind, cfg);
else
    grid = {default_hyperparams_for(model_kind, cfg)};
end

% -------------------------------------------------------------------------
% k-fold CV — find best hyperparams by mean CV RMSE in z-score domain
% -------------------------------------------------------------------------
rng(cfg.seed, 'twister');
cv = cvpartition(numel(y_train), 'KFold', cfg.split.k_fold);

best_score = inf;
best_hp = grid{1};

for gi = 1:numel(grid)
    hp = grid{gi};
    fold_rmse = zeros(cv.NumTestSets, 1);
    for f = 1:cv.NumTestSets
        tr = training(cv, f);
        va = test(cv, f);
        model_f = train_one(X_train(tr,:), y_train(tr), model_kind, hp);
        yhat_va = predict_one(model_f, X_train(va,:), model_kind);
        fold_rmse(f) = sqrt(mean((yhat_va - y_train(va)).^2));
    end
    mean_rmse = mean(fold_rmse);
    if mean_rmse < best_score
        best_score = mean_rmse;
        best_hp    = hp;
    end
end

% -------------------------------------------------------------------------
% Re-run CV with best hyperparams to harvest OOF predictions
% -------------------------------------------------------------------------
rng(cfg.seed, 'twister');
cv = cvpartition(numel(y_train), 'KFold', cfg.split.k_fold);

oof_pred = nan(size(y_train));
% Canonical 7-field schema (matches force_metric_fields)
cv_fold_metrics = repmat(force_metric_fields(), cv.NumTestSets, 1);

for f = 1:cv.NumTestSets
    tr = training(cv, f);
    va = test(cv, f);
    model_f = train_one(X_train(tr,:), y_train(tr), model_kind, best_hp);
    oof_pred(va) = predict_one(model_f, X_train(va,:), model_kind);
    
    % Per-fold metrics in km/s
    yhat_va_kms = inverse_normalization(oof_pred(va), train_stats_y);
    y_va_kms    = inverse_normalization(y_train(va), train_stats_y);
    fold_m = force_metric_fields(evaluate_model(y_va_kms, yhat_va_kms));
    cv_fold_metrics(f) = fold_m;
end

% -------------------------------------------------------------------------
% Final model on FULL training set, applied to held-out test set
% -------------------------------------------------------------------------
final_model = train_one(X_train, y_train, model_kind, best_hp);
test_pred_z = predict_one(final_model, X_test, model_kind);
test_pred_kms = inverse_normalization(test_pred_z, train_stats_y);
y_test_kms    = inverse_normalization(y_test, train_stats_y);
test_metrics = evaluate_model(y_test_kms, test_pred_kms);

% -------------------------------------------------------------------------
% Pack
% -------------------------------------------------------------------------
results.kind             = model_kind;
results.feature_set      = feature_set_id;
results.oof_pred_z       = oof_pred;
results.test_pred_z      = test_pred_z;
results.test_pred_kms    = test_pred_kms;
results.cv_metrics_kms   = cv_fold_metrics;
results.cv_rmse_mean     = mean([cv_fold_metrics.RMSE_kms]);
results.cv_rmse_std      = std([cv_fold_metrics.RMSE_kms]);
results.test_metrics     = force_metric_fields(test_metrics);
results.best_hyperparams = best_hp;
results.final_model      = final_model;

fprintf('  [%s | %s] best hp → CV-RMSE mean=%.3f±%.3f km/s, test R²=%.3f, RMSE=%.3f\n', ...
        model_kind, feature_set_id, results.cv_rmse_mean, results.cv_rmse_std, ...
        test_metrics.R2, test_metrics.RMSE_kms);
end


function grid = expand_grid_for(kind, cfg)
% Return a cell array of hyperparam structs for grid search
mc = cfg.model.(lower(kind));
gridcfg = mc.grid;
g_fields = fieldnames(gridcfg);
combos = {struct()};
for k = 1:numel(g_fields)
    field = g_fields{k};
    vals  = gridcfg.(field);
    new_combos = {};
    for i = 1:numel(combos)
        c = combos{i};
        for j = 1:numel(vals)
            cn = c;
            if iscell(vals), cn.(field) = vals{j};
            else,            cn.(field) = vals(j); end
            new_combos{end+1} = cn;
        end
    end
    combos = new_combos;
end

% Fill defaults for fields not in grid
def = mc.default;
def_fields = fieldnames(def);
for i = 1:numel(combos)
    for k = 1:numel(def_fields)
        if ~isfield(combos{i}, def_fields{k})
            combos{i}.(def_fields{k}) = def.(def_fields{k});
        end
    end
end

% Cap at max_evals
if numel(combos) > cfg.optimization.max_evals
    combos = combos(1:cfg.optimization.max_evals);
end
grid = combos;
end


function hp = default_hyperparams_for(kind, cfg)
hp = cfg.model.(lower(kind)).default;
end


function model = train_one(X, y, kind, hp)
switch lower(kind)
    case 'pnn',    model = train_pnn(X, y, hp);
    case 'mlffnn', model = train_mlffnn(X, y, hp);
    case 'dffnn',  model = train_dffnn(X, y, hp);
    case 'cnn1d',  model = train_cnn1d(X, y, hp);
    otherwise, error('Unknown model kind: %s', kind);
end
end


function yhat = predict_one(model, X, kind)
switch lower(kind)
    case 'pnn',    yhat = predict_pnn(model, X);
    case 'mlffnn', yhat = predict_mlffnn(model, X);
    case 'dffnn',  yhat = predict_dffnn(model, X);
    case 'cnn1d',  yhat = predict_cnn1d(model, X);
    otherwise, error('Unknown model kind: %s', kind);
end
end
