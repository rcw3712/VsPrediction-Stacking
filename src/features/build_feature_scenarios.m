function scenarios = build_feature_scenarios(X, y, candidate_logs, cfg)
% BUILD_FEATURE_SCENARIOS — strict, asserted construction of S1..S4.
%
%   Definitions (HARD):
%     S2_all          = all candidate features         (definitionally all)
%     S3_mrmr_only    = mRMR top-k features            (k = cfg.features.mrmr_top_k)
%     S4_lasso_only   = LASSO non-zero β features      (CV-tuned λ)
%     S1_intersection = S3 ∩ S4                        (with fallback rule)
%
%   Output table columns (all canonical):
%     scenario_id, scenario_name, selected_features, n_features,
%     source_method, notes
%
%   Assertions:
%     - S2 must equal full candidate set
%     - S3 must be exactly the mRMR ranking output
%     - S4 must come from LASSO with at least 1 selected feature
%     - S1 = S3 ∩ S4 if non-empty; otherwise S3 ∪ S4 with WARNING
%
%   Issues a WARNING (does NOT fail) if all scenarios end up identical —
%   that indicates the ablation is not meaningful and ablation comparison
%   should be flagged in the manuscript.
%
%   Author: RCW (2026-06)

addpath(genpath(fullfile(cfg.matlab_root, 'src', 'features')));

p = numel(candidate_logs);
top_k = max(1, min(cfg.features.mrmr_top_k, p));

fprintf('\n  [BUILD-FS] Candidate logs (%d): %s\n', p, strjoin(candidate_logs, ', '));
fprintf('  [BUILD-FS] mRMR top_k = %d, LASSO α = %.4f\n', ...
        top_k, cfg.features.lasso_alpha);

% ----- Run mRMR
[mrmr_idx, mrmr_scores] = mrmr_select(X, y, top_k, candidate_logs);

% ----- Run LASSO
[lasso_idx, lasso_beta] = lasso_select(X, y, cfg.features.lasso_alpha, ...
                                       candidate_logs);

% ----- Define each scenario explicitly
S2_idx = (1:p)';                          % S2 = all
S3_idx = sort(mrmr_idx(:));               % S3 = mRMR (we use top_k)
S4_idx = sort(lasso_idx(:));              % S4 = LASSO
if isempty(S4_idx)
    warning('[BUILD-FS] LASSO selected ZERO features; falling back to S3 for S4');
    S4_idx = S3_idx;
end

S1_idx = intersect(S3_idx, S4_idx);
s1_note = 'mRMR ∩ LASSO';
if isempty(S1_idx)
    warning('[BUILD-FS] Intersection S3 ∩ S4 is EMPTY — falling back to UNION');
    S1_idx = union(S3_idx, S4_idx);
    s1_note = 'mRMR ∪ LASSO (intersection empty)';
end

% ----- Hard assertions
assert(isequal(sort(S2_idx), (1:p)'), 'S2 must equal full candidate set');
assert(~isempty(S3_idx), 'S3 (mRMR) is empty — top_k=%d returned nothing', top_k);
assert(~isempty(S4_idx), 'S4 (LASSO) is empty');
assert(~isempty(S1_idx), 'S1 (intersection) is empty');

% ----- Pack into struct array
scenarios = struct( ...
    'id', {'S1_intersection','S2_all','S3_mrmr_only','S4_lasso_only'}, ...
    'name', {'mRMR ∩ LASSO','All features (no FS)','mRMR-only','LASSO-only'}, ...
    'indices', {S1_idx(:), S2_idx(:), S3_idx(:), S4_idx(:)}, ...
    'features', {candidate_logs(S1_idx), candidate_logs(S2_idx), ...
                 candidate_logs(S3_idx), candidate_logs(S4_idx)}, ...
    'source', {s1_note, 'No feature selection', ...
               sprintf('mRMR top-%d', top_k), 'LASSO non-zero β (CV λ)'});

% Reorder so each row of struct array has fields in canonical order
scenarios = arrayfun(@canonicalize, scenarios);

% Attach algorithm scores once
scenarios(1).extra.mrmr_scores = mrmr_scores;
scenarios(1).extra.lasso_beta  = lasso_beta;

% ----- Check distinctness
sets_str = cell(numel(scenarios), 1);
for s = 1:numel(scenarios)
    sets_str{s} = strjoin(sort(scenarios(s).features), ',');
end
u = unique(sets_str);
if numel(u) < 2
    warning(['[BUILD-FS] All %d scenarios produced IDENTICAL feature sets. ' ...
             'Ablation is not meaningful — review mrmr_top_k and LASSO α.'], ...
             numel(scenarios));
elseif numel(u) < numel(scenarios)
    warning('[BUILD-FS] Only %d distinct feature sets across %d scenarios.', ...
            numel(u), numel(scenarios));
end

% ----- Pretty print
fprintf('  [BUILD-FS] Final scenarios:\n');
for s = 1:numel(scenarios)
    fprintf('    %-16s [%d feats, %s]: %s\n', scenarios(s).id, ...
            numel(scenarios(s).features), scenarios(s).source, ...
            strjoin(scenarios(s).features, ', '));
end
end


function s = canonicalize(s_in)
% Ensure all entries have the same fields in same order (no extra struct mismatch)
s.id       = s_in.id;
s.name     = s_in.name;
s.indices  = s_in.indices;
s.features = s_in.features;
s.source   = s_in.source;
s.extra    = struct();   % placeholder; only the first will get filled
end
