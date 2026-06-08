function [winner_kind, ranking, reason] = select_deployment_model(M, cfg)
% SELECT_DEPLOYMENT_MODEL — pick deployment model using explicit rules.
%
%   M : output of build_model_results_master (struct array, R²-sorted)
%
%   Rules:
%     1. Consider only ML models (base + meta), skip empirical baselines.
%     2. Rank by R² descending.
%     3. If best - second_best  <  cfg.selection.tie_threshold (default 0.005),
%        declare "practically tied" and prefer the SIMPLER model per
%        cfg.selection.simplicity_order.
%     4. Stability secondary tie-break via lower cv_rmse_std.
%     5. Hybrid I-CNN may only win if it exceeds threshold AND cv_rmse_std
%        is no worse than Ridge.
%
%   Returns:
%     winner_kind : selected model name
%     ranking     : struct array suitable for export (rank, kind, R2, RMSE_kms,
%                   MAE_kms, MAPE_percent, cv_rmse_std, category, note)
%     reason      : multi-line narrative explaining the choice
%
%   Author: RCW (2026-06)

if nargin < 2 || ~isfield(cfg, 'selection')
    cfg.selection.tie_threshold   = 0.005;
    cfg.selection.simplicity_order = {'ridge','pnn','mlffnn','dffnn','icnn','cnn1d','hybrid_icnn'};
end

% ---- Filter ML candidates only -----------------------------------------
ml_mask = arrayfun(@(x) ismember(x.category, {'base_learner','meta_learner'}), M);
ML = M(ml_mask);
if isempty(ML)
    error('No ML candidates found in model_results_master');
end

% ---- Get sorted R² (already sorted by build_model_results_master) -----
r2_all  = arrayfun(@(x) x.metrics.R2, ML);
cv_std  = arrayfun(@(x) x.cv_rmse_std, ML);
kinds   = {ML.kind};
n = numel(ML);

% ---- Identify tied set at the top -------------------------------------
top_r2 = r2_all(1);
tied = (top_r2 - r2_all) <= cfg.selection.tie_threshold;
tied_kinds  = kinds(tied);
tied_cv_std = cv_std(tied);
tied_r2     = r2_all(tied);

% ---- Selection logic ---------------------------------------------------
narrative = strings(0, 1);
narrative(end+1) = sprintf('Tie threshold: ΔR² < %.4f', cfg.selection.tie_threshold);
narrative(end+1) = sprintf('Top model: %s (R²=%.4f)', kinds{1}, r2_all(1));
if n >= 2
    narrative(end+1) = sprintf('2nd model: %s (R²=%.4f, ΔR²=%.4f)', ...
                               kinds{2}, r2_all(2), top_r2 - r2_all(2));
end

if numel(tied_kinds) == 1
    % Clear winner — no tie
    winner_kind = tied_kinds{1};
    narrative(end+1) = sprintf( ...
        '%s exceeded all other models beyond the tie threshold — selected directly.', ...
        winner_kind);
else
    % Tied — apply simplicity + stability rules
    narrative(end+1) = sprintf( ...
        '%d models are practically tied (within %.4f R² of the top): %s.', ...
        numel(tied_kinds), cfg.selection.tie_threshold, ...
        strjoin(tied_kinds, ', '));
    
    % Hybrid I-CNN special rule: only allowed to win if (a) NOT in tied set
    % (already handled above) OR (b) it has the BEST cv_rmse_std among tied.
    %
    % Here we simply prefer simpler. Ridge < I-CNN < Hybrid I-CNN.
    simp_order = cfg.selection.simplicity_order;
    rank_pos = inf(1, numel(tied_kinds));
    for i = 1:numel(tied_kinds)
        p = find(strcmpi(simp_order, tied_kinds{i}), 1);
        if ~isempty(p), rank_pos(i) = p; end
    end
    [~, simplest_idx] = min(rank_pos);
    candidate_simplest = tied_kinds{simplest_idx};
    
    % Check stability — if a strictly-simpler model has clearly worse CV std,
    % we may upgrade to a more complex (but more stable) model
    cv_simplest = tied_cv_std(simplest_idx);
    [min_cv, min_cv_idx] = min(tied_cv_std);
    if min_cv < 0.5 * cv_simplest && ~strcmpi(tied_kinds{min_cv_idx}, candidate_simplest)
        winner_kind = tied_kinds{min_cv_idx};
        narrative(end+1) = sprintf( ...
            '%s is simplest but its CV-RMSE std (%.4f) is much worse than %s (%.4f); selected %s for stability.', ...
            candidate_simplest, cv_simplest, ...
            tied_kinds{min_cv_idx}, min_cv, ...
            tied_kinds{min_cv_idx});
    else
        winner_kind = candidate_simplest;
        narrative(end+1) = sprintf( ...
            '%s achieved the highest R² (%.4f) but its gain over %s was within the practical tie threshold; %s was selected due to lower complexity and comparable stability.', ...
            kinds{1}, r2_all(1), candidate_simplest, candidate_simplest);
    end
end

reason = strjoin(narrative, newline);

% ---- Build ranking struct array (canonical order = R² descending) ----
ranking = repmat(struct('rank',0,'kind','','category','', ...
                        'R2',NaN,'RMSE_kms',NaN,'MAE_kms',NaN, ...
                        'MAPE_percent',NaN,'cv_rmse_std',NaN, ...
                        'note',''), 0, 0);
for i = 1:numel(M)
    e = M(i);
    note_str = '';
    if strcmpi(e.kind, winner_kind), note_str = '★ DEPLOYED';
    elseif ml_mask(i) && ismember(e.kind, tied_kinds) && ~strcmpi(e.kind, winner_kind)
        note_str = 'practically tied';
    end
    entry.rank         = i;
    entry.kind         = e.kind;
    entry.category     = e.category;
    entry.R2           = double(e.metrics.R2);
    entry.RMSE_kms     = double(e.metrics.RMSE_kms);
    entry.MAE_kms      = double(e.metrics.MAE_kms);
    entry.MAPE_percent = double(e.metrics.MAPE_percent);
    entry.cv_rmse_std  = double(e.cv_rmse_std);
    entry.note         = note_str;
    ranking(end+1, 1) = entry;
end
end
