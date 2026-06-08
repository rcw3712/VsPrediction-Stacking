function scenarios = feature_selection_scenarios(X, y, candidate_logs, cfg)
% FEATURE_SELECTION_SCENARIOS — run all 4 scenarios, return struct array.
%   X: n x p TRAINING matrix (already preprocessed + normalized)
%   y: n x 1 TRAINING target
%   candidate_logs: cell array of feature names corresponding to X columns
%
%   Returns scenarios(s).id, .features, .indices for s = 1..4.
%   NEVER selects "final"; just enumerates the four scenarios.
%
%   Author: RCW (2026-06)

addpath(genpath(fullfile(cfg.matlab_root, 'src', 'features')));

p = numel(candidate_logs);
fprintf('\n  [FS] Running 4 feature-selection scenarios on %d candidates: %s\n', ...
        p, strjoin(candidate_logs, ', '));

% Run mRMR and LASSO once, reuse results across scenarios
[mrmr_idx, mrmr_scores] = mrmr_select(X, y, cfg.features.mrmr_top_k, candidate_logs);
[lasso_idx, lasso_beta] = lasso_select(X, y, cfg.features.lasso_alpha, candidate_logs);

mrmr_set  = mrmr_idx;
lasso_set = lasso_idx;
all_set   = (1:p)';

% S1: intersection
inter_set = intersect(mrmr_set, lasso_set);
if isempty(inter_set)
    warning('  [FS] S1 (intersection) is EMPTY — falling back to union');
    inter_set = union(mrmr_set, lasso_set);
end

% Build scenarios
scenarios(1).id       = 'S1_intersection';
scenarios(1).indices  = inter_set(:);
scenarios(1).features = candidate_logs(scenarios(1).indices);

scenarios(2).id       = 'S2_all';
scenarios(2).indices  = all_set(:);
scenarios(2).features = candidate_logs(scenarios(2).indices);

scenarios(3).id       = 'S3_mrmr_only';
scenarios(3).indices  = mrmr_set(:);
scenarios(3).features = candidate_logs(scenarios(3).indices);

scenarios(4).id       = 'S4_lasso_only';
scenarios(4).indices  = lasso_set(:);
scenarios(4).features = candidate_logs(scenarios(4).indices);

% Save metadata
scenarios(1).extra.mrmr_scores  = mrmr_scores;
scenarios(1).extra.lasso_beta   = lasso_beta;

fprintf('  [FS] S1 intersection: %s\n', strjoin(scenarios(1).features, ', '));
fprintf('  [FS] S2 all:          %s\n', strjoin(scenarios(2).features, ', '));
fprintf('  [FS] S3 mRMR-only:    %s\n', strjoin(scenarios(3).features, ', '));
fprintf('  [FS] S4 LASSO-only:   %s\n', strjoin(scenarios(4).features, ', '));
end
