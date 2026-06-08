function fig4_model_ranking_pub(M, outdir, cfg, ranking)
% FIG4_MODEL_RANKING_PUB — horizontal dot plot (publication ready).
%
%   Fix vs previous: YTick must be a STRICTLY INCREASING numeric vector.
%   We use 1:N indices with reverse-direction Y axis so best stays on top.
%   Author: RCW (2026-06)

addpath(fullfile(cfg.matlab_root, 'src', 'figures_publication'));

% Defensive: drop any entries with non-finite R²
r2_raw = arrayfun(@(x) x.metrics.R2, M);
valid_mask = isfinite(r2_raw);
M = M(valid_mask);

if isempty(M)
    warning('Fig4: no valid models to plot'); return;
end

n = numel(M);
r2     = arrayfun(@(x) double(x.metrics.R2),       M);
rmse   = arrayfun(@(x) double(x.metrics.RMSE_kms), M);
cv_std = arrayfun(@(x) double(x.cv_rmse_std),      M);
kinds  = {M.kind};
cats   = {M.category};

cat_colors = struct('base_learner',       [0.20 0.40 0.78], ...
                    'meta_learner',       [0.78 0.20 0.20], ...
                    'empirical_baseline', [0.45 0.45 0.45]);

% Match ranking notes by kind
notes = repmat({''}, n, 1);
if nargin >= 4 && ~isempty(ranking)
    for k = 1:n
        for r = 1:numel(ranking)
            if strcmpi(ranking(r).kind, kinds{k})
                notes{k} = ranking(r).note;
                break;
            end
        end
    end
end

% ---- YTick must be STRICTLY INCREASING numeric ----
y_idx = (1:n)';                  % monotonic 1,2,3,...,n  ✓

fig = figure('Position', [60 60 980 max(420, 32*n + 100)], 'Color', 'w');
ax = axes('Parent', fig); hold(ax, 'on');

% Plot each row at its y_idx
for k = 1:n
    cat = cats{k};
    if isfield(cat_colors, cat), col = cat_colors.(cat); else, col = [0.4 0.4 0.4]; end
    
    % Dot
    plot(ax, r2(k), y_idx(k), 'o', 'MarkerSize', 9, ...
         'MarkerFaceColor', col, 'MarkerEdgeColor', col*0.7, ...
         'LineWidth', 1.0, 'HandleVisibility', 'off');
    
    % CV std error bar
    if ~strcmp(cat, 'empirical_baseline') && isfinite(cv_std(k))
        err = min(0.02, cv_std(k));
        plot(ax, [r2(k)-err, r2(k)+err], [y_idx(k) y_idx(k)], '-', ...
             'Color', col, 'LineWidth', 1.2, 'HandleVisibility', 'off');
    end
    
    % RMSE label
    text(ax, r2(k) + 0.012, y_idx(k), sprintf('RMSE = %.3f km/s', rmse(k)), ...
         'FontName', 'Arial', 'FontSize', 9, ...
         'VerticalAlignment', 'middle', 'HandleVisibility', 'off');
    
    % Deployed star
    if contains(string(notes{k}), 'DEPLOY', 'IgnoreCase', true)
        plot(ax, r2(k), y_idx(k), 'p', 'MarkerSize', 18, ...
             'MarkerFaceColor', [1 0.85 0], 'MarkerEdgeColor', [0.5 0.4 0], ...
             'LineWidth', 1.2, 'HandleVisibility', 'off');
    end
end

% Legend dummies
plot(ax, NaN, NaN, 'o', 'MarkerFaceColor', cat_colors.base_learner, ...
     'MarkerEdgeColor', cat_colors.base_learner*0.7, 'MarkerSize', 9, ...
     'LineStyle', 'none', 'DisplayName', 'Base learner');
plot(ax, NaN, NaN, 'o', 'MarkerFaceColor', cat_colors.meta_learner, ...
     'MarkerEdgeColor', cat_colors.meta_learner*0.7, 'MarkerSize', 9, ...
     'LineStyle', 'none', 'DisplayName', 'Meta-learner');
plot(ax, NaN, NaN, 'o', 'MarkerFaceColor', cat_colors.empirical_baseline, ...
     'MarkerEdgeColor', cat_colors.empirical_baseline*0.7, 'MarkerSize', 9, ...
     'LineStyle', 'none', 'DisplayName', 'Empirical baseline');
plot(ax, NaN, NaN, 'p', 'MarkerFaceColor', [1 0.85 0], ...
     'MarkerEdgeColor', [0.5 0.4 0], 'MarkerSize', 14, ...
     'LineStyle', 'none', 'DisplayName', '★ Deployed model');

% --- YTick: pass MONOTONIC INCREASING vector, then reverse direction ---
set(ax, 'YTick', y_idx, 'YTickLabel', kinds, 'YDir', 'reverse');
xlim(ax, [max(0, min(r2)-0.05), 1.08]);
ylim(ax, [0.5, n+0.5]);
xlabel(ax, 'R^2 (test set, km/s domain)', 'FontName', 'Arial', 'FontSize', 11);
title(ax, 'Model ranking by test R²', 'FontName', 'Arial', 'FontSize', 13, ...
      'FontWeight', 'bold');
legend('Location', 'southwest', 'FontName', 'Arial', 'FontSize', 9, ...
       'Box', 'off');

set(ax, 'FontName', 'Arial', 'FontSize', 10, 'Box', 'on', 'TickDir', 'in', ...
        'XGrid', 'on', 'YGrid', 'off', 'GridAlpha', 0.15);

pub_save_figure(fig, outdir, 'Fig4_model_ranking_pub');
close(fig);
end
